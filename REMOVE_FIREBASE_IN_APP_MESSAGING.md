# Remove Firebase In-App Messaging

## Steps to Remove from Xcode

### Step 1: Remove Package Dependency

1. **Open Xcode**
2. **Select your project** in the Project Navigator (top item)
3. **Select the project** (not a target) in the main editor
4. Go to **"Package Dependencies"** tab
5. Find **"firebase-ios-sdk"** in the list
6. **Click on it** to expand
7. Look for **"FirebaseInAppMessaging-Beta"** in the products list
8. **Uncheck** "FirebaseInAppMessaging-Beta"
9. Click **"Done"** or wait for Xcode to update

### Step 2: Clean Build

1. **Product** → **Clean Build Folder** (Shift+Cmd+K)
2. **Build** the project again (Cmd+B)

### Step 3: Verify

After removing, the warnings should stop appearing. The app will still work fine with:
- ✅ Firebase Core
- ✅ Firebase Messaging (FCM)
- ✅ Firebase Realtime Database

## Alternative: If Package Removal Doesn't Work

If you can't remove it from Package Dependencies, you can suppress the warnings by adding this to your `Info.plist`:

```xml
<key>FirebaseAppDelegateProxyEnabled</key>
<false/>
```

But this might affect other Firebase features. **Removing the package is the best solution.**

## After Removal

The warnings will disappear and your app will continue to work normally. Firebase In-App Messaging is not needed for your app's functionality.
