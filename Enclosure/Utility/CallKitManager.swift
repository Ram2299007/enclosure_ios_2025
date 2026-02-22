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
import WebRTC
import os.log

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
    
    // Track if we intentionally dismissed CallKit for a video/voice call
    private var dismissedForVideoCall = false
    private var dismissedForVoiceCall = false
    
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
        CallLogger.log("Reporting incoming \(callType) call: Caller=\(callerName), Room=\(roomId), UUID=\(uuid.uuidString)", category: .callkit)
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
        // Use receiverId in the handle so we can look up the contact
        // when user taps this call from iPhone's native Phone app Recents.
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: receiverId)
        
        // Show caller name with call type on single line
        NSLog("🔍 [CallKit] isVideoCall = \(isVideoCall)")
        print("🔍 [CallKit] Call type: \(isVideoCall ? "VIDEO" : "VOICE")")
        
        update.localizedCallerName = callerName
        
        NSLog("📞 [CallKit] Display text: '\(callerName)' (handle=\(receiverId))")
        print("📞 [CallKit] Format: Caller • CallType (handle=receiverId)")
        
        // Set hasVideo based on actual call type.
        // Voice calls: hasVideo=false → iOS shows "Enclosure Audio" (not "Enclosure Video")
        // Video calls: hasVideo=true → iOS shows "Enclosure Video" + forces unlock
        // Background audio for voice calls works via ActiveCallManager (no unlock hack needed).
        update.hasVideo = isVideoCall
        print("📞 [CallKit] hasVideo = \(isVideoCall) (\(isVideoCall ? "video" : "voice") call)")
        
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
    
    // MARK: - Start Outgoing Call (for Native WebRTC)
    /// Start an outgoing CallKit call so it shows in Dynamic Island / green status bar.
    /// Returns the UUID for tracking this call.
    func startOutgoingCall(callerName: String, roomId: String, receiverId: String) -> UUID {
        let uuid = UUID()
        
        let callInfo = CallInfo(
            uuid: uuid,
            callerName: callerName,
            callerPhoto: "",
            roomId: roomId,
            receiverId: receiverId,
            receiverPhone: "",
            isVideoCall: false
        )
        activeCalls[uuid] = callInfo
        
        let handle = CXHandle(type: .generic, value: receiverId)
        let startAction = CXStartCallAction(call: uuid, handle: handle)
        startAction.isVideo = false
        startAction.contactIdentifier = callerName
        
        let transaction = CXTransaction(action: startAction)
        callController.request(transaction) { error in
            if let error = error {
                NSLog("❌ [CallKit] Failed to start outgoing call: \(error.localizedDescription)")
            } else {
                NSLog("✅ [CallKit] Outgoing call started — Dynamic Island active")
                // Update display name after starting
                let update = CXCallUpdate()
                update.remoteHandle = handle
                update.localizedCallerName = callerName
                update.hasVideo = false
                self.provider.reportCall(with: uuid, updated: update)
            }
        }
        
        return uuid
    }
    
    // MARK: - Report Call Connected
    /// Tell CallKit the call is now connected (updates Dynamic Island UI).
    func reportCallConnected(uuid: UUID) {
        provider.reportOutgoingCall(with: uuid, connectedAt: Date())
        NSLog("✅ [CallKit] Reported call connected: \(uuid)")
    }

    // MARK: - Sync Mute State to CallKit
    /// Called from NativeVoiceCallSession when user toggles mute in the app UI.
    /// This syncs the mute state to CallKit so the Dynamic Island/green bar shows correct icon.
    func reportMuteState(uuid: UUID, muted: Bool) {
        let muteAction = CXSetMutedCallAction(call: uuid, muted: muted)
        let transaction = CXTransaction(action: muteAction)
        callController.request(transaction) { error in
            if let error = error {
                NSLog("⚠️ [CallKit] Failed to sync mute to CallKit: \(error.localizedDescription)")
            } else {
                NSLog("✅ [CallKit] Mute synced to CallKit: \(muted)")
            }
        }
    }
    
    // MARK: - Dismiss CallKit for Voice Session
    /// Dismiss CallKit call while keeping isAudioSessionReady=true.
    /// Used when voice call is connected and WebRTC needs to take over audio.
    /// CallKit was kept active until call connected for earpiece routing.
    func dismissCallForVoiceSession(uuid: UUID) {
        NSLog("📞 [CallKit] Dismissing CallKit for voice session: \(uuid)")
        // Ensure didDeactivate keeps isAudioSessionReady=true
        dismissedForVoiceCall = true
        provider.reportCall(with: uuid, endedAt: Date(), reason: .answeredElsewhere)
        activeCalls.removeValue(forKey: uuid)
        // Don't reset isAudioSessionReady - voice call is still active
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
        CallLogger.log("User ANSWERED call: \(action.callUUID)", category: .callkit)
        print("📞 [CallKit] User answered call: \(action.callUUID)")
        
        guard let callInfo = activeCalls[action.callUUID] else {
            action.fail()
            return
        }
        
        // Don't configure audio here - CallKit will call didActivate with audio session
        // Configuring here causes conflicts and "Session activation failed" errors
        
        // CRITICAL ORDER: fulfill() FIRST, then start session.
        // action.fulfill() triggers didActivate on the main queue.
        // If we do heavy WebRTC setup (PeerConnectionFactory, audio tracks, Firebase)
        // BEFORE fulfill(), it blocks the main queue and didActivate NEVER fires.
        //
        // After fulfill(), didActivate sets isAudioSessionReady=true.
        // When the async onAnswerCall creates the session, proceedWithStart() checks
        // isAudioSessionReady and activates audio immediately if true.
        // If didActivate hasn't fired yet, the notification observer handles it.
        let roomId = callInfo.roomId
        let receiverId = callInfo.receiverId
        let receiverPhone = callInfo.receiverPhone
        let isVideoCall = callInfo.isVideoCall
        
        action.fulfill()
        NSLog("📞 [CallKit] action.fulfill() called — didActivate will fire next")
        
        DispatchQueue.main.async { [weak self] in
            NSLog("📞 [CallKit] Starting session async after fulfill (isAudioReady=\(CallKitManager.shared.isAudioSessionReady))")
            self?.onAnswerCall?(roomId, receiverId, receiverPhone, isVideoCall)
        }
        
        // Dismiss CallKit full-screen UI after answering for video calls.
        // Native WebRTC doesn't need the 1s delay that WebView required.
        if callInfo.isVideoCall {
            print("📞 [CallKit] Video call - dismissing CallKit UI (0.3s delay)")
            dismissedForVideoCall = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                print("📞 [CallKit] Now dismissing CallKit UI for video call")
                self.provider.reportCall(with: action.callUUID, endedAt: Date(), reason: .answeredElsewhere)
                self.activeCalls.removeValue(forKey: action.callUUID)
            }
        } else {
            // KEEP CallKit call ACTIVE for voice calls!
            // When CallKit has an active call, iOS gives system-level telephony priority
            // to earpiece (Receiver) routing. WebContent's .defaultToSpeaker is overridden
            // by the system because there's an active "phone call".
            // Previously we ended the call at 1.0s which caused audio session deactivation,
            // letting WebContent's .defaultToSpeaker take over → Speaker output.
            // The CallKit UI auto-dismisses after action.fulfill() - user sees VoiceCallScreen.
            // Green bar / Dynamic Island shows active call indicator (good UX).
            // Call is ended in VoiceCallSession.endCall() / stop() when user ends the call.
            print("📞 [CallKit] Voice call - keeping CallKit call ACTIVE for earpiece routing")
            dismissedForVoiceCall = true
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("📞 [CallKit] User ended call: \(action.callUUID)")
        
        guard let callInfo = activeCalls[action.callUUID] else {
            action.fail()
            return
        }
        
        // Notify app to end call (legacy decline handler)
        DispatchQueue.main.async {
            self.onDeclineCall?(callInfo.roomId)
        }
        
        // Route end-call through ActiveCallManager (primary path)
        // This directly ends the NativeVoiceCallSession if active
        ActiveCallManager.shared.endCallFromCallKit()
        
        // Also post notification as fallback for NativeVoiceCallSession observer
        DispatchQueue.main.async {
            NSLog("📞 [CallKit] Posting CallKitEndedCall notification for room: \(callInfo.roomId)")
            NotificationCenter.default.post(
                name: NSNotification.Name("CallKitEndedCall"),
                object: nil,
                userInfo: ["roomId": callInfo.roomId]
            )
        }
        
        activeCalls.removeValue(forKey: action.callUUID)
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        let handleValue = action.handle.value
        NSLog("📞 [CallKit] CXStartCallAction: uuid=\(action.callUUID), handle=\(handleValue)")
        
        // If this UUID is already in activeCalls, it's an app-initiated outgoing call — just fulfill.
        if activeCalls[action.callUUID] != nil {
            NSLog("📞 [CallKit] App-initiated outgoing call — fulfilling")
            action.fulfill()
            return
        }
        
        // Otherwise, this is a CALLBACK from native Phone app Recents.
        // The handle value is the receiverId (friendId) we stored when the call was reported.
        NSLog("📞 [CallKit] 📱 Callback from Phone app Recents! handle (friendId) = \(handleValue)")
        
        // End this CallKit call immediately — we'll start our own via the normal flow.
        action.fail()
        
        // Look up the stored contact info and post notification to initiate the call.
        DispatchQueue.main.async {
            if let contact = RecentCallContactStore.shared.getContact(for: handleValue) {
                NSLog("📞 [CallKit] Found stored contact: \(contact.fullName) — initiating Enclosure call")
                NotificationCenter.default.post(
                    name: NSNotification.Name("InitiateCallFromRecents"),
                    object: nil,
                    userInfo: [
                        "friendId": contact.friendId,
                        "fullName": contact.fullName,
                        "photo": contact.photo,
                        "fToken": contact.fToken,
                        "voipToken": contact.voipToken,
                        "deviceType": contact.deviceType,
                        "mobileNo": contact.mobileNo
                    ]
                )
            } else {
                NSLog("⚠️ [CallKit] No stored contact for handle \(handleValue) — posting with handle only")
                NotificationCenter.default.post(
                    name: NSNotification.Name("InitiateCallFromRecents"),
                    object: nil,
                    userInfo: [
                        "friendId": handleValue,
                        "fullName": action.contactIdentifier ?? "Unknown",
                        "photo": "",
                        "fToken": "",
                        "voipToken": "",
                        "deviceType": "",
                        "mobileNo": ""
                    ]
                )
            }
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        print("📞 [CallKit] Hold action: \(action.isOnHold)")
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        NSLog("📞 [CallKit] Mute action: \(action.isMuted)")
        // Route mute to the active voice call session (WhatsApp-style sync)
        ActiveCallManager.shared.setMutedFromCallKit(action.isMuted)
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        print("⚠️ [CallKit] Action timed out: \(action)")
        action.fail()
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        CallLogger.log("didActivate — audio session activated by system", category: .audio)
        NSLog("📞 [CallKit] didActivate — audio session activated by system")
        
        let isVoiceCall = activeCalls.values.contains(where: { !$0.isVideoCall })
        CallLogger.log("Call type: \(isVoiceCall ? "VOICE (native WebRTC)" : "VIDEO (WebView)"), Category: \(audioSession.category.rawValue), Mode: \(audioSession.mode.rawValue)", category: .audio)
        NSLog("📞 [CallKit] Call type: \(isVoiceCall ? "VOICE (native WebRTC)" : "VIDEO (WebView)")")
        
        if isVoiceCall {
            // CRITICAL: For native WebRTC voice calls, activate RTCAudioSession DIRECTLY.
            // Do NOT reconfigure AVAudioSession (setCategory/setActive) here.
            // CallKit has ALREADY activated the audio session — reconfiguring it
            // causes AURemoteIO format errors (1701737535) on cold start / background.
            //
            // The proper WebRTC + CallKit pattern:
            // 1. RTCAudioSession.useManualAudio = true (set in NativeWebRTCManager.init)
            // 2. In didActivate: audioSessionDidActivate + isAudioEnabled = true
            // 3. In didDeactivate: audioSessionDidDeactivate + isAudioEnabled = false
            let rtcAudioSession = RTCAudioSession.sharedInstance()
            rtcAudioSession.audioSessionDidActivate(audioSession)
            rtcAudioSession.isAudioEnabled = true
            CallLogger.success("RTCAudioSession.audioSessionDidActivate + isAudioEnabled=true", category: .audio)
            NSLog("✅ [CallKit] RTCAudioSession.audioSessionDidActivate + isAudioEnabled=true")
            
            let route = audioSession.currentRoute
            CallLogger.log("Route: in=\(route.inputs.map{$0.portType.rawValue}), out=\(route.outputs.map{$0.portType.rawValue})", category: .audio)
            NSLog("✅ [CallKit] Route: in=\(route.inputs.map{$0.portType.rawValue}), out=\(route.outputs.map{$0.portType.rawValue})")
        } else {
            // Video call (WKWebView): configure for WebView mic access
            do {
                try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .mixWithOthers])
                try audioSession.setActive(true)
                NSLog("✅ [CallKit] Video call: .default mode + .mixWithOthers")
            } catch {
                NSLog("❌ [CallKit] Video call audio config failed: \(error.localizedDescription)")
            }
        }
        
        // Set flag AND post notification
        isAudioSessionReady = true
        CallLogger.success("Audio session FULLY READY", category: .audio)
        NSLog("✅✅✅ [CallKit] Audio session FULLY READY")
        NotificationCenter.default.post(name: NSNotification.Name("CallKitAudioSessionReady"), object: nil)
        
        // Belt-and-suspenders: also tell ActiveCallManager (session may not exist yet on cold start)
        ActiveCallManager.shared.activateAudioForCallKit()
        
        // LOCK SCREEN FIX: On lock screen + cold start, didActivate fires BEFORE
        // ActiveCallManager.startIncomingSession() creates the NativeVoiceCallSession.
        // The call above finds nil session. This delayed retry ensures audio is activated
        // AFTER the session and WebRTC factory/tracks are fully created.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard self.isAudioSessionReady else { return }
            if ActiveCallManager.shared.hasActiveCall {
                CallLogger.log("didActivate delayed retry — re-activating WebRTC audio (lock screen fix)", category: .audio)
                NSLog("📞 [CallKit] didActivate delayed retry — re-activating WebRTC audio")
                ActiveCallManager.shared.activateAudioForCallKit()
            }
        }
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        CallLogger.log("didDeactivate — audio session deactivated", category: .audio)
        NSLog("📞 [CallKit] didDeactivate — audio session deactivated")
        
        // Tell RTCAudioSession the system deactivated audio
        let rtcAudioSession = RTCAudioSession.sharedInstance()
        rtcAudioSession.audioSessionDidDeactivate(audioSession)
        rtcAudioSession.isAudioEnabled = false
        
        if dismissedForVideoCall {
            print("📞 [CallKit] Keeping isAudioSessionReady=true (video call active)")
            dismissedForVideoCall = false
        } else if dismissedForVoiceCall {
            NSLog("📞 [CallKit] Voice call dismissed — reactivating RTCAudioSession")
            dismissedForVoiceCall = false
            // Re-activate for native WebRTC to continue
            rtcAudioSession.audioSessionDidActivate(audioSession)
            rtcAudioSession.isAudioEnabled = true
        } else {
            isAudioSessionReady = false
        }
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
