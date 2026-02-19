# Share Extension Not Running - Crash Check

## Current Situation
- ✅ "Enclosure" appears in share sheet
- ❌ No Share Extension logs in console
- ❌ Share Extension doesn't seem to run

## This Means:
The Share Extension is likely **crashing immediately** before any code executes, OR it's not being invoked at all.

## Step 1: Check for Crashes

### In Xcode:
1. **Window** → **Devices and Simulators**
2. Select your **device/simulator**
3. Click **"View Device Logs"** button
4. Look for **"EnclosureShareExtension"** in the list
5. Check for **crash reports** with today's date/time
6. Open any crash reports and look for:
   - **Exception Type**
   - **Crashed Thread**
   - **Stack trace**

### What to Look For:
- **"EXC_BAD_ACCESS"** → Memory issue
- **"EXC_CRASH"** → Uncaught exception
- **"Code Signature Invalid"** → Signing issue
- **"Library not loaded"** → Missing framework/dependency

## Step 2: Verify Share Extension Can Launch

### Test 1: Simplest Possible Share Extension

Temporarily replace `ShareViewController.swift` with this minimal version:

```swift
import UIKit

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        print("🔴 MINIMAL SHARE EXTENSION LOADED")
        
        // Just complete immediately
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
```

**If this works:**
- ✅ Share Extension can launch
- Issue is in the full code

**If this doesn't work:**
- ❌ Share Extension has a fundamental issue
- Check Info.plist, code signing, or dependencies

## Step 3: Check Info.plist Configuration

Verify `EnclosureShareExtension/Info.plist`:

1. **NSExtensionPointIdentifier** = `com.apple.share-services` ✅
2. **NSExtensionPrincipalClass** = `$(PRODUCT_MODULE_NAME).ShareViewController`
3. **Check PRODUCT_MODULE_NAME:**
   - Select **EnclosureShareExtension** target
   - **Build Settings** → Search "Product Module Name"
   - Should be something like: `EnclosureShareExtension`
   - The class name in code must match: `ShareViewController`

## Step 4: Check Code Signing

**For EnclosureShareExtension target:**
1. **Signing & Capabilities** tab
2. **Team** should be selected (same as main app)
3. **Bundle Identifier** should be: `com.enclosure.EnclosureShareExtension`
4. **Provisioning Profile** should be valid

**Common Issue:**
- Share Extension not signed → Won't run
- Different team than main app → Won't work

## Step 5: Check Dependencies

**Share Extension might be missing frameworks:**

1. Select **EnclosureShareExtension** target
2. **Build Phases** → **Link Binary With Libraries**
3. Check if these are included:
   - `UIKit.framework` (should be automatic)
   - Any custom frameworks your code uses

**If Share Extension uses Firebase or other frameworks:**
- They must be added to Share Extension target
- Share Extensions have limited access to main app's frameworks

## Step 6: Use Console.app (Most Reliable)

**macOS Console.app shows ALL logs:**

1. **Open Console.app** on your Mac
2. **Connect device/simulator** (if using device)
3. **In search box**, type: `EnclosureShareExtension`
4. **Tap "Enclosure" in share sheet** on device
5. **Watch Console.app** - you should see logs immediately

**If you see logs in Console.app but not Xcode:**
- Xcode console is filtering them out
- Use Console.app for debugging

## Step 7: Add Breakpoint Test

**Most reliable way to verify Share Extension runs:**

1. Open `ShareViewController.swift`
2. Add a **breakpoint** on first line of `viewDidLoad()`:
   ```swift
   override func viewDidLoad() {
       super.viewDidLoad()  // <- Breakpoint here
   ```
3. **Run main app** (Enclosure target)
4. **Tap "Enclosure" in share sheet**
5. **Does breakpoint hit?**
   - ✅ **Yes** → Share Extension runs, issue is in code
   - ❌ **No** → Share Extension doesn't launch, check crashes

## Most Common Issues

1. **Code Signing** → Share Extension not signed properly
2. **Missing Framework** → Share Extension can't load required framework
3. **Info.plist Error** → NSExtensionPrincipalClass doesn't match class name
4. **Crash on Init** → Exception in init() or viewDidLoad()

## Next Steps

1. **Check crash logs** (Step 1) - This will tell us exactly what's wrong
2. **Try minimal Share Extension** (Step 2) - Verify it can launch at all
3. **Use Console.app** (Step 6) - See all logs
4. **Add breakpoint** (Step 7) - Verify it's being invoked

**Share the crash log or Console.app output** and we can fix the exact issue!
