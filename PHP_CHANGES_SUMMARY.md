# ✅ PHP Backend Changes for VoIP Token

## 🎯 What Changed

Added VoIP token support to `verify_mobile_otp` API while keeping it **OPTIONAL** (so Android devices continue to work perfectly).

---

## 📝 Changes Made (5 Lines Added)

### **Change 1: Get VoIP Token (Optional)**

**Line ~10 (after getting other parameters):**

```php
// BEFORE:
$uid = $this->input->post('uid');
$mob_otp = $this->input->post('mob_otp');
$f_token = $this->input->post('f_token');
$device_id = $this->input->post('device_id');
$phone_id = $this->input->post('phone_id');

// AFTER:
$uid = $this->input->post('uid');
$mob_otp = $this->input->post('mob_otp');
$f_token = $this->input->post('f_token');
$device_id = $this->input->post('device_id');
$phone_id = $this->input->post('phone_id');

// 🆕 Get VoIP token (OPTIONAL - only iOS sends this)
$voip_token = $this->input->post('voip_token') != null ? $this->input->post('voip_token') : '';
```

**Why optional?**
- Android devices don't have VoIP tokens
- Keeps backward compatibility
- Won't break existing apps

---

### **Change 2: Save VoIP Token (First Update Location)**

**Around Line ~35 (in first $arr array):**

```php
// BEFORE:
$arr = array(
    'mob_otp_verfied' => 1,
    'is_registered' => 1,
    'registration_date' => date("Y-m-d"),
    'f_token' => $f_token,
    'device_id' => $device_id,
    'phone_id' => $phone_id
);

// AFTER:
$arr = array(
    'mob_otp_verfied' => 1,
    'is_registered' => 1,
    'registration_date' => date("Y-m-d"),
    'f_token' => $f_token,
    'device_id' => $device_id,
    'phone_id' => $phone_id
);

// 🆕 Only add voip_token if it's not empty (iOS only)
if (!empty($voip_token)) {
    $arr['voip_token'] = $voip_token;
    error_log("✅ [VOIP] iOS user login - Saving VoIP token: " . substr($voip_token, 0, 20) . "...");
}
```

---

### **Change 3: Include VoIP Token in Response (First Location)**

**Around Line ~45 (in first $send_data):**

```php
// BEFORE:
$send_data[] = array(
    'uid' => $check_otp['uid'],
    'mobile_no' => $check_otp['mobile_no'],
    'f_token' => $f_token,
    'device_id' => $device_id,
    'phone_id' => $check_otp['phone_id']
);

// AFTER:
// 🆕 Prepare response data
$send_data_item = array(
    'uid' => $check_otp['uid'],
    'mobile_no' => $check_otp['mobile_no'],
    'f_token' => $f_token,
    'device_id' => $device_id,
    'phone_id' => $check_otp['phone_id']
);

// 🆕 Include voip_token in response if available
if (!empty($voip_token)) {
    $send_data_item['voip_token'] = $voip_token;
}

$send_data[] = $send_data_item;
```

---

### **Change 4: Save VoIP Token (Second Update Location)**

**Around Line ~85 (in $arr_edit array):**

```php
// BEFORE:
$arr_edit = array(
    'mob_otp_verfied' => 1,
    'is_registered' => 1,
    'registration_date' => date("Y-m-d"),
    'f_token' => $f_token,
    'device_id' => $device_id,
    'phone_id' => $phone_id
);

// AFTER:
$arr_edit = array(
    'mob_otp_verfied' => 1,
    'is_registered' => 1,
    'registration_date' => date("Y-m-d"),
    'f_token' => $f_token,
    'device_id' => $device_id,
    'phone_id' => $phone_id
);

// 🆕 Only add voip_token if it's not empty (iOS only)
if (!empty($voip_token)) {
    $arr_edit['voip_token'] = $voip_token;
    error_log("✅ [VOIP] iOS user first login - Saving VoIP token: " . substr($voip_token, 0, 20) . "...");
}
```

---

### **Change 5: Include VoIP Token in Response (Second Location)**

**Around Line ~100 (in second $send_data):**

```php
// BEFORE:
$send_data[] = array(
    'uid' => $check_info['uid'],
    'mobile_no' => $check_info['mobile_no'],
    'f_token' => $check_info['f_token'],
    'device_id' => $check_info['device_id'],
    'phone_id' => $check_info['phone_id']
);

// AFTER:
// 🆕 Prepare response data
$send_data_item = array(
    'uid' => $check_info['uid'],
    'mobile_no' => $check_info['mobile_no'],
    'f_token' => $check_info['f_token'],
    'device_id' => $check_info['device_id'],
    'phone_id' => $check_info['phone_id']
);

// 🆕 Include voip_token in response if available
if (!empty($voip_token)) {
    $send_data_item['voip_token'] = $voip_token;
}

$send_data[] = $send_data_item;
```

---

## 📊 How It Works

### **Android Device Login:**

```
Android App sends:
{
    "uid": "1",
    "mob_otp": "123456",
    "f_token": "fcm_android_token...",
    "device_id": "...",
    "phone_id": "...",
    // NO voip_token ✅
}

Backend:
- Receives parameters
- $voip_token = '' (empty)
- Skips adding voip_token to database
- Returns normal response
- ✅ Everything works as before!
```

---

### **iOS Device Login:**

```
iOS App sends:
{
    "uid": "2",
    "mob_otp": "123456",
    "f_token": "fcm_ios_token...",
    "device_id": "...",
    "phone_id": "...",
    "voip_token": "416951db5bb2d8dd..." ✅
}

Backend:
- Receives parameters
- $voip_token = "416951db5bb2d8dd..."
- Adds voip_token to database update ✅
- Logs: "✅ [VOIP] iOS user login - Saving VoIP token: 416951db5bb2d..."
- Returns response with voip_token included ✅
```

---

## 🔍 Backend Logs

When iOS user logs in, you'll see in your PHP error log:

```
✅ [VOIP] iOS user login - Saving VoIP token: 416951db5bb2d8dd...
```

When Android user logs in, you won't see any VoIP logs (normal).

---

## 📋 Testing

### **Test 1: Android Login (Should Work Same as Before)**

```bash
curl -X POST "https://your-backend.com/api/verify_mobile_otp" \
  -d "uid=1" \
  -d "mob_otp=123456" \
  -d "f_token=fcm_android_token" \
  -d "device_id=android_device" \
  -d "phone_id=android_phone"
```

**Expected:**
```json
{
  "success": "1",
  "error_code": "200",
  "message": "OTP Verified Successfully",
  "data": [{
    "uid": "1",
    "mobile_no": "+919876543210",
    "f_token": "fcm_android_token",
    "device_id": "android_device",
    "phone_id": "android_phone"
  }]
}
```

**✅ No voip_token in response (normal for Android)**

---

### **Test 2: iOS Login (With VoIP Token)**

```bash
curl -X POST "https://your-backend.com/api/verify_mobile_otp" \
  -d "uid=2" \
  -d "mob_otp=123456" \
  -d "f_token=fcm_ios_token" \
  -d "device_id=ios_device" \
  -d "phone_id=ios_phone" \
  -d "voip_token=416951db5bb2d8dd836060f8deb6725e049e048c1f41669b9f8fc94500b689e6"
```

**Expected:**
```json
{
  "success": "1",
  "error_code": "200",
  "message": "OTP Verified Successfully",
  "data": [{
    "uid": "2",
    "mobile_no": "+919876543210",
    "f_token": "fcm_ios_token",
    "device_id": "ios_device",
    "phone_id": "ios_phone",
    "voip_token": "416951db5bb2d8dd836060f8deb6725e049e048c1f41669b9f8fc94500b689e6"
  }]
}
```

**✅ voip_token included in response!**

---

### **Test 3: Check Database**

```sql
SELECT uid, mobile_no, f_token, voip_token, device_type 
FROM user_details 
WHERE uid IN ('1', '2');
```

**Expected Result:**

| uid | mobile_no | f_token | voip_token | device_type |
|-----|-----------|---------|------------|-------------|
| 1 | +919876543210 | fcm_android_token | NULL or empty | 1 (Android) |
| 2 | +919876543210 | fcm_ios_token | 416951db5bb2d... | 2 (iOS) |

---

## 🎯 Summary

### What's Different?

| Platform | Before | After |
|----------|--------|-------|
| **Android** | Saves f_token only | Saves f_token only (same!) |
| **iOS** | Saves f_token only | Saves f_token + voip_token ✅ |

### What's NOT Required?

- ❌ No changes to Android app
- ❌ No changes to required parameters check
- ❌ No breaking changes to existing functionality

### What IS Required?

- ✅ Copy the updated code to your PHP controller
- ✅ That's it! 🎉

---

## 📁 File to Update

**File Path:** Your CodeIgniter controller (probably something like):
- `application/controllers/Api.php`
- or `application/controllers/User.php`
- or wherever your `verify_mobile_otp()` function is

**Function Name:** `public function verify_mobile_otp()`

**Complete updated code:** See `UPDATED_verify_mobile_otp.php`

---

## 🚀 Next Steps

1. ✅ Copy the updated code to your PHP controller
2. ✅ Test Android login (should work exactly as before)
3. ✅ Test iOS login (should save voip_token)
4. ✅ Update Java `FcmNotificationsSender.java` (see `BACKEND_JAVA_CODE_NEEDED.java`)
5. ✅ Test call notification → Instant CallKit! 🎉

---

**Total implementation time: ~2 minutes!** 🚀
