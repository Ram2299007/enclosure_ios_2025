//
//  FirebaseManager.swift
//  Enclosure
//
//  Created for Firebase integration
//

import Foundation
import UIKit
import FirebaseCore
import FirebaseMessaging
import FirebaseDatabase
import UserNotifications

class FirebaseManager: NSObject, ObservableObject {
    static let shared = FirebaseManager()
    
    @Published var fcmToken: String?
    
    /// When non-nil, ChattingScreen is visible for this receiver UID (friendUidKey). Used to suppress chat notifications (matching Android chattingScreen.isChatScreenActive).
    @Published var chatScreenActiveUid: String?
    
    private override init() {
        super.init()
    }
    
    func configure() {
        // Firebase will be configured via GoogleService-Info.plist
        // This method can be used for additional setup if needed
        Messaging.messaging().delegate = self
        
        // Configure Realtime Database
        Database.database().isPersistenceEnabled = false // Set to true if you want offline persistence
        
        // Listen for APNs token received notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAPNsTokenReceived(_:)),
            name: NSNotification.Name("APNsTokenReceived"),
            object: nil
        )
        
        // Listen for FCM token received notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFCMTokenReceived(_:)),
            name: NSNotification.Name("FCMTokenReceived"),
            object: nil
        )
        
        // Request notification permissions
        requestNotificationPermissions()
        
        print("✅ Firebase Database initialized")
    }
    
    @objc private func handleAPNsTokenReceived(_ notification: Notification) {
        if let deviceToken = notification.object as? Data {
            print("📱 [FIREBASE_MANAGER] APNs token received via notification: \(deviceToken.map { String(format: "%02.2hhx", $0) }.joined().prefix(20))...")
        }
    }
    
    @objc private func handleFCMTokenReceived(_ notification: Notification) {
        if let token = notification.object as? String {
            print("📱 [FIREBASE_MANAGER] FCM token received via notification: \(token.prefix(50))...")
            DispatchQueue.main.async {
                self.fcmToken = token
            }
            UserDefaults.standard.set(token, forKey: Constant.FCM_TOKEN)
        }
    }
    
    func requestNotificationPermissions() {
        UNUserNotificationCenter.current().delegate = self
        
        // Check current authorization status first
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("📱 [NOTIFICATION_PERMISSION] Current authorization status: \(settings.authorizationStatus.rawValue)")
            print("📱 [NOTIFICATION_PERMISSION] Authorization status: \(self.authorizationStatusString(settings.authorizationStatus))")
            
            if settings.authorizationStatus == .authorized {
                print("✅ [NOTIFICATION_PERMISSION] Already authorized - registering for remote notifications...")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    print("📱 [NOTIFICATION_PERMISSION] registerForRemoteNotifications() called")
                }
            } else {
                print("📱 [NOTIFICATION_PERMISSION] Requesting authorization...")
                let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
                UNUserNotificationCenter.current().requestAuthorization(
                    options: authOptions,
                    completionHandler: { granted, error in
                        if let error = error {
                            print("🚫 [NOTIFICATION_PERMISSION] Permission error: \(error.localizedDescription)")
                            return
                        }
                        
                        if granted {
                            print("✅ [NOTIFICATION_PERMISSION] Permission granted - registering for remote notifications...")
                            DispatchQueue.main.async {
                                UIApplication.shared.registerForRemoteNotifications()
                                print("📱 [NOTIFICATION_PERMISSION] registerForRemoteNotifications() called")
                            }
                        } else {
                            print("🚫 [NOTIFICATION_PERMISSION] Permission denied")
                        }
                    }
                )
            }
        }
    }
    
    private func authorizationStatusString(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .denied: return "denied"
        case .authorized: return "authorized"
        case .provisional: return "provisional"
        case .ephemeral: return "ephemeral"
        @unknown default: return "unknown"
        }
    }
    
    func getFCMToken(completion: @escaping (String?) -> Void) {
        #if targetEnvironment(simulator)
        if Messaging.messaging().apnsToken == nil {
            print("⚠️ [FCM_TOKEN] Simulator: APNs is not supported - FCM token will not be available. Use a real device for push.")
            completion(nil)
            return
        }
        #endif
        
        // Check if APNs token is set first
        if Messaging.messaging().apnsToken == nil {
            print("⚠️ [FCM_TOKEN] APNs token not set yet - returning nil (token will arrive via didRegisterForRemoteNotificationsWithDeviceToken → FCMTokenReceived)")
            completion(nil)
            return
        }
        
        // APNs token is available, fetch FCM token
        print("✅ [FCM_TOKEN] APNs token is available - fetching FCM token...")
        fetchFCMToken(completion: completion)
    }
    
    private func fetchFCMToken(completion: @escaping (String?) -> Void) {
        Messaging.messaging().token { token, error in
            if let error = error {
                print("🚫 [FCM_TOKEN] Error fetching FCM token: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            if let token = token {
                print("✅ [FCM_TOKEN] FCM Token retrieved: \(token.prefix(50))...")
                DispatchQueue.main.async {
                    self.fcmToken = token
                }
                completion(token)
            } else {
                print("🚫 [FCM_TOKEN] FCM token is nil")
                completion(nil)
            }
        }
    }
}

// MARK: - MessagingDelegate
extension FirebaseManager: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("📱 [FCM_TOKEN] Firebase registration token received: \(String(describing: fcmToken))")
        
        if let token = fcmToken, !token.isEmpty {
            DispatchQueue.main.async {
                self.fcmToken = token
            }
            
            // Store token in UserDefaults
            let previousToken = UserDefaults.standard.string(forKey: Constant.FCM_TOKEN) ?? ""
            UserDefaults.standard.set(token, forKey: Constant.FCM_TOKEN)
            
            // Broadcast so screens waiting for token (e.g. whatsTheCode) can proceed
            NotificationCenter.default.post(name: NSNotification.Name("FCMTokenReceived"), object: token)
            
            print("📱 [FCM_TOKEN] Previous token: \(previousToken.isEmpty ? "EMPTY" : (previousToken == "apns_missing" ? "apns_missing" : "\(previousToken.prefix(50))..."))")
            print("📱 [FCM_TOKEN] New token: \(token.prefix(50))...")
            
            // If previous token was "apns_missing" or empty, and user is logged in, update backend
            let uid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
            let isLoggedIn = !uid.isEmpty && UserDefaults.standard.string(forKey: Constant.loggedInKey) != nil
            
            if isLoggedIn && (previousToken == "apns_missing" || previousToken.isEmpty) {
                print("📱 [FCM_TOKEN] User is logged in and previous token was missing - updating backend...")
                self.updateFCMTokenInBackend(uid: uid, fcmToken: token)
            } else if isLoggedIn && previousToken != token {
                print("📱 [FCM_TOKEN] FCM token changed - updating backend...")
                self.updateFCMTokenInBackend(uid: uid, fcmToken: token)
            }
        }
    }
    
    /// Updates FCM token in backend using update_profile API (also sends device_type so backend can store for iOS notification payload)
    private func updateFCMTokenInBackend(uid: String, fcmToken: String) {
        print("📱 [FCM_TOKEN] Updating FCM token in backend for UID: \(uid)")
        
        let parameters: [String: Any] = [
            "uid": uid,
            "f_token": fcmToken,
            "device_type": "2"  // iOS; backend stores so send_notification_api can add FCM notification block for this user when they are receiver
        ]
        
        ApiService.update_profile(data: parameters) { success, message in
            if success {
                print("✅ [FCM_TOKEN] FCM token updated successfully in backend: \(message)")
            } else {
                print("⚠️ [FCM_TOKEN] Failed to update FCM token in backend: \(message)")
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension FirebaseManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([[.banner, .sound, .badge]])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let raw = response.notification.request.content.userInfo
        // Convert to [String: Any] for OpenChatFromNotification (keys may be AnyHashable)
        let userInfo: [String: Any] = Dictionary(uniqueKeysWithValues: raw.compactMap { k, v in (k as? String).map { ($0, v) } })
        // If this was a chat notification, open ChattingScreen (matching Android PendingIntent to chattingScreen)
        if (userInfo["bodyKey"] as? String) == Constant.chatting {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("OpenChatFromNotification"),
                    object: nil,
                    userInfo: userInfo
                )
            }
        }
        completionHandler()
    }
}

// MARK: - Chat notification payload keys (matching Android FirebaseMessagingService getData())
extension FirebaseManager {
    /// Keys for FCM chat payload – match Android remoteMessage.getData() keys
    enum ChatPayloadKey {
        static let name = "name"
        static let msgKey = "msgKey"
        static let meetingId = "meetingId"
        static let phone = "phone"
        static let photo = "photo"
        static let token = "token"
        static let uid = "uid"
        static let receiverId = "receiverId"
        static let bodyKey = "bodyKey"
        static let friendUidKey = "friendUidKey"
        static let user_nameKey = "user_nameKey"
        static let currentDateTimeString = "currentDateTimeString"
        static let device_type = "device_type"
        static let title = "title"
        static let userFcmToken = "userFcmToken"
        static let username = "username"
        static let createdBy = "createdBy"
        static let incoming = "incoming"
        // Reply / power keys (matching Android)
        static let uidPower = "uidPower"
        static let messagePower = "messagePower"
        static let timePower = "timePower"
        static let documentPower = "documentPower"
        static let dataTypePower = "dataTypePower"
        static let extensionPower = "extensionPower"
        static let namepower = "namepower"
        static let phonePower = "phonePower"
        static let micPhotoPower = "micPhotoPower"
        static let miceTimingPower = "miceTimingPower"
        static let userNamePower = "userNamePower"
        static let replytextDataPower = "replytextDataPower"
        static let replyKeyPower = "replyKeyPower"
        static let replyTypePower = "replyTypePower"
        static let replyOldDataPower = "replyOldDataPower"
        static let replyCrtPostionPower = "replyCrtPostionPower"
        static let modelIdPower = "modelIdPower"
        static let receiverUidPower = "receiverUidPower"
        static let forwaredKeyPower = "forwaredKeyPower"
        static let groupNamePower = "groupNamePower"
        static let docSizePower = "docSizePower"
        static let fileNamePower = "fileNamePower"
        static let thumbnailPower = "thumbnailPower"
        static let fileNameThumbnailPower = "fileNameThumbnailPower"
        static let captionPower = "captionPower"
        static let notificationPower = "notificationPower"
        static let currentDatePower = "currentDatePower"
        static let userFcmTokenPower = "userFcmTokenPower"
        static let myFcmOwn = "myFcmOwn"
        static let senderTokenReplyPower = "senderTokenReplyPower"
        static let roomId = "roomId"
        static let selectionCount = "selectionCount"
    }
    
    /// Handle remote FCM payload. Call from AppDelegate didReceiveRemoteNotification. When bodyKey == Constant.chatting, show local chat notification (matching Android onMessageReceived for chatting).
    func handleRemoteNotification(userInfo: [AnyHashable: Any], completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let data = userInfo as? [String: Any] ?? [:]
        let bodyKey = data[ChatPayloadKey.bodyKey] as? String
        
        if bodyKey == Constant.chatting {
            handleChatNotification(data: data, completionHandler: completionHandler)
            return
        }
        
        // Payload without bodyKey or with other type: show generic notification if we have title/body (e.g. from backend or FCM notification payload)
        if let aps = userInfo["aps"] as? [String: Any], let alert = aps["alert"] as? [String: Any] {
            let title = alert["title"] as? String ?? "Notification"
            let body = alert["body"] as? String ?? (alert["title"] as? String) ?? ""
            showLocalNotification(title: title, body: body, userInfo: data, completionHandler: completionHandler)
            return
        }
        if let aps = userInfo["aps"] as? [String: Any], let body = aps["alert"] as? String {
            showLocalNotification(title: "Notification", body: body, userInfo: data, completionHandler: completionHandler)
            return
        }
        if let title = data["title"] as? String, let body = data["body"] as? String {
            showLocalNotification(title: title, body: body, userInfo: data, completionHandler: completionHandler)
            return
        }
        
        print("📱 [FCM] Payload has no bodyKey/chatting and no title/body - skipping local notification")
        completionHandler(.noData)
    }
    
    private func showLocalNotification(title: String, body: String, userInfo: [String: Any], completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
        let request = UNNotificationRequest(identifier: "fcm_\(abs(title.hashValue))", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🚫 [FCM] Failed to show notification: \(error.localizedDescription)")
            } else {
                print("✅ [FCM] Notification shown: \(title)")
            }
            completionHandler(.newData)
        }
    }
    
    private func handleChatNotification(data: [String: Any], completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        // Extract all params (matching Android FirebaseMessagingService)
        let userName = data[ChatPayloadKey.name] as? String ?? ""
        let message = data[ChatPayloadKey.msgKey] as? String ?? ""
        let receiverKey = data[ChatPayloadKey.friendUidKey] as? String ?? ""
        let user_nameKey = data[ChatPayloadKey.user_nameKey] as? String ?? ""
        
        // Suppress if user is already on this chat (matching Android chattingScreen.isChatScreenActive && receiverKey.equals(chattingScreen.isChatScreenActiveUid))
        let activeUid = chatScreenActiveUid ?? ""
        if !receiverKey.isEmpty && receiverKey == activeUid {
            print("📱 [CHAT_NOTIFICATION] Chat in foreground for \(receiverKey) → suppressing notification")
            completionHandler(.newData)
            return
        }
        
        let truncatedMessage = message.count > 500 ? String(message.prefix(500)) + "..." : message
        let displayName = user_nameKey.isEmpty ? (userName.isEmpty ? "Unknown" : userName) : user_nameKey
        
        // Build local notification with full payload in userInfo for tap handling (matching Android buildChatNotification intent extras)
        let content = UNMutableNotificationContent()
        content.title = displayName
        content.body = truncatedMessage
        content.sound = .default
        content.categoryIdentifier = "CHAT_MESSAGE"
        content.userInfo = data
        content.threadIdentifier = receiverKey.isEmpty ? "chat" : receiverKey
        
        let uidForNotification = (data[ChatPayloadKey.uidPower] as? String).flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 }
            ?? (receiverKey.isEmpty ? nil : receiverKey)
            ?? (data[ChatPayloadKey.uid] as? String)
            ?? "unknown"
        let notifId = abs(uidForNotification.hashValue)
        let request = UNNotificationRequest(identifier: "chat_\(notifId)", content: content, trigger: nil)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🚫 [CHAT_NOTIFICATION] Failed to add notification: \(error.localizedDescription)")
            } else {
                print("✅ [CHAT_NOTIFICATION] Chat notification shown for \(displayName)")
            }
            completionHandler(.newData)
        }
    }
    
    /// Static reply suggestions (matching Android getStaticReplies)
    private static func getStaticReplies(for message: String) -> [String] {
        let lower = message.lowercased().trimmingCharacters(in: .whitespaces)
        if lower.contains("good morning") || lower.contains("gm") || lower.contains("morning") {
            return ["Good morning", "Morning!", "Good morning! 😊"]
        }
        if lower.contains("good night") || lower.contains("gn") || lower.contains("night") {
            return ["Good night", "Night!", "Sleep well! 😴"]
        }
        if lower.contains("hello") || lower.contains("hi") || lower.contains("hey") {
            return ["Hello", "Hi there!", "Hey! 👋"]
        }
        if lower.contains("thank") || lower.contains("thanks") {
            return ["You're welcome", "No problem", "Anytime! 😊"]
        }
        if lower.contains("sorry") || lower.contains("apolog") {
            return ["No worries", "It's okay", "That's fine"]
        }
        return ["Ok", "Thanks", "👍"]
    }
}

