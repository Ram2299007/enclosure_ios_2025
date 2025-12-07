//
//  EnclosureApp.swift
//  Enclosure
//
//  Created by Ram Lohar on 14/03/25.
//

import SwiftUI
import FirebaseCore
import FirebaseMessaging

// AppDelegate to lock orientation to portrait only and handle Firebase
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure Firebase options to disable In-App Messaging (to suppress warnings)
        if FirebaseApp.app() == nil {
            // Only configure if not already configured
            FirebaseApp.configure()
        }
        
        // Configure Firebase Manager
        FirebaseManager.shared.configure()
        
        return true
    }
    
    // Handle remote notification registration
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }
}

@main
struct EnclosureApp: App {
    let persistenceController = PersistenceController.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .lockOrientationToPortrait()
        }
    }
}
