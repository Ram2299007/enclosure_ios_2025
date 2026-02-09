# Voice Call Notification Delivery Diagnosis

## Problem Summary

Voice call notifications are being received but showing as **"unhandled action"** and displaying as regular banners instead of triggering CallKit.

## Root Cause Analysis

### What the Logs Show

```
debug  16:36:14.312165  Enclosure  respondToActions unhandled action:<UISHandleRemoteNotificationAction: 0x00540182>
```

**KEY ISSUE**: The notification is delivered at the UIScene level but NOT properly routed to:
- `AppDelegate.didReceiveRemoteNotification` ❌
- `NotificationDelegate.willPresent` ❌  
- `NotificationDelegate.didReceive response` ❌

### Why This Happens

The notification payload has **BOTH** `content-available = 1` AND `alert`:

```json
{
  "aps": {
    "content-available": 1,
    "alert": {
      "title": "Enclosure",
      "body": "Incoming voice call"
    },
    "category": "VOICE_CALL",
    "sound": "default"
  },
  "name": "Priti Lohar",
  "roomId": "EnclosurePowerfulNext1770635173",
  ...
}
```

**Problem**: When you have BOTH:
- `content-available = 1` → Should wake app in background to process data
- `alert` + `sound` → Shows user-visible notification banner

iOS 13+ with scenes delivers this as a scene-level action (`UISHandleRemoteNotificationAction`) which doesn't properly trigger either the background fetch handler OR the user notification delegate.

## Solution Options

### Option 1: Use Silent Push for CallKit (RECOMMENDED for Background/Killed App)

For voice calls, send **TWO separate notifications**:

#### 1. Silent Push to Wake App & Trigger CallKit
```json
{
  "data": {
    "bodyKey": "Incoming voice call",
    "name": "Priti Lohar",
    "roomId": "EnclosurePowerfulNext1770635173",
    "receiverId": "2",
    "phone": "+918379887185"
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
**This will:**
- ✅ Wake app in background (even if killed)
- ✅ Trigger `AppDelegate.didReceiveRemoteNotification`
- ✅ Allow app to report call to CallKit
- ✅ CallKit shows full-screen native call UI (not a banner)

#### 2. Visible Notification (Only if Silent Push Fails)
After 3-5 seconds, if app doesn't answer/decline, send a fallback visible notification:
```json
{
  "notification": {
    "title": "Missed Call",
    "body": "Priti Lohar tried to call you"
  },
  "data": {
    "bodyKey": "chatting",
    "type": "missed_call"
  }
}
```

### Option 2: Use Only Visible Notification with Category (CURRENT APPROACH)

Keep sending visible notification with `category: VOICE_CALL`, but:

**Backend must send:**
```json
{
  "notification": {
    "title": "Enclosure",
    "body": "Incoming voice call"
  },
  "data": {
    "bodyKey": "Incoming voice call",
    "name": "Priti Lohar",
    "roomId": "EnclosurePowerfulNext1770635173"
  },
  "apns": {
    "payload": {
      "aps": {
        "category": "VOICE_CALL",
        "sound": "default",
        "mutable-content": 1
      }
    }
  }
}
```

**Notes:**
- ⚠️ Only works reliably when app is in **foreground**
- ⚠️ When app is background/killed, user must tap the notification
- ⚠️ Not recommended for real-time calls (poor UX)

### Option 3: Use VoIP Push (Apple PushKit) - BEST SOLUTION

**This is Apple's recommended approach for voice calls:**

1. Register for VoIP pushes using PushKit
2. Backend sends VoIP push (different from FCM)
3. iOS **guarantees** app wakes up instantly
4. App reports call to CallKit
5. Native full-screen call UI appears

**Advantages:**
- ✅ Instant delivery (higher priority than regular push)
- ✅ App always wakes up (even from killed state)
- ✅ Best user experience
- ✅ Required for App Store approval of calling apps

**Implementation:** Would require backend to support APNs VoIP pushes (separate from FCM).

## Current Code Changes Made

### Fixed Issues:
1. ✅ Removed custom `RemoteNotificationSceneDelegate` that was blocking notification delivery
2. ✅ Using default scene configuration for proper notification routing
3. ✅ `NotificationDelegate` properly set in `AppDelegate.didFinishLaunching`
4. ✅ `didReceiveRemoteNotification` properly handles voice calls

### What Will Work Now:
- ✅ Foreground notifications → `NotificationDelegate.willPresent` → CallKit
- ✅ Tapped notifications → `NotificationDelegate.didReceive` → CallKit
- ✅ Silent push (content-available only) → `AppDelegate.didReceiveRemoteNotification` → CallKit

## Testing Instructions

### Test 1: Silent Push (Recommended Approach)
1. Clean build and install app
2. Send notification with **ONLY** `content-available = 1` (NO alert, NO sound)
3. Check logs for:
   ```
   🚨🚨🚨 [FCM] NOTIFICATION RECEIVED IN APPDELEGATE!!!
   📞📞📞 [CallKit] ✅ VOICE CALL NOTIFICATION DETECTED!
   ```
4. CallKit full-screen UI should appear

### Test 2: Foreground with Visible Notification  
1. Open app (foreground)
2. Send notification with `alert` + `category: VOICE_CALL`
3. Check logs for:
   ```
   🚨🚨🚨 [NotificationDelegate] willPresent notification in FOREGROUND
   📞 [NotificationDelegate] Forwarding to AppDelegate.didReceiveRemoteNotification
   ```
4. CallKit UI should appear (banner suppressed)

### Test 3: Background - User Taps Notification
1. Put app in background
2. Send notification with `alert` + `category: VOICE_CALL`
3. User taps notification
4. Check logs for:
   ```
   📱 [NotificationDelegate] User tapped notification
   📞📞📞 [NotificationDelegate] VOICE CALL notification tapped from BACKGROUND!
   ```
5. CallKit UI should appear

## Recommended Backend Changes

### Priority 1: For Background/Killed App (Best UX)
Change voice call notifications to **silent push**:

```kotlin
// Android FCM (Kotlin)
val message = Message.builder()
    .putData("bodyKey", "Incoming voice call")
    .putData("name", callerName)
    .putData("roomId", roomId)
    .putData("receiverId", receiverId)
    .putData("phone", phone)
    .setApnsConfig(
        ApnsConfig.builder()
            .setAps(
                Aps.builder()
                    .setContentAvailable(true)
                    .build()
            )
            .build()
    )
    .setToken(userFcmToken)
    .build()
```

**Remove:**
- ❌ `notification.title`
- ❌ `notification.body`  
- ❌ `aps.alert`
- ❌ `aps.sound`
- ❌ `aps.category` (not needed for silent push)

**Keep:**
- ✅ `data` payload with all call info
- ✅ `content-available = 1`

### Priority 2: Add Fallback Visible Notification
After 5 seconds, if no answer/decline from app, send "Missed Call" notification.

## Expected Log Output (After Fix)

### When Silent Push Arrives:
```
🚨🚨🚨 [FCM] ============================================
🚨 [FCM] NOTIFICATION RECEIVED IN APPDELEGATE!!!
🚨 [FCM] App State: 2 (background)
📱 [FCM] bodyKey = 'Incoming voice call'
📞📞📞 [CallKit] ✅ VOICE CALL NOTIFICATION DETECTED!
📞 [CallKit] Extracted data:
   - Caller Name: 'Priti Lohar'
   - Room ID: 'EnclosurePowerfulNext1770635173'
✅ [CallKit] Call reported successfully
```

## Summary

**Current Issue**: Notification has both `alert` and `content-available`, causing iOS to treat it as a scene action that doesn't trigger CallKit.

**Solution**: Backend must send **silent push** (content-available ONLY) for voice calls so app wakes up and triggers CallKit before user sees any banner.

**Result**: Native full-screen CallKit UI instead of notification banner.
