//
//  VoIPPushManager.swift
//  Enclosure
//
//  Created for handling VoIP Push Notifications (PushKit)
//  This enables WhatsApp-style instant CallKit in background/lock screen
//

import Foundation
import PushKit
import CallKit
import UIKit
import AVFoundation
import FirebaseDatabase
import UserNotifications
import os.log

class VoIPPushManager: NSObject {
    static let shared = VoIPPushManager()
    
    private let pushRegistry = PKPushRegistry(queue: .main)
    private var voipToken: String?

    private var removeCallObserverHandle: DatabaseHandle?
    private var removeCallObserverPath: String?
    private var callAnswered = false

    private struct PendingCallContext {
        let callerName: String
        let callerPhoto: String
        let isVideoCall: Bool
    }
    private var pendingCallContextByRoomId: [String: PendingCallContext] = [:]
    
    // Completion handler for token updates
    var onVoIPTokenReceived: ((String) -> Void)?
    
    override init() {
        super.init()
        NSLog("📞 [VoIP] VoIPPushManager initializing...")
        print("📞 [VoIP] VoIPPushManager initializing...")
    }
    
    func start() {
        NSLog("📞 [VoIP] ========================================")
        NSLog("📞 [VoIP] Starting VoIP Push Registration")
        NSLog("📞 [VoIP] ========================================")
        
        print("📞 [VoIP] Starting VoIP Push Registration")
        
        configure()
        
        NSLog("📞 [VoIP] PushKit registry configured for VoIP")
        print("📞 [VoIP] PushKit registry configured")
    }
    
    func configure() {
        pushRegistry.delegate = self
        pushRegistry.desiredPushTypes = [.voIP]
    }
    
    func getVoIPToken() -> String? {
        return voipToken
    }
}

extension VoIPPushManager {
    func registerIncomingCallContext(roomId: String, callerName: String, callerPhoto: String, isVideoCall: Bool) {
        let trimmedRoomId = roomId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRoomId.isEmpty else { return }
        pendingCallContextByRoomId[trimmedRoomId] = PendingCallContext(
            callerName: callerName,
            callerPhoto: callerPhoto,
            isVideoCall: isVideoCall
        )
    }

    func clearIncomingCallContext(roomId: String) {
        let trimmedRoomId = roomId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRoomId.isEmpty else { return }
        pendingCallContextByRoomId.removeValue(forKey: trimmedRoomId)
    }

    func showMissedCallNotificationIfPossible(roomId: String) {
        let trimmedRoomId = roomId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRoomId.isEmpty else { return }
        guard let ctx = pendingCallContextByRoomId[trimmedRoomId] else { return }

        if #available(iOS 15.0, *) {
            CommunicationNotificationManager.shared.createMissedCallCommunicationNotification(
                callerName: ctx.callerName,
                callerPhotoUrl: ctx.callerPhoto,
                roomId: trimmedRoomId,
                isVideoCall: ctx.isVideoCall
            ) { success in
                if success {
                    NSLog("✅ [VoIP] Missed call notification scheduled (INSendMessageIntent-style). roomId=\(trimmedRoomId)")
                } else {
                    NSLog("⚠️ [VoIP] Missed call Communication Notification failed, using fallback")
                    self.showMissedCallNotificationFallback(roomId: trimmedRoomId, ctx: ctx)
                }
            }
        } else {
            showMissedCallNotificationFallback(roomId: trimmedRoomId, ctx: ctx)
        }
    }

    /// Fallback: plain notification when iOS < 15 or when Communication Notification fails
    private func showMissedCallNotificationFallback(roomId: String, ctx: PendingCallContext) {
        let content = UNMutableNotificationContent()
        content.title = ctx.callerName
        content.body = ctx.isVideoCall ? "☎️ Missed video call" : "☎️ Missed voice call"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "missed_call_\(roomId)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                NSLog("⚠️ [VoIP] Failed to schedule missed call notification: \(error.localizedDescription)")
            } else {
                NSLog("✅ [VoIP] Missed call notification scheduled. roomId=\(roomId)")
            }
        }
    }
}

// MARK: - PKPushRegistryDelegate
extension VoIPPushManager: PKPushRegistryDelegate {
    
    /// Called when VoIP push token is received or updated
    func pushRegistry(_ registry: PKPushRegistry, 
                     didUpdate pushCredentials: PKPushCredentials, 
                     for type: PKPushType) {
        guard type == .voIP else {
            NSLog("⚠️ [VoIP] Received credentials for non-VoIP type: \(type)")
            return
        }
        
        // Convert token data to hex string
        let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        voipToken = token
        
        NSLog("📞📞📞 [VoIP] ========================================")
        NSLog("📞 [VoIP] VoIP PUSH TOKEN RECEIVED!")
        NSLog("📞 [VoIP] ========================================")
        NSLog("📞 [VoIP] Token: \(token)")
        NSLog("📞 [VoIP] Token Length: \(token.count) characters")
        NSLog("📞 [VoIP] ========================================")
        NSLog("📞 [VoIP] IMPORTANT: Send this token to your backend!")
        NSLog("📞 [VoIP] Store it separately from FCM token")
        NSLog("📞 [VoIP] Backend must send VoIP pushes to APNs directly")
        NSLog("📞 [VoIP] ========================================")
        
        print("📞📞📞 [VoIP] VoIP Token: \(token)")
        
        // Save to UserDefaults for easy access
        UserDefaults.standard.set(token, forKey: "voipPushToken")
        UserDefaults.standard.synchronize()
        
        // Notify callback
        onVoIPTokenReceived?(token)
        
        // TODO: Send to your backend API
        // Example: sendVoIPTokenToBackend(token)
    }
    
    /// Called when VoIP push is received - THIS IS WHERE THE MAGIC HAPPENS!
    func pushRegistry(_ registry: PKPushRegistry, 
                     didReceiveIncomingPushWith payload: PKPushPayload, 
                     for type: PKPushType, 
                     completion: @escaping () -> Void) {
        guard type == .voIP else {
            NSLog("⚠️ [VoIP] Received push for non-VoIP type: \(type)")
            completion()
            return
        }
        
        CallLogger.log("======== INCOMING VOIP PUSH RECEIVED! ========", category: .voip)
        CallLogger.log("App State: \(UIApplication.shared.applicationState.rawValue) (0=active, 1=inactive, 2=background)", category: .voip)
        NSLog("📞📞📞 [VoIP] ========================================")
        NSLog("📞 [VoIP] INCOMING VOIP PUSH RECEIVED!")
        NSLog("📞 [VoIP] App State: \(UIApplication.shared.applicationState.rawValue) (0=active, 1=inactive, 2=background)")
        NSLog("📞 [VoIP] ========================================")
        
        print("📞📞📞 [VoIP] INCOMING VOIP PUSH!")
        
        let userInfo = payload.dictionaryPayload
        
        CallLogger.log("Full Payload: \(userInfo)", category: .voip)
        NSLog("📞 [VoIP] Full Payload: \(userInfo)")
        print("📞 [VoIP] Payload: \(userInfo)")
        
        // Extract call data from payload
        let payloadName = (userInfo["name"] as? String) 
                      ?? (userInfo["user_nameKey"] as? String) 
                      ?? "Unknown Caller"
        let payloadPhoto = (userInfo["photo"] as? String) ?? ""
        let roomId = (userInfo["roomId"] as? String) ?? ""
        let receiverId = (userInfo["receiverId"] as? String) ?? ""
        let receiverPhone = (userInfo["phone"] as? String) ?? ""
        let bodyKey = (userInfo["bodyKey"] as? String) ?? ""
        let payloadSenderPhone = (userInfo["senderPhone"] as? String) ?? ""
        // Caller's UID (the person calling us)
        let callerUid = (userInfo["uid"] as? String)
                     ?? (userInfo["incoming"] as? String)
                     ?? receiverId
        
        // Resolve caller name/photo/phone from locally saved contacts
        let savedContact = RecentCallContactStore.shared.getContact(for: callerUid)
        let callerName = (savedContact != nil && !savedContact!.fullName.isEmpty) ? savedContact!.fullName : payloadName
        let callerPhoto = (savedContact != nil && !savedContact!.photo.isEmpty) ? savedContact!.photo : payloadPhoto
        // Caller's phone number for CXHandle — native Phone app uses this to match iOS Contacts
        let callerPhone = (savedContact != nil && !savedContact!.mobileNo.isEmpty) ? savedContact!.mobileNo : payloadSenderPhone
        
        CallLogger.log("Caller: \(callerName), Room: \(roomId), BodyKey: \(bodyKey)", category: .voip)
        NSLog("📞 [VoIP] Extracted Data:")
        NSLog("📞 [VoIP]   Caller UID: \(callerUid)")
        NSLog("📞 [VoIP]   Caller Name: \(callerName) (payload: \(payloadName))")
        NSLog("📞 [VoIP]   Room ID: \(roomId)")
        NSLog("📞 [VoIP]   Receiver ID: \(receiverId)")
        NSLog("📞 [VoIP]   Body Key: '\(bodyKey)'")
        
        print("📞 [VoIP] Call from: \(callerName)")
        print("📞 [VoIP] Room: \(roomId)")
        print("📞 [VoIP] Body Key: '\(bodyKey)'")
        
        // Validate required data
        guard !roomId.isEmpty else {
            NSLog("❌ [VoIP] ERROR: Missing roomId in VoIP push payload")
            NSLog("❌ [VoIP] Cannot process call without roomId")
            print("❌ [VoIP] Missing roomId!")
            completion()
            return
        }
        
        // Determine if voice or video call
        // Check specifically for "video" in bodyKey
        // Voice call: "Incoming voice call"
        // Video call: "Incoming video call"
        let isVideoCall = bodyKey.lowercased().contains("video")
        let callType = isVideoCall ? "VIDEO" : "VOICE"
        CallLogger.log("Detected Call Type: \(callType) (bodyKey='\(bodyKey)')", category: .voip)
        NSLog("📞 [VoIP] Body Key: '\(bodyKey)' → Detected Call Type: \(callType)")
        print("📞 [VoIP] Call Type: \(callType)")
        
        // Check toggle state from shared App Group UserDefaults
        let sharedDefaults = UserDefaults(suiteName: "group.com.enclosure.data")
        let isVoiceCallEnabled = sharedDefaults?.object(forKey: "voiceRadioKey") as? Bool ?? true
        let isVideoCallEnabled = sharedDefaults?.object(forKey: "videoRadioKey") as? Bool ?? true
        
        if !isVideoCall && !isVoiceCallEnabled {
            NSLog("🔇 [VoIP] Voice call SUPPRESSED - audio call toggle is OFF")
            completion()
            return
        }
        if isVideoCall && !isVideoCallEnabled {
            NSLog("🔇 [VoIP] Video call SUPPRESSED - video call toggle is OFF")
            completion()
            return
        }

        registerIncomingCallContext(roomId: roomId, callerName: callerName, callerPhoto: callerPhoto, isVideoCall: isVideoCall)

        // Persist caller info for callback from native Phone app Recents.
        // Use callerUid (the caller's UID) as friendId so we can look them up later.
        // fToken/voipToken/deviceType are unavailable here — they'll be populated
        // when call logs are loaded later via merge.
        RecentCallContactStore.shared.saveFromOutgoingCall(
            friendId: callerUid,
            fullName: callerName,
            photo: callerPhoto,
            fToken: "",
            voipToken: "",
            deviceType: "",
            mobileNo: callerPhone,
            isVideoCall: isVideoCall
        )

        // Start observing for caller-cancel signal (Android parity)
        // Voice: removeCallNotification/<myUid>/<pushKey>
        // Video: removeVideoCallNotification/<myUid>/<pushKey>
        if isVideoCall {
            startObservingRemoveVideoCallNotification(roomId: roomId)
        } else {
            startObservingRemoveCallNotification(roomId: roomId)
        }
        
        // CRITICAL: Pre-configure audio session BEFORE reporting to CallKit.
        // On cold start (app killed), AVAudioSession defaults to SoloAmbientSound.
        // When callservicesd creates a proxy session, it inherits this category and fails:
        //   "not allowed to play because it is a lock stopper"
        //   "insufficient privileges to take control"
        // Setting PlayAndRecord early fixes this. CallKit's didActivate will finalize.
        if !isVideoCall {
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .allowBluetoothA2DP])
                CallLogger.success("Pre-configured audio: PlayAndRecord + voiceChat", category: .audio)
                NSLog("✅ [VoIP] Pre-configured audio session for voice call")
            } catch {
                CallLogger.error("Audio pre-config failed: \(error.localizedDescription)", category: .audio)
                NSLog("⚠️ [VoIP] Audio pre-config failed: \(error.localizedDescription)")
            }
        }
        
        CallLogger.log("Reporting \(callType) call to CallKit NOW...", category: .voip)
        NSLog("📞 [VoIP] Reporting call to CallKit NOW...")
        print("📞 [VoIP] Triggering CallKit...")
        
        // Report to CallKit IMMEDIATELY
        // This will show the CallKit full-screen UI instantly, even in background!
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
                CallLogger.error("CallKit Error: \(error.localizedDescription)", category: .voip)
                NSLog("❌ [VoIP] CallKit Error: \(error.localizedDescription)")
                print("❌ [VoIP] CallKit error: \(error.localizedDescription)")
            } else {
                CallLogger.success("CallKit call reported! Caller=\(callerName), Room=\(roomId)", category: .voip)
                NSLog("✅✅✅ [VoIP] CallKit call reported successfully!")
                NSLog("✅ [VoIP] User should now see full-screen CallKit UI")
                NSLog("✅ [VoIP] This works in FOREGROUND, BACKGROUND, and LOCK SCREEN!")
                NSLog("✅ [VoIP] Video button visible - tap it to trigger unlock")
                print("✅✅✅ [VoIP] CallKit triggered successfully!")
            }
            
            // CRITICAL: Must call completion handler
            // iOS will terminate app if not called within 30 seconds
            completion()
        }
        
        // Set up answer callback
        callAnswered = false
        CallKitManager.shared.onAnswerCall = { roomId, receiverId, receiverPhone, isVideoCall in
            NSLog("📞📞📞 [VoIP] ========================================")
            NSLog("📞 [VoIP] User ANSWERED call!")
            NSLog("📞 [VoIP] Room: \(roomId)")
            NSLog("📞 [VoIP] App State: \(UIApplication.shared.applicationState.rawValue) (0=active, 1=inactive, 2=background)")
            NSLog("📞 [VoIP] ========================================")
            print("📞📞📞 [VoIP] CALL ANSWERED!")
            print("📞 [VoIP] Room: \(roomId)")

            self.callAnswered = true

            // Stop observing cancel signal once user answered
            self.stopObservingRemoveCallNotification()
            self.clearIncomingCallContext(roomId: roomId)

            // Start WebRTC session IMMEDIATELY for BOTH voice and video calls.
            // Audio/video connects in background BEFORE UI appears (like WhatsApp).
            // Call screens will attach to the already-running session.
            if isVideoCall {
                ActiveCallManager.shared.startIncomingVideoSession(
                    roomId: roomId, receiverId: receiverId,
                    receiverPhone: receiverPhone, callerName: callerName, callerPhoto: callerPhoto
                )
                PendingCallManager.shared.setPendingVideoCall(
                    roomId: roomId, receiverId: receiverId,
                    receiverPhone: receiverPhone, callerName: callerName, callerPhoto: callerPhoto
                )
            } else {
                ActiveCallManager.shared.startIncomingSession(
                    roomId: roomId, receiverId: receiverId,
                    receiverPhone: receiverPhone, callerName: callerName, callerPhoto: callerPhoto
                )
                PendingCallManager.shared.setPendingVoiceCall(
                    roomId: roomId, receiverId: receiverId,
                    receiverPhone: receiverPhone, callerName: callerName, callerPhoto: callerPhoto
                )
            }
            
            // Request app to come to foreground if on lock screen
            // This will prompt iOS to show unlock (Face ID/Touch ID/Passcode)
            let appState = UIApplication.shared.applicationState
            
            if appState == .background || appState == .inactive {
                NSLog("🔓 [VoIP] Lock screen detected - requesting app activation")
                print("🔓 [VoIP] Requesting unlock prompt...")
                
                // Request the app to come to foreground
                // iOS will show Face ID/Touch ID prompt naturally
                // hasVideo = true in CallKit will also trigger unlock
                DispatchQueue.main.async {
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                        NSLog("🔓 [VoIP] Requesting scene activation for unlock")
                        UIApplication.shared.requestSceneSessionActivation(
                            scene.session,
                            userActivity: nil,
                            options: nil,
                            errorHandler: { error in
                                NSLog("⚠️ [VoIP] Scene activation error: \(error.localizedDescription)")
                                NSLog("✅ [VoIP] Fallback: hasVideo=true will trigger unlock")
                            }
                        )
                    } else {
                        NSLog("✅ [VoIP] No multi-scene support - hasVideo=true will trigger unlock")
                    }
                }
            }
            
            // Minimal delay to let iOS prepare for unlock/foreground transition
            let delay: TimeInterval = (appState == .background || appState == .inactive) ? 0.5 : 0.1
            
            NSLog("📞 [VoIP] Posting call notification (delay: \(delay)s)")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                NSLog("📞📞📞 [VoIP] ⏰ DELAY COMPLETE - Posting notification NOW")
                print("📞📞📞 [VoIP] ⏰ Posting AnswerIncomingCall notification")
                
                let callData: [String: String] = [
                    "roomId": roomId,
                    "receiverId": receiverId,
                    "receiverPhone": receiverPhone,
                    "callerName": callerName,
                    "callerPhoto": callerPhoto,
                    "isVideoCall": isVideoCall ? "1" : "0"
                ]
                
                NSLog("📞 [VoIP] Call Data: \(callData)")
                NSLog("📞 [VoIP] Posting AnswerIncomingCall notification NOW")
                
                NotificationCenter.default.post(
                    name: NSNotification.Name("AnswerIncomingCall"),
                    object: nil,
                    userInfo: callData
                )
                
                NSLog("✅ [VoIP] AnswerIncomingCall notification posted!")
                print("✅ [VoIP] Notification posted - MainActivityOld should receive it")
                
                // Stop observing removeCallNotification once user answers the call
                self.stopObservingRemoveCallNotification()
            }
        }
        
        // Set up decline callback
        CallKitManager.shared.onDeclineCall = { roomId in
            NSLog("📞 [VoIP] User DECLINED call - Room: \(roomId)")
            print("📞 [VoIP] Call declined!")

            // Stop observing cancel signal once user declined
            self.stopObservingRemoveCallNotification()
            self.clearIncomingCallContext(roomId: roomId)
            
            // TODO: Notify your backend that call was declined
            // Example: sendCallDeclinedToBackend(roomId: roomId)
        }
    }

    func startObservingRemoveCallNotification(roomId: String) {
        startObservingCancelSignal(rootNode: "removeCallNotification", roomId: roomId)
    }

    func startObservingRemoveVideoCallNotification(roomId: String) {
        startObservingCancelSignal(rootNode: "removeVideoCallNotification", roomId: roomId)
    }

    private func startObservingCancelSignal(rootNode: String, roomId: String) {
        stopObservingRemoveCallNotification()

        let myUid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        let trimmedUid = myUid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUid.isEmpty else {
            NSLog("⚠️ [VoIP] Cannot observe \(rootNode) - myUid missing")
            return
        }
        let path = "\(rootNode)/\(trimmedUid)"
        removeCallObserverPath = path

        NSLog("📞 [VoIP] Observing \(rootNode) for uid=\(trimmedUid), room=\(roomId)")
        let ref = Database.database().reference().child(rootNode).child(trimmedUid)
        removeCallObserverHandle = ref.observe(.childAdded) { snapshot in
            let key = snapshot.key
            NSLog("📞 [VoIP] \(rootNode) RECEIVED key=\(key)")

            // Remove the node (best-effort) to avoid repeated triggers
            ref.child(key).removeValue()

            // If call was already answered, ignore this cancel signal.
            // The active call session manages its own lifecycle via JS endCall.
            if self.callAnswered {
                NSLog("📞 [VoIP] \(rootNode) IGNORED - call already answered, session manages lifecycle")
                self.stopObservingRemoveCallNotification()
                return
            }

            NSLog("📞 [VoIP] \(rootNode) - dismissing CallKit/UI (call not yet answered)")

            // End active CallKit call (if exists)
            if let uuid = CallKitManager.shared.getCallUUID(for: roomId) {
                CallKitManager.shared.endCall(uuid: uuid, reason: .remoteEnded)
            }

            // Notify SwiftUI to dismiss call UI if it was opened
            NotificationCenter.default.post(
                name: NSNotification.Name("IncomingCallCancelled"),
                object: nil,
                userInfo: ["roomId": roomId]
            )

            // Android parity: show missed-call notification when caller cancels while still ringing
            self.showMissedCallNotificationIfPossible(roomId: roomId)
            self.clearIncomingCallContext(roomId: roomId)

            // Stop observing after first cancellation
            self.stopObservingRemoveCallNotification()
        }
    }

    func stopObservingRemoveCallNotification() {
        guard let handle = removeCallObserverHandle,
              let path = removeCallObserverPath else {
            return
        }
        Database.database().reference().child(path).removeObserver(withHandle: handle)
        removeCallObserverHandle = nil
        removeCallObserverPath = nil
    }
    
    /// Called when VoIP token is invalidated (rare)
    func pushRegistry(_ registry: PKPushRegistry, 
                     didInvalidatePushTokenFor type: PKPushType) {
        NSLog("⚠️ [VoIP] ========================================")
        NSLog("⚠️ [VoIP] VoIP Push token INVALIDATED!")
        NSLog("⚠️ [VoIP] Type: \(type)")
        NSLog("⚠️ [VoIP] This is rare - usually happens on app reinstall")
        NSLog("⚠️ [VoIP] Will receive new token shortly")
        NSLog("⚠️ [VoIP] ========================================")
        
        print("⚠️ [VoIP] Token invalidated")
        
        voipToken = nil
        UserDefaults.standard.removeObject(forKey: "voipPushToken")
        UserDefaults.standard.synchronize()
    }
}

// MARK: - Backend Integration Helper
extension VoIPPushManager {
    
    /// Call this to send VoIP token to your backend
    func sendVoIPTokenToBackend() {
        guard let token = voipToken else {
            NSLog("⚠️ [VoIP] No VoIP token available to send")
            return
        }
        
        NSLog("📤 [VoIP] Sending VoIP token to backend...")
        NSLog("📤 [VoIP] Token: \(token)")
        
        // TODO: Implement your backend API call here
        // Example:
        /*
        let url = URL(string: "https://your-backend.com/api/register-voip-token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "userId": "current_user_id",
            "voipToken": token,
            "deviceType": "iOS"
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                NSLog("❌ [VoIP] Failed to send token: \(error)")
                return
            }
            NSLog("✅ [VoIP] Token sent to backend successfully")
        }.resume()
        */
        
        NSLog("⚠️ [VoIP] TODO: Implement sendVoIPTokenToBackend() in VoIPPushManager.swift")
    }
}
