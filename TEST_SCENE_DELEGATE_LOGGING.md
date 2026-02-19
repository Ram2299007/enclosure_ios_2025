# Test: Scene Delegate Logging

## What We Changed

Added a `RemoteNotificationSceneDelegate` that:
1. Implements `canPerformAction(_:withSender:)` to intercept ALL actions
2. Uses reflection (Mirror) to inspect the sender object
3. Attempts to extract the notification payload from the sender
4. Logs everything for debugging

## What to Test

1. **Clean and Rebuild**
   ```bash
   Product > Clean Build Folder (Cmd+Shift+K)
   Product > Build (Cmd+B)
   ```

2. **Send Another Voice Call Notification**
   - With the app in the foreground
   - Watch Console.app for new logs

3. **Expected Logs**

   You should now see additional logs:
   ```
   🔍 [RemoteNotificationSceneDelegate] canPerformAction: <selector_name>
   🔍 [RemoteNotificationSceneDelegate] Sender class: <class_name>
   🔍 [RemoteNotificationSceneDelegate] Property: <property_name> = <value>
   ```

   These logs will tell us:
   - What selector iOS is trying to call
   - What object is being passed as the sender
   - What properties that object has
   - **Hopefully, we can extract the notification payload from the sender**

4. **If Payload Is Found**

   If the logs show:
   ```
   🚨🚨🚨 [RemoteNotificationSceneDelegate] Found payload in sender!
   📱 [RemoteNotificationSceneDelegate] Forwarding notification to AppDelegate
   🚨 [FCM] NOTIFICATION RECEIVED IN APPDELEGATE!!!
   📞 [CallKit] Incoming voice call detected
   ```

   Then the scene delegate successfully intercepted and forwarded the notification!

5. **If Payload Is NOT Found**

   This confirms that the scene system doesn't expose the notification payload in a way we can access it via public APIs. In this case, **the backend MUST be changed** to use VoIP pushes or user-visible notifications as explained in `CRITICAL_BACKEND_NOTIFICATION_ISSUE.md`.

## Next Steps Based on Results

### Scenario A: Logs Show Payload Found
✅ The scene delegate worked! The notification is now being forwarded to AppDelegate and CallKit should work.

### Scenario B: Logs Don't Show Payload
❌ The scene delegate cannot access the payload via public APIs. This confirms the backend needs to be changed.

**Required Backend Change:**
- Stop using `content-available: 1` (silent push)
- Use VoIP Push Notifications (recommended)
- OR use user-visible notifications with `alert` block

### Scenario C: No New Logs Appear
⚠️ The scene delegate isn't being instantiated. Check:
- Did you rebuild the app?
- Did you delete the old app before installing the new build?
- Check for build errors

## Console.app Filter

Use this filter to see all relevant logs:
```
process:Enclosure subsystem:any category:any message:SceneDelegate OR message:unhandled OR message:FCM OR message:CallKit
```

## Current State

The app now has:
1. ✅ `RemoteNotificationSceneDelegate` with introspection
2. ✅ `VOICE_CALL` category registered
3. ✅ CallKit integration
4. ✅ `NotificationDelegate` for user-visible notifications

If the scene delegate logging doesn't reveal a way to access the payload, then **the only solution is to fix the backend notification format**.
