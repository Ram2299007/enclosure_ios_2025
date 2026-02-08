# CRITICAL FIX: Communication Notifications Not Working

## Problem
You're seeing:
- ❌ App logo on LEFT side
- ❌ Title and subtitle
- ❌ NOT like WhatsApp (should have profile picture on LEFT)

## Root Cause

**The Notification Service Extension is NOT being called** because:

1. **Backend might be sending data-only notifications** (no APS alert)
2. **Backend needs to send APS alert WITH mutable-content** for Service Extension to run
3. **Service Extension must update notification with INSendMessageIntent**

## Solution: Update Backend to Send Proper Notifications

### Your backend MUST send this format:

```json
{
  "message": {
    "token": "device_token",
    "apns": {
      "payload": {
        "aps": {
          "alert": {
            "title": "Sender Name",
            "body": "Message text"
          },
          "sound": "default",
          "badge": 1,
          "mutable-content": 1,  // ← CRITICAL: This triggers Service Extension
          "category": "CHAT_MESSAGE"
        }
      }
    },
    "data": {
      "bodyKey": "chatting",
      "friendUidKey": "sender123",
      "photo": "https://example.com/profile.jpg",
      "msgKey": "Message text",
      "user_nameKey": "Sender Name",
      "name": "Sender Name"
    }
  }
}
```

### Check Your Backend Code

Look at `backend_example/send_notification_api.php` line 161 - it SHOULD have:
```php
"mutable-content" => 1,
```

If it doesn't, **ADD IT**.

## How to Verify Service Extension is Called

1. **Check device logs** for:
   ```
   🔔 [NotificationService] Processing Communication Notification for...
   ✅ [NotificationService] Updated notification with Communication Intent
   ```

2. **If you DON'T see these logs**, the Service Extension is NOT being called.

## If Service Extension is NOT Being Called

### Option 1: Update Backend (Recommended)

Make sure your backend sends notifications with:
- ✅ APS alert (title + body)
- ✅ `mutable-content: 1`
- ✅ Category: `CHAT_MESSAGE`
- ✅ Data payload with all chat info

### Option 2: Test with Remote Push

Send a test notification directly via FCM console or curl:

```bash
curl -X POST https://fcm.googleapis.com/v1/projects/YOUR_PROJECT/messages:send \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "token": "DEVICE_TOKEN",
      "apns": {
        "payload": {
          "aps": {
            "alert": {
              "title": "Test User",
              "body": "Test message"
            },
            "sound": "default",
            "badge": 1,
            "mutable-content": 1,
            "category": "CHAT_MESSAGE"
          }
        }
      },
      "data": {
        "bodyKey": "chatting",
        "friendUidKey": "test123",
        "photo": "https://example.com/profile.jpg",
        "msgKey": "Test message",
        "user_nameKey": "Test User",
        "name": "Test User"
      }
    }
  }'
```

## Current Implementation Status

✅ **Notification Service Extension** - Updated to process Communication Notifications  
✅ **CommunicationNotificationManager** - Ready for local notifications (fallback)  
✅ **Content Extension** - Disabled for CHAT_MESSAGE category  
✅ **Category Registration** - Includes INSendMessageIntent  

## Next Steps

1. **Verify backend sends `mutable-content: 1`**
2. **Send a test notification**
3. **Check device logs** for Service Extension messages
4. **If Service Extension is called**, you should see WhatsApp-like UI
5. **If NOT called**, update backend to include mutable-content

## Debugging

Add this to your backend to verify payload:

```php
error_log("FCM Payload: " . json_encode($fcmMessage));
```

Check that `mutable-content` is set to `1` (not `true` or string `"1"`).

## Expected Result

After fixing backend:
- ✅ Profile picture on LEFT (circular)
- ✅ App icon secondary (small badge)
- ✅ WhatsApp-like notification UI
- ✅ Message grouping works
- ✅ Inline reply works
