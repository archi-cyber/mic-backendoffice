# Firebase Cloud Messaging (FCM) Setup Guide

This guide will walk you through setting up Firebase Cloud Messaging for your Flutter app.

## Prerequisites

- A Firebase account (create one at https://firebase.google.com if you don't have one)
- Your Flutter project
- Android Studio or VS Code with Flutter extensions

## Step 1: Create or Access Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Add project"** or select your existing project
3. If creating new:
   - Enter project name: `mic-backoffice` (or your preferred name)
   - Enable/disable Google Analytics (optional)
   - Click **"Create project"**

## Step 2: Enable Firebase Cloud Messaging API

1. In your Firebase project, go to **Project Settings** (gear icon ⚙️)
2. Click on the **"Cloud Messaging"** tab
3. Ensure the **Firebase Cloud Messaging API (V1)** is enabled
4. If not enabled, go to [Google Cloud Console](https://console.cloud.google.com/)
   - Select your Firebase project
   - Navigate to **APIs & Services** > **Library**
   - Search for "Firebase Cloud Messaging API"
   - Click **Enable**

## Step 3: Register Android App

1. In Firebase Console, click **"Add app"** or the Android icon
2. Fill in the details:
   - **Android package name**: Check your `android/app/build.gradle.kts` file for `applicationId`
     - Usually something like: `com.example.mic_backoffice`
   - **App nickname** (optional): `MIC Backoffice Android`
   - **Debug signing certificate SHA-1** (optional for now)
3. Click **"Register app"**

## Step 4: Download google-services.json

1. After registering the Android app, download the `google-services.json` file
2. Place it in: `android/app/google-services.json`
   - **Important**: This file should already exist in your project based on the git status
   - If it doesn't exist, create the file and paste the downloaded content

## Step 5: Configure Android Build Files

1. **Check `android/build.gradle.kts`**:
   ```kotlin
   buildscript {
       dependencies {
           // ... existing dependencies
           classpath("com.google.gms:google-services:4.4.0")  // Should already be there
       }
   }
   ```

2. **Check `android/app/build.gradle.kts`**:
   ```kotlin
   plugins {
       id("com.android.application")
       id("kotlin-android")
       id("com.google.gms.google-services")  // Should already be there
   }
   ```

## Step 6: Register iOS App (if targeting iOS)

1. In Firebase Console, click **"Add app"** or the iOS icon
2. Fill in the details:
   - **iOS bundle ID**: Check your `ios/Runner.xcodeproj` or `ios/Runner/Info.plist`
   - **App nickname** (optional): `MIC Backoffice iOS`
3. Click **"Register app"**
4. Download `GoogleService-Info.plist`
5. Place it in: `ios/Runner/GoogleService-Info.plist`

## Step 7: Generate Service Account Key

This is needed for the Supabase Edge Function to send push notifications.

1. In Firebase Console, go to **Project Settings** (gear icon ⚙️)
2. Click on the **"Service accounts"** tab
3. Click **"Generate new private key"**
4. A dialog will appear - click **"Generate key"**
5. A JSON file will be downloaded (e.g., `mic-backoffice-firebase-adminsdk-fbsvc-c34db39af1.json`)
6. **Important**: 
   - Store this file securely
   - Never commit it to version control
   - You already have this file at: `c:\Users\maint\Pictures\mic-backoffice-firebase-adminsdk-fbsvc-c34db39af1.json`

## Step 8: Get Firebase Project ID

1. In Firebase Console, go to **Project Settings** (gear icon ⚙️)
2. Under **"General"** tab, find **"Project ID"**
3. Your project ID is: `mic-backoffice` (from your service account file)

## Step 9: Configure Supabase Edge Function Secrets

Now set up the secrets for your Supabase Edge Function:

```bash
# 1. Set Firebase Project ID
supabase secrets set FIREBASE_PROJECT_ID=mic-backoffice

# 2. Set Service Account JSON (Windows PowerShell)
$json = Get-Content "c:\Users\maint\Pictures\mic-backoffice-firebase-adminsdk-fbsvc-c34db39af1.json" -Raw
supabase secrets set FIREBASE_SERVICE_ACCOUNT="$json"
```

## Step 10: Verify Flutter Dependencies

Check your `pubspec.yaml` - these should already be included:

```yaml
dependencies:
  firebase_core: ^3.6.0
  firebase_messaging: ^15.1.3
  flutter_local_notifications: ^18.0.1
```

If not, add them and run:
```bash
flutter pub get
```

## Step 11: Verify Firebase Configuration

1. Check that `lib/firebase_options.dart` exists (it should be generated)
2. If it doesn't exist, run:
   ```bash
   flutterfire configure
   ```
   - Select your Firebase project
   - Select platforms (Android, iOS, etc.)

## Step 12: Test FCM Setup

### Test from Firebase Console:

1. In Firebase Console, go to **Cloud Messaging**
2. Click **"Send your first message"** or **"New campaign"**
3. Fill in:
   - **Notification title**: Test Notification
   - **Notification text**: This is a test
4. Click **"Next"**
5. Select **"Test message"**
6. Enter your device's FCM token (you can get this from app logs)
7. Click **"Test"**

### Test from Your App:

1. Run your Flutter app
2. Check the console logs for:
   - `✓ Firebase initialized successfully`
   - FCM token (if device token service is working)
3. Create an announcement in your app
4. You should receive a push notification

## Troubleshooting

### Issue: "Firebase not initialized"
- **Solution**: Ensure `firebase_options.dart` exists and is properly configured
- Run `flutterfire configure` if needed

### Issue: "FCM token not generated"
- **Solution**: 
  - Check that `google-services.json` is in `android/app/`
  - Verify Android package name matches Firebase project
  - Check app permissions for notifications

### Issue: "Push notifications not received"
- **Solution**:
  - Verify Edge Function is deployed
  - Check Supabase secrets are set correctly
  - Check device token is saved in `user_devices` table
  - Verify FCM API is enabled in Google Cloud Console

### Issue: "Service account authentication failed"
- **Solution**:
  - Verify service account JSON is correctly set as Supabase secret
  - Check that the JSON is valid (no extra quotes or escaping issues)
  - Ensure the service account has FCM permissions

## Next Steps

1. **Deploy Edge Function**:
   ```bash
   supabase functions deploy send-push-notification
   ```

2. **Test Announcement Notifications**:
   - Create an announcement in your app
   - Verify all users receive push notifications
   - Check Edge Function logs in Supabase dashboard

3. **Monitor**:
   - Check Firebase Console > Cloud Messaging for delivery statistics
   - Monitor Supabase Edge Function logs for errors

## Additional Resources

- [Firebase Cloud Messaging Documentation](https://firebase.google.com/docs/cloud-messaging)
- [FCM HTTP v1 API Migration Guide](https://firebase.google.com/docs/cloud-messaging/migrate-v1)
- [Flutter Firebase Setup](https://firebase.flutter.dev/docs/overview)
- [Supabase Edge Functions Documentation](https://supabase.com/docs/guides/functions)

## Security Notes

⚠️ **Important Security Reminders**:

1. **Never commit** `google-services.json` or service account JSON files to version control
2. **Keep service account keys secure** - they have full access to your Firebase project
3. **Use Supabase secrets** for storing sensitive credentials
4. **Rotate keys** if they are ever exposed
5. **Limit service account permissions** to only what's needed (FCM messaging)

## Quick Reference: Your Current Configuration

Based on your project files, here's what's already set up:

✅ **Android Package Name**: `com.example.mic_backoffice`  
✅ **Google Services Plugin**: Configured in `android/settings.gradle.kts` (version 4.3.15)  
✅ **Firebase Options**: `lib/firebase_options.dart` exists  
✅ **Service Account File**: `c:\Users\maint\Pictures\mic-backoffice-firebase-adminsdk-fbsvc-c34db39af1.json`  
✅ **Firebase Project ID**: `mic-backoffice`  
✅ **Flutter Dependencies**: Already in `pubspec.yaml`

### What You Need to Do:

1. **Verify Firebase Console Setup**:
   - Ensure Android app is registered with package name: `com.example.mic_backoffice`
   - Verify `google-services.json` matches your Firebase project

2. **Set Supabase Secrets** (if not already done):
   ```powershell
   supabase secrets set FIREBASE_PROJECT_ID=mic-backoffice
   $json = Get-Content "c:\Users\maint\Pictures\mic-backoffice-firebase-adminsdk-fbsvc-c34db39af1.json" -Raw
   supabase secrets set FIREBASE_SERVICE_ACCOUNT="$json"
   ```

3. **Deploy Edge Function**:
   ```bash
   supabase functions deploy send-push-notification
   ```

4. **Test**:
   - Run your app
   - Create an announcement
   - Verify push notifications are received

## Checklist

- [ ] Firebase project created/accessed
- [ ] FCM API enabled
- [ ] Android app registered in Firebase
- [ ] `google-services.json` downloaded and placed correctly
- [ ] iOS app registered (if targeting iOS)
- [ ] Service account key generated
- [ ] Supabase secrets configured
- [ ] Flutter dependencies installed
- [ ] `firebase_options.dart` generated
- [ ] Edge Function deployed
- [ ] Test notification sent successfully
