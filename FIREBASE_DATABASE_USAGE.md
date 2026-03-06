# Firebase Realtime Database Usage Guide

This guide shows you how to use Firebase Realtime Database in your Enclosure app.

## Setup Complete ✅

- ✅ FirebaseDatabase package added
- ✅ FirebaseDatabaseManager service created
- ✅ Database initialized in FirebaseManager

## Database URL

Your database URL: `https://enclosure-30573-default-rtdb.firebaseio.com`

## Basic Usage Examples

### 1. Write Data

```swift
// Write data to a path
FirebaseDatabaseManager.shared.write(
    path: "users/\(userId)/name",
    data: ["name": "John Doe"]
) { error in
    if let error = error {
        print("❌ Error: \(error.localizedDescription)")
    } else {
        print("✅ Data written successfully")
    }
}
```

### 2. Read Data Once

```swift
// Read data from a path
FirebaseDatabaseManager.shared.readOnce(path: "users/\(userId)") { snapshot in
    if let data = snapshot?.value as? [String: Any] {
        print("User data: \(data)")
    }
}
```

### 3. Observe Real-time Changes

```swift
// Observe changes at a path
var handle: DatabaseHandle?

handle = FirebaseDatabaseManager.shared.observe(path: "users/\(userId)") { snapshot in
    if let data = snapshot?.value as? [String: Any] {
        print("Data updated: \(data)")
    }
}

// Don't forget to remove observer when done
// FirebaseDatabaseManager.shared.removeObserver(handle: handle!, path: "users/\(userId)")
```

### 4. Push Data (Auto-generated Key)

```swift
// Push data with auto-generated key
FirebaseDatabaseManager.shared.push(
    path: "messages",
    data: [
        "text": "Hello!",
        "senderId": userId,
        "timestamp": ServerValue.timestamp()
    ]
) { messageId, error in
    if let error = error {
        print("❌ Error: \(error.localizedDescription)")
    } else if let messageId = messageId {
        print("✅ Message ID: \(messageId)")
    }
}
```

### 5. Update Data

```swift
// Update existing data
FirebaseDatabaseManager.shared.update(
    path: "users/\(userId)",
    data: ["lastSeen": ServerValue.timestamp()]
) { error in
    if let error = error {
        print("❌ Error: \(error.localizedDescription)")
    } else {
        print("✅ Updated successfully")
    }
}
```

### 6. Delete Data

```swift
// Delete data
FirebaseDatabaseManager.shared.delete(path: "users/\(userId)/tempData") { error in
    if let error = error {
        print("❌ Error: \(error.localizedDescription)")
    } else {
        print("✅ Deleted successfully")
    }
}
```

## Chat-Specific Methods

### Send a Message

```swift
FirebaseDatabaseManager.shared.sendMessage(
    senderId: Constant.SenderIdMy,
    receiverId: contactId,
    message: "Hello, how are you?",
    dataType: "Text"
) { messageId, error in
    if let error = error {
        print("❌ Error sending message: \(error.localizedDescription)")
    } else if let messageId = messageId {
        print("✅ Message sent with ID: \(messageId)")
    }
}
```

### Load Messages

```swift
FirebaseDatabaseManager.shared.loadMessages(
    userId: Constant.SenderIdMy,
    contactId: contactId,
    limit: 50
) { messages, error in
    if let error = error {
        print("❌ Error loading messages: \(error.localizedDescription)")
    } else if let messages = messages {
        // Process messages
        print("✅ Loaded \(messages.count) messages")
    }
}
```

### Observe New Messages (Real-time)

```swift
var messageHandle: DatabaseHandle?

messageHandle = FirebaseDatabaseManager.shared.observeMessages(
    userId: Constant.SenderIdMy,
    contactId: contactId
) { message in
    // Handle new message
    print("New message: \(message)")
}

// Remove observer when leaving chat
// FirebaseDatabaseManager.shared.removeObserver(handle: messageHandle!, path: "messages/\(userId)/\(contactId)")
```

### Update User Status

```swift
// Set user online
FirebaseDatabaseManager.shared.updateUserStatus(
    userId: Constant.SenderIdMy,
    isOnline: true
)

// Set user offline
FirebaseDatabaseManager.shared.updateUserStatus(
    userId: Constant.SenderIdMy,
    isOnline: false
)
```

## Integration with ChattingScreen

Here's how you can integrate with your existing `ChattingScreen.swift`:

```swift
// In ChattingScreen.swift

@State private var messageHandle: DatabaseHandle?

// Load messages on appear
.onAppear {
    loadMessages()
    observeNewMessages()
}

// Remove observer on disappear
.onDisappear {
    if let handle = messageHandle {
        let userId = Constant.SenderIdMy
        FirebaseDatabaseManager.shared.removeObserver(
            handle: handle,
            path: "messages/\(userId)/\(contact.uid)"
        )
    }
}

// Update loadMessages function
private func loadMessages() {
    FirebaseDatabaseManager.shared.loadMessages(
        userId: Constant.SenderIdMy,
        contactId: contact.uid,
        limit: 50
    ) { messages, error in
        if let messages = messages {
            DispatchQueue.main.async {
                self.messages = messages.compactMap { messageData in
                    // Convert dictionary to ChatMessage
                    // Implementation depends on your ChatMessage structure
                }
            }
        }
    }
}

// Update sendMessage function
private func sendMessage() {
    guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    
    FirebaseDatabaseManager.shared.sendMessage(
        senderId: Constant.SenderIdMy,
        receiverId: contact.uid,
        message: messageText,
        dataType: "Text"
    ) { messageId, error in
        if let error = error {
            print("❌ Error: \(error.localizedDescription)")
        } else {
            DispatchQueue.main.async {
                self.messageText = ""
            }
        }
    }
}

// Observe new messages
private func observeNewMessages() {
    messageHandle = FirebaseDatabaseManager.shared.observeMessages(
        userId: Constant.SenderIdMy,
        contactId: contact.uid
    ) { message in
        // Handle new message
        DispatchQueue.main.async {
            // Add message to messages array
        }
    }
}
```

## Database Structure Example

```
enclosure-30573-default-rtdb
├── messages/
│   ├── {userId1}/
│   │   ├── {userId2}/
│   │   │   ├── {messageId1}/
│   │   │   │   ├── id: "messageId1"
│   │   │   │   ├── senderId: "userId1"
│   │   │   │   ├── receiverId: "userId2"
│   │   │   │   ├── text: "Hello!"
│   │   │   │   ├── timestamp: 1234567890
│   │   │   │   └── dataType: "Text"
│   │   │   └── {messageId2}/...
│   │   └── {userId3}/...
│   └── {userId2}/...
├── conversations/
│   ├── {userId1}/
│   │   └── {userId2}/
│   │       └── {messageId}/...
└── users/
    ├── {userId}/
    │   ├── status/
    │   │   ├── isOnline: true/false
    │   │   └── lastSeen: timestamp
    │   └── profile/...
```

## Security Rules

Make sure to set up Firebase Realtime Database security rules in Firebase Console:

```json
{
  "rules": {
    "messages": {
      "$userId": {
        ".read": "$userId === auth.uid",
        ".write": "$userId === auth.uid"
      }
    },
    "users": {
      "$userId": {
        ".read": true,
        ".write": "$userId === auth.uid"
      }
    }
  }
}
```

## Tips

1. **Always remove observers** when you're done to prevent memory leaks
2. **Use ServerValue.timestamp()** for timestamps to ensure consistency
3. **Handle errors** in all completion handlers
4. **Test offline behavior** - Firebase can work offline with persistence enabled
5. **Monitor database usage** in Firebase Console to avoid unexpected costs

## Next Steps

1. Enable Firebase Authentication if you need user authentication
2. Set up security rules in Firebase Console
3. Test the database connection
4. Integrate with your existing chat functionality

