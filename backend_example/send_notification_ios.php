<?php
/**
 * send_notification_ios – iOS WhatsApp-like notification with Service Extension
 *
 * Sends APNs alert + mutable-content so the Notification Service Extension can
 * attach the profile image (photo) and the system shows the banner even when
 * the app is not running. The app can still handle replies via category action.
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

    // msgKey logic (same behaviour as Android)
    if (is_numeric($selectionCount) && (int)$selectionCount > 1) {
        $msgKey = $body . "&" . $selectionCount;
    } else {
        $msgKey = $body;
    }

    // FCM endpoint
    $url = "https://fcm.googleapis.com/v1/projects/enclosure-30573/messages:send";

    // iOS DATA payload – all parameters preserved (use $msgKey for multi-selection)
    $iosData = [
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
    ];

    // FINAL iOS payload – APNs alert + mutable-content (Service Extension loads image)
    $payload = [
        "message" => [
            "token" => $deviceToken,
            "data" => $iosData,
            "apns" => [
                "headers" => [
                    "apns-priority" => "10"
                ],
                "payload" => [
                    "aps" => [
                        "alert" => [
                            "title" => !empty($groupName) ? $groupName : $user_name,
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

    echo json_encode([
        "status" => "success",
        "platform" => "ios",
        "fcm_response" => json_decode($response, true)
    ]);
}
