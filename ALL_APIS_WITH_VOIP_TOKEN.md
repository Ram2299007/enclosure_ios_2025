# ✅ All APIs with VoIP Token Support

## 🎯 Complete Overview

Here are all the APIs that now handle VoIP tokens for iOS CallKit functionality.

---

## 📝 APIs Updated

### **1. verify_mobile_otp** (Login/Registration)

**Purpose:** Save VoIP token when iOS user logs in

**Input:**
- `uid` - User ID
- `mob_otp` - OTP code
- `f_token` - FCM token (Chat)
- `voip_token` - VoIP token (Calls) 🆕
- `device_id` - Device ID
- `phone_id` - Phone ID
- `device_type` - "2" for iOS

**Output:**
```json
{
  "success": "1",
  "error_code": "200",
  "message": "OTP Verified Successfully",
  "data": [{
    "uid": "2",
    "mobile_no": "+919876543210",
    "f_token": "fcm_token...",
    "voip_token": "416951db5bb2d..." 🆕
  }]
}
```

**File:** `UPDATED_verify_mobile_otp.php`

---

### **2. get_calling_contact_list** (Contact List)

**Purpose:** Return VoIP tokens for all contacts so app knows who can receive CallKit

**Input:**
- `uid` - User ID
- `f_token` - FCM token

**Output:**
```json
{
  "success": "1",
  "error_code": "200",
  "message": "Success",
  "data": [
    {
      "uid": 2,
      "full_name": "John Doe",
      "mobile_no": "+919876543210",
      "f_token": "fcm_token...",
      "voip_token": "416951db5bb2d..." 🆕
    }
  ]
}
```

**File:** `UPDATED_get_calling_contact_list.php`

---

## 🔄 Complete User Flow

### **1. iOS User Login:**

```
User enters OTP
    ↓
App calls: verify_mobile_otp
    - Sends: f_token + voip_token
    ↓
Backend saves BOTH tokens in database
    ↓
Response includes both tokens
    ↓
✅ User registered with VoIP support!
```

---

### **2. User Gets Contact List:**

```
App calls: get_calling_contact_list
    ↓
Backend returns all contacts with their tokens:
    - f_token (for chat)
    - voip_token (for calls)
    ↓
App now knows:
    - iOS users with VoIP token → Instant CallKit ✅
    - Android users (no VoIP) → Regular FCM
    ↓
✅ Ready to make calls!
```

---

### **3. Making a Call:**

```
User taps call button on iOS contact
    ↓
App already has voip_token from contact list
    ↓
Sends call request to backend with voip_token
    ↓
Backend sends VoIP push directly to APNs
    ↓
🎉 Instant CallKit appears on receiver's device!
```

---

## 📊 Database Schema

### **user_details table:**

```sql
CREATE TABLE user_details (
    uid INT PRIMARY KEY,
    mobile_no VARCHAR(20),
    f_token VARCHAR(255),      -- FCM token (Chat)
    voip_token VARCHAR(255),   -- VoIP token (Calls) 🆕
    device_id VARCHAR(255),
    phone_id VARCHAR(255),
    device_type VARCHAR(10),   -- "1" = Android, "2" = iOS
    photo TEXT,
    caption TEXT,
    themeColor VARCHAR(20),
    -- ... other fields
);
```

---

## 🎯 Token Types Explained

### **FCM Token (f_token):**
- **Used for:** Chat messages, regular notifications
- **Format:** Long string (150+ chars) like `cWXCYutVCEItm9JpJbkVF1:APA91b...`
- **Sent to:** Firebase Cloud Messaging
- **Platforms:** Both iOS and Android

**Example:**
```
cWXCYutVCEItm9JpJbkVF1:APA91bGaFHMHBxp0ZFnlyWvza1-Lzt_rmX0YaiGEOFctOt8tFjsk1go38OfdCYaMI0GBLjxf9D8s3V0MBJM-6K75gEPKJ1bA543c7fmyZJDNGPlzoge0LFE
```

---

### **VoIP Token (voip_token):**
- **Used for:** Voice/Video call notifications (CallKit)
- **Format:** 64 hexadecimal characters like `416951db5bb2d8dd...`
- **Sent to:** Apple Push Notification service (APNs)
- **Platforms:** iOS ONLY

**Example:**
```
416951db5bb2d8dd836060f8deb6725e049e048c1f41669b9f8fc94500b689e6
```

---

## 📱 Client Implementation

### **iOS App (Swift):**

```swift
// 1. Login - Send both tokens
func verifyOTP() {
    let fcmToken = getFCMToken()  // From Firebase
    let voipToken = getVoIPToken()  // From PushKit
    
    API.verifyOTP(
        uid: uid,
        otp: otp,
        f_token: fcmToken,
        voip_token: voipToken  // 🆕 Send VoIP token
    )
}

// 2. Get Contacts - Receive both tokens
func getContactList() {
    API.getCallingContactList { contacts in
        for contact in contacts {
            if contact.deviceType == "2" && !contact.voipToken.isEmpty {
                // iOS user with CallKit support ✅
                self.enableInstantCalling(for: contact)
            }
        }
    }
}

// 3. Make Call - Use VoIP token
func makeCall(to contact: Contact) {
    if contact.deviceType == "2" && !contact.voipToken.isEmpty {
        // Send VoIP push for instant CallKit
        API.sendVoIPPush(
            toToken: contact.voipToken,
            callerId: myUID,
            callerName: myName
        )
    } else {
        // Send FCM push for regular call
        API.sendFCMPush(
            toToken: contact.f_token,
            callerId: myUID,
            callerName: myName
        )
    }
}
```

---

### **Android App (Java):**

```java
// 1. Login - Send FCM token only (no VoIP for Android)
private void verifyOTP() {
    String fcmToken = getFCMToken();  // From Firebase
    
    API.verifyOTP(
        uid,
        otp,
        fcmToken,
        null,  // voipToken = null (Android doesn't have VoIP)
        deviceId
    );
}

// 2. Get Contacts - Check device types
private void getContactList() {
    API.getCallingContactList(uid, (contacts) -> {
        for (Contact contact : contacts) {
            if (contact.deviceType.equals("2") && !contact.voipToken.isEmpty()) {
                // iOS user - backend will send VoIP push ✅
                Log.d("CALL", "iOS user: " + contact.fullName);
            } else {
                // Android user - backend will send FCM push
                Log.d("CALL", "Android user: " + contact.fullName);
            }
        }
    });
}

// 3. Make Call - Backend handles token selection
private void makeCall(Contact contact) {
    // Just send call request, backend decides which token to use
    API.sendCallNotification(
        contact.uid,
        contact.f_token,      // For Android or fallback
        contact.voipToken,    // For iOS (if available)
        myUID,
        myName
    );
}
```

---

## 🧪 Testing Checklist

### **Backend Testing:**

- [ ] **Test 1:** iOS user login with voip_token
  ```sql
  SELECT voip_token FROM user_details WHERE uid = 2;
  -- Should return: 416951db5bb2d8dd...
  ```

- [ ] **Test 2:** Android user login without voip_token
  ```sql
  SELECT voip_token FROM user_details WHERE uid = 1;
  -- Should return: NULL or empty
  ```

- [ ] **Test 3:** get_calling_contact_list returns voip_token
  ```bash
  curl -X POST "https://your-api.com/get_calling_contact_list" -d "uid=1"
  # Response should include voip_token field
  ```

---

### **Integration Testing:**

- [ ] **Test 4:** iOS user logs in → voip_token saved
- [ ] **Test 5:** iOS user gets contact list → sees voip_tokens
- [ ] **Test 6:** Android user calls iOS user → CallKit appears
- [ ] **Test 7:** iOS user calls iOS user → CallKit appears
- [ ] **Test 8:** Android calls Android → Regular FCM works

---

## 📋 Implementation Status

### ✅ Completed:

1. **Database:**
   - [x] Added `voip_token` column to `user_details` table

2. **iOS App:**
   - [x] Gets VoIP token from PushKit
   - [x] Sends to backend during login
   - [x] Receives from backend in contact list

3. **PHP Backend:**
   - [x] `verify_mobile_otp` - Saves VoIP token
   - [x] `get_calling_contact_list` - Returns VoIP token

### ⏳ Pending:

4. **Java Backend (5 minutes):**
   - [ ] Add `getVoIPTokenFromDatabase()` method
   - [ ] Use dynamic token instead of hardcoded
   - [ ] Send VoIP push to APNs

---

## 🚀 Final Step: Update Java Backend

**File:** `FcmNotificationsSender.java`

**What to do:**
1. Copy code from `BACKEND_JAVA_CODE_NEEDED.java`
2. Add `getVoIPTokenFromDatabase(userId)` method
3. Replace hardcoded token with database query
4. Test call notification

**Time:** ~5 minutes

**Result:** 🎉 Complete VoIP CallKit system working!

---

## 📁 Files Reference

| File | Purpose |
|------|---------|
| `UPDATED_verify_mobile_otp.php` | Save VoIP token on login |
| `UPDATED_get_calling_contact_list.php` | Return VoIP tokens |
| `BACKEND_JAVA_CODE_NEEDED.java` | Fetch VoIP token from DB |
| `ADD_VOIP_COLUMN.sql` | Database migration |
| `ALL_CHANGES_COMPLETE.md` | Complete summary |

---

## 🎉 Summary

**APIs Updated:** 2  
**iOS Changes:** Complete ✅  
**PHP Changes:** Complete ✅  
**Java Changes:** Pending (5 mins) ⏳  

**Once Java is updated:** Full CallKit support! 🚀
