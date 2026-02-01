# Backend: send_notification_api

Use this in your PHP backend (e.g. inside `EmojiController` or equivalent).

## Files

- **`send_notification_api.php`** – Full `send_notification_api()` for FCM push (Android + iOS). When `receiverDeviceType` is empty, it calls `getUserDeviceTypeByUid($receiverUid)` to get the receiver’s device type from the DB.
- **`device_type_storage_and_lookup.php`** – Helper `getUserDeviceTypeByUid()` plus examples for storing `device_type` at login and in `update_profile`.

## What to do

### 1. Database

- Add a **`device_type`** column to your **users** table (VARCHAR, e.g. `"1"` = Android, `"2"` = iOS) if it doesn’t exist.

### 2. Store device_type at login and profile update

- In **verify_mobile_otp**: when the app sends `deviceType` (or `device_type`), after successful OTP verification update the user row:  
  `UPDATE users SET device_type = ?, f_token = ? WHERE uid = ?`
- In **update_profile**: when the app sends `deviceType` / `device_type`, update the user row the same way.
- See **`device_type_storage_and_lookup.php`** for copy-paste snippets (verify_mobile_otp and update_profile).

### 3. Add the helper and send_notification_api

- Copy **`getUserDeviceTypeByUid()`** from `device_type_storage_and_lookup.php` into the same controller that has `send_notification_api()` (e.g. `EmojiController`). Use one of the DB options (PDO, CodeIgniter, or Laravel) and adapt table/column names.
- Copy the full **`send_notification_api()`** from `send_notification_api.php` into that controller (replace your existing method). No need to change the call to `getUserDeviceTypeByUid($receiverUid)`.

### 4. FCM project ID

- If your project is not `enclosure-30573`, change the FCM URL in `send_notification_api()` to your Firebase project ID.

## Request (Android & iOS)

- **Method:** POST  
- **URL:** `https://your-domain.com/EmojiController/send_notification_api`  
- **Content-Type:** `application/json`

**Required:**

- `deviceToken` – Receiver’s FCM token (target device).
- `accessToken` – Google OAuth2 access token for FCM (Bearer).

**Important for iOS:**

- `receiverDeviceType` – `"2"` = receiver is iOS, `"1"` = Android.  
  If present, backend uses it to add FCM `notification` block for iOS.  
  iOS app sends this when available; Android should send it when the receiver is iOS (from contact’s `device_type`).

**Other fields** (same as you use today):  
`title`, `body`, `receiverKey`, `user_name`, `photo`, `currentDateTimeString`, `deviceType`, `uid`, `message`, `time`, `receiverUid`, `modelId`, and the rest of your payload.

## Response

- **200** – JSON: `{ "status": "success", "fcm_response": { ... } }`  
- **4xx/5xx** – JSON: `{ "error": "..." }`

## iOS vs Android

- **Android receiver:** Message is sent with `data` only; Android app shows notification in `onMessageReceived` if needed.
- **iOS receiver:** Backend adds `notification` (title, body, sound) and `apns.payload.aps` when `receiverDeviceType === "2"` so the system shows the notification when the app is in background.
