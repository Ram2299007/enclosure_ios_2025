# 🔧 Fix VoIP Token Issue - URGENT

## ❌ Problem Found in Your Logs

```
📞 [VOIP] VoIP Token: cWXCYutVCEItm9JpJbkVF1:APA91b... ← FCM Token (WRONG!)
❌ [VOIP] APNs Error: 400
❌ [VOIP] Response: {"reason":"BadDeviceToken"}
```

**Issue:** Backend is sending **FCM token** to APNs instead of **VoIP token**!

**APNs rejects FCM tokens because:**
- FCM tokens have colons (`:`) and special format
- VoIP tokens are pure hex (64 characters, no special chars)

---

## ✅ QUICK FIX (5 minutes)

### Step 1: Get Your iOS VoIP Token

1. **Build and run iOS app** in Xcode
2. **Check Console** for this log:
   ```
   📞 [AppDelegate] VoIP Token: 416951db5bb2d8dd836060f8deb6725e...
   ```
3. **Copy the entire token** (should be 64 hex characters)

**Your iOS VoIP token from earlier logs:**
```
416951db5bb2d8dd836060f8deb6725e049e048c1f41669b9f8fc94500b689e6
```

---

### Step 2: Temporarily Hardcode VoIP Token for Testing

**File:** `FcmNotificationsSender.java`

**Find line ~240 (in `sendVoIPPushToAPNs()` method):**

```java
// TODO: Get VoIP token from database (separate from FCM token)
// For now, using FCM token as placeholder
String voipToken = userFcmToken;
```

**Replace with:**

```java
// TEMPORARY: Hardcoded VoIP token for testing
// TODO: Get from database after implementing token storage
String voipToken = "416951db5bb2d8dd836060f8deb6725e049e048c1f41669b9f8fc94500b689e6";

// Validate it's not FCM token
if (voipToken.contains(":") || voipToken.contains("APA91b")) {
    System.err.println("❌ [VOIP] ERROR: This is an FCM token, not a VoIP token!");
    System.err.println("❌ [VOIP] VoIP tokens are 64 hex characters, no colons");
    System.err.println("❌ [VOIP] Get VoIP token from iOS console logs");
    return;
}
```

---

### Step 3: Test Again!

1. **Rebuild Android backend** with hardcoded VoIP token
2. **Put iOS app in background**
3. **Send call from Android**
4. **Check logs for:**
   ```
   ✅ [VOIP] APNs Response Status: 200
   ✅ [VOIP] VoIP Push sent SUCCESSFULLY!
   ```

5. **Check iOS:**
   ```
   🎉 INSTANT CALLKIT APPEARS!
   ```

---

## 🎯 Expected Logs After Fix

### Backend:
```
📞 [VOIP] VoIP Token: 416951db5bb2d8dd836060f8deb6725e... ← Correct!
✅ [APNs JWT] JWT token created successfully!
📞 [VOIP] Sending VoIP Push to APNs...
📞 [VOIP] APNs Response Status: 200 ← Success!
✅ [VOIP] VoIP Push sent SUCCESSFULLY!
```

### iOS:
```
📞 [VoIP] INCOMING VOIP PUSH RECEIVED!
📞 [VoIP] Reporting call to CallKit NOW...
✅ [VoIP] CallKit call reported successfully!
```

---

## 🔍 How to Identify Token Types

### FCM Token (WRONG for VoIP):
```
cWXCYutVCEItm9JpJbkVF1:APA91bGaFHMHBxp0ZFnly...
                       ↑
                   Has colons!
```

### VoIP Token (CORRECT):
```
416951db5bb2d8dd836060f8deb6725e049e048c1f41669b9f8fc94500b689e6
                   ↑
            Pure hex, 64 chars
```

---

## 📋 Permanent Solution (After Testing Works)

### Step 1: Database Changes

```sql
-- Add VoIP token column
ALTER TABLE users 
ADD COLUMN voip_token VARCHAR(255);

-- Update with test token
UPDATE users 
SET voip_token = '416951db5bb2d8dd836060f8deb6725e049e048c1f41669b9f8fc94500b689e6' 
WHERE uid = '2';  -- Your iOS user ID
```

---

### Step 2: Backend Code (Replace Hardcode)

**In `sendVoIPPushToAPNs()` method:**

```java
// Get VoIP token from database
String voipToken = getVoIPTokenFromDatabase(callerId);

if (voipToken == null || voipToken.isEmpty()) {
    System.err.println("❌ [VOIP] No VoIP token found for user: " + callerId);
    System.err.println("❌ [VOIP] User needs to register VoIP token from iOS app");
    return;
}

// Validate it's not FCM token
if (voipToken.contains(":") || voipToken.contains("APA91b")) {
    System.err.println("❌ [VOIP] ERROR: Stored token is FCM, not VoIP!");
    return;
}
```

**Add method:**

```java
private String getVoIPTokenFromDatabase(String userId) {
    try {
        // Query database
        String query = "SELECT voip_token FROM users WHERE uid = ?";
        // Execute query and return voip_token
        // return resultSet.getString("voip_token");
        
        return null;  // Implement your database query
    } catch (Exception e) {
        System.err.println("❌ [VOIP] Database error: " + e.getMessage());
        return null;
    }
}
```

---

### Step 3: iOS Token Registration (Already Done!)

I already enabled it in `EnclosureApp.swift`:

```swift
// ✅ Send VoIP token to backend
VoIPPushManager.shared.sendVoIPTokenToBackend()
```

**Now implement the backend endpoint:**

**PHP Example:**
```php
// api/register_voip_token.php
$uid = $_POST['uid'];
$voip_token = $_POST['voip_token'];

$query = "UPDATE users SET voip_token = ? WHERE uid = ?";
$stmt = $conn->prepare($query);
$stmt->bind_param("ss", $voip_token, $uid);
$stmt->execute();

echo json_encode(["error_code" => 200, "message" => "VoIP token registered"]);
```

---

## 🚀 Action Plan (In Order)

### IMMEDIATE (Test with hardcode):

1. ✅ Get your VoIP token from iOS console
2. ✅ Hardcode it in `FcmNotificationsSender.java`
3. ✅ Rebuild backend
4. ✅ Test call → Should work! 🎉

### AFTER SUCCESS (Implement properly):

5. ✅ Add `voip_token` column to database
6. ✅ Create backend API endpoint
7. ✅ Implement `getVoIPTokenFromDatabase()` method
8. ✅ Remove hardcoded token
9. ✅ Test with real database lookup

---

## 🔍 Quick Verification

**Check if token is VoIP or FCM:**

```java
// VoIP token - ✅ Correct
if (token.length() == 64 && token.matches("[0-9a-f]+")) {
    System.out.println("✅ Valid VoIP token!");
}

// FCM token - ❌ Wrong
if (token.contains(":") || token.contains("APA91b")) {
    System.out.println("❌ This is FCM token, not VoIP!");
}
```

---

## 📝 Summary

**Current State:**
- ✅ JWT creation working
- ✅ Call detection working
- ✅ APNs URL correct
- ❌ **Using FCM token instead of VoIP token** ← FIX THIS!

**Quick Fix:**
```java
// Line ~240 in FcmNotificationsSender.java
String voipToken = "416951db5bb2d8dd836060f8deb6725e049e048c1f41669b9f8fc94500b689e6";
```

**Test:** Send call → APNs returns 200 → CallKit appears! 🎉

---

## 🎯 Next Test Result Should Be:

```
✅ [APNs JWT] JWT token created successfully!
📞 [VOIP] VoIP Token: 416951db5bb2d8dd836060f8deb6725e... ← Correct hex!
📞 [VOIP] APNs Response Status: 200 ← Success!
✅ [VOIP] VoIP Push sent SUCCESSFULLY!
```

And on iOS:
```
📞 [VoIP] INCOMING VOIP PUSH RECEIVED! 🎉
✅ [VoIP] CallKit call reported successfully!
```

---

**DO THIS NOW:** Hardcode the VoIP token and test again! Report the new logs! 🚀
