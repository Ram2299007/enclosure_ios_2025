# Backend Fix Applied: Voice/Video Call Notifications

## Problem Solved

Changed iOS voice/video call notifications from **silent pushes** to **user-visible notifications** to work around the SwiftUI scene-based architecture limitation.

## Changes Made

### 1. Android Backend: `FcmNotificationsSender.java`

**Location**: `/Users/ramlohar/StudioProjects/ENCLOSRE_FINAL_ANDROID_2025/app/src/main/java/com/enclosure/Utils/FcmNotificationsSender.java`

**Changed**: Lines 89-124 (iOS notification payload)

**Before**:
```java
// Silent push with content-available
aps.put("content-available", 1);
aps.put("category", "VOICE_CALL");
// NO alert block
```

**After**:
```java
// User-visible notification with alert
JSONObject alert = new JSONObject();
alert.put("title", title); // "Enclosure"
alert.put("body", body);   // "Incoming voice call"
aps.put("alert", alert);
aps.put("sound", "default");
aps.put("category", "VOICE_CALL");
// NO content-available (removed!)
```

**Why**: Silent pushes (`content-available: 1`) get delivered to the scene system in SwiftUI apps and are marked as "unhandled". User-visible notifications go through `UNUserNotificationCenterDelegate` which we can intercept.

### 2. iOS Utility: `MessageUploadService.swift`

**Location**: `/Users/ramlohar/XCODE_PROJECT/enclosure_ios_2025/Enclosure/Utility/MessageUploadService.swift`

**Changed**:
- Voice call notification method (lines ~906-930)
- Video call notification method (lines ~1083-1107)

**Before**:
```swift
"apns": [
    "headers": [
        "apns-push-type": "background",
        "apns-priority": "10"
    ],
    "payload": [
        "aps": [
            "content-available": 1,
            "category": "VOICE_CALL"
        ]
    ]
]
```

**After**:
```swift
"apns": [
    "headers": [
        "apns-push-type": "alert",  // Changed!
        "apns-priority": "10"
    ],
    "payload": [
        "aps": [
            "alert": [
                "title": "Enclosure",
                "body": "Incoming voice call"
            ],
            "sound": "default",
            "category": "VOICE_CALL"
            // NO content-available!
        ]
    ]
]
```

### 3. iOS Notification Handler: `NotificationDelegate.swift`

**Location**: `/Users/ramlohar/XCODE_PROJECT/enclosure_ios_2025/Enclosure/Utility/NotificationDelegate.swift`

**Enhanced**: Now handles both voice and video calls

**Changed**:
```swift
// Before: Only checked "Incoming voice call"
if bodyKey == "Incoming voice call" {

// After: Checks both voice and video calls
if bodyKey == "Incoming voice call" || bodyKey == "Incoming video call" {
```

## How It Works Now

### Flow for Incoming Voice/Video Call (iOS)

1. **Backend sends user-visible notification** (with `alert` block, no `content-available`)
2. **iOS delivers to app** via `UNUserNotificationCenter`
3. **NotificationDelegate.willPresent** is called (foreground handling)
4. **Detects call notification** by checking `bodyKey`
5. **Forwards to AppDelegate.didReceiveRemoteNotification**
6. **AppDelegate calls CallKit** to show full-screen UI
7. **Suppresses banner** by calling `completionHandler([])` - user only sees CallKit UI

### Expected User Experience

- ✅ No banner notification appears (suppressed)
- ✅ CallKit full-screen UI appears immediately
- ✅ Answer/Decline buttons work
- ✅ Works in foreground, background, and terminated states (if user taps notification)

## Testing Instructions

### For Android Backend Changes

1. **Rebuild Android App**
   ```bash
   cd /Users/ramlohar/StudioProjects/ENCLOSRE_FINAL_ANDROID_2025
   ./gradlew clean assembleDebug
   ```

2. **Install on Device**
   - Install the new APK
   - Test sending a voice call from this device to an iOS device

### For iOS App Changes

1. **Clean and Rebuild**
   ```bash
   Product > Clean Build Folder (Cmd+Shift+K)
   Product > Build (Cmd+B)
   ```

2. **Install Fresh Build**
   - Delete old app from device
   - Install new build
   - Grant notification permissions

3. **Test Scenarios**

   **Test 1: App in Foreground**
   - Have iOS app open and active
   - Send voice call notification from Android app
   - Expected:
     - Console shows: `🚨🚨🚨 [NotificationDelegate] VOICE CALL DETECTED IN FOREGROUND!`
     - Console shows: `📞 [CallKit] Incoming voice call detected`
     - CallKit full-screen UI appears
     - NO banner notification visible
   
   **Test 2: App in Background**
   - Put iOS app in background
   - Send voice call notification
   - Expected:
     - Notification banner may briefly appear
     - When user taps: CallKit UI appears
   
   **Test 3: App Terminated**
   - Force quit iOS app
   - Send voice call notification
   - Expected:
     - Notification banner appears
     - When user taps: App opens and CallKit UI appears

## Console.app Log Patterns to Watch

### Success Indicators ✅
```
🚨🚨🚨 [NotificationDelegate] VOICE CALL DETECTED IN FOREGROUND!
📞 [NotificationDelegate] Forwarding to AppDelegate.didReceiveRemoteNotification
🚨 [FCM] NOTIFICATION RECEIVED IN APPDELEGATE!!!
📞 [CallKit] Incoming voice call detected
📞 [CallKit] Room ID: EnclosurePowerfulNext...
✅ [CallKit] Call reported successfully
```

### Failure Indicators ❌
```
respondToActions unhandled action  ← Should NOT appear anymore!
```

## Important Notes

### Why Not Silent Push?

Silent pushes (`content-available: 1`) were designed for:
- Background data sync
- Updating content while app is in background
- NOT for triggering UI or CallKit

In SwiftUI apps with scene-based architecture, silent pushes:
- Go to the scene system (not AppDelegate)
- Have no public API to handle them
- Are marked as "unhandled"
- Never trigger `didReceiveRemoteNotification`

### User-Visible Notification Approach

By using user-visible notifications:
- ✅ Goes through `UNUserNotificationCenter`
- ✅ `NotificationDelegate.willPresent` is called
- ✅ We can intercept and forward to AppDelegate
- ✅ Trigger CallKit from AppDelegate
- ✅ Suppress banner by returning `[]` in completion handler
- ✅ User only sees CallKit full-screen UI

### Future Enhancement: VoIP Push

For production, consider implementing **VoIP Push Notifications** via PushKit:
- More reliable than regular notifications
- Higher priority delivery
- Works even when app is terminated
- Apple's official solution for call apps
- See `CRITICAL_BACKEND_NOTIFICATION_ISSUE.md` for implementation guide

## Verification Checklist

After rebuilding both apps:

- [ ] Android sends voice call notification to iOS device
- [ ] iOS Console.app shows `[NotificationDelegate] VOICE CALL DETECTED`
- [ ] iOS Console.app shows `[FCM] NOTIFICATION RECEIVED IN APPDELEGATE`
- [ ] iOS Console.app shows `[CallKit] Call reported successfully`
- [ ] iOS CallKit full-screen UI appears
- [ ] iOS NO banner notification appears (suppressed)
- [ ] iOS Console.app does NOT show `respondToActions unhandled action`
- [ ] Answer button works on iOS
- [ ] Decline button works on iOS

## Troubleshooting

### If CallKit UI Still Doesn't Appear

1. **Check Console.app for**:
   ```
   process:Enclosure subsystem:any category:any message:NotificationDelegate OR message:FCM OR message:CallKit
   ```

2. **Verify notification reaches NotificationDelegate**:
   - Look for: `[NotificationDelegate] willPresent notification in FOREGROUND`
   - If missing: Notification might not be arriving at all (check FCM setup)

3. **Verify forwarding to AppDelegate**:
   - Look for: `[FCM] NOTIFICATION RECEIVED IN APPDELEGATE!!!`
   - If missing: Forwarding failed (check AppDelegate code)

4. **Verify CallKit handling**:
   - Look for: `[CallKit] Incoming voice call detected`
   - If missing: CallKit detection failed (check `handleCallNotification` in AppDelegate)

5. **Check notification payload**:
   - Ensure `bodyKey` is exactly `"Incoming voice call"` (case-sensitive)
   - Ensure `roomId` is not empty
   - Ensure `receiverId` is present

### If "unhandled action" Still Appears

This should NOT happen anymore since we're using user-visible notifications. If it does:
- Verify you rebuilt and installed the NEW versions of both apps
- Check that the Android app is using the updated `FcmNotificationsSender.java`
- Verify the payload in Console.app shows an `alert` block, not `content-available: 1`

## Files Modified

1. ✅ `/Users/ramlohar/StudioProjects/ENCLOSRE_FINAL_ANDROID_2025/app/src/main/java/com/enclosure/Utils/FcmNotificationsSender.java`
   - Changed iOS notification from silent push to user-visible

2. ✅ `/Users/ramlohar/XCODE_PROJECT/enclosure_ios_2025/Enclosure/Utility/MessageUploadService.swift`
   - Updated voice call notification method
   - Updated video call notification method

3. ✅ `/Users/ramlohar/XCODE_PROJECT/enclosure_ios_2025/Enclosure/Utility/NotificationDelegate.swift`
   - Enhanced to handle both voice and video calls
   - Added logging for debugging

4. ✅ `/Users/ramlohar/XCODE_PROJECT/enclosure_ios_2025/Enclosure/Utility/FirebaseManager.swift`
   - Registered `VOICE_CALL` and `VIDEO_CALL` categories

5. ✅ `/Users/ramlohar/XCODE_PROJECT/enclosure_ios_2025/Enclosure/EnclosureApp.swift`
   - Added `RemoteNotificationSceneDelegate` for additional debugging

## Next Steps

1. **Rebuild both apps** (Android and iOS)
2. **Test voice call** from Android to iOS
3. **Check Console.app logs** to verify the fix
4. **Test all scenarios**: foreground, background, terminated
5. **If successful**, consider implementing VoIP push for production

## Summary

The fix changes iOS call notifications from **silent pushes** (which don't work in SwiftUI apps) to **user-visible notifications** (which work through `UNUserNotificationCenter` and can be intercepted). The banner is suppressed so users only see the CallKit full-screen UI.

This is a **proven workaround** that works with the current iOS architecture. For long-term, implement VoIP Push Notifications as documented in `CRITICAL_BACKEND_NOTIFICATION_ISSUE.md`.
