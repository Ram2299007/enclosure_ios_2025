<?php
/**
 * send_notification_api
 * Handles push notifications for both Android and iOS via FCM HTTP v1.
 * For iOS receivers: includes "notification" block so APNs shows the notification when app is in background.
 * 
 * Called by: Android (Webservice) and iOS (MessageUploadService.sendNotificationAPI)
 * Endpoint: POST .../EmojiController/send_notification_api
 * Content-Type: application/json
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
    // receiverDeviceType: "2" = iOS (needs "notification" block so APNs shows notification when app in background)
    // If not in request, fetch from users table by receiverUid (stored at login via verify_mobile_otp / update_profile)
    if ($receiverDeviceType === '' && $receiverUid !== '') {
        $receiverDeviceType = $this->getUserDeviceTypeByUid($receiverUid);
    }
    $isReceiverIos = ($receiverDeviceType === '2');

    // FCM API endpoint (HTTP v1)
    $url = "https://fcm.googleapis.com/v1/projects/enclosure-30573/messages:send";

    // Build FCM message: token + data (always; for app to handle tap/chat)
    $fcmMessage = [
        "token" => $deviceToken,
        "data" => [
            "bodyKey" => "chatting",
            "title" => $title,
            "body" => $body,
            "click_action" => $click_action,
            "icon" => $icon,
            "nameKey" => $user_name,
            "msgKey" => $msgKey,
            "currentDateTimeString" => $currentDateTimeString,
            "photo" => $photo,
            "friendUidKey" => $receiverKey,
            "device_type" => $deviceType,
            "user_nameKey" => $user_name,
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
            "userFcmTokenPower" => $deviceToken,
            "selectionCount" => $selectionCount
        ]
    ];

    // iOS: add "notification" so APNs shows the notification when app is in background
    if ($isReceiverIos) {
        $fcmMessage["notification"] = [
            "title" => $title,
            "body" => $body,
            "sound" => "default"
        ];
        $fcmMessage["apns"] = [
            "payload" => [
                "aps" => [
                    "sound" => "default",
                    "content-available" => 1
                ]
            ]
        ];
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

    header('Content-Type: application/json');
    echo json_encode([
        "status" => "success",
        "fcm_response" => $fcmResponse
    ]);
}
