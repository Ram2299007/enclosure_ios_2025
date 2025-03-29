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


    static func showToast(message: String) {
        guard let window = UIApplication.shared.windows.first else { return }

        let toastView = UIView(frame: CGRect(x: 20, y: -60, width: window.frame.width - 40, height: 60))

        // Set background color from asset
        if let cardColor = UIColor(named: "cardBackgroundColornew") {
            toastView.backgroundColor = cardColor
        } else {
            toastView.backgroundColor = UIColor.red // Fallback color
        }

        toastView.alpha = 0
        toastView.layer.cornerRadius = 20
        toastView.layer.shadowColor = UIColor.black.cgColor
        toastView.layer.shadowOpacity = 0.2
        toastView.layer.shadowOffset = CGSize(width: 2, height: 2)

        let messageLabel = UILabel(frame: CGRect(x: 10, y: 10, width: toastView.frame.width - 20, height: 40))
        messageLabel.text = message
        messageLabel.textColor = UIColor(named: "TextColor")
        messageLabel.textAlignment = .center
        messageLabel.font =  UIFont(name: "Inter18pt-Medium", size: 16)

        toastView.addSubview(messageLabel)
        window.addSubview(toastView)

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
