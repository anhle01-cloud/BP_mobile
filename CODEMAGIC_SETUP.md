# CodeMagic iOS Build Setup

This guide will help you set up CodeMagic for building and deploying your BP Mobile iOS app.

## Prerequisites

1. **Apple Developer Account** (required for signing and distribution)
2. **CodeMagic Account** (sign up at https://codemagic.io)
3. **GitHub Repository** (your code must be in a Git repository)

## Step 1: Configure CodeMagic

1. Go to https://codemagic.io and sign in
2. Click "Add application"
3. Select your Git provider (GitHub, GitLab, Bitbucket)
4. Select your repository: `BP_mobile` or `BlackPearlMobile`
5. Select "Flutter" as the project type

## Step 2: Configure App Store Connect Credentials

### Option A: Using API Key (Recommended)

1. In App Store Connect, go to **Users and Access** → **Keys**
2. Create a new key with **App Manager** role
3. Download the `.p8` key file
4. Note the Key ID and Issuer ID

### Option B: Using Username/Password

1. Use your Apple ID credentials
2. Enable 2FA if required

## Step 3: Add CodeMagic Environment Variables

In CodeMagic dashboard, go to your app → **Settings** → **Environment variables** and add:

```
APP_STORE_CONNECT_ISSUER_ID=<your-issuer-id>
APP_STORE_CONNECT_KEY_IDENTIFIER=<your-key-id>
APP_STORE_CONNECT_PRIVATE_KEY=<your-p8-key-content>
```

Or if using username/password:
```
APP_STORE_CONNECT_USERNAME=<your-apple-id>
APP_STORE_CONNECT_PASSWORD=<app-specific-password>
```

## Step 4: Configure Code Signing

1. In CodeMagic, go to **Settings** → **Code signing**
2. Upload your **Distribution Certificate** (.p12 file)
3. Upload your **Provisioning Profile** (.mobileprovision file)

### How to get certificates:

1. In Xcode:
   - Go to **Preferences** → **Accounts**
   - Add your Apple ID
   - Select your team
   - Click **Manage Certificates**
   - Download certificates

2. Or use App Store Connect:
   - Go to **Certificates, Identifiers & Profiles**
   - Create/Download certificates

## Step 5: Update codemagic.yaml

The `codemagic.yaml` file is already configured. You may need to update:

1. **Bundle ID**: Currently set to `com.example.blackpearlMobile`
   - If you want to change it, update in:
     - `ios/Runner.xcodeproj/project.pbxproj`
     - `codemagic.yaml` (BUNDLE_ID variable)

2. **Email notifications**: Update the email in `codemagic.yaml`:
   ```yaml
   recipients:
     - your-email@example.com
   ```

3. **App Store Connect**: If you want to submit to TestFlight or App Store:
   ```yaml
   submit_to_testflight: true
   submit_to_app_store: false  # Set to true for App Store submission
   ```

## Step 6: Test the Build

1. In CodeMagic dashboard, click **Start new build**
2. Select the `ios-workflow` workflow
3. Select your branch (usually `main` or `master`)
4. Click **Start build**

The build will:
- Install dependencies
- Build the iOS app
- Create an IPA file
- Optionally submit to TestFlight/App Store

## Step 7: Download or Distribute

After a successful build:
- Download the IPA from CodeMagic dashboard
- Or install via TestFlight (if configured)
- Or release to App Store (if configured)

## Troubleshooting

### Common Issues:

1. **Code Signing Errors**
   - Ensure certificates are valid and not expired
   - Check that bundle ID matches in all places
   - Verify provisioning profile matches bundle ID

2. **Build Failures**
   - Check build logs in CodeMagic dashboard
   - Ensure all dependencies are in `pubspec.yaml`
   - Verify iOS deployment target compatibility

3. **Permission Errors**
   - Ensure Info.plist has all required permission descriptions
   - Check that background modes are configured

## Additional Resources

- CodeMagic Docs: https://docs.codemagic.io
- Flutter iOS Setup: https://docs.flutter.dev/deployment/ios
- App Store Connect: https://appstoreconnect.apple.com

## Notes

- The current bundle ID is `com.example.blackpearlMobile`
- For production, consider changing to a reverse domain name (e.g., `com.yourcompany.bpmobile`)
- iOS deployment target is set in `ios/Podfile` (default: iOS 14.0+)
- Background modes are configured for location and background processing

