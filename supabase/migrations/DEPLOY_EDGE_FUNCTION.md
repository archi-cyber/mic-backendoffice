# Deploy Push Notification Edge Function

This guide will help you deploy the `send-push-notification` Edge Function to Supabase.

## Prerequisites

1. **Supabase CLI installed**
   ```bash
   npm install -g supabase
   ```

2. **Logged into Supabase CLI**
   ```bash
   supabase login
   ```

3. **Service Account JSON file**
   - Location: `c:\Users\maint\Pictures\mic-backoffice-firebase-adminsdk-fbsvc-c34db39af1.json`
   - This file contains your Firebase service account credentials

## Step 1: Link Your Supabase Project

1. Go to your Supabase Dashboard
2. Go to Project Settings (gear icon)
3. Find your **Project Reference ID** (it looks like: `abcdefghijklmnop`)
4. Link your project:
   ```bash
   supabase link --project-ref YOUR_PROJECT_REF
   ```
   Replace `YOUR_PROJECT_REF` with your actual project reference ID.

## Step 2: Set Supabase Secrets

The Edge Function needs Firebase credentials stored as Supabase secrets.

### Set Firebase Project ID

```bash
supabase secrets set FIREBASE_PROJECT_ID=mic-backoffice
```

### Set Service Account JSON

The JSON file contains special characters, so we need to handle it carefully. Here are several methods:

**Method 1: Base64 Encoding (Recommended - Works reliably in PowerShell):**

This method encodes the JSON as base64 to avoid special character issues:

```powershell
# Read JSON file and encode as base64
$json = [System.IO.File]::ReadAllText("c:\Users\maint\Pictures\mic-backoffice-firebase-adminsdk-fbsvc-c34db39af1.json", [System.Text.Encoding]::UTF8)
$bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
$base64 = [System.Convert]::ToBase64String($bytes)
supabase secrets set "FIREBASE_SERVICE_ACCOUNT=$base64"
```

**Note:** The Edge Function has been updated to automatically detect and decode base64-encoded secrets. If you use this method, the function will work correctly.

**Method 2: Manual via Supabase Dashboard (Alternative):**

If CLI methods fail, you can set the secret manually:

1. Go to your Supabase Dashboard: https://supabase.com/dashboard/project/YOUR_PROJECT_ID/settings/functions
2. Navigate to **Settings** → **Edge Functions** → **Secrets**
3. Click **Add Secret**
4. Name: `FIREBASE_SERVICE_ACCOUNT`
5. Value: Paste the entire contents of your JSON file
6. Click **Save**

**Method 3: Using stdin (may not work with PowerShell):**

```powershell
# Read JSON file and pipe to supabase command
Get-Content "c:\Users\maint\Pictures\mic-backoffice-firebase-adminsdk-fbsvc-c34db39af1.json" -Raw | supabase secrets set FIREBASE_SERVICE_ACCOUNT
```

**Method 4: Manual JSON with single quotes (if you want to paste directly):**

1. Open the JSON file: `c:\Users\maint\Pictures\mic-backoffice-firebase-adminsdk-fbsvc-c34db39af1.json`
2. Copy the entire contents and minify it (remove all newlines)
3. In PowerShell, run:
```powershell
# Paste the minified JSON between single quotes
supabase secrets set FIREBASE_SERVICE_ACCOUNT='{"type":"service_account","project_id":"mic-backoffice",...}'
```
Note: Use single quotes `'` to avoid escaping double quotes in JSON. You must minify the JSON first (remove all newlines).

**On Linux/Mac:**

```bash
supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat /path/to/mic-backoffice-firebase-adminsdk-fbsvc-c34db39af1.json)"
```

### Verify Secrets Are Set

```bash
supabase secrets list
```

You should see:
- `FIREBASE_PROJECT_ID`
- `FIREBASE_SERVICE_ACCOUNT`

## Step 3: Deploy the Edge Function

```bash
supabase functions deploy send-push-notification
```

The deployment process will:
1. Build the function
2. Upload it to Supabase
3. Make it available at: `https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-push-notification`

## Step 4: Verify Deployment

1. **Check in Supabase Dashboard:**
   - Go to Supabase Dashboard
   - Navigate to Edge Functions
   - You should see `send-push-notification` in the list

2. **Or use CLI:**
   ```bash
   supabase functions list
   ```

3. **Test the function:**
   - In Supabase Dashboard → Edge Functions → send-push-notification
   - Click "Invoke function"
   - Use this test payload:
   ```json
   {
     "deviceTokens": ["YOUR_DEVICE_TOKEN_HERE"],
     "title": "Test Notification",
     "body": "This is a test",
     "data": {}
   }
   ```

## Troubleshooting

### Error: "Project not linked"
**Solution**: Run `supabase link --project-ref YOUR_PROJECT_REF`

### Error: "Authentication required"
**Solution**: Run `supabase login`

### Error: "Secret already exists"
**Solution**: That's fine - the secret will be updated. You can verify with `supabase secrets list`

### Error: "Function deploy failed"
**Solution**: 
- Check that you're in the project root directory
- Verify the function code exists at `supabase/functions/send-push-notification/index.ts`
- Check Supabase CLI version: `supabase --version`
- Update if needed: `npm update -g supabase`

### Error: "Invalid JSON in service account secret"
**Solution**: 
- Make sure the JSON file is valid (open it and verify no syntax errors)
- For PowerShell, ensure you're using `-Raw` flag with `Get-Content`
- The JSON should be on a single line when set as a secret

## Quick Reference Commands

```bash
# Login to Supabase
supabase login

# Link project
supabase link --project-ref YOUR_PROJECT_REF

# Set secrets
supabase secrets set FIREBASE_PROJECT_ID=mic-backoffice
# (Then set service account JSON as shown above)

# Deploy function
supabase functions deploy send-push-notification

# List functions
supabase functions list

# View function logs
supabase functions logs send-push-notification

# List secrets
supabase secrets list
```

## After Deployment

Once the function is deployed:

1. ✅ Test it from Supabase Dashboard
2. ✅ Try creating an announcement in your app
3. ✅ Check Edge Function logs for any errors
4. ✅ Verify push notifications are received

## Next Steps

After deployment, the push notification service in your Flutter app will automatically use this Edge Function. You don't need to change any code - the function will be called automatically when announcements are created.

