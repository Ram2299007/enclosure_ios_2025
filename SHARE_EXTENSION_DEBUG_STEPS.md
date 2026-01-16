# Share Extension Debug Steps - EXACT PROCEDURE

## Current Situation
- ✅ "Enclosure" appears in share sheet
- ❌ No Share Extension logs when tapping it
- ❌ Share Extension doesn't seem to run

## Step-by-Step Debug Procedure

### Step 1: Test with Minimal Share Extension

**Replace ShareViewController.swift temporarily:**

1. **Backup current file:**
   ```bash
   cp EnclosureShareExtension/ShareViewController.swift EnclosureShareExtension/ShareViewController_BACKUP.swift
   ```

2. **Replace with minimal test version:**
   - Use the code from `ShareViewController_TEST.swift`
   - This version does NOTHING except print and show red screen
   - If this doesn't work, the issue is fundamental (signing, Info.plist, etc.)

3. **Build Share Extension:**
   - Scheme → Select "EnclosureShareExtension"
   - Build (Cmd+B)
   - Switch back to "Enclosure" scheme
   - Build and run main app

4. **Test:**
   - Photos → Share → Tap "Enclosure"
   - **Do you see a RED screen?**
     - ✅ **Yes** → Share Extension runs! Issue is in full code
     - ❌ **No** → Share Extension doesn't launch, check crashes

### Step 2: Check Crash Logs (CRITICAL)

**In Xcode:**
1. **Window** → **Devices and Simulators**
2. Select your **device/simulator**
3. Click **"View Device Logs"**
4. Look for **"EnclosureShareExtension"** in the list
5. Check **today's date/time** for crash reports
6. **Open any crash report**
7. **Look for:**
   - **Exception Type** (e.g., EXC_BAD_ACCESS, EXC_CRASH)
   - **Crashed Thread** stack trace
   - **Error messages**

**Share the crash log details** - this will tell us exactly what's wrong!

### Step 3: Use Console.app (macOS)

**This shows ALL system logs, including Share Extensions:**

1. **Open Console.app** on your Mac
2. **In search box**, type: `EnclosureShareExtension`
3. **Clear the log** (to see only new entries)
4. **On device:** Photos → Share → Tap "Enclosure"
5. **Watch Console.app immediately**
6. **Do you see any logs?**
   - ✅ **Yes** → Share Extension runs, logs just not in Xcode
   - ❌ **No** → Share Extension doesn't launch

### Step 4: Verify Info.plist

**Check `EnclosureShareExtension/Info.plist`:**

1. **NSExtensionPointIdentifier** = `com.apple.share-services` ✅
2. **NSExtensionPrincipalClass** = `$(PRODUCT_MODULE_NAME).ShareViewController`
3. **Verify PRODUCT_MODULE_NAME:**
   - Select **EnclosureShareExtension** target
   - **Build Settings** → Search "Product Module Name"
   - Should be: `EnclosureShareExtension`
   - Class name must match: `ShareViewController`

### Step 5: Check Code Signing

**For EnclosureShareExtension target:**
1. **Signing & Capabilities** tab
2. **Team** must be selected (same as main app)
3. **Bundle Identifier** = `com.enclosure.EnclosureShareExtension`
4. **Provisioning Profile** should be valid

**Common Issue:**
- Share Extension not signed → Won't run
- Different team → Won't work

### Step 6: Check Build Phases

**Verify Share Extension is embedded:**

1. Select **Enclosure** target (main app)
2. **Build Phases** tab
3. **Embed App Extensions** section
4. **EnclosureShareExtension.appex** should be listed
5. If missing, add it

### Step 7: Add Breakpoint Test

**Most reliable way to verify:**

1. Open `ShareViewController.swift`
2. Add **breakpoint** on first line:
   ```swift
   override func viewDidLoad() {
       super.viewDidLoad()  // <- Breakpoint here
   ```
3. **Run main app**
4. **Tap "Enclosure" in share sheet**
5. **Does breakpoint hit?**
   - ✅ **Yes** → Extension runs, check why logs don't appear
   - ❌ **No** → Extension doesn't launch, check crashes

## Most Likely Issues

1. **Code Signing** → Extension not signed properly
2. **Info.plist Error** → NSExtensionPrincipalClass doesn't match
3. **Crash on Init** → Exception before viewDidLoad()
4. **Missing Framework** → Extension can't load required framework

## What to Share

Please share:
1. **Crash log** (if any) from Step 2
2. **Console.app output** from Step 3
3. **Breakpoint result** from Step 7
4. **Red screen test result** from Step 1

This will tell us exactly what's wrong!
