# ✅ TODO: Complete VoIP Push Implementation

## 🎯 Changes Already Applied

✅ iOS `MessageUploadService.swift` - Modified to send VoIP push
✅ Android `FcmNotificationsSender.java` - Modified to send VoIP push
✅ Code structure ready for VoIP push

---

## ⚠️ What You MUST Do Now

### 🔑 STEP 1: Get APNs Auth Key (15 minutes)

**Go to:** https://developer.apple.com/account

1. Click **Certificates, Identifiers & Profiles**
2. Click **Keys** → **+ (Create a Key)**
3. Name: **"VoIP Push Key"**
4. Enable: **Apple Push Notifications service (APNs)**
5. Click **Continue** → **Register** → **Download**

**Save these values:**
```
File: AuthKey_ABCD1234.p8    ← Download this file!
Key ID: ABCD1234EF            ← Copy this!
Team ID: XYZ9876543           ← Copy from Account page!
```

⚠️ **IMPORTANT:** You can only download the `.p8` file ONCE! Don't lose it!

---

### 💻 STEP 2: Implement JWT Token in iOS

**File:** `Enclosure/Utility/MessageUploadService.swift`

**Find the method:** `createAPNsJWT()` (around line 1103)

**Replace with:**

```swift
private func createAPNsJWT() -> String? {
    // ✏️ REPLACE THESE WITH YOUR VALUES:
    let keyId = "ABCD1234EF"        // ← From Apple Portal
    let teamId = "XYZ9876543"       // ← From Apple Portal
    let privateKey = """
    -----BEGIN PRIVATE KEY-----
    MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg...
    ← PASTE CONTENT FROM AuthKey_ABCD1234.p8 FILE HERE
    -----END PRIVATE KEY-----
    """
    
    let now = Int(Date().timeIntervalSince1970)
    
    // Create JWT header
    let header: [String: Any] = [
        "alg": "ES256",
        "kid": keyId
    ]
    
    // Create JWT claims
    let claims: [String: Any] = [
        "iss": teamId,
        "iat": now
    ]
    
    // TODO: Implement ES256 signing
    // For quick test: Use jwt.io to generate token manually
    // For production: Use a JWT library or implement ES256 signing
    
    // TEMPORARY: Manually generated token for testing
    return "eyJ0eXAiOiJKV1QiLCJhbGciOiJFUzI1NiIsImtpZCI6IkFCQ0QxMjM0In0..."
}
```

**Quick Test Option:** Generate token at https://jwt.io
- Algorithm: ES256
- Header: `{"alg": "ES256", "kid": "YOUR_KEY_ID"}`
- Payload: `{"iss": "YOUR_TEAM_ID", "iat": 1234567890}`
- Use your private key from .p8 file

---

### 💻 STEP 3: Implement JWT Token in Android

**File:** `FcmNotificationsSender.java`

**Find the method:** `createAPNsJWT()` (around line 180)

**Replace with:**

```java
private String createAPNsJWT() {
    // ✏️ REPLACE THESE WITH YOUR VALUES:
    String keyId = "ABCD1234EF";        // ← From Apple Portal
    String teamId = "XYZ9876543";       // ← From Apple Portal
    String privateKey = 
        "-----BEGIN PRIVATE KEY-----\n" +
        "MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg...\n" +
        "← PASTE CONTENT FROM AuthKey_ABCD1234.p8 FILE HERE\n" +
        "-----END PRIVATE KEY-----";
    
    try {
        long now = System.currentTimeMillis() / 1000;
        
        // Create JWT header
        JSONObject header = new JSONObject();
        header.put("alg", "ES256");
        header.put("kid", keyId);
        
        // Create JWT claims
        JSONObject claims = new JSONObject();
        claims.put("iss", teamId);
        claims.put("iat", now);
        
        // TODO: Implement ES256 signing
        // See BACKEND_VOIP_IMPLEMENTATION.md for complete code with:
        // - Base64 URL encoding
        // - ES256 signature generation
        // - Private key parsing
        
        // TEMPORARY: Return manually generated token for testing
        return "eyJ0eXAiOiJKV1QiLCJhbGciOiJFUzI1NiIsImtpZCI6IkFCQ0QxMjM0In0...";
        
    } catch (Exception e) {
        System.err.println("❌ [JWT] Error: " + e.getMessage());
        return null;
    }
}
```

**For complete ES256 implementation:** See `BACKEND_VOIP_IMPLEMENTATION.md` (STEP 5)

---

### 🗄️ STEP 4: Database Changes

**Run this SQL:**

```sql
ALTER TABLE users 
ADD COLUMN voip_token VARCHAR(255);
```

**Create PHP API endpoint:** (or your backend language)

```php
// File: api/register_voip_token.php

<?php
$uid = $_POST['uid'];
$voip_token = $_POST['voip_token'];

$query = "UPDATE users SET voip_token = ? WHERE uid = ?";
$stmt = $conn->prepare($query);
$stmt->bind_param("ss", $voip_token, $uid);
$stmt->execute();

echo json_encode([
    "error_code" => 200,
    "message" => "VoIP token registered successfully"
]);
?>
```

---

### 📱 STEP 5: Enable iOS VoIP Token Sender

**File:** `Enclosure/EnclosureApp.swift`

**Find:** Around line 120

**Change from:**
```swift
VoIPPushManager.shared.onVoIPTokenReceived = { token in
    NSLog("📞 [AppDelegate] VoIP Token received!")
    // VoIPPushManager.shared.sendVoIPTokenToBackend()  // ← COMMENTED!
}
```

**To:**
```swift
VoIPPushManager.shared.onVoIPTokenReceived = { token in
    NSLog("📞 [AppDelegate] VoIP Token received!")
    VoIPPushManager.shared.sendVoIPTokenToBackend()  // ✅ ENABLED!
}
```

---

### 🔧 STEP 6: Update VoIP Token Retrieval

**Currently:** Code uses FCM token as placeholder

**You need to:** Retrieve actual VoIP token from database

#### In iOS (MessageUploadService.swift - Line ~920):

**Find:**
```swift
voipToken: deviceToken,  // TODO: Use separate voipToken
```

**Change to:**
```swift
voipToken: getVoIPTokenForUser(receiverId) ?? deviceToken,
```

**Then implement:**
```swift
private func getVoIPTokenForUser(_ userId: String) -> String? {
    // Get from database via ChatCacheManager or API call
    // For now, return nil to use deviceToken as fallback
    return nil
}
```

#### In Android (FcmNotificationsSender.java - Line ~177):

**Find:**
```java
String voipToken = userFcmToken;  // TODO: Get from database
```

**Change to:**
```java
String voipToken = getVoIPTokenFromDatabase(callerId);
if (voipToken == null || voipToken.isEmpty()) {
    voipToken = userFcmToken;  // Fallback
}
```

**Then implement:**
```java
private String getVoIPTokenFromDatabase(String userId) {
    // Query database: SELECT voip_token FROM users WHERE uid = ?
    return null;  // Replace with actual query
}
```

---

## 🧪 Testing Steps

### After Implementing JWT (MINIMUM requirement):

1. **Build and run iOS app**
2. **Check logs for VoIP token:**
   ```
   📞 [VoIP] VoIP Token: 416951db5bb2d8dd...
   ```
3. **Put app in background**
4. **Send call from Android device**
5. **Check backend logs:**
   ```
   📞 [VOIP] Detected CALL notification for iOS!
   📞 [VOIP] Sending VoIP Push to APNs...
   ✅ [VOIP] VoIP Push sent SUCCESSFULLY!
   ```
6. **Check iOS device:**
   ```
   🎉 INSTANT FULL-SCREEN CALLKIT APPEARS!
   ```

---

## 🎯 Checklist

### Minimum to Make it Work:

- [ ] Download APNs Auth Key (.p8 file)
- [ ] Copy Key ID and Team ID
- [ ] Implement `createAPNsJWT()` in iOS (even with manual token)
- [ ] Implement `createAPNsJWT()` in Android (even with manual token)
- [ ] Test with background call

### For Production:

- [ ] Add `voip_token` column to database
- [ ] Create API endpoint to receive VoIP token
- [ ] Uncomment VoIP token sender in iOS
- [ ] Implement VoIP token retrieval from database
- [ ] Implement proper ES256 JWT signing (not manual)
- [ ] Test all scenarios (background, lock screen, terminated)

---

## 📊 Priority Order

### HIGH PRIORITY (Do First):
1. ✅ Get APNs Auth Key - **15 minutes**
2. ✅ Implement JWT in iOS (manual token OK for testing) - **30 minutes**
3. ✅ Implement JWT in Android (manual token OK for testing) - **30 minutes**
4. ✅ Test background call - **5 minutes**

### MEDIUM PRIORITY (Do Next):
5. ✅ Add database column - **5 minutes**
6. ✅ Create API endpoint - **15 minutes**
7. ✅ Enable iOS token sender - **2 minutes**
8. ✅ Test with real VoIP token - **10 minutes**

### LOW PRIORITY (Do Later):
9. ✅ Implement proper ES256 signing - **2 hours**
10. ✅ Add error handling and retries - **1 hour**
11. ✅ Add analytics and monitoring - **1 hour**

---

## 🚀 Quick Start (30 minutes)

**Fastest way to test VoIP push:**

1. **Get APNs Key** (15 min)
   - Download from Apple Portal
   
2. **Generate JWT Token** (5 min)
   - Go to https://jwt.io
   - Algorithm: ES256
   - Header: `{"alg": "ES256", "kid": "YOUR_KEY_ID"}`
   - Payload: `{"iss": "YOUR_TEAM_ID", "iat": 1707393600}`
   - Paste your private key
   - Copy generated token
   
3. **Hardcode JWT** (5 min)
   - Paste token in `createAPNsJWT()` methods
   - Return that token
   
4. **Test!** (5 min)
   - Build iOS app
   - Background it
   - Send call from Android
   - **See instant CallKit!** 🎉

---

## 📞 Need Help?

**Reference Documents:**
- `BACKEND_VOIP_IMPLEMENTATION.md` - Complete implementation guide
- `VOIP_CHANGES_APPLIED.md` - Summary of changes made
- `BACKEND_CHANGES_SUMMARY.md` - Executive summary

**Common Issues:**
- **403 Error:** Invalid JWT token or wrong Key ID/Team ID
- **410 Error:** Invalid VoIP token (not registered)
- **No response:** Check APNs URL (sandbox vs production)

---

## 🎉 Success Criteria

**You know it's working when:**

✅ Backend logs show: "✅ [VOIP] VoIP Push sent SUCCESSFULLY!"
✅ iOS logs show: "📞 [VoIP] INCOMING VOIP PUSH RECEIVED!"
✅ iOS shows instant full-screen CallKit in background
✅ No banner notification appears
✅ User doesn't need to tap anything
✅ Works in lock screen and terminated states

---

**Your code is 90% ready! Just need APNs Auth Key and JWT implementation!** 🚀

**FOCUS ON: Getting APNs Key + JWT token FIRST. Everything else can wait!**
