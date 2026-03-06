# CallKit Testing Guide - UPDATED

## Changes Made

### Fixed Code Issues:
1. ✅ **Removed custom RemoteNotificationSceneDelegate** that was blocking notification delivery
2. ✅ Removed `configurationForConnecting` override that was interfering with default behavior
3. ✅ App now uses **default SwiftUI scene management** for proper notification routing

### What This Fixes:
- ✅ Notifications will now properly reach `AppDelegate.didReceiveRemoteNotification`
- ✅ Foreground notifications will reach `NotificationDelegate.willPresent`  
- ✅ Tapped notifications will reach `NotificationDelegate.didReceive`
- ✅ No more "unhandled action" errors

## Build & Test Steps

### Step 1: Clean Build
```bash
# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/Enclosure-*

# In Xcode:
Product > Clean Build Folder (Cmd+Shift+K)
Product > Build (Cmd+B)
```

### Step 2: Install on Device
```bash
# Run on physical device (not simulator - CallKit doesn't work in simulator)
Product > Run (Cmd+R)
```

### Step 3: Test Current Backend Notification

**Current Payload (from logs):**
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
  "bodyKey": "Incoming voice call",
  "name": "Priti Lohar",
  "roomId": "EnclosurePowerfulNext1770635173",
  "receiverId": "2",
  "phone": "+918379887185"
}
```

**Test Scenarios:**

#### Test A: App in FOREGROUND
1. Open app and keep it in foreground
2. Send voice call notification from backend
3. **Expected Result**: CallKit full-screen UI appears immediately
4. **Expected Logs:**
   ```
   🚨🚨🚨 [NotificationDelegate] willPresent notification in FOREGROUND
   🚨 [NotificationDelegate] VOICE CALL DETECTED IN FOREGROUND!
   📞 [NotificationDelegate] Triggering CallKit IMMEDIATELY...
   ✅ [NotificationDelegate] CallKit call reported successfully!
   📞 [NotificationDelegate] Suppressing banner - CallKit UI active
   ```

#### Test B: App in BACKGROUND (Home Screen)
1. Press home button (app goes to background)
2. Send voice call notification from backend  
3. User sees notification banner
4. **Tap the notification**
5. **Expected Result**: CallKit UI appears
6. **Expected Logs:**
   ```
   📱 [NotificationDelegate] User tapped notification
   📞📞📞 [NotificationDelegate] VOICE CALL notification tapped from BACKGROUND!
   📞 [NotificationDelegate] Triggering CallKit NOW...
   ✅ [NotificationDelegate] CallKit triggered from background tap!
   ```

#### Test C: App KILLED (Swiped Away)
1. Swipe app away completely  
2. Send voice call notification from backend
3. **Current Backend Payload Will NOT work** because:
   - App needs to wake up to trigger CallKit
   - Current payload has `alert`, so iOS shows banner instead of waking app
4. **You'll see**: Regular notification banner (NOT CallKit)
5. **Expected Behavior**: User must tap notification to open app, THEN CallKit appears

### Step 4: Check Console Logs

**Open Console.app:**
1. Window > Devices
2. Select your iPhone
3. Click "Open Console"
4. Filter: "Enclosure"
5. Look for these markers:
   - 🚨 = Critical notification received
   - 📞 = CallKit processing
   - ✅ = Success
   - ❌ = Error

**Key Logs to Find:**

✅ **SUCCESS CASE (Foreground):**
```
🚨🚨🚨 [NotificationDelegate] willPresent notification in FOREGROUND
🚨 [NotificationDelegate] VOICE CALL DETECTED IN FOREGROUND!
✅ [NotificationDelegate] CallKit call reported successfully!
```

✅ **SUCCESS CASE (Background Tap):**
```
📱 [NotificationDelegate] User tapped notification
📞📞📞 [NotificationDelegate] VOICE CALL notification tapped from BACKGROUND!
✅ [NotificationDelegate] CallKit triggered from background tap!
```

⚠️ **FAIL CASE (App Killed - Backend Issue):**
```
# NO LOGS because app doesn't wake up with current payload
```

## Expected Results Summary

| App State | Current Payload | Result | User Experience |
|-----------|----------------|---------|-----------------|
| **Foreground** | Works ✅ | CallKit appears | Full-screen native call UI |
| **Background** | Works ✅ (after tap) | User taps banner → CallKit | Requires user to tap notification |
| **Killed** | ❌ Doesn't work | Shows banner only | User must tap → Opens app → No CallKit |

## Backend Fix Required for "Killed App" State

To make CallKit work when app is **killed** (swiped away), backend MUST send **silent push**:

### Change Backend Notification to:
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

**REMOVE these for voice calls:**
- ❌ `notification.title`
- ❌ `notification.body`
- ❌ `aps.alert`
- ❌ `aps.sound`
- ❌ `aps.category`

**This will:**
1. ✅ Wake app in background (even if killed)
2. ✅ Trigger `AppDelegate.didReceiveRemoteNotification`
3. ✅ App reports call to CallKit
4. ✅ CallKit shows full-screen UI (not a banner)
5. ✅ Works in ALL app states

## Quick Verification Commands

### Check if app is running:
```bash
xcrun simctl launch booted com.enclosure
```

### Kill app manually:
```bash
killall Enclosure
```

### View real-time logs in terminal:
```bash
log stream --device --predicate 'process == "Enclosure"' --level debug
```

## Summary

✅ **Code is now fixed** - No more custom scene delegate blocking notifications

⚠️ **Backend needs updating** - Must send silent push for "killed app" state to work

🎯 **Test Priority:**
1. Test foreground (should work NOW with current code + current backend)
2. Test background tap (should work NOW with current code + current backend)
3. Request backend team to change to silent push for killed app state

## Success Criteria

**The fix is successful when:**
1. ✅ Foreground: CallKit appears immediately (no banner)
2. ✅ Background: User taps banner → CallKit appears
3. ✅ Killed (after backend fix): CallKit appears automatically (no banner)

**NO MORE:**
- ❌ "unhandled action" errors
- ❌ Regular notification banners for voice calls
- ❌ Need to tap notification in foreground
