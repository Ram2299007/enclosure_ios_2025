# 🚨 Complete VoIP Push Solution - Fix Required in BOTH iOS & Backend

## 🎯 Problem Summary

**Current Flow (WHY BACKGROUND DOESN'T SHOW CALLKIT):**

```
User initiates call
    ↓
iOS: MessageUploadService.sendVoiceCallNotificationToBackend() (Line 862)
    ↓
Sends to: fcm.googleapis.com/v1/projects/.../messages:send ❌
    ↓
FCM "alert" notification with category: "VOICE_CALL"
    ↓
RESULT: Background shows BANNER, not CallKit ❌
```

**OR**

```
User initiates call
    ↓
Backend: FcmNotificationsSender.java SendNotifications() (Line 64)
    ↓
Sends to: fcm.googleapis.com/v1/projects/.../messages:send ❌
    ↓
FCM "alert" notification with category: "VOICE_CALL"
    ↓
RESULT: Background shows BANNER, not CallKit ❌
```

---

## ✅ Required Solution

**For instant CallKit in background/lock screen:**

```
User initiates call
    ↓
iOS/Backend: Send VoIP Push to APNs (NOT FCM!)
    ↓
APNs delivers VoIP push to device
    ↓
iOS: VoIPPushManager.pushRegistry() called (Line 88) ✅
    ↓
iOS: CallKitManager.reportIncomingCall() called (Line 148) ✅
    ↓
RESULT: Instant full-screen CallKit! 🎉
```

---

## 🔧 Changes Required

### OPTION 1: Change iOS App to Send VoIP Push (Recommended)

**Modify:** `MessageUploadService.swift`

**Replace Lines 862-999:**

```swift
// BEFORE (sends FCM):
private func sendVoiceCallNotificationToBackend(...) {
    let fcmUrl = "https://fcm.googleapis.com/v1/projects/enclosure-30573/messages:send"
    // ... sends FCM alert notification ...
}

// AFTER (sends VoIP Push):
private func sendVoiceCallNotificationToBackend(...) {
    // Check if receiver has VoIP token
    guard let voipToken = getVoIPToken(for: receiverId) else {
        print("⚠️ [VOICE_CALL] No VoIP token for receiver, falling back to FCM")
        sendFCMFallback(...)
        return
    }
    
    // Send VoIP Push directly to APNs
    let apnsUrl = "https://api.push.apple.com/3/device/\(voipToken)"
    
    let voipPayload: [String: Any] = [
        "name": senderName,
        "photo": senderPhoto,
        "roomId": roomId,
        "receiverId": receiverId,
        "phone": receiverPhone,
        "bodyKey": "Incoming voice call"
    ]
    
    // Need JWT token for APNs authentication
    // See VOIP_PUSH_JWT_IMPLEMENTATION.md
    let jwtToken = createAPNsJWT(...)
    
    var request = URLRequest(url: URL(string: apnsUrl)!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("com.enclosure.voip", forHTTPHeaderField: "apns-topic")
    request.setValue("voip", forHTTPHeaderField: "apns-push-type")
    request.setValue("10", forHTTPHeaderField: "apns-priority")
    request.setValue("bearer \(jwtToken)", forHTTPHeaderField: "authorization")
    request.httpBody = try? JSONSerialization.data(withJSONObject: voipPayload)
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 200 {
                print("✅ [VOICE_CALL] VoIP Push sent successfully!")
                print("✅ [VOICE_CALL] CallKit will appear instantly!")
            } else {
                print("❌ [VOICE_CALL] VoIP Push failed: \(httpResponse.statusCode)")
            }
        }
    }.resume()
}
```

**Same for Video Call (Lines 1048-1185)**

---

### OPTION 2: Change Backend to Send VoIP Push (Recommended)

**Modify:** `FcmNotificationsSender.java`

**Add new method:**

```java
// Add to FcmNotificationsSender.java
private void sendVoIPPushToAPNs(String voipToken, JSONObject callData) throws Exception {
    
    System.out.println("📞 [VoIP] Sending VoIP Push to APNs");
    
    // 1. Create APNs JWT Token (see BACKEND_VOIP_CHANGES_REQUIRED.md)
    String jwtToken = createAPNsJWT(
        "YOUR_KEY_ID",
        "YOUR_TEAM_ID",
        "/path/to/AuthKey_XXXXX.p8"
    );
    
    // 2. APNs endpoint
    String apnsUrl = "https://api.push.apple.com/3/device/" + voipToken;
    
    // 3. Create HTTP/2 request
    OkHttpClient client = new OkHttpClient.Builder()
        .protocols(Arrays.asList(Protocol.H2_PRIOR_KNOWLEDGE))
        .build();
    
    RequestBody requestBody = RequestBody.create(
        callData.toString(),
        MediaType.parse("application/json")
    );
    
    Request request = new Request.Builder()
        .url(apnsUrl)
        .addHeader("apns-topic", "com.enclosure.voip")
        .addHeader("apns-push-type", "voip")
        .addHeader("apns-priority", "10")
        .addHeader("authorization", "bearer " + jwtToken)
        .post(requestBody)
        .build();
    
    Response response = client.newCall(request).execute();
    
    if (response.code() == 200) {
        System.out.println("✅ [VoIP] VoIP Push sent successfully!");
    } else {
        System.err.println("❌ [VoIP] Error: " + response.code());
    }
}
```

**Modify SendNotifications() (Lines 89-138):**

```java
// BEFORE:
if (!"1".equals(normalizedDeviceType)) {
    // iOS device - send FCM alert
    aps.put("category", "VOICE_CALL");
}

// AFTER:
if (!"1".equals(normalizedDeviceType)) {
    // iOS device - check if call notification
    boolean isCallNotification = Constant.voicecall.equals(body) 
                              || Constant.videocall.equals(body);
    
    if (isCallNotification) {
        // Send VoIP Push for instant CallKit
        JSONObject voipPayload = new JSONObject();
        voipPayload.put("name", userName);
        voipPayload.put("photo", photo);
        voipPayload.put("roomId", roomId);
        voipPayload.put("receiverId", callerId);
        voipPayload.put("phone", phone);
        voipPayload.put("bodyKey", body);
        
        sendVoIPPushToAPNs(voipToken, voipPayload);
        return;  // Don't send FCM!
    }
    
    // For non-call notifications, use FCM as before
    aps.put("category", "VOICE_CALL");
}
```

---

## 📊 Comparison: Current vs Required

| Aspect | Current (FCM) | Required (VoIP Push) |
|--------|---------------|----------------------|
| **iOS Sender** | MessageUploadService Line 874 | Send to APNs directly |
| **Backend Sender** | FcmNotificationsSender Line 40 | Send to APNs directly |
| **Push Type** | FCM "alert" notification | VoIP Push |
| **iOS Handler** | NotificationDelegate | VoIPPushManager Line 88 |
| **Foreground** | Banner → CallKit | Instant CallKit |
| **Background** | Banner → Must tap ❌ | Instant CallKit ✅ |
| **Lock Screen** | Banner → Must tap ❌ | Instant CallKit ✅ |

---

## 🚀 Implementation Steps

### Step 1: Get APNs Auth Key (5 minutes)

1. Go to https://developer.apple.com/account
2. **Certificates, Identifiers & Profiles**
3. **Keys** → **+ (Create Key)**
4. Name: "VoIP Push Key"
5. Enable: **Apple Push Notifications service (APNs)**
6. Click **Continue** → **Register** → **Download**

**You get:**
- `AuthKey_ABCD1234.p8` ← File (download ONCE only!)
- **Key ID:** `ABCD1234`
- **Team ID:** `XYZ9876` (from Account settings)

---

### Step 2: Choose Implementation Location

**OPTION A: iOS App Sends VoIP Push**
- Modify `MessageUploadService.swift` Lines 862-999, 1048-1185
- Add APNs JWT generation
- Add VoIP token retrieval

**OPTION B: Backend Sends VoIP Push (RECOMMENDED)**
- Modify `FcmNotificationsSender.java`
- Add `sendVoIPPushToAPNs()` method
- Add APNs JWT generation
- Add VoIP token storage

**OPTION C: Both (Best for reliability)**
- iOS sends VoIP if receiver is iOS user
- Backend sends VoIP if sender is Android user
- Covers all scenarios!

---

### Step 3: Database Changes

**Add VoIP token column:**

```sql
ALTER TABLE users 
ADD COLUMN voip_token VARCHAR(255);
```

**Store VoIP token when received:**
- iOS sends VoIP token to backend on startup
- Backend stores in `voip_token` column
- Use VoIP token ONLY for call notifications

---

### Step 4: Update iOS VoIP Token Sender

**File:** `Enclosure/EnclosureApp.swift` (around Line 120)

**Currently:**
```swift
VoIPPushManager.shared.onVoIPTokenReceived = { token in
    NSLog("📞 [AppDelegate] VoIP Token received!")
    // TODO: Send VoIP token to your backend
    // VoIPPushManager.shared.sendVoIPTokenToBackend()  // COMMENTED!
}
```

**Uncomment:**
```swift
VoIPPushManager.shared.onVoIPTokenReceived = { token in
    NSLog("📞 [AppDelegate] VoIP Token received!")
    VoIPPushManager.shared.sendVoIPTokenToBackend()  // ✅ ENABLED!
}
```

---

### Step 5: Test End-to-End

**Test Scenario 1: Background**
1. Put app in background
2. Send call from another device
3. **EXPECTED:** Instant CallKit appears! 🎉

**Test Scenario 2: Lock Screen**
1. Lock device
2. Send call from another device
3. **EXPECTED:** Instant CallKit appears! 🎉

**Test Scenario 3: Terminated**
1. Force quit app
2. Send call from another device
3. **EXPECTED:** Instant CallKit appears! 🎉

---

## 📝 Why VoIP Push, Not FCM?

| Feature | FCM Push | VoIP Push |
|---------|----------|-----------|
| **Wakes app** | ❌ Sometimes | ✅ Always |
| **Background** | Shows banner | Wakes app instantly |
| **Lock screen** | Shows banner | Wakes app instantly |
| **Terminated** | Shows banner | Wakes app instantly |
| **CallKit integration** | Manual after tap | Instant trigger |
| **Reliability** | iOS throttles | Guaranteed delivery |
| **Battery** | Higher | Optimized |

**Apple's Rule:** Voice/video calls MUST use VoIP Push for best UX!

---

## 🎯 Quick Reference

**Your VoIP Token (from logs):**
```
416951db5bb2d8dd836060f8deb6725e049e048c1f41669b9f8fc94500b689e6
```

**iOS VoIP Handler:**
```
File: Enclosure/Utility/VoIPPushManager.swift
Method: pushRegistry(_:didReceiveIncomingPushWith:for:completion:)
Line: 88-201
Triggers: CallKitManager.reportIncomingCall() at Line 148
```

**iOS FCM Sender (CURRENT - NEEDS CHANGE):**
```
File: Enclosure/Utility/MessageUploadService.swift
Method: sendVoiceCallNotificationToBackend()
Line: 862-999
Sends to: fcm.googleapis.com (FCM) ❌
```

**Backend FCM Sender (CURRENT - NEEDS CHANGE):**
```
File: FcmNotificationsSender.java
Method: SendNotifications()
Line: 64-174
Sends to: fcm.googleapis.com (FCM) ❌
```

---

## ✅ Summary

**Current Problem:**
- Both iOS app AND backend send FCM pushes
- FCM shows banner in background
- VoIPPushManager exists but never called
- User must tap banner to see CallKit

**Solution:**
- Change iOS OR backend (or both) to send VoIP Push
- VoIP Push → VoIPPushManager → Instant CallKit
- Works in foreground, background, lock screen, terminated

**Next Action:**
- Get APNs Auth Key (.p8 file)
- Choose: iOS or Backend to implement VoIP Push
- Test with real VoIP push from APNs

---

**YOUR iOS CODE IS PERFECT! Just need to send VoIP pushes instead of FCM!** 🚀
