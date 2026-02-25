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
        NSLog("🚨🚨🚨 [NotificationDelegate] ============================================")
        NSLog("🚨 [NotificationDelegate] willPresent notification in FOREGROUND")
        NSLog("🚨🚨🚨 [NotificationDelegate] ============================================")
        print("🚨🚨🚨 [NotificationDelegate] willPresent notification in FOREGROUND")
        
        let userInfo = notification.request.content.userInfo
        let bodyKey = userInfo["bodyKey"] as? String
        
        // CRITICAL: For user-visible notifications, also check the alert body text
        let alertBody = notification.request.content.body
        
        NSLog("📱 [NotificationDelegate] bodyKey: '\(bodyKey ?? "nil")'")
        print("📱 [NotificationDelegate] bodyKey: '\(bodyKey ?? "nil")'")
        NSLog("📱 [NotificationDelegate] alert body: '\(alertBody)'")
        print("📱 [NotificationDelegate] alert body: '\(alertBody)'")
        NSLog("📱 [NotificationDelegate] category: '\(notification.request.content.categoryIdentifier)'")
        print("📱 [NotificationDelegate] category: '\(notification.request.content.categoryIdentifier)'")
        NSLog("📱 [NotificationDelegate] Full userInfo: \(userInfo)")
        print("📱 [NotificationDelegate] Full userInfo: \(userInfo)")
        
        // CRITICAL: Voice/Video call notifications must be forwarded to AppDelegate for CallKit
        // Check THREE ways: bodyKey (data payload), alert body (user-visible), OR category identifier
        let category = notification.request.content.categoryIdentifier
        let isVoiceCall = bodyKey == "Incoming voice call" || alertBody == "Incoming voice call" || category == "VOICE_CALL"
        let isVideoCall = bodyKey == "Incoming video call" || alertBody == "Incoming video call" || category == "VIDEO_CALL"
        
        if isVoiceCall || isVideoCall {
            let callType = isVoiceCall ? "VOICE" : "VIDEO"
            NSLog("🚨🚨🚨 [NotificationDelegate] \(callType) CALL DETECTED IN FOREGROUND!")
            NSLog("📞 [NotificationDelegate] Detected via: bodyKey='\(bodyKey ?? "nil")', alertBody='\(alertBody)', category='\(category)'")
            
            // Check toggle state from shared App Group UserDefaults
            let sharedDefaults = UserDefaults(suiteName: "group.com.enclosure.data")
            let isVoiceCallEnabled = sharedDefaults?.object(forKey: "voiceRadioKey") as? Bool ?? true
            let isVideoCallEnabled = sharedDefaults?.object(forKey: "videoRadioKey") as? Bool ?? true
            
            if isVoiceCall && !isVoiceCallEnabled {
                NSLog("� [NotificationDelegate] Voice call SUPPRESSED - audio call toggle is OFF")
                completionHandler([])
                return
            }
            if isVideoCall && !isVideoCallEnabled {
                NSLog("🔇 [NotificationDelegate] Video call SUPPRESSED - video call toggle is OFF")
                completionHandler([])
                return
            }
            
            NSLog("�📞 [NotificationDelegate] Forwarding to AppDelegate.didReceiveRemoteNotification")
            print("🚨🚨🚨 [NotificationDelegate] \(callType) CALL DETECTED IN FOREGROUND!")
            print("📞 [NotificationDelegate] Detected via: bodyKey='\(bodyKey ?? "nil")', alertBody='\(alertBody)'")
            print("📞 [NotificationDelegate] This is a USER-VISIBLE notification (changed from silent push)")
            
            // CRITICAL: Trigger CallKit IMMEDIATELY (not async) so it shows before iOS displays banner
            NSLog("📞 [NotificationDelegate] Triggering CallKit IMMEDIATELY...")
            print("📞 [NotificationDelegate] Triggering CallKit IMMEDIATELY...")
            
            // Extract call data
            let payloadName = (userInfo["name"] as? String) ?? (userInfo["user_nameKey"] as? String) ?? "Unknown"
            let payloadPhoto = (userInfo["photo"] as? String) ?? ""
            let roomId = (userInfo["roomId"] as? String) ?? ""
            let receiverId = (userInfo["receiverId"] as? String) ?? ""
            let receiverPhone = (userInfo["phone"] as? String) ?? ""
            // Caller's UID (the person calling us)
            let callerUid = (userInfo["uid"] as? String)
                         ?? (userInfo["incoming"] as? String)
                         ?? receiverId

            // Resolve caller name/photo/phone from locally saved contacts
            let savedContact = RecentCallContactStore.shared.getContact(for: callerUid)
            let callerName = (savedContact != nil && !savedContact!.fullName.isEmpty) ? savedContact!.fullName : payloadName
            let callerPhoto = (savedContact != nil && !savedContact!.photo.isEmpty) ? savedContact!.photo : payloadPhoto
            let payloadSenderPhone = (userInfo["senderPhone"] as? String) ?? ""
            let callerPhone = (savedContact != nil && !savedContact!.mobileNo.isEmpty) ? savedContact!.mobileNo : payloadSenderPhone

            VoIPPushManager.shared.registerIncomingCallContext(
                roomId: roomId,
                callerName: callerName,
                callerPhoto: callerPhoto,
                isVideoCall: isVideoCall
            )

            // Start observing for caller-cancel signal (Android parity) even for foreground notification path
            // Voice: removeCallNotification/<myUid>/<pushKey>
            // Video: removeVideoCallNotification/<myUid>/<pushKey>
            if isVideoCall {
                VoIPPushManager.shared.startObservingRemoveVideoCallNotification(roomId: roomId)
            } else {
                VoIPPushManager.shared.startObservingRemoveCallNotification(roomId: roomId)
            }
            
            NSLog("📞 [NotificationDelegate] Call data: caller='\(callerName)', room='\(roomId)'")
            print("📞 [NotificationDelegate] Call data: caller='\(callerName)', room='\(roomId)'")
            
            if !roomId.isEmpty {
                // Report to CallKit SYNCHRONOUSLY
                CallKitManager.shared.reportIncomingCall(
                    callerName: callerName,
                    callerPhoto: callerPhoto,
                    roomId: roomId,
                    callerUid: callerUid,
                    callerPhone: callerPhone,
                    receiverId: receiverId,
                    receiverPhone: receiverPhone,
                    isVideoCall: isVideoCall
                ) { error, callUUID in
                    if let error = error {
                        NSLog("❌ [NotificationDelegate] CallKit error: \(error.localizedDescription)")
                        print("❌ [NotificationDelegate] CallKit error: \(error.localizedDescription)")
                    } else {
                        NSLog("✅ [NotificationDelegate] CallKit call reported successfully!")
                        print("✅ [NotificationDelegate] CallKit call reported successfully!")
                        if let uuid = callUUID {
                            NSLog("✅ [NotificationDelegate] Call UUID: \(uuid.uuidString)")
                        }
                    }
                }
                
                // Set up answer/decline callbacks
                CallKitManager.shared.onAnswerCall = { roomId, receiverId, receiverPhone, isVideoCall in
                    NSLog("📞 [CallKit] User answered call - Room: \(roomId)")
                    print("📞 [CallKit] User answered call - Room: \(roomId)")

                    // Start voice call session immediately (background-safe)
                    if !isVideoCall {
                        ActiveCallManager.shared.startIncomingSession(
                            roomId: roomId, receiverId: receiverId,
                            receiverPhone: receiverPhone, callerName: callerName, callerPhoto: callerPhoto
                        )
                    }
                    // Store pending call for UI presentation
                    if isVideoCall {
                        PendingCallManager.shared.setPendingVideoCall(
                            roomId: roomId, receiverId: receiverId,
                            receiverPhone: receiverPhone, callerName: callerName, callerPhoto: callerPhoto
                        )
                    } else {
                        PendingCallManager.shared.setPendingVoiceCall(
                            roomId: roomId, receiverId: receiverId,
                            receiverPhone: receiverPhone, callerName: callerName, callerPhoto: callerPhoto
                        )
                    }

                    DispatchQueue.main.async {
                        let callData: [String: String] = [
                            "roomId": roomId,
                            "receiverId": receiverId,
                            "receiverPhone": receiverPhone,
                            "callerName": callerName,
                            "callerPhoto": callerPhoto,
                            "isVideoCall": isVideoCall ? "1" : "0"
                        ]
                        NotificationCenter.default.post(
                            name: NSNotification.Name("AnswerIncomingCall"),
                            object: nil,
                            userInfo: callData
                        )
                    }
                }
                
                CallKitManager.shared.onDeclineCall = { roomId in
                    NSLog("📞 [CallKit] User declined call - Room: \(roomId)")
                    print("📞 [CallKit] User declined call - Room: \(roomId)")
                }
            } else {
                NSLog("⚠️ [NotificationDelegate] Missing roomId - cannot trigger CallKit")
                print("⚠️ [NotificationDelegate] Missing roomId - cannot trigger CallKit")
            }
            
            // Don't show banner - CallKit is now showing full-screen UI
            NSLog("📞 [NotificationDelegate] Suppressing banner - CallKit UI active")
            print("📞 [NotificationDelegate] Suppressing banner - CallKit UI active")
            completionHandler([])
            return
        }
        
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
            NSLog("📱 [NotificationDelegate] Other notification - showing banner")
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
        let alertBody = notification.request.content.body
        let category = notification.request.content.categoryIdentifier
        
        // CRITICAL: Check if this is a call notification (from background state)
        let isVoiceCall = bodyKey == "Incoming voice call" || alertBody == "Incoming voice call" || category == "VOICE_CALL"
        let isVideoCall = bodyKey == "Incoming video call" || alertBody == "Incoming video call" || category == "VIDEO_CALL"
        
        if response.actionIdentifier == "REPLY_ACTION",
           let textResponse = response as? UNTextInputNotificationResponse {
            let replyText = textResponse.userText.trimmingCharacters(in: .whitespacesAndNewlines)
            if replyText.isEmpty {
                completionHandler()
                return
            }
            sendReplyFromNotification(userInfo: userInfo, replyText: replyText) { _ in
                let notifId = response.notification.request.identifier
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notifId])
                completionHandler()
            }
            return
        }

        // Handle different action types
        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification
            NSLog("📱 [NotificationDelegate] User tapped notification")
            NSLog("📱 [NotificationDelegate] bodyKey: '\(bodyKey ?? "nil")', category: '\(category)'")
            
            // CRITICAL: Handle CALL notifications tapped from background/lock screen
            if isVoiceCall || isVideoCall {
                let callType = isVoiceCall ? "VOICE" : "VIDEO"
                NSLog("📞📞📞 [NotificationDelegate] \(callType) CALL notification tapped from BACKGROUND!")
                NSLog("📞 [NotificationDelegate] Triggering CallKit NOW...")
                
                // Extract call data
                let payloadNameBg = (userInfo["name"] as? String) ?? (userInfo["user_nameKey"] as? String) ?? "Unknown"
                let payloadPhotoBg = (userInfo["photo"] as? String) ?? ""
                let roomId = (userInfo["roomId"] as? String) ?? ""
                let receiverId = (userInfo["receiverId"] as? String) ?? ""
                let receiverPhone = (userInfo["phone"] as? String) ?? ""
                // Caller's UID (the person calling us)
                let callerUidBg = (userInfo["uid"] as? String)
                             ?? (userInfo["incoming"] as? String)
                             ?? receiverId

                // Resolve caller name/photo/phone from locally saved contacts
                let savedContactBg = RecentCallContactStore.shared.getContact(for: callerUidBg)
                let callerName = (savedContactBg != nil && !savedContactBg!.fullName.isEmpty) ? savedContactBg!.fullName : payloadNameBg
                let callerPhoto = (savedContactBg != nil && !savedContactBg!.photo.isEmpty) ? savedContactBg!.photo : payloadPhotoBg
                let payloadSenderPhoneBg = (userInfo["senderPhone"] as? String) ?? ""
                let callerPhoneBg = (savedContactBg != nil && !savedContactBg!.mobileNo.isEmpty) ? savedContactBg!.mobileNo : payloadSenderPhoneBg
                
                NSLog("📞 [NotificationDelegate] Call data: caller='\(callerName)', room='\(roomId)'")
                
                if !roomId.isEmpty {
                    // Report to CallKit immediately
                    CallKitManager.shared.reportIncomingCall(
                        callerName: callerName,
                        callerPhoto: callerPhoto,
                        roomId: roomId,
                        callerUid: callerUidBg,
                        callerPhone: callerPhoneBg,
                        receiverId: receiverId,
                        receiverPhone: receiverPhone,
                        isVideoCall: isVideoCall
                    ) { error, callUUID in
                        if let error = error {
                            NSLog("❌ [NotificationDelegate] CallKit error: \(error.localizedDescription)")
                        } else {
                            NSLog("✅ [NotificationDelegate] CallKit triggered from background tap!")
                            if let uuid = callUUID {
                                NSLog("✅ [NotificationDelegate] Call UUID: \(uuid.uuidString)")
                            }
                        }
                    }
                    
                    // Set up answer/decline callbacks
                    CallKitManager.shared.onAnswerCall = { roomId, receiverId, receiverPhone, isVideoCall in
                        NSLog("📞 [CallKit] User answered call - Room: \(roomId)")
                        
                        DispatchQueue.main.async {
                            let callData: [String: String] = [
                                "roomId": roomId,
                                "receiverId": receiverId,
                                "receiverPhone": receiverPhone,
                                "callerName": callerName,
                                "callerPhoto": callerPhoto,
                                "isVideoCall": isVideoCall ? "1" : "0"
                            ]
                            NotificationCenter.default.post(
                                name: NSNotification.Name("AnswerIncomingCall"),
                                object: nil,
                                userInfo: callData
                            )
                        }
                    }
                    
                    CallKitManager.shared.onDeclineCall = { roomId in
                        NSLog("📞 [CallKit] User declined call - Room: \(roomId)")
                    }
                } else {
                    NSLog("⚠️ [NotificationDelegate] Missing roomId - cannot trigger CallKit")
                }
                
                completionHandler()
                return
            }
            
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

    private func sendReplyFromNotification(userInfo: [AnyHashable: Any], replyText: String, completion: @escaping (Bool) -> Void) {
        let receiverKey = (userInfo[FirebaseManager.ChatPayloadKey.friendUidKey] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let receiverUidPower = (userInfo[FirebaseManager.ChatPayloadKey.receiverUidPower] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let uidPower = (userInfo[FirebaseManager.ChatPayloadKey.uidPower] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let receiverKeyFallback = receiverKey.isEmpty ? (receiverUidPower.isEmpty ? uidPower : receiverUidPower) : receiverKey
        if receiverKeyFallback.isEmpty {
            NSLog("🚫 [NotificationDelegate] [CHAT_REPLY] Missing receiverKey in userInfo")
            completion(false)
            return
        }

        let uid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        if uid.isEmpty {
            NSLog("🚫 [NotificationDelegate] [CHAT_REPLY] User not logged in")
            completion(false)
            return
        }

        let userFTokenKey = UserDefaults.standard.string(forKey: Constant.FCM_TOKEN) ?? FirebaseManager.shared.fcmToken ?? ""
        let userNamePower = UserDefaults.standard.string(forKey: Constant.full_name) ?? ""

        let replyKeyPower = userInfo[FirebaseManager.ChatPayloadKey.replyKeyPower] as? String
        let replyTypePower = userInfo[FirebaseManager.ChatPayloadKey.replyTypePower] as? String
        let replyOldDataPower = userInfo[FirebaseManager.ChatPayloadKey.replyOldDataPower] as? String
        let replyCrtPostionPower = userInfo[FirebaseManager.ChatPayloadKey.replyCrtPostionPower] as? String
        let modelIdPower = userInfo[FirebaseManager.ChatPayloadKey.modelIdPower] as? String
        let messagePower = userInfo[FirebaseManager.ChatPayloadKey.messagePower] as? String

        let timeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "hh:mm a"
            f.locale = Locale(identifier: "en_US_POSIX")
            return f
        }()
        let dateFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.locale = Locale(identifier: "en_US_POSIX")
            return f
        }()
        let now = Date()
        let currentTimeString = timeFormatter.string(from: now)
        let currentDateString = dateFormatter.string(from: now)
        let modelId = UUID().uuidString

        let replyModel = ChatMessage(
            id: modelId,
            uid: uid,
            message: replyText,
            time: currentTimeString,
            document: "",
            dataType: Constant.Text,
            fileExtension: nil,
            name: nil,
            phone: nil,
            micPhoto: nil,
            miceTiming: nil,
            userName: userNamePower.isEmpty ? nil : userNamePower,
            receiverId: receiverKeyFallback,
            replytextData: messagePower,
            replyKey: replyKeyPower ?? "ReplyKey",
            replyType: replyTypePower ?? Constant.Text,
            replyOldData: replyOldDataPower ?? messagePower,
            replyCrtPostion: replyCrtPostionPower ?? modelIdPower,
            forwaredKey: nil,
            groupName: nil,
            docSize: nil,
            fileName: nil,
            thumbnail: nil,
            fileNameThumbnail: nil,
            caption: nil,
            notification: 1,
            currentDate: currentDateString,
            emojiModel: nil,
            emojiCount: nil,
            timestamp: Date().timeIntervalSince1970,
            imageWidth: nil,
            imageHeight: nil,
            aspectRatio: nil,
            selectionCount: "1",
            selectionBunch: nil,
            receiverLoader: 0,
            linkTitle: nil,
            linkDescription: nil,
            linkImageUrl: nil,
            favIconUrl: nil
        )

        let bgTaskId = UIApplication.shared.beginBackgroundTask(withName: "chat_notification_reply")
        MessageUploadService.shared.uploadMessage(
            model: replyModel,
            filePath: nil,
            userFTokenKey: userFTokenKey,
            deviceType: nil
        ) { success, message in
            if bgTaskId != .invalid {
                UIApplication.shared.endBackgroundTask(bgTaskId)
            }
            if success {
                NSLog("✅ [NotificationDelegate] [CHAT_REPLY] Reply sent")
                completion(true)
            } else {
                NSLog("🚫 [NotificationDelegate] [CHAT_REPLY] Reply failed: \(message)")
                completion(false)
            }
        }
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
