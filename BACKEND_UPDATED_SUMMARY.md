# Backend File Updated: send_notification_api.php

## Changes Made

### 1. Enhanced Documentation
- Added detailed comments explaining Communication Notifications requirements
- Clarified that `mutable-content` MUST be integer 1
- Explained what happens with/without mutable-content

### 2. Improved iOS Payload Structure
- Better handling of display name (uses `user_nameKey` with fallbacks)
- Proper title selection (groupName for groups, sender name for individual)
- Added error logging for debugging

### 3. Enhanced Data Payload
- Added comments explaining each field's purpose
- Ensured all required fields for Communication Notifications are included
- Better field organization and documentation

### 4. Added Validation
- Validates iOS payload structure before sending
- Logs warnings if mutable-content, alert, or category are missing/wrong
- Better error handling for FCM responses

### 5. Improved Response
- Returns platform info (ios/android)
- Returns `has_mutable_content` flag for verification
- Better error reporting

## Key Requirements (Already Implemented)

✅ **APS Alert**: Present with title and body  
✅ **mutable-content**: Set to integer `1` (not boolean or string)  
✅ **Category**: Set to `"CHAT_MESSAGE"`  
✅ **Data Payload**: Includes all required fields (bodyKey, friendUidKey, photo, etc.)  

## How to Verify

### 1. Check Backend Logs

After sending a notification, check your PHP error log for:
```
iOS Notification: title=John Doe, mutable-content=1, category=CHAT_MESSAGE
```

If you see warnings, the payload structure might be incorrect.

### 2. Check API Response

The API now returns:
```json
{
  "status": "success",
  "platform": "ios",
  "has_mutable_content": true,
  "fcm_response": { ... }
}
```

Verify `has_mutable_content` is `true` for iOS notifications.

### 3. Check iOS Device Logs

After receiving a notification, check device logs for:
```
📱 [FCM] APS present: true
📱 [FCM] APS alert present: true
📱 [FCM] mutable-content: true
✅ [FCM] Notification Service Extension SHOULD be called
🔔 [NotificationService] Processing Communication Notification for...
✅ [NotificationService] Updated notification with Communication Intent
```

## Testing

1. **Send a test notification** from your backend
2. **Check backend logs** - should see "iOS Notification: ..." log
3. **Check API response** - `has_mutable_content` should be `true`
4. **Check device logs** - Service Extension should be called
5. **Verify UI** - Profile picture should appear on LEFT (WhatsApp-like)

## Troubleshooting

### If Service Extension Still Not Called

1. **Verify backend is using this updated file**
2. **Check PHP error logs** for validation warnings
3. **Verify `receiverDeviceType === "2"`** is being set correctly
4. **Check FCM response** for any errors
5. **Verify device token** is valid iOS token

### Common Issues

- **mutable-content as string**: Must be integer `1`, not `"1"`
- **Missing APS alert**: Backend must include APS payload for iOS
- **Wrong category**: Must be exactly `"CHAT_MESSAGE"` (case-sensitive)
- **Missing data fields**: All chat fields must be in data payload

## Next Steps

1. **Deploy updated backend file**
2. **Test with a real notification**
3. **Monitor logs** (backend + device)
4. **Verify Communication Notifications work**

The backend is now properly configured for Communication Notifications! 🎉
