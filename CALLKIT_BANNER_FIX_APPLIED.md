# CRITICAL FIX: CallKit Full-Screen UI Instead of Banner

## Problem

User reported: *"notification detected but not it is in standard rich design like whatsapp call notification mean left side circular and small app icon and right side horizontal dismiss and accept button"*

**Translation:** The notification was showing as a **standard iOS banner** (like chat messages) instead of the **CallKit full-screen UI** (like WhatsApp/FaceTime calls with large circular image, Accept/Decline buttons).

## Root Cause #1: Async Timing Issue

```swift
// ❌ WRONG - CallKit triggered AFTER willPresent returns
DispatchQueue.main.async {
    appDelegate.application(UIApplication.shared, didReceiveRemoteNotification:...) {
        // CallKit triggered here - TOO LATE!
    }
}
completionHandler([]) // iOS shows banner before CallKit runs
```

**Problem:** We were using `DispatchQueue.main.async` to forward to AppDelegate, which meant:
1. `completionHandler([])` was called immediately
2. iOS showed the banner while we waited for the async block
3. CallKit was triggered later, showing on top of the banner

## Root Cause #2: Detection Methods

The notification might not be detected correctly if we only check `bodyKey`. For user-visible notifications, we need to check:
1. `bodyKey` in data payload
2. `notification.request.content.body` (alert body)
3. `notification.request.content.categoryIdentifier` (VOICE_CALL/VIDEO_CALL)

## Fixes Applied

### Fix 1: Direct CallKit Triggering (NotificationDelegate.swift)

**Changed:** Trigger CallKit **synchronously** in `willPresent` BEFORE returning to iOS

```swift
// ✅ CORRECT - CallKit triggered IMMEDIATELY
// Extract call data
let callerName = (userInfo["name"] as? String) ?? "Unknown"
let roomId = (userInfo["roomId"] as? String) ?? ""

// Report to CallKit SYNCHRONOUSLY (not async!)
CallKitManager.shared.reportIncomingCall(...) { error in
    if error == nil {
        print("✅ CallKit full-screen UI is now showing")
    }
}

// NOW suppress the banner
completionHandler([]) // CallKit UI already visible
```

**Result:** CallKit full-screen UI appears BEFORE iOS tries to show a banner

### Fix 2: Triple Detection Method (NotificationDelegate.swift)

```swift
let bodyKey = userInfo["bodyKey"] as? String
let alertBody = notification.request.content.body
let category = notification.request.content.categoryIdentifier

// Check THREE ways to detect call notifications
let isVoiceCall = bodyKey == "Incoming voice call" || 
                  alertBody == "Incoming voice call" || 
                  category == "VOICE_CALL"
```

**Result:** Call notifications are detected reliably regardless of payload structure

### Fix 3: Notification Service Extension Logging (NotificationService.swift)

Added detection and logging for call notifications in the extension:

```swift
if bodyKey == "Incoming voice call" || category == "VOICE_CALL" {
    NSLog("📞📞📞 [NotificationService] CALL NOTIFICATION DETECTED!")
    NSLog("📞 [NotificationService] Passing to main app - CallKit will handle UI")
    contentHandler(bestAttemptContent)
    return
}
```

**Result:** We can see in logs if the extension detects call notifications

## Expected Behavior Now

### When Voice/Video Call Notification Arrives (App in Foreground):

1. **Notification Service Extension** detects it (logs: `📞📞📞 CALL NOTIFICATION DETECTED`)
2. **NotificationDelegate.willPresent** called immediately:
   ```
   🚨🚨🚨 [NotificationDelegate] VOICE CALL DETECTED IN FOREGROUND!
   📞 [NotificationDelegate] Triggering CallKit IMMEDIATELY...
   📞 [NotificationDelegate] Call data: caller='John Doe', room='abc123'
   ```
3. **CallKit** reports incoming call (logs: `✅ [CallKit] Successfully reported incoming call`)
4. **CallKit Full-Screen UI appears** (like WhatsApp):
   - Large circular caller photo (if available)
   - Caller name at top
   - Green "Accept" button
   - Red "Decline" button
   - Native iOS call interface
5. **Banner suppressed** (logs: `📞 [NotificationDelegate] Suppressing banner - CallKit UI active`)

### When User Taps "Accept":

```
📞 [CallKit] User answered call: <UUID>
📞 [CallKit] User answered call - Room: abc123
```
- Notification posted: `AnswerIncomingCall`
- App navigates to voice/video call screen

### When User Taps "Decline":

```
📞 [CallKit] User ended call: <UUID>
📞 [CallKit] User declined call - Room: abc123
```
- Call is ended
- Server can be notified of declined call

## Files Modified

1. **Enclosure/Utility/NotificationDelegate.swift**
   - Lines 38-43: Added triple detection (bodyKey, alertBody, category)
   - Lines 56-107: Direct CallKit triggering (not async)
   - Lines 108-110: Banner suppression

2. **EnclosureNotificationService/NotificationService.swift**
   - Lines 56-66: Call notification detection and logging

## Testing Instructions

1. **Rebuild the app** (clean build recommended):
   ```bash
   Product > Clean Build Folder (Cmd+Shift+K)
   Product > Build (Cmd+B)
   ```

2. **Install on device** (must test on real device, not simulator)

3. **Open app and keep it in foreground**

4. **Send voice call notification** from Android backend

5. **Expected result:**
   - ✅ **NO** standard banner notification
   - ✅ **YES** CallKit full-screen UI (like WhatsApp)
   - ✅ Large circular image area (uses caller photo if available)
   - ✅ Green "Accept" and Red "Decline" buttons
   - ✅ Native iOS ringtone (if CallKit ringtone configured)

6. **Check Console.app logs** for:
   ```
   📞📞📞 [NotificationService] CALL NOTIFICATION DETECTED!
   🚨🚨🚨 [NotificationDelegate] VOICE CALL DETECTED IN FOREGROUND!
   📞 [NotificationDelegate] Triggering CallKit IMMEDIATELY...
   ✅ [CallKit] Successfully reported incoming call
   📞 [NotificationDelegate] Suppressing banner - CallKit UI active
   ```

## Comparison: Banner vs CallKit UI

### ❌ Banner Notification (OLD - What user was seeing):
- Small notification at top of screen
- App icon on left (small)
- Short text preview
- "X" dismiss button
- Tap to open app
- **Not optimized for calls**

### ✅ CallKit Full-Screen UI (NEW - What user should see now):
- **Full-screen takeover** (like native phone app)
- **Large circular photo area** (center of screen)
- **Caller name prominently displayed**
- **Two large horizontal buttons:**
  - 🟢 **Accept** (green, left or bottom)
  - 🔴 **Decline** (red, right or bottom)
- **Native ringtone** and vibration
- **Shows on lock screen** with same UI
- **Integrated with CarPlay, Bluetooth headsets**
- **Matches WhatsApp/FaceTime/Phone app UI**

## Fallback if Still Showing Banner

If you still see a banner instead of CallKit UI after this fix, check:

1. **Is CallKit permission granted?**
   - No explicit permission needed for CallKit
   - But check `Info.plist` has `UIBackgroundModes` with `voip`
   - ✅ Already configured (verified line 173)

2. **Check logs in Console.app** - Look for:
   - ❌ `Could not get AppDelegate!` → App not properly initialized
   - ❌ `Missing roomId` → Backend not sending roomId
   - ❌ `CallKit error:` → CallKit report failed

3. **Verify backend payload** includes:
   ```json
   {
     "bodyKey": "Incoming voice call",
     "name": "Caller Name",
     "photo": "https://...",
     "roomId": "abc123",
     "receiverId": "user123",
     "phone": "+1234567890",
     "aps": {
       "alert": {
         "title": "Enclosure",
         "body": "Incoming voice call"
       },
       "category": "VOICE_CALL",
       "sound": "default"
     }
   }
   ```

## Long-Term Recommendation: VoIP Push Notifications

For **production**, migrate to **VoIP Push Notifications** (PushKit):

### Why VoIP Pushes Are Better:
1. **No banner ever** - Only CallKit UI shows
2. **Higher priority** - Delivered even if app is terminated
3. **Instant delivery** - Wake app immediately
4. **Battery optimized** - iOS handles efficiently
5. **Apple recommended** for call apps

### How to Implement (Future Task):
1. Add `PushKit` framework to app
2. Register for VoIP pushes: `PKPushRegistry`
3. Backend sends to APNs VoIP endpoint (not FCM)
4. Handle in `pushRegistry(_:didReceiveIncomingPushWith:for:completion:)`
5. Report to CallKit directly

See: `CRITICAL_BACKEND_NOTIFICATION_ISSUE.md` for full VoIP implementation guide

---

**Status**: ✅ READY TO TEST

**Priority**: HIGH - This fix makes call notifications work like WhatsApp

**Expected Impact**: CallKit full-screen UI will replace standard banner notifications
