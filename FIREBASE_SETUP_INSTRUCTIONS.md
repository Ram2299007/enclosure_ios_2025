# Firebase Setup Instructions

This guide will help you complete the Firebase integration for your Enclosure iOS app.

## Prerequisites

1. A Firebase account (create one at https://firebase.google.com/)
2. Your iOS app's Bundle Identifier (check in Xcode project settings)

## Step 1: Add Firebase SDK Packages via Xcode

1. Open your project in Xcode
2. Select your project in the navigator
3. Go to the **Package Dependencies** tab
4. Click the **+** button to add a package
5. Enter the Firebase iOS SDK URL: `https://github.com/firebase/firebase-ios-sdk`
6. Click **Add Package**
7. Select the following products (you can select multiple):
   - **FirebaseCore**
   - **FirebaseMessaging**
8. Click **Add Package**
9. Make sure these packages are added to your **Enclosure** target

## Step 2: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **Add project** or select an existing project
3. Follow the setup wizard:
   - Enter project name
   - Enable/disable Google Analytics (optional)
   - Create the project

## Step 3: Add iOS App to Firebase

1. In Firebase Console, click **Add app** and select **iOS**
2. Enter your iOS bundle ID: **`com.enclosure`** (or check in Xcode: Project Settings → General → Bundle Identifier)
3. Register the app
4. Download the **GoogleService-Info.plist** file

## Step 4: Add GoogleService-Info.plist to Xcode

1. In Xcode, right-click on the **Enclosure** folder in the project navigator
2. Select **Add Files to "Enclosure"...**
3. Navigate to and select the downloaded **GoogleService-Info.plist** file
4. **IMPORTANT**: Make sure:
   - ✅ "Copy items if needed" is checked
   - ✅ "Add to targets: Enclosure" is checked
   - ✅ The file is added to the root of the Enclosure folder (same level as EnclosureApp.swift)

## Step 5: Enable Push Notifications in Xcode

1. Select your project in Xcode
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **Push Notifications**
5. Add **Background Modes** and enable:
   - ✅ Remote notifications

## Step 6: Verify Setup

1. Build and run your app
2. Check the console logs for:
   - ✅ "Firebase registration token: [token]" - indicates successful setup
   - ❌ Any Firebase-related errors

## Troubleshooting

### Common Issues:

1. **"GoogleService-Info.plist not found"**
   - Ensure the file is in the Enclosure folder (not a subfolder)
   - Check that it's added to the target in "Target Membership"

2. **"No Firebase App '[DEFAULT]' has been created"**
   - Make sure `FirebaseApp.configure()` is called in `AppDelegate.didFinishLaunchingWithOptions`
   - Verify GoogleService-Info.plist is properly added

3. **FCM Token is nil**
   - Check that Push Notifications capability is enabled
   - Verify notification permissions are granted
   - Check device/simulator supports push notifications (simulator may have limitations)

4. **Build Errors**
   - Clean build folder: Product → Clean Build Folder (Shift+Cmd+K)
   - Delete DerivedData folder
   - Rebuild the project

## Testing FCM Token

The app will automatically:
- Request notification permissions on first launch
- Retrieve and store the FCM token
- Use the token in OTP verification flows

You can verify the token is working by checking:
- Console logs when the app launches
- UserDefaults key: `FCM_TOKEN`

## Next Steps

After completing setup, you can:
- Send test notifications from Firebase Console
- Implement additional Firebase features (Analytics, Crashlytics, etc.)
- Configure notification handling in your app

## Support

For more information, visit:
- [Firebase iOS Documentation](https://firebase.google.com/docs/ios/setup)
- [Firebase Cloud Messaging Guide](https://firebase.google.com/docs/cloud-messaging/ios/client)

