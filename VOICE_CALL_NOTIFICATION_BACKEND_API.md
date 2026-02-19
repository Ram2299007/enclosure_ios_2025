# Voice Call Notification - Direct FCM (Matching Android)

## Overview
Voice and video call notifications now send **directly to FCM** with minimal call-specific payload, exactly matching the Android `FcmNotificationsSender.java` implementation. No backend API intermediary.

## Changes Made

### Modified File: `Enclosure/Utility/MessageUploadService.swift`

#### 1. Voice Call Notification (`sendVoiceCallNotification`)
- **Previous**: Sent all chat message fields (replytextData, caption, selectionCount, etc.)
- **Updated**: Sends directly to FCM with only 17 call-specific fields
- **Device-Type Logic**:
  - `device_type == "1"` → **Android payload**: data-only (no notification object)
  - `device_type != "1"` → **iOS payload**: data + notification + APNs headers (mutable-content, category, priority)

#### 2. Video Call Notification (`sendVideoCallNotification`)
- **Previous**: Sent all chat message fields
- **Updated**: Sends directly to FCM with only call-specific fields
- **Same Device-Type Logic**: 
  - Android (device_type="1") gets data-only
  - iOS (device_type!="1") gets enhanced payload with APNs

## Direct FCM Integration (No Backend)

### Endpoint
```
POST https://fcm.googleapis.com/v1/projects/enclosure-30573/messages:send
Authorization: Bearer <firebase_access_token>
Content-Type: application/json
```

**Note**: Exactly matches Android `FcmNotificationsSender.java` implementation.

### FCM Payload Structure

#### For Android (device_type == "1") - Data Only:
```json
{
  "message": {
    "token": "fp135dEjS1CKlsprW1RcgR:APA91b...",
    "data": {
      "name": "Ram",
      "title": "Enclosure",
      "body": "Incoming voice call",
      "icon": "notification_icon",
      "click_action": "OPEN_VOICE_CALL",
      "meetingId": "meetingId",
      "phone": "+918485887185",
      "photo": "",
      "token": "",
      "uid": "2",
      "receiverId": "1",
      "device_type": "1",
      "userFcmToken": "fp135dEjS1CKlsprW1RcgR:APA91b...",
      "username": "2",
      "createdBy": "2",
      "incoming": "2",
      "bodyKey": "Incoming voice call",
      "roomId": "17705499755145495"
    }
  }
}
```

#### For iOS (device_type != "1") - Enhanced Payload with APNs:
```json
{
  "message": {
    "token": "receiver_fcm_token",
    "data": {
      "name": "Ram",
      "title": "Enclosure",
      "body": "Incoming voice call",
      "icon": "notification_icon",
      "click_action": "OPEN_VOICE_CALL",
      ... (same 17 fields as Android)
    },
    "notification": {
      "title": "Enclosure",
      "body": "Incoming voice call",
      "sound": "default"
    },
    "apns": {
      "headers": {
        "apns-push-type": "alert",
        "apns-priority": "10"
      },
      "payload": {
        "aps": {
          "alert": {
            "title": "Enclosure",
            "body": "Incoming voice call"
          },
          "sound": "default",
          "badge": 1,
          "mutable-content": 1,
          "category": "VOICE_CALL"
        }
      }
    }
  }
}
```

## FCM Response Structure

### Success Response
```json
{
  "name": "projects/enclosure-30573/messages/0:1234567890"
}
```

### Error Response
```json
{
  "error": {
    "code": 400,
    "message": "Invalid token",
    "status": "INVALID_ARGUMENT"
  }
}
```

## Key Differences: Android vs iOS Payload

### Android Payload (device_type == "1")
- **Data-only**: No `notification` object
- **Silent push**: Android app handles notification display
- **Minimal structure**: Just token + data

### iOS Payload (device_type != "1")
- **Enhanced payload**: Includes `notification`, `data`, and `apns` objects
- **APNs headers**: `apns-push-type: alert`, `apns-priority: 10`
- **Mutable content**: `mutable-content: 1` enables Notification Service Extension
- **Category**: `VOICE_CALL` or `VIDEO_CALL` for proper handling
- **Badge**: Shows unread count on app icon
- **Visible notification**: iOS shows system notification immediately

## Benefits

1. **Platform-Specific**: Each platform gets its optimal notification format
2. **Minimal Payload**: Only 17 call-specific fields (removed 25+ chat message fields)
3. **Direct Communication**: No backend intermediary, faster notification delivery
4. **Device-Type Aware**: Automatically detects Android vs iOS
5. **iOS Enhancement**: APNs-specific features for better user experience
6. **Proper Recognition**: Receiver gets call notification (not chat message)

## Testing Checklist

- [ ] Voice call from iOS to Android device
- [ ] Voice call from iOS to iOS device
- [ ] Video call from iOS to Android device
- [ ] Video call from iOS to iOS device
- [ ] Check backend logs for proper device_type routing
- [ ] Verify FCM success/error responses
- [ ] Test with invalid tokens
- [ ] Test with empty device_type

## Call Flow

### From `callView.swift`:
1. User taps to make voice/video call
2. `startVoiceCall(for:)` is called
3. Generates `roomId` and creates `VoiceCallPayload`
4. Calls `sendVoiceCallNotificationIfNeeded()`

### From `MessageUploadService.swift`:
5. `sendVoiceCallNotification()` gets Firebase access token
6. Calls `sendVoiceCallNotificationToBackend()` with all parameters
7. Makes HTTP POST to backend API
8. Backend checks `device_type` and routes to appropriate handler
9. Backend calls FCM with platform-specific payload
10. Backend returns success/error response
11. iOS app logs the result

## Related Files
- `Enclosure/Child Views/callView.swift` (lines 655-745)
- `Enclosure/Utility/MessageUploadService.swift` (lines 815-1150)
- `Enclosure/ViewModel/CallViewModel.swift` (for contact list with device_type)

## API Endpoint Reference
Based on `get_calling_contact_list` API response:
```json
{
  "uid": 1,
  "f_token": "fcm_token_here",
  "device_type": "1",  // 1=Android, 2=iOS
  ...
}
```

The `device_type` from contact list is passed to backend API to determine notification format.
