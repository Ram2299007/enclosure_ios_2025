# CallKit Testing Guide - Get Full-Screen Call UI

## ✅ Changes Made

### Android Side (UPDATED)
**File**: `FcmNotificationsSender.java`

**Changed**: iOS devices now receive **data-only** notifications (no banner)
- Removed `notification` object for iOS
- Changed to `content-available` silent push
- Changed `apns-push-type` from "alert" to "background"

**Why**: CallKit needs exclusive control - no competing notification banners!

### iOS Side (ALREADY DONE)
- CallKitManager.swift created ✅
- AppDelegate updated ✅
- Info.plist configured ✅
- Background modes enabled ✅

## Testing Steps

### Step 1: Add CallKitManager to Xcode Project

**IMPORTANT**: The CallKitManager.swift file must be added to your Xcode project!

1. Open `Enclosure.xcodeproj` in Xcode
2. In Project Navigator, right-click on `Enclosure/Utility` folder
3. Select **"Add Files to Enclosure..."**
4. Navigate to: `Enclosure/Utility/CallKitManager.swift`
5. Check ✅ **"Copy items if needed"**
6. Check ✅ **Target: Enclosure** (make sure it's checked)
7. Click **"Add"**

### Step 2: Build and Install on REAL iOS Device

**CRITICAL**: CallKit does NOT work fully in Simulator!
- Build and install on a physical iPhone/iPad
- Ensure device is unlocked first time for testing

### Step 3: Send Call from Android

1. **Keep iOS app running** (can be foreground or background)
2. From Android device, initiate voice call to iOS user
3. Android will send data-only notification

### What You Should See

#### ❌ Before (What You Were Seeing)
- Normal notification banner at top
- Tap to open app
- No full-screen UI

#### ✅ After (What You Should See Now)
```
┌────────────────────────────────┐
│                                │
│   [Photo]    Priti Lohar       │  ← Circular photo (left)
│              Enclosure          │  ← Subtitle
│                        [Icon]   │  ← App icon (right)
│                                │
│                                │
│   🔴 Decline         Accept 🟢 │  ← Native iOS buttons
└────────────────────────────────┘
```

**Full-screen native call UI with:**
- Circular caller photo on left
- Caller name in center
- App icon on right
- Red Decline button (left bottom)
- Green Accept button (right bottom)

## Console Output to Verify

### Android Side (When Sending)
```
📞 [FCM] Sending call notification
📞 [FCM] Device Type: E5E07622-... (1=Android, other=iOS)
📞 [FCM] Using iOS CallKit payload (data-only with content-available)
📞 [FCM] NO notification banner - CallKit will show full-screen call UI
📤 [FCM] ========== SENDING PAYLOAD ==========
📤 [FCM] Payload: {
  "message": {
    "token": "...",
    "data": { ... },
    "apns": {
      "headers": {
        "apns-push-type": "background",
        "apns-priority": "10"
      },
      "payload": {
        "aps": {
          "content-available": 1,
          "category": "VOICE_CALL"
        }
      }
    }
  }
}
✅ [FCM] Call notification sent successfully
```

### iOS Side (When Receiving)
```
📱 [FCM] didReceiveRemoteNotification - keys: ...
📱 [FCM] bodyKey = Incoming voice call
📞 [CallKit] Voice/Video call notification received
📞 [CallKit] Processing call notification...
📞 [CallKit] Caller: Priti Lohar
📞 [CallKit] Room ID: EnclosurePowerfulNext1770560730
📞 [CallKit] Reporting incoming call:
✅ [CallKit] Successfully reported incoming call
✅ [CallKit] Caller photo downloaded successfully
```

## Troubleshooting

### Issue 1: Still Seeing Normal Notification Banner

**Cause**: Old Android code still sending `notification` object

**Solution**: 
1. Rebuild Android app with updated `FcmNotificationsSender.java`
2. Install on Android device
3. Test again

### Issue 2: No Call UI Shows at All

**Cause**: CallKitManager.swift not added to Xcode project

**Solution**:
1. Open Xcode
2. Check if `CallKitManager.swift` appears in Project Navigator under `Utility`
3. If not, follow Step 1 above to add it
4. Rebuild iOS app

### Issue 3: App Crashes When Call Arrives

**Cause**: CallKitManager.swift not compiled properly

**Solution**:
1. In Xcode, select `CallKitManager.swift`
2. Open File Inspector (right panel)
3. Under "Target Membership", ensure ✅ **Enclosure** is checked
4. Clean build folder (Product → Clean Build Folder)
5. Rebuild

### Issue 4: Call UI Shows But No Photo

**Cause**: Photo download delay or invalid URL

**Solution**:
- Check console for photo download logs
- Verify photo URL is accessible
- Photo will show after download completes (1-2 seconds)

## Test Scenarios

### ✅ Test 1: App in Foreground
1. iOS app is open and visible
2. Android sends call
3. Should see CallKit full-screen UI immediately

### ✅ Test 2: App in Background
1. iOS app is in background (home screen visible)
2. Android sends call
3. Should see CallKit full-screen UI immediately

### ✅ Test 3: App Terminated
1. Force quit iOS app (swipe up in app switcher)
2. Android sends call
3. Should see CallKit full-screen UI
4. Accept should launch app

### ✅ Test 4: Device Locked
1. Lock iOS device (power button)
2. Android sends call
3. Should see CallKit UI on lock screen
4. Slide to answer should work

### ✅ Test 5: Accept Call
1. Call arrives
2. Tap green Accept button
3. Should open VoiceCallScreen
4. Room should connect

### ✅ Test 6: Decline Call
1. Call arrives
2. Tap red Decline button
3. Call should dismiss
4. No app launch

## New Payload Structure (After Update)

### For Android (device_type == "1")
**UNCHANGED** - Still data-only
```json
{
  "message": {
    "token": "...",
    "data": { ... }
  }
}
```

### For iOS (device_type != "1")
**CHANGED** - Now data-only (removed notification object)
```json
{
  "message": {
    "token": "...",
    "data": { ... },
    "apns": {
      "headers": {
        "apns-push-type": "background",  ← Changed from "alert"
        "apns-priority": "10"
      },
      "payload": {
        "aps": {
          "content-available": 1,  ← Changed from "alert"
          "category": "VOICE_CALL"
        }
      }
    }
  }
}
```

**Key Differences**:
- ❌ NO `notification` object
- ❌ NO `alert` in `aps`
- ✅ YES `content-available: 1` (silent push)
- ✅ YES `apns-push-type: background`

## Expected Behavior

| Event | Old Behavior | New Behavior |
|-------|-------------|-------------|
| Call arrives (foreground) | Banner notification | Full-screen CallKit UI |
| Call arrives (background) | Banner notification | Full-screen CallKit UI |
| Call arrives (terminated) | Banner notification | Full-screen CallKit UI |
| Call arrives (locked) | Banner notification | CallKit on lock screen |
| Tap notification | Opens app | N/A (no banner) |
| Tap Accept | N/A | Opens VoiceCallScreen |
| Tap Decline | N/A | Dismisses call |

## Quick Checklist

Before testing, verify:

- [ ] Updated Android `FcmNotificationsSender.java`
- [ ] Rebuilt and installed Android app
- [ ] Added `CallKitManager.swift` to Xcode project
- [ ] Verified CallKitManager has Enclosure target checked
- [ ] Rebuilt and installed iOS app
- [ ] Testing on REAL iOS device (not simulator)
- [ ] iOS device is unlocked (for first test)
- [ ] Both devices have internet connection

## Success Indicators

✅ **You'll know it's working when**:
1. No banner notification appears on iOS
2. Full-screen native call UI appears instantly
3. Circular caller photo shows on left
4. Accept/Decline buttons work
5. Console shows CallKit logs

## Still Not Working?

1. Check Xcode build errors
2. Verify CallKitManager.swift is in compiled sources
3. Check console logs on both devices
4. Restart both devices
5. Test with another iOS device

The key change is **removing the notification banner** so CallKit can be the exclusive UI!
