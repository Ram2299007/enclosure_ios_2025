# Scene Delegate Fix for Voice Call Notifications

## Problem
Remote notifications for "Incoming voice call" were being marked as `unhandled action` in the logs when the app was in the foreground. The logs showed:

```
[(FBSceneManager):sceneID:...] Sending action(s) in update: <UISHandleRemoteNotificationAction: 0x0054015f>
[(FBSceneManager):sceneID:...] Received action(s) in scene-update: <UISHandleRemoteNotificationAction: 0x0054015f>
respondToActions unhandled action:<UISHandleRemoteNotificationAction: 0x157c56cc0>
```

This prevented `AppDelegate.application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` from being called, which meant CallKit was never triggered.

## Root Cause
In iOS 13+, apps using SwiftUI automatically use scene-based architecture. When a remote notification arrives:
1. iOS delivers it as a `UISHandleRemoteNotificationAction` to the scene
2. If there's no scene delegate to handle it, it's marked as "unhandled"
3. The notification is NOT automatically forwarded to AppDelegate

Additionally, the notification had `category: VOICE_CALL` but this category was never registered in the app, which could cause iOS to not know how to handle it.

## Changes Made

### 1. Removed Scene Delegate Configuration (`EnclosureApp.swift`)
- Removed `application(_:configurationForConnecting:options:)` method
- Removed custom `SceneDelegate` class
- By not implementing custom scene configuration, iOS should fall back to delivering notifications to AppDelegate

### 2. Registered VOICE_CALL Category (`FirebaseManager.swift`)
- Added registration for `VOICE_CALL` notification category
- This tells iOS how to handle notifications with this category
- Category has no actions because CallKit provides the full-screen UI

```swift
let voiceCallCategory = UNNotificationCategory(
    identifier: "VOICE_CALL",
    actions: [],
    intentIdentifiers: [],
    options: [.allowInCarPlay]
)
```

## Testing Instructions

1. **Clean and Rebuild**
   ```bash
   # Clean build folder
   Product > Clean Build Folder (Cmd+Shift+K)
   
   # Rebuild
   Product > Build (Cmd+B)
   ```

2. **Install Fresh Build**
   - Delete the app from your device (to ensure clean state)
   - Install the new build
   - Grant notification permissions when prompted

3. **Test Voice Call Notification**
   - **Test 1: App in Foreground**
     - Have the app open and active
     - Send an incoming voice call notification from backend
     - Expected: CallKit full-screen UI should appear immediately
   
   - **Test 2: App in Background**
     - Put the app in background (Home button)
     - Send an incoming voice call notification
     - Expected: CallKit full-screen UI should appear
   
   - **Test 3: App Terminated**
     - Force quit the app
     - Send an incoming voice call notification
     - Expected: CallKit full-screen UI should appear

4. **Check Console.app Logs**
   Search for these patterns in Console.app:
   ```
   process:Enclosure subsystem:any category:any
   ```
   
   Look for:
   - `🚨 [FCM] NOTIFICATION RECEIVED IN APPDELEGATE!!!` - Confirms AppDelegate received it
   - `📞 [CallKit] Incoming voice call detected` - Confirms CallKit handling started
   - `✅ [CallKit] Call reported successfully` - Confirms CallKit UI triggered
   - `respondToActions unhandled action` - Should NOT appear anymore

## Expected Behavior

After these changes, when an incoming voice call notification arrives:

1. iOS delivers the notification
2. **NEW**: iOS recognizes the VOICE_CALL category
3. **NEW**: Without custom scene configuration, notification goes to AppDelegate
4. `AppDelegate.didReceiveRemoteNotification` is called
5. AppDelegate detects `bodyKey == "Incoming voice call"`
6. CallKit's `reportIncomingCall` is triggered
7. Full-screen CallKit UI appears

## If It Still Doesn't Work

If the issue persists, the problem might be with the backend notification payload. Check:

1. **Backend Payload Format**
   - Silent pushes should have `content-available: 1`
   - Category should be `VOICE_CALL` (all caps)
   - Must include all required data fields (callerName, roomId, etc.)

2. **Potential Backend Issue**
   If the backend is sending the notification with BOTH `content-available: 1` (silent push) AND an `alert` block (user-visible notification), iOS might get confused. Voice call notifications should be **silent pushes only** with no alert, because CallKit provides the UI.

   Example of CORRECT payload structure:
   ```json
   {
     "to": "<fcm_token>",
     "priority": "high",
     "data": {
       "bodyKey": "Incoming voice call",
       "callerName": "John Doe",
       "roomId": "123456",
       "receiverId": "user_id",
       ...
     },
     "apns": {
       "payload": {
         "aps": {
           "content-available": 1,
           "category": "VOICE_CALL"
         }
       }
     }
   }
   ```
   
   NOTE: There should be NO `alert` in the `aps` block.

3. **Alternative Approach**
   If the above doesn't work, we may need to implement a full SceneDelegate that explicitly handles `UISHandleRemoteNotificationAction`, but there's no public API for this, which makes it challenging.

## Files Modified

1. `/Users/ramlohar/XCODE_PROJECT/enclosure_ios_2025/Enclosure/EnclosureApp.swift`
   - Removed scene delegate configuration

2. `/Users/ramlohar/XCODE_PROJECT/enclosure_ios_2025/Enclosure/Utility/FirebaseManager.swift`
   - Added VOICE_CALL category registration

## Next Steps

1. Test with the changes above
2. Check Console.app for the expected logs
3. If still not working, provide the backend notification payload for review
4. If needed, we can implement additional runtime inspection to debug what iOS is doing with the notification
