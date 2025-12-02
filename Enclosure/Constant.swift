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
    static let chatView = "chatView"
    static let callView = "callView"
    static let videoCallView = "videoCallView"
    static let groupMsgView = "groupMsgView"
    static let messageLmtView = "messageLmtView"
    static let youView = "youView"
    static let profilePic = "profilePic"
    static let full_name = "full_name"
    static let ThemeColorKey = "ThemeColorKey"


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
        let boundingRect = (message as NSString).boundingRect(
            with: CGSize(width: maxLabelWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        let toastHeight = max(50, boundingRect.height + (labelVerticalPadding * 2))
        let toastWidth = min(maxToastWidth, boundingRect.width + (labelHorizontalPadding * 2))
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

        // Message Label (Centered)
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.textColor = UIColor(named: "TextColor")
        messageLabel.textAlignment = .center
        messageLabel.font = font
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        toastView.addSubview(messageLabel)
        window.addSubview(toastView)

        // Constraints for label inside toast
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
