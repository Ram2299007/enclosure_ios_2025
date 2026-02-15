//
//  Constant.swift
//  Enclosure
//
//  Created by Ram Lohar on 18/03/25.
//

import Foundation
import SwiftUI

struct Constant{

    static let baseURL = "https://confidential.enclosureapp.com/"
    static let PHONE_NUMBERKEY = "PHONE_NUMBER"
    static let UID_KEY = "UID_KEY"
    static let c_id = "c_id"
    static let country_Code = "country_Code"
    static let FCM_TOKEN = "FCM_TOKEN"
    static let loggedInKey = "loggedInKey"
    static let sleepKey = "sleepKey"
    static let sleepKeyCheckOFF = "sleepKeyCheckOFF"
    static let voiceRadioKey = "voiceRadioKey"
    static let videoRadioKey = "videoRadioKey"
    static let chatView = "chatView"
    static let callView = "callView"
    static let videoCallView = "videoCallView"
    static let groupMsgView = "groupMsgView"
    static let messageLmtView = "messageLmtView"
    static let youView = "youView"
    static let profilePic = "profilePic"
    static let full_name = "full_name"
    static let ThemeColorKey = "ThemeColorKey"
    static let DEVICE_TYPE_KEY = "DEVICE_TYPE_KEY"
    
    // Firebase constants (matching Android Constant.java)
    static let CHAT = "chats"
    static let GROUPCHAT = "group_chats"
    static let chattingSocket = "chattingSocket"
    static let chatting = "chatting"
    
    // Data type constants (matching Android)
    static let Text = "Text"
    static let img = "img"
    static let video = "video"
    static let doc = "doc"
    static let contact = "contact"
    static let voiceAudio = "voiceAudio"
    static let camera = "camera"
    static let TYPEINDICATOR = "typingIndicator"
    static let incomingVoiceCall = "Incoming voice call"
    static let incomingVideoCall = "Incoming video call"

    /// Current user device type from API (get_profile / verify_otp). "2" = iOS, "1" = Android. Fallback "2" if not yet fetched.
    static var deviceType: String {
        UserDefaults.standard.string(forKey: Constant.DEVICE_TYPE_KEY) ?? "2"
    }

    static var SenderIdMy: String {
        return UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? "0"
    }

    // Get theme color dynamically from UserDefaults
    static var themeColor: String {
        return UserDefaults.standard.string(forKey: Constant.ThemeColorKey) ?? "#00A3E9"
    }




    static func showToast(message: String) {
        guard let window = UIApplication.shared.windows.first else { return }

        let horizontalMargin: CGFloat = 20
        let maxToastWidth: CGFloat = window.frame.width - (horizontalMargin * 2)
        let bottomMargin: CGFloat = 30
        let font = UIFont(name: "Inter18pt-Medium", size: 16) ?? UIFont.systemFont(ofSize: 16, weight: .medium)
        let labelHorizontalPadding: CGFloat = 20
        let labelVerticalPadding: CGFloat = 14
        let maxLabelWidth = maxToastWidth - (labelHorizontalPadding * 2)
        
        // Calculate text size with wrap content (matching Android wrap_content)
        let boundingRect = (message as NSString).boundingRect(
            with: CGSize(width: maxLabelWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        
        // Calculate toast dimensions with wrap content
        // Height: wrap content based on text height
        let toastHeight = max(50, boundingRect.height + (labelVerticalPadding * 2))
        
        // Width: wrap content - use text width for short messages, max width for long messages
        // If text width is less than maxLabelWidth, use text width + padding (wrap content)
        // If text wraps (width equals maxLabelWidth), use maxToastWidth
        let textWidth = boundingRect.width
        let toastWidth: CGFloat
        if textWidth < maxLabelWidth {
            // Short message - wrap content to text width
            toastWidth = min(maxToastWidth, textWidth + (labelHorizontalPadding * 2))
        } else {
            // Long message that wraps - use full available width
            toastWidth = maxToastWidth
        }
        
        let originX = (window.frame.width - toastWidth) / 2

        let safeAreaBottom = window.safeAreaInsets.bottom
        let toastY = window.frame.height - safeAreaBottom - toastHeight - bottomMargin

        let toastView = UIView(frame: CGRect(x: originX,
                                             y: toastY,
                                             width: toastWidth,
                                             height: toastHeight))

        // Set background color from asset
        toastView.backgroundColor = UIColor(named: "cardBackgroundColornew") ?? UIColor.red // Fallback color
        toastView.alpha = 0
        toastView.layer.cornerRadius = 25
        toastView.layer.shadowColor = UIColor.black.cgColor
        toastView.layer.shadowOpacity = 0.1
        toastView.layer.shadowOffset = CGSize(width: 2, height: 2)

        // Message Label (Centered) - with wrap content
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.textColor = UIColor(named: "TextColor")
        messageLabel.textAlignment = .center
        messageLabel.font = font
        messageLabel.numberOfLines = 0 // Allow multiple lines (wrap content)
        messageLabel.lineBreakMode = .byWordWrapping // Wrap by words
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        toastView.addSubview(messageLabel)
        window.addSubview(toastView)

        // Constraints for label inside toast - wrap content
        NSLayoutConstraint.activate([
            messageLabel.leadingAnchor.constraint(equalTo: toastView.leadingAnchor, constant: labelHorizontalPadding),
            messageLabel.trailingAnchor.constraint(equalTo: toastView.trailingAnchor, constant: -labelHorizontalPadding),
            messageLabel.topAnchor.constraint(equalTo: toastView.topAnchor, constant: labelVerticalPadding),
            messageLabel.bottomAnchor.constraint(equalTo: toastView.bottomAnchor, constant: -labelVerticalPadding),
            messageLabel.centerYAnchor.constraint(equalTo: toastView.centerYAnchor)
        ])

        // Animate fade-in
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
            toastView.alpha = 1
        }) { _ in
            // Auto-dismiss with fade-out
            UIView.animate(withDuration: 0.3, delay: 2.0, options: .curveEaseInOut, animations: {
                toastView.alpha = 0
            }) { _ in
                toastView.removeFromSuperview()
            }
        }
    }








    



        
}
