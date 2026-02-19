<?php
// ============================================
// UPDATE THIS FILE: verify_mobile_otp.php
// ============================================

// Receive parameters from iOS
$uid = $_POST['uid'];
$mob_otp = $_POST['mob_otp'];
$f_token = $_POST['f_token'];          // FCM token (Chat notifications)
$voip_token = $_POST['voip_token'];    // 🆕 VoIP token (Call notifications)
$device_id = $_POST['device_id'];
$phone_id = $_POST['phone_id'];
$country_code = $_POST['country_code'];
$device_type = $_POST['device_type'];  // "2" for iOS, "1" for Android

// Verify OTP
$stored_otp = getStoredOTP($uid); // Your existing OTP verification logic
if ($mob_otp != $stored_otp) {
    echo json_encode([
        'error_code' => '400',
        'message' => 'Invalid OTP'
    ]);
    exit;
}

// OTP is valid - Update user tokens in database
try {
    // Get database connection
    $conn = getDBConnection(); // Your existing DB connection function
    
    if ($device_type == "2") {
        // iOS device - Save BOTH FCM and VoIP tokens
        $query = "UPDATE user_details 
                  SET fcm_token = ?, 
                      voip_token = ?,  -- 🆕 Add VoIP token
                      device_type = ?,
                      last_login = NOW()
                  WHERE uid = ?";
        
        $stmt = $conn->prepare($query);
        $stmt->bind_param("ssss", $f_token, $voip_token, $device_type, $uid);
        $stmt->execute();
        
        // Log for debugging
        error_log("✅ iOS User Login - UID: $uid");
        error_log("✅ Updated FCM token: " . substr($f_token, 0, 20) . "...");
        error_log("✅ Updated VoIP token: " . substr($voip_token, 0, 20) . "...");
        
        // Get user details
        $userQuery = "SELECT uid, mobile_no, f_token, voip_token, device_type 
                      FROM user_details 
                      WHERE uid = ?";
        $userStmt = $conn->prepare($userQuery);
        $userStmt->bind_param("s", $uid);
        $userStmt->execute();
        $result = $userStmt->get_result();
        $user = $result->fetch_assoc();
        
        // Return success with user data
        echo json_encode([
            'error_code' => '200',
            'message' => 'OTP verified successfully',
            'data' => [[
                'uid' => $user['uid'],
                'mobile_no' => $user['mobile_no'],
                'f_token' => $user['f_token'],
                'voip_token' => $user['voip_token'],  // 🆕 Include VoIP token
                'device_type' => $user['device_type']
            ]]
        ]);
        
    } else {
        // Android device - Only FCM token (no VoIP)
        $query = "UPDATE user_details 
                  SET fcm_token = ?, 
                      device_type = ?,
                      last_login = NOW()
                  WHERE uid = ?";
        
        $stmt = $conn->prepare($query);
        $stmt->bind_param("sss", $f_token, $device_type, $uid);
        $stmt->execute();
        
        error_log("✅ Android User Login - UID: $uid");
        error_log("✅ Updated FCM token: " . substr($f_token, 0, 20) . "...");
        
        // Get user details
        $userQuery = "SELECT uid, mobile_no, f_token, device_type 
                      FROM user_details 
                      WHERE uid = ?";
        $userStmt = $conn->prepare($userQuery);
        $userStmt->bind_param("s", $uid);
        $userStmt->execute();
        $result = $userStmt->get_result();
        $user = $result->fetch_assoc();
        
        echo json_encode([
            'error_code' => '200',
            'message' => 'OTP verified successfully',
            'data' => [[
                'uid' => $user['uid'],
                'mobile_no' => $user['mobile_no'],
                'f_token' => $user['f_token'],
                'device_type' => $user['device_type']
            ]]
        ]);
    }
    
} catch (Exception $e) {
    error_log("❌ Database error: " . $e->getMessage());
    echo json_encode([
        'error_code' => '500',
        'message' => 'Database error: ' . $e->getMessage()
    ]);
}

?>
