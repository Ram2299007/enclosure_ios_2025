# iOS chat notification – WhatsApp-like (Service Extension)

## What happens

- **Service Extension approach**: backend sends APNs **alert** + **mutable-content** → iOS shows banner even when app is closed → Notification Service Extension downloads **photo** and attaches it.
- App still receives **reply** actions via category (`CHAT_MESSAGE`).

## Important: which endpoint is used for iOS?

The **iOS app** calls only:

- `EmojiController/send_notification_api`

So when a chat is sent **to an iOS user**, the backend always uses **send_notification_api**, not send_notification_ios.

For the **receiver** to see the proper chat notification (banner + reply + image), **send_notification_api** must send the **same payload as send_notification_ios** when the receiver is iOS:

- APNs **alert** (`aps.alert`) so the system shows the banner.
- `mutable-content: 1` so the Notification Service Extension can attach the **photo**.
- `category: "CHAT_MESSAGE"` so inline reply appears.

## What to do on your production backend

1. In **send_notification_api**, when `receiverDeviceType === '2'` (iOS):
   - Send APNs **alert** + **mutable-content** + **category**.
   - Keep full `data` payload for the app (reply, open chat, etc.).
2. Use **backend_example/send_notification_ios.php** and **backend_example/send_notification_api.php** as references.
3. Ensure the **Notification Service Extension** is added to the iOS app target (see `EnclosureNotificationService/`).

## Summary

| Backend sends                               | Banner shows? | Image shows? |
|---------------------------------------------|--------------|--------------|
| APNs alert + mutable-content (service ext)   | Yes          | Yes          |
| Data-only (no alert)                         | App must add local notification | No image |

For WhatsApp-like notifications with profile image, use **Service Extension** + **APNs alert**.
