# All notification files for chatting

Paths and roles for every file involved in **chat push notifications** (receiving, showing, reply, and backend).

---

## iOS app – receiving and showing chat notifications

| File | Role |
|------|------|
| **Enclosure/Utility/FirebaseManager.swift** | Receives FCM payload, shows local chat notification (title/body, CHAT_MESSAGE category, Reply action), handles notification reply and tap; `handleRemoteNotification`, `handleChatNotification`, `handleNotificationReply`, `registerChatNotificationCategory`. |
| **Enclosure/EnclosureApp.swift** | `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` – receives FCM and forwards to `FirebaseManager.handleRemoteNotification`. |
| **Enclosure/Screens/MainActivityOld.swift** | Listens for `OpenChatFromNotification` and navigates to chat when user taps the notification (opens ChattingScreen with `friendUidKey`). |
| **Enclosure/Constant.swift** | `Constant.chatting` (`"chatting"`) and `Constant.FCM_TOKEN` used for chat notification flow. |

---

## iOS app – sending the “notify receiver” request

| File | Role |
|------|------|
| **Enclosure/Utility/MessageUploadService.swift** | After sending a chat message, calls backend `send_notification_api` so the **receiver** gets a push (builds JSON with title, body, deviceToken, receiverDeviceType, all Power keys, etc.). |

---

## Backend – FCM payload for chat (iOS receiver)

| File | Role |
|------|------|
| **backend_example/send_notification_ios.php** | Data-only FCM for iOS chat; **no** `"notification"` block so the app receives payload and shows the banner. Use this payload shape when receiver is iOS. |
| **backend_example/send_notification_api.php** | Main API called by the app (`EmojiController/send_notification_api`). For iOS receiver (`receiverDeviceType === '2'`) must send **same payload as send_notification_ios** (data-only). |
| **backend_example/send_notification_ios_DATA_ONLY.php** | Backup/reference copy of the data-only iOS chat payload. |
| **backend_example/IOS_CHAT_NOTIFICATION_README.md** | Explains why data-only is required for iOS and how `send_notification_api` must match `send_notification_ios` for iOS receivers. |

---

## Supporting (not notification-specific)

| File | Role |
|------|------|
| **Enclosure/Utility/ChatCacheManager.swift** | Caches FCM token and device_type for contacts so `MessageUploadService` can call `send_notification_api` with correct receiver token/device. |
| **Enclosure/Info.plist** | `UIBackgroundModes` → `remote-notification` so the app is woken for data-only FCM. |

---

## Quick path list (copy-paste)

```
Enclosure/Utility/FirebaseManager.swift
Enclosure/EnclosureApp.swift
Enclosure/Screens/MainActivityOld.swift
Enclosure/Utility/MessageUploadService.swift
Enclosure/Constant.swift
backend_example/send_notification_ios.php
backend_example/send_notification_api.php
backend_example/send_notification_ios_DATA_ONLY.php
backend_example/IOS_CHAT_NOTIFICATION_README.md
Enclosure/Utility/ChatCacheManager.swift
Enclosure/Info.plist
```
