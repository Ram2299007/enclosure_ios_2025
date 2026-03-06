# VoIP Push Backend Setup Guide

## 🎯 Goal: WhatsApp-Style Instant CallKit

With VoIP pushes, CallKit will appear **IMMEDIATELY** in all app states:
- ✅ Foreground: Instant CallKit (no banner)
- ✅ Background: Instant CallKit (no banner, no tap required)
- ✅ Lock Screen: Instant CallKit (full-screen call UI)
- ✅ Terminated: iOS wakes app, instant CallKit

**Just like WhatsApp!**

## Step 1: Get iOS VoIP Token

### A. Add VoIPPushManager.swift to Xcode

**CRITICAL:** The file `Enclosure/Utility/VoIPPushManager.swift` exists but needs to be added to Xcode:

1. Open Xcode project
2. Right-click on `Enclosure/Utility` folder
3. Select "Add Files to Enclosure..."
4. Navigate to `/Users/ramlohar/XCODE_PROJECT/enclosure_ios_2025/Enclosure/Utility/`
5. Select `VoIPPushManager.swift`
6. Make sure "Copy items if needed" is **UNCHECKED** (file already in place)
7. Make sure your target is **CHECKED**
8. Click "Add"

### B. Build and Run iOS App

1. Clean build: ⌘ + Shift + K
2. Build: ⌘ + B
3. Run on device (VoIP doesn't work on simulator!)
4. Check Console for VoIP token:

```
📞 [VoIP] ========================================
📞 [VoIP] VoIP PUSH TOKEN RECEIVED!
📞 [VoIP] ========================================
📞 [VoIP] Token: a1b2c3d4e5f6...  (64 characters)
```

5. **Copy this token** - you'll need it for testing

## Step 2: Backend Changes Required

### Understanding the Flow

**Current (Regular Push):**
```
Backend → FCM → APNs → iOS → Notification banner → User taps → CallKit
```

**VoIP Push (New):**
```
Backend → APNs VoIP endpoint → iOS → App wakes → CallKit instantly!
```

### Key Differences

| Aspect | Regular Push | VoIP Push |
|--------|--------------|-----------|
| **Endpoint** | FCM API | APNs directly |
| **Token** | FCM token (Firebase) | VoIP token (PushKit) |
| **Authentication** | Firebase server key | Apple APNs auth key (.p8 file) |
| **Payload** | Has `aps` block | NO `aps` block (data only!) |
| **Priority** | Normal | Highest |
| **Wakes app** | ❌ No | ✅ Yes |

### What You Need from Apple

1. **APNs Authentication Key (.p8 file)**
   - Sign in to https://developer.apple.com/account
   - Go to: Certificates, Identifiers & Profiles
   - Click Keys → "+" to create new key
   - Name it: "Enclosure VoIP Push Key"
   - Enable: "Apple Push Notification service (APNs)"
   - Click "Continue" → "Register"
   - **Download the .p8 file** (you can only download ONCE!)
   - Save these values:
     - **Key ID** (10 characters, shown in portal)
     - **Team ID** (10 characters, shown in portal)
     - **Bundle ID**: `com.enclosure` (or your actual bundle ID)

## Step 3: Backend Implementation Options

### Option A: Java with java-apns Library (Recommended)

**Add dependency to your Android project:**

```gradle
// In app/build.gradle
dependencies {
    implementation 'com.github.notnoop.apns:apns:1.0.0.Beta6'
}
```

**Java code:**

```java
import com.notnoop.apns.APNS;
import com.notnoop.apns.ApnsService;
import com.notnoop.apns.PayloadBuilder;
import java.io.File;

public class VoIPPushSender {
    
    private static ApnsService voipService;
    
    // Initialize once at app startup
    public static void initialize() {
        try {
            // Path to your .p8 auth key file
            String p8FilePath = "/path/to/your/AuthKey_XXXXXXXXXX.p8";
            String keyId = "YOUR_KEY_ID";      // 10 characters
            String teamId = "YOUR_TEAM_ID";    // 10 characters
            String bundleId = "com.enclosure";
            
            // For PRODUCTION (live app)
            String apnsEndpoint = "api.push.apple.com";
            
            // For TESTING (sandbox/TestFlight)
            // String apnsEndpoint = "api.sandbox.push.apple.com";
            
            voipService = APNS.newService()
                .withApnsDestination(apnsEndpoint, 443)
                .withTokenAuthentication(p8FilePath, keyId, teamId, bundleId)
                .build();
            
            System.out.println("✅ VoIP Push Service initialized");
            
        } catch (Exception e) {
            System.err.println("❌ Failed to initialize VoIP Push: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    // Send VoIP push notification
    public static boolean sendVoIPPush(
        String voipToken,
        String callerName,
        String callerPhoto,
        String roomId,
        String receiverId,
        String receiverPhone,
        String bodyKey
    ) {
        try {
            if (voipService == null) {
                System.err.println("❌ VoIP service not initialized!");
                return false;
            }
            
            System.out.println("📞 [VoIP] Sending VoIP push to: " + voipToken.substring(0, 10) + "...");
            
            // CRITICAL: VoIP payload has NO "aps" block!
            // Just send data directly
            JSONObject payload = new JSONObject();
            payload.put("name", callerName);
            payload.put("photo", callerPhoto);
            payload.put("roomId", roomId);
            payload.put("receiverId", receiverId);
            payload.put("phone", receiverPhone);
            payload.put("bodyKey", bodyKey);  // "Incoming voice call" or "Incoming video call"
            
            System.out.println("📤 [VoIP] Payload: " + payload.toString());
            
            // Convert token from hex string to byte array
            byte[] tokenBytes = hexStringToByteArray(voipToken);
            
            // Send push
            voipService.push(tokenBytes, payload.toString());
            
            System.out.println("✅ [VoIP] Push sent successfully!");
            return true;
            
        } catch (Exception e) {
            System.err.println("❌ [VoIP] Failed to send push: " + e.getMessage());
            e.printStackTrace();
            return false;
        }
    }
    
    // Helper to convert hex token to bytes
    private static byte[] hexStringToByteArray(String s) {
        int len = s.length();
        byte[] data = new byte[len / 2];
        for (int i = 0; i < len; i += 2) {
            data[i / 2] = (byte) ((Character.digit(s.charAt(i), 16) << 4)
                                 + Character.digit(s.charAt(i+1), 16));
        }
        return data;
    }
}
```

**Update your existing FcmNotificationsSender.java:**

```java
// In FcmNotificationsSender.java, update your voice/video call methods:

public void sendVoiceCallNotification(...) {
    // Get device type
    String deviceType = ...; // from your database
    
    if (deviceType.equals("1")) {
        // Android device - use existing FCM code
        sendFCMNotification(...);
    } else {
        // iOS device - use VoIP push!
        String voipToken = ...; // Get from database (stored separately from FCM token)
        
        boolean success = VoIPPushSender.sendVoIPPush(
            voipToken,
            callerName,
            callerPhoto,
            roomId,
            receiverId,
            receiverPhone,
            "Incoming voice call"  // bodyKey
        );
        
        if (success) {
            System.out.println("✅ VoIP push sent to iOS device");
        } else {
            System.err.println("❌ VoIP push failed - falling back to FCM");
            // Fallback to regular FCM if VoIP fails
            sendFCMNotification(...);
        }
    }
}
```

### Option B: Direct HTTP/2 API (More Control)

If you want to use raw HTTP/2 API instead of a library:

**Endpoint:**
```
Production: https://api.push.apple.com/3/device/{voipToken}
Sandbox: https://api.sandbox.push.apple.com/3/device/{voipToken}
```

**Headers:**
```
apns-topic: com.enclosure.voip   (your bundle ID + .voip)
apns-push-type: voip
apns-priority: 10
authorization: bearer {JWT_TOKEN}
```

**JWT Token Generation:**
```java
// You need to generate JWT using your .p8 key
// Libraries: io.jsonwebtoken:jjwt
```

**Body (JSON):**
```json
{
  "name": "Priti Lohar",
  "photo": "https://...",
  "roomId": "EnclosurePowerfulNext1234",
  "receiverId": "2",
  "phone": "+918379887185",
  "bodyKey": "Incoming voice call"
}
```

**Important:** NO `aps` block in VoIP pushes!

## Step 4: Database Changes

You need to store **TWO tokens per iOS user**:

| Field | Purpose | Example |
|-------|---------|---------|
| `fcm_token` | For chat notifications | `cWXCYutV...` |
| `voip_token` | For call notifications | `a1b2c3d4...` |

**Update your database schema:**

```sql
ALTER TABLE users ADD COLUMN voip_token VARCHAR(255);
```

**iOS app will send both tokens to backend:**
- FCM token: From Firebase (existing)
- VoIP token: From PushKit (new - see next step)

## Step 5: iOS App Backend API Integration

### A. Create Backend Endpoint

Create API endpoint to receive VoIP token from iOS:

```
POST /api/register-voip-token
```

**Request body:**
```json
{
  "userId": "2",
  "voipToken": "a1b2c3d4e5f6...",
  "deviceType": "iOS"
}
```

**Response:**
```json
{
  "success": true,
  "message": "VoIP token registered"
}
```

### B. Update iOS App to Send VoIP Token

In `VoIPPushManager.swift`, update the `sendVoIPTokenToBackend()` method:

```swift
func sendVoIPTokenToBackend() {
    guard let token = voipToken else {
        NSLog("⚠️ [VoIP] No token to send")
        return
    }
    
    guard let url = URL(string: "https://confidential.enclosureapp.com/register_voip_token") else {
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    // Get current user ID from UserDefaults
    let userId = UserDefaults.standard.string(forKey: "userId") ?? ""
    
    let body: [String: Any] = [
        "userId": userId,
        "voipToken": token,
        "deviceType": "iOS"
    ]
    
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            NSLog("❌ [VoIP] Failed to send token: \(error)")
            return
        }
        NSLog("✅ [VoIP] Token sent to backend successfully")
    }.resume()
}
```

Then uncomment this line in `EnclosureApp.swift`:

```swift
VoIPPushManager.shared.onVoIPTokenReceived = { token in
    // ...
    VoIPPushManager.shared.sendVoIPTokenToBackend()  // UNCOMMENT THIS
}
```

## Step 6: Testing VoIP Pushes

### Quick Test with cURL (Before Full Backend Implementation)

You can test VoIP pushes immediately using cURL:

1. **Get your VoIP token from iOS logs**
2. **Generate JWT token** (see online JWT generators for APNs)
3. **Send test push:**

```bash
# Replace placeholders:
# - {voipToken}: VoIP token from iOS
# - {JWT}: Generated JWT token
# - api.sandbox.push.apple.com for TestFlight/debug

curl -v \
  --http2 \
  --header "apns-topic: com.enclosure.voip" \
  --header "apns-push-type: voip" \
  --header "apns-priority: 10" \
  --header "authorization: bearer {JWT}" \
  --data '{
    "name": "Test Caller",
    "photo": "",
    "roomId": "TestRoom123",
    "receiverId": "2",
    "phone": "+911234567890",
    "bodyKey": "Incoming voice call"
  }' \
  https://api.sandbox.push.apple.com/3/device/{voipToken}
```

**Expected response:**
```json
{"apns-id":"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"}
```

**On iOS device:**
- CallKit full-screen UI appears INSTANTLY
- Even if app is in background or lock screen!

### Full Integration Test

1. **Register VoIP Token:**
   - iOS app sends VoIP token to backend
   - Backend stores in database

2. **Initiate Call:**
   - User A calls User B
   - Backend looks up User B's VoIP token
   - Backend sends VoIP push to APNs

3. **Verify CallKit:**
   - User B's device: CallKit appears instantly
   - Check iOS logs for success messages

## Step 7: Troubleshooting

### VoIP Token Not Received on iOS

Check:
- ✅ VoIPPushManager.swift added to Xcode project?
- ✅ Running on REAL device (not simulator)?
- ✅ `UIBackgroundModes` includes `voip` in Info.plist?

### VoIP Push Not Received

Check:
- ✅ Using correct APNs endpoint (sandbox vs production)?
- ✅ JWT token generated correctly?
- ✅ Bundle ID matches: `com.enclosure.voip`?
- ✅ VoIP token is correct (64 hex characters)?
- ✅ Payload has NO `aps` block?

### CallKit Not Appearing

Check iOS logs:
```
📞 [VoIP] INCOMING VOIP PUSH RECEIVED!
📞 [VoIP] Reporting call to CallKit NOW...
✅ [VoIP] CallKit call reported successfully!
```

If not seeing these logs:
- VoIP push not reaching iOS app
- Check APNs delivery

### APNs Response Errors

| Error | Meaning | Solution |
|-------|---------|----------|
| `BadDeviceToken` | Token invalid/expired | Get new token from device |
| `TopicDisallowed` | Wrong apns-topic | Use `{bundleId}.voip` |
| `BadCertificate` | Auth issue | Check .p8 key and JWT |

## Summary: What Changes Are Needed

### iOS App Changes (Done!)
- ✅ VoIPPushManager.swift created
- ✅ EnclosureApp.swift updated
- ⚠️ Need to add file to Xcode project
- ⚠️ Need to implement backend API integration

### Backend Changes (You Need to Do)
1. ⚠️ Get APNs auth key (.p8) from Apple
2. ⚠️ Add java-apns library or HTTP/2 client
3. ⚠️ Implement VoIP push sending
4. ⚠️ Create database column for VoIP tokens
5. ⚠️ Create API endpoint to receive VoIP tokens
6. ⚠️ Update call notification logic to use VoIP for iOS

### Estimated Implementation Time
- iOS: ✅ Done (just add file to Xcode)
- Backend: 2-4 hours
- Testing: 1 hour
- **Total: 3-5 hours**

## Next Steps

1. **Add VoIPPushManager.swift to Xcode** (see Step 1A above)
2. **Build and run iOS app** to get VoIP token
3. **Get APNs auth key** from Apple Developer Portal
4. **Implement backend VoIP push** (use java-apns library)
5. **Test with cURL first** to verify APNs connectivity
6. **Integrate into your existing call flow**
7. **Test end-to-end** from both devices

---

**Result:** WhatsApp-style instant CallKit in all app states! 🎉
