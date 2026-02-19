# Share Extension Logs Not Appearing - Debugging Guide

## Current Status
✅ Share Extension IS running (confirmed in Console.app logs)
✅ View controller IS being instantiated (`Set materialized view controller: <EnclosureShareExtension.ShareViewController>`)
❌ Our custom logs (`📤 INIT CALLED`, `🔴 viewDidLoad`, etc.) are NOT appearing
❌ Extension completes in < 1 second (too fast - suggests code isn't running)

## What I've Done
1. ✅ Added `NSLog` logging (more reliable than `print` for extensions)
2. ✅ Added `fputs` to `stderr` (most reliable for extensions)
3. ✅ Added logging in `init(nibName:)`, `init(coder:)`, `awakeFromNib()`, `viewDidLoad()`, `viewWillAppear()`, `viewDidAppear()`
4. ✅ Added logging in `processSharedItems()`, `openMainApp()`, `completeRequest()`

## Next Steps

### 1. Rebuild Everything
1. **Clean Build Folder:**
   - Product → Clean Build Folder (Shift+Cmd+K)

2. **Build Share Extension:**
   - Select **EnclosureShareExtension** scheme
   - Press **Cmd+B** to build
   - Wait for successful build

3. **Build Main App:**
   - Select **Enclosure** scheme
   - Build and run

### 2. Test and Check Console.app
1. **Open Console.app** on your Mac
2. **In search box**, type: `EnclosureShareExtension`
3. **Clear the log** (to see only new entries)
4. **On device:** Photos → Share → Tap "Enclosure"
5. **Watch Console.app immediately**

### 3. Look For These Logs
You should see logs with these prefixes:
- `🔴🔴🔴 [ShareExtension] INIT(coder) CALLED` (if loaded from storyboard)
- `🔴🔴🔴 [ShareExtension] INIT(nibName) CALLED` (if loaded programmatically)
- `🔴🔴🔴 [ShareExtension] awakeFromNib CALLED` (if using storyboard)
- `🔴🔴🔴🔴🔴 SHARE EXTENSION viewDidLoad CALLED`
- `🔴 [ShareExtension] viewWillAppear CALLED`
- `🔴 [ShareExtension] viewDidAppear CALLED`
- `🔴🔴🔴 [ShareExtension] processSharedItems CALLED`
- `🔴🔴🔴 [ShareExtension] openMainApp CALLED`
- `🔴 [ShareExtension] completeRequest CALLED`

## If You Still Don't See Logs

This could mean:
1. **iOS is using SLComposeViewController** - The native share sheet wraps our view controller
2. **Storyboard is interfering** - iOS might be loading the view controller differently
3. **Logs are filtered** - Make sure Console.app shows all logs

## What to Share

After testing, please share:
1. **Any logs from Console.app** that start with `🔴` or `📤`
2. **What you see** when you tap "Enclosure" in the share sheet:
   - Native iOS share sheet UI?
   - Custom black screen with "Processing..."?
   - Nothing (immediately closes)?

The extension is definitely running - we just need to see where our code is executing (or not executing)!
