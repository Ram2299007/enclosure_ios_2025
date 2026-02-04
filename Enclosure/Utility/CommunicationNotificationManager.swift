//
//  CommunicationNotificationManager.swift
//  Enclosure
//
//  WhatsApp-like iOS Communication Notifications using INSendMessageIntent
//  iOS 15+ required
//

import Foundation
import UserNotifications
import Intents
import UIKit
import CryptoKit

/// Manages WhatsApp-like Communication Notifications using INSendMessageIntent and INPerson
/// This provides native iOS notification UI with circular profile picture on the LEFT
@available(iOS 15.0, *)
final class CommunicationNotificationManager {
    static let shared = CommunicationNotificationManager()
    
    private init() {}
    
    /// Creates a WhatsApp-like communication notification using INSendMessageIntent
    /// - Parameters:
    ///   - senderName: Display name of the sender
    ///   - message: Message text to display
    ///   - senderUid: Unique identifier for the sender (used for conversationIdentifier)
    ///   - profileImagePath: Local file path to sender's profile picture (must be cached locally)
    ///   - userInfo: Additional payload data for notification handling
    ///   - completion: Callback with success status
    func createCommunicationNotification(
        senderName: String,
        message: String,
        senderUid: String,
        profileImagePath: String?,
        userInfo: [String: Any],
        completion: @escaping (Bool) -> Void
    ) {
        // Step 1: Create INPerson with profile image from local cache
        let person = createPerson(
            name: senderName,
            uid: senderUid,
            profileImagePath: profileImagePath
        )
        
        // Step 2: Create INSendMessageIntent using initializer (properties are read-only)
        // conversationIdentifier is critical for WhatsApp-like message grouping
        // sender is the person sending the message (shown as profile picture on LEFT)
        // serviceName identifies the messaging service (e.g., "Enclosure")
        let conversationId = senderUid.isEmpty ? "chat" : senderUid
        let currentUser = Self.makeCurrentUserPerson()
        let intent = INSendMessageIntent(
            recipients: [currentUser],
            content: message,
            speakableGroupName: nil,
            conversationIdentifier: conversationId,
            serviceName: nil,
            sender: person
        )
        
        // Step 3: Create UNNotificationContent
        let content = UNMutableNotificationContent()
        content.title = senderName
        content.body = message
        content.sound = .default
        content.userInfo = userInfo
        
        // Critical: Set threadIdentifier for grouping messages from same sender
        // This groups notifications in iOS notification center (like WhatsApp)
        content.threadIdentifier = senderUid.isEmpty ? "chat" : senderUid
        content.summaryArgument = senderName
        content.summaryArgumentCount = 1
        
        // Set category for inline reply action
        // Note: Content Extension is disabled for CHAT_MESSAGE, so native UI will be used
        content.categoryIdentifier = "CHAT_MESSAGE"
        
        // Set interruption level for iOS 15+
        content.interruptionLevel = .active
        
        // Step 4: Configure for Communication Notifications
        // Store intent information in userInfo so iOS can recognize it as a Communication Notification
        // iOS will use the donated intent to show profile picture on LEFT
        content.userInfo["intentType"] = "INSendMessageIntent"
        content.userInfo["senderUid"] = senderUid
        content.userInfo["senderName"] = senderName
        
        // Step 5: Create UNNotificationRequest
        let identifier = "chat_\(abs(senderUid.hashValue))"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        
        // Step 6: Donate intent BEFORE showing notification (recommended)
        // This helps iOS learn user's communication patterns and enables Communication Notifications
        // iOS uses donated intents to recognize communication patterns and show profile pictures
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.donate { error in
            if let error = error {
                print("⚠️ [COMM_NOTIFICATION] Intent donation failed: \(error.localizedDescription)")
            } else {
                print("✅ [COMM_NOTIFICATION] Intent donated successfully for \(senderName)")
            }
            
            // Add notification after intent donation (ensures iOS recognizes it as communication)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("🚫 [COMM_NOTIFICATION] Failed to add notification: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("✅ [COMM_NOTIFICATION] Communication notification created for \(senderName)")
                    completion(true)
                }
            }
        }
        
        return  // Don't add notification here - wait for intent donation
        
    }

    /// Donates an INSendMessageIntent without scheduling a notification.
    /// Use this in the MAIN APP to ensure donation metadata exists before pushes arrive.
    func donateIntent(
        senderName: String,
        message: String,
        senderUid: String,
        photoUrl: String,
        completion: ((Bool) -> Void)? = nil
    ) {
        ProfilePictureCacheManager.shared.getCachedProfileImage(
            photoUrl: photoUrl,
            senderUid: senderUid
        ) { [weak self] cachedImagePath in
            guard let self = self else {
                completion?(false)
                return
            }

            let person = self.createPerson(
                name: senderName,
                uid: senderUid,
                profileImagePath: cachedImagePath
            )

            let conversationId = senderUid.isEmpty ? "chat" : senderUid
            let currentUser = Self.makeCurrentUserPerson()
            let intent = INSendMessageIntent(
                recipients: [currentUser],
                content: message,
                speakableGroupName: nil,
                conversationIdentifier: conversationId,
                serviceName: nil,
                sender: person
            )

            let interaction = INInteraction(intent: intent, response: nil)
            interaction.donate { error in
                if let error = error {
                    print("⚠️ [COMM_NOTIFICATION] Intent donate failed: \(error.localizedDescription)")
                    completion?(false)
                } else {
                    print("✅ [COMM_NOTIFICATION] Intent donated successfully for \(senderName)")
                    completion?(true)
                }
            }
        }
    }
    
    /// Creates INPerson with profile image loaded from local file cache
    private func createPerson(
        name: String,
        uid: String,
        profileImagePath: String?,
        isMe: Bool = false
    ) -> INPerson {
        var image: INImage?
        
        // Load profile image from local cache (not remote URL)
        if let imagePath = profileImagePath, !imagePath.isEmpty {
            // Check if it's a file path or URL string
            let fileURL: URL?
            if imagePath.hasPrefix("file://") {
                fileURL = URL(string: imagePath)
            } else if FileManager.default.fileExists(atPath: imagePath) {
                fileURL = URL(fileURLWithPath: imagePath)
            } else {
                fileURL = nil
            }
            
            // Load image from file path
            if let url = fileURL,
               let imageData = try? Data(contentsOf: url),
               let uiImage = UIImage(data: imageData) {
                // Create INImage from UIImage using imageData (INImage doesn't have uiImage initializer)
                if let jpegData = uiImage.jpegData(compressionQuality: 0.9) {
                    image = INImage(imageData: jpegData)
                    print("✅ [COMM_NOTIFICATION] Loaded profile image from local cache: \(imagePath)")
                } else {
                    print("⚠️ [COMM_NOTIFICATION] Failed to convert UIImage to JPEG data")
                }
            } else {
                print("⚠️ [COMM_NOTIFICATION] Failed to load profile image from: \(imagePath)")
            }
        }
        
        // Create personHandle (required for INPerson)
        let personHandle = INPersonHandle(
            value: uid,
            type: .unknown,
            label: nil
        )
        
        // Create INPerson with image
        let person: INPerson
        if #available(iOS 15.0, *) {
            person = INPerson(
                personHandle: personHandle,
                nameComponents: nil,
                displayName: name,
                image: image,
                contactIdentifier: nil,
                customIdentifier: uid,
                isMe: isMe
            )
        } else {
            person = INPerson(
                personHandle: personHandle,
                nameComponents: nil,
                displayName: name,
                image: image,
                contactIdentifier: nil,
                customIdentifier: uid
            )
        }
        
        return person
    }

    /// Creates a minimal INPerson for the current user as the message recipient.
    private static func makeCurrentUserPerson() -> INPerson {
        let currentUid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? "me"
        let currentName = UserDefaults.standard.string(forKey: Constant.full_name) ?? "Me"
        let handle = INPersonHandle(value: currentUid, type: .unknown, label: nil)
        if #available(iOS 15.0, *) {
            return INPerson(
                personHandle: handle,
                nameComponents: nil,
                displayName: currentName,
                image: nil,
                contactIdentifier: nil,
                customIdentifier: currentUid,
                isMe: true
            )
        }
        return INPerson(
            personHandle: handle,
            nameComponents: nil,
            displayName: currentName,
            image: nil,
            contactIdentifier: nil,
            customIdentifier: currentUid
        )
    }
    
    /// Creates a communication notification from FCM payload data
    /// This is the main entry point called from FirebaseManager
    func createNotificationFromPayload(
        data: [String: Any],
        completion: @escaping (Bool) -> Void
    ) {
        // Extract notification data (using same keys as FirebaseManager.ChatPayloadKey)
        let userName = data["name"] as? String ?? ""
        let message = data["msgKey"] as? String ?? ""
        let senderUid = data["friendUidKey"] as? String ?? ""
        let user_nameKey = data["user_nameKey"] as? String ?? ""
        let photoUrlString = data["photo"] as? String ?? ""
        let selectionCount = data["selectionCount"] as? String ?? "1"
        
        let displayName = user_nameKey.isEmpty ? (userName.isEmpty ? "Unknown" : userName) : user_nameKey
        let displayMessage = Self.displayMessageForNotification(message: message, selectionCount: selectionCount)
        
        // Load profile picture from local cache
        ProfilePictureCacheManager.shared.getCachedProfileImage(
            photoUrl: photoUrlString,
            senderUid: senderUid
        ) { [weak self] cachedImagePath in
            guard let self = self else {
                completion(false)
                return
            }
            
            // Create communication notification
            self.createCommunicationNotification(
                senderName: displayName,
                message: displayMessage,
                senderUid: senderUid.isEmpty ? "unknown" : senderUid,
                profileImagePath: cachedImagePath,
                userInfo: data,
                completion: completion
            )
        }
    }
    
    /// Map message to display string (matching Android buildChatNotification displayMessage switch)
    private static func displayMessageForNotification(message: String, selectionCount: String) -> String {
        let truncatedMessage = message.count > 500 ? String(message.prefix(500)) + "..." : message
        let isMultiple = selectionCount != "1"
        
        switch truncatedMessage {
        case "You have a new Image": return "📷 " + (isMultiple ? "\(selectionCount) Photos" : "Photo")
        case "You have a new Contact": return "👤 " + (isMultiple ? "\(selectionCount) Contacts" : "Contact")
        case "You have a new Audio": return "🎙️ " + (isMultiple ? "\(selectionCount) Audios" : "Audio")
        case "You have a new File": return "📄 " + (isMultiple ? "\(selectionCount) Files" : "File")
        case "You have a new Video": return "📹 " + (isMultiple ? "\(selectionCount) Videos" : "Video")
        default: return truncatedMessage
        }
    }
}
