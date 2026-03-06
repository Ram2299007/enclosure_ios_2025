# Notification Service Extension Fix - Communication Notifications

## UPDATED APPROACH (Silent Push - Main App Creates Notification)

**New Flow (Required):**  
Silent push → MAIN APP creates INSendMessageIntent → Donate → Schedule notification  

## Problem Statement

When sending notifications from Android to iOS devices, the notifications were showing with the **standard UI** (app icon on left) instead of **Communication Notifications UI** (profile picture on left, WhatsApp-like).

**Symptoms:**
- API returns `platform: "ios"` and `has_mutable_content: true` ✅
- FCM successfully sends the notification ✅
- Notification appears on iPhone ✅
- **BUT**: Shows app icon on left instead of profile picture on left ❌
- INSendMessageIntent not being processed ❌

## Root Cause Analysis

The issue was that when `receiverDeviceType` was not provided in the API request (or was empty), the backend was:
1. Defaulting to Android payload (no APNs alert + mutable-content)
2. Not sending the iOS-specific payload that triggers the Notification Service Extension

**Why this matters:**
- Without `mutable-content: 1` in the APNs payload, the Notification Service Extension **doesn't run**
- Without the Service Extension running, INSendMessageIntent is never created
- Without INSendMessageIntent, iOS shows standard notification UI (app icon on left)

## Solution Implemented

### 1. Enhanced `send_notification_api.php`

**Changes Made:**

#### A. iOS Fallback Send (When Receiver Type Unknown)
- When `receiverDeviceType` is missing/empty, the API now sends **BOTH** Android and iOS payloads
- This ensures iPhone devices receive the iOS payload with:
  - APNs alert (title + body)
  - `mutable-content: 1` (integer, not boolean or string)
  - `category: "CHAT_MESSAGE"`
  - Complete data payload with all chat fields

**Code Location:** Lines 305-395 in `send_notification_api.php`

**Key Logic:**
```php
if ($receiverDeviceTypeUnknown) {
    // Send Android payload first (for Android devices)
    // Then send iOS payload with APNs + mutable-content (for iPhone devices)
    // iPhone will receive the iOS payload and trigger Notification Service Extension
}
```

#### B. Comprehensive Debug Logging
Added detailed logging to track:
- Which payload fields are being sent (`bodyKey`, `friendUidKey`, `user_nameKey`, `msgKey`, `photo`)
- Payload validation (mutable-content, alert, category)
- Success/failure of iOS fallback send
- FCM response details

**Log Examples:**
```
send_notification_api: Sending iOS fallback payload:
  - bodyKey: chatting
  - friendUidKey: 1
  - user_nameKey: Priti Lohar
  - msgKey: Bbdhdjs
  - photo: SET
✅ iOS fallback payload validation passed - Notification Service Extension should run
✅ send_notification_api: iOS fallback send succeeded
```

#### C. Improved Response Format
The API response now includes:
```json
{
    "status": "success",
    "fcm_response": { ... },
    "platform": "ios",
    "has_mutable_content": true,
    "ios_fcm_response": { ... },  // Only when fallback was sent
    "sent_ios_fallback": true      // Indicates fallback was used
}
```

### 2. Enhanced Notification Service Extension Logging

**File:** `EnclosureNotificationService/NotificationService.swift`

**Changes Made:**

#### A. Comprehensive Debug Logging
Added detailed logging at every step:
- All userInfo keys received from FCM
- Specific field values (`bodyKey`, `friendUidKey`, `user_nameKey`, `msgKey`, `photo`)
- Intent creation details
- Success/failure of `updating(from: intent)` call
- Detailed error messages if intent update fails

**Log Examples:**
```
🔔 [NotificationService] Received notification - userInfo keys: bodyKey, friendUidKey, user_nameKey, msgKey, photo, ...
🔔 [NotificationService] bodyKey: chatting
🔔 [NotificationService] friendUidKey: 1
🔔 [NotificationService] Processing Communication Notification for Priti Lohar
✅ [NotificationService] Successfully updated notification with Communication Intent
✅ [NotificationService] Profile picture should now show on LEFT (Communication Notifications UI)
```

**If there's an error:**
```
❌ [NotificationService] FAILED to update from intent: [error details]
❌ [NotificationService] Error type: [error type]
❌ [NotificationService] NSError domain: [domain], code: [code]
⚠️ [NotificationService] Falling back to standard notification (app icon on left)
```

## How It Works Now

### Flow When `receiverDeviceType` is Missing:

1. **API receives request** without `receiverDeviceType`
2. **API sends Android payload** (data-only, no APNs)
3. **API sends iOS payload** (with APNs alert + mutable-content + data)
4. **FCM delivers to device:**
   - Android device: Receives Android payload → Shows notification
   - iPhone device: Receives iOS payload → Triggers Notification Service Extension
5. **Notification Service Extension runs:**
   - Reads data payload (`bodyKey`, `friendUidKey`, `user_nameKey`, `msgKey`, `photo`)
   - Downloads/caches profile picture
   - Creates INPerson with profile image
   - Creates INSendMessageIntent
   - Updates notification content with intent
6. **iOS shows Communication Notification:**
   - Profile picture on LEFT ✅
   - App icon secondary (small badge) ✅
   - WhatsApp-like UI ✅

### Flow When `receiverDeviceType: "2"` is Provided:

1. **API receives request** with `receiverDeviceType: "2"` (iOS)
2. **API sends ONLY iOS payload** (more efficient, single send)
3. **FCM delivers to iPhone**
4. **Notification Service Extension runs** (same as above)
5. **iOS shows Communication Notification** (same as above)

## Recommended Best Practice

**Always include `receiverDeviceType` in the request:**
- `"receiverDeviceType": "1"` for Android receivers
- `"receiverDeviceType": "2"` for iOS receivers

**Benefits:**
- More efficient (single FCM send instead of two)
- Faster delivery
- Lower FCM quota usage
- Clearer intent

**Example Request:**
```json
{
    "deviceToken": "...",
    "accessToken": "...",
    "receiverDeviceType": "2",  // ← Always include this!
    "receiverKey": "1",
    "user_name": "Priti Lohar",
    "photo": "https://...",
    "body": "Bbdhdjs",
    "bodyKey": "chatting",
    ...
}
```

## Debugging Guide

### Step 1: Check API Logs

Look for these log messages in your PHP error logs:

**Success:**
```
✅ iOS fallback payload validation passed - Notification Service Extension should run
✅ send_notification_api: iOS fallback send succeeded
```

**Failure:**
```
ERROR: iOS fallback payload validation failed:
  mutable-content: MISSING or WRONG
  alert: MISSING
  category: MISSING
```

### Step 2: Check Device Logs (iPhone)

1. Connect iPhone to Mac
2. Open **Console.app** (or Xcode → Window → Devices and Simulators → View Device Logs)
3. Filter for: `NotificationService` or `EnclosureNotificationService`
4. Send a test notification
5. Look for these logs:

**If Extension is Running Correctly:**
```
🔔 [NotificationService] Received notification - userInfo keys: bodyKey, friendUidKey, ...
🔔 [NotificationService] bodyKey: chatting
🔔 [NotificationService] Processing Communication Notification for [sender name]
✅ [NotificationService] Successfully updated notification with Communication Intent
✅ [NotificationService] Profile picture should now show on LEFT
```

**If Extension is NOT Running:**
- No logs appear → Extension isn't being called
- Check: Extension target is properly configured and signed

**If Extension Runs But Fails:**
```
❌ [NotificationService] FAILED to update from intent: [error]
```
- Check error details to see why intent update failed
- Common issues: Missing fields, invalid data, iOS version < 15

**If Data Payload is Missing:**
```
🔔 [NotificationService] bodyKey: MISSING
🔔 [NotificationService] friendUidKey: MISSING
```
- FCM isn't delivering data payload correctly
- Check API payload structure

### Step 3: Verify Notification UI

**Correct (Communication Notifications):**
- ✅ Circular profile picture on **LEFT**
- ✅ App icon is **small badge** (secondary)
- ✅ Sender name and message text
- ✅ WhatsApp-like appearance

**Incorrect (Standard Notifications):**
- ❌ App icon on **LEFT** (large)
- ❌ Profile picture missing or on right
- ❌ Standard iOS notification appearance

## Troubleshooting

### Issue: Extension Not Running

**Symptoms:** No `[NotificationService]` logs appear

**Possible Causes:**
1. Extension target not properly configured
2. Extension not signed/installed
3. `mutable-content` not set to integer `1`
4. APNs alert missing

**Solutions:**
1. Verify extension target exists in Xcode project
2. Check extension is signed with same team as main app
3. Verify `mutable-content: 1` (integer) in API payload
4. Verify APNs alert (title + body) is present

### Issue: Extension Runs But Shows Standard UI

**Symptoms:** Extension logs appear but notification shows app icon on left

**Possible Causes:**
1. `updating(from: intent)` call failing
2. INSendMessageIntent not created correctly
3. Missing required fields in data payload
4. iOS version < 15

**Solutions:**
1. Check error logs for `updating(from: intent)` failure
2. Verify all required fields are present:
   - `bodyKey: "chatting"`
   - `friendUidKey: [sender UID]`
   - `user_nameKey: [sender name]`
   - `msgKey: [message text]`
   - `photo: [profile picture URL]`
3. Verify iOS version is 15+ (Communication Notifications require iOS 15+)
4. Check INPerson and INSendMessageIntent creation logs

### Issue: Data Payload Fields Missing

**Symptoms:** Extension logs show "MISSING" for required fields

**Possible Causes:**
1. FCM not delivering data payload correctly
2. Data payload structure incorrect
3. Fields not included in API request

**Solutions:**
1. Verify data payload is included in FCM message
2. Check API request includes all required fields
3. Verify data payload structure matches FCM requirements

## Files Modified

1. **`backend_example/send_notification_api.php`**
   - Added iOS fallback send when receiver type unknown
   - Added comprehensive debug logging
   - Improved response format

2. **`EnclosureNotificationService/NotificationService.swift`**
   - Added comprehensive debug logging
   - Enhanced error reporting
   - Better field validation logging

## Testing Checklist

- [ ] Send notification from Android without `receiverDeviceType`
- [ ] Verify API returns `sent_ios_fallback: true`
- [ ] Verify notification appears on iPhone
- [ ] Check device logs for `[NotificationService]` entries
- [ ] Verify notification shows profile picture on LEFT
- [ ] Verify app icon is secondary (small badge)
- [ ] Send notification with `receiverDeviceType: "2"`
- [ ] Verify API sends only iOS payload (no fallback)
- [ ] Verify Communication Notifications UI appears correctly

## Next Steps

1. **Test the fix:**
   - Send a notification from Android to iOS
   - Check device logs on iPhone
   - Verify Communication Notifications UI appears

2. **Update Android client (Recommended):**
   - Modify Android code to always send `receiverDeviceType: "2"` when receiver is iOS
   - This avoids the fallback (more efficient)

3. **Monitor logs:**
   - Check PHP error logs for API debug messages
   - Check device logs for extension debug messages
   - Identify any remaining issues

## Additional Notes

- The fallback mechanism ensures notifications work even when `receiverDeviceType` is missing
- However, **always including `receiverDeviceType` is recommended** for better performance
- Communication Notifications require iOS 15+ (fallback to standard notifications on older iOS)
- The Notification Service Extension has a 30-second time limit to process notifications
- Profile pictures are cached locally for faster notification display

## Related Documentation

- `COMMUNICATION_NOTIFICATIONS_SETUP.md` - Initial setup guide
- `COMMUNICATION_NOTIFICATIONS_SUMMARY.md` - Overview of Communication Notifications
- `CRITICAL_FIX_COMMUNICATION_NOTIFICATIONS.md` - Previous fix documentation
- `BACKEND_FIX_REQUIRED.md` - Backend requirements
