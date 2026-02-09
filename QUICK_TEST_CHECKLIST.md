# ⚡ Quick Test Checklist - 5 Minutes

Follow this exact sequence to debug why you're not seeing CallKit UI:

---

## 🔴 STEP 1: Clean & Rebuild (2 minutes)

In Xcode:

1. **Product** → **Clean Build Folder** (⇧⌘K)
   - Wait for "Clean Complete"

2. **Product** → **Build** (⌘B)
   - Wait for "Build Succeeded"
   - If errors appear, **STOP** and fix them

3. **Product** → **Run** (⌘R)
   - Select **real iPhone** (not simulator!)
   - Wait for app to launch on device

---

## 🔴 STEP 2: Open Console.app (30 seconds)

On your Mac:

1. Press **Cmd + Space**
2. Type: `Console`
3. Press Enter
4. In left sidebar, click your **iPhone name**
5. In search box (top right), type: `🚨`
6. Click "Clear" button (trash icon) to remove old logs

**Keep Console.app open and visible!**

---

## 🔴 STEP 3: Verify App is Ready (30 seconds)

In Console.app, you should already see these logs from when app launched:

```
📤 [AppDelegate] didFinishLaunchingWithOptions CALLED
📱 [APNS_TOKEN] ✅✅✅✅✅ APNs device token received
```

**✅ If you see both** → App is ready! Continue to Step 4.

**❌ If you DON'T see these**:
   - App is not properly initialized
   - In Xcode, check the debug console (bottom panel)
   - Check for build errors or crash logs

---

## 🔴 STEP 4: Keep iOS App Running (5 seconds)

On your iPhone:

- **Keep app in FOREGROUND** (don't minimize, don't lock!)
- Just leave it open on the main screen

---

## 🔴 STEP 5: Make Test Call (30 seconds)

From Android device:

1. Open Enclosure app
2. Tap on "My Hubby 💘" (the iOS user)
3. Tap **Voice Call** button
4. **IMMEDIATELY look at both**:
   - Console.app on Mac
   - iPhone screen

---

## 🎯 WHAT YOU SHOULD SEE

### On Mac Console.app (within 1-2 seconds):

```
🚨🚨🚨 [FCM] ============================================
🚨 [FCM] NOTIFICATION RECEIVED!!!
🚨 [FCM] App State: 0
```

### On iPhone (immediately after):

**FULL-SCREEN CALL UI** should appear!

```
┌─────────────────────────────────┐
│                                 │
│  ⭕ Priti Lohar                 │
│     Enclosure            📱     │
│                                 │
│                                 │
│  🔴 Decline         Accept 🟢  │
│                                 │
└─────────────────────────────────┘
```

---

## ❌ IF YOU DON'T SEE CALLKIT UI

### Scenario A: Console.app shows NO logs at all

**Problem**: Notification is NOT arriving to iOS

**Debugging**:

1. In Console.app, remove the `🚨` filter → just type `Enclosure`
2. Check if you see ANY logs from your app
3. If NO logs at all → App is not running properly

**Solutions**:
- Uninstall app from iPhone
- Clean Build Folder in Xcode
- Rebuild and reinstall
- Check iPhone Settings → Notifications → Enclosure is allowed

### Scenario B: Console.app shows "NOTIFICATION RECEIVED" but no CallKit UI

**Problem**: Notification arrived, but CallKit not showing

**What to check in Console.app** (look for these exact lines):

```
📱 [FCM] bodyKey = 'Incoming voice call'
```

**If bodyKey is correct**:
- Look for: `📞📞📞 [CallKit] ✅ CALL NOTIFICATION DETECTED!`
- If you see this → Continue reading logs
- Look for: `✅ [CallKit] Call reported successfully`

**If you see error instead**:
- Copy the error message
- Share it

**If bodyKey is NOT 'Incoming voice call'**:
- The Android payload is wrong
- Check Android logs for what was sent

### Scenario C: Console.app shows "Call reported successfully" but still no UI

**Problem**: CallKit was called but UI didn't appear

**Possible causes**:
1. CallKitManager.swift not compiled into app
2. iOS CallKit permissions not granted
3. Device-specific issue

**Solutions**:

1. Check Xcode Project Navigator:
   - Look for `Enclosure` → `Utility` → `CallKitManager.swift`
   - If you DON'T see it → Manually add it:
     - Right-click `Utility` folder
     - "Add Files to Enclosure..."
     - Select `CallKitManager.swift`
     - Make sure "Enclosure" target is checked
     - Click "Add"

2. Rebuild after adding:
   - Clean Build Folder
   - Build
   - Run

3. Check iPhone Settings:
   - Settings → Phone
   - "Call Blocking & Identification"
   - See if "Enclosure" appears
   - Enable it if it does

---

## 📊 DECISION TREE

```
Start Here
    ↓
[Clean & Rebuild] → [Open Console.app] → [Make Call]
    ↓
Console.app shows logs?
    ↓
   YES                                    NO
    ↓                                     ↓
Shows "NOTIFICATION RECEIVED"?      App not running properly
    ↓                               → Reinstall app
   YES              NO
    ↓               ↓
Shows bodyKey?      Notification not arriving
    ↓               → Check FCM token
   YES              → Check network
    ↓
bodyKey = "Incoming voice call"?
    ↓
   YES              NO
    ↓               ↓
Shows "CALL         Android payload wrong
NOTIFICATION        → Check Android logs
DETECTED"?          → Verify data.bodyKey field
    ↓
   YES              NO
    ↓               ↓
Shows "Call         bodyKey check failed
reported            → Check exact string match
successfully"?      → Case sensitive!
    ↓
   YES              NO
    ↓               ↓
CallKit UI          CallKit error
appears?            → Copy error message
    ↓               → Share error
   YES              NO
    ↓               ↓
✅ SUCCESS!    CallKitManager.swift not in project
                   → Add file to Xcode
                   → Rebuild
```

---

## 🚨 CRITICAL: What Logs to Share

If still not working after all steps, share these logs:

### From Mac Console.app:

Filter for `Enclosure`, then copy ALL logs from the moment you made the call.

Should include:
- `🚨 [FCM] NOTIFICATION RECEIVED!!!` (or not)
- `📱 [FCM] bodyKey = ...`
- `📞 [CallKit]` lines

### From Android Logcat:

Filter for `FCM`, then copy:
- The payload being sent
- The response from FCM

---

## ⏱️ Timeline

When working correctly:

```
T=0s:    Android taps call button
T=0.1s:  Android logs: "Sending call notification"
T=0.5s:  Android logs: "✅ Call notification sent successfully"
T=1s:    iOS Console.app logs: "🚨 NOTIFICATION RECEIVED!!!"
T=1.1s:  iOS Console.app logs: "📞 CALL NOTIFICATION DETECTED!"
T=1.2s:  iOS device: Full-screen CallKit UI appears ✅
```

**Total time**: ~1-2 seconds from Android button tap to iOS CallKit UI

If it takes longer or never happens, there's a problem in the chain!

---

## ✅ Success Criteria

You'll know it's working when you see:

1. ✅ Console.app shows: `🚨 [FCM] NOTIFICATION RECEIVED!!!`
2. ✅ Console.app shows: `📞📞📞 [CallKit] ✅ CALL NOTIFICATION DETECTED!`
3. ✅ Console.app shows: `✅ [CallKit] Call reported successfully`
4. ✅ **iPhone shows full-screen CallKit UI with Accept/Decline buttons**

All 4 must happen! If any is missing, go back to the decision tree. 🎯
