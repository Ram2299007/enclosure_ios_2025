# WhatsApp-like iOS Communication Notifications Setup Guide

## Overview

This guide explains how to implement **exact WhatsApp-like iOS notifications** using iOS Communication Notifications API with `INSendMessageIntent` and `INPerson`. This provides native iOS notification UI with circular profile pictures on the LEFT, matching WhatsApp's design.

## Why Content Extension Must NOT Be Used

### Problems with UNNotificationContentExtension:

1. **Custom UI Limitations**: Content Extensions create custom UI that doesn't match iOS native design
2. **Layout Issues**: Profile picture appears on RIGHT, not LEFT like WhatsApp
3. **App Icon Dominance**: App icon is shown prominently, not secondary
4. **Performance**: Custom UI rendering can cause delays and inconsistencies
5. **System Integration**: Doesn't integrate with iOS Communication Notifications features

### Benefits of Communication Notifications:

1. **Native iOS Design**: Uses iOS system UI that matches WhatsApp/iMessage exactly
2. **Circular Profile Picture on LEFT**: Automatically positioned correctly
3. **App Icon Secondary**: System handles app icon placement (small badge)
4. **Threading**: Automatic message grouping using `conversationIdentifier`
5. **Inline Reply**: Native inline reply support
6. **Siri Integration**: Intent donation enables Siri suggestions
7. **Performance**: System-optimized rendering

## Architecture

```
FCM Data-Only Payload
    ↓
AppDelegate.didReceiveRemoteNotification
    ↓
FirebaseManager.handleRemoteNotification
    ↓
CommunicationNotificationManager.createNotificationFromPayload
    ↓
ProfilePictureCacheManager.getCachedProfileImage (loads from local cache)
    ↓
INSendMessageIntent + INPerson (with cached image)
    ↓
UNNotificationRequest (with intent)
    ↓
iOS System (shows WhatsApp-like notification)
```

## Step-by-Step Implementation

### Step 1: Add Intents Framework

1. Open your Xcode project
2. Select your **main app target** (Enclosure)
3. Go to **Signing & Capabilities**
4. Click **+ Capability**
5. Add **Intents** capability
6. Enable **Intents** in the list

**Note**: The Intents framework is required for `INSendMessageIntent` and `INPerson`.

### Step 2: Update Info.plist

Add Intents usage description (required for iOS 15+):

```xml
<key>NSUserNotificationsUsageDescription</key>
<string>Enclosure needs notification permissions to show messages</string>
```

### Step 3: Remove Content Extension (Optional but Recommended)

Since Communication Notifications use native iOS UI, the Content Extension is no longer needed:

1. **Remove Content Extension Target**:
   - In Xcode, select `EnclosureNotificationContentExtension` target
   - Right-click → Delete → Move to Trash

2. **Remove from Project**:
   - Delete `EnclosureNotificationContentExtension/` folder
   - Remove from Xcode project navigator

3. **Update Info.plist** (if keeping for other notification types):
   - Remove `UNNotificationExtensionCategory` entry for `CHAT_MESSAGE`
   - Or keep it but don't use it for chat notifications

### Step 4: Code Implementation

The following files have been created/updated:

#### ✅ Created Files:

1. **`CommunicationNotificationManager.swift`**
   - Creates `INSendMessageIntent` with `INPerson`
   - Handles Communication Notifications API
   - Loads profile images from local cache

2. **`ProfilePictureCacheManager.swift`**
   - Downloads and caches profile pictures locally
   - Provides cached image paths for `INPerson`
   - Pre-caches images when users open chats

#### ✅ Updated Files:

1. **`FirebaseManager.swift`**
   - Updated `handleChatNotification()` to use Communication Notifications
   - Falls back to standard notifications for iOS < 15

2. **`NotificationService.swift`**
   - Updated to cache images for Communication Notifications
   - Maintains backward compatibility

### Step 5: Profile Picture Caching Strategy

#### Background Caching (Silent Push):

When a user opens a chat, pre-cache their profile picture:

```swift
// In ChattingScreen or similar
ProfilePictureCacheManager.shared.preCacheProfileImage(
    photoUrl: contactProfileUrl,
    senderUid: contactUid
)
```

#### Notification-Time Caching:

When a notification arrives:
1. Check local cache first (fast)
2. If not cached, show notification without image (don't block)
3. Download image in background for next notification

This ensures notifications appear immediately without waiting for image downloads.

## How It Works

### 1. Creating INPerson with Image

```swift
// Load image from local cache
let imagePath = ProfilePictureCacheManager.shared.getCachedProfileImage(...)
let image = UIImage(contentsOfFile: imagePath)
let inImage = INImage(uiImage: image)

// Create INPerson
let person = INPerson(
    personHandle: INPersonHandle(value: senderUid, type: .unknown),
    nameComponents: nil,
    displayName: senderName,
    image: inImage,  // Circular profile picture
    contactIdentifier: nil,
    customIdentifier: senderUid
)
```

### 2. Creating INSendMessageIntent

```swift
let intent = INSendMessageIntent()
intent.recipients = [person]  // Sender as recipient (iOS shows their image)
intent.content = message
intent.speakableGroupName = INSpeakableString(spokenPhrase: senderName)
```

### 3. Building UNNotificationRequest

```swift
let content = UNMutableNotificationContent()
content.title = senderName
content.body = message
content.threadIdentifier = senderUid  // Groups messages from same sender
content.categoryIdentifier = "CHAT_MESSAGE"  // For inline reply

let request = UNNotificationRequest(
    identifier: identifier,
    content: content,
    trigger: nil
)
```

### 4. Intent Donation (Optional)

```swift
let interaction = INInteraction(intent: intent, response: nil)
interaction.donate { error in
    // Helps iOS learn communication patterns for Siri
}
```

## Key Features

### ✅ Circular Profile Picture on LEFT
- iOS automatically positions profile picture on the LEFT
- Uses circular mask matching WhatsApp design

### ✅ App Icon Secondary
- System shows app icon as small badge (not dominant)
- Profile picture is the primary visual element

### ✅ Message Grouping
- Uses `threadIdentifier` (sender UID) to group messages
- Multiple messages from same sender appear grouped in notification center

### ✅ Inline Reply Support
- Native inline reply action (already configured in `CHAT_MESSAGE` category)
- Reply text input works automatically

### ✅ Local Image Cache
- Profile pictures loaded from local file cache (not remote URLs)
- Fast notification display without network delays

## Testing

### Test Scenarios:

1. **Single Message**:
   - Send one message → Notification shows with profile picture on LEFT

2. **Multiple Messages**:
   - Send multiple messages from same sender → Messages grouped together

3. **Profile Picture**:
   - Verify circular profile picture appears on LEFT
   - Verify app icon is secondary (small badge)

4. **Inline Reply**:
   - Long-press notification → Reply action appears
   - Type reply → Message sent successfully

5. **Cache Behavior**:
   - First notification: May show without image (if not cached)
   - Subsequent notifications: Show with cached image

## Troubleshooting

### Profile Picture Not Showing:

1. **Check Cache**: Verify image is cached in `ProfilePictures/` directory
2. **Check File Path**: Ensure `profileImagePath` is valid file path
3. **Check Permissions**: Ensure app has file access permissions
4. **Check Image Format**: Ensure image is valid JPEG/PNG

### Notification Not Appearing:

1. **Check iOS Version**: Communication Notifications require iOS 15+
2. **Check Permissions**: Verify notification permissions granted
3. **Check FCM Payload**: Ensure `bodyKey == "chatting"` in payload
4. **Check Logs**: Look for `[COMM_NOTIFICATION]` logs

### Intent Donation Errors:

- Intent donation failures are non-critical (notifications still work)
- Check logs for `[COMM_NOTIFICATION] Intent donation failed`

## Migration from Content Extension

If you're migrating from Content Extension:

1. **Remove Content Extension target** (as described above)
2. **Update notification creation** to use `CommunicationNotificationManager`
3. **Test thoroughly** to ensure notifications appear correctly
4. **Monitor logs** for any issues

## iOS Version Support

- **iOS 15+**: Full Communication Notifications support
- **iOS < 15**: Falls back to standard notifications (without profile picture on LEFT)

## Summary

✅ **Use**: `INSendMessageIntent` + `INPerson` for WhatsApp-like notifications  
❌ **Don't Use**: `UNNotificationContentExtension` (doesn't match WhatsApp design)  
✅ **Cache**: Profile pictures locally for fast access  
✅ **Group**: Use `threadIdentifier` for message grouping  
✅ **Reply**: Native inline reply support  

This implementation provides **exact WhatsApp-like iOS notification behavior** with minimal code and maximum system integration.
