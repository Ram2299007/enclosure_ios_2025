# App Group Setup Guide for Share Extension

## Problem
The Share Extension cannot share data with the main app because the App Group is not configured.

## Solution: Configure App Group in Xcode

### Step 1: Configure App Group for Main App (Enclosure)

1. Open your project in Xcode
2. Select the **Enclosure** target (main app)
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability** button at the top left
5. Search for and select **App Groups**
6. Click **+** button next to "App Groups"
7. Enter: `group.com.enclosure`
8. Press Enter to confirm

### Step 2: Configure App Group for Share Extension

1. Select the **EnclosureShareExtension** target
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability** button at the top left
4. Search for and select **App Groups**
5. Click **+** button next to "App Groups"
6. Enter: `group.com.enclosure` (same as main app)
7. Press Enter to confirm

### Step 3: Verify Configuration

Both targets should now show:
- ✅ App Groups capability
- ✅ `group.com.enclosure` listed

### Step 4: Clean and Rebuild

1. In Xcode: **Product** → **Clean Build Folder** (Shift+Cmd+K)
2. Build the project again
3. Run the app on a device or simulator

### Step 5: Test Share Extension

1. Open Photos app
2. Select an image
3. Tap Share button
4. Look for "Enclosure" in the share sheet
5. If you see it, tap it
6. Check Xcode console for logs:
   - `📤 [ShareExtension] viewDidLoad called`
   - `✅ [ShareExtension] App Group UserDefaults accessible`
   - `📤 [ShareExtension] Saving shared content...`

## Troubleshooting

### If Share Extension doesn't appear in share sheet:

1. Make sure you've built the Share Extension target at least once
2. Go to **Settings** → **[Your App Name]** → Check if Share Extension is enabled
3. Restart the device/simulator

### If you see "App Group UserDefaults is nil":

1. Verify both targets have App Groups capability
2. Verify both use the same group ID: `group.com.enclosure`
3. Make sure both targets are signed with the same Team/Developer account
4. Clean build folder and rebuild

### If Share Extension shows "Error: App Group not configured":

The App Group capability is missing. Follow Step 1 and Step 2 above.

## Important Notes

- The App Group ID must be **exactly the same** in both targets
- Both targets must be signed with the same Team
- The App Group ID format: `group.<bundle-id>` (e.g., `group.com.enclosure`)
- After configuring, you must clean and rebuild the project
