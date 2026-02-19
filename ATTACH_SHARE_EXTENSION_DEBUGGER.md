# Attach Share Extension to Debugger

## Problem
Share Extension logs are not appearing because the Share Extension runs in a separate process and needs to be attached to the debugger separately.

## Solution: Attach Share Extension Debugger

### Method 1: Automatic Attachment (Recommended)

1. **In Xcode:**
   - Go to **Product** → **Scheme** → **Edit Scheme...**
   - Select **Run** in the left sidebar
   - Go to **Info** tab
   - Under **"Executable"**, make sure **"Enclosure"** is selected
   - Click **OK**

2. **Add Share Extension to Debug:**
   - Go to **Product** → **Scheme** → **Edit Scheme...** again
   - Click **+** button at the bottom left
   - Select **"EnclosureShareExtension"**
   - Click **OK**
   - Now you should see both **"Enclosure"** and **"EnclosureShareExtension"** in the scheme

3. **Run with Both Targets:**
   - Make sure **"Enclosure"** scheme is selected
   - Build and run the app (Cmd+R)
   - When you tap "Enclosure" in share sheet, Xcode should automatically attach to the Share Extension

### Method 2: Manual Attachment

1. **Run the main app** (Enclosure target)
2. **In Xcode:**
   - Go to **Debug** → **Attach to Process by PID or Name...**
   - Type: `EnclosureShareExtension`
   - Click **Attach**
3. **Now tap "Enclosure" in share sheet**
4. **Check console** - you should see Share Extension logs

### Method 3: Use Console App (macOS)

1. **Open Console.app** on your Mac
2. **Connect your device/simulator**
3. **Filter by:** `EnclosureShareExtension` or `ShareExtension`
4. **Tap "Enclosure" in share sheet**
5. **Check Console.app** for logs

### Method 4: Add Breakpoint

1. **Open `ShareViewController.swift`**
2. **Add a breakpoint** at the first line of `viewDidLoad()`:
   ```swift
   override func viewDidLoad() {
       super.viewDidLoad()  // <- Add breakpoint here
   ```
3. **Run the main app**
4. **Tap "Enclosure" in share sheet**
5. **If breakpoint hits** → Share Extension is running
6. **If breakpoint doesn't hit** → Share Extension is not launching

## Quick Test

**Simplest way to verify Share Extension is running:**

1. Add this at the very top of `viewDidLoad()`:
   ```swift
   override func viewDidLoad() {
       super.viewDidLoad()
       print("🔴🔴🔴 SHARE EXTENSION LOADED 🔴🔴🔴")
       // ... rest of code
   ```

2. Build and run main app
3. Tap "Enclosure" in share sheet
4. Check console for `🔴🔴🔴 SHARE EXTENSION LOADED 🔴🔴🔴`

**If you see this message:**
- ✅ Share Extension is running
- Check why other logs aren't appearing

**If you DON'T see this message:**
- ❌ Share Extension is not running at all
- It might be crashing immediately
- Check for crash logs in Xcode → Window → Devices and Simulators

## Check for Crashes

1. **In Xcode:**
   - **Window** → **Devices and Simulators**
   - Select your device/simulator
   - Click **"View Device Logs"**
   - Look for **"EnclosureShareExtension"** crashes
   - Check crash logs for errors

## Common Issues

**Issue:** Share Extension crashes immediately
- **Check:** Info.plist configuration
- **Check:** Missing dependencies/frameworks
- **Check:** Code signing issues

**Issue:** Share Extension doesn't launch
- **Check:** NSExtensionPrincipalClass matches actual class name
- **Check:** Share Extension target is embedded in main app
- **Check:** Build Phases → Embed App Extensions

**Issue:** Logs appear but in wrong console
- **Solution:** Use Console.app or attach debugger manually
