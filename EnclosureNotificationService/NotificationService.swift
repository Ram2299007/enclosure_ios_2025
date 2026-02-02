import Foundation
import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let bestAttemptContent = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        let userInfo = bestAttemptContent.userInfo
        let directPhoto = userInfo["photo"] as? String
        let nestedData = (userInfo["data"] as? [String: Any])?["photo"] as? String
        let photoUrlString = directPhoto ?? nestedData ?? ""

        NSLog("🔔 [NotificationService] userInfo keys: \(userInfo.keys)")
        NSLog("🔔 [NotificationService] photo URL: \(photoUrlString)")

        guard let url = URL(string: photoUrlString), !photoUrlString.isEmpty else {
            contentHandler(bestAttemptContent)
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, _, _ in
            defer { contentHandler(bestAttemptContent) }
            guard let data = data else { return }

            let tmp = FileManager.default.temporaryDirectory
            let fileURL = tmp.appendingPathComponent("chat_profile_\(UUID().uuidString).jpg")
            do {
                try data.write(to: fileURL)
                let attachment = try UNNotificationAttachment(identifier: "profile", url: fileURL, options: nil)
                bestAttemptContent.attachments = [attachment]
            } catch {
                NSLog("🔔 [NotificationService] Failed to attach image: \(error)")
            }
        }
        task.resume()
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
