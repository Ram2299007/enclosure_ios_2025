# Check Share Extension Crash - Step by Step

## Current Problem
- "Enclosure" appears in share sheet ✅
- No logs in Xcode console ❌
- No logs in Console.app ❌
- **Share Extension is NOT running at all** ❌

## This Means: Share Extension is Crashing Immediately

The Share Extension is crashing before any code executes. We need to find out why.

## Step 1: Check Crash Logs (DO THIS FIRST!)

**In Xcode:**
1. **Window** → **Devices and Simulators**
2. Select your **device/simulator**
3. Click **"View Device Logs"** button
4. Look for **"EnclosureShareExtension"** in the list
5. **Sort by Date** - look for today's crashes
6. **Open any crash report**
7. **Look for:**
   - **Exception Type** (e.g., EXC_BAD_ACCESS, EXC_CRASH, SIGABRT)
   - **Crashed Thread** - shows where it crashed
   - **Exception Message** - shows the error
   - **Stack trace** - shows what code was running

**Share the crash log details** - especially:
- Exception Type
- Exception Message
- First few lines of the stack trace

## Step 2: Verify Code Signing

**Most common issue!**

**For EnclosureShareExtension target:**
1. Select **EnclosureShareExtension** target
2. **Signing & Capabilities** tab
3. Check:
   - ✅ **Team** is selected (same as main app)
   - ✅ **Bundle Identifier** = `com.enclosure.EnclosureShareExtension`
   - ✅ **Provisioning Profile** is valid (not "None")
   - ✅ **Code Signing Entitlements** = `EnclosureShareExtension/EnclosureShareExtension.entitlements`

**If any of these are wrong, the Share Extension won't run!**

## Step 3: Verify Share Extension is Embedded

**Critical - if not embedded, it won't be included!**

**For Enclosure target (main app):**
1. Select **Enclosure** target
2. **Build Phases** tab
3. Look for **"Embed App Extensions"** section
4. **EnclosureShareExtension.appex** MUST be listed
5. If missing:
   - Click **+** button
   - Select **EnclosureShareExtension.appex**
   - Make sure "Code Sign On Copy" is checked

## Step 4: Verify Info.plist Configuration

**Check `EnclosureShareExtension/Info.plist`:**

1. **NSExtensionPointIdentifier** = `com.apple.share-services` ✅
2. **NSExtensionPrincipalClass** = `$(PRODUCT_MODULE_NAME).ShareViewController`

**Verify PRODUCT_MODULE_NAME matches:**
- Select **EnclosureShareExtension** target
- **Build Settings** → Search "Product Module Name"
- Should be: `EnclosureShareExtension`
- So the class should be: `EnclosureShareExtension.ShareViewController`

**If it doesn't match, the Share Extension won't launch!**

## Step 5: Test with Minimal Code

**Replace entire `ShareViewController.swift` with this absolute minimum:**

```swift
import UIKit

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
```

**Build Share Extension target, then test:**
- If this works → Issue is in full code
- If this doesn't work → Fundamental issue (signing/Info.plist)

## Most Common Crash Reasons:

1. **Code Signing Invalid** → Share Extension not signed
2. **Class Name Mismatch** → NSExtensionPrincipalClass doesn't match
3. **Not Embedded** → Share Extension not included in app
4. **Missing Framework** → Share Extension can't load framework
5. **Exception in Init** → Crash before viewDidLoad()

## What to Share:

Please share:
1. **Crash log** (if any) - Exception Type, Message, Stack trace
2. **Code signing status** - Is Team selected? Is Provisioning Profile valid?
3. **Embed status** - Is EnclosureShareExtension.appex in "Embed App Extensions"?
4. **Product Module Name** - What is it set to in Build Settings?

This will help us identify the exact issue!
