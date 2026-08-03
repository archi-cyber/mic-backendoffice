# Push Notification Troubleshooting Guide

This guide helps diagnose and fix common push notification issues.

## Quick Diagnosis Checklist

Run through these checks to identify the issue:

### 1. ✅ Firebase Initialization
- [ ] Check console logs for: `✓ Firebase initialized successfully`
- [ ] If you see `⚠ Error initializing Firebase`, check `firebase_options.dart`
- [ ] Verify `google-services.json` exists in `android/app/`

### 2. ✅ Device Token Registration
- [ ] Check console logs for FCM token generation
- [ ] Verify token is saved to `user_devices` table in Supabase
- [ ] Check that `DeviceTokenService.initialize()` runs without errors

### 3. ✅ Edge Function Deployment
- [ ] Verify Edge Function is deployed: Check Supabase Dashboard → Edge Functions
- [ ] Function name should be: `send-push-notification`
- [ ] If not deployed, run: `supabase functions deploy send-push-notification`

### 4. ✅ Supabase Secrets Configuration
- [ ] Check that `FIREBASE_PROJECT_ID` secret is set
- [ ] Check that `FIREBASE_SERVICE_ACCOUNT` secret is set
- [ ] Verify service account JSON is valid JSON (no extra quotes/escaping)

### 5. ✅ Firebase Project Setup
- [ ] Verify FCM API is enabled in Google Cloud Console
- [ ] Check service account has proper permissions
- [ ] Verify Firebase project ID matches the one in secrets

## Common Error Messages and Solutions

### Error: "Function not found" or "404"
**Problem**: Edge Function is not deployed or name is incorrect.

**Solution**:
```bash
# Deploy the function
supabase functions deploy send-push-notification

# Verify deployment
supabase functions list
```

---

### Error: "Firebase project ID not configured" or "Firebase service account not configured"
**Problem**: Supabase secrets are not set.

**Solution**:
```bash
# Set Firebase Project ID
supabase secrets set FIREBASE_PROJECT_ID=mic-backoffice

# Set Service Account JSON (Windows PowerShell)
$json = Get-Content "c:\Users\maint\Pictures\mic-backoffice-firebase-adminsdk-fbsvc-c34db39af1.json" -Raw
supabase secrets set FIREBASE_SERVICE_ACCOUNT="$json"

# Verify secrets are set
supabase secrets list
```

---

### Error: "Failed to obtain access token"
**Problem**: Service account JSON is invalid or service account doesn't have proper permissions.

**Solution**:
1. Verify the service account JSON file is valid:
   - Open the JSON file
   - Validate it's proper JSON (no syntax errors)
   - Ensure all required fields are present

2. Check service account permissions in Firebase Console:
   - Go to Firebase Console → Project Settings → Service Accounts
   - Verify the service account has FCM permissions

3. Re-download service account key if needed:
   - Firebase Console → Project Settings → Service Accounts
   - Generate new private key
   - Update Supabase secret with new JSON

---

### Error: "FCM API error: 403" or "Permission denied"
**Problem**: FCM API is not enabled or service account lacks permissions.

**Solution**:
1. Enable FCM API in Google Cloud Console:
   - Go to https://console.cloud.google.com/
   - Select your Firebase project
   - Navigate to APIs & Services → Library
   - Search for "Firebase Cloud Messaging API"
   - Click Enable

2. Verify service account has proper role:
   - Google Cloud Console → IAM & Admin → IAM
   - Find your service account
   - Ensure it has "Firebase Cloud Messaging API Admin" role (or "Editor" role)

---

### Error: "No device tokens found"
**Problem**: Device tokens are not being saved to the database.

**Solution**:
1. Check `user_devices` table exists:
   ```sql
   SELECT * FROM user_devices LIMIT 10;
   ```

2. Check device token service logs:
   - Look for `[DeviceTokenService]` logs in console
   - Verify token is being generated and saved

3. Verify user is authenticated when token is saved:
   - Token is only saved when user is logged in
   - Check that user is properly authenticated

---

### Error: "Firebase not initialized"
**Problem**: Firebase is not initialized in the app.

**Solution**:
1. Check `firebase_options.dart` exists:
   ```bash
   # If missing, generate it
   flutterfire configure
   ```

2. Verify Firebase initialization in `main.dart`:
   - Check that `Firebase.initializeApp()` is called
   - Verify no errors during initialization

3. Check `google-services.json` exists:
   - Path: `android/app/google-services.json`
   - Verify it matches your Firebase project

---

### No Error, But Notifications Not Received
**Problem**: Silent failure - check these common issues.

**Solution**:
1. **Check Edge Function Logs**:
   - Supabase Dashboard → Edge Functions → send-push-notification → Logs
   - Look for errors or warnings

2. **Verify Device Token is Valid**:
   - Check `user_devices` table has valid tokens
   - Tokens can expire - user may need to re-login

3. **Check Notification Permissions**:
   - Android: Check app has notification permission
   - iOS: Check notification permissions in Settings

4. **Test with Firebase Console**:
   - Firebase Console → Cloud Messaging
   - Send a test message to your device token
   - If this works, the issue is with the Edge Function
   - If this doesn't work, the issue is with Firebase setup

5. **Check Device Token Format**:
   - FCM tokens should be long strings
   - Verify tokens in database match format from Firebase

---

## Step-by-Step Diagnostic Process

### Step 1: Check Console Logs
Run your app and look for these log messages:

```
✓ Firebase initialized successfully
[DeviceTokenService] FCM token generated: ...
[DeviceTokenService] Device token saved successfully
[PushNotificationService] Sending push notifications to X devices via Edge Function
[PushNotificationService] ✅ Successfully sent: X success, Y failures
```

If you see error messages, note the exact error text.

### Step 2: Verify Edge Function is Deployed
```bash
# List all deployed functions
supabase functions list

# Should see: send-push-notification
```

If not listed, deploy it:
```bash
supabase functions deploy send-push-notification
```

### Step 3: Verify Supabase Secrets
```bash
# List all secrets
supabase secrets list

# Should see:
# FIREBASE_PROJECT_ID
# FIREBASE_SERVICE_ACCOUNT
```

If missing, set them (see "Common Error Messages" section above).

### Step 4: Test Edge Function Directly
You can test the Edge Function directly from Supabase Dashboard:
1. Go to Supabase Dashboard → Edge Functions → send-push-notification
2. Click "Invoke function"
3. Use this test payload:
```json
{
  "deviceTokens": ["YOUR_DEVICE_TOKEN_HERE"],
  "title": "Test Notification",
  "body": "This is a test",
  "data": {}
}
```
4. Check the response and logs

### Step 5: Check Firebase Console
1. Go to Firebase Console → Cloud Messaging
2. Click "Send your first message"
3. Enter a test device token
4. Send test notification
5. If this works, Firebase is configured correctly

### Step 6: Verify Database
Check that device tokens are being saved:
```sql
-- Check user_devices table
SELECT * FROM user_devices ORDER BY created_at DESC LIMIT 10;

-- Check for active tokens
SELECT COUNT(*) FROM user_devices WHERE token IS NOT NULL;
```

---

## Testing Push Notifications

### Test 1: Create an Announcement
1. Log in to the app
2. Create a new announcement
3. Check console logs for push notification attempts
4. Check if notification is received

### Test 2: Direct Function Invocation
Test the Edge Function with a known device token:
```bash
# Get your device token from console logs or database
# Then invoke function via Supabase Dashboard or CLI
```

### Test 3: Firebase Console Test
1. Get your device token from app logs
2. Firebase Console → Cloud Messaging → Send test message
3. Enter token and send
4. Verify notification is received

---

## Still Having Issues?

If you've checked everything above and notifications still don't work:

1. **Check Edge Function Logs** in Supabase Dashboard for detailed error messages
2. **Check Firebase Console** → Cloud Messaging for delivery statistics
3. **Verify all configuration steps** in FCM_SETUP_GUIDE.md
4. **Check network connectivity** - ensure device can reach Firebase servers
5. **Try a fresh device token** - logout and login again to get a new token

---

## Quick Fix Commands

```bash
# Deploy Edge Function
supabase functions deploy send-push-notification

# Set Firebase Project ID
supabase secrets set FIREBASE_PROJECT_ID=mic-backoffice

# Set Service Account (Windows PowerShell)
$json = Get-Content "c:\Users\maint\Pictures\mic-backoffice-firebase-adminsdk-fbsvc-c34db39af1.json" -Raw
supabase secrets set FIREBASE_SERVICE_ACCOUNT="$json"

# List secrets (verify they're set)
supabase secrets list

# Check function logs
supabase functions logs send-push-notification
```

---

## Configuration Reference

- **Firebase Project ID**: `mic-backoffice`
- **Service Account File**: `c:\Users\maint\Pictures\mic-backoffice-firebase-adminsdk-fbsvc-c34db39af1.json`
- **Edge Function Name**: `send-push-notification`
- **Device Tokens Table**: `user_devices`

