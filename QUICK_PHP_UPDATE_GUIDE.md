# 🚀 Quick PHP Update Guide

## 📝 Step-by-Step: Update verify_mobile_otp

### Step 1: Find Your PHP Controller

Look for the file containing `verify_mobile_otp()` function.

Usually in:
- `application/controllers/Api.php`
- `application/controllers/User.php`
- `application/controllers/Auth.php`

---

### Step 2: Find This Line (Around Line 10)

```php
$phone_id = $this->input->post('phone_id');
```

**Add AFTER it:**

```php
// 🆕 Get VoIP token (OPTIONAL - only iOS sends this)
$voip_token = $this->input->post('voip_token') != null ? $this->input->post('voip_token') : '';
```

---

### Step 3: Find This Block (Around Line 35)

```php
$arr = array(
    'mob_otp_verfied' => 1,
    'is_registered' => 1,
    'registration_date' => date("Y-m-d"),
    'f_token' => $f_token,
    'device_id' => $device_id,
    'phone_id' => $phone_id
);
```

**Add AFTER it (before `$update_id = ...`):**

```php
// 🆕 Only add voip_token if it's not empty (iOS only)
if (!empty($voip_token)) {
    $arr['voip_token'] = $voip_token;
    error_log("✅ [VOIP] iOS user login - Saving VoIP token: " . substr($voip_token, 0, 20) . "...");
}
```

---

### Step 4: Find This Block (Around Line 45)

```php
$send_data[] = array(
    'uid' => $check_otp['uid'],
    'mobile_no' => $check_otp['mobile_no'],
    'f_token' => $f_token,
    'device_id' => $device_id,
    'phone_id' => $check_otp['phone_id']
);
```

**Replace with:**

```php
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

### Step 5: Find This Block (Around Line 85)

```php
$arr_edit = array(
    'mob_otp_verfied' => 1,
    'is_registered' => 1,
    'registration_date' => date("Y-m-d"),
    'f_token' => $f_token,
    'device_id' => $device_id,
    'phone_id' => $phone_id
);
```

**Add AFTER it (before `$wh_1 = ...`):**

```php
// 🆕 Only add voip_token if it's not empty (iOS only)
if (!empty($voip_token)) {
    $arr_edit['voip_token'] = $voip_token;
    error_log("✅ [VOIP] iOS user first login - Saving VoIP token: " . substr($voip_token, 0, 20) . "...");
}
```

---

### Step 6: Find This Block (Around Line 100)

```php
$send_data[] = array(
    'uid' => $check_info['uid'],
    'mobile_no' => $check_info['mobile_no'],
    'f_token' => $check_info['f_token'],
    'device_id' => $check_info['device_id'],
    'phone_id' => $check_info['phone_id']
);
```

**Replace with:**

```php
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

## ✅ Done!

Save the file and test:

1. **Test Android login** (should work same as before)
2. **Test iOS login** (should save voip_token)
3. **Check database:**
   ```sql
   SELECT uid, fcm_token, voip_token FROM user_details WHERE uid = '2';
   ```

---

## 🎯 Quick Checklist

- [ ] Added `$voip_token = ...` line
- [ ] Added voip_token to first `$arr` array
- [ ] Updated first `$send_data` response
- [ ] Added voip_token to `$arr_edit` array
- [ ] Updated second `$send_data` response
- [ ] Tested Android login (works)
- [ ] Tested iOS login (voip_token saved)

---

**Total changes: 5 additions, ~20 lines of code!** 🚀

See `UPDATED_verify_mobile_otp.php` for complete updated function.
