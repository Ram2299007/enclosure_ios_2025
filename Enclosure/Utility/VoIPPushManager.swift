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

class VoIPPushManager: NSObject {
    static let shared = VoIPPushManager()
    
    private let pushRegistry = PKPushRegistry(queue: .main)
    private var voipToken: String?
    
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
        
        pushRegistry.delegate = self
        pushRegistry.desiredPushTypes = [.voIP]
        
        NSLog("📞 [VoIP] PushKit registry configured for VoIP")
        print("📞 [VoIP] PushKit registry configured")
    }
    
    func getVoIPToken() -> String? {
        return voipToken
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
        
        NSLog("📞📞📞 [VoIP] ========================================")
        NSLog("📞 [VoIP] INCOMING VOIP PUSH RECEIVED!")
        NSLog("📞 [VoIP] App State: \(UIApplication.shared.applicationState.rawValue) (0=active, 1=inactive, 2=background)")
        NSLog("📞 [VoIP] ========================================")
        
        print("📞📞📞 [VoIP] INCOMING VOIP PUSH!")
        
        let userInfo = payload.dictionaryPayload
        
        NSLog("📞 [VoIP] Full Payload: \(userInfo)")
        print("📞 [VoIP] Payload: \(userInfo)")
        
        // Extract call data from payload
        let callerName = (userInfo["name"] as? String) 
                      ?? (userInfo["user_nameKey"] as? String) 
                      ?? "Unknown Caller"
        let callerPhoto = (userInfo["photo"] as? String) ?? ""
        let roomId = (userInfo["roomId"] as? String) ?? ""
        let receiverId = (userInfo["receiverId"] as? String) ?? ""
        let receiverPhone = (userInfo["phone"] as? String) ?? ""
        let bodyKey = (userInfo["bodyKey"] as? String) ?? ""
        
        NSLog("📞 [VoIP] Extracted Data:")
        NSLog("📞 [VoIP]   Caller Name: \(callerName)")
        NSLog("📞 [VoIP]   Room ID: \(roomId)")
        NSLog("📞 [VoIP]   Receiver ID: \(receiverId)")
        NSLog("📞 [VoIP]   Body Key: \(bodyKey)")
        
        print("📞 [VoIP] Call from: \(callerName)")
        print("📞 [VoIP] Room: \(roomId)")
        
        // Validate required data
        guard !roomId.isEmpty else {
            NSLog("❌ [VoIP] ERROR: Missing roomId in VoIP push payload")
            NSLog("❌ [VoIP] Cannot process call without roomId")
            print("❌ [VoIP] Missing roomId!")
            completion()
            return
        }
        
        // Determine if voice or video call
        let isVideoCall = bodyKey.contains("video") || bodyKey.contains("Video")
        NSLog("📞 [VoIP] Call Type: \(isVideoCall ? "VIDEO" : "VOICE")")
        
        NSLog("📞 [VoIP] Reporting call to CallKit NOW...")
        print("📞 [VoIP] Triggering CallKit...")
        
        // Report to CallKit IMMEDIATELY
        // This will show the CallKit full-screen UI instantly, even in background!
        CallKitManager.shared.reportIncomingCall(
            callerName: callerName,
            callerPhoto: callerPhoto,
            roomId: roomId,
            receiverId: receiverId,
            receiverPhone: receiverPhone
        ) { error in
            if let error = error {
                NSLog("❌ [VoIP] CallKit Error: \(error.localizedDescription)")
                print("❌ [VoIP] CallKit error: \(error.localizedDescription)")
            } else {
                NSLog("✅✅✅ [VoIP] CallKit call reported successfully!")
                NSLog("✅ [VoIP] User should now see full-screen CallKit UI")
                NSLog("✅ [VoIP] This works in FOREGROUND, BACKGROUND, and LOCK SCREEN!")
                print("✅✅✅ [VoIP] CallKit triggered successfully!")
            }
            
            // CRITICAL: Must call completion handler
            // iOS will terminate app if not called within 30 seconds
            completion()
        }
        
        // Set up answer callback
        CallKitManager.shared.onAnswerCall = { roomId, receiverId, receiverPhone in
            NSLog("📞 [VoIP] User ANSWERED call - Room: \(roomId)")
            print("📞 [VoIP] Call answered!")
            
            DispatchQueue.main.async {
                let callData: [String: String] = [
                    "roomId": roomId,
                    "receiverId": receiverId,
                    "receiverPhone": receiverPhone,
                    "callerName": callerName,
                    "callerPhoto": callerPhoto
                ]
                
                NSLog("📞 [VoIP] Posting AnswerIncomingCall notification")
                NotificationCenter.default.post(
                    name: NSNotification.Name("AnswerIncomingCall"),
                    object: nil,
                    userInfo: callData
                )
            }
        }
        
        // Set up decline callback
        CallKitManager.shared.onDeclineCall = { roomId in
            NSLog("📞 [VoIP] User DECLINED call - Room: \(roomId)")
            print("📞 [VoIP] Call declined!")
            
            // TODO: Notify your backend that call was declined
            // Example: sendCallDeclinedToBackend(roomId: roomId)
        }
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
