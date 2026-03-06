# Debug WhatsApp-Style Notification

## Problem: Notification साधा दिसतो (simple), WhatsApp सारखा नाही

## Solution Steps:

### Step 1: Xcode Console Logs तपासा

1. **Xcode उघडा**
2. Device connect करा
3. App run करा
4. Bottom मध्ये **Console** panel उघडा (View → Debug Area → Activate Console)
5. Search box मध्ये type करा: `NotificationService`
6. Backend वरून notification पाठवा
7. हे logs दिसतील का ते तपासा:

#### Expected Logs (यावे लागणारे logs):

```
🔔 [NotificationService] didReceive invoked
🔔 [NotificationService] APS present: alert=true mutable-content=1 category=CHAT_MESSAGE
🔔 [NotificationService] bodyKey: chatting
🔔 [NotificationService] Preparing Communication Notification:
   - senderName: Ram
   - senderUid: 12345
   - message: Hello
   - photoUrl: https://...
✅ [NotificationService] Updated notification with INSendMessageIntent
   - Sender: Ram
   - Has image: true
   - Message: Hello
```

#### If Logs Missing:

**Problem 1: कोणतेही NotificationService logs नाहीत**
- Extension execute होत नाही
- Solution: Backend payload तपासा

**Problem 2: "bodyKey != 'chatting'" दिसतो**
- Backend मध्ये bodyKey missing आहे
- Solution: Backend payload मध्ये bodyKey: "chatting" add करा

**Problem 3: "Failed to update from intent" error**
- INSendMessageIntent fail होतो
- Solution: iOS version, entitlements check करा

---

### Step 2: Backend Payload Verify करा

**तुमच्या backend (send_notification_ios.php) मध्ये हे confirm करा:**

#### Required Fields:

```json
{
  "message": {
    "token": "device_token_here",
    "data": {
      "bodyKey": "chatting",              // ✅ CRITICAL
      "user_nameKey": "Ram Lohar",        // Sender name
      "friendUidKey": "user123",          // Sender UID
      "msgKey": "Hello, how are you?",    // Message text
      "photo": "https://example.com/profile.jpg"  // Profile picture URL
    },
    "apns": {
      "headers": {
        "apns-push-type": "alert",
        "apns-priority": "10"
      },
      "payload": {
        "aps": {
          "alert": {
            "title": "Ram Lohar",
            "body": "Hello, how are you?"
          },
          "sound": "default",
          "badge": 1,
          "mutable-content": 1,           // ✅ CRITICAL (must be 1, not 0)
          "category": "CHAT_MESSAGE"       // ✅ CRITICAL
        }
      }
    }
  }
}
```

---

### Step 3: Test करण्यासाठी Simple Debugging

#### A) मोबाईल console वरून logs पहा:

**Mac Console App वापरा:**
1. Mac वर **Console.app** उघडा (Applications → Utilities → Console)
2. Device select करा left sidebar मध्ये
3. Search box मध्ये type करा: `NotificationService`
4. Backend वरून notification पाठवा
5. Real-time logs दिसतील

#### B) NotificationService मध्ये Extra Debug Logs:

File: `EnclosureNotificationService/NotificationService.swift`

Line 26 च्या खाली हे check logs आहेत:
```swift
NSLog("🔔 [NotificationService] didReceive invoked")
NSLog("🔔 [NotificationService] APS present: alert=\(hasAlert) mutable-content=\(mutableContent) category=\(category)")
```

हे logs दिसत नसतील तर Extension execute होत नाही.

---

### Step 4: Common Issues & Solutions

#### Issue 1: Extension Execute होत नाही

**Symptoms:**
- कोणतेही NotificationService logs नाहीत
- साधा notification दिसतो

**Solution:**
```
1. Check मध्ये mutable-content = 1 आहे का backend payload
2. Extension properly linked आहे का Xcode मध्ये
3. App fresh install करा (delete + reinstall)
```

#### Issue 2: "bodyKey != 'chatting'" दिसतो

**Symptoms:**
- Extension execute होतो पण skip होतो
- Log: "bodyKey != 'chatting' (got: 'nil')"

**Solution:**
Backend मध्ये `data` object मध्ये हे add करा:
```json
"data": {
  "bodyKey": "chatting"  // ← Add this
}
```

#### Issue 3: Profile Picture नाही दिसत

**Symptoms:**
- Notification दिसतो पण profile pic नाही
- Log: "photoUrl: MISSING"

**Solution:**
Backend payload मध्ये:
```json
"data": {
  "photo": "https://your-server.com/profile.jpg"  // Valid URL
}
```

#### Issue 4: INSendMessageIntent Error

**Symptoms:**
- Log: "Failed to update from intent: ..."

**Solution:**
```
1. iOS 15+ असणे गरजेचे (तुमच्याकडे आहे)
2. Main app Info.plist मध्ये NSUserActivityTypes check करा (आधीच आहे ✅)
3. App delete करून fresh install करा
```

---

### Step 5: Quick Test

**Console वर हे command run करा (Backend Testing):**

तुमच्या backend API ला test request पाठवा आणि response तपासा:

```bash
# Test notification send
curl -X POST https://your-backend.com/send_notification_ios.php \
  -H "Content-Type: application/json" \
  -d '{
    "deviceToken": "YOUR_DEVICE_TOKEN",
    "accessToken": "YOUR_FCM_TOKEN",
    "user_name": "Test User",
    "body": "Test message",
    "photo": "https://picsum.photos/200"
  }'
```

Response मध्ये हे असावे:
```json
{
  "status": "success",
  "platform": "ios",
  "has_mutable_content": true,  // ← Must be true
  "is_silent_push": false        // ← Must be false
}
```

---

## Final Checklist:

✅ **Backend Payload:**
- [ ] `mutable-content: 1` (not 0)
- [ ] `bodyKey: "chatting"` in data
- [ ] `category: "CHAT_MESSAGE"`
- [ ] `user_nameKey` has sender name
- [ ] `friendUidKey` has sender UID
- [ ] `photo` has valid URL

✅ **iOS App:**
- [ ] iOS 15+ version
- [ ] App fresh installed (not over old version)
- [ ] NotificationService extension linked properly
- [ ] Console logs visible

✅ **Expected Result:**
- [ ] 🔔 Notification arrived
- [ ] 👤 Circular profile picture on LEFT
- [ ] 📝 Name and message on RIGHT
- [ ] 📱 App icon at bottom right

---

## Need Help?

**Check these logs specifically:**

1. `🔔 [NotificationService] didReceive invoked` - Extension started?
2. `bodyKey: chatting` - Correct category?
3. `photoUrl:` - Profile picture URL present?
4. `✅ Updated notification with INSendMessageIntent` - Success?

**If still not working, share:**
- Console logs screenshot
- Backend response JSON
- Notification appearance screenshot

मदत हवी असल्यास हे माहिती share करा!
