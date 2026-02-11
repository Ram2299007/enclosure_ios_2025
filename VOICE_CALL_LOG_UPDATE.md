# ✅ get_voice_call_log API - Add VoIP Token

## 🎯 What Changed

Added `voip_token` to the voice call log response so users can quickly call back contacts from call history using instant CallKit.

---

## 📝 Changes Made (2 Lines Added)

### **Change 1: Initialize VoIP Token Variable (Line ~68)**

**BEFORE:**
```php
$full_name   = '';
$u_f_token   = '';
$u_mobile_no = '';
$photo       = base_url('assets/images/user_profile.png');
$u_device_type = '';
```

**AFTER:**
```php
$full_name     = '';
$u_f_token     = '';
$u_voip_token  = ''; // 🆕 Initialize VoIP token
$u_mobile_no   = '';
$photo         = base_url('assets/images/user_profile.png');
$u_device_type = '';
```

---

### **Change 2: Get VoIP Token from Database (Line ~75)**

**BEFORE:**
```php
if (!empty($user)) {
    $u_f_token     = $user['f_token'] ?? '';
    $u_mobile_no   = $user['mobile_no'] ?? '';
    $u_device_type = isset($user['device_id'])
        ? (string)$user['device_id']
        : '';
```

**AFTER:**
```php
if (!empty($user)) {
    $u_f_token     = $user['f_token'] ?? '';
    $u_voip_token  = $user['voip_token'] ?? ''; // 🆕 Get VoIP token
    $u_mobile_no   = $user['mobile_no'] ?? '';
    $u_device_type = isset($user['device_id'])
        ? (string)$user['device_id']
        : '';
```

---

### **Change 3: Add VoIP Token to Response (Line ~132)**

**BEFORE:**
```php
$user_info[] = [
    'id' => $l_1['id'],
    'last_id' => $last_cal[0]['id'],
    'friend_id' => $friend_id,
    'photo' => $photo,
    'full_name' => $full_name,
    'f_token' => $u_f_token,
    'device_type' => $u_device_type,
    'mobile_no' => $u_mobile_no,
    // ... rest
];
```

**AFTER:**
```php
$user_info[] = [
    'id' => $l_1['id'],
    'last_id' => $last_cal[0]['id'],
    'friend_id' => $friend_id,
    'photo' => $photo,
    'full_name' => $full_name,
    'f_token' => $u_f_token,
    'voip_token' => $u_voip_token, // 🆕 Add VoIP token to response
    'device_type' => $u_device_type,
    'mobile_no' => $u_mobile_no,
    // ... rest
];
```

---

## 📊 API Response Examples

### **Before (Without VoIP Token):**

```json
{
  "success": "1",
  "error_code": "200",
  "message": "Success",
  "data": [
    {
      "date": "2026-02-08",
      "sr_nos": 1,
      "user_info": [
        {
          "id": 123,
          "friend_id": 2,
          "photo": "https://example.com/photo.jpg",
          "full_name": "John Doe",
          "f_token": "fcm_token...",
          "device_type": "2",
          "mobile_no": "+919876543210",
          "date": "2026-02-08",
          "start_time": "14:30:00",
          "end_time": "14:35:00",
          "calling_flag": "1",
          "call_type": "1",
          "call_history": [...]
        }
      ]
    }
  ]
}
```

---

### **After (With VoIP Token):**

```json
{
  "success": "1",
  "error_code": "200",
  "message": "Success",
  "data": [
    {
      "date": "2026-02-08",
      "sr_nos": 1,
      "user_info": [
        {
          "id": 123,
          "friend_id": 2,
          "photo": "https://example.com/photo.jpg",
          "full_name": "John Doe",
          "f_token": "fcm_token...",
          "voip_token": "416951db5bb2d8dd836060f8deb6725e049e048c1f41669b9f8fc94500b689e6",
          "device_type": "2",
          "mobile_no": "+919876543210",
          "date": "2026-02-08",
          "start_time": "14:30:00",
          "end_time": "14:35:00",
          "calling_flag": "1",
          "call_type": "1",
          "call_history": [...]
        }
      ]
    }
  ]
}
```

**New field:** `voip_token` 🎉

---

## 🎯 Why This Is Important

### **Use Case: Call Back from History**

```
User views call history
    ↓
Sees missed call from iOS user
    ↓
Taps "Call Back" button
    ↓
App already has voip_token from call log ✅
    ↓
Sends VoIP push immediately
    ↓
🎉 Instant CallKit on receiver's device!
```

**Without VoIP token:**
- Would need to fetch contact list first
- Or make extra API call
- Slower user experience ❌

**With VoIP token:**
- Everything needed is already in call log
- Instant callback ✅
- Better UX! 🚀

---

## 📱 How Apps Will Use This

### **iOS App (Swift):**

```swift
// Get voice call log
func getVoiceCallLog() {
    API.getVoiceCallLog { response in
        for dateGroup in response.data {
            for callLog in dateGroup.userInfo {
                
                // Store call log with tokens
                let contact = CallLogContact(
                    uid: callLog.friendId,
                    name: callLog.fullName,
                    photo: callLog.photo,
                    fcmToken: callLog.f_token,
                    voipToken: callLog.voipToken,  // 🆕 Now available!
                    deviceType: callLog.deviceType,
                    lastCallDate: callLog.date,
                    lastCallTime: callLog.startTime
                )
                
                self.callHistory.append(contact)
            }
        }
    }
}

// Call back directly from history
func callBack(contact: CallLogContact) {
    if contact.deviceType == "2" && !contact.voipToken.isEmpty {
        // iOS user - use VoIP token for instant CallKit ✅
        print("📞 Calling iOS user with instant CallKit")
        sendVoIPPush(
            to: contact.voipToken,
            from: myUID,
            callerName: myName
        )
    } else {
        // Android user - use FCM token
        print("📞 Calling Android user")
        sendFCMPush(
            to: contact.fcmToken,
            from: myUID,
            callerName: myName
        )
    }
}
```

---

### **Android App (Java):**

```java
// Get voice call log
private void getVoiceCallLog() {
    API.getVoiceCallLog(uid, (response) -> {
        JSONArray data = response.getJSONArray("data");
        
        for (int i = 0; i < data.length(); i++) {
            JSONObject dateGroup = data.getJSONObject(i);
            JSONArray userInfo = dateGroup.getJSONArray("user_info");
            
            for (int j = 0; j < userInfo.length(); j++) {
                JSONObject callLog = userInfo.getJSONObject(j);
                
                CallLogContact contact = new CallLogContact();
                contact.uid = callLog.getInt("friend_id");
                contact.name = callLog.getString("full_name");
                contact.photo = callLog.getString("photo");
                contact.fcmToken = callLog.getString("f_token");
                contact.voipToken = callLog.optString("voip_token", "");  // 🆕 Now available!
                contact.deviceType = callLog.getString("device_type");
                
                callHistory.add(contact);
            }
        }
    });
}

// Call back directly from history
private void callBack(CallLogContact contact) {
    if (contact.deviceType.equals("2") && !contact.voipToken.isEmpty()) {
        // iOS user - backend will use VoIP token ✅
        Log.d("CALL", "📞 Calling iOS user with instant CallKit");
        API.sendCallNotification(
            contact.uid,
            contact.fcmToken,    // For fallback
            contact.voipToken,   // For iOS CallKit
            myUID,
            myName
        );
    } else {
        // Android user - use FCM
        Log.d("CALL", "📞 Calling Android user");
        API.sendCallNotification(
            contact.uid,
            contact.fcmToken,
            "",  // No VoIP token
            myUID,
            myName
        );
    }
}
```

---

## 🔍 Testing

### **Test 1: Get Call Log**

**Request:**
```bash
curl -X POST "https://your-backend.com/api/get_voice_call_log" \
  -d "uid=1" \
  -d "f_token=my_fcm_token"
```

**Expected Response:**
```json
{
  "success": "1",
  "data": [
    {
      "date": "2026-02-08",
      "user_info": [
        {
          "friend_id": 2,
          "full_name": "iOS User",
          "f_token": "fcm_token...",
          "voip_token": "416951db5bb2d...",  // ✅ iOS user
          "device_type": "2"
        },
        {
          "friend_id": 3,
          "full_name": "Android User",
          "f_token": "fcm_token...",
          "voip_token": "",  // ❌ Android user (empty)
          "device_type": "1"
        }
      ]
    }
  ]
}
```

---

### **Test 2: Call Back from History**

```
1. User views call history
2. Sees iOS contact with voip_token ✅
3. Taps "Call Back"
4. App uses voip_token directly (no extra API call)
5. Backend sends VoIP push
6. 🎉 Instant CallKit appears!
```

---

## 📋 Quick Update Guide

**Step 1:** Find `get_voice_call_log()` function in your PHP controller

**Step 2:** Find this line (around line 68):
```php
$u_f_token   = '';
```

**Add AFTER it:**
```php
$u_voip_token  = ''; // 🆕 Initialize VoIP token
```

---

**Step 3:** Find this line (around line 75):
```php
$u_f_token     = $user['f_token'] ?? '';
```

**Add AFTER it:**
```php
$u_voip_token  = $user['voip_token'] ?? ''; // 🆕 Get VoIP token
```

---

**Step 4:** Find this line (around line 132):
```php
'f_token' => $u_f_token,
```

**Add AFTER it:**
```php
'voip_token' => $u_voip_token, // 🆕 Add VoIP token to response
```

---

**Step 5:** Save and test!

---

## ✅ Benefits

1. **Faster Callbacks** - No extra API call needed
2. **Better UX** - Instant call from history
3. **Complete Data** - All info in one response
4. **Consistent** - Same format as contact list API

---

## 🎯 Summary

**Changes:** 3 lines added  
**Impact:** Users can call back instantly from call history  
**Breaking:** No (backward compatible)  
**Time to implement:** 1 minute  

---

## 📁 APIs Now Supporting VoIP Token

1. ✅ `verify_mobile_otp` - Saves VoIP token on login
2. ✅ `get_calling_contact_list` - Returns VoIP tokens for contacts
3. ✅ `get_voice_call_log` - Returns VoIP tokens in call history 🆕

---

**File created:** `UPDATED_get_voice_call_log.php`

Just copy/paste and your call history will include VoIP tokens! 🚀
