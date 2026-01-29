# How to Register App Group in Apple Developer Portal

## Step-by-Step Instructions

### Step 1: Go to Apple Developer Portal
1. Open your web browser
2. Go to: https://developer.apple.com/account
3. Sign in with your Apple Developer account

### Step 2: Navigate to App Groups
1. Click on **"Certificates, Identifiers & Profiles"** (left sidebar)
2. Click on **"Identifiers"** (left sidebar)
3. Click on **"App Groups"** (under Identifiers section)
4. Click the **"+"** button (top left) to create a new App Group

### Step 3: Register the App Group
1. **Description**: Enter "Enclosure App Group" (or any description)
2. **Identifier**: Enter `group.com.enclosure` (must match exactly)
3. Click **"Continue"**
4. Review the details
5. Click **"Register"**

### Step 4: Configure App IDs (if needed)
1. Go back to **"Identifiers"**
2. Click on **"App IDs"**
3. Find and select your main app: `com.enclosure`
4. Click **"Edit"**
5. Scroll down to **"App Groups"** capability
6. Check the box next to `group.com.enclosure`
7. Click **"Save"**

### Step 5: Configure Share Extension App ID
1. Still in **"App IDs"**
2. Find and select: `com.enclosure.EnclosureShareExtension`
   - If it doesn't exist, create it:
     - Click **"+"** button
     - Description: "Enclosure Share Extension"
     - Bundle ID: `com.enclosure.EnclosureShareExtension`
     - Capabilities: Check "App Groups"
     - Click "Continue" → "Register"
3. Click **"Edit"**
4. Scroll to **"App Groups"**
5. Check the box next to `group.com.enclosure`
6. Click **"Save"**

### Step 6: Return to Xcode
1. Open Xcode
2. Select **Enclosure** target
3. Go to **Signing & Capabilities** tab
4. Click **"+" Capability** → **App Groups**
5. Click **"+"** next to App Groups
6. Select `group.com.enclosure` from the dropdown (it should now appear)
7. Repeat for **EnclosureShareExtension** target

### Step 7: Clean and Rebuild
1. **Product** → **Clean Build Folder** (Shift+Cmd+K)
2. **Product** → **Build** (Cmd+B)

## Troubleshooting

### If App Group still doesn't appear:
1. Wait 5-10 minutes (Apple's servers need to sync)
2. In Xcode: **Xcode** → **Preferences** → **Accounts**
3. Select your Apple ID
4. Click **"Download Manual Profiles"**
5. Try again

### If you get "No profiles found":
1. Make sure both App IDs are registered:
   - `com.enclosure`
   - `com.enclosure.EnclosureShareExtension`
2. Make sure both have App Groups capability enabled
3. In Xcode, make sure **"Automatically manage signing"** is checked
4. Select the correct **Team** for both targets
