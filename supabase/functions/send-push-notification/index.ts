// Supabase Edge Function to send push notifications via FCM HTTP v1 API
// This function should be deployed to Supabase Edge Functions
// 
// Setup:
// 1. Install Supabase CLI: npm install -g supabase
// 2. Login: supabase login
// 3. Link project: supabase link --project-ref your-project-ref
// 4. Set Firebase project ID: supabase secrets set FIREBASE_PROJECT_ID=your-project-id
// 5. Set service account JSON (as string): supabase secrets set FIREBASE_SERVICE_ACCOUNT='{"type":"service_account",...}'
// 6. Deploy: supabase functions deploy send-push-notification

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { create, getNumericDate } from 'https://deno.land/x/djwt@v2.8/mod.ts';

const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
const MAX_TOKENS_PER_REQUEST = 500; // FCM v1 allows up to 500 tokens per multicast request

interface PushNotificationRequest {
  deviceTokens: string[];
  title: string;
  body: string;
  data?: Record<string, any>;
}

interface ServiceAccount {
  type: string;
  project_id: string;
  private_key_id: string;
  private_key: string;
  client_email: string;
  client_id: string;
  auth_uri: string;
  token_uri: string;
  auth_provider_x509_cert_url: string;
  client_x509_cert_url: string;
}

interface AccessTokenResponse {
  access_token: string;
  expires_in: number;
  token_type: string;
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    });
  }

  try {
    // Get Firebase project ID and service account from secrets
    const projectId = Deno.env.get('FIREBASE_PROJECT_ID');
    let serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');

    if (!projectId) {
      console.error('FIREBASE_PROJECT_ID secret is not set');
      return new Response(
        JSON.stringify({ error: 'Firebase project ID not configured' }),
        {
          status: 500,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      );
    }

    if (!serviceAccountJson) {
      console.error('FIREBASE_SERVICE_ACCOUNT secret is not set');
      return new Response(
        JSON.stringify({ error: 'Firebase service account not configured' }),
        {
          status: 500,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      );
    }

    // Handle base64-encoded service account (common when setting via CLI with special characters)
    try {
      // Try to decode as base64 first (if it's base64, it will decode successfully)
      // Base64 strings are typically longer and don't start with '{'
      if (!serviceAccountJson.trim().startsWith('{')) {
        try {
          const decoded = atob(serviceAccountJson);
          // If decoding works and results in valid JSON, use it
          JSON.parse(decoded);
          serviceAccountJson = decoded;
        } catch {
          // If base64 decode fails, assume it's already JSON
        }
      }
    } catch {
      // If any error, assume it's already JSON format
    }

    const serviceAccount: ServiceAccount = JSON.parse(serviceAccountJson);
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

    // Parse request body
    const body: PushNotificationRequest = await req.json();
    const { deviceTokens, title, body: messageBody, data } = body;

    if (!deviceTokens || deviceTokens.length === 0) {
      return new Response(
        JSON.stringify({ error: 'No device tokens provided' }),
        {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      );
    }

    if (!title || !messageBody) {
      return new Response(
        JSON.stringify({ error: 'Title and body are required' }),
        {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      );
    }

    console.log(`Sending push notifications to ${deviceTokens.length} devices`);

    // Get OAuth 2.0 access token
    const accessToken = await getAccessToken(serviceAccount);
    if (!accessToken) {
      return new Response(
        JSON.stringify({ error: 'Failed to obtain access token' }),
        {
          status: 500,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      );
    }

    // Send notifications
    // FCM v1 doesn't support batch sending like legacy API
    // We'll send individual requests or use multicast (up to 500 tokens)
    let totalSuccess = 0;
    let totalFailure = 0;

    // Process in batches of 500 (FCM v1 multicast limit)
    for (let i = 0; i < deviceTokens.length; i += MAX_TOKENS_PER_REQUEST) {
      const batch = deviceTokens.slice(i, i + MAX_TOKENS_PER_REQUEST);
      
      // For single token, use token field; for multiple, use tokens array (multicast)
      const messagePayload: any = {
        notification: {
          title: title,
          body: messageBody,
        },
        data: data || {},
        android: {
          priority: 'high',
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      };

      // Use multicast for multiple tokens, single token for one
      if (batch.length === 1) {
        messagePayload.token = batch[0];
      } else {
        messagePayload.tokens = batch;
      }

      const payload = {
        message: messagePayload,
      };

      const response = await fetch(fcmUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${accessToken}`,
        },
        body: JSON.stringify(payload),
      });

      if (!response.ok) {
        const errorText = await response.text();
        console.error(`FCM API error: ${response.status} - ${errorText}`);
        totalFailure += batch.length;
        continue;
      }

      const result = await response.json();
      
      // For multicast, check responses array
      if (batch.length > 1 && result.responses) {
        result.responses.forEach((resp: any) => {
          if (resp.success) {
            totalSuccess++;
          } else {
            totalFailure++;
            console.error(`Token failed: ${resp.error}`);
          }
        });
      } else if (result.name) {
        // Single token success
        totalSuccess++;
      } else {
        totalFailure++;
      }

      console.log(`Batch ${Math.floor(i / MAX_TOKENS_PER_REQUEST) + 1}: processed ${batch.length} tokens`);
    }

    console.log(`Total: ${totalSuccess} success, ${totalFailure} failures`);

    return new Response(
      JSON.stringify({
        success: true,
        totalSuccess,
        totalFailure,
        totalSent: deviceTokens.length,
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    );
  } catch (error) {
    console.error('Error sending push notifications:', error);
    return new Response(
      JSON.stringify({ error: error.message || 'Internal server error' }),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    );
  }
});

// Generate OAuth 2.0 access token from service account
async function getAccessToken(serviceAccount: ServiceAccount): Promise<string | null> {
  try {
    // Create JWT for service account
    const now = getNumericDate(new Date());
    const jwt = await createJWT(serviceAccount, now);

    // Exchange JWT for access token
    const tokenResponse = await fetch(serviceAccount.token_uri, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: jwt,
      }),
    });

    if (!tokenResponse.ok) {
      const errorText = await tokenResponse.text();
      console.error(`Failed to get access token: ${errorText}`);
      return null;
    }

    const tokenData: AccessTokenResponse = await tokenResponse.json();
    return tokenData.access_token;
  } catch (error) {
    console.error('Error generating access token:', error);
    return null;
  }
}

// Create JWT for service account authentication
async function createJWT(serviceAccount: ServiceAccount, now: number): Promise<string> {
  const header = {
    alg: 'RS256',
    typ: 'JWT',
  };

  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: serviceAccount.token_uri,
    iat: now,
    exp: now + 3600, // 1 hour
    scope: FCM_SCOPE,
  };

  // Import private key
  const privateKey = await importPrivateKey(serviceAccount.private_key);

  // Create and sign JWT
  const jwt = await create(header, payload, privateKey);
  return jwt;
}

// Import PEM private key for Web Crypto API
async function importPrivateKey(pem: string): Promise<CryptoKey> {
  // Remove PEM headers and whitespace
  const base64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '');
  
  // Decode base64
  const binaryString = atob(base64);
  const bytes = new Uint8Array(binaryString.length);
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }

  // Import key
  const key = await crypto.subtle.importKey(
    'pkcs8',
    bytes.buffer,
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    },
    false,
    ['sign']
  );

  return key;
}
