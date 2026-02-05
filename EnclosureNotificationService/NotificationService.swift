import Foundation
import UserNotifications
import UIKit
import Intents
import os

/// Notification Service Extension for Communication Notifications
/// Creates INSendMessageIntent to enable WhatsApp-like UI
final class NotificationService: UNNotificationServiceExtension {
    private let logger = Logger(subsystem: "com.enclosure.EnclosureNotificationService", category: "notification")
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        // 🔥 CRITICAL DEBUG - Check if extension runs AT ALL
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔥🔥🔥 NOTIFICATION SERVICE EXTENSION STARTED 🔥🔥🔥")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        NSLog("🔥🔥🔥 NOTIFICATION SERVICE EXTENSION STARTED 🔥🔥🔥")
        
        guard let bestAttemptContent = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        let userInfo = bestAttemptContent.userInfo
        logger.notice("didReceive invoked")
        NSLog("🔔 [NotificationService] didReceive invoked")

        if let aps = userInfo["aps"] as? [String: Any] {
            let hasAlert = aps["alert"] != nil
            let mutableContent = (aps["mutable-content"] as? Int) ?? -1
            let category = aps["category"] as? String ?? "nil"
            logger.notice("APS present: alert=\(hasAlert, privacy: .public) mutable-content=\(mutableContent, privacy: .public) category=\(category, privacy: .public)")
            NSLog("🔔 [NotificationService] APS present: alert=\(hasAlert) mutable-content=\(mutableContent) category=\(category)")
        } else {
            logger.notice("APS missing in userInfo")
            NSLog("🔔 [NotificationService] APS missing in userInfo")
        }

        let allKeys = userInfo.keys.map { "\($0)" }.joined(separator: ", ")
        NSLog("🔔 [NotificationService] userInfo keys: \(allKeys)")
        NSLog("🔔 [NotificationService] bodyKey: \(userInfo["bodyKey"] as? String ?? "MISSING")")
        NSLog("🔔 [NotificationService] friendUidKey: \(userInfo["friendUidKey"] as? String ?? "MISSING")")
        NSLog("🔔 [NotificationService] user_nameKey: \(userInfo["user_nameKey"] as? String ?? "MISSING")")
        NSLog("🔔 [NotificationService] msgKey: \(userInfo["msgKey"] as? String ?? "MISSING")")
        NSLog("🔔 [NotificationService] photo: \(userInfo["photo"] as? String ?? "MISSING")")

        let bodyKey = userInfo["bodyKey"] as? String
        guard bodyKey == "chatting" else {
            NSLog("⚠️ [NotificationService] bodyKey != 'chatting' (got: '\(bodyKey ?? "nil")') - skipping")
            contentHandler(bestAttemptContent)
            return
        }

        let directPhoto = userInfo["photo"] as? String
        let nestedData = (userInfo["data"] as? [String: Any])?["photo"] as? String
        let photoUrlString = directPhoto ?? nestedData ?? ""
        let senderUid = stringValue(userInfo["friendUidKey"])
        let senderName = (userInfo["user_nameKey"] as? String)
            ?? (userInfo["name"] as? String)
            ?? "Unknown"
        let message = userInfo["msgKey"] as? String ?? ""

        NSLog("🔔 [NotificationService] Preparing Communication Notification:")
        NSLog("   - senderName: \(senderName)")
        NSLog("   - senderUid: \(senderUid)")
        NSLog("   - message: \(message)")
        NSLog("   - photoUrl: \(photoUrlString.isEmpty ? "MISSING" : photoUrlString)")

        if let url = URL(string: photoUrlString), !photoUrlString.isEmpty {
            let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let profileCacheDir = cachesDir.appendingPathComponent("ProfilePictures", isDirectory: true)
            let cachePath = profileCacheDir.appendingPathComponent("\(senderUid).jpg")

            if FileManager.default.fileExists(atPath: cachePath.path),
               let imageData = try? Data(contentsOf: cachePath),
               let uiImage = UIImage(data: imageData) {
                // Resize image to optimal size for notifications (iOS recommends 100-200px)
                let resizedImage = self.resizeImage(uiImage, to: CGSize(width: 200, height: 200))
                if let jpegData = resizedImage.jpegData(compressionQuality: 0.9) {
                    let personImage = INImage(imageData: jpegData)
                    NSLog("✅ [NotificationService] Loaded profile image from cache (\(jpegData.count) bytes)")
                    updateWithIntent(
                        personImage: personImage,
                        senderName: senderName,
                        senderUid: senderUid,
                        message: message,
                        contentHandler: contentHandler
                    )
                } else {
                    updateWithIntent(
                        personImage: nil,
                        senderName: senderName,
                        senderUid: senderUid,
                        message: message,
                        contentHandler: contentHandler
                    )
                }
            } else {
                URLSession.shared.dataTask(with: url) { data, _, _ in
                    guard let data = data, let image = UIImage(data: data) else {
                        self.updateWithIntent(
                            personImage: nil,
                            senderName: senderName,
                            senderUid: senderUid,
                            message: message,
                            contentHandler: contentHandler
                        )
                        return
                    }

                    // Resize image to optimal size for notifications
                    let resizedImage = self.resizeImage(image, to: CGSize(width: 200, height: 200))
                    try? FileManager.default.createDirectory(at: profileCacheDir, withIntermediateDirectories: true)
                    if let jpegData = resizedImage.jpegData(compressionQuality: 0.9) {
                        try? jpegData.write(to: cachePath, options: .atomic)
                        NSLog("✅ [NotificationService] Cached profile image (\(jpegData.count) bytes)")
                        let personImage = INImage(imageData: jpegData)
                        self.updateWithIntent(
                            personImage: personImage,
                            senderName: senderName,
                            senderUid: senderUid,
                            message: message,
                            contentHandler: contentHandler
                        )
                    } else {
                        self.updateWithIntent(
                            personImage: nil,
                            senderName: senderName,
                            senderUid: senderUid,
                            message: message,
                            contentHandler: contentHandler
                        )
                    }
                }.resume()
                return
            }
        } else {
            // No photo URL provided - show notification without profile picture
            NSLog("⚠️ [NotificationService] No photo URL - showing notification without profile picture")
            updateWithIntent(
                personImage: nil,
                senderName: senderName,
                senderUid: senderUid,
                message: message,
                contentHandler: contentHandler
            )
        }
    }

    private func updateWithIntent(
        personImage: INImage?,
        senderName: String,
        senderUid: String,
        message: String,
        contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        guard let bestAttemptContent = bestAttemptContent else {
            return
        }

        let personHandle = INPersonHandle(value: senderUid, type: .unknown)
        let person: INPerson
        if #available(iOS 15.0, *) {
            person = INPerson(
                personHandle: personHandle,
                nameComponents: nil,
                displayName: senderName,
                image: personImage,
                contactIdentifier: nil,
                customIdentifier: senderUid,
                isMe: false
            )
        } else {
            person = INPerson(
                personHandle: personHandle,
                nameComponents: nil,
                displayName: senderName,
                image: personImage,
                contactIdentifier: nil,
                customIdentifier: senderUid
            )
        }

        let conversationId = senderUid.isEmpty ? "chat" : senderUid
        bestAttemptContent.categoryIdentifier = "CHAT_MESSAGE"
        bestAttemptContent.threadIdentifier = conversationId
        bestAttemptContent.summaryArgument = senderName
        bestAttemptContent.summaryArgumentCount = 1
        
        // Get current badge count from shared UserDefaults (App Group)
        // Extensions cannot access UIApplication.shared, so we use App Group storage
        let sharedDefaults = UserDefaults(suiteName: "group.com.enclosure.data")
        let currentBadge = sharedDefaults?.integer(forKey: "badgeCount") ?? 0
        let newBadge = currentBadge + 1
        
        // Store updated badge count for main app to sync
        sharedDefaults?.set(newBadge, forKey: "badgeCount")
        
        // Set badge in notification content
        bestAttemptContent.badge = NSNumber(value: newBadge)
        NSLog("📱 [NotificationService] Badge updated (App Group): \(currentBadge) -> \(newBadge)")
        let receiverUid = stringValue(bestAttemptContent.userInfo["receiverUidPower"])
            .ifEmpty(stringValue(bestAttemptContent.userInfo["receiverUid"]))
            .ifEmpty("me")
        let recipientHandle = INPersonHandle(value: receiverUid, type: .unknown)
        let recipient: INPerson
        if #available(iOS 15.0, *) {
            recipient = INPerson(
                personHandle: recipientHandle,
                nameComponents: nil,
                displayName: "You",
                image: nil,
                contactIdentifier: nil,
                customIdentifier: receiverUid,
                isMe: true
            )
        } else {
            recipient = INPerson(
                personHandle: recipientHandle,
                nameComponents: nil,
                displayName: "You",
                image: nil,
                contactIdentifier: nil,
                customIdentifier: receiverUid
            )
        }
        let intent = INSendMessageIntent(
            recipients: [recipient],
            content: message,
            speakableGroupName: nil,
            conversationIdentifier: conversationId,
            serviceName: nil,
            sender: person
        )
        NSLog("🔔 [NotificationService] recipientUid: \(receiverUid)")
        NSLog("🔔 [NotificationService] intent.recipients count: \(intent.recipients?.count ?? 0)")

        if #available(iOS 15.0, *) {
            // Update notification content with INSendMessageIntent for WhatsApp-like UI
            // iOS will automatically show:
            // - Circular profile picture on LEFT (from INPerson.image)
            // - Small app icon badge (system handles automatically)
            // - Name and message text
            do {
                let updatedContent = try bestAttemptContent.updating(from: intent)
                NSLog("✅ [NotificationService] Updated notification with INSendMessageIntent")
                NSLog("   - Sender: \(senderName)")
                NSLog("   - Has image: \(personImage != nil)")
                NSLog("   - Message: \(message.prefix(50))")
                
                // Donate intent for Siri suggestions (optional, async)
                let interaction = INInteraction(intent: intent, response: nil)
                interaction.donate { error in
                    if let error = error {
                        NSLog("⚠️ [NotificationService] Intent donate failed: \(error.localizedDescription)")
                    } else {
                        NSLog("✅ [NotificationService] Intent donated successfully")
                    }
                }
                
                contentHandler(updatedContent)
            } catch {
                NSLog("⚠️ [NotificationService] Failed to update from intent: \(error.localizedDescription)")
                NSLog("   Error details: \(error)")
                contentHandler(bestAttemptContent)
            }
        } else {
            NSLog("⚠️ [NotificationService] iOS < 15, using standard notification")
            contentHandler(bestAttemptContent)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            logger.notice("Time will expire - delivering bestAttemptContent")
            NSLog("⏳ [NotificationService] Time will expire - delivering bestAttemptContent")
            contentHandler(bestAttemptContent)
        }
    }

    private func stringValue(_ value: Any?) -> String {
        if let string = value as? String {
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        if let intValue = value as? Int {
            return String(intValue)
        }
        if let doubleValue = value as? Double {
            return String(Int(doubleValue))
        }
        return ""
    }
    
    /// Resize image to optimal size for notification profile pictures
    /// iOS automatically makes it circular, but proper sizing ensures best quality
    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
