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
        // Check if APNs token is set first
        if Messaging.messaging().apnsToken == nil {
            print("⚠️ [FCM_TOKEN] APNs token not set yet - returning nil immediately (no waiting)")
            // Return nil immediately instead of waiting
            // FCM token will be available via MessagingDelegate callback when APNs token is ready
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
    
    /// Updates FCM token in backend using update_profile API
    private func updateFCMTokenInBackend(uid: String, fcmToken: String) {
        print("📱 [FCM_TOKEN] Updating FCM token in backend for UID: \(uid)")
        
        let parameters: [String: Any] = [
            "uid": uid,
            "f_token": fcmToken
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
        // Handle notification tap
        completionHandler()
    }
}

