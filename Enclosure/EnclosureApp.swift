//
//  EnclosureApp.swift
//  Enclosure
//
//  Created by Ram Lohar on 14/03/25.
//

import SwiftUI
import UserNotifications
import FirebaseCore
import FirebaseMessaging

// AppDelegate to lock orientation to portrait only and handle Firebase
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        NSLog("📤 [AppDelegate] didFinishLaunchingWithOptions CALLED")
        print("📤 [AppDelegate] didFinishLaunchingWithOptions CALLED")
        NSLog("📤 [AppDelegate] Launch options: \(launchOptions ?? [:])")
        print("📤 [AppDelegate] Launch options: \(launchOptions ?? [:])")
        
        // Check if app was launched from remote notification (when app is terminated and user taps notification)
        if let remoteNotification = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            print("📱 [AppDelegate] App launched from remote notification tap")
            print("📱 [AppDelegate] Remote notification keys: \(remoteNotification.keys.map { "\($0)" }.joined(separator: ", "))")
            
            // Convert to [String: Any] for processing
            let userInfo: [String: Any] = Dictionary(uniqueKeysWithValues: remoteNotification.compactMap { k, v in (k as? String).map { ($0, v) } })
            
            // Check if it's a chat notification
            let bodyKey = (userInfo["bodyKey"] as? String)?.lowercased() ?? ""
            if bodyKey == "chatting" {
                print("✅ [AppDelegate] Chat notification detected in launch options - will navigate after app is ready")
                
                // Store notification data and handle after app UI is ready
                // Longer delay to ensure ContentView has navigated to MainActivityOld
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    print("📱 [AppDelegate] Posting OpenChatFromNotification from launch options...")
                    print("📱 [AppDelegate] friendUidKey: \(userInfo["friendUidKey"] as? String ?? "nil")")
                    NotificationCenter.default.post(
                        name: NSNotification.Name("OpenChatFromNotification"),
                        object: nil,
                        userInfo: userInfo
                    )
                    print("✅ [AppDelegate] OpenChatFromNotification posted from launch")
                }
            }
        }
        
        // Check if app was launched from URL (this happens when app is terminated)
        // Note: When app launches from URL, iOS calls application(_:open:options:) AFTER this
        // But we also check here as a fallback
        if let url = launchOptions?[.url] as? URL {
            print("📤 [AppDelegate] App launched from URL in launchOptions: \(url)")
            if url.scheme == "enclosure" && url.host == "share" {
                print("📤 [AppDelegate] ✅ Launch URL matches - posting notification")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    NotificationCenter.default.post(name: NSNotification.Name("HandleSharedContent"), object: url)
                }
            }
        } else if launchOptions?[.remoteNotification] == nil {
            // Fallback: If app was just launched and Share Extension might have saved data,
            // check file container after a short delay (only if not launched from notification)
            print("📤 [AppDelegate] No URL or notification in launchOptions - will check file container as fallback")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Post notification without URL object to trigger UserDefaults check
                print("📤 [AppDelegate] Fallback: Posting HandleSharedContent notification")
                NotificationCenter.default.post(name: NSNotification.Name("HandleSharedContent"), object: nil)
            }
        }
        
        // Configure Firebase options to disable In-App Messaging (to suppress warnings)
        if FirebaseApp.app() == nil {
            // Only configure if not already configured
            FirebaseApp.configure()
        }
        
        // Firebase In-App Messaging has been removed from package dependencies
        // No need to configure it
        
        // Configure Firebase Manager
        FirebaseManager.shared.configure()
        
        // Register for remote notifications as soon as possible (if permission already granted).
        // This helps APNs token be ready before user reaches OTP screen.
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .authorized {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    print("📱 [APNS_TOKEN] registerForRemoteNotifications() called at launch (permission already granted)")
                }
            }
        }
        
        return true
    }
    
    // Handle remote notification registration
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("📱 [APNS_TOKEN] ✅✅✅✅✅ APNs device token received: \(tokenString)")
        print("📱 [APNS_TOKEN] ✅✅✅✅✅ Token length: \(deviceToken.count) bytes")
        NSLog("📱 [APNS_TOKEN] ✅✅✅✅✅ APNs device token received")
        
        Messaging.messaging().apnsToken = deviceToken
        print("📱 [APNS_TOKEN] APNs token set to Firebase Messaging")
        
        // Post notification that APNs token is available
        NotificationCenter.default.post(name: NSNotification.Name("APNsTokenReceived"), object: deviceToken)
        
        // Force FCM token refresh after APNs token is set (short delay so token is ready sooner)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            Messaging.messaging().token { token, error in
                if let error = error {
                    print("🚫 [APNS_TOKEN] Error fetching FCM token after APNs registration: \(error.localizedDescription)")
                } else if let token = token {
                    print("✅ [APNS_TOKEN] FCM token generated after APNs registration: \(token.prefix(50))...")
                    UserDefaults.standard.set(token, forKey: Constant.FCM_TOKEN)
                    // Post notification that FCM token is available
                    NotificationCenter.default.post(name: NSNotification.Name("FCMTokenReceived"), object: token)
                } else {
                    print("🚫 [APNS_TOKEN] FCM token is nil after APNs registration")
                }
            }
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("🚫 [APNS_TOKEN] ❌❌❌❌❌ Failed to register for remote notifications: \(error.localizedDescription)")
        print("🚫 [APNS_TOKEN] ❌❌❌❌❌ Error details: \(error)")
        NSLog("🚫 [APNS_TOKEN] ❌❌❌❌❌ Failed to register: \(error.localizedDescription)")
        
        // Post notification that registration failed
        NotificationCenter.default.post(name: NSNotification.Name("APNsTokenFailed"), object: error)
    }
    
    /// Handle FCM data payload (matching Android FirebaseMessagingService.onMessageReceived). For bodyKey == Constant.chatting, show local chat notification.
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let keys = userInfo.keys.map { "\($0)" }.joined(separator: ", ")
        let bodyKey = userInfo["bodyKey"] as? String
        
        // Check if APS payload exists (required for Notification Service Extension)
        let hasAps = userInfo["aps"] != nil
        let hasAlert = (userInfo["aps"] as? [String: Any])?["alert"] != nil
        let hasMutableContent = ((userInfo["aps"] as? [String: Any])?["mutable-content"] as? Int) == 1
        
        print("📱 [FCM] didReceiveRemoteNotification - keys: \(keys)")
        print("📱 [FCM] bodyKey = \(bodyKey ?? "nil")")
        print("📱 [FCM] APS present: \(hasAps)")
        print("📱 [FCM] APS alert present: \(hasAlert)")
        print("📱 [FCM] mutable-content: \(hasMutableContent)")
        
        if hasAps && hasAlert && hasMutableContent {
            print("✅ [FCM] Notification Service Extension SHOULD be called (APS alert + mutable-content)")
        } else if hasAps && hasAlert {
            print("⚠️ [FCM] APS alert present but NO mutable-content - Service Extension will NOT be called")
        } else {
            print("⚠️ [FCM] Data-only notification (no APS alert) - Service Extension will NOT be called")
            print("⚠️ [FCM] Backend needs to send APS alert with mutable-content: 1 for Communication Notifications")
        }
        
        if bodyKey == Constant.chatting {
            print("📱 [CHAT_NOTIFICATION] AppDelegate: chat payload received - forwarding to FirebaseManager")
        } else if bodyKey == nil {
            print("📱 [FCM] bodyKey missing (use data-only FCM for chat so this is called)")
        }
        FirebaseManager.shared.handleRemoteNotification(userInfo: userInfo, completionHandler: completionHandler)
    }
    
    // Handle URL schemes (for Share Extension)
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        NSLog("📤📤📤 [AppDelegate] ====== application(_:open:options:) CALLED ======")
        print("📤 [AppDelegate] ====== application(_:open:options:) CALLED ======")
        NSLog("📤 [AppDelegate] URL: \(url)")
        print("📤 [AppDelegate] URL: \(url)")
        NSLog("📤 [AppDelegate] URL scheme: \(url.scheme ?? "nil")")
        print("📤 [AppDelegate] URL scheme: \(url.scheme ?? "nil")")
        NSLog("📤 [AppDelegate] URL host: \(url.host ?? "nil")")
        print("📤 [AppDelegate] URL host: \(url.host ?? "nil")")
        NSLog("📤 [AppDelegate] Options: \(options)")
        print("📤 [AppDelegate] Options: \(options)")
        
        if url.scheme == "enclosure" && url.host == "share" {
            NSLog("📤 [AppDelegate] ✅ URL matches enclosure://share - posting notification")
            print("📤 [AppDelegate] ✅ URL matches enclosure://share - posting notification")
            // Post notification to handle shared content
            // File container is fast - minimal delay needed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                NSLog("📤 [AppDelegate] ⏰ Posting HandleSharedContent notification after delay...")
                print("📤 [AppDelegate] ⏰ Posting HandleSharedContent notification after delay...")
                NotificationCenter.default.post(name: NSNotification.Name("HandleSharedContent"), object: url)
                NSLog("📤 [AppDelegate] ✅ Notification posted: HandleSharedContent")
                print("📤 [AppDelegate] ✅ Notification posted: HandleSharedContent")
            }
            return true
        }
        
        NSLog("📤 [AppDelegate] ⚠️ URL does not match enclosure://share")
        print("📤 [AppDelegate] ⚠️ URL does not match enclosure://share")
        return false
    }
    
    // Handle app becoming active (when Share Extension opens app that's already running)
    func applicationDidBecomeActive(_ application: UIApplication) {
        NSLog("📤📤📤 [AppDelegate] applicationDidBecomeActive CALLED")
        print("📤 [AppDelegate] applicationDidBecomeActive CALLED")
        // Check for shared content when app becomes active
        // File container is fast - minimal delay needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NSLog("📤 [AppDelegate] ⏰ Checking for shared content after becoming active...")
            print("📤 [AppDelegate] ⏰ Checking for shared content after becoming active...")
            NotificationCenter.default.post(name: NSNotification.Name("HandleSharedContent"), object: nil)
        }
    }
}

@main
struct EnclosureApp: App {
    let persistenceController = PersistenceController.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .lockOrientationToPortrait()
                .onChange(of: scenePhase) { newPhase in
                    NSLog("📤📤📤 [EnclosureApp] Scene phase changed to: \(String(describing: newPhase))")
                    print("📤 [EnclosureApp] Scene phase changed to: \(String(describing: newPhase))")
                    
                    if newPhase == .active {
                        NSLog("📤📤📤 [EnclosureApp] App became ACTIVE - checking for shared content...")
                        print("📤 [EnclosureApp] App became ACTIVE - checking for shared content...")
                        // Check for shared content when app becomes active
                        // File container is fast - minimal delay needed
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            NSLog("📤📤📤 [EnclosureApp] Posting HandleSharedContent notification from scene phase change")
                            print("📤 [EnclosureApp] Posting HandleSharedContent notification from scene phase change")
                            NotificationCenter.default.post(name: NSNotification.Name("HandleSharedContent"), object: nil)
                        }
                    }
                }
        }
    }
}
