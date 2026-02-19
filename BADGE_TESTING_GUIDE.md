# Badge Count Testing Guide (मराठीत)

## 🧪 Testing करण्यासाठी Steps

### Preparation (तयारी)

1. **App Fresh Install करा:**
   ```bash
   # Device वरून app delete करा
   # Xcode मधून fresh install करा
   ```

2. **Notification Permission द्या:**
   - App open करा
   - Notification permission accept करा
   - Settings → Notifications → Enclosure → Allow Notifications ✅

3. **Backend Ready ठेवा:**
   - `send_notification_ios.php` working असावे
   - Device token ready असावे

---

## Test Case 1: Single Notification Badge

### Steps:
1. App background मध्ये ठेवा (Home button दाबा)
2. Backend वरून **1 notification** पाठवा
3. Home screen पहा

### Expected Result:
- ✅ App icon वर **badge "1"** दिसेल
- ✅ Notification banner दिसेल

### Console Logs:
```
📱 [NotificationService] Badge updated: 0 -> 1
```

---

## Test Case 2: Multiple Notifications Badge

### Steps:
1. App background मध्ये ठेवा
2. Backend वरून **3 notifications** पाठवा (different users)
3. Home screen पहा

### Expected Result:
- ✅ Badge count **"3"** दिसेल
- ✅ प्रत्येक notification banner दिसेल

### Console Logs:
```
📱 [NotificationService] Badge updated: 0 -> 1
📱 [NotificationService] Badge updated: 1 -> 2
📱 [NotificationService] Badge updated: 2 -> 3
```

---

## Test Case 3: Dismiss Notification (Badge Decrement)

### Steps:
1. Badge count = 3 (3 notifications)
2. Notification Center उघडा (swipe down)
3. **1 notification swipe करून dismiss करा**
4. Home screen पहा

### Expected Result:
- ✅ Badge count **"2"** होईल (3 → 2)

### Console Logs:
```
📱 [NotificationDelegate] User dismissed notification
📱 [BadgeManager] Badge decremented: 3 -> 2
```

---

## Test Case 4: Open Chat (Badge Clear)

### Steps:
1. Badge count = 3
2. Chat A मध्ये 2 unread messages
3. App open करा
4. **Chat A open करा**
5. Home screen पहा

### Expected Result:
- ✅ Badge count **"1"** होईल (3 - 2 = 1)
- ✅ Chat A मध्ये notification badge "0" दिसेल
- ✅ Firebase मध्ये notification count = 0

### Console Logs:
```
📱 [MainActivityOld] Clearing notification count: 2 for user: abc123
✅ [BadgeManager] Notification count cleared in Firebase
📱 [BadgeManager] Badge decremented by 2: 3 -> 1
```

---

## Test Case 5: Multiple Chats With Unread

### Setup:
- Chat A: 2 unread messages
- Chat B: 3 unread messages
- Chat C: 1 unread message
- **Total badge: 6**

### Test 5A: Open Chat B
**Steps:**
1. App open करा
2. Chat B open करा

**Expected:**
- ✅ Badge: 6 → **3** (6 - 3 = 3)
- ✅ Chat B notification badge = 0
- ✅ Chat A notification badge = 2 (unchanged)
- ✅ Chat C notification badge = 1 (unchanged)

### Test 5B: Open Chat A Next
**Steps:**
1. Back button दाबा
2. Chat A open करा

**Expected:**
- ✅ Badge: 3 → **1** (3 - 2 = 1)
- ✅ Chat A notification badge = 0
- ✅ Chat C notification badge = 1 (unchanged)

---

## Test Case 6: App Reopen (Badge Sync)

### Steps:
1. Badge count = 4
2. App **completely kill** करा (swipe up in app switcher)
3. Wait 2 seconds
4. App पुन्हा open करा

### Expected Result:
- ✅ Badge count **4** दिसेल (preserved)
- ✅ ChatView मध्ये सर्व unread counts दिसतील

### Console Logs:
```
📱 [BadgeManager] Syncing badge with delivered notifications: 4
📱 [chatView] Badge recalculated from 12 chats
```

---

## Test Case 7: Foreground Notification

### Steps:
1. App **foreground** मध्ये ठेवा (open)
2. Backend वरून notification पाठवा

### Expected Result:
- ✅ Notification **banner दिसेल** (top of screen)
- ✅ Badge count increment होईल
- ✅ Sound वाजेल

### Console Logs:
```
📱 [NotificationDelegate] willPresent notification
📱 [NotificationDelegate] Chat notification in foreground - showing banner
```

---

## Test Case 8: Clear All Notifications

### Steps:
1. Badge count = 5
2. Notification Center उघडा
3. **"Clear All"** button दाबा

### Expected Result:
- ✅ Badge count **0** होईल
- ✅ सर्व notifications cleared

### Console Logs:
```
📱 [BadgeManager] All notifications dismissed
📱 [BadgeManager] Badge cleared
```

---

## Test Case 9: Firebase Sync Check

### Steps:
1. App open करा
2. Chat with 3 unread open करा
3. Firebase Console उघडा
4. Check: `users/{your_uid}/Contacts/{friend_uid}/notification`

### Expected Result:
- ✅ Firebase मध्ये **notification = 0** दिसेल
- ✅ Before opening: notification = 3
- ✅ After opening: notification = 0

---

## Test Case 10: Multiple Devices (Optional)

### Setup:
- Device A: Your phone
- Device B: Simulator/Another phone

### Steps:
1. Both devices मध्ये login करा
2. Device A वरून message पाठवा
3. Device B वर notification येईल
4. Device B वर chat open करा

### Expected Result:
- ✅ Device B badge clear होईल
- ✅ Firebase sync होईल
- ✅ Device A वर पण update होईल (if listener active)

---

## Debugging Tips

### Badge Not Showing?

**Check:**
```swift
// Permission granted?
UNUserNotificationCenter.current().getNotificationSettings { settings in
    print("Authorization: \(settings.authorizationStatus)")
    // Should be .authorized
}

// Badge capability enabled?
print("Badge setting: \(settings.badgeSetting)")
// Should be .enabled
```

### Badge Wrong Count?

**Fix:**
```swift
// Recalculate from Firebase
BadgeManager.shared.recalculateBadgeFromFirebase(currentUserUid: Constant.SenderIdMy)

// Or sync with delivered notifications
BadgeManager.shared.syncBadgeWithNotificationCenter()
```

### Notification Not Incrementing?

**Check Logs:**
```
🔔 [NotificationService] didReceive invoked ← Extension running?
📱 [NotificationService] Badge updated: X -> Y ← Badge set?
```

**Backend Payload:**
```json
{
  "apns": {
    "payload": {
      "aps": {
        "mutable-content": 1,  ← MUST be 1
        "alert": { ... },
        "badge": 1  ← NOT needed, extension handles it
      }
    }
  }
}
```

---

## Expected Console Output (Sample)

### When Notification Arrives:
```
🔔 [NotificationService] didReceive invoked
🔔 [NotificationService] APS present: alert=true mutable-content=1
🔔 [NotificationService] bodyKey: chatting
🔔 [NotificationService] Preparing Communication Notification:
   - senderName: Ram
   - senderUid: abc123
   - message: Hello
   - photoUrl: https://...
📱 [NotificationService] Badge updated: 3 -> 4
✅ [NotificationService] Updated notification with INSendMessageIntent
```

### When User Opens Chat:
```
✅ [MainActivityOld] selectedChatForNavigation changed - navigating to ChattingScreen
📱 [MainActivityOld] Contact: Ram (abc123)
📱 [MainActivityOld] Clearing notification count: 3 for user: abc123
📱 [BadgeManager] Clearing notification count for user abc123
📱 [BadgeManager] Firebase path: users/xyz789/Contacts/abc123/notification
✅ [BadgeManager] Notification count cleared in Firebase
📱 [BadgeManager] Badge decremented by 3: 5 -> 2
```

### When App Becomes Active:
```
📤 [EnclosureApp] App became ACTIVE
📱 [BadgeManager] Syncing badge with delivered notifications: 2
📱 [chatView] Badge recalculated from 8 chats
```

---

## Success Criteria

### All Tests Pass If:
- ✅ Badge increments on each notification
- ✅ Badge decrements on dismiss
- ✅ Badge clears when opening chat
- ✅ Firebase notification counts sync
- ✅ Multiple chats handle correctly
- ✅ App reopen preserves badge
- ✅ Console logs show correct flow

---

## Common Issues & Solutions

### Issue 1: Badge Shows Wrong Number
**Solution:** Kill app, reopen. Badge will recalculate from Firebase.

### Issue 2: Badge Not Clearing After Opening Chat
**Solution:** Check Firebase connection. Verify `Constant.SenderIdMy` is set.

### Issue 3: Multiple Badges Adding Up Wrong
**Solution:** Check if chat list has duplicate entries.

### Issue 4: Badge Showing After Reading All
**Solution:** Pull to refresh chat list. Badge will recalculate.

---

## मस्त! Testing पूर्ण झाल्यावर सर्व काही बरोबर काम करेल! 🎉
