# ⚡ QUICK FIX - Do This Right Now!

## 🎯 Problem: Using FCM Token Instead of VoIP Token

**Your logs show:**
```
❌ VoIP Token: cWXCYutVCEItm9JpJbkVF1:APA91b... ← FCM token (WRONG!)
❌ APNs Response: {"reason":"BadDeviceToken"}
```

**Should be:**
```
✅ VoIP Token: 416951db5bb2d8dd836060f8deb6725e... ← VoIP token (64 hex chars)
```

---

## 🔧 ONE CODE CHANGE TO FIX IT

### File: `FcmNotificationsSender.java`

**Find line ~240 (in the `sendVoIPPushToAPNs()` method):**

```java
// TODO: Get VoIP token from database (separate from FCM token)
// For now, using FCM token as placeholder
String voipToken = userFcmToken;
```

### ✅ REPLACE WITH THIS:

```java
// TEMPORARY FIX: Hardcoded VoIP token for testing
// Your iOS VoIP token (64 hex characters)
String voipToken = "416951db5bb2d8dd836060f8deb6725e049e048c1f41669b9f8fc94500b689e6";

// Validate it's a real VoIP token, not FCM
if (voipToken == null || voipToken.isEmpty()) {
    System.err.println("❌ [VOIP] VoIP token is empty");
    return;
}

if (voipToken.contains(":") || voipToken.contains("APA91b")) {
    System.err.println("❌ [VOIP] ERROR: This is an FCM token, not a VoIP token!");
    System.err.println("❌ [VOIP] FCM token: " + voipToken);
    System.err.println("❌ [VOIP] Need VoIP token from iOS app (64 hex characters)");
    return;
}

System.out.println("✅ [VOIP] Using valid VoIP token (64 hex chars)");
```

---

## 🚀 Test Again!

1. **Save the file**
2. **Rebuild Android backend**
3. **Send call from Android to iOS**
4. **Check logs:**

### Expected SUCCESS logs:

```
✅ [VOIP] Using valid VoIP token (64 hex chars)
🔑 [APNs JWT] JWT token created successfully!
📞 [VOIP] APNs Response Status: 200 ← Should be 200 now!
✅ [VOIP] VoIP Push sent SUCCESSFULLY!
```

### Expected iOS behavior:

```
📞 [VoIP] INCOMING VOIP PUSH RECEIVED!
🎉 INSTANT CALLKIT APPEARS!
```

---

## 📊 Before vs After

### BEFORE (Current - FAILS):
```
VoIP Token: cWXCYutVCEItm9JpJbkVF1:APA91b... ← FCM (has colons)
APNs Response: 400 ❌
Error: BadDeviceToken
```

### AFTER (With Fix - SUCCESS):
```
VoIP Token: 416951db5bb2d8dd836060f8deb6725e... ← VoIP (pure hex)
APNs Response: 200 ✅
CallKit appears instantly! 🎉
```

---

## 🎯 Summary

**Change 1 line:**
```java
String voipToken = "416951db5bb2d8dd836060f8deb6725e049e048c1f41669b9f8fc94500b689e6";
```

**Test → Should work!**

---

**DO THIS NOW AND TEST! Share the new logs!** 🚀
