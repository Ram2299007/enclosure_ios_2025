<?php
/**
 * Device type storage and lookup
 * 
 * 1. Store device_type when user logs in (verify_mobile_otp) or updates profile (update_profile).
 * 2. In send_notification_api, use getUserDeviceTypeByUid($receiverUid) when receiverDeviceType is empty.
 * 
 * Add the helper to your controller or model. Add the store logic to your verify_mobile_otp and update_profile.
 */

// =============================================================================
// HELPER: Fetch receiver's device_type from users table (for send_notification_api)
// =============================================================================
// Add this method to the same class that has send_notification_api() (e.g. EmojiController),
// or to a User model and call e.g. $this->UserModel->getUserDeviceTypeByUid($receiverUid)

/**
 * Get device_type for a user by uid.
 * Returns "1" = Android, "2" = iOS, or "" if not found.
 * 
 * @param string $uid User ID (receiverUid)
 * @return string
 */
public function getUserDeviceTypeByUid($uid) {
    if (empty($uid)) {
        return '';
    }
    // Use ONE of the following (adapt table/column to your schema: e.g. users.uid, users.device_type).

    // --- Option A: PDO (replace $this->db with your PDO connection) ---
    try {
        $stmt = $this->db->prepare("SELECT device_type FROM users WHERE uid = ? LIMIT 1");
        $stmt->execute([$uid]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        return $row && isset($row['device_type']) ? (string)$row['device_type'] : '';
    } catch (Exception $e) {
        return '';
    }

    // --- Option B: CodeIgniter (comment out Option A, uncomment below) ---
    // $row = $this->db->select('device_type')->from('users')->where('uid', $uid)->limit(1)->get()->row_array();
    // return ($row && isset($row['device_type'])) ? (string)$row['device_type'] : '';

    // --- Option C: Laravel (comment out Option A, uncomment below) ---
    // $user = \App\User::where('uid', $uid)->first();
    // return $user ? (string)($user->device_type ?? '') : '';
}


// =============================================================================
// 1. STORE device_type in verify_mobile_otp (when user logs in)
// =============================================================================
// When the app calls verify_mobile_otp, it sends: uid, mob_otp, f_token, device_id, phone_id, country_code.
// Add device_type to the request from the app (iOS sends "2", Android sends "1").
// Then in your verify_mobile_otp handler, after successful OTP verification, update the user record:

/*
// In your verify_mobile_otp function, after you validate OTP and have $uid:

$deviceType = $requestData['deviceType'] ?? $requestData['device_type'] ?? '';  // "1" = Android, "2" = iOS

if ($uid && $deviceType !== '') {
    // Update users table: set device_type for this uid
    // Example (PDO):
    // $stmt = $this->db->prepare("UPDATE users SET device_type = ?, f_token = ? WHERE uid = ?");
    // $stmt->execute([$deviceType, $requestData['f_token'] ?? '', $uid]);
    
    // Example (CodeIgniter):
    // $this->db->where('uid', $uid)->update('users', ['device_type' => $deviceType, 'f_token' => $requestData['f_token'] ?? '']);
    
    // Example (Laravel):
    // \App\User::where('uid', $uid)->update(['device_type' => $deviceType, 'f_token' => $requestData['f_token'] ?? '']);
}
*/

// Ensure the app sends deviceType in verify_mobile_otp:
// - iOS: already sends deviceType "2" (in VerifyMobileOTPViewModel the request uses deviceId etc.; add device_type from constant "2").
// - Android: should send device_type "1" or "2" in the verify_mobile_otp request body.


// =============================================================================
// 2. STORE device_type in update_profile (when user updates profile or FCM token)
// =============================================================================
// When the app calls update_profile, it may send f_token. Add device_type to the request from the app.
// Then in your update_profile handler, when updating f_token, also update device_type:

/*
// In your update_profile function, when you have $uid and update the user:

$deviceType = $requestData['deviceType'] ?? $requestData['device_type'] ?? '';

if ($uid && $deviceType !== '') {
    // Update users table: set device_type (and f_token if present)
    // $this->db->where('uid', $uid)->update('users', ['device_type' => $deviceType, 'f_token' => $requestData['f_token'] ?? '']);
}
*/

// iOS: FirebaseManager.updateFCMTokenInBackend sends only uid and f_token; you can add device_type "2" in the iOS app
//      when calling update_profile, or set device_type in backend when you know the request is from iOS (e.g. from a header or separate endpoint).
// Android: when calling update_profile, include device_type "1" (or "2" if ever from iOS).
