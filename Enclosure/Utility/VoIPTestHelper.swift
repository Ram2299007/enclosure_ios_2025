//
//  VoIPTestHelper.swift
//  Enclosure
//
//  Test VoIP CallKit triggering without backend
//

import Foundation
import PushKit
import CallKit

class VoIPTestHelper {
    
    /// Simulate receiving a VoIP push - TEST ONLY
    /// This shows what will happen when backend sends real VoIP push
    static func testVoIPPushReceived() {
        NSLog("🧪 [TEST] ========================================")
        NSLog("🧪 [TEST] Simulating VoIP Push Received")
        NSLog("🧪 [TEST] This is what happens when backend sends VoIP push")
        NSLog("🧪 [TEST] ========================================")
        
        print("🧪 [TEST] Simulating VoIP push...")
        
        // Simulate VoIP push payload
        let simulatedPayload: [String: Any] = [
            "name": "Test Caller (VoIP)",
            "photo": "",
            "roomId": "TestRoom_VoIP_\(Date().timeIntervalSince1970)",
            "receiverId": "999",
            "phone": "+911234567890",
            "bodyKey": "Incoming voice call"
        ]
        
        NSLog("🧪 [TEST] Simulated Payload: \(simulatedPayload)")
        print("🧪 [TEST] Triggering CallKit with test data...")
        
        // Extract call data
        let callerName = simulatedPayload["name"] as! String
        let callerPhoto = simulatedPayload["photo"] as! String
        let roomId = simulatedPayload["roomId"] as! String
        let receiverId = simulatedPayload["receiverId"] as! String
        let receiverPhone = simulatedPayload["phone"] as! String
        
        NSLog("📞 [TEST] Reporting call to CallKit...")
        print("📞 [TEST] Caller: \(callerName)")
        print("📞 [TEST] Room: \(roomId)")
        
        // Report to CallKit - THIS IS WHAT VOIP PUSH DOES!
        CallKitManager.shared.reportIncomingCall(
            callerName: callerName,
            callerPhoto: callerPhoto,
            roomId: roomId,
            receiverId: receiverId,
            receiverPhone: receiverPhone
        ) { error, callUUID in
            if let error = error {
                NSLog("❌ [TEST] CallKit Error: \(error.localizedDescription)")
                print("❌ [TEST] CallKit error")
            } else {
                NSLog("✅✅✅ [TEST] CallKit SUCCESS!")
                NSLog("✅ [TEST] You should now see full-screen CallKit UI")
                NSLog("✅ [TEST] This proves VoIP will work when backend sends real push")
                print("✅✅✅ [TEST] CallKit triggered successfully!")
                print("✅ [TEST] This is what happens with real VoIP push!")
                if let uuid = callUUID {
                    NSLog("✅ [TEST] Call UUID: \(uuid.uuidString)")
                }
            }
        }
        
        // Set up callbacks
        CallKitManager.shared.onAnswerCall = { roomId, receiverId, receiverPhone, isVideoCall in
            NSLog("📞 [TEST] User ANSWERED test call")
            print("📞 [TEST] Call answered!")
            
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
            NSLog("📞 [TEST] User DECLINED test call")
            print("📞 [TEST] Call declined!")
        }
    }
    
    /// Display VoIP token for easy copying
    static func showVoIPToken() {
        if let token = VoIPPushManager.shared.getVoIPToken() {
            NSLog("📞 [TEST] ========================================")
            NSLog("📞 [TEST] YOUR VOIP TOKEN:")
            NSLog("📞 [TEST] \(token)")
            NSLog("📞 [TEST] ========================================")
            NSLog("📞 [TEST] Copy this token and send to backend developer")
            NSLog("📞 [TEST] Backend must use this for VoIP pushes")
            print("📞 [TEST] VoIP Token: \(token)")
        } else {
            NSLog("⚠️ [TEST] No VoIP token yet - wait a few seconds after app launch")
            print("⚠️ [TEST] No VoIP token yet")
        }
    }
}
