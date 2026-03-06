//
//  BadgeManager.swift
//  Enclosure
//
//  Badge count management for app icon and notification sync
//

import Foundation
import UIKit
import UserNotifications
import FirebaseDatabase

/// Manages app icon badge count and syncs with Firebase notification counts
class BadgeManager {
    static let shared = BadgeManager()
    
    // App Group for sharing badge count between app and extensions
    private let appGroupID = "group.com.enclosure.data"
    private let badgeCountKey = "badgeCount"
    
    private var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupID)
    }
    
    private init() {}
    
    // MARK: - App Icon Badge Management
    
    /// Get current app icon badge count
    func getCurrentBadgeCount() -> Int {
        return UIApplication.shared.applicationIconBadgeNumber
    }
    
    /// Set app icon badge count
    func setBadgeCount(_ count: Int) {
        let finalCount = max(0, count)
        
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = finalCount
            NSLog("📱 [BadgeManager] Badge count set to: \(finalCount)")
        }
        
        // Store in App Group so Notification Service Extension can access it
        sharedDefaults?.set(finalCount, forKey: badgeCountKey)
        NSLog("📱 [BadgeManager] Badge count stored in App Group: \(finalCount)")
    }
    
    /// Increment badge count by 1 (called when new notification arrives)
    func incrementBadge() {
        let current = getCurrentBadgeCount()
        setBadgeCount(current + 1)
        NSLog("📱 [BadgeManager] Badge incremented: \(current) -> \(current + 1)")
    }
    
    /// Decrement badge count by 1 (called when notification is dismissed)
    func decrementBadge() {
        let current = getCurrentBadgeCount()
        if current > 0 {
            setBadgeCount(current - 1)
            NSLog("📱 [BadgeManager] Badge decremented: \(current) -> \(current - 1)")
        }
    }
    
    /// Decrement badge by specific count (when opening chat with multiple unread)
    func decrementBadge(by count: Int) {
        let current = getCurrentBadgeCount()
        let newCount = max(0, current - count)
        setBadgeCount(newCount)
        NSLog("📱 [BadgeManager] Badge decremented by \(count): \(current) -> \(newCount)")
    }
    
    /// Calculate total badge from all chat notification counts
    func calculateTotalBadgeFromChats(chatList: [UserActiveContactModel]) {
        let total = chatList.reduce(0) { $0 + $1.notification }
        setBadgeCount(total)
        NSLog("📱 [BadgeManager] Total badge calculated from \(chatList.count) chats: \(total)")
    }
    
    /// Clear all badges (when app opens or user manually clears)
    func clearBadge() {
        setBadgeCount(0)
        NSLog("📱 [BadgeManager] Badge cleared")
    }
    
    // MARK: - Firebase Notification Count Sync
    
    /// Update notification count in Firebase for a specific chat
    /// This is called when user opens a chat to reset unread count
    func clearNotificationCount(forUserUid userUid: String, currentUserUid: String, previousCount: Int) {
        guard !userUid.isEmpty && !currentUserUid.isEmpty else {
            NSLog("⚠️ [BadgeManager] Cannot clear notification count - invalid UIDs")
            return
        }
        
        let ref = Database.database().reference()
        let path = "users/\(currentUserUid)/Contacts/\(userUid)/notification"
        
        NSLog("📱 [BadgeManager] Clearing notification count for user \(userUid)")
        NSLog("📱 [BadgeManager] Firebase path: \(path)")
        
        ref.child(path).setValue(0) { error, _ in
            if let error = error {
                NSLog("🚫 [BadgeManager] Failed to clear notification count: \(error.localizedDescription)")
            } else {
                NSLog("✅ [BadgeManager] Notification count cleared in Firebase")
                // Decrease app badge by the previous count
                self.decrementBadge(by: previousCount)
            }
        }
    }
    
    /// Increment notification count in Firebase when new message arrives
    /// This is called by NotificationService when notification is delivered
    func incrementNotificationCount(forUserUid userUid: String, currentUserUid: String) {
        guard !userUid.isEmpty && !currentUserUid.isEmpty else {
            NSLog("⚠️ [BadgeManager] Cannot increment notification count - invalid UIDs")
            return
        }
        
        let ref = Database.database().reference()
        let path = "users/\(currentUserUid)/Contacts/\(userUid)/notification"
        
        NSLog("📱 [BadgeManager] Incrementing notification count for user \(userUid)")
        
        // Get current count and increment
        ref.child(path).getData { error, snapshot in
            if let error = error {
                NSLog("🚫 [BadgeManager] Failed to get current notification count: \(error.localizedDescription)")
                // Set to 1 as fallback
                ref.child(path).setValue(1)
                return
            }
            
            let currentCount = snapshot?.value as? Int ?? 0
            let newCount = currentCount + 1
            
            ref.child(path).setValue(newCount) { error, _ in
                if let error = error {
                    NSLog("🚫 [BadgeManager] Failed to increment notification count: \(error.localizedDescription)")
                } else {
                    NSLog("✅ [BadgeManager] Notification count updated: \(currentCount) -> \(newCount)")
                }
            }
        }
    }
    
    // MARK: - Notification Center Integration
    
    /// Sync badge when notification is dismissed/removed
    func handleNotificationDismissed(withIdentifier identifier: String) {
        NSLog("📱 [BadgeManager] Notification dismissed: \(identifier)")
        
        // Decrement badge by 1
        decrementBadge()
        
        // Optionally: Parse identifier to get user UID and update Firebase
        // Format: "chat_notification_{senderUid}"
        if identifier.hasPrefix("chat_notification_") {
            let senderUid = identifier.replacingOccurrences(of: "chat_notification_", with: "")
            NSLog("📱 [BadgeManager] Chat notification dismissed for user: \(senderUid)")
            
            // Note: We don't clear Firebase count here because user didn't read the message
            // Only clear when user actually opens the chat
        }
    }
    
    /// Handle when all notifications are dismissed
    func handleAllNotificationsDismissed() {
        NSLog("📱 [BadgeManager] All notifications dismissed")
        clearBadge()
    }
    
    // MARK: - App Lifecycle Integration
    
    /// Called when app becomes active - sync badge with actual notification count
    func syncBadgeWithNotificationCenter() {
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            let chatNotifications = notifications.filter { notification in
                let bodyKey = notification.request.content.userInfo["bodyKey"] as? String
                return bodyKey == "chatting"
            }
            
            let count = chatNotifications.count
            NSLog("📱 [BadgeManager] Syncing badge with delivered notifications: \(count)")
            
            // Also check App Group stored value
            let storedCount = self.sharedDefaults?.integer(forKey: self.badgeCountKey) ?? 0
            NSLog("📱 [BadgeManager] App Group stored badge: \(storedCount)")
            
            // Use whichever is higher (delivered notifications or stored count)
            let finalCount = max(count, storedCount)
            
            DispatchQueue.main.async {
                self.setBadgeCount(finalCount)
            }
        }
    }
    
    /// Called when app launches - optionally recalculate from Firebase
    func recalculateBadgeFromFirebase(currentUserUid: String) {
        guard !currentUserUid.isEmpty else {
            NSLog("⚠️ [BadgeManager] Cannot recalculate badge - invalid user UID")
            return
        }
        
        let ref = Database.database().reference()
        let path = "users/\(currentUserUid)/Contacts"
        
        NSLog("📱 [BadgeManager] Recalculating badge from Firebase...")
        
        ref.child(path).getData { error, snapshot in
            if let error = error {
                NSLog("🚫 [BadgeManager] Failed to fetch contacts for badge calculation: \(error.localizedDescription)")
                return
            }
            
            guard let contactsDict = snapshot?.value as? [String: [String: Any]] else {
                NSLog("⚠️ [BadgeManager] No contacts found in Firebase")
                self.clearBadge()
                return
            }
            
            var totalCount = 0
            for (_, contactData) in contactsDict {
                if let notificationCount = contactData["notification"] as? Int {
                    totalCount += notificationCount
                }
            }
            
            NSLog("✅ [BadgeManager] Calculated total badge from Firebase: \(totalCount)")
            self.setBadgeCount(totalCount)
        }
    }
}
