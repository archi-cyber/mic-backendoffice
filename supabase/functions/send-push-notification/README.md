# Send Push Notification Edge Function

This Supabase Edge Function sends push notifications via Firebase Cloud Messaging (FCM) using the **HTTP v1 API** with OAuth 2.0 access tokens.

## Setup

1. **Install Supabase CLI** (if not already installed):
   ```bash
   npm install -g supabase
   ```

2. **Login to Supabase**:
   ```bash
   supabase login
   ```

3. **Link your project**:
   ```bash
   supabase link --project-ref your-project-ref
   ```
   You can find your project ref in your Supabase project settings.

4. **Service Account File**:
   - The service account file is located at: `c:\Users\maint\Pictures\mic-backoffice-firebase-adminsdk-fbsvc-c34db39af1.json`
   - **Important**: Keep this file secure and never commit it to version control
   - The project ID from this file is: `mic-backoffice`

5. **Set Supabase Secrets**:
   ```bash
   # Set Firebase Project ID (extracted from service account file)
   supabase secrets set FIREBASE_PROJECT_ID=mic-backoffice
   
   # Set Service Account JSON (as a string)
   # On Windows (PowerShell):
   $json = Get-Content "c:\Users\maint\Pictures\mic-backoffice-firebase-adminsdk-fbsvc-c34db39af1.json" -Raw
   supabase secrets set FIREBASE_SERVICE_ACCOUNT="$json"
   
   # On Linux/Mac (if file is copied):
   supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat path/to/mic-backoffice-firebase-adminsdk-fbsvc-c34db39af1.json)"
   ```

6. **Deploy the function**:
   ```bash
   supabase functions deploy send-push-notification
   ```

## Usage

The function can be called from your Flutter app using the Supabase client:

```dart
final response = await supabase.functions.invoke('send-push-notification', body: {
  'deviceTokens': ['token1', 'token2', ...],
  'title': 'Notification Title',
  'body': 'Notification Body',
  'data': {
    'type': 'announcement',
    'announcement_id': '123',
  },
});
```

## Response

```json
{
  "success": true,
  "totalSuccess": 10,
  "totalFailure": 0,
  "totalSent": 10
}
```

## Notes

- **Uses FCM HTTP v1 API**: This function uses the modern FCM HTTP v1 API with OAuth 2.0 access tokens (not the deprecated legacy API)
- **Batch Processing**: The function processes device tokens in batches of 500 (FCM v1 multicast limit)
- **Secure Credentials**: Service account credentials are stored securely as Supabase secrets
- **Token Management**: Access tokens are automatically generated and refreshed as needed
- **Error Handling**: The function handles errors gracefully and returns detailed results

## Migration from Legacy API

If you were previously using the legacy FCM API:
- The legacy API was deprecated on June 20, 2023
- Shutdown begins on July 22, 2024
- This Edge Function uses the HTTP v1 API which is the recommended approach
- You need to use a service account JSON instead of a server key
