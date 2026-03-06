# VoIP Push Notifications - The ONLY Solution for Background CallKit

## Problem: Regular Notifications Cannot Wake App in Background

**User reported:** "Still i am in background then getting simple notification not like foreground"

### What We Tried

#### Attempt 1: Alert Only (NO content-available)
```json
{
  "aps": {
    "alert": { "title": "...", "body": "..." },
    "category": "VOICE_CALL"
  }
}
```
**Result:**
- ✅ Foreground: CallKit appears immediately
- ❌ Background: Banner shows, app NOT woken, CallKit NOT triggered

#### Attempt 2: Alert + content-available
```json
{
  "aps": {
    "alert": { "title": "...", "body": "..." },
    "content-available": 1,
    "category": "VOICE_CALL"
  }
}
```
**Result:**
- ✅ Foreground: CallKit appears immediately  
- ❌ Background: **"UISHandleRemoteNotificationAction unhandled action"** error
- ❌ Same error as we started with!

**Logs:**
```
info Enclosure Decode <UISHandleRemoteNotificationAction: 0x00540182>
debug Enclosure respondToActions unhandled action:<UISHandleRemoteNotificationAction...>
```

### Why This Happens (Technical Deep Dive)

In SwiftUI scene-based apps, when a notification with BOTH `alert` and `content-available` arrives while app is in **background**:

1. iOS routes it through the **scene system** (not AppDelegate)
2. Scene receives `UISHandleRemoteNotificationAction`
3. **SwiftUI has NO public API to handle this action**
4. Action remains "unhandled"
5. `AppDelegate.didReceiveRemoteNotification` is NEVER called

This is a **fundamental limitation** of regular push notifications in SwiftUI apps.

## The ONLY Solution: VoIP Push Notifications

**VoIP pushes bypass the entire notification/scene system** and go directly to your app via PushKit framework.

### Why VoIP Pushes Work

| Feature | Regular Push | VoIP Push |
|---------|-------------|-----------|
| **Wakes app in background** | ❌ Causes "unhandled action" | ✅ Always works |
| **Goes through scene system** | ✅ Yes (causes issues) | ❌ No (direct to app) |
| **Priority** | Normal | Highest |
| **User-visible notification** | Always shows | Never shows |
| **Apple recommended for calls** | ❌ No | ✅ Yes |
| **CallKit integration** | Manual | Built-in |

### VoIP Push Flow

```
1. 📞 Backend sends VoIP push to APNs VoIP endpoint
2. ⚡ APNs delivers with HIGHEST priority
3. 🚀 iOS wakes app (even if terminated)
4. 📲 PKPushRegistryDelegate receives push
5. 📞 App reports to CallKit IMMEDIATELY
6. 🖼️ CallKit full-screen UI appears
7. 🔕 NO banner notification ever shows
```

## VoIP Push Implementation Guide

### Step 1: Add PushKit Framework (iOS)

**In Xcode:**
1. Select your target → `Enclosure`
2. Go to "Signing & Capabilities"
3. Click "+ Capability"
4. Add "Push Notifications" (if not already added)
5. Add "Background Modes"
6. Check "Voice over IP" (voip)

**In `Info.plist`:** (Already done)
```xml
<key>UIBackgroundModes</key>
<array>
    <string>voip</string>
    <string>remote-notification</string>
</array>
```

### Step 2: Register for VoIP Pushes (iOS)

Create new file: `Enclosure/Utility/VoIPPushManager.swift`

```swift
import Foundation
import PushKit
import CallKit

class VoIPPushManager: NSObject {
    static let shared = VoIPPushManager()
    
    private let pushRegistry = PKPushRegistry(queue: .main)
    private var voipToken: String?
    
    // Completion handler for token
    var onVoIPTokenReceived: ((String) -> Void)?
    
    override init() {
        super.init()
        pushRegistry.delegate = self
        pushRegistry.desiredPushTypes = [.voIP]
        
        NSLog("📞 [VoIP] VoIPPushManager initialized")
        print("📞 [VoIP] VoIPPushManager initialized")
    }
    
    func start() {
        // Registration happens automatically in init
        NSLog("📞 [VoIP] Starting VoIP push registration...")
        print("📞 [VoIP] Starting VoIP push registration...")
    }
    
    func getVoIPToken() -> String? {
        return voipToken
    }
}

// MARK: - PKPushRegistryDelegate
extension VoIPPushManager: PKPushRegistryDelegate {
    
    // Called when VoIP token is received
    func pushRegistry(_ registry: PKPushRegistry, 
                     didUpdate pushCredentials: PKPushCredentials, 
                     for type: PKPushType) {
        guard type == .voIP else { return }
        
        let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        voipToken = token
        
        NSLog("📞 [VoIP] ============================================")
        NSLog("📞 [VoIP] VoIP Push Token Received!")
        NSLog("📞 [VoIP] Token: \(token)")
        NSLog("📞 [VoIP] ============================================")
        
        print("📞 [VoIP] VoIP Push Token: \(token)")
        
        // Send token to server
        onVoIPTokenReceived?(token)
        
        // TODO: Send token to backend
        // UserDefaults.standard.set(token, forKey: "voipToken")
        // Call your API to register this VoIP token
    }
    
    // Called when VoIP push is received
    func pushRegistry(_ registry: PKPushRegistry, 
                     didReceiveIncomingPushWith payload: PKPushPayload, 
                     for type: PKPushType, 
                     completion: @escaping () -> Void) {
        guard type == .voIP else {
            completion()
            return
        }
        
        NSLog("📞📞📞 [VoIP] ========================================")
        NSLog("📞 [VoIP] INCOMING VOIP PUSH RECEIVED!")
        NSLog("📞 [VoIP] Payload: \(payload.dictionaryPayload)")
        NSLog("📞📞📞 [VoIP] ========================================")
        
        print("📞📞📞 [VoIP] INCOMING VOIP PUSH!")
        print("📞 [VoIP] Payload: \(payload.dictionaryPayload)")
        
        let userInfo = payload.dictionaryPayload
        
        // Extract call data
        let callerName = (userInfo["name"] as? String) ?? (userInfo["user_nameKey"] as? String) ?? "Unknown"
        let callerPhoto = (userInfo["photo"] as? String) ?? ""
        let roomId = (userInfo["roomId"] as? String) ?? ""
        let receiverId = (userInfo["receiverId"] as? String) ?? ""
        let receiverPhone = (userInfo["phone"] as? String) ?? ""
        
        NSLog("📞 [VoIP] Call from: \(callerName)")
        NSLog("📞 [VoIP] Room ID: \(roomId)")
        
        print("📞 [VoIP] Caller: \(callerName)")
        print("📞 [VoIP] Room: \(roomId)")
        
        guard !roomId.isEmpty else {
            NSLog("⚠️ [VoIP] Missing roomId - cannot process call")
            completion()
            return
        }
        
        // Report to CallKit IMMEDIATELY
        CallKitManager.shared.reportIncomingCall(
            callerName: callerName,
            callerPhoto: callerPhoto,
            roomId: roomId,
            receiverId: receiverId,
            receiverPhone: receiverPhone
        ) { error in
            if let error = error {
                NSLog("❌ [VoIP] CallKit error: \(error.localizedDescription)")
                print("❌ [VoIP] CallKit error: \(error.localizedDescription)")
            } else {
                NSLog("✅ [VoIP] CallKit call reported successfully!")
                print("✅ [VoIP] CallKit call reported successfully!")
            }
            
            // CRITICAL: Must call completion handler
            completion()
        }
        
        // Set up callbacks
        CallKitManager.shared.onAnswerCall = { roomId, receiverId, receiverPhone in
            NSLog("📞 [VoIP] User answered call - Room: \(roomId)")
            
            DispatchQueue.main.async {
                let callData: [String: String] = [
                    "roomId": roomId,
                    "receiverId": receiverId,
                    "receiverPhone": receiverPhone,
                    "callerName": callerName,
                    "callerPhoto": callerPhoto
                ]
                NotificationCenter.default.post(
                    name: NSNotification.Name("AnswerIncomingCall"),
                    object: nil,
                    userInfo: callData
                )
            }
        }
        
        CallKitManager.shared.onDeclineCall = { roomId in
            NSLog("📞 [VoIP] User declined call - Room: \(roomId)")
            // Notify server
        }
    }
    
    // Handle invalid token
    func pushRegistry(_ registry: PKPushRegistry, 
                     didInvalidatePushTokenFor type: PKPushType) {
        NSLog("⚠️ [VoIP] Push token invalidated for type: \(type)")
        voipToken = nil
    }
}
```

### Step 3: Initialize VoIP Manager (EnclosureApp.swift)

```swift
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, 
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Existing code...
        
        // Initialize VoIP Push Manager
        VoIPPushManager.shared.start()
        
        // Handle VoIP token
        VoIPPushManager.shared.onVoIPTokenReceived = { token in
            NSLog("📞 [VoIP] Token received, sending to backend...")
            // TODO: Send to your backend API
            // Example: YourAPI.registerVoIPToken(token)
        }
        
        return true
    }
}
```

### Step 4: Backend Changes (Android)

**Create new method for VoIP pushes:**

```java
public void sendVoIPPushNotification(
    String voipToken,  // Different from FCM token!
    String callerName,
    String callerPhoto,
    String roomId,
    String receiverId,
    String phone
) {
    try {
        // VoIP pushes go to APNs DIRECTLY (not through FCM!)
        // You need to use APNs HTTP/2 API with your Apple certificates
        
        // APNs endpoint for VoIP
        String apnsUrl = "https://api.sandbox.push.apple.com/3/device/" + voipToken;  // sandbox
        // String apnsUrl = "https://api.push.apple.com/3/device/" + voipToken;  // production
        
        // Headers
        // "apns-topic": "com.enclosure.voip"  // Your bundle ID + .voip
        // "apns-push-type": "voip"
        // "apns-priority": "10"
        
        // Payload (NO APS block! Just data)
        JSONObject payload = new JSONObject();
        payload.put("name", callerName);
        payload.put("photo", callerPhoto);
        payload.put("roomId", roomId);
        payload.put("receiverId", receiverId);
        payload.put("phone", phone);
        payload.put("bodyKey", "Incoming voice call");
        
        // Send to APNs with JWT authentication
        // See: https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/sending_notification_requests_to_apns
        
    } catch (Exception e) {
        Log.e("VoIP", "Failed to send VoIP push", e);
    }
}
```

**Important:** VoIP pushes require:
1. Apple Push Notification Service (APNs) certificates
2. Direct HTTP/2 connection to APNs (not through FCM)
3. JWT token for authentication
4. Different token (VoIP token, not FCM token)

### Step 5: Backend API Integration

**You'll need to:**

1. **Get APNs Authentication Key** from Apple Developer Portal
   - Sign In to https://developer.apple.com
   - Go to Certificates, Identifiers & Profiles
   - Create "Apple Push Notification Authentication Key (APNs Auth Key)"
   - Download the .p8 file
   - Save the Key ID and Team ID

2. **Update Backend to Send to APNs**
   - Use APNs HTTP/2 API
   - Libraries available:
     - Java: https://github.com/notnoop/java-apns
     - Node.js: https://github.com/node-apn/node-apn
     - Python: https://github.com/Pr0Ger/PyAPNs2

3. **Store TWO Tokens Per User**
   - Regular FCM token (for chat notifications)
   - VoIP token (for call notifications)

## Current State: What Works Now

### ✅ Foreground (Works Perfectly)
```
App in foreground:
1. Notification arrives
2. willPresent() called
3. CallKit triggered immediately
4. Banner suppressed
5. CallKit full-screen UI appears

User sees: WhatsApp-style call UI ✅
```

### ⚠️ Background (Requires User Tap)
```
App in background:
1. Notification arrives
2. Banner shows on lock screen
3. User MUST tap banner
4. didReceive(response:) called
5. CallKit triggered
6. CallKit full-screen UI appears

User sees: Banner first, then CallKit after tapping
```

## Decision: Use Current Solution or Implement VoIP?

### Option 1: Keep Current Implementation (No VoIP)

**Pros:**
- ✅ Already working in foreground (perfect UX)
- ✅ Works in background after user taps
- ✅ No backend changes needed
- ✅ Uses existing FCM infrastructure
- ✅ Simple to maintain

**Cons:**
- ⚠️ Background: User must tap banner first
- ⚠️ Not instant like WhatsApp in background
- ⚠️ Slight delay compared to VoIP

**Recommendation:** **Good enough for most apps!** The foreground experience is perfect, and background requires one tap.

### Option 2: Implement VoIP Pushes

**Pros:**
- ✅ Instant CallKit in ALL states (foreground, background, terminated)
- ✅ Apple recommended for call apps
- ✅ Highest priority delivery
- ✅ No banner ever shown
- ✅ Professional-grade call experience

**Cons:**
- ⚠️ Requires APNs certificates and setup
- ⚠️ Backend must send to APNs directly (not FCM)
- ⚠️ More complex implementation
- ⚠️ Must maintain two push systems (FCM for chat, VoIP for calls)
- ⚠️ Development effort required

**Recommendation:** **Implement for production-quality call app** where instant background calls are critical.

## Quick Comparison: User Experience

### Current Implementation (Regular Notifications)

**Foreground:**
```
📱 Using app
📞 Call notification arrives
🖼️ CallKit full-screen UI appears INSTANTLY
👍 Perfect! ✅
```

**Background:**
```
📱 Home screen
🔔 Banner appears at top
😐 User sees banner
👆 User taps banner
📲 App opens
🖼️ CallKit full-screen UI appears
👍 Works, but requires tap
```

### VoIP Implementation

**Foreground:**
```
📱 Using app
📞 VoIP push arrives
🖼️ CallKit full-screen UI appears INSTANTLY
👍 Perfect! ✅
```

**Background:**
```
📱 Home screen or locked
📞 VoIP push arrives
🖼️ CallKit full-screen UI appears INSTANTLY (no banner!)
👍 Perfect! Same as WhatsApp! ✅
```

## Migration Path (If You Choose VoIP)

### Phase 1: Setup (Backend)
1. Get APNs authentication key (.p8 file)
2. Set up APNs HTTP/2 client library
3. Create endpoint to receive VoIP tokens from iOS
4. Store VoIP tokens separately from FCM tokens

### Phase 2: iOS App
1. Add `VoIPPushManager.swift` (code provided above)
2. Initialize in `AppDelegate.didFinishLaunching`
3. Send VoIP token to backend
4. Test receiving VoIP pushes

### Phase 3: Testing
1. Send VoIP push from backend
2. Verify app wakes in background
3. Verify CallKit appears immediately
4. Test from all states (foreground, background, terminated)

### Phase 4: Production
1. Switch to production APNs endpoint
2. Update backend to send VoIP for calls, FCM for chat
3. Monitor delivery and error rates
4. Keep current implementation as fallback

## Immediate Action Required

### Revert content-available Changes

I've already reverted the changes in:
1. ✅ `FcmNotificationsSender.java` - Removed `content-available: 1`
2. ✅ `MessageUploadService.swift` - Removed `"content-available": 1`

**Reason:** They cause "unhandled action" in background, breaking the notification flow.

### Rebuild Android Backend

You need to rebuild your Android backend with the REVERTED `FcmNotificationsSender.java`.

### Current Behavior After Revert

- ✅ **Foreground:** CallKit appears immediately (perfect!)
- ⚠️ **Background:** Banner shows → user taps → CallKit appears (good enough!)

## Summary

**The hard truth:** With regular push notifications (FCM/APNs), we **CANNOT** trigger CallKit immediately in background for SwiftUI apps. This is a platform limitation.

**Your options:**

1. **Accept current behavior** (recommended for now)
   - Foreground: Perfect ✅
   - Background: Requires one tap (acceptable for most users)

2. **Implement VoIP pushes** (recommended for production)
   - Perfect experience in ALL states
   - Requires backend work and APNs setup
   - Industry standard for call apps

**My recommendation:** 
- Use current implementation NOW (it works well!)
- Plan VoIP migration for next phase
- Focus on other features first
- Implement VoIP when you have time for proper backend integration

---

**Status:** ✅ Reverted to working state  
**Current:** Foreground perfect, Background requires tap  
**Future:** VoIP pushes for instant background calls
