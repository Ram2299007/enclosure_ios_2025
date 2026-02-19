# Backend Fix Required for CallKit

## Problem

Voice call notifications show as **regular banners** instead of **CallKit full-screen UI** when app is killed/swiped away.

## Root Cause

Current backend sends notification with **BOTH alert AND content-available**:

```json
{
  "notification": {
    "title": "Enclosure",
    "body": "Incoming voice call"
  },
  "data": { ... },
  "apns": {
    "payload": {
      "aps": {
        "content-available": 1,
        "alert": { ... },
        "category": "VOICE_CALL",
        "sound": "default"
      }
    }
  }
}
```

**Problem**: When app is **killed**, iOS shows the alert banner instead of waking the app to trigger CallKit.

## Solution: Send Silent Push for Voice Calls

### ❌ REMOVE (for voice/video calls):
```json
{
  "notification": {
    "title": "...",  // ❌ REMOVE
    "body": "..."    // ❌ REMOVE
  },
  "apns": {
    "payload": {
      "aps": {
        "alert": { ... },  // ❌ REMOVE
        "sound": "...",    // ❌ REMOVE
        "category": "..."  // ❌ REMOVE
      }
    }
  }
}
```

### ✅ SEND THIS INSTEAD:
```json
{
  "data": {
    "bodyKey": "Incoming voice call",
    "name": "Priti Lohar",
    "roomId": "EnclosurePowerfulNext1770635173",
    "receiverId": "2",
    "phone": "+918379887185",
    "photo": "https://...",
    "uid": "1",
    "username": "1",
    "createdBy": "1",
    "token": "",
    "meetingId": "meetingId",
    "incoming": "1",
    "click_action": "OPEN_VOICE_CALL",
    "device_type": "BD5313B8-C120-42B7-A17B-C3446F88447C",
    "userFcmToken": "cWXCYutVCEItm9JpJbkVF1:..."
  },
  "apns": {
    "payload": {
      "aps": {
        "content-available": 1
      }
    }
  }
}
```

## Implementation Example (Kotlin/Java)

### Current Code (WRONG):
```kotlin
val message = Message.builder()
    .setNotification(
        Notification.builder()
            .setTitle("Enclosure")
            .setBody("Incoming voice call")
            .build()
    )
    .putData("bodyKey", "Incoming voice call")
    .putData("name", callerName)
    // ... more data
    .setApnsConfig(
        ApnsConfig.builder()
            .setAps(
                Aps.builder()
                    .setContentAvailable(true)
                    .setCategory("VOICE_CALL")
                    .setSound("default")
                    .build()
            )
            .build()
    )
    .setToken(userFcmToken)
    .build()
```

### Fixed Code (CORRECT):
```kotlin
val message = Message.builder()
    // ✅ NO .setNotification() for voice calls!
    .putData("bodyKey", "Incoming voice call")
    .putData("name", callerName)
    .putData("roomId", roomId)
    .putData("receiverId", receiverId)
    .putData("phone", phone)
    .putData("photo", photo)
    .putData("uid", uid)
    .putData("username", username)
    .putData("createdBy", createdBy)
    .putData("token", "")
    .putData("meetingId", meetingId)
    .putData("incoming", "1")
    .putData("click_action", "OPEN_VOICE_CALL")
    .putData("device_type", deviceType)
    .putData("userFcmToken", userFcmToken)
    .setApnsConfig(
        ApnsConfig.builder()
            .setAps(
                Aps.builder()
                    .setContentAvailable(true)  // ✅ ONLY this
                    // ❌ NO .setCategory()
                    // ❌ NO .setSound()
                    .build()
            )
            .build()
    )
    .setToken(userFcmToken)
    .build()
```

## Code Change Locations

### File: `VoiceCallNotificationService.kt` (or similar)

**Find:**
```kotlin
fun sendVoiceCallNotification(...)
```

**Change:**
1. Remove `.setNotification()` call
2. Remove `.setCategory()` from ApnsConfig
3. Remove `.setSound()` from ApnsConfig
4. Keep `.setContentAvailable(true)`
5. Keep all `.putData()` calls

## What Happens After Fix

| App State | Before Fix | After Fix |
|-----------|------------|-----------|
| **Foreground** | Banner (tap required) | CallKit UI (automatic) ✅ |
| **Background** | Banner (tap required) | CallKit UI (automatic) ✅ |
| **Killed** | Banner (tap required) ❌ | CallKit UI (automatic) ✅ |

## Testing the Fix

### Send Silent Push with cURL:
```bash
curl -X POST https://fcm.googleapis.com/v1/projects/YOUR_PROJECT/messages:send \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "token": "USER_FCM_TOKEN",
      "data": {
        "bodyKey": "Incoming voice call",
        "name": "Test Caller",
        "roomId": "TestRoom123",
        "receiverId": "2",
        "phone": "+1234567890"
      },
      "apns": {
        "payload": {
          "aps": {
            "content-available": 1
          }
        }
      }
    }
  }'
```

### Expected iOS Behavior:
1. ✅ No notification banner appears
2. ✅ CallKit full-screen UI appears immediately
3. ✅ Native "Accept/Decline" buttons
4. ✅ Works even if app is killed

## Fallback for Failed Delivery

If the silent push fails (e.g., user disabled notifications), send a visible "missed call" notification after 5 seconds:

```kotlin
// After 5 seconds, if no answer/decline event received:
val fallbackMessage = Message.builder()
    .setNotification(
        Notification.builder()
            .setTitle("Missed Call")
            .setBody("$callerName tried to call you")
            .build()
    )
    .putData("bodyKey", "chatting")
    .putData("type", "missed_call")
    .setToken(userFcmToken)
    .build()
```

## API Endpoint to Update

### Likely file location:
```
backend/
  └── src/
      └── main/
          └── kotlin/
              └── com/
                  └── enclosure/
                      └── service/
                          └── NotificationService.kt  ← UPDATE THIS
```

### Method to change:
```kotlin
fun sendVoiceCallNotification(
    userId: String,
    callerName: String,
    roomId: String,
    // ...
)
```

## Verification Checklist

- [ ] Remove `.setNotification()` for voice/video calls
- [ ] Keep `.putData()` with all call information
- [ ] Set `content-available = 1` in ApnsConfig
- [ ] Remove `category`, `sound`, `alert` from ApnsConfig
- [ ] Test with app killed (swipe away)
- [ ] Verify CallKit UI appears automatically
- [ ] Verify no notification banner appears

## Summary

**Change Type**: Remove notification alert, keep data + content-available

**Impact**: Voice calls will now trigger CallKit instead of showing banners

**Testing**: Kill app → Send call → CallKit appears automatically

**Rollback**: If issues occur, revert to previous code (will show banners again)

## Questions?

Contact iOS team for:
- Testing on device
- Verifying log output
- Confirming CallKit behavior
