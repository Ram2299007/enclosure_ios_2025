# ✅ get_calling_contact_list API - Add VoIP Token

## 🎯 What Changed

Added `voip_token` to the contact list response so your app knows which contacts can receive VoIP push notifications for instant CallKit.

---

## 📝 The Change (1 Line!)

**File:** `get_calling_contact_list()` function

**Line ~76 (in $send_data array):**

### **BEFORE:**
```php
$send_data[] = [
    'uid'         => $friend_id,
    'photo'       => $photo,
    'full_name'   => $full_name,
    'mobile_no'   => $user_data['mobile_no'],
    'caption'     => $user_data['caption'] ?? '',
    'f_token'     => $user_data['f_token'] ?? '',

    // ✅ device_id → device_type
    'device_type' => isset($user_data['device_id'])
        ? (string)$user_data['device_id']
        : '',

    'themeColor'  => $themeColor,
    'block'       => $is_blocked
];
```

---

### **AFTER:**
```php
$send_data[] = [
    'uid'         => $friend_id,
    'photo'       => $photo,
    'full_name'   => $full_name,
    'mobile_no'   => $user_data['mobile_no'],
    'caption'     => $user_data['caption'] ?? '',
    'f_token'     => $user_data['f_token'] ?? '',
    'voip_token'  => $user_data['voip_token'] ?? '', // 🆕 VoIP token for iOS CallKit

    // ✅ device_id → device_type
    'device_type' => isset($user_data['device_id'])
        ? (string)$user_data['device_id']
        : '',

    'themeColor'  => $themeColor,
    'block'       => $is_blocked
];
```

**That's it!** Just add one line: `'voip_token' => $user_data['voip_token'] ?? '',`

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
      "uid": 2,
      "photo": "https://example.com/photo.jpg",
      "full_name": "John Doe",
      "mobile_no": "+919876543210",
      "caption": "Hey there!",
      "f_token": "fcm_token_here...",
      "device_type": "2",
      "themeColor": "#00A3E9",
      "block": false
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
      "uid": 2,
      "photo": "https://example.com/photo.jpg",
      "full_name": "John Doe",
      "mobile_no": "+919876543210",
      "caption": "Hey there!",
      "f_token": "fcm_token_here...",
      "voip_token": "416951db5bb2d8dd836060f8deb6725e049e048c1f41669b9f8fc94500b689e6",
      "device_type": "2",
      "themeColor": "#00A3E9",
      "block": false
    }
  ]
}
```

**New field:** `voip_token` 🎉

---

## 🎯 Why This Is Important

### **Without VoIP Token in Response:**

```
App wants to call iOS user
    ↓
Gets contact list (no voip_token)
    ↓
Sends call request to backend
    ↓
Backend has to query database AGAIN for voip_token
    ↓
Extra database query! ❌
```

---

### **With VoIP Token in Response:**

```
App wants to call iOS user
    ↓
Gets contact list (includes voip_token) ✅
    ↓
App already knows which contacts are iOS
    ↓
Can send voip_token directly to backend
    ↓
Backend doesn't need extra query! ✅
```

**Result:** Faster calls, fewer database queries! 🚀

---

## 📱 How Apps Will Use This

### **iOS App (Swift):**

```swift
// Get contact list
let contacts = response.data

for contact in contacts {
    let uid = contact.uid
    let name = contact.full_name
    let fcmToken = contact.f_token
    let voipToken = contact.voip_token  // 🆕 Now available!
    let deviceType = contact.device_type
    
    // Check if iOS user with VoIP token
    if deviceType == "2" && !voipToken.isEmpty {
        print("✅ iOS user - can receive CallKit: \(name)")
        // Use voipToken for instant CallKit calls
    } else {
        print("ℹ️ Android user: \(name)")
        // Use fcmToken for regular calls
    }
}
```

---

### **Android App (Java):**

```java
// Get contact list
JSONArray contacts = response.getJSONArray("data");

for (int i = 0; i < contacts.length(); i++) {
    JSONObject contact = contacts.getJSONObject(i);
    
    int uid = contact.getInt("uid");
    String name = contact.getString("full_name");
    String fcmToken = contact.getString("f_token");
    String voipToken = contact.optString("voip_token", "");  // 🆕 Now available!
    String deviceType = contact.getString("device_type");
    
    // Check if iOS user with VoIP token
    if (deviceType.equals("2") && !voipToken.isEmpty()) {
        Log.d("CALL", "✅ iOS user - can receive CallKit: " + name);
        // Use voipToken for instant CallKit calls
    } else {
        Log.d("CALL", "ℹ️ Android user: " + name);
        // Use fcmToken for regular calls
    }
}
```

---

## 🔍 Testing

### **Test 1: Get Contact List**

**Request:**
```bash
curl -X POST "https://your-backend.com/api/get_calling_contact_list" \
  -d "uid=1" \
  -d "f_token=my_fcm_token"
```

**Expected Response:**
```json
{
  "success": "1",
  "error_code": "200",
  "message": "Success",
  "data": [
    {
      "uid": 2,
      "full_name": "iOS User",
      "f_token": "fcm_token...",
      "voip_token": "416951db5bb2d8dd...",  // ✅ iOS user
      "device_type": "2"
    },
    {
      "uid": 3,
      "full_name": "Android User",
      "f_token": "fcm_token...",
      "voip_token": "",  // ❌ Android user (empty)
      "device_type": "1"
    }
  ]
}
```

---

### **Test 2: Check Database**

```sql
SELECT 
    uid, 
    mobile_no, 
    device_type, 
    LENGTH(f_token) as fcm_length,
    LENGTH(voip_token) as voip_length,
    CASE 
        WHEN device_type = '2' AND voip_token IS NOT NULL THEN 'iOS with VoIP ✅'
        WHEN device_type = '2' AND voip_token IS NULL THEN 'iOS without VoIP ⚠️'
        WHEN device_type = '1' THEN 'Android (no VoIP) ✅'
        ELSE 'Unknown'
    END as status
FROM user_details
WHERE user_type = 2;
```

**Expected:**

| uid | mobile_no | device_type | fcm_length | voip_length | status |
|-----|-----------|-------------|------------|-------------|--------|
| 1 | +919876543210 | 1 | 152 | NULL | Android (no VoIP) ✅ |
| 2 | +919876543211 | 2 | 152 | 64 | iOS with VoIP ✅ |
| 3 | +919876543212 | 2 | 152 | NULL | iOS without VoIP ⚠️ |

---

## 📋 Quick Update Guide

**Step 1:** Find `get_calling_contact_list()` function in your PHP controller

**Step 2:** Find the line with `'f_token' => $user_data['f_token'] ?? '',`

**Step 3:** Add this line RIGHT AFTER it:
```php
'voip_token'  => $user_data['voip_token'] ?? '', // 🆕 VoIP token for iOS CallKit
```

**Step 4:** Save and test!

---

## ✅ Benefits

1. **Faster Calls** - No extra database query needed
2. **Better UX** - App knows immediately which contacts support CallKit
3. **Cleaner Code** - All contact info in one response
4. **Future-Proof** - Ready for VoIP call features

---

## 🎯 Summary

**Change:** 1 line added  
**Impact:** Huge improvement for call performance  
**Breaking:** No (backward compatible - empty string for Android)  
**Time to implement:** 30 seconds  

---

**File created:** `UPDATED_get_calling_contact_list.php`

Just copy/paste and you're done! 🚀
