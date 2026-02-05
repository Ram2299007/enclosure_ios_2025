# Notification Count Display Debug Guide

## Problem
Notification counts not showing in chatView when new messages arrive.

---

## Debug Steps

### Step 1: Check Console Logs When Message Arrives

When a new message arrives, you should see these logs:

```
🔵 [chatView] Live update received: {message_data}
🔵 [chatView] Refreshing chat list due to socket update
🔵 [ChatViewModel] API callback received - success: true, data count: X
🔵 [ChatViewModel] ===== NOTIFICATION COUNTS =====
🔵 [ChatViewModel] Chat #1 - Ram Lohar: notification = 3
🔵 [ChatViewModel] Total unread messages: 5
🔵 [ChatViewModel] ===== END NOTIFICATION COUNTS =====
📱 [chatView] Chat list changed - count: X
📱 [chatView] Total notifications: 5
📱 [chatView] Chats with unread: 2
📱 [chatView]   - Ram Lohar: 3 unread
📱 [chatView]   - Sita: 2 unread
```

### Step 2: Verify API Response

**Check backend API response:**

```json
{
  "success": true,
  "message": "Data found",
  "data": [
    {
      "uid": "user123",
      "full_name": "Ram Lohar",
      "notification": 3,  // ← This field must be present and > 0
      "message": "Hello",
      ...
    }
  ]
}
```

**Important:** The `notification` field must be:
- Present in API response
- Integer type (not string)
- Value > 0 for unread messages

### Step 3: Check Model Decoding

**File:** `Enclosure/Model/UserActiveContactModel.swift`

```swift
let notification: Int  // Must be Int, not String

// Decoding
notification = (try? container.decode(Int.self, forKey: .notification)) ?? 0
```

✅ Verify: Notification field is decoded as Int, defaults to 0 if missing

### Step 4: Check UI Display Logic

**File:** `Enclosure/Child Views/chatView.swift`

```swift
// Notification badge should show when count > 0
if chat.notification > 0 {
    NotificationBadge(count: chat.notification)
}
```

✅ Verify: Badge displays when `chat.notification > 0`

---

## Common Issues & Solutions

### Issue 1: API Not Returning Notification Count

**Symptom:**
```
🔵 [ChatViewModel] Total unread messages: 0
// Even though you just received a message
```

**Solution:**
- Check backend API (get_user_active_chat_list)
- Ensure it returns `notification` field for each contact
- Ensure notification count increments when message arrives

**Backend Fix:**
```sql
-- Update notification count when new message arrives
UPDATE contacts 
SET notification = notification + 1 
WHERE uid = 'receiver_uid' AND friend_uid = 'sender_uid'
```

### Issue 2: Notification Field is String Instead of Int

**Symptom:**
```
🔵 [ChatViewModel] Chat #1 - Ram: notification = 0
// But API returns "3" as string
```

**Solution:**
Check API response type. If it's a string, update model:

```swift
// In UserActiveContactModel.swift
if let notificationInt = try? container.decode(Int.self, forKey: .notification) {
    notification = notificationInt
} else if let notificationString = try? container.decode(String.self, forKey: .notification) {
    notification = Int(notificationString) ?? 0
} else {
    notification = 0
}
```

### Issue 3: Firebase Listener Not Triggering

**Symptom:**
```
// No logs after sending message
// No "Live update received" log
```

**Solution:**
1. Check Firebase path: `chattingSocket/{your_uid}`
2. Verify backend writes to this path when message is sent
3. Test Firebase listener:

```swift
// In chatView
print("🔵 Firebase listener path: chattingSocket/\(Constant.SenderIdMy)")

// Backend should write to this path:
firebase.child("chattingSocket/{receiver_uid}").setValue("new_message")
```

### Issue 4: UI Not Refreshing

**Symptom:**
```
📱 [chatView] Total notifications: 5
// But UI still shows 0
```

**Solution:**
1. Check if `viewModel.chatList` is `@Published`
2. Verify SwiftUI view observes ViewModel changes
3. Force UI refresh:

```swift
// Already implemented in fix:
@State private var lastUpdateTimestamp: Date = Date()

.onChange(of: viewModel.chatList) { _ in
    lastUpdateTimestamp = Date() // Force refresh
}
```

### Issue 5: Badge Shows But Count is Wrong

**Symptom:**
- Badge shows but displays "0" or wrong number

**Solution:**
Check badge component:

```swift
// In NotificationBadge component
Text("\(count)")  // ← Verify count parameter is passed correctly
```

---

## Testing Scenarios

### Test 1: Single New Message

**Steps:**
1. Open app, go to chatView
2. Send message from another device/user
3. Wait 2 seconds

**Expected Logs:**
```
🔵 [chatView] Live update received: ...
🔵 [ChatViewModel] Chat #1 - {sender}: notification = 1
📱 [chatView] Total notifications: 1
```

**Expected UI:**
- Chat item shows badge with "1"
- Time color changes to theme color
- Caption text is darker (bold)

### Test 2: Multiple Messages Same Chat

**Steps:**
1. Send 3 messages from same user
2. Check chatView

**Expected:**
- Badge shows "3"
- API returns notification = 3

### Test 3: Messages From Different Chats

**Steps:**
1. User A sends 2 messages
2. User B sends 1 message

**Expected:**
- User A chat: badge shows "2"
- User B chat: badge shows "1"  
- Total badge on app icon: 3

---

## Backend Requirements

### get_user_active_chat_list API

**Must Return:**
```json
{
  "data": [
    {
      "uid": "user123",
      "notification": 3,  // ← Required, must be Int
      "full_name": "Ram",
      "message": "Last message",
      "sent_time": "10:30 AM",
      ...
    }
  ]
}
```

### When Message is Sent

Backend must:
1. Increment notification count in database
2. Update chattingSocket/{receiver_uid} in Firebase
3. Send push notification

**Example:**
```php
// When message sent
$sql = "UPDATE contacts 
        SET notification = notification + 1 
        WHERE receiver_uid = ? AND sender_uid = ?";

// Trigger Firebase listener
$firebase->getReference("chattingSocket/{$receiver_uid}")
         ->set("new_message_" . time());
```

---

## Quick Fix Checklist

When notification counts don't show:

- [ ] Check console logs (ViewModel + chatView)
- [ ] Verify API returns `notification` field
- [ ] Confirm `notification` is Int, not String
- [ ] Check Firebase listener is working
- [ ] Verify UI updates when chatList changes
- [ ] Test with real message from another device
- [ ] Check backend increments notification count
- [ ] Verify Firebase chattingSocket updates

---

## Expected Flow

```
1. User B sends message to User A
   ↓
2. Backend increments notification count:
   UPDATE contacts SET notification = notification + 1
   ↓
3. Backend updates Firebase:
   chattingSocket/userA_uid = "new_message"
   ↓
4. App A Firebase listener triggers:
   🔵 [chatView] Live update received
   ↓
5. App A fetches fresh chat list:
   🔵 [ChatViewModel] API callback received
   ↓
6. API returns updated notification counts:
   🔵 [ChatViewModel] Chat #1 - User B: notification = 1
   ↓
7. chatView updates:
   📱 [chatView] Total notifications: 1
   ↓
8. UI shows badge:
   ✅ Badge "1" visible on User B's chat
```

---

## Debug Commands

### Console Filtering

**Xcode Console:**
```
# Filter for notification logs
notification

# Filter for chatView logs
[chatView]

# Filter for API response
[ChatViewModel] SUCCESS
```

**Mac Console.app:**
```
# Process: Enclosure
# Filter: notification
```

### Print All Notification Counts

Add this to chatView for debugging:

```swift
.onAppear {
    // Debug all notification counts
    Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
        print("📱 [DEBUG] Current notification counts:")
        for chat in viewModel.chatList {
            if chat.notification > 0 {
                print("📱 [DEBUG]   \(chat.fullName): \(chat.notification)")
            }
        }
    }
}
```

---

## मराठीत Summary

### समस्या:
chatView मध्ये notification count नाही दिसत

### तपासायचे:
1. ✅ Console logs पहा
2. ✅ API response मध्ये `notification` field आहे का
3. ✅ Firebase listener काम करतो का
4. ✅ UI update होतो का

### Fix:
1. Backend API notification count return करतो याची खात्री करा
2. Firebase listener trigger होतो याची खात्री करा  
3. Console logs पाहून verify करा
4. UI मध्ये badge दिसतो याची खात्री करा

**तुमच्या app मध्ये आता debug logs आहेत - test करून logs share करा!** 🔍
