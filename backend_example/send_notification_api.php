<?php
/**
 * send_notification_api
 * Handles push notifications for both Android and iOS via FCM HTTP v1.
 * 
 * IMPORTANT FOR iOS COMMUNICATION NOTIFICATIONS (Silent Push):
 * For iOS + chat (bodyKey=chatting): send APS content-available: 1
 * MAIN APP creates INSendMessageIntent and schedules the notification.
 * Notification Service Extension should NOT create intent anymore.
 * 
 * CRITICAL REQUIREMENTS:
 * 1. APS must include content-available: 1
 * 2. Data payload MUST include all chat fields (bodyKey, friendUidKey, photo, etc.)
 * 3. Main app must create INSendMessageIntent and donate it before scheduling
 * 
 * If you send visible APNs alert from backend, iOS may show standard UI (app icon on left).
 * Silent push -> main app creates communication notification -> profile pic on left.
 *
 * RECOMMENDED: When calling from Android to iOS, include receiverDeviceType: "2" in the request.
 * If receiverDeviceType is missing, the API will send BOTH Android and iOS payloads as fallback
 * (iOS device will receive the silent push payload with content-available=1).
 *
 * Called by: Android (Webservice) and iOS (MessageUploadService.sendNotificationAPI)
 * Endpoint: POST .../EmojiController/send_notification_api
 * Content-Type: application/json
 * 
 * Request parameters:
 * - deviceToken: FCM token of the receiver
 * - accessToken: FCM access token for authentication
 * - receiverDeviceType: "1" = Android, "2" = iOS (RECOMMENDED: always include this)
 * - receiverKey: Sender UID (confusing naming - this is the person sending the message)
 * - user_name: Sender display name
 * - photo: Sender profile picture URL
 * - body: Message text
 * - bodyKey: Must be "chatting" for chat notifications
 * - (and other fields...)
 */

public function send_notification_api() {
    // Get JSON input
    $input = file_get_contents("php://input");
    $requestData = json_decode($input, true);

    // Validate JSON decoding
    if (json_last_error() !== JSON_ERROR_NONE) {
        http_response_code(400);
        echo json_encode(["error" => "Invalid JSON input: " . json_last_error_msg()]);
        return;
    }

    // Extract required parameters
    $deviceToken = $requestData['deviceToken'] ?? null;
    $accessToken = $requestData['accessToken'] ?? null;

    // Validate required parameters
    if (empty($deviceToken) || empty($accessToken)) {
        http_response_code(400);
        echo json_encode(["error" => "Device token or access token is missing!"]);
        return;
    }

    // Extract other parameters with defaults
    $userFcmToken = $requestData['userFcmToken'] ?? '';
    $title = $requestData['title'] ?? '';
    $body = $requestData['body'] ?? '';
    $selectionCount = $requestData['selectionCount'] ?? "1";
    $receiverKey = $requestData['receiverKey'] ?? '';
    $user_name = $requestData['user_name'] ?? '';
    $photo = $requestData['photo'] ?? '';
    $currentDateTimeString = $requestData['currentDateTimeString'] ?? '';
    $deviceType = $requestData['deviceType'] ?? '';           // Sender: "1" = Android, "2" = iOS
    $receiverDeviceType = $requestData['receiverDeviceType'] ?? '';  // Receiver: "1" = Android, "2" = iOS (for FCM payload)
    $click_action = $requestData['click_action'] ?? '';
    $icon = $requestData['icon'] ?? '';
    $uid = $requestData['uid'] ?? '';
    $message = $requestData['message'] ?? '';
    $time = $requestData['time'] ?? '';
    $document = $requestData['document'] ?? '';
    $dataType = $requestData['dataType'] ?? '';
    $extension = $requestData['extension'] ?? '';
    $name = $requestData['name'] ?? '';
    $phone = $requestData['phone'] ?? '';
    $miceTiming = $requestData['miceTiming'] ?? '';
    $micPhoto = $requestData['micPhoto'] ?? '';
    $userName = $requestData['userName'] ?? '';
    $replytextData = $requestData['replytextData'] ?? '';
    $replyKey = $requestData['replyKey'] ?? '';
    $replyType = $requestData['replyType'] ?? '';
    $replyOldData = $requestData['replyOldData'] ?? '';
    $replyCrtPostion = $requestData['replyCrtPostion'] ?? '';
    $modelId = $requestData['modelId'] ?? '';
    $receiverUid = $requestData['receiverUid'] ?? '';
    $forwaredKey = $requestData['forwaredKey'] ?? '';
    $groupName = $requestData['groupName'] ?? '';
    $docSize = $requestData['docSize'] ?? '';
    $fileName = $requestData['fileName'] ?? '';
    $thumbnail = $requestData['thumbnail'] ?? '';
    $fileNameThumbnail = $requestData['fileNameThumbnail'] ?? '';
    $caption = $requestData['caption'] ?? '';
    $notification = $requestData['notification'] ?? '';
    $currentDate = $requestData['currentDate'] ?? '';
    $senderTokenReply = $requestData['senderTokenReply'] ?? '';

    // Handle selectionCount (msgKey)
    if (is_numeric($selectionCount) && (int)$selectionCount > 1) {
        $msgKey = $body . "&" . $selectionCount;
    } else {
        $msgKey = $body;
    }

    // Determine receiver platform for FCM payload
    // receiverDeviceType: "2" = iOS, "1" = Android
    // IMPORTANT: iOS clients should always pass receiverDeviceType in the request
    // If not provided, try to get from database (optional fallback)
    if ($receiverDeviceType === '' && $receiverUid !== '') {
        // Option 1: Try to get device type from database if method exists
        if (method_exists($this, 'getUserDeviceTypeByUid')) {
            $receiverDeviceType = $this->getUserDeviceTypeByUid($receiverUid);
        }
        // Option 2: Query database directly (uncomment and customize if needed)
        // else {
        //     $this->load->database();
        //     $query = $this->db->select('device_type')
        //                       ->from('users')
        //                       ->where('uid', $receiverUid)
        //                       ->get();
        //     if ($query->num_rows() > 0) {
        //         $receiverDeviceType = $query->row()->device_type;
        //     }
        // }
    }
    
    // When receiver type is unknown: send BOTH Android and iOS payloads so iPhone gets
    // the notification (iOS payload has APNs alert + mutable-content). Known type = single send.
    $receiverDeviceTypeUnknown = ($receiverDeviceType === '');
    if ($receiverDeviceTypeUnknown) {
        $receiverDeviceType = '1'; // Use Android as primary for first send
        error_log("send_notification_api: receiverDeviceType unknown – will send both Android and iOS (send_notification_ios) payloads.");
    }

    $isReceiverIos = ($receiverDeviceType === '2');

    // FCM API endpoint (HTTP v1)
    $url = "https://fcm.googleapis.com/v1/projects/enclosure-30573/messages:send";

    // Build FCM message: token + data (always; for app to handle tap/chat/reply)
    // Data payload is used by both Notification Service Extension and app for handling notifications
    $fcmMessage = [
        "token" => $deviceToken,
        "data" => [
            // Required for chat notifications
            "bodyKey" => "chatting",  // Identifies this as a chat notification
            "title" => $title,
            "body" => $body,
            
            // Sender information (required for Communication Notifications)
            "name" => !empty($name) ? $name : $user_name,  // Fallback name
            "user_nameKey" => $user_name,  // Primary display name
            "nameKey" => $user_name,  // Alias for name
            
            // Message content
            "msgKey" => $msgKey,  // Message text (may include selectionCount)
            "selectionCount" => $selectionCount,
            
            // Sender identification (required for profile picture and grouping)
            "friendUidKey" => $receiverKey,  // Actually the sender UID (confusing naming)
            "photo" => $photo,  // Profile picture URL (Service Extension will download/cache)
            
            // Metadata
            "currentDateTimeString" => $currentDateTimeString,
            "device_type" => $deviceType,
            "click_action" => $click_action,
            "icon" => $icon,
            
            // Reply/thread information
            "uidPower" => $uid,
            "messagePower" => $message,
            "timePower" => $time,
            "documentPower" => $document,
            "dataTypePower" => $dataType,
            "extensionPower" => $extension,
            "namepower" => $name,
            "phonePower" => $phone,
            "micPhotoPower" => $micPhoto,
            "miceTimingPower" => $miceTiming,
            "userNamePower" => $userName,
            "replytextDataPower" => $replytextData,
            "replyKeyPower" => $replyKey,
            "replyTypePower" => $replyType,
            "replyOldDataPower" => $replyOldData,
            "replyCrtPostionPower" => $replyCrtPostion,
            "modelIdPower" => $modelId,
            "receiverUidPower" => $receiverUid,
            "forwaredKeyPower" => $forwaredKey,
            "groupNamePower" => $groupName,
            "docSizePower" => $docSize,
            "fileNamePower" => $fileName,
            "thumbnailPower" => $thumbnail,
            "fileNameThumbnailPower" => $fileNameThumbnail,
            "captionPower" => $caption,
            "notificationPower" => $notification,
            "currentDatePower" => $currentDate,
            "senderTokenReplyPower" => $senderTokenReply,
            "userFcmTokenPower" => $deviceToken
        ]
    ];

    // iOS chat notifications: Send alert + mutable-content for Notification Service Extension
    // Service Extension will create INSendMessageIntent for WhatsApp-like UI with profile picture
    // Flow: Remote push with alert -> Service Extension runs -> Creates INSendMessageIntent -> iOS shows native UI
    if ($isReceiverIos) {
        $fcmMessage["apns"] = [
            "headers" => [
                "apns-push-type" => "alert",
                "apns-priority" => "10"
            ],
            "payload" => [
                "aps" => [
                    "alert" => [
                        "title" => !empty($name) ? $name : $user_name,
                        "body" => $msgKey
                    ],
                    "sound" => "default",
                    "badge" => 1,
                    "mutable-content" => 1,  // CRITICAL: Triggers Notification Service Extension
                    "category" => "CHAT_MESSAGE"  // Required for reply actions
                ]
            ]
        ];
    }

    // Validate iOS notification payload structure (for debugging)
    if ($isReceiverIos && isset($fcmMessage["apns"])) {
        $aps = $fcmMessage["apns"]["payload"]["aps"];
        $hasAlert = isset($aps["alert"]);
        $hasMutableContent = isset($aps["mutable-content"]) && $aps["mutable-content"] === 1;
        $hasCategory = isset($aps["category"]) && $aps["category"] === "CHAT_MESSAGE";
        if (!$hasAlert || !$hasMutableContent || !$hasCategory) {
            error_log("WARNING: iOS notification payload missing required fields. alert=" . ($hasAlert ? "yes" : "no") . " mutable-content=" . ($hasMutableContent ? "yes" : "no") . " category=" . ($hasCategory ? "yes" : "no"));
        } else {
            error_log("✅ iOS notification payload valid: alert + mutable-content=1 + category=CHAT_MESSAGE");
        }
    }

    $data = [
        "message" => $fcmMessage
    ];

    // Initialize cURL session
    $ch = curl_init($url);

    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        "Authorization: Bearer " . $accessToken,
        "Content-Type: application/json"
    ]);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

    $response = curl_exec($ch);

    if ($response === false) {
        http_response_code(500);
        echo json_encode(["error" => "cURL Error: " . curl_error($ch)]);
        curl_close($ch);
        return;
    }

    $fcmResponse = json_decode($response, true);

    if (json_last_error() !== JSON_ERROR_NONE) {
        http_response_code(500);
        echo json_encode(["error" => "FCM response is not valid JSON: " . json_last_error_msg()]);
        curl_close($ch);
        return;
    }

    curl_close($ch);

    // Check FCM response for errors
    if (isset($fcmResponse['error'])) {
        http_response_code(500);
        error_log("FCM Error: " . json_encode($fcmResponse['error']));
        echo json_encode([
            "status" => "error",
            "error" => $fcmResponse['error']
        ]);
        return;
    }

    // When receiver type was unknown: also send iOS payload (same as send_notification_ios)
    // so that iPhone devices get the notification with APNs alert + mutable-content.
    $iosSent = false;
    $iosFcmResponse = null;
    if ($receiverDeviceTypeUnknown) {
        // Ensure all required fields are present for MAIN APP to create the notification
        // App reads: bodyKey, friendUidKey, user_nameKey, msgKey, photo
        $iosDataPayload = $fcmMessage["data"];
        
        // Log payload for debugging (remove in production or use proper logging)
        error_log("send_notification_api: Sending iOS fallback payload:");
        error_log("  - bodyKey: " . ($iosDataPayload["bodyKey"] ?? "MISSING"));
        error_log("  - friendUidKey: " . ($iosDataPayload["friendUidKey"] ?? "MISSING"));
        error_log("  - user_nameKey: " . ($iosDataPayload["user_nameKey"] ?? "MISSING"));
        error_log("  - msgKey: " . ($iosDataPayload["msgKey"] ?? "MISSING"));
        error_log("  - photo: " . (!empty($iosDataPayload["photo"]) ? "SET" : "MISSING"));
        
        $iosMessage = [
            "token" => $deviceToken,
            "data" => $iosDataPayload,
            "apns" => [
                "headers" => [
                    "apns-push-type" => "background",
                    "apns-priority" => "5"
                ],
                "payload" => [
                    "aps" => [
                        "content-available" => 1
                    ]
                ]
            ]
        ];
        
        // Validate iOS silent payload structure
        $aps = $iosMessage["apns"]["payload"]["aps"];
        $hasContentAvailable = isset($aps["content-available"]) && $aps["content-available"] === 1;
        if (!$hasContentAvailable) {
            error_log("ERROR: iOS fallback payload validation failed: content-available missing");
        } else {
            error_log("✅ iOS fallback payload validation passed - silent push content-available=1");
        }
        
        $ch2 = curl_init($url);
        curl_setopt($ch2, CURLOPT_HTTPHEADER, [
            "Authorization: Bearer " . $accessToken,
            "Content-Type: application/json"
        ]);
        curl_setopt($ch2, CURLOPT_POST, true);
        curl_setopt($ch2, CURLOPT_POSTFIELDS, json_encode(["message" => $iosMessage]));
        curl_setopt($ch2, CURLOPT_RETURNTRANSFER, true);
        $response2 = curl_exec($ch2);
        curl_close($ch2);
        if ($response2 !== false) {
            $iosFcmResponse = json_decode($response2, true);
            $iosSent = !isset($iosFcmResponse['error']);
            if ($iosSent) {
                error_log("✅ send_notification_api: iOS fallback send succeeded (receiver type was unknown).");
                error_log("   FCM message ID: " . ($iosFcmResponse['name'] ?? 'unknown'));
            } else {
                error_log("❌ send_notification_api: iOS fallback send FCM error: " . json_encode($iosFcmResponse['error'] ?? $response2));
            }
        } else {
            error_log("❌ send_notification_api: iOS fallback cURL request failed");
        }
    }

    $effectivePlatform = $isReceiverIos ? "ios" : ($iosSent ? "ios" : "android");
    $hasMutable = false;
    $hasContentAvailable = $isReceiverIos || $iosSent;

    header('Content-Type: application/json');
    $output = [
        "status" => "success",
        "fcm_response" => $fcmResponse,
        "platform" => $effectivePlatform,
        "has_mutable_content" => $hasMutable,
        "has_content_available" => $hasContentAvailable,
        "is_silent_push" => $hasContentAvailable
    ];
    if ($receiverDeviceTypeUnknown && $iosSent && $iosFcmResponse !== null) {
        $output["ios_fcm_response"] = $iosFcmResponse;
        $output["sent_ios_fallback"] = true;
    }
    echo json_encode($output);
}
