# Fix: Content Extension Still Showing (Profile on RIGHT, App Icon on LEFT)

## Problem

You're still seeing:
- ❌ Profile picture on RIGHT side
- ❌ App icon on LEFT side

This means the **Content Extension is still active** and overriding Communication Notifications.

## Root Cause

The Content Extension (`EnclosureNotificationContentExtension`) is registered for the `CHAT_MESSAGE` category. When iOS sees a notification with `categoryIdentifier = "CHAT_MESSAGE"`, it uses the Content Extension instead of native Communication Notifications UI.

## Solution: Disable Content Extension for Chat Notifications

### Option 1: Remove Content Extension Category (Recommended)

1. **Open** `EnclosureNotificationContentExtension/Info.plist`
2. **Remove** the `CHAT_MESSAGE` category from `UNNotificationExtensionCategory`:
   ```xml
   <key>UNNotificationExtensionCategory</key>
   <array>
       <!-- Empty - Content Extension disabled for chat notifications -->
   </array>
   ```
3. **Rebuild** the app
4. **Test** - notifications should now use native iOS UI

### Option 2: Delete Content Extension Target (Best Solution)

Since Communication Notifications use native iOS UI, the Content Extension is not needed:

1. **In Xcode**:
   - Select `EnclosureNotificationContentExtension` target
   - Right-click → Delete → Move to Trash
   
2. **Delete the folder**:
   - Delete `EnclosureNotificationContentExtension/` folder from project

3. **Rebuild** the app

### Option 3: Use Different Category for Communication Notifications

If you want to keep Content Extension for other notification types:

1. **Update** `CommunicationNotificationManager.swift`:
   ```swift
   // Use a different category that doesn't trigger Content Extension
   content.categoryIdentifier = "COMMUNICATION_MESSAGE"
   ```

2. **Update** `FirebaseManager.swift` to register the new category:
   ```swift
   let chatCategory = UNNotificationCategory(
       identifier: "COMMUNICATION_MESSAGE",
       actions: [replyAction],
       intentIdentifiers: ["INSendMessageIntent"], // Important!
       options: []
   )
   ```

3. **Keep** `CHAT_MESSAGE` in Content Extension for other notification types

## Important: Communication Notifications Limitation

**Communication Notifications work best with remote push notifications** that go through the Notification Service Extension. For local notifications created in-app, iOS may not always show the Communication Notifications UI.

### For Best Results:

1. **Send remote push notifications** with `mutable-content: 1` in APS payload
2. **Let Notification Service Extension** process the notification and update it with `INSendMessageIntent`
3. **iOS will then show** WhatsApp-like UI with profile picture on LEFT

### Current Implementation (Local Notifications):

Since you're using data-only FCM and creating local notifications:
- The Notification Service Extension is **not called**
- Communication Notifications may not work perfectly
- You might need to send notifications with APS alert + mutable-content

## Testing Steps

1. **Remove Content Extension category** (Option 1 above)
2. **Rebuild and run** the app
3. **Send a test notification**
4. **Check**:
   - ✅ Profile picture should be on LEFT (or not shown if Communication Notifications don't work)
   - ✅ App icon should be secondary
   - ❌ Content Extension UI should NOT appear

## If Still Not Working

If you still see Content Extension UI after removing the category:

1. **Check** if Content Extension target is still in project
2. **Verify** `Info.plist` changes were saved
3. **Clean build folder**: Product → Clean Build Folder
4. **Delete app** from device and reinstall
5. **Check logs** for `[NotificationService]` or `[COMM_NOTIFICATION]` messages

## Alternative: Use Remote Push with Mutable Content

For true Communication Notifications, update your backend to send:

```json
{
  "aps": {
    "alert": {
      "title": "Sender Name",
      "body": "Message text"
    },
    "mutable-content": 1,
    "category": "CHAT_MESSAGE"
  },
  "bodyKey": "chatting",
  "friendUidKey": "sender123",
  "photo": "https://example.com/profile.jpg",
  "msgKey": "Message text"
}
```

Then the Notification Service Extension will be called and can process the Communication Notification properly.
