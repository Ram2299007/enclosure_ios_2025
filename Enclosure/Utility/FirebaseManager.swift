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
        
        // Request notification permissions
        requestNotificationPermissions()
        
        print("✅ Firebase Database initialized")
    }
    
    func requestNotificationPermissions() {
        UNUserNotificationCenter.current().delegate = self
        
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { granted, error in
                if let error = error {
                    print("❌ Notification permission error: \(error.localizedDescription)")
                    return
                }
                
                if granted {
                    print("✅ Notification permission granted")
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                } else {
                    print("❌ Notification permission denied")
                }
            }
        )
    }
    
    func getFCMToken(completion: @escaping (String?) -> Void) {
        Messaging.messaging().token { token, error in
            if let error = error {
                print("❌ Error fetching FCM token: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            if let token = token {
                print("✅ FCM Token: \(token)")
                DispatchQueue.main.async {
                    self.fcmToken = token
                }
                completion(token)
            } else {
                print("❌ FCM token is nil")
                completion(nil)
            }
        }
    }
}

// MARK: - MessagingDelegate
extension FirebaseManager: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("📱 Firebase registration token: \(String(describing: fcmToken))")
        
        if let token = fcmToken {
            DispatchQueue.main.async {
                self.fcmToken = token
            }
            
            // Store token in UserDefaults
            UserDefaults.standard.set(token, forKey: Constant.FCM_TOKEN)
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

