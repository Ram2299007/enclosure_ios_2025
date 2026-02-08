# 🔴 CRITICAL: Backend Fix Required for Communication Notifications

## Problem

**Notification Service Extension is NOT being called** because your backend is sending **data-only notifications** (no APS alert).

## Current Backend Behavior

Looking at `backend_example/send_notification_api.php`, line 151-165, your backend DOES include APS alert with mutable-content for iOS. However, you might be using a different endpoint or the payload might not be correct.

## Required Backend Payload Format

Your backend MUST send notifications in this exact format for Communication Notifications to work:

```php
// For iOS receiver (receiverDeviceType === "2")
$fcmMessage["apns"] = [
    "payload" => [
        "aps" => [
            "alert" => [
                "title" => $user_name,  // Sender name
                "body" => $body         // Message text
            ],
            "sound" => "default",
            "badge" => 1,
            "mutable-content" => 1,     // ← CRITICAL: Must be integer 1, not boolean
            "category" => "CHAT_MESSAGE"
        ]
    ]
];

// Data payload (for app to handle tap/reply)
$fcmMessage["data"] = [
    "bodyKey" => "chatting",
    "friendUidKey" => $receiverKey,
    "photo" => $photo,
    "msgKey" => $msgKey,
    "user_nameKey" => $user_name,
    "name" => $user_name,
    // ... all other fields
];
```

## Check Your Backend Code

### Option 1: Verify send_notification_api.php

Check line 161 in `backend_example/send_notification_api.php`:

```php
if ($isReceiverIos) {
    $fcmMessage["apns"] = [
        "payload" => [
            "aps" => [
                "alert" => [
                    "title" => !empty($groupName) ? $groupName : $user_name,
                    "body" => $body
                ],
                "sound" => "default",
                "badge" => 1,
                "mutable-content" => 1,  // ← Must be integer 1
                "category" => "CHAT_MESSAGE"
            ]
        ]
    ];
}
```

**Verify:**
- ✅ `mutable-content` is set to integer `1` (not boolean `true` or string `"1"`)
- ✅ `alert` has both `title` and `body`
- ✅ `category` is `"CHAT_MESSAGE"`

### Option 2: Check Which Endpoint You're Using

If you're using `send_notification_ios_DATA_ONLY.php`, **STOP** - that endpoint sends data-only notifications without APS alert. Use `send_notification_api.php` instead.

## How to Test

1. **Send a test notification** from your backend
2. **Check device logs** for:
   ```
   📱 [FCM] APS present: true
   📱 [FCM] APS alert present: true
   📱 [FCM] mutable-content: true
   ✅ [FCM] Notification Service Extension SHOULD be called
   🔔 [NotificationService] Processing Communication Notification for...
   ```

3. **If you see**:
   ```
   ⚠️ [FCM] Data-only notification (no APS alert)
   ```
   Then your backend is NOT sending APS alert - **fix the backend**.

## Quick Fix for Backend

If your backend is not sending APS alert, update it to include:

```php
// In your notification sending code
if ($isReceiverIos) {
    $fcmMessage["apns"] = [
        "payload" => [
            "aps" => [
                "alert" => [
                    "title" => $user_name,
                    "body" => $body
                ],
                "sound" => "default",
                "badge" => 1,
                "mutable-content" => 1,  // Integer 1, not boolean
                "category" => "CHAT_MESSAGE"
            ]
        ]
    ];
}
```

## Why This Matters

- **Without APS alert + mutable-content**: Service Extension never runs → No Communication Notifications → App logo on LEFT (wrong)
- **With APS alert + mutable-content**: Service Extension runs → Communication Notifications work → Profile picture on LEFT (correct)

## Next Steps

1. **Check your backend code** - verify it sends APS alert with mutable-content
2. **Send a test notification**
3. **Check device logs** - look for the new logging messages
4. **If Service Extension logs appear**, Communication Notifications should work
5. **If no Service Extension logs**, fix backend to include APS alert + mutable-content

## Summary

✅ **Backend MUST send**: APS alert + mutable-content: 1  
❌ **Backend MUST NOT send**: Data-only notifications (no APS alert)  
✅ **Result**: Notification Service Extension runs → Communication Notifications work  
❌ **Current**: Data-only → Service Extension never runs → Wrong UI  

Fix your backend, then test again!
