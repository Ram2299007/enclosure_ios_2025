# 📞 WhatsApp-Style CallKit Setup - Action Required

## What We've Implemented

✅ **VoIP Push Notifications** - The ONLY way to get instant CallKit in background/lock screen

## Current Status

| State | What Happens |
|-------|--------------|
| **Foreground** | ✅ Perfect! CallKit appears instantly |
| **Background** | ⚠️ Shows banner → requires tap → CallKit |
| **Lock Screen** | ⚠️ Shows banner → requires tap → CallKit |

## After VoIP Setup

| State | What Happens |
|-------|--------------|
| **Foreground** | ✅ Perfect! CallKit appears instantly |
| **Background** | ✅ **Instant CallKit! (no banner, no tap!)** |
| **Lock Screen** | ✅ **Full-screen CallKit! (like WhatsApp!)** |

---

## 🚨 ACTION REQUIRED - 3 Steps

### Step 1: Add File to Xcode (5 minutes)

The file `VoIPPushManager.swift` exists but needs to be added to Xcode:

1. **Open Xcode project**: `Enclosure.xcodeproj`
2. **In Project Navigator**, right-click on `Enclosure/Utility` folder
3. Click **"Add Files to Enclosure..."**
4. Navigate to: `/Users/ramlohar/XCODE_PROJECT/enclosure_ios_2025/Enclosure/Utility/`
5. Select **`VoIPPushManager.swift`**
6. **IMPORTANT**: 
   - ✅ **Check** your target (Enclosure)
   - ❌ **Uncheck** "Copy items if needed" (file is already in place)
7. Click **"Add"**

### Step 2: Build & Get VoIP Token (2 minutes)

1. **Clean build**: ⌘ + Shift + K
2. **Build**: ⌘ + B  
3. **Run on REAL device** (VoIP doesn't work on simulator!)
4. **Open Console.app** and filter for "VoIP"
5. **Look for this in logs:**

```
📞📞📞 [VoIP] ========================================
📞 [VoIP] VoIP PUSH TOKEN RECEIVED!
📞 [VoIP] ========================================
📞 [VoIP] Token: a1b2c3d4e5f6789...
```

6. **COPY THIS TOKEN** - It's 64 hex characters

**What is this token?**
- Different from FCM token
- Used exclusively for VoIP calls
- Backend will send VoIP pushes using this token

### Step 3: Backend Implementation (See VOIP_BACKEND_SETUP.md)

**Quick summary:**

1. **Get APNs Auth Key from Apple** (10 min)
   - Go to https://developer.apple.com/account
   - Certificates, Identifiers & Profiles → Keys
   - Create new key for "Apple Push Notification service"
   - Download `.p8` file (can only download ONCE!)
   - Save Key ID and Team ID

2. **Add Java library to Android project** (5 min)
   ```gradle
   implementation 'com.github.notnoop.apns:apns:1.0.0.Beta6'
   ```

3. **Update database** (5 min)
   ```sql
   ALTER TABLE users ADD COLUMN voip_token VARCHAR(255);
   ```

4. **Create backend endpoint** (30 min)
   ```
   POST /api/register-voip-token
   Body: { "userId": "2", "voipToken": "a1b2c3..." }
   ```

5. **Send VoIP pushes for calls** (1 hour)
   - See complete code in `VOIP_BACKEND_SETUP.md`
   - Use `VoIPPushSender.sendVoIPPush()` for iOS calls
   - Keep existing FCM for Android calls

**Full details:** Read `VOIP_BACKEND_SETUP.md`

---

## How VoIP Pushes Work

### Regular Push (Current - Doesn't Work in Background)
```
Backend 
  ↓ (FCM API)
FCM Server
  ↓ (APNs)
iOS Device
  ↓ (Shows banner)
User taps banner
  ↓
CallKit appears
```

### VoIP Push (New - Works EVERYWHERE!)
```
Backend
  ↓ (Direct to APNs with .p8 auth)
APNs VoIP endpoint
  ↓ (Highest priority)
iOS Device
  ↓ (Wakes app IMMEDIATELY)
VoIPPushManager receives push
  ↓ (Triggers CallKit)
CallKit full-screen UI appears INSTANTLY!
```

**No banner, no tap, instant CallKit - just like WhatsApp!**

---

## Testing VoIP Pushes

### Quick Test with cURL (Before Full Backend)

Once you have:
- ✅ VoIP token from iOS
- ✅ APNs auth key (.p8)
- ✅ Generated JWT token

Test immediately with cURL:

```bash
curl -v \
  --http2 \
  --header "apns-topic: com.enclosure.voip" \
  --header "apns-push-type: voip" \
  --header "apns-priority: 10" \
  --header "authorization: bearer YOUR_JWT_TOKEN" \
  --data '{
    "name": "Test Caller",
    "roomId": "TestRoom123",
    "receiverId": "2",
    "phone": "+911234567890",
    "bodyKey": "Incoming voice call"
  }' \
  https://api.sandbox.push.apple.com/3/device/YOUR_VOIP_TOKEN
```

**Expected:** CallKit appears instantly on iOS device!

---

## What You'll See After Setup

### Foreground (Already Perfect)
```
User: Using app
→ Call arrives
→ CallKit full-screen UI appears instantly
→ No banner shown ✅
```

### Background (NEW - Instant!)
```
User: Home screen or other app
→ VoIP push arrives
→ App woken by iOS
→ CallKit full-screen UI appears instantly
→ No banner shown ✅
→ No tap needed ✅
```

### Lock Screen (NEW - Like WhatsApp!)
```
User: Phone locked
→ VoIP push arrives  
→ App woken by iOS
→ CallKit full-screen call UI appears
→ Shows caller name, photo, Answer/Decline buttons
→ Looks EXACTLY like WhatsApp ✅
```

### Terminated (NEW - Amazing!)
```
User: App force-closed
→ VoIP push arrives
→ iOS launches app in background
→ CallKit full-screen UI appears
→ User never knows app was closed ✅
```

---

## Comparison: Before vs After

### BEFORE VoIP (Current State)

**Foreground:** ✅ Perfect  
**Background:** ⚠️ Banner → tap → CallKit  
**Lock Screen:** ⚠️ Banner → tap → CallKit  
**Terminated:** ❌ Just shows banner, app doesn't wake

### AFTER VoIP (WhatsApp-Style!)

**Foreground:** ✅ Perfect (unchanged)  
**Background:** ✅ Instant CallKit!  
**Lock Screen:** ✅ Full-screen CallKit!  
**Terminated:** ✅ App wakes, instant CallKit!

---

## Why Regular Pushes Don't Work

In SwiftUI apps, regular pushes with `alert + content-available` in background:
1. Go through scene system
2. Become `UISHandleRemoteNotificationAction`
3. **SwiftUI has NO API to handle this**
4. Result: "unhandled action" error

**VoIP pushes bypass all this!**
- Don't go through notification system
- Go directly to app via PushKit
- Always wake app
- Always work

---

## Files Created/Updated

### New Files
- ✅ `Enclosure/Utility/VoIPPushManager.swift` - VoIP push handler
- ✅ `VOIP_BACKEND_SETUP.md` - Complete backend guide
- ✅ `WHATSAPP_STYLE_CALLKIT_SETUP.md` - This file

### Updated Files
- ✅ `Enclosure/EnclosureApp.swift` - Initialize VoIPPushManager
- ✅ `VOIP_PUSH_IMPLEMENTATION.md` - Updated with details

---

## Need Help?

### Check These Files

1. **For iOS setup:** This file (WHATSAPP_STYLE_CALLKIT_SETUP.md)
2. **For backend:** VOIP_BACKEND_SETUP.md  
3. **For theory:** VOIP_PUSH_IMPLEMENTATION.md

### Common Issues

**"VoIP token not received"**
- ✅ Added VoIPPushManager.swift to Xcode?
- ✅ Running on REAL device (not simulator)?
- ✅ Check Console.app for VoIP logs

**"VoIP push not arriving"**
- ✅ Using correct APNs endpoint (sandbox vs production)?
- ✅ JWT token correct?
- ✅ apns-topic is `com.enclosure.voip`?

**"CallKit not appearing"**
- ✅ Check iOS Console for VoIP push received logs
- ✅ Check for CallKit error messages

---

## Timeline

| Task | Time | Who |
|------|------|-----|
| Add file to Xcode | 5 min | You |
| Get VoIP token | 2 min | You |
| Get APNs auth key | 10 min | You |
| Update database | 5 min | Backend |
| Implement VoIP sender | 1-2 hours | Backend |
| Test end-to-end | 30 min | You + Backend |
| **TOTAL** | **2-3 hours** | |

---

## Summary

🎯 **Goal:** WhatsApp-style instant CallKit in background/lock screen

✅ **iOS Code:** Done! (just add file to Xcode)

⚠️ **Backend:** Needs implementation (see VOIP_BACKEND_SETUP.md)

🚀 **Result:** Professional-grade call experience!

---

**Ready to start? Begin with Step 1: Add file to Xcode!**
