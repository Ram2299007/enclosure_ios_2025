# CRITICAL FIX: Notification Delegate Conflict Resolved

## Problem Found in iOS Logs (08:19:46)

The backend fix worked! The notification now arrives as a **user-visible notification** (not silent push):
- ✅ `hasAlertContent: 1`
- ✅ `categoryIdentifier: VOICE_CALL`
- ✅ `contentAvailable: NO` (no more content-available)
- ✅ `apns-push-type: alert`

BUT the notification was going to the **wrong delegate**!

### Root Cause

**TWO classes were competing to be the `UNUserNotificationCenter` delegate:**

1. **FirebaseManager** (line 98):
   ```swift
   UNUserNotificationCenter.current().delegate = self
   ```
   - Its `willPresent` method just shows banner/sound/badge
   - **Does NOT check for voice calls**
   - **Does NOT trigger CallKit**

2. **NotificationDelegate.shared** (AppDelegate line 47):
   ```swift
   UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
   ```
   - **HAS the voice call detection code**
   - **Forwards to CallKit**
   - BUT was being overridden by FirebaseManager!

### Evidence from Logs

```
info 08:19:46.171415+0530 Enclosure Decode <UIWillPresentNotificationAction: 0x0023780c>
debug 08:19:46.173316+0530 Enclosure respondToActions unhandled action:<UIWillPresentNotificationAction...>

Stack trace:
6   Enclosure   FirebaseManager.userNotificationCenter(_:willPresent:withCompletionHandler:)
7   Enclosure   FCMSwizzleWillPresentNotificationWithHandler
```

The notification reached `FirebaseManager.willPresent` instead of `NotificationDelegate.willPresent`!

## Fix Applied

### 1. Removed FirebaseManager as Delegate (FirebaseManager.swift line 98)

**BEFORE:**
```swift
func requestNotificationPermissions() {
    UNUserNotificationCenter.current().delegate = self  // ❌ WRONG - overrides NotificationDelegate
```

**AFTER:**
```swift
func requestNotificationPermissions() {
    // CRITICAL: Do NOT set self as delegate here!
    // NotificationDelegate.shared is already set in AppDelegate.didFinishLaunchingWithOptions
    // UNUserNotificationCenter.current().delegate = self  // ✅ REMOVED
```

### 2. Commented Out FirebaseManager's willPresent Method (FirebaseManager.swift line 261)

**BEFORE:**
```swift
func userNotificationCenter(_ center: UNUserNotificationCenter,
                            willPresent notification: UNNotification,
                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([[.banner, .sound, .badge]])  // ❌ Doesn't check for calls
}
```

**AFTER:**
```swift
// CRITICAL: willPresent is NO LONGER USED because FirebaseManager is NOT set as the delegate
// NotificationDelegate.shared is the delegate (set in AppDelegate.didFinishLaunchingWithOptions)
// NotificationDelegate handles call notifications specially and forwards them to CallKit
/* COMMENTED OUT */
```

## Expected Behavior Now

1. **NotificationDelegate.shared** is the ONLY delegate
2. When a voice/video call notification arrives:
   - `NotificationDelegate.willPresent` detects `bodyKey == "Incoming voice call"`
   - Forwards to `AppDelegate.application(_:didReceiveRemoteNotification:fetchCompletionHandler:)`
   - Calls `completionHandler([])` to suppress banner (CallKit provides UI)
3. **CallKit full-screen UI should appear**

## Testing Instructions

1. **Rebuild the app** (clean build recommended)
2. **Send a voice call notification** from the Android backend
3. **Check iOS logs** in Console.app for:
   ```
   🚨🚨🚨 [NotificationDelegate] VOICE CALL DETECTED IN FOREGROUND!
   📞 [NotificationDelegate] This is a USER-VISIBLE notification
   ✅ [NotificationDelegate] Forwarded to AppDelegate.didReceiveRemoteNotification
   📲 [AppDelegate] Suppressing banner - CallKit will show full-screen UI
   ```
4. **Verify CallKit UI appears** (full-screen incoming call interface)

## Files Modified

1. `/Users/ramlohar/XCODE_PROJECT/enclosure_ios_2025/Enclosure/Utility/FirebaseManager.swift`
   - Line 98: Removed `UNUserNotificationCenter.current().delegate = self`
   - Line 261-266: Commented out `willPresent` method

## Why This Fix Works

- **Single Delegate**: Only `NotificationDelegate` handles foreground notifications
- **Voice Call Detection**: NotificationDelegate has the logic to detect and handle calls
- **CallKit Integration**: Properly forwards call notifications to CallKit
- **No Banner Interference**: Suppresses default banner to let CallKit take over

## Related Files (No Changes Needed)

- `NotificationDelegate.swift` - Already has correct call handling
- `AppDelegate.swift` - Already sets NotificationDelegate as delegate
- Android Backend - Already sending correct payload (user-visible notification)

---

**Status**: ✅ READY TO TEST

**Next Step**: Rebuild app and test incoming voice call
