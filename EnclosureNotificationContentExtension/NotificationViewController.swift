import UIKit
import UserNotifications
import UserNotificationsUI

final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private let profileImageView = UIImageView()
    private let appIconImageView = UIImageView()
    private let nameLabel = UILabel()
    private let messageLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    func didReceive(_ notification: UNNotification) {
        let content = notification.request.content
        nameLabel.text = content.title
        messageLabel.text = content.body

        // Check if this is a chat notification (bodyKey == "chatting")
        let isChatNotification = (content.userInfo["bodyKey"] as? String) == "chatting"
        
        // For chat notifications: completely hide app icon, show profile picture on left (WhatsApp-style)
        if isChatNotification {
            appIconImageView.isHidden = true
            profileImageView.isHidden = false // Always show profile image for chat notifications
            
            // Load profile image for chat notifications
            loadProfileImage(from: content)
        } else {
            // For non-chat notifications: show app icon, hide profile image
            appIconImageView.isHidden = false
            profileImageView.isHidden = true
        }
    }
    
    private func loadProfileImage(from content: UNNotificationContent) {
        // Prefer Service Extension attachment (profile image downloaded by NotificationService)
        if let attachment = content.attachments.first,
           attachment.url.startAccessingSecurityScopedResource() {
            defer { attachment.url.stopAccessingSecurityScopedResource() }
            if let data = try? Data(contentsOf: attachment.url),
               let image = UIImage(data: data) {
                DispatchQueue.main.async { [weak self] in
                    self?.profileImageView.image = image
                    self?.profileImageView.isHidden = false
                }
                return
            }
        }
        
        // Fallback: load from payload photo URL (if attachment not present)
        if let photoUrl = (content.userInfo["photo"] as? String),
           !photoUrl.isEmpty,
           let url = URL(string: photoUrl) {
            URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                guard let data = data, error == nil,
                      let image = UIImage(data: data) else {
                    // If image fails to load, still show the profile image view with placeholder
                    DispatchQueue.main.async {
                        self?.profileImageView.isHidden = false
                    }
                    return
                }
                DispatchQueue.main.async {
                    self?.profileImageView.image = image
                    self?.profileImageView.isHidden = false
                }
            }.resume()
        } else {
            // No photo URL available - show placeholder (background color will be visible)
            profileImageView.isHidden = false
        }
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        // Profile image - circular, WhatsApp-style on the LEFT side (replaces app logo)
        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        profileImageView.contentMode = .scaleAspectFill
        profileImageView.clipsToBounds = true
        profileImageView.layer.cornerRadius = 26 // Makes it perfectly circular for 52x52 size
        profileImageView.backgroundColor = UIColor(white: 0.9, alpha: 1.0) // Placeholder color
        profileImageView.isHidden = true // Will be shown when chat notification arrives

        // App icon - completely hidden for chat notifications (only shown for non-chat notifications)
        appIconImageView.translatesAutoresizingMaskIntoConstraints = false
        appIconImageView.contentMode = .scaleAspectFill
        appIconImageView.clipsToBounds = true
        appIconImageView.layer.cornerRadius = 8
        appIconImageView.layer.borderWidth = 1
        appIconImageView.layer.borderColor = UIColor.white.cgColor
        appIconImageView.image = UIImage(named: "Group 8791-2") ?? UIImage(systemName: "app.fill")
        appIconImageView.isHidden = true // Hidden by default, shown only for non-chat notifications

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        nameLabel.textColor = .label

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        messageLabel.textColor = .secondaryLabel
        messageLabel.numberOfLines = 2

        view.addSubview(profileImageView)
        view.addSubview(appIconImageView)
        view.addSubview(nameLabel)
        view.addSubview(messageLabel)

        NSLayoutConstraint.activate([
            // Profile image on LEFT side (WhatsApp-style) - replaces app logo
            profileImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            profileImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            profileImageView.widthAnchor.constraint(equalToConstant: 52),
            profileImageView.heightAnchor.constraint(equalToConstant: 52),

            // App icon badge (only for non-chat notifications) - positioned as small badge
            appIconImageView.widthAnchor.constraint(equalToConstant: 16),
            appIconImageView.heightAnchor.constraint(equalToConstant: 16),
            appIconImageView.bottomAnchor.constraint(equalTo: profileImageView.bottomAnchor, constant: 2),
            appIconImageView.trailingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: 2),

            // Name label - positioned to the right of profile image
            nameLabel.leadingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            nameLabel.topAnchor.constraint(equalTo: profileImageView.topAnchor, constant: 2),

            // Message label - below name label
            messageLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            messageLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4)
        ])
    }
}
