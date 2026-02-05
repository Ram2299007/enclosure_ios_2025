//
//  NotificationDelegate.swift
//  Enclosure
//
//  Handles notification interactions and badge management
//

import Foundation
import UserNotifications
import UIKit

/// Notification Center Delegate to handle notification interactions
/// - Handles notification taps (foreground/background)
/// - Handles notification dismissal (badge decrement)
/// - Syncs with BadgeManager for accurate badge counts
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    
    static let shared = NotificationDelegate()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Will Present (Foreground)
    
    /// Called when notification arrives while app is in foreground
    /// Decide whether to show notification or handle silently
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        NSLog("📱 [NotificationDelegate] willPresent notification")
        
        let userInfo = notification.request.content.userInfo
        let bodyKey = userInfo["bodyKey"] as? String
        
        if bodyKey == "chatting" {
            // Chat notification - show banner, sound, and increment badge
            NSLog("📱 [NotificationDelegate] Chat notification in foreground - showing banner")
            
            if #available(iOS 14.0, *) {
                completionHandler([.banner, .sound, .badge])
            } else {
                completionHandler([.alert, .sound, .badge])
            }
        } else {
            // Other notifications
            if #available(iOS 14.0, *) {
                completionHandler([.banner, .sound, .badge])
            } else {
                completionHandler([.alert, .sound, .badge])
            }
        }
    }
    
    // MARK: - Did Receive Response (Tap/Dismiss)
    
    /// Called when user interacts with notification (tap, dismiss, action button)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        NSLog("📱 [NotificationDelegate] didReceive response")
        NSLog("📱 [NotificationDelegate] Action identifier: \(response.actionIdentifier)")
        
        let notification = response.notification
        let userInfo = notification.request.content.userInfo
        let bodyKey = userInfo["bodyKey"] as? String
        
        // Handle different action types
        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification
            NSLog("📱 [NotificationDelegate] User tapped notification")
            
            if bodyKey == "chatting" {
                // Chat notification tapped - navigate to chat
                NSLog("📱 [NotificationDelegate] Chat notification tapped - posting OpenChatFromNotification")
                
                // Post notification to navigate to chat
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("OpenChatFromNotification"),
                        object: nil,
                        userInfo: userInfo
                    )
                }
                
                // Badge will be decremented when chat opens and clears notification count
            }
            
        case UNNotificationDismissActionIdentifier:
            // User dismissed/swiped away the notification
            NSLog("📱 [NotificationDelegate] User dismissed notification")
            
            if bodyKey == "chatting" {
                // Decrement badge when notification is dismissed
                let friendUid = userInfo["friendUidKey"] as? String ?? ""
                NSLog("📱 [NotificationDelegate] Chat notification dismissed for user: \(friendUid)")
                
                // Decrement app icon badge
                BadgeManager.shared.decrementBadge()
            }
            
        default:
            // Custom action button tapped
            NSLog("📱 [NotificationDelegate] Custom action: \(response.actionIdentifier)")
        }
        
        completionHandler()
    }
    
    // MARK: - Open Settings
    
    /// Called when user opens notification settings from notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        openSettingsFor notification: UNNotification?
    ) {
        NSLog("📱 [NotificationDelegate] User opened notification settings")
    }
}
