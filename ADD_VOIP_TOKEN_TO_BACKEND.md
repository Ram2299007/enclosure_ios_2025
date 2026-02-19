# ✅ Found: FCM Token API - Add VoIP Token Here!

## 🔍 Current Setup (FCM Token)

### **iOS File:** `whatsTheCode.swift`

**Line 713-729:** Calls `verifyOTP()` with FCM token:
```swift
verifyViewModel.verifyOTP(
    uid: uid,
    otp: otp.joined(),
    cCode: country_Code,
    token: fcmToken,  // ← FCM token पाठवतो
    deviceId: deviceId
)
```

---

### **iOS File:** `VerifyMobileOTPViewModel.swift`

**Line 20:** API Endpoint
```swift
let urlString = Constant.baseURL + "verify_mobile_otp"  // ← हा API
```

**Line 128-136:** Parameters sent to backend
```swift
let params: [String: String] = [
    "uid": uid,
    "mob_otp": otp,
    "f_token": finalToken,      // ← FCM token (Chat साठी) ✅
    "device_id": deviceId,
    "phone_id": phoneId,
    "country_code": cCode,
    "device_type": "2"           // iOS
]
```

**Backend API:** `verify_mobile_otp`

**Receives:**
- ✅ `f_token` = FCM token (Chat साठी)
- ❌ VoIP token नाही (Calls साठी हवं!)

---

## ✅ Solution: Add VoIP Token to Same API

### Option 1: Add to `verify_mobile_otp` API (RECOMMENDED)

तुम्ही **same API** मध्ये VoIP token add करू शकता!

---

## 🔧 iOS Code Changes

### **File:** `VerifyMobileOTPViewModel.swift`

**Line 16:** Update function signature:

**BEFORE:**
```swift
func verifyOTP(uid: String, otp: String, cCode: String, token: String, deviceId: String) {
```

**AFTER:**
```swift
func verifyOTP(uid: String, otp: String, cCode: String, token: String, deviceId: String, voipToken: String? = nil) {
```

---

**Line 128-136:** Add VoIP token to parameters:

**BEFORE:**
```swift
let params: [String: String] = [
    "uid": uid,
    "mob_otp": otp,
    "f_token": finalToken,
    "device_id": deviceId,
    "phone_id": phoneId,
    "country_code": cCode,
    "device_type": "2"
]
```

**AFTER:**
```swift
// Get VoIP token from VoIPPushManager
let currentVoIPToken = voipToken ?? VoIPPushManager.shared.voipToken ?? ""

var params: [String: String] = [
    "uid": uid,
    "mob_otp": otp,
    "f_token": finalToken,        // ← FCM token (Chat साठी)
    "voip_token": currentVoIPToken, // ← VoIP token (Calls साठी) 🆕
    "device_id": deviceId,
    "phone_id": phoneId,
    "country_code": cCode,
    "device_type": "2"
]

print("🔑 [VERIFY_OTP] Sending tokens to backend:")
print("🔑 [VERIFY_OTP]   - FCM Token: \(finalToken.prefix(20))...")
print("🔑 [VERIFY_OTP]   - VoIP Token: \(currentVoIPToken.isEmpty ? "EMPTY" : "\(currentVoIPToken.prefix(20))...")")
```

---

### **File:** `whatsTheCode.swift`

**Line 713-729:** Pass VoIP token when calling verifyOTP:

**BEFORE:**
```swift
verifyViewModel.verifyOTP(
    uid: uid,
    otp: otp.joined(),
    cCode: country_Code,
    token: fcmToken,
    deviceId: deviceId
)
```

**AFTER:**
```swift
// Get VoIP token from VoIPPushManager
let voipToken = VoIPPushManager.shared.voipToken ?? ""

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

## 🔧 Backend (PHP) Changes

### **API:** `verify_mobile_otp`

**Current code probably looks like:**

```php
$uid = $_POST['uid'];
$mob_otp = $_POST['mob_otp'];
$f_token = $_POST['f_token'];        // FCM token
$device_id = $_POST['device_id'];
$phone_id = $_POST['phone_id'];
$country_code = $_POST['country_code'];
$device_type = $_POST['device_type'];  // "2" for iOS

// Verify OTP...
// Update database...
UPDATE users 
SET fcm_token = '$f_token', 
    device_type = '$device_type' 
WHERE uid = '$uid';
```

---

**ADD VoIP token handling:**

```php
$uid = $_POST['uid'];
$mob_otp = $_POST['mob_otp'];
$f_token = $_POST['f_token'];          // FCM token (Chat)
$voip_token = $_POST['voip_token'];    // VoIP token (Calls) 🆕
$device_id = $_POST['device_id'];
$phone_id = $_POST['phone_id'];
$country_code = $_POST['country_code'];
$device_type = $_POST['device_type'];

// Verify OTP...
// Update database with BOTH tokens...

if ($device_type == "2") {
    // iOS device - update both FCM and VoIP tokens
    $query = "UPDATE user_details 
              SET fcm_token = ?, 
                  voip_token = ?,  -- 🆕 Add VoIP token
                  device_type = ? 
              WHERE uid = ?";
    
    $stmt = $conn->prepare($query);
    $stmt->bind_param("ssss", $f_token, $voip_token, $device_type, $uid);
    $stmt->execute();
    
    echo "✅ Updated FCM token: " . substr($f_token, 0, 20) . "...";
    echo "✅ Updated VoIP token: " . substr($voip_token, 0, 20) . "...";
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
```

---

## 🔧 Backend (Java/Android) - Get VoIP Token

**When sending call notification:**

**BEFORE:**
```java
// FcmNotificationsSender.java
String voipToken = "416951db5bb2d8dd..."; // ❌ Hardcoded
```

**AFTER:**
```java
// Get VoIP token from database
String voipToken = getVoIPTokenFromDatabase(receiverId);

if (voipToken == null || voipToken.isEmpty()) {
    System.err.println("❌ [VOIP] No VoIP token for user: " + receiverId);
    System.err.println("❌ [VOIP] User needs to login from iOS app first");
    return;  // Can't send VoIP push without token
}

System.out.println("✅ [VOIP] Got VoIP token from database: " + voipToken.substring(0, 20) + "...");
```

**Add method:**
```java
private String getVoIPTokenFromDatabase(String userId) {
    try {
        // Your database connection
        String query = "SELECT voip_token FROM user_details WHERE uid = ?";
        PreparedStatement stmt = connection.prepareStatement(query);
        stmt.setString(1, userId);
        ResultSet rs = stmt.executeQuery();
        
        if (rs.next()) {
            String token = rs.getString("voip_token");
            return token;
        }
        
        return null;
    } catch (Exception e) {
        System.err.println("❌ [VOIP] Database error: " + e.getMessage());
        return null;
    }
}
```

---

## 📊 Complete Flow

### **User Registration/Login:**

```
1. iOS App → whatsTheCode.swift
    ↓
2. User enters OTP
    ↓
3. verifyOTP() called with:
    - fcmToken (Chat साठी) ✅
    - voipToken (Calls साठी) 🆕
    ↓
4. POST to verify_mobile_otp API
    - f_token = FCM token
    - voip_token = VoIP token 🆕
    ↓
5. Backend saves BOTH tokens:
    - user_details.fcm_token = "cWXCYutVCE..."
    - user_details.voip_token = "416951db5bb2d8dd..." 🆕
```

---

### **When Call is Sent:**

```
1. Android user calls iOS user (receiverId = 2)
    ↓
2. Backend gets receiver's tokens:
    - fcmToken = "cWXCYutVCE..." (for chat)
    - voipToken = "416951db5bb2d8dd..." (for calls)
    ↓
3. Backend checks notification type:
    - If Chat: Use fcmToken → FCM push
    - If Call: Use voipToken → VoIP push 🆕
    ↓
4. Send VoIP push to APNs with voipToken
    ↓
5. iOS shows instant CallKit! 🎉
```

---

## 🎯 Summary

### **Current (आत्ता काय आहे):**

| API | Endpoint | Tokens Sent |
|-----|----------|-------------|
| **verify_mobile_otp** | Line 20 | `f_token` (FCM only) |

**Result:** फक्त Chat notifications काम करतात ✅

---

### **After Changes (काय हवं):**

| API | Endpoint | Tokens Sent |
|-----|----------|-------------|
| **verify_mobile_otp** | Line 20 | `f_token` (FCM) + `voip_token` (VoIP) 🆕 |

**Result:** Chat + Call notifications दोन्ही काम करतील! ✅

---

## 📋 Step-by-Step Implementation

### Step 1: Add voip_token column (✅ Already done!)
```sql
ALTER TABLE user_details ADD COLUMN voip_token VARCHAR(255);
```

### Step 2: Update iOS `VerifyMobileOTPViewModel.swift`
- Add `voipToken` parameter to `verifyOTP()` function
- Add `voip_token` to API params

### Step 3: Update iOS `whatsTheCode.swift`
- Get VoIP token from `VoIPPushManager`
- Pass it to `verifyOTP()` call

### Step 4: Update Backend PHP `verify_mobile_otp`
- Receive `voip_token` parameter
- Save it in database along with `f_token`

### Step 5: Update Backend Java `FcmNotificationsSender.java`
- Replace hardcoded token with `getVoIPTokenFromDatabase()`
- Query database for receiver's VoIP token

---

## 🎉 Final Result

**iOS User Logs In:**
```
✅ FCM Token saved: cWXCYutVCE... (Chat साठी)
✅ VoIP Token saved: 416951db5bb2d8dd... (Calls साठी)
```

**Someone Calls This User:**
```
Backend gets VoIP token from database
    ↓
Sends VoIP push with correct token
    ↓
🎉 INSTANT CALLKIT on user's device!
```

---

**Want me to make these code changes for you?** 🚀
