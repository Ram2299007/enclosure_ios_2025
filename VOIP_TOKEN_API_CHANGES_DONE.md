# ✅ VoIP Token Added to verify_mobile_otp API

## 🎉 iOS Code Changes Complete!

The iOS app now sends **both tokens** to the backend:
- ✅ **FCM Token** (`f_token`) - For chat notifications
- ✅ **VoIP Token** (`voip_token`) - For call notifications

---

## 📱 iOS Changes Made

### **1. File: `VerifyMobileOTPViewModel.swift`**

#### **Change 1: Function Signature (Line 16)**
```swift
// BEFORE:
func verifyOTP(uid: String, otp: String, cCode: String, token: String, deviceId: String)

// AFTER:
func verifyOTP(uid: String, otp: String, cCode: String, token: String, deviceId: String, voipToken: String? = nil)
```

#### **Change 2: Get VoIP Token (Line 122-129)**
```swift
// Get VoIP token from VoIPPushManager or use passed token
let currentVoIPToken = voipToken ?? VoIPPushManager.shared.getVoIPToken() ?? ""

print("🔑 [VERIFY_OTP] Sending tokens to backend:")
print("🔑 [VERIFY_OTP]   - FCM Token: \(finalToken == "apns_missing" ? "apns_missing" : "\(finalToken.prefix(20))...")")
print("🔑 [VERIFY_OTP]   - VoIP Token: \(currentVoIPToken.isEmpty ? "EMPTY - will be sent later" : "\(currentVoIPToken.prefix(20))...")")
```

#### **Change 3: Add to API Parameters (Line 137)**
```swift
let params: [String: String] = [
    "uid": uid,
    "mob_otp": otp,
    "f_token": finalToken,              // ← FCM token
    "voip_token": currentVoIPToken,     // ← VoIP token 🆕
    "device_id": deviceId,
    "phone_id": phoneId,
    "country_code": cCode,
    "device_type": "2"
]
```

---

### **2. File: `whatsTheCode.swift`**

#### **Change: Pass VoIP Token (Line 705-731)**
```swift
// Get VoIP token from VoIPPushManager
let voipToken = VoIPPushManager.shared.getVoIPToken() ?? ""

// Pass to verifyOTP
verifyViewModel.verifyOTP(
    uid: uid,
    otp: otp.joined(),
    cCode: country_Code,
    token: fcmToken,      // ← FCM token
    deviceId: deviceId,
    voipToken: voipToken  // ← VoIP token 🆕
)
```

---

## 🔧 Backend Changes Needed

### **Step 1: Update `verify_mobile_otp` API (PHP)**

**Location:** Your PHP backend API endpoint

**Current code (approximate):**
```php
// Receive parameters
$uid = $_POST['uid'];
$mob_otp = $_POST['mob_otp'];
$f_token = $_POST['f_token'];        // FCM token
$device_id = $_POST['device_id'];
$phone_id = $_POST['phone_id'];
$country_code = $_POST['country_code'];
$device_type = $_POST['device_type'];

// Update database
$query = "UPDATE user_details 
          SET fcm_token = ?, device_type = ? 
          WHERE uid = ?";
```

---

**NEW code (add VoIP token):**
```php
// Receive parameters
$uid = $_POST['uid'];
$mob_otp = $_POST['mob_otp'];
$f_token = $_POST['f_token'];          // FCM token (Chat)
$voip_token = $_POST['voip_token'];    // VoIP token (Calls) 🆕
$device_id = $_POST['device_id'];
$phone_id = $_POST['phone_id'];
$country_code = $_POST['country_code'];
$device_type = $_POST['device_type'];

// Verify OTP...
if ($otp_valid) {
    // Update database with BOTH tokens
    if ($device_type == "2") {
        // iOS device - save both FCM and VoIP tokens
        $query = "UPDATE user_details 
                  SET fcm_token = ?, 
                      voip_token = ?,     -- 🆕 Add VoIP token
                      device_type = ? 
                  WHERE uid = ?";
        
        $stmt = $conn->prepare($query);
        $stmt->bind_param("ssss", $f_token, $voip_token, $device_type, $uid);
        $stmt->execute();
        
        // Log for debugging
        error_log("✅ Updated FCM token: " . substr($f_token, 0, 20) . "...");
        error_log("✅ Updated VoIP token: " . substr($voip_token, 0, 20) . "...");
        
        // Return success
        echo json_encode([
            'error_code' => '200',
            'message' => 'OTP verified successfully',
            'data' => [[
                'uid' => $uid,
                'mobile_no' => $mobile_no,
                'f_token' => $f_token,
                'voip_token' => $voip_token,  // 🆕 Include in response
                'device_type' => $device_type
            ]]
        ]);
    } else {
        // Android device - only FCM token
        $query = "UPDATE user_details 
                  SET fcm_token = ?, 
                      device_type = ? 
                  WHERE uid = ?";
        
        $stmt = $conn->prepare($query);
        $stmt->bind_param("sss", $f_token, $device_type, $uid);
        $stmt->execute();
    }
}
```

---

### **Step 2: Update `FcmNotificationsSender.java` (Android Backend)**

**Remove hardcoded VoIP token and fetch from database:**

**BEFORE (Line 89-138):**
```java
// Hardcoded token ❌
String voipToken = "416951db5bb2d8dd836060f8deb6725e049e048c1f41669b9f8fc94500b689e6";
```

---

**AFTER:**
```java
// Get VoIP token from database ✅
String voipToken = getVoIPTokenFromDatabase(receiverId);

if (voipToken == null || voipToken.isEmpty()) {
    System.err.println("❌ [VOIP] No VoIP token for user: " + receiverId);
    System.err.println("❌ [VOIP] User needs to login from iOS app first");
    return;  // Can't send VoIP push
}

System.out.println("✅ [VOIP] Got VoIP token from database: " + voipToken.substring(0, 20) + "...");

// Validate token format (64 hex characters)
if (!voipToken.matches("[0-9a-fA-F]{64}")) {
    System.err.println("❌ [VOIP] Invalid VoIP token format!");
    return;
}

// Send VoIP push
sendVoIPPushToAPNs(voipToken, callerName, roomId, receiverId, photo, phone, callType);
```

---

**Add database method:**
```java
private String getVoIPTokenFromDatabase(String userId) {
    try {
        // Your database connection
        Connection conn = getConnection();
        String query = "SELECT voip_token FROM user_details WHERE uid = ?";
        PreparedStatement stmt = conn.prepareStatement(query);
        stmt.setString(1, userId);
        ResultSet rs = stmt.executeQuery();
        
        if (rs.next()) {
            String token = rs.getString("voip_token");
            return token;
        }
        
        return null;
    } catch (Exception e) {
        System.err.println("❌ [VOIP] Database error: " + e.getMessage());
        e.printStackTrace();
        return null;
    }
}
```

---

## 📊 Complete Flow After Changes

### **1. User Login (iOS):**

```
iOS App (whatsTheCode.swift)
    ↓
User enters OTP
    ↓
verifyOTP() called with:
    - fcmToken = "cWXCYutVCE..."  (Chat)
    - voipToken = "416951db5bb2d..."  (Calls)
    ↓
POST to verify_mobile_otp API
    ↓
Backend saves BOTH tokens in database:
    user_details.fcm_token = "cWXCYutVCE..."
    user_details.voip_token = "416951db5bb2d..."
    ↓
✅ User registered successfully!
```

---

### **2. Incoming Call:**

```
Android user calls iOS user (receiverId = "2")
    ↓
Backend (FcmNotificationsSender.java)
    ↓
Gets receiver's tokens from database:
    - fcmToken = "cWXCYutVCE..."  (for chat)
    - voipToken = "416951db5bb2d..."  (for calls)
    ↓
Checks notification type:
    - Is VOICE_CALL or VIDEO_CALL? → Use voipToken
    - Is chat message? → Use fcmToken
    ↓
Sends VoIP push to APNs with correct voipToken
    ↓
🎉 iOS shows INSTANT CALLKIT!
```

---

## 🔍 Testing Instructions

### **Test 1: Login from iOS**

1. Open iOS app
2. Enter phone number and OTP
3. Check backend logs:
   ```
   ✅ Received f_token: cWXCYutVCE...
   ✅ Received voip_token: 416951db5bb2d...
   ✅ Updated database
   ```

4. Verify in MySQL:
   ```sql
   SELECT uid, fcm_token, voip_token, device_type 
   FROM user_details 
   WHERE uid = '2';
   ```
   
   Expected:
   ```
   uid | fcm_token       | voip_token      | device_type
   2   | cWXCYutVCE...   | 416951db5bb2d... | 2
   ```

---

### **Test 2: Make Call to iOS**

1. Login as Android user
2. Call iOS user (uid = 2)
3. Check Android backend logs:
   ```
   📞 [VOIP] Detected CALL notification for iOS!
   📞 [VOIP] Getting VoIP token from database for user: 2
   ✅ [VOIP] Got VoIP token: 416951db5bb2d...
   📞 [VOIP] Sending VoIP Push to APNs...
   📞 [VOIP] APNs Response Status: 200
   ✅ [VOIP] VoIP Push sent successfully!
   ```

4. **Expected Result:** iOS device shows INSTANT CallKit screen! 🎉

---

## 🎯 What's Done vs What's Needed

### ✅ Done (iOS):
- [x] Add `voipToken` parameter to `verifyOTP()`
- [x] Get VoIP token from `VoIPPushManager`
- [x] Send VoIP token in API request
- [x] Add logging for debugging

### ⏳ Pending (Backend):
- [ ] Update PHP `verify_mobile_otp` API to receive `voip_token`
- [ ] Save `voip_token` in database (table already has column!)
- [ ] Update Java `FcmNotificationsSender.java` to fetch token from DB
- [ ] Remove hardcoded VoIP token
- [ ] Test end-to-end flow

---

## 📝 Quick Backend Implementation Checklist

```
1. ✅ Add voip_token column to database (DONE!)
   ALTER TABLE user_details ADD COLUMN voip_token VARCHAR(255);

2. ⏳ Update verify_mobile_otp API (PHP)
   - Add: $voip_token = $_POST['voip_token'];
   - Update: SET voip_token = ? in UPDATE query

3. ⏳ Add getVoIPTokenFromDatabase() method (Java)
   - Query: SELECT voip_token FROM user_details WHERE uid = ?

4. ⏳ Use dynamic token instead of hardcoded (Java)
   - Replace: String voipToken = "416951db5bb2d...";
   - With: String voipToken = getVoIPTokenFromDatabase(receiverId);

5. ⏳ Test login and call
   - Login from iOS → Check database has token
   - Call from Android → Check CallKit appears
```

---

## 🎉 Summary

**iOS is ready!** The app now sends VoIP token to backend during login.

**Backend needs 3 simple changes:**
1. Receive `voip_token` in verify_mobile_otp API ✅ (2 minutes)
2. Save it in database ✅ (2 minutes)
3. Fetch it when sending calls ✅ (5 minutes)

**Total time:** ~10 minutes of backend work, then you're done! 🚀

---

**Need help with backend code? Let me know!** 💪
