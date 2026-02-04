<?php
/**
 * send_notification_ios – iOS WhatsApp-like notification (visible APNs)
 *
 * Sends APNs alert + mutable-content so the Notification Service Extension can update
 * the notification with INSendMessageIntent (profile picture on LEFT).
 */

public function send_notification_ios()
{
    // Get JSON input
    $input = file_get_contents("php://input");
    $requestData = json_decode($input, true);

    // Validate JSON
    if (json_last_error() !== JSON_ERROR_NONE) {
        http_response_code(400);
        echo json_encode(["error" => "Invalid JSON input: " . json_last_error_msg()]);
        return;
    }

    // Required parameters
    $deviceToken = $requestData['deviceToken'] ?? null;
    $accessToken = $requestData['accessToken'] ?? null;

    if (empty($deviceToken) || empty($accessToken)) {
        http_response_code(400);
        echo json_encode(["error" => "Device token or access token is missing!"]);
        return;
    }

    // Extract all parameters (SAME AS ANDROID)
    $title = $requestData['title'] ?? '';
    $body = $requestData['body'] ?? '';
    $selectionCount = $requestData['selectionCount'] ?? "1";
    $receiverKey = $requestData['receiverKey'] ?? '';
    $user_name = $requestData['user_name'] ?? '';
    $photo = $requestData['photo'] ?? '';
    $currentDateTimeString = $requestData['currentDateTimeString'] ?? '';
    $deviceType = $requestData['deviceType'] ?? '';
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

    // Resolve sender identity (used for Communication Notifications)
    // Prefer explicit sender fields if provided; fallback to existing fields for compatibility.
    $senderUid = $requestData['senderUid'] ?? ($requestData['senderKey'] ?? $receiverKey);
    $senderName = $requestData['senderName'] ?? $user_name;
    if (empty($senderName)) {
        $senderName = $name;
    }
    $senderPhoto = $requestData['senderPhoto'] ?? $photo;

    // msgKey logic (same behaviour as Android)
    if (is_numeric($selectionCount) && (int)$selectionCount > 1) {
        $msgKey = $body . "&" . $selectionCount;
    } else {
        $msgKey = $body;
    }

    // FCM endpoint
    $url = "https://fcm.googleapis.com/v1/projects/enclosure-30573/messages:send";

    // iOS DATA payload – all parameters (same structure as send_notification_api)
    $iosData = [
        "bodyKey" => "chatting",
        "title" => $title,
        "body" => $body,
        "name" => $senderName,
        "user_nameKey" => $senderName,
        "nameKey" => $senderName,
        "msgKey" => $msgKey,
        "selectionCount" => $selectionCount,
        "friendUidKey" => $senderUid,
        "photo" => $senderPhoto,
        "currentDateTimeString" => $currentDateTimeString,
        "device_type" => $deviceType,
        "click_action" => $click_action,
        "icon" => $icon,
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
    ];

    // FINAL iOS payload – visible APNs alert + mutable-content
    // Notification Service Extension will update content with INSendMessageIntent
    $payload = [
        "message" => [
            "token" => $deviceToken,
            "data" => $iosData,
            "apns" => [
                "headers" => [
                    "apns-push-type" => "alert",
                    "apns-priority" => "10"
                ],
                "payload" => [
                    "aps" => [
                        "alert" => [
                            "title" => !empty($groupName) ? $groupName : (!empty($senderName) ? $senderName : 'Unknown'),
                            "body" => $body
                        ],
                        "sound" => "default",
                        "badge" => 1,
                        "mutable-content" => 1,
                        "category" => "CHAT_MESSAGE"
                    ]
                ]
            ]
        ]
    ];

    // CURL request
    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        "Authorization: Bearer " . $accessToken,
        "Content-Type: application/json"
    ]);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

    $response = curl_exec($ch);

    if ($response === false) {
        http_response_code(500);
        echo json_encode(["error" => "cURL Error: " . curl_error($ch)]);
        curl_close($ch);
        return;
    }

    curl_close($ch);

    $fcmResponse = json_decode($response, true);

    if (json_last_error() !== JSON_ERROR_NONE) {
        http_response_code(500);
        echo json_encode(["error" => "FCM response is not valid JSON: " . json_last_error_msg()]);
        return;
    }

    // Check FCM response for errors (same as send_notification_api)
    if (isset($fcmResponse['error'])) {
        http_response_code(500);
        error_log("FCM Error (send_notification_ios): " . json_encode($fcmResponse['error']));
        header('Content-Type: application/json');
        echo json_encode([
            "status" => "error",
            "error" => $fcmResponse['error'],
            "platform" => "ios",
            "has_mutable_content" => true,
            "has_content_available" => false,
            "is_silent_push" => false,
            "sent_payload" => $payload
        ]);
        return;
    }

    // Same response format as send_notification_api
    header('Content-Type: application/json');
    echo json_encode([
        "status" => "success",
        "fcm_response" => $fcmResponse,
        "platform" => "ios",
        "has_mutable_content" => true,
        "has_content_available" => false,
        "is_silent_push" => false,
        "sent_payload" => $payload
    ]);
}
