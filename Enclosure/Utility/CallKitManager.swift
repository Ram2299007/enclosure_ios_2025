//
//  CallKitManager.swift
//  Enclosure
//
//  CallKit integration for native iOS call UI
//

import Foundation
import CallKit
import AVFoundation
import UIKit

class CallKitManager: NSObject {
    static let shared = CallKitManager()
    
    private let callController = CXCallController()
    private let provider: CXProvider
    
    // Store active calls
    private var activeCalls: [UUID: CallInfo] = [:]
    
    // Completion handlers
    var onAnswerCall: ((String, String, String, Bool) -> Void)?
    var onDeclineCall: ((String) -> Void)?
    
    // Track if CallKit audio session is ready for WebRTC
    private(set) var isAudioSessionReady = false
    
    struct CallInfo {
        let uuid: UUID
        let callerName: String
        let callerPhoto: String
        let roomId: String
        let receiverId: String
        let receiverPhone: String
        let isVideoCall: Bool
    }
    
    private override init() {
        // Configure CallKit provider
        let configuration = CXProviderConfiguration(localizedName: "Enclosure")
        
        // Set ringtone and icon
        configuration.ringtoneSound = "ringtone.caf"
        configuration.iconTemplateImageData = UIImage(named: "AppIcon")?.pngData()
        
        // Support video and audio calls
        configuration.supportsVideo = true
        configuration.maximumCallsPerCallGroup = 1
        configuration.maximumCallGroups = 1
        
        // Supported call actions
        configuration.supportedHandleTypes = [.generic, .phoneNumber]
        
        // Enable video button on CallKit UI for natural unlock trigger
        configuration.includesCallsInRecents = true
        
        provider = CXProvider(configuration: configuration)
        
        super.init()
        
        provider.setDelegate(self, queue: nil)
        
        print("✅ [CallKit] CallKitManager initialized with video button")
    }
    
    // MARK: - Report Incoming Call
    func reportIncomingCall(
        callerName: String,
        callerPhoto: String,
        roomId: String,
        receiverId: String,
        receiverPhone: String,
        isVideoCall: Bool = false,
        completion: @escaping (Error?, UUID?) -> Void
    ) {
        let uuid = UUID()
        
        let callType = isVideoCall ? "VIDEO" : "VOICE"
        print("📞 [CallKit] Reporting incoming \(callType) call:")
        print("   - Caller: \(callerName)")
        print("   - Room ID: \(roomId)")
        print("   - UUID: \(uuid.uuidString)")
        
        // Store call info
        let callInfo = CallInfo(
            uuid: uuid,
            callerName: callerName,
            callerPhoto: callerPhoto,
            roomId: roomId,
            receiverId: receiverId,
            receiverPhone: receiverPhone,
            isVideoCall: isVideoCall
        )
        activeCalls[uuid] = callInfo
        
        // Create call update
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: callerName)
        
        // Show caller name with call type on single line
        NSLog("🔍 [CallKit] isVideoCall = \(isVideoCall)")
        print("🔍 [CallKit] Call type: \(isVideoCall ? "VIDEO" : "VOICE")")
        
        // Single line format: "Ganu • Voice Call" (using bullet separator)
        let callTypeText = isVideoCall ? "Video Call" : "Voice Call"
        let displayName = "\(callerName) • \(callTypeText)"
        
        update.localizedCallerName = displayName
        
        NSLog("📞 [CallKit] Display text: '\(displayName)'")
        print("📞 [CallKit] Format: Caller • CallType")
        
        // IMPORTANT: Keep hasVideo = true for both call types
        // This ensures iOS shows Face ID/Touch ID unlock prompt on lock screen
        // Video button visibility doesn't affect the actual call (it's audio-only in WebView anyway)
        update.hasVideo = true
        print("📞 [CallKit] hasVideo = true (for auto-unlock prompt)")
        
        update.supportsHolding = false
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsDTMF = false
        
        // Report to CallKit
        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error = error {
                print("❌ [CallKit] Error reporting call: \(error.localizedDescription)")
                self.activeCalls.removeValue(forKey: uuid)
                completion(error, nil)
            } else {
                print("✅ [CallKit] Successfully reported incoming call")
                
                // Download and cache caller photo for CallKit UI
                self.downloadCallerImage(urlString: callerPhoto, for: uuid)
            
                completion(nil, uuid)
            }
        }
    }
    
    // MARK: - Download Caller Image
    private func downloadCallerImage(urlString: String, for uuid: UUID) {
        guard !urlString.isEmpty, let url = URL(string: urlString) else {
            print("⚠️ [CallKit] Invalid caller photo URL")
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("⚠️ [CallKit] Failed to download caller photo: \(error.localizedDescription)")
                return
            }
            
            guard let data = data, let image = UIImage(data: data) else {
                print("⚠️ [CallKit] Invalid image data")
                return
            }
            
            // Save to cache for CallKit to use
            if let callInfo = self.activeCalls[uuid] {
                print("✅ [CallKit] Caller photo downloaded successfully")
                // CallKit will automatically use the image from the provider delegate
            }
        }.resume()
    }
    
    // MARK: - Answer Call
    func answerCall(uuid: UUID) {
        guard let callInfo = activeCalls[uuid] else {
            print("⚠️ [CallKit] Call not found: \(uuid)")
            return
        }
        
        print("📞 [CallKit] Answering call from \(callInfo.callerName)")
        
        let answerAction = CXAnswerCallAction(call: uuid)
        let transaction = CXTransaction(action: answerAction)
        
        callController.request(transaction) { error in
            if let error = error {
                print("❌ [CallKit] Error answering call: \(error.localizedDescription)")
            } else {
                print("✅ [CallKit] Call answered successfully")
            }
        }
    }
    
    // MARK: - End Call
    func endCall(uuid: UUID, reason: CXCallEndedReason = .remoteEnded) {
        print("📞 [CallKit] Ending call: \(uuid)")
        
        provider.reportCall(with: uuid, endedAt: Date(), reason: reason)
        activeCalls.removeValue(forKey: uuid)
        
        // Reset audio ready flag when call ends
        if activeCalls.isEmpty {
            isAudioSessionReady = false
        }
    }
    
    // MARK: - End All Calls
    func endAllCalls() {
        print("📞 [CallKit] Ending all calls")
        
        for (uuid, _) in activeCalls {
            endCall(uuid: uuid, reason: .remoteEnded)
        }
    }
    
    // MARK: - Get Call Info
    func getCallInfo(for uuid: UUID) -> CallInfo? {
        return activeCalls[uuid]
    }
    
    // MARK: - Get Call UUID by Room ID
    func getCallUUID(for roomId: String) -> UUID? {
        return activeCalls.first(where: { $0.value.roomId == roomId })?.key
    }
}

// MARK: - CXProviderDelegate
extension CallKitManager: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        print("📞 [CallKit] Provider reset - ending all calls")
        activeCalls.removeAll()
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        print("📞 [CallKit] User answered call: \(action.callUUID)")
        
        guard let callInfo = activeCalls[action.callUUID] else {
            action.fail()
            return
        }
        
        // Don't configure audio here - CallKit will call didActivate with audio session
        // Configuring here causes conflicts and "Session activation failed" errors
        
        // Notify app to start call, callInfo.isVideoCall
        DispatchQueue.main.async {
            self.onAnswerCall?(callInfo.roomId, callInfo.receiverId, callInfo.receiverPhone, callInfo.isVideoCall)
        }
        
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("📞 [CallKit] User ended call: \(action.callUUID)")
        
        guard let callInfo = activeCalls[action.callUUID] else {
            action.fail()
            return
        }
        
        // Notify app to end call
        DispatchQueue.main.async {
            self.onDeclineCall?(callInfo.roomId)
        }
        
        activeCalls.removeValue(forKey: action.callUUID)
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        print("📞 [CallKit] Starting outgoing call: \(action.callUUID)")
        
        // Don't configure audio here - CallKit will call didActivate
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        print("📞 [CallKit] Hold action: \(action.isOnHold)")
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        print("⚠️ [CallKit] Action timed out: \(action)")
        action.fail()
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        print("📞 [CallKit] Audio session activated by CallKit")
        NSLog("📞 [CallKit] Audio session activated - configuring for WebRTC...")
        
        // Configure audio session now that CallKit has activated it
        do {
            // CRITICAL: Use .default mode (NOT .voiceChat)
            // .voiceChat applies system-level Voice Processing I/O (echo cancellation, AGC, noise suppression)
            // which CONFLICTS with WKWebView's own WebRTC audio processing, causing getUserMedia tracks
            // to stay permanently muted=true. WebRTC handles its own echo cancellation and noise suppression.
            // .playAndRecord category naturally routes to earpiece (receiver).
            // .mixWithOthers is REQUIRED for WKWebView to access the microphone.
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .mixWithOthers])
            try audioSession.setActive(true)
            print("✅ [CallKit] Audio session configured: playAndRecord + default mode + active")
            NSLog("✅ [CallKit] Audio session configured: .default mode + .mixWithOthers + setActive(true)")
            
            let route = audioSession.currentRoute
            let inputs = route.inputs.map { $0.portType.rawValue }
            let outputs = route.outputs.map { $0.portType.rawValue }
            NSLog("✅ [CallKit] Route after config - inputs: \(inputs), outputs: \(outputs)")
            
            // CRITICAL: Set flag AND post notification
            // Flag allows late-arriving observers to check if audio is already ready
            isAudioSessionReady = true
            NSLog("✅✅✅ [CallKit] Audio session FULLY READY - setting flag and posting notification")
            NotificationCenter.default.post(name: NSNotification.Name("CallKitAudioSessionReady"), object: nil)
            
        } catch {
            print("❌ [CallKit] Failed to configure audio session: \(error.localizedDescription)")
            NSLog("❌ [CallKit] Audio session configuration failed: \(error.localizedDescription)")
            // Even if configuration fails, mark as ready so session can try to proceed
            isAudioSessionReady = true
            NotificationCenter.default.post(name: NSNotification.Name("CallKitAudioSessionReady"), object: nil)
        }
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        print("📞 [CallKit] Audio session deactivated")
        isAudioSessionReady = false
    }
    
    // MARK: - Audio Session Configuration
    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Use .default mode - .voiceChat conflicts with WKWebView WebRTC audio processing
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .mixWithOthers])
            try audioSession.setActive(true)
            print("✅ [CallKit] Audio session configured")
        } catch {
            print("❌ [CallKit] Failed to configure audio session: \(error.localizedDescription)")
        }
    }
}
