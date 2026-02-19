# 🚨 Backend Changes Required for Instant CallKit

## Current Problem

**Backend File:** `/Users/ramlohar/StudioProjects/ENCLOSRE_FINAL_ANDROID_2025/app/src/main/java/com/enclosure/Utils/FcmNotificationsSender.java`

**Current Behavior:**
- Sends **FCM Push** for all notifications (including calls)
- iOS shows **simple banner** in background/lock screen
- User must **tap banner** to see CallKit

## Required Solution

**For iOS voice/video calls:** Send **VoIP Push directly to APNs** (not FCM)

---

## Code Changes Needed

### Change 1: Add VoIP Token Field

**In `FcmNotificationsSender.java` constructor, add:**

```java
public class FcmNotificationsSender {
    
    private String userFcmToken;
    private String voipToken;  // ← ADD THIS (iOS VoIP token)
    private String device_type;
    // ... other fields ...
    
    public FcmNotificationsSender(
        String userFcmToken,
        String voipToken,  // ← ADD THIS parameter
        String title,
        String body,
        // ... other parameters ...
        String device_type,
        // ... remaining parameters ...
    ) {
        this.userFcmToken = userFcmToken;
        this.voipToken = voipToken;  // ← ADD THIS
        this.device_type = device_type;
        // ... rest of constructor ...
    }
}
```

### Change 2: Add VoIP Push Sender Method

**Add this new method to the class:**

```java
/**
 * Send VoIP Push directly to APNs for iOS call notifications
 * This triggers instant CallKit in background/lock screen
 */
private void sendVoIPPushToAPNs(String voipToken, JSONObject callData) {
    
    System.out.println("📞 [VoIP] Sending VoIP Push to APNs");
    System.out.println("📞 [VoIP] VoIP Token: " + voipToken);
    System.out.println("📞 [VoIP] Call Data: " + callData.toString());
    
    try {
        // 1. Create APNs JWT Token
        String jwtToken = createAPNsJWT(
            "YOUR_KEY_ID",      // Get from Apple Developer Portal
            "YOUR_TEAM_ID",     // Get from Apple Developer Portal
            "/path/to/AuthKey_XXXXX.p8"  // Download from Apple Portal
        );
        
        // 2. APNs endpoint
        String apnsUrl = "https://api.sandbox.push.apple.com/3/device/" + voipToken;
        // For PRODUCTION: https://api.push.apple.com/3/device/
        
        // 3. Create HTTP/2 request
        OkHttpClient client = new OkHttpClient.Builder()
            .protocols(Arrays.asList(Protocol.H2_PRIOR_KNOWLEDGE))  // Force HTTP/2
            .build();
        
        RequestBody requestBody = RequestBody.create(
            callData.toString(),
            MediaType.parse("application/json")
        );
        
        Request request = new Request.Builder()
            .url(apnsUrl)
            .addHeader("apns-topic", "com.enclosure.voip")  // Bundle ID + .voip
            .addHeader("apns-push-type", "voip")
            .addHeader("apns-priority", "10")  // High priority
            .addHeader("authorization", "bearer " + jwtToken)
            .post(requestBody)
            .build();
        
        // 4. Send request
        Response response = client.newCall(request).execute();
        
        if (response.code() == 200) {
            System.out.println("✅ [VoIP] VoIP Push sent successfully!");
            System.out.println("✅ [VoIP] iOS will show instant CallKit!");
        } else {
            System.err.println("❌ [VoIP] Error: " + response.code());
            System.err.println("❌ [VoIP] Body: " + response.body().string());
        }
        
    } catch (Exception e) {
        System.err.println("❌ [VoIP] Exception: " + e.getMessage());
        e.printStackTrace();
    }
}

/**
 * Create JWT token for APNs authentication
 */
private String createAPNsJWT(String keyId, String teamId, String p8FilePath) {
    // Use a JWT library like io.jsonwebtoken:jjwt
    // See VOIP_BACKEND_SETUP.md for complete implementation
    
    long now = System.currentTimeMillis() / 1000;
    
    // JWT Header
    Map<String, Object> header = new HashMap<>();
    header.put("alg", "ES256");
    header.put("kid", keyId);
    
    // JWT Claims
    return Jwts.builder()
        .setHeader(header)
        .setIssuer(teamId)
        .setIssuedAt(new Date(now * 1000))
        .signWith(getPrivateKey(p8FilePath), SignatureAlgorithm.ES256)
        .compact();
}
```

### Change 3: Modify SendNotification Method

**Find the voice/video call section (around line 114-127) and REPLACE with:**

```java
public void SendNotifications() {
    ExecutorService executorService = Executors.newSingleThreadExecutor();
    executorService.execute(() -> {
        try {
            // ... existing FCM token and JSON setup ...
            
            // 🚨 CRITICAL: Check if iOS call notification
            boolean isIOSDevice = "2".equals(device_type);  // 2 = iOS
            boolean isCallNotification = Constant.voicecall.equals(body) 
                                      || Constant.videocall.equals(body);
            
            if (isIOSDevice && isCallNotification) {
                
                System.out.println("📞 [FCM] Detected iOS CALL notification");
                System.out.println("📞 [FCM] Switching to VoIP Push for instant CallKit");
                
                // Create call data payload for VoIP push
                JSONObject voipPayload = new JSONObject();
                voipPayload.put("name", userName);
                voipPayload.put("photo", photo);
                voipPayload.put("roomId", roomId);
                voipPayload.put("receiverId", callerId);
                voipPayload.put("phone", phone);
                voipPayload.put("bodyKey", body);  // "Incoming voice call"
                
                // Send VoIP Push (NOT FCM!)
                sendVoIPPushToAPNs(voipToken, voipPayload);
                
                System.out.println("✅ [VoIP] VoIP Push sent to APNs");
                System.out.println("✅ [VoIP] CallKit will appear instantly on iOS!");
                return;  // STOP here - don't send FCM for iOS calls
            }
            
            // For non-call notifications OR Android devices, use FCM as before
            if (isIOSDevice) {
                // iOS device (non-call notification)
                JSONObject aps = new JSONObject();
                JSONObject alert = new JSONObject();
                alert.put("title", title);
                alert.put("body", body);
                aps.put("alert", alert);
                aps.put("sound", "default");
                
                message.put("apns", apns);
                // ... rest of FCM code ...
                
            } else {
                // Android device
                // ... existing Android FCM code ...
            }
            
            // Send FCM request
            sendFCMRequest(notificationJson);
            
        } catch (Exception e) {
            e.printStackTrace();
        }
    });
}
```

---

## Database Changes Required

### Add VoIP Token Column

**Table:** `users` (or wherever you store device tokens)

**New Column:**
```sql
ALTER TABLE users 
ADD COLUMN voip_token VARCHAR(255);
```

**Usage:**
- Store VoIP token separately from FCM token
- Use VoIP token ONLY for call notifications to iOS
- Use FCM token for everything else

---

## iOS App Change Required

### Send VoIP Token to Backend

**File:** `Enclosure/EnclosureApp.swift`

**Currently (Line ~120):**
```swift
VoIPPushManager.shared.onVoIPTokenReceived = { token in
    NSLog("📞 [AppDelegate] VoIP Token received!")
    NSLog("📞 [AppDelegate] Token: \(token)")
    
    // TODO: Send VoIP token to your backend
    // Uncomment when backend endpoint is ready:
    // VoIPPushManager.shared.sendVoIPTokenToBackend()
}
```

**Uncomment this line AFTER backend creates endpoint:**
```swift
VoIPPushManager.shared.sendVoIPTokenToBackend()
```

---

## Backend API Endpoint Needed

### Create: `/api/register_voip_token`

```java
@POST
@Path("/register_voip_token")
public Response registerVoIPToken(
    @FormParam("uid") String userId,
    @FormParam("voip_token") String voipToken
) {
    try {
        // Update database
        String query = "UPDATE users SET voip_token = ? WHERE uid = ?";
        // Execute query...
        
        return Response.ok("VoIP token registered").build();
        
    } catch (Exception e) {
        return Response.status(500).entity("Error: " + e.getMessage()).build();
    }
}
```

---

## What You Need from Apple Developer Portal

### 1. Download APNs Auth Key (.p8 file)

1. Go to https://developer.apple.com
2. **Certificates, Identifiers & Profiles**
3. **Keys** → **+ (New Key)**
4. Name: "VoIP Push Key"
5. Enable: **Apple Push Notifications service (APNs)**
6. Click **Continue** → **Register** → **Download**

**You get:**
- `AuthKey_ABCD1234.p8` ← File
- **Key ID:** `ABCD1234` ← Note this
- **Team ID:** `XYZ9876` ← From Account settings

⚠️ **Download ONCE ONLY! Can't re-download!**

---

## Summary: What Changes Where

| Location | Current | Required |
|----------|---------|----------|
| **iOS App** | ✅ VoIP ready | ✅ Already done! |
| **iOS VoIP Handler** | Line 88-168 `VoIPPushManager.swift` | ✅ Already coded! |
| **Backend Call Sender** | Sends FCM ❌ | Send VoIP Push ✅ |
| **Backend Database** | Only FCM token | Add `voip_token` column |
| **APNs Auth Key** | Don't have | Download .p8 file |

---

## 🎯 Next Steps (In Order)

### Step 1: Get APNs Key (5 minutes)
Download `.p8` file from Apple Developer Portal

### Step 2: Update Backend Code (1-2 hours)
- Add VoIP token field
- Add `sendVoIPPushToAPNs()` method
- Modify `SendNotifications()` to check if iOS call

### Step 3: Update Database (5 minutes)
```sql
ALTER TABLE users ADD COLUMN voip_token VARCHAR(255);
```

### Step 4: Create API Endpoint (30 minutes)
`/api/register_voip_token` to receive VoIP token from iOS

### Step 5: Update iOS App (2 minutes)
Uncomment: `VoIPPushManager.shared.sendVoIPTokenToBackend()`

### Step 6: Test End-to-End
Send test call → **Instant CallKit appears!** 🎉

---

## 💡 Want Detailed Backend Code?

I can create a **complete, ready-to-use Java file** with:
- ✅ Full VoIP push sender
- ✅ JWT token generator
- ✅ APNs integration
- ✅ Error handling

**Should I create it?** Just say "yes, create backend code"! 😊