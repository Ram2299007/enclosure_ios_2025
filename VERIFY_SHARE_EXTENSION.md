# Verify Share Extension is Properly Configured

## Critical Steps to Verify

### 1. Check if Share Extension Target Exists

**In Xcode:**
1. Look at the **Project Navigator** (left sidebar)
2. Find **EnclosureShareExtension** folder
3. It should contain:
   - `ShareViewController.swift`
   - `Info.plist`
   - `EnclosureShareExtension.entitlements`

**If folder doesn't exist:**
- The Share Extension target was never created
- You need to create it manually in Xcode

### 2. Verify Share Extension is Embedded

**In Xcode:**
1. Select **Enclosure** target (main app)
2. Go to **General** tab
3. Scroll to **"Frameworks, Libraries, and Embedded Content"** section
4. Look for **EnclosureShareExtension.appex**
5. It should be listed there

**If NOT listed:**
- The Share Extension is not embedded
- Go to **Build Phases** → **Embed App Extensions**
- Add **EnclosureShareExtension.appex** if missing

### 3. Build Share Extension Separately (MOST IMPORTANT)

**This is the #1 reason Share Extensions don't work!**

**Steps:**
1. In Xcode, click the **Scheme** dropdown (top toolbar, next to device selector)
2. You should see **"EnclosureShareExtension"** in the list
3. **Select "EnclosureShareExtension"** (NOT "Enclosure")
4. Select your device/simulator
5. Press **Cmd+B** to build
6. Wait for build to complete successfully
7. **Switch back to "Enclosure" scheme**
8. Build and run the main app

**Why this is critical:**
- Share Extensions are separate targets
- They must be built before they can be embedded
- Building only the main app doesn't build the extension

### 4. Check Build Settings

**For EnclosureShareExtension target:**
1. Select **EnclosureShareExtension** target
2. Go to **Build Settings**
3. Search for **"Code Signing Entitlements"**
4. Should be: `EnclosureShareExtension/EnclosureShareExtension.entitlements`
5. Search for **"Product Bundle Identifier"**
6. Should be: `com.enclosure.EnclosureShareExtension`

### 5. Verify Info.plist Configuration

**Check `EnclosureShareExtension/Info.plist`:**
- Must have `NSExtensionPointIdentifier` = `com.apple.share-services`
- Must have `NSExtensionPrincipalClass` = `$(PRODUCT_MODULE_NAME).ShareViewController`
- Should have `CFBundleDisplayName` = `Enclosure` (to show in share sheet)

### 6. Test on Device/Simulator

**After building:**
1. **Restart** your device/simulator (important!)
2. Open **Photos** app
3. Select an image
4. Tap **Share** button
5. Scroll through share sheet
6. Look for **"Enclosure"**

**If still not visible:**
- Check **Settings** → **[Your App]** → Look for Share Extension toggle
- Make sure it's enabled
- Some iOS versions require manual enable

### 7. Check Console for Errors

**When you tap "Enclosure" in share sheet:**
- Check Xcode console immediately
- Look for ANY errors or warnings
- Even if Share Extension doesn't run, there might be crash logs

### 8. Verify App Groups (If Extension Appears but Doesn't Work)

**Both targets must have:**
1. **Enclosure** target → **Signing & Capabilities** → **App Groups** → `group.com.enclosure`
2. **EnclosureShareExtension** target → **Signing & Capabilities** → **App Groups** → `group.com.enclosure`

**Both must be signed with the same Team!**

## Quick Diagnostic Checklist

Run through this checklist:

- [ ] Share Extension target exists in Xcode project
- [ ] Share Extension folder contains ShareViewController.swift
- [ ] Share Extension is listed in "Embed App Extensions" build phase
- [ ] Built Share Extension target separately (selected scheme and built)
- [ ] Built main app after building Share Extension
- [ ] Restarted device/simulator after building
- [ ] "Enclosure" appears in Photos share sheet
- [ ] Share Extension is enabled in Settings (if option exists)
- [ ] Console shows Share Extension logs when tapping "Enclosure"

## If Still Not Working

**Share this information:**
1. Do you see "EnclosureShareExtension" in the Scheme dropdown?
2. Can you build the Share Extension target without errors?
3. Does "Enclosure" appear in the Photos share sheet?
4. What happens when you tap "Enclosure" (if it appears)?
5. What do you see in the Xcode console?

## Most Common Issues

1. **Share Extension target never built** → Build it separately first
2. **Share Extension not embedded** → Check Build Phases
3. **Device not restarted** → Restart after building
4. **Share Extension disabled in Settings** → Enable it manually
