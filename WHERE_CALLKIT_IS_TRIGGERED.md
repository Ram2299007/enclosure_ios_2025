# 📍 WHERE CallKit is Triggered for Voice/Video Calls

## 🎯 You Want: Instant Full-Screen CallKit in Background

**Current:** Background shows simple banner ❌
**Want:** Instant full-screen CallKit (WhatsApp style) ✅

---

## 📂 File Locations - Complete Flow

### 1️⃣ VoIP Push Arrives (Background/Lock Screen)

**File:** `Enclosure/Utility/VoIPPushManager.swift`

**Line 88-201:** Method that handles incoming VoIP pushes

```swift
// LINE 88: THIS METHOD IS CALLED WHEN VOIP PUSH ARRIVES! 🎯
func pushRegistry(_ registry: PKPushRegistry, 
                 didReceiveIncomingPushWith payload: PKPushPayload, 
                 for type: PKPushType, 
                 completion: @escaping () -> Void) {
    
    // Extract call data from VoIP push
    let callerName = userInfo["name"] as? String ?? "Unknown"
    let roomId = userInfo["roomId"] as? String ?? ""
    // ... extract other data ...
    
    // LINE 148: TRIGGER CALLKIT INSTANTLY! 🚀
    CallKitManager.shared.reportIncomingCall(
        callerName: callerName,
        callerPhoto: callerPhoto,
        roomId: roomId,
        receiverId: receiverId,
        receiverPhone: receiverPhone
    ) { error in
        // CallKit appears INSTANTLY!
        // Works in: foreground, background, lock screen!
    }
}
```

**When Called:**
- ✅ Only when **VoIP Push** arrives from APNs
- ✅ Works in **ALL app states** (foreground, background, terminated, lock screen)
- ✅ Triggers **instant CallKit** (no banner, no tap needed!)

**NOT Called When:**
- ❌ Regular FCM push arrives (shows banner instead)
- ❌ Test button tapped in foreground (different code path)

---

### 2️⃣ CallKit Display Logic

**File:** `Enclosure/Utility/CallKitManager.swift`

**Line ~50-120:** `reportIncomingCall()` method

```swift
func reportIncomingCall(
    callerName: String,
    callerPhoto: String,
    roomId: String,
    receiverId: String,
    receiverPhone: String,
    completion: ((Error?) -> Void)? = nil
) {
    // Create CallKit call update
    let update = CXCallUpdate()
    update.remoteHandle = CXHandle(type: .generic, value: callerName)
    update.localizedCallerName = callerName
    update.hasVideo = false  // or true for video calls
    
    // Report to CallKit - SHOWS FULL-SCREEN UI!
    provider.reportNewIncomingCall(with: uuid, update: update) { error in
        if error == nil {
            // ✅ CallKit UI is now showing!
        }
    }
}
```

**What This Does:**
- Shows **full-screen CallKit UI**
- Works **instantly** (no delay)
- Shows **Answer/Decline buttons**
- Looks exactly like **WhatsApp/FaceTime**

---

### 3️⃣ Regular Notification Handler (Foreground Only)

**File:** `Enclosure/Utility/NotificationDelegate.swift`

**Line 50-150:** `userNotificationCenter(_:willPresent:)` 

```swift
// This handles REGULAR notifications when app is in FOREGROUND
func userNotificationCenter(_ center: UNUserNotificationCenter, 
                           willPresent notification: UNNotification, 
                           withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    
    // Check if it's a call notification
    if bodyKey.contains("voice call") || bodyKey.contains("video call") {
        // Trigger CallKit
        CallKitManager.shared.reportIncomingCall(...)
    }
}
```

**When Called:**
- ✅ App is in **FOREGROUND**
- ✅ Regular FCM push arrives

**Limitation:**
- ❌ **NOT called in background!**
- ❌ Background shows banner instead

---

## 🔄 Complete Notification Flow

### Current Situation (FCM Push):

```
FOREGROUND:
Backend → FCM → iOS Device → NotificationDelegate.willPresent()
                                      ↓
                              CallKitManager.reportIncomingCall()
                                      ↓
                              ✅ Instant CallKit!

BACKGROUND/LOCK SCREEN:
Backend → FCM → iOS Device → Shows banner notification
                                      ↓
                              User taps banner
                                      ↓
                              NotificationDelegate.didReceive()
                                      ↓
                              CallKitManager.reportIncomingCall()
                                      ↓
                              CallKit appears (delayed) ❌
```

### Required Solution (VoIP Push):

```
ALL STATES (Foreground, Background, Lock Screen, Terminated):
Backend → APNs (VoIP) → iOS Device → VoIPPushManager.pushRegistry()
                                             ↓
                                    CallKitManager.reportIncomingCall()
                                             ↓
                                    ✅ INSTANT Full-Screen CallKit! 🎉
                                             ↓
                                    No banner, no tap, instant!
```

---

## 🚨 The Critical Problem

**Your Backend Code:**
```java
// Line 114-127 in FcmNotificationsSender.java
if (Constant.voicecall.equals(body)) {
    aps.put("category", "VOICE_CALL");  // ❌ Sends to FCM
}
```

**Sends:** Regular FCM Push
**Result:** Background shows banner ❌

**Must Change To:**
```java
// Check if iOS call
if (device_type.equals("2") && isCallNotification) {
    sendVoIPPushToAPNs(voipToken, callData);  // ✅ Direct to APNs
    return;  // Don't send FCM!
}
```

**Sends:** VoIP Push to APNs
**Result:** Instant CallKit! ✅

---

## 📋 Summary: Where Each Type is Handled

| Notification Type | App State | Handler | Result |
|-------------------|-----------|---------|--------|
| **VoIP Push** (call) | Foreground | `VoIPPushManager.pushRegistry()` Line 88 | ✅ Instant CallKit |
| **VoIP Push** (call) | Background | `VoIPPushManager.pushRegistry()` Line 88 | ✅ Instant CallKit |
| **VoIP Push** (call) | Lock Screen | `VoIPPushManager.pushRegistry()` Line 88 | ✅ Instant CallKit |
| **VoIP Push** (call) | Terminated | `VoIPPushManager.pushRegistry()` Line 88 | ✅ Instant CallKit |
| **FCM Push** (call) | Foreground | `NotificationDelegate.willPresent()` | ✅ Instant CallKit |
| **FCM Push** (call) | Background | Shows banner → user taps | ❌ Delayed CallKit |

**Bottom Line:** VoIP Push = Instant CallKit in ALL states! 🎯

---

## ✅ Your iOS Code is Perfect!

**These files handle CallKit correctly:**
- ✅ `VoIPPushManager.swift` - Handles VoIP pushes (Line 88-201)
- ✅ `CallKitManager.swift` - Shows CallKit UI
- ✅ `NotificationDelegate.swift` - Handles foreground FCM

**Problem:** Backend sends FCM (not VoIP) for calls!

---

## 🔧 Action Required

**Backend developer must:**
1. Get APNs Auth Key (.p8) from Apple
2. Add `sendVoIPPushToAPNs()` method
3. Send VoIP pushes for iOS calls (NOT FCM)

**See complete code:** `BACKEND_VOIP_CHANGES_REQUIRED.md`

**Your VoIP Token:** `416951db5bb2d8dd836060f8deb6725e049e048c1f41669b9f8fc94500b689e6`

---

**iOS is ready! Just waiting for backend to send VoIP pushes!** 🚀
