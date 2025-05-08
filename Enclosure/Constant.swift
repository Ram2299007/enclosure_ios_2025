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


    static var SenderIdMy: String {
        return UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? "0"
    }




    static func showToast(message: String) {
        guard let window = UIApplication.shared.windows.first else { return }

        let toastHeight: CGFloat = 50
        let padding: CGFloat = 12
        let logoSize: CGFloat = 20
        let toastWidth: CGFloat = window.frame.width - 80 // Adjust width for better centering

        // Center toast horizontally
        let toastView = UIView(frame: CGRect(x: (window.frame.width - toastWidth) / 2,
                                             y: -toastHeight,
                                             width: toastWidth,
                                             height: toastHeight))

        // Set background color from asset
        toastView.backgroundColor = UIColor(named: "cardBackgroundColornew") ?? UIColor.red // Fallback color
        toastView.alpha = 0
        toastView.layer.cornerRadius = 25
        toastView.layer.shadowColor = UIColor.black.cgColor
        toastView.layer.shadowOpacity = 0.1
        toastView.layer.shadowOffset = CGSize(width: 2, height: 2)

        // Logo ImageView (Aligned Left with 5px Left Margin)
        let logoImageView = UIImageView()
        logoImageView.image = UIImage(named: "ec_modern") // Replace with your asset name
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.widthAnchor.constraint(equalToConstant: logoSize).isActive = true
        logoImageView.heightAnchor.constraint(equalToConstant: logoSize).isActive = true

        // Message Label (Centered)
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.textColor = UIColor(named: "TextColor")
        messageLabel.textAlignment = .center
        messageLabel.font = UIFont(name: "Inter18pt-Medium", size: 16)
        messageLabel.numberOfLines = 1
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        // Container StackView for positioning
        let containerStackView = UIStackView()
        containerStackView.axis = .horizontal
        containerStackView.alignment = .center
        containerStackView.spacing = 8
        containerStackView.distribution = .fill
        containerStackView.translatesAutoresizingMaskIntoConstraints = false

        // Add logo first, then message
        containerStackView.addArrangedSubview(logoImageView)
        containerStackView.addArrangedSubview(messageLabel)

        toastView.addSubview(containerStackView)
        window.addSubview(toastView)

        // Constraints for StackView inside toast
        NSLayoutConstraint.activate([
            containerStackView.leadingAnchor.constraint(equalTo: toastView.leadingAnchor, constant: padding + 5), // 5px margin left for logo
            containerStackView.trailingAnchor.constraint(equalTo: toastView.trailingAnchor, constant: -padding),
            containerStackView.centerYAnchor.constraint(equalTo: toastView.centerYAnchor),

            // Ensure messageLabel takes available space
            messageLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ])

        // Animate slide down
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 1, options: .curveEaseOut, animations: {
            toastView.frame.origin.y = 50
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
