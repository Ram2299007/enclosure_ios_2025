# 🔍 How to Check iOS Logs - Complete Guide

## Why You're Not Seeing Logs

There are 3 possible reasons:

1. **Notification not arriving** → Check FCM & device settings
2. **App not running properly** → Check app state
3. **Logs not visible in Xcode** → Use Console.app instead

---

## 📱 METHOD 1: Mac Console.app (MOST RELIABLE)

This shows ALL iOS device logs, even when Xcode doesn't.

### Steps:

1. **Open Console.app** on your Mac:
   - Press `Cmd + Space`
   - Type "Console"
   - Press Enter

2. **Connect your iPhone** via cable

3. **Select your iPhone** in the left sidebar

4. **Filter logs**:
   - In the search box (top right), type: `Enclosure`
   - OR type: `FCM`
   - OR type: `CallKit`

5. **Clear existing logs**:
   - Click "Clear" button (trash icon)

6. **Test the call**:
   - Make a call from Android
   - Watch Console.app for logs in real-time

### What to Look For:

```
🚨🚨🚨 [FCM] ============================================
🚨 [FCM] NOTIFICATION RECEIVED!!!
🚨 [FCM] App State: 0 (0=active, 1=inactive, 2=background)
```

**If you see this** → Notification is arriving! ✅  
**If you don't see this** → Notification NOT arriving ❌

---

## 📱 METHOD 2: Xcode Console (While Connected)

### Steps:

1. **Open Xcode**

2. **Connect iPhone via cable**

3. **Build & Run** (Cmd+R):
   - Select your iPhone as target
   - Click Run
   - Keep Xcode open

4. **Open Debug Console**:
   - Bottom panel should show automatically
   - If not: `View` → `Debug Area` → `Activate Console`
   - OR press: `Cmd + Shift + Y`

5. **Filter logs**:
   - In the search box at bottom, type: `🚨`
   - This will show the critical notification logs

6. **Test the call**:
   - Keep Xcode open with iPhone connected
   - Make call from Android
   - Watch debug console

### What to Look For:

```
🚨 [FCM] NOTIFICATION RECEIVED!!!
📱 [FCM] Full payload: ...
📱 [FCM] bodyKey = 'Incoming voice call'
📞📞📞 [CallKit] ✅ CALL NOTIFICATION DETECTED!
📞 [CallKit] ========== PROCESSING CALL NOTIFICATION ==========
```

---

## 📱 METHOD 3: Device Settings & Notifications

### Check if Push Notifications are Enabled:

On your **iPhone**:

1. Settings → **Enclosure**
2. Check **Notifications** is ON
3. Check **Allow Notifications** is ON
4. Check **Lock Screen** is ON
5. Check **Banners** is ON or OFF (doesn't matter for CallKit)

### Check Network:

- WiFi or cellular data connected?
- Try switching between WiFi and cellular

---

## 🔍 DEBUGGING CHECKLIST

Run through this in order:

### ✅ Step 1: Verify App is Registered for Push

In Console.app or Xcode console, after app launches, you should see:

```
📱 [APNS_TOKEN] ✅✅✅✅✅ APNs device token received
📤 [AppDelegate] didFinishLaunchingWithOptions CALLED
📱 [AppDelegate] NotificationDelegate set
```

**If you see this** → App is ready for notifications ✅  
**If you don't see this** → App not properly initialized ❌

### ✅ Step 2: Check FCM Token

In your iOS app, the FCM token should be:
```
fhbXC_ilJE-aj_8gtRDTtp:APA91bHzpIUuKSi9UyLZCKJ3AvhWaVbTVqdXRV_xMsWnKccX3pfZZSGP-sMi2r5CHAloQKWayRlD3x_koMBhLWaz_qr70hbqxOuM25026BoEKXZYbvQ3fo8
```

This is stored in UserDefaults. Check if it matches what Android is sending to.

### ✅ Step 3: Verify Android is Sending

In Android Studio Logcat, you should see:

```
📞 [FCM] Using iOS CallKit payload (data-only with content-available)
📤 [FCM] Payload: { ... }
✅ [FCM] Call notification sent successfully
```

**If Android shows this** → Notification was sent ✅  
**Now check if iOS receives it...**

### ✅ Step 4: Check iOS Receives Notification

In Console.app or Xcode, you should see **within 1-2 seconds** of Android sending:

```
🚨🚨🚨 [FCM] ============================================
🚨 [FCM] NOTIFICATION RECEIVED!!!
```

**If you see this** → iOS received the notification! ✅  
**If you don't see this** → Problem with FCM delivery ❌

### ✅ Step 5: Check bodyKey is Correct

In the same logs, look for:

```
📱 [FCM] bodyKey = 'Incoming voice call'
```

**If bodyKey is correct** → Good! ✅  
**If bodyKey is different** → Check Android payload ❌

### ✅ Step 6: Check CallKit is Called

You should see:

```
📞📞📞 [CallKit] ✅ CALL NOTIFICATION DETECTED!
📞 [CallKit] ========== PROCESSING CALL NOTIFICATION ==========
📞 [CallKit] Extracted data:
   - Caller Name: 'Priti Lohar'
   - Room ID: 'EnclosurePowerfulNext...'
```

**If you see this** → CallKit handler called ✅  
**If you don't see this** → bodyKey check failed ❌

### ✅ Step 7: Check CallKit Reports Call

You should see:

```
✅ [CallKit] Call reported successfully
```

**If you see this** → CallKit UI should appear! ✅  
**If you see error instead** → Check error message ❌

---

## 🚨 COMMON ISSUES & SOLUTIONS

### Issue 1: No Logs in Xcode at All

**Solution**: Use Console.app instead
- Xcode sometimes doesn't capture background notifications
- Console.app is more reliable

### Issue 2: "NOTIFICATION NOT RECEIVED" (iOS)

**Possible Causes**:
1. **Wrong FCM token** → Verify token in iOS matches Android's target
2. **App not running** → Open app once, then lock device and test
3. **Network issue** → Try different WiFi/cellular
4. **FCM project mismatch** → Verify `enclosure-30573` project ID

**Solution**: Check Android logs first, then iOS device settings

### Issue 3: Notification Received but bodyKey is Wrong

**Check Android payload**. The `bodyKey` in the `data` object should be:
```json
"data": {
  "bodyKey": "Incoming voice call"
}
```

NOT inside `aps` or `notification` objects!

### Issue 4: bodyKey Correct but CallKit Not Called

**Check the exact string**. It must be EXACTLY:
- `"Incoming voice call"` for voice calls
- `"Incoming video call"` for video calls

Case-sensitive, no extra spaces!

### Issue 5: CallKit Called but No UI

**Check iOS device state**:
1. Device must be **unlocked** for first test
2. App must be in **foreground** or **background** (not terminated for first test)
3. After it works once, try with device locked

---

## 📋 STEP-BY-STEP TESTING PROCESS

Do this in order:

1. **Clean & Rebuild iOS app in Xcode**
   - Product → Clean Build Folder
   - Product → Build
   - Product → Run (on real iPhone!)

2. **Open Console.app on Mac**
   - Select your iPhone
   - Filter: `Enclosure`
   - Click "Clear" to remove old logs

3. **Launch iOS app**
   - Should see: `didFinishLaunchingWithOptions CALLED`
   - Should see: `APNs device token received`

4. **Keep iOS app in foreground**
   - Don't close or lock yet

5. **Open Android Studio**
   - View → Tool Windows → Logcat
   - Filter: `FCM`

6. **Make call from Android**
   - Tap call button
   - Watch Android Logcat for: `✅ [FCM] Call notification sent successfully`

7. **Watch Console.app immediately**
   - Within 1-2 seconds, should see: `🚨 [FCM] NOTIFICATION RECEIVED!!!`

8. **Check iOS device screen**
   - Should show full-screen CallKit UI
   - Circular photo + Accept/Decline buttons

---

## 🎯 Expected Full Log Sequence

When everything works, you'll see this sequence:

### iOS Console.app / Xcode:

```
🚨🚨🚨 [FCM] ============================================
🚨 [FCM] NOTIFICATION RECEIVED!!!
🚨 [FCM] App State: 0
📱 [FCM] Full payload: { ... }
📱 [FCM] Keys present: bodyKey, name, photo, roomId, ...
📱 [FCM] bodyKey = 'Incoming voice call'
📱 [FCM] APS present: true
📱 [FCM] APS alert present: false
📱 [FCM] mutable-content: false
🔍 [FCM] Checking bodyKey: 'Incoming voice call'
📞📞📞 [CallKit] ✅ CALL NOTIFICATION DETECTED! bodyKey = 'Incoming voice call'
📞📞📞 [CallKit] ========== PROCESSING CALL NOTIFICATION ==========
📞 [CallKit] Extracted data:
   - Caller Name: 'Priti Lohar'
   - Caller Photo: 'https://...'
   - Room ID: 'EnclosurePowerfulNext1770562445'
   - Receiver ID: '2'
   - Receiver Phone: '+918379887185'
✅ [CallKit] Call reported successfully
```

### iOS Device Screen:

Full-screen native call UI appears!

---

## 🆘 Still Not Working?

If you've tried all of the above:

1. **Share the logs** from Console.app:
   - Select all log lines
   - Copy & paste

2. **Share Android logs** from Logcat:
   - Filter: `FCM`
   - Copy the payload section

3. **Check these files**:
   - `Info.plist` → `UIBackgroundModes` should include `voip`
   - `CallKitManager.swift` → Should exist in Xcode project
   - Project → Enclosure target → Signing & Capabilities → Push Notifications enabled

4. **Try a fresh install**:
   - Delete app from iPhone
   - Clean build folder in Xcode
   - Rebuild and reinstall

---

## 💡 Quick Console.app Setup

```bash
# Open Console.app
open -a Console

# OR from terminal, follow live logs:
log stream --predicate 'subsystem contains "Enclosure"' --level debug
```

In the terminal command, you'll see real-time logs as they happen!

---

## ✅ Success Indicators

You'll know it's working when:

1. ✅ Android logs show: `✅ [FCM] Call notification sent successfully`
2. ✅ iOS Console.app shows: `🚨 [FCM] NOTIFICATION RECEIVED!!!`
3. ✅ iOS Console.app shows: `📞📞📞 [CallKit] ✅ CALL NOTIFICATION DETECTED!`
4. ✅ iOS Console.app shows: `✅ [CallKit] Call reported successfully`
5. ✅ **iOS device shows full-screen CallKit UI**

All 5 must happen in sequence! 🎯
