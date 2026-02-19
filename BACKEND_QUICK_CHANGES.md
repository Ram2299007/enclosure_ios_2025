# ⚡ Quick Backend Changes - VoIP Push Implementation

## 🎯 Goal
Change backend to send **VoIP Push to APNs** instead of **FCM** for iOS call notifications.

---

## 📁 File to Edit
`FcmNotificationsSender.java`

---

## 🔧 3 Main Changes

### Change 1: Add VoIP Token Field (Line 37)

**After line 37, add:**
```java
private String voipToken;  // VoIP token for iOS
```

**Update constructor (line 44) - add last parameter:**
```java
public FcmNotificationsSender(...existing params..., String voipToken) {
    // ... existing code ...
    this.voipToken = voipToken;  // Add this line at end
}
```

---

### Change 2: Add VoIP Push Sender Method

**Add this complete method anywhere in the class:**

```java
private void sendVoIPPushToAPNs() {
    System.out.println("📞 [VoIP] Sending VoIP Push to APNs");
    
    if (voipToken == null || voipToken.isEmpty()) {
        System.err.println("❌ [VoIP] No VoIP token - cannot send");
        return;
    }
    
    try {
        // APNs endpoint
        String apnsUrl = "https://api.push.apple.com/3/device/" + voipToken;
        
        // Create VoIP payload
        JSONObject payload = new JSONObject();
        payload.put("name", userName);
        payload.put("photo", photo);
        payload.put("roomId", roomId);
        payload.put("receiverId", callerId);
        payload.put("phone", phone);
        payload.put("bodyKey", body);
        
        // You need JWT token - see BACKEND_VOIP_IMPLEMENTATION.md
        String jwtToken = "YOUR_JWT_TOKEN_HERE";
        
        // Create HTTP/2 client
        OkHttpClient client = new OkHttpClient.Builder()
            .protocols(Collections.singletonList(Protocol.H2_PRIOR_KNOWLEDGE))
            .build();
        
        RequestBody requestBody = RequestBody.create(
            MediaType.parse("application/json"),
            payload.toString()
        );
        
        Request request = new Request.Builder()
            .url(apnsUrl)
            .post(requestBody)
            .addHeader("apns-topic", "com.enclosure.voip")
            .addHeader("apns-push-type", "voip")
            .addHeader("apns-priority", "10")
            .addHeader("authorization", "bearer " + jwtToken)
            .build();
        
        Response response = client.newCall(request).execute();
        
        if (response.code() == 200) {
            System.out.println("✅ [VoIP] Push sent successfully!");
        } else {
            System.err.println("❌ [VoIP] Error: " + response.code());
        }
        
    } catch (Exception e) {
        System.err.println("❌ [VoIP] Exception: " + e.getMessage());
    }
}
```

---

### Change 3: Modify SendNotifications() Method

**Replace lines 89-138 (the iOS section) with:**

```java
} else {
    // iOS device (device_type != "1")
    System.out.println("📞 [FCM] Detected iOS device");
    
    // Check if this is a call notification
    boolean isCallNotification = Constant.voicecall.equals(body) 
                               || Constant.videocall.equals(body);
    
    if (isCallNotification) {
        // 🚀 SEND VOIP PUSH FOR INSTANT CALLKIT!
        System.out.println("📞 [VoIP] Sending VoIP Push instead of FCM");
        sendVoIPPushToAPNs();
        System.out.println("✅ [VoIP] iOS will show instant CallKit!");
        return;  // IMPORTANT: Don't send FCM!
    }
    
    // For non-call notifications, use FCM as before
    System.out.println("📞 [FCM] Using FCM for non-call notification");
    notificationJson = new JSONObject();
    
    // ... rest of FCM code stays the same ...
}
```

---

## 📝 Where to Get JWT Token

**For now, you can:**

### Option A: Use Online JWT Generator (Quick Test)
1. Go to https://jwt.io
2. Use Algorithm: ES256
3. Add your Apple Auth Key
4. Generate token
5. Paste in code temporarily

### Option B: Implement Full Solution
See `BACKEND_VOIP_IMPLEMENTATION.md` for:
- APNs Auth Key setup
- JWT generation code
- Complete implementation

---

## ⚠️ Important Notes

1. **VoIP Token** is different from FCM token
   - Get from iOS app: `VoIPPushManager.swift`
   - Store in database: `users.voip_token` column
   
2. **APNs URL** is different from FCM
   - Production: `https://api.push.apple.com/3/device/`
   - Sandbox: `https://api.sandbox.push.apple.com/3/device/`
   
3. **HTTP/2 Required**
   - APNs requires HTTP/2 protocol
   - Use OkHttp with Protocol.H2_PRIOR_KNOWLEDGE

---

## 🎯 Quick Test Flow

### Before (Current - FCM):
```
Android sends call → Backend sends FCM → iOS shows banner → User taps → CallKit ❌
```

### After (VoIP Push):
```
Android sends call → Backend sends VoIP → iOS shows CallKit instantly! ✅
```

---

## 📊 Comparison

| Aspect | FCM (Current) | VoIP Push (New) |
|--------|---------------|-----------------|
| Background | Banner ❌ | Instant CallKit ✅ |
| Lock Screen | Banner ❌ | Instant CallKit ✅ |
| Terminated | Banner ❌ | Instant CallKit ✅ |
| User Action | Must tap | No tap needed |
| Delivery | Throttled | Guaranteed |

---

## 🚀 Minimal Working Version

**If you just want to test quickly:**

1. **Add voipToken field** (line 37)
2. **Update constructor** to accept voipToken
3. **Replace iOS section** (lines 89-138) with the code from Change 3 above
4. **Add the sendVoIPPushToAPNs() method**
5. **Get APNs Auth Key** from Apple Developer Portal
6. **Generate JWT token** (use jwt.io for testing)
7. **Test with real iOS device!**

---

## 📞 Need Help?

**See complete implementation:**
- `BACKEND_VOIP_IMPLEMENTATION.md` - Full step-by-step guide
- `COMPLETE_VOIP_SOLUTION.md` - Overall solution architecture
- `WHERE_CALLKIT_IS_TRIGGERED.md` - iOS code explanation

**Your iOS app is ready! Just need backend to send VoIP pushes!** 🎉
