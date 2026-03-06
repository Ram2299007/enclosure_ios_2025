# Share Extension Not Running - Fix Guide

## Problem
No `📤 [ShareExtension]` logs appear in console, meaning the Share Extension is not executing at all.

## Root Cause
The Share Extension is either:
1. Not appearing in the share sheet
2. Not built/installed
3. Not enabled in iOS Settings

## Step-by-Step Fix

### Step 1: Verify Share Extension Target Exists

**In Xcode:**
1. Open your project
2. Look at the left sidebar (Project Navigator)
3. You should see **EnclosureShareExtension** folder/target
4. If you DON'T see it, the Share Extension target doesn't exist → Go to Step 2
5. If you DO see it → Go to Step 3

### Step 2: Build Share Extension Target (CRITICAL)

**This is the most common issue!**

1. In Xcode, click the **Scheme** dropdown (next to Play/Stop buttons at top)
2. Select **EnclosureShareExtension** (not "Enclosure")
3. Select a device or simulator
4. Click **Product** → **Build** (Cmd+B)
5. Wait for build to complete
6. **IMPORTANT:** Now switch back to **Enclosure** scheme
7. Build and run the main app again

**Why this matters:**
- Share Extensions must be built separately
- They're embedded in the main app, but need to be compiled first
- If you only build the main app, the extension might not be included

### Step 3: Verify Share Extension Appears in Share Sheet

**Test:**
1. Open **Photos** app
2. Select an image
3. Tap **Share** button (bottom left)
4. Scroll through the share sheet
5. **Look for "Enclosure"** in the list

**If "Enclosure" is NOT visible:**
- The Share Extension is not installed
- Go back to Step 2 and build the Share Extension target
- Restart your device/simulator
- Rebuild the main app

**If "Enclosure" IS visible:**
- Continue to Step 4

### Step 4: Enable Share Extension in Settings (iOS)

**On Device/Simulator:**
1. Open **Settings** app
2. Scroll down and find your app name (e.g., "Enclosure")
3. Tap on it
4. Look for **"Share Extension"** or **"EnclosureShareExtension"**
5. Make sure it's **enabled/toggled ON**

**Note:** This step might not be necessary on all iOS versions, but check if the option exists.

### Step 5: Test Share Extension

**After completing Steps 1-4:**
1. Open **Photos** app
2. Select an image
3. Tap **Share**
4. Tap **"Enclosure"** in the share sheet
5. **Check Xcode console immediately**

**You should see:**
```
📤 [ShareExtension] viewDidLoad called
✅ [ShareExtension] App Group UserDefaults accessible
📤 [ShareExtension] Processing shared items...
```

**If you still see NO logs:**
- The Share Extension is crashing immediately
- Check Xcode console for crash logs
- Verify Info.plist is correct
- Check if there are any build errors

### Step 6: Verify Build Configuration

**In Xcode:**
1. Select **EnclosureShareExtension** target
2. Go to **Build Settings**
3. Search for **"Product Bundle Identifier"**
4. It should be something like: `com.enclosure.EnclosureShareExtension`
5. Make sure it's different from main app bundle ID

**Check General Tab:**
1. Select **EnclosureShareExtension** target
2. Go to **General** tab
3. Under **"Embedded Binaries"** or **"Frameworks, Libraries, and Embedded Content"**
4. Verify the extension is properly embedded

### Step 7: Clean and Rebuild

**If nothing works:**
1. In Xcode: **Product** → **Clean Build Folder** (Shift+Cmd+K)
2. Close Xcode
3. Delete `DerivedData` folder:
   - In Xcode: **Preferences** → **Locations** → Click arrow next to DerivedData path
   - Delete the folder for your project
4. Reopen Xcode
5. Build **EnclosureShareExtension** target first
6. Then build and run **Enclosure** target
7. Test again

## Quick Checklist

- [ ] Share Extension target exists in Xcode
- [ ] Share Extension target has been built at least once
- [ ] Main app has been built after building Share Extension
- [ ] Device/Simulator has been restarted
- [ ] "Enclosure" appears in Photos share sheet
- [ ] Share Extension is enabled in Settings (if option exists)
- [ ] No build errors in Share Extension target
- [ ] Console shows Share Extension logs when tapping "Enclosure"

## Most Common Issue

**90% of the time, the issue is Step 2:**
- The Share Extension target hasn't been built separately
- You need to select "EnclosureShareExtension" scheme and build it
- Then switch back to "Enclosure" scheme and build/run

## Still Not Working?

If after all these steps you still don't see Share Extension logs:

1. **Check Xcode console for ANY errors** when you tap "Enclosure" in share sheet
2. **Verify Info.plist** is correct (NSExtensionPointIdentifier = com.apple.share-services)
3. **Check if Share Extension crashes** - look for crash logs in Xcode
4. **Share the exact steps you took** and what you see in console

## Expected Behavior

When working correctly:
1. Tap "Enclosure" in share sheet
2. See "Processing..." screen briefly
3. App opens automatically
4. Console shows Share Extension logs
5. ShareExternalDataScreen appears
