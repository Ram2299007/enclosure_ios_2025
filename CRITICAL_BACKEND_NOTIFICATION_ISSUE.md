# CRITICAL: Backend Notification Configuration Issue

## The Real Problem

After extensive debugging, the issue is NOT with the iOS app code. The problem is with **how the backend is sending the notification**.

### Current Backend Configuration (INCORRECT)

The notification is being sent as a **silent push** with:
```json
{
  "aps": {
    "content-available": 1  // ← THIS IS THE PROBLEM
  },
  "bodyKey": "Incoming voice call",
  "roomId": "...",
  ...
}
```

### Why This Doesn't Work

1. **SwiftUI + Scenes Architecture**
   - iOS 13+ apps (including SwiftUI apps) use a scene-based architecture
   - Silent pushes (`content-available: 1`) are delivered to the **scene system**, not to `AppDelegate`
   - There is NO public API in `UISceneDelegate` to handle remote notification actions
   - The notification arrives at the scene and is marked as "unhandled" because the scene doesn't know what to do with it

2. **iOS System Behavior**
   - When a silent push arrives while the app is in the foreground:
     - iOS delivers it as a `UISHandleRemoteNotificationAction` to the scene
     - The scene has no handler for this action type
     - The action is marked as "unhandled"
     - `AppDelegate.didReceiveRemoteNotification` is NEVER called
   - This is **by design** in iOS's scene architecture

3. **What the Logs Show**
   ```
   Received action(s) in scene-update: <UISHandleRemoteNotificationAction: 0x00540169>
   respondToActions unhandled action:<UISHandleRemoteNotificationAction: ...>
   ```
   This confirms the notification goes to the scene and is not handled.

## The Correct Solution: Use VoIP Pushes

For **incoming voice calls**, iOS provides a dedicated mechanism called **VoIP Push Notifications** via PushKit. This is the Apple-recommended way to handle call notifications.

### Why VoIP Pushes?

1. **Designed for Calls**: VoIP pushes are specifically designed for incoming call notifications
2. **Reliable**: They have higher priority and are more reliable than silent pushes
3. **Direct to App**: They bypass the scene system and go directly to your PushKit delegate
4. **CallKit Integration**: They work seamlessly with CallKit
5. **Battery Efficient**: iOS optimizes VoIP push delivery

### Implementation Required (Backend + iOS)

#### Backend Changes

Instead of sending a silent push via FCM, send a **VoIP push** via Apple Push Notification service (APNs):

```python
# Example Python backend code
import jwt
import time
import requests

# Load your APNs auth key (.p8 file from Apple Developer)
APNS_KEY_ID = "YOUR_KEY_ID"
APNS_TEAM_ID = "YOUR_TEAM_ID"
APNS_AUTH_KEY = """-----BEGIN PRIVATE KEY-----
YOUR_PRIVATE_KEY_HERE
-----END PRIVATE KEY-----"""

# Create JWT token for APNs authentication
def create_apns_token():
    headers = {
        "alg": "ES256",
        "kid": APNS_KEY_ID
    }
    payload = {
        "iss": APNS_TEAM_ID,
        "iat": int(time.time())
    }
    token = jwt.encode(payload, APNS_AUTH_KEY, algorithm="ES256", headers=headers)
    return token

# Send VoIP push
def send_voip_push(device_token, call_data):
    url = f"https://api.push.apple.com/3/device/{device_token}"
    
    headers = {
        "authorization": f"bearer {create_apns_token()}",
        "apns-topic": "com.enclosure.voip",  # Your app's bundle ID + .voip
        "apns-push-type": "voip",
        "apns-priority": "10"
    }
    
    payload = {
        "callerName": call_data["name"],
        "roomId": call_data["roomId"],
        "receiverId": call_data["receiverId"],
        "callerPhoto": call_data["photo"],
        "receiverPhone": call_data["phone"]
    }
    
    response = requests.post(url, json=payload, headers=headers)
    return response

# Usage
send_voip_push(
    device_token="user_voip_token",
    call_data={
        "name": "John Doe",
        "roomId": "EnclosurePowerfulNext1770603899",
        "receiverId": "2",
        "photo": "https://...",
        "phone": "+918379887185"
    }
)
```

#### iOS Changes Required

1. **Enable VoIP Push Capability**
   - In Xcode: Target > Signing & Capabilities > Add Capability > "Push Notifications"
   - Add Background Mode: "Voice over IP"

2. **Implement PushKit Delegate** (create new file `VoIPPushManager.swift`):

```swift
import PushKit
import CallKit

class VoIPPushManager: NSObject, PKPushRegistryDelegate {
    static let shared = VoIPPushManager()
    private var pushRegistry: PKPushRegistry?
    
    func registerForVoIPPushes() {
        let pushRegistry = PKPushRegistry(queue: DispatchQueue.main)
        pushRegistry.delegate = self
        pushRegistry.desiredPushTypes = [.voIP]
        self.pushRegistry = pushRegistry
    }
    
    // Called when VoIP token is received
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        print("✅ [VoIP] VoIP token: \(token)")
        
        // Send this token to your backend
        UserDefaults.standard.set(token, forKey: "VOIP_TOKEN")
        // TODO: Upload to backend via API
    }
    
    // CRITICAL: Called when VoIP push is received
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        print("🚨 [VoIP] Incoming VoIP push received!")
        print("📱 [VoIP] Payload: \(payload.dictionaryPayload)")
        
        // Extract call data
        let callerName = payload.dictionaryPayload["callerName"] as? String ?? "Unknown"
        let roomId = payload.dictionaryPayload["roomId"] as? String ?? ""
        let receiverId = payload.dictionaryPayload["receiverId"] as? String ?? ""
        let callerPhoto = payload.dictionaryPayload["callerPhoto"] as? String ?? ""
        let receiverPhone = payload.dictionaryPayload["receiverPhone"] as? String ?? ""
        
        // Report incoming call to CallKit
        CallKitManager.shared.reportIncomingCall(
            callerName: callerName,
            callerPhoto: callerPhoto,
            roomId: roomId,
            receiverId: receiverId,
            receiverPhone: receiverPhone
        ) { error in
            if let error = error {
                print("❌ [VoIP] CallKit error: \(error)")
            } else {
                print("✅ [VoIP] CallKit UI displayed")
            }
            completion()
        }
    }
}
```

3. **Register for VoIP Pushes** in `AppDelegate`:

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    // ... existing code ...
    
    // Register for VoIP pushes
    VoIPPushManager.shared.registerForVoIPPushes()
    
    return true
}
```

4. **Update Backend API** to accept and store VoIP tokens separately from FCM tokens

## Alternative Solution (If VoIP Push Is Not Possible)

If you cannot implement VoIP pushes immediately, use a **user-visible notification** instead of a silent push:

### Backend Configuration (Alternative)

```json
{
  "notification": {
    "title": "Incoming Call",
    "body": "John Doe is calling...",
    "sound": "default"
  },
  "data": {
    "bodyKey": "Incoming voice call",
    "roomId": "...",
    "callerName": "John Doe",
    ...
  },
  "apns": {
    "payload": {
      "aps": {
        "alert": {
          "title": "Incoming Call",
          "body": "John Doe is calling..."
        },
        "sound": "default",
        "category": "VOICE_CALL"
        // NO content-available!
      }
    }
  }
}
```

This will:
1. Show a notification banner to the user
2. Call `userNotificationCenter(_:willPresent:withCompletionHandler:)` in `NotificationDelegate`
3. We can intercept it there and trigger CallKit

**Note**: This is less ideal than VoIP pushes because:
- It shows a banner notification (VoIP pushes don't)
- It's less reliable
- It doesn't wake the app as reliably as VoIP pushes

## Current iOS App Status

The iOS app is **correctly configured** to handle voice call notifications via:
1. ✅ CallKit integration
2. ✅ `NotificationDelegate` that intercepts "Incoming voice call" notifications
3. ✅ `VOICE_CALL` category registration
4. ✅ Scene delegate that logs all activity

The app will work correctly once the backend sends notifications properly via:
- **Option 1 (Recommended)**: VoIP Push Notifications
- **Option 2 (Temporary)**: User-visible notifications (not silent pushes)

## Testing After Backend Fix

Once the backend is updated:

1. **Test with VoIP Push**:
   - Send a VoIP push from backend
   - Expected: CallKit full-screen UI appears immediately
   - No banner notification should appear

2. **Test with User-Visible Notification** (if using Option 2):
   - Send a notification with `alert` and NO `content-available`
   - Expected: `NotificationDelegate.willPresent` is called
   - CallKit UI is triggered from there

## References

- [Apple VoIP Push Documentation](https://developer.apple.com/documentation/pushkit/responding_to_voip_notifications_from_pushkit)
- [CallKit Programming Guide](https://developer.apple.com/documentation/callkit)
- [APNs Provider API](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server)

## Summary

**The iOS app code is correct**. The issue is that the backend is sending the wrong type of push notification. Silent pushes (`content-available: 1`) cannot trigger CallKit in foreground apps with scene-based architecture. Use VoIP pushes or user-visible notifications instead.
