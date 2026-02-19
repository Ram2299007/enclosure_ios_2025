import Foundation
import FirebaseDatabase
import AVFoundation
import AudioToolbox
import WebKit
import UIKit

final class VoiceCallSession: ObservableObject {
    @Published var shouldDismiss = false
    @Published var isCallConnected = false
    /// Mute state for microphone; synced with native audio and WebView.
    @Published var isMuted: Bool

    private let payload: VoiceCallPayload
    private let roomId: String
    private let myUid: String
    private let myName: String
    private let myPhoto: String

    private var myPeerId: String?
    private var peersHandle: DatabaseHandle?
    private var signalingHandle: DatabaseHandle?
    private var databaseRef: DatabaseReference?
    private weak var webView: WKWebView?

    private let audioSession = AVAudioSession.sharedInstance()
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var isAudioInterrupted = false
    private var lastAudioActivationTime: TimeInterval = 0
    private var shouldForceEarpiece = true
    private var isSettingEarpiece = false
    private var lastEarpieceSetTime: TimeInterval = 0
    private var ringtonePlayer: AVAudioPlayer?
    private var ringtoneKeepAliveTimer: Timer?
    private var ringtoneSystemSoundId: SystemSoundID = 0
    private var ringtoneSystemSoundTimer: Timer?
    private var earpieceMonitorTimer: Timer?
    private var proximityObserver: NSObjectProtocol?
    private var callKitAudioReadyObserver: NSObjectProtocol?
    private var isWaitingForCallKitAudio = false
    private var hasStarted = false
    private var callKitDismissed = false
    private var earpieceForceRetryCount = 0

    private var removeCallNotificationSent = false
    private var isCallEnded = false

    init(payload: VoiceCallPayload) {
        self.payload = payload
        self.roomId = payload.roomId ?? Self.generateRoomId()
        self.myUid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        self.myName = UserDefaults.standard.string(forKey: Constant.full_name) ?? "Name"
        self.myPhoto = UserDefaults.standard.string(forKey: Constant.profilePic) ?? ""
        self.isMuted = UserDefaults.standard.bool(forKey: "voice_call_muted")
    }

    func attach(webView: WKWebView) {
        self.webView = webView
    }

    func start() {
        guard !hasStarted else {
            NSLog("⚠️ [VoiceCallSession] start() already called - ignoring duplicate")
            return
        }
        hasStarted = true
        isCallConnected = false
        
        // For incoming CallKit calls, set up Firebase IMMEDIATELY so the WebView can connect
        // (onPageReady/sendPeerId may run before CallKit is ready; we need databaseRef for peer to appear in room)
        if !payload.isSender {
            NSLog("📞 [VoiceCallSession] Incoming call - setting up Firebase/room immediately so call can connect")
            databaseRef = Database.database().reference()
            setupFirebaseListeners()
        }
        
        // For incoming CallKit calls, WAIT for CallKit before audio/earpiece (prevents muted mic)
        if !payload.isSender {
            // CRITICAL: Check if CallKit audio is already ready (handles race condition)
            if CallKitManager.shared.isAudioSessionReady {
                NSLog("✅✅✅ [VoiceCallSession] CallKit audio ALREADY READY - proceeding with audio now!")
                proceedWithStart()
                return
            }
            
            print("📞 [VoiceCallSession] Incoming CallKit call - waiting for audio session...")
            NSLog("📞 [VoiceCallSession] Waiting for CallKit audio session to be ready...")
            
            isWaitingForCallKitAudio = true
            
            // Set up listener for CallKit audio ready notification
            callKitAudioReadyObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("CallKitAudioSessionReady"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self = self, self.isWaitingForCallKitAudio else { return }
                self.isWaitingForCallKitAudio = false
                
                NSLog("✅✅✅ [VoiceCallSession] CallKit audio session READY - starting audio now!")
                self.proceedWithStart()
            }
            
            // Timeout fallback
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self, self.isWaitingForCallKitAudio else { return }
                NSLog("⚠️ [VoiceCallSession] Timeout waiting for CallKit audio - proceeding anyway")
                self.isWaitingForCallKitAudio = false
                self.proceedWithStart()
            }
        } else {
            print("📞 [VoiceCallSession] Outgoing call - starting immediately")
            proceedWithStart()
        }
    }
    
    private func proceedWithStart() {
        // Skip Firebase setup if already done (incoming call sets it up in start())
        if databaseRef == nil {
            databaseRef = Database.database().reference()
            setupFirebaseListeners()
        }
        
        // Audio and earpiece
        if !payload.isSender {
            print("📞 [VoiceCallSession] Incoming call - CallKit managing audio session")
            checkMicrophonePermission()
        } else {
            print("📞 [VoiceCallSession] Outgoing call - we manage audio session")
            requestMicrophoneAccess()
        }
        
        startObservingAudioInterruptions()
        
        // For incoming CallKit calls: do NOT start earpiece monitor or force earpiece.
        // CallKit didActivate already configured earpiece. Any audio session touch
        // prevents WKWebView track from transitioning muted=true → muted=false.
        if payload.isSender {
            startEarpieceMonitor()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.setAudioOutput("earpiece")
            }
            startRingtone()
        } else {
            // CallKit call stays ACTIVE for the entire voice call duration.
            // System-level telephony priority keeps audio on earpiece (Receiver).
            // No need to reconfigure audio or force earpiece - CallKit manages it.
            // CallKit UI auto-dismisses after action.fulfill() - VoiceCallScreen shows.
            // Call is ended in endCall()/stop() when user ends the voice call.
            NSLog("📞 [VoiceCallSession] Incoming call - CallKit ACTIVE, system manages earpiece routing")
        }
    }

    // REMOVED: nudgeIncomingCallKitAudioSession was re-poking the audio session after
    // CallKit already configured it in didActivate, which disrupted the WKWebView mic track
    // and caused muted=true to persist. For incoming CallKit calls, trust CallKit's config.

    func stop() {
        // Safety net: only sender sends removeCallNotification, and only if call actually ended
        if isCallEnded && payload.isSender {
            sendRemoveCallNotificationIfNeeded()
        }
        // Always clean up any entries addressed to us
        if isCallEnded {
            cleanupRemoveCallNotificationForSelf()
        }
        
        // Release microphone in WebView FIRST so iOS drops mic access before we end CallKit.
        // This prevents the orange dot from flashing briefly when the call is dismissed.
        sendToWebView("if (typeof releaseMicrophone === 'function') releaseMicrophone();")
        
        stopRingtone(reason: "session_stop")
        stopObservingAudioInterruptions()
        stopEarpieceMonitor()
        disableProximitySensor()
        
        if let observer = callKitAudioReadyObserver {
            NotificationCenter.default.removeObserver(observer)
            callKitAudioReadyObserver = nil
        }
        isWaitingForCallKitAudio = false
        
        // Short delay so WebView has time to release tracks before we end CallKit (reduces orange dot flash)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.performStopCleanup()
        }
    }
    
    private func performStopCleanup() {
        cleanupFirebaseListeners()
        
        // End CallKit call if this was an incoming CallKit call
        if !payload.isSender {
            if let callKitUUID = CallKitManager.shared.getCallUUID(for: roomId) {
                NSLog("📞 [VoiceCallSession] Ending CallKit call: \(callKitUUID)")
                print("📞 [VoiceCallSession] Dismissing CallKit full-screen UI...")
                CallKitManager.shared.endCall(uuid: callKitUUID, reason: .remoteEnded)
            } else {
                NSLog("⚠️ [VoiceCallSession] No active CallKit call found for room: \(roomId)")
            }
        }
    }

    func handleMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        switch type {
        case "logToNative":
            if let logMessage = message["message"] as? String {
                NSLog("🌐 [WebRTC-JS] %@", logMessage)
                print("🌐 [WebRTC-JS] \(logMessage)")
            }
        case "sendPeerId":
            if let peerId = message["peerId"] as? String {
                handleSendPeerId(peerId)
            }
        case "setAudioOutput":
            if let output = message["output"] as? String {
                setAudioOutput(output)
            }
        case "toggleMicrophone":
            if let mute = message["mute"] as? Bool {
                DispatchQueue.main.async { [weak self] in self?.isMuted = mute }
                setMicrophoneMuted(mute)
            }
        case "saveMuteState":
            if let mute = message["mute"] as? Bool {
                DispatchQueue.main.async { [weak self] in self?.isMuted = mute }
                UserDefaults.standard.set(mute, forKey: "voice_call_muted")
            }
        case "sendSignaling":
            if let jsonString = message["data"] as? String {
                let key = databaseRef?.child("rooms").child(roomId).child("signaling").childByAutoId().key ?? UUID().uuidString
                databaseRef?.child("rooms").child(roomId).child("signaling").child(key).setValue(jsonString)
                NSLog("📤 [VoiceCallSession] JS sendSignaling relayed to Firebase")
            }
        case "checkBluetoothAvailability":
            updateBluetoothAvailability()
        case "onPeerConnected":
            requestMicrophonePermissionIfNeeded()
        case "onCallConnected":
            isCallConnected = true
            stopRingtone(reason: "call_connected")
            
            NSLog("🎤🎤🎤 [VoiceCallSession] ========================================")
            NSLog("🎤 [VoiceCallSession] Call connected - activating microphone")
            NSLog("🎤 [VoiceCallSession] Permission: \(audioSession.recordPermission.rawValue)")
            NSLog("🎤 [VoiceCallSession] Session active: \(audioSession.isOtherAudioPlaying)")
            NSLog("🎤 [VoiceCallSession] isSender: \(payload.isSender)")
            NSLog("🎤🎤🎤 [VoiceCallSession] ========================================")
            
            // Enable proximity sensor when call connects
            enableProximitySensor()
            
            // HYBRID: CallKit was kept active for earpiece routing. Now call is connected,
            // dismiss CallKit so WebRTC mic can unmute (muted=true while CallKit owns audio).
            if !payload.isSender && !callKitDismissed {
                NSLog("🎤 [VoiceCallSession] Call connected - dismissing CallKit to unmute microphone")
                
                // Set callKitDismissed IMMEDIATELY so route observer & setAudioOutput aren't blocked
                self.callKitDismissed = true
                
                if let callKitUUID = CallKitManager.shared.getCallUUID(for: roomId) {
                    NSLog("📞 [VoiceCallSession] Dismissing CallKit call: \(callKitUUID)")
                    CallKitManager.shared.dismissCallForVoiceSession(uuid: callKitUUID)
                } else {
                    NSLog("⚠️ [VoiceCallSession] CallKit UUID not found (may already be dismissed)")
                }
                
                // After short delay for audio session to resettle, reconfigure audio
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self else { return }
                    NSLog("📞 [VoiceCallSession] Reconfiguring audio after CallKit dismiss")
                    
                    // Use .default mode (NOT .voiceChat which conflicts with WebRTC → muted=true)
                    // .mixWithOthers REQUIRED for WebContent to function
                    do {
                        try self.audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .mixWithOthers])
                        try self.audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
                        if let builtInMic = self.audioSession.availableInputs?.first(where: { $0.portType == .builtInMic }) {
                            try self.audioSession.setPreferredInput(builtInMic)
                        }
                        try self.audioSession.overrideOutputAudioPort(.none)
                        NSLog("✅ [VoiceCallSession] Audio reconfigured: .default + .mixWithOthers")
                        let route = self.audioSession.currentRoute
                        NSLog("✅ [VoiceCallSession] Route after reconfig - outputs: \(route.outputs.map { $0.portType.rawValue })")
                    } catch {
                        NSLog("❌ [VoiceCallSession] Audio reconfigure failed: \(error.localizedDescription)")
                    }
                    
                    // Best-effort earpiece (may not stick due to WebContent .defaultToSpeaker)
                    self.setAudioOutput("earpiece")
                    self.startEarpieceMonitor()
                }
                
                // CRITICAL: Force fresh getUserMedia after 1.0s to get unmuted mic track.
                // The original track (created while CallKit was active) stays muted=true permanently.
                // A fresh getUserMedia after CallKit dismiss returns muted=false.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    guard let self = self else { return }
                    NSLog("🎤 [VoiceCallSession] Triggering forceRefreshMicrophone after CallKit dismiss")
                    self.sendToWebView("if (typeof forceRefreshMicrophone === 'function') forceRefreshMicrophone();")
                }
                // Retry in case first attempt was too early
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    guard let self = self else { return }
                    self.sendToWebView("if (typeof forceRefreshMicrophone === 'function') forceRefreshMicrophone();")
                }
            } else if !payload.isSender && callKitDismissed {
                NSLog("🎤 [VoiceCallSession] CallKit already dismissed - forcing earpiece + mic NOW")
                setAudioOutput("earpiece")
                sendToWebView("if (typeof ensureLocalMicActive === 'function') ensureLocalMicActive('onCallConnected_postDismiss');")
            } else {
                // Outgoing or CallKit not ready: force activation
                NSLog("🎤 [VoiceCallSession] Force activating audio session NOW")
                lastAudioActivationTime = 0
                ensureAudioSessionActive()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    self?.lastAudioActivationTime = 0
                    self?.ensureAudioSessionActive()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.lastAudioActivationTime = 0
                    self?.ensureAudioSessionActive()
                }
                DispatchQueue.main.async { [weak self] in
                    self?.setAudioOutput("earpiece")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self?.setAudioOutput("earpiece") }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self?.setAudioOutput("earpiece") }
                }
            }

            // Ask JS layer to verify/recover local mic stream (fixes iOS tracks that start as muted)
            sendToWebView("if (typeof ensureLocalMicActive === 'function') ensureLocalMicActive('native_onCallConnected');")
            
            // Log audio session status
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
                guard let self = self else { return }
                NSLog("🎤🎤🎤 [VoiceCallSession] ========================================")
                NSLog("🎤 [VoiceCallSession] Post-activation check (after 0.7s):")
                NSLog("🎤 [VoiceCallSession] - Category: \(self.audioSession.category.rawValue)")
                NSLog("🎤 [VoiceCallSession] - Mode: \(self.audioSession.mode.rawValue)")
                NSLog("🎤 [VoiceCallSession] - Input available: \(self.audioSession.isInputAvailable)")
                NSLog("🎤 [VoiceCallSession] - Input gain: \(self.audioSession.inputGain)")
                NSLog("🎤 [VoiceCallSession] - Current route: \(self.audioSession.currentRoute)")
                
                let inputs = self.audioSession.currentRoute.inputs
                NSLog("🎤 [VoiceCallSession] - Input ports: \(inputs.map { $0.portType.rawValue })")
                let outputs = self.audioSession.currentRoute.outputs
                NSLog("🎤 [VoiceCallSession] - Output ports: \(outputs.map { $0.portType.rawValue })")
                NSLog("🎤🎤🎤 [VoiceCallSession] ========================================")
            }
        case "sendBroadcast":
            break
        case "endCall":
            endCall()
        case "callOnBackPressed":
            NSLog("📞 [VoiceCallSession] callOnBackPressed")
            if payload.isSender {
                sendRemoveCallNotificationIfNeeded()
            }
            stopRingtone(reason: "back_pressed")
            disableProximitySensor()
            shouldDismiss = true
        case "addMemberBtn":
            break
        case "onPageReady":
            handlePageReady()
        case "testInterface":
            break
        case "sendRejoinSignal":
            break
        case "setSpeakerphoneOn":
            // Always force earpiece — never allow speaker mode
            NSLog("🔊 [VoiceCallSession] setSpeakerphoneOn BLOCKED - always earpiece")
            setAudioOutput("earpiece")
        case "isWifiConnected":
            break
        default:
            break
        }
    }

    private func handlePageReady() {
        sendToWebView("setRoomId('\(jsEscaped(roomId))')")
        let safePhoto = payload.receiverPhoto.isEmpty ? "user.svg" : payload.receiverPhoto
        let safeName = payload.receiverName.isEmpty ? "Name" : payload.receiverName
        sendToWebView("setCallerInfo('\(jsEscaped(myName))', '\(jsEscaped(myPhoto))', 'self')")
        sendToWebView("setRemoteCallerInfo('\(jsEscaped(safePhoto))', '\(jsEscaped(safeName))')")
        sendToWebView("setThemeColor('\(jsEscaped(Constant.themeColor))')")
        updateBluetoothAvailability()
        // Set earpiece as default when page is ready (outgoing only - CallKit handles incoming)
        if payload.isSender {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.setAudioOutput("earpiece")
            }
        } else if callKitDismissed {
            // Only nudge audio AFTER CallKit is dismissed (fallback path).
            // When CallKit is still active, it manages audio session with earpiece routing.
            // Touching the audio session would interfere with CallKit's configuration.
            NSLog("🎤 [VoiceCallSession] handlePageReady: Nudging audio session (CallKit dismissed)")
            do {
                try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .mixWithOthers])
                try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
                if let builtInMic = audioSession.availableInputs?.first(where: { $0.portType == .builtInMic }) {
                    try audioSession.setPreferredInput(builtInMic)
                }
                try audioSession.overrideOutputAudioPort(.none)
                NSLog("✅ [VoiceCallSession] Audio session nudged: .playAndRecord + .default + active")
                let route = audioSession.currentRoute
                NSLog("✅ [VoiceCallSession] Route after nudge - inputs: \(route.inputs.map { $0.portType.rawValue }), outputs: \(route.outputs.map { $0.portType.rawValue })")
            } catch {
                NSLog("⚠️ [VoiceCallSession] Audio session nudge failed: \(error.localizedDescription)")
            }
        } else if CallKitManager.shared.isAudioSessionReady {
            // CallKit is ACTIVE and managing audio - hands off!
            // Just log the current route for debugging
            let route = audioSession.currentRoute
            NSLog("📞 [VoiceCallSession] handlePageReady: CallKit ACTIVE - hands off audio session")
            NSLog("📞 [VoiceCallSession] Current route - inputs: \(route.inputs.map { $0.portType.rawValue }), outputs: \(route.outputs.map { $0.portType.rawValue })")
        }
    }

    private func handleSendPeerId(_ peerId: String) {
        myPeerId = peerId

        guard let databaseRef else { return }
        let peerPayload: [String: Any] = [
            "peerId": peerId,
            "name": myName,
            "photo": myPhoto.isEmpty ? "user.svg" : myPhoto
        ]

        if let data = try? JSONSerialization.data(withJSONObject: peerPayload, options: []),
           let jsonString = String(data: data, encoding: .utf8) {
            databaseRef.child("rooms").child(roomId).child("peers").child(peerId).setValue(jsonString)
        }
    }

    private func setupFirebaseListeners() {
        guard let databaseRef else { return }
        guard peersHandle == nil else { return } // Already set up (e.g. incoming call did it in start())

        peersHandle = databaseRef.child("rooms").child(roomId).child("peers")
            .observe(.value) { [weak self] snapshot in
                guard let self else { return }
                var peerIds: [String] = []
                var seen = Set<String>()

                for child in snapshot.children {
                    guard
                        let childSnapshot = child as? DataSnapshot,
                        let value = childSnapshot.value as? String,
                        let data = value.data(using: .utf8),
                        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                    else { continue }

                    let peerId = json["peerId"] as? String ?? ""
                    if peerId.isEmpty || seen.contains(peerId) { continue }
                    seen.insert(peerId)
                    peerIds.append(peerId)

                    let name = json["name"] as? String ?? "Peer \(peerId)"
                    let photo = json["photo"] as? String ?? "user.svg"
                    sendToWebView("setCallerInfo('\(jsEscaped(name))', '\(jsEscaped(photo))', '\(jsEscaped(peerId))')")
                }

                // Android parity: when peer count drops to 0 (room deleted by other side),
                // auto-end the call on this side too (setupDeleteListers behavior).
                // IMPORTANT: Only trigger after our own peer has been written (myPeerId != nil).
                // Before that, peerCount=0 is expected (empty room at call start).
                let peerCount = snapshot.childrenCount
                NSLog("📞 [VoiceCallSession] Peers listener: peerCount=\(peerCount), myPeerId=\(self.myPeerId ?? "nil")")
                if peerCount == 0 && !self.isCallEnded && self.myPeerId != nil {
                    NSLog("📞 [VoiceCallSession] Peers dropped to 0 - other side ended call, auto-ending")
                    DispatchQueue.main.async {
                        self.endCall()
                    }
                    return
                }

                if let peersJsonData = try? JSONSerialization.data(withJSONObject: ["peers": peerIds], options: []),
                   let peersJson = String(data: peersJsonData, encoding: .utf8) {
                    sendToWebView("updatePeers(\(peersJson))")
                }
            }

        signalingHandle = databaseRef.child("rooms").child(roomId).child("signaling")
            .observe(.value) { [weak self] snapshot in
                guard let self else { return }
                for child in snapshot.children {
                    guard let childSnapshot = child as? DataSnapshot,
                          let value = childSnapshot.value as? String,
                          let data = value.data(using: .utf8),
                          let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                    else { continue }

                    let receiver = jsonObject["receiver"] as? String ?? ""
                    if receiver == myPeerId || receiver == "all" {
                        if let jsonString = String(data: data, encoding: .utf8) {
                            sendToWebView("handleSignalingData(\(jsonString))")
                            childSnapshot.ref.removeValue()
                        }
                    }
                }
            }
    }

    private func cleanupFirebaseListeners() {
        guard let databaseRef else { return }
        if let peersHandle {
            databaseRef.child("rooms").child(roomId).child("peers").removeObserver(withHandle: peersHandle)
            self.peersHandle = nil
        }
        if let signalingHandle {
            databaseRef.child("rooms").child(roomId).child("signaling").removeObserver(withHandle: signalingHandle)
            self.signalingHandle = nil
        }
        // Android parity: remove entire room when call ended so the other side
        // sees peerCount=0 and auto-ends. Only remove entire room if endCall() was triggered.
        // Otherwise just remove own peer (e.g. stop() called during view lifecycle).
        if isCallEnded {
            databaseRef.child("rooms").child(roomId).removeValue { error, _ in
                if let error = error {
                    NSLog("⚠️ [VoiceCallSession] Failed to remove room: \(error.localizedDescription)")
                } else {
                    NSLog("✅ [VoiceCallSession] Room removed: \(self.roomId)")
                }
            }
        } else if let peerId = myPeerId {
            databaseRef.child("rooms").child(roomId).child("peers").child(peerId).removeValue()
        }
    }

    private func requestMicrophonePermissionIfNeeded() {
        switch audioSession.recordPermission {
        case .granted:
            return
        case .denied:
            Constant.showToast(message: "Microphone permission is required for voice calls.")
        case .undetermined:
            audioSession.requestRecordPermission { granted in
                if !granted {
                    DispatchQueue.main.async {
                        Constant.showToast(message: "Microphone permission is required for voice calls.")
                    }
                }
            }
        @unknown default:
            break
        }
    }

    private func checkMicrophonePermission() {
        // For incoming CallKit calls, check/request permission
        // And ensure audio session is ready when permission exists
        switch audioSession.recordPermission {
        case .granted:
            NSLog("✅ [VoiceCallSession] Microphone permission already granted")
            print("✅ [VoiceCallSession] Microphone permission already granted")
            
            // CRITICAL: If CallKit already activated the session, do NOT touch it at all.
            // Any audio session manipulation (even overrideOutputAudioPort) prevents
            // WKWebView track from transitioning muted=true → muted=false.
            if !payload.isSender && CallKitManager.shared.isAudioSessionReady {
                NSLog("🎤 [VoiceCallSession] CallKit already configured audio - completely hands off!")
                return
            }
            
            // For incoming calls when CallKit hasn't activated yet, delay activation
            let delay: TimeInterval = 0.3
            NSLog("🎤 [VoiceCallSession] Will activate audio session in \(delay)s...")
            print("🎤 [VoiceCallSession] Configuring audio session for incoming call...")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                NSLog("🎤 [VoiceCallSession] Now activating audio session for CallKit call")
                self?.ensureAudioSessionActive()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    NSLog("🎤 [VoiceCallSession] Second audio session activation (ensure it sticks)")
                    self?.ensureAudioSessionActive()
                }
            }
        case .denied:
            DispatchQueue.main.async {
                Constant.showToast(message: "Microphone permission is required for voice calls.")
            }
        case .undetermined:
            NSLog("🎤 [VoiceCallSession] Requesting microphone permission...")
            print("🎤 [VoiceCallSession] Requesting microphone permission...")
            audioSession.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        NSLog("✅ [VoiceCallSession] Microphone permission granted")
                        print("✅ [VoiceCallSession] Microphone permission granted")
                        // Activate audio session now that we have permission
                        self?.ensureAudioSessionActive()
                    } else {
                        Constant.showToast(message: "Microphone permission is required for voice calls.")
                    }
                }
            }
        @unknown default:
            break
        }
    }
    
    private func requestMicrophoneAccess() {
        switch audioSession.recordPermission {
        case .granted:
            ensureAudioSessionActive()
        case .denied:
            DispatchQueue.main.async {
                Constant.showToast(message: "Microphone permission is required for voice calls.")
            }
        case .undetermined:
            audioSession.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.ensureAudioSessionActive()
                    } else {
                        Constant.showToast(message: "Microphone permission is required for voice calls.")
                    }
                }
            }
        @unknown default:
            break
        }
    }

    private func startObservingAudioInterruptions() {
        guard interruptionObserver == nil else { return }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let info = notification.userInfo,
                  let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            
            switch type {
            case .began:
                // Interruption began (e.g., phone call, system)
                self.isAudioInterrupted = true
            case .ended:
                self.isAudioInterrupted = false
                // For incoming CallKit calls BEFORE dismiss, do NOT touch audio session.
                // After CallKit is dismissed, we MUST manage audio ourselves.
                if !self.payload.isSender && CallKitManager.shared.isAudioSessionReady && !self.callKitDismissed {
                    NSLog("\u{1F3A4} [VoiceCallSession] Interruption ended - hands off (incoming CallKit call)")
                } else {
                    // Resume audio when interruption ends (outgoing calls only)
                    if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                        if options.contains(.shouldResume) {
                            self.ensureAudioSessionActive()
                            if self.shouldForceEarpiece {
                                self.setAudioOutput("earpiece")
                            }
                        }
                    } else {
                        self.ensureAudioSessionActive()
                        if self.shouldForceEarpiece {
                            self.setAudioOutput("earpiece")
                        }
                    }
                }
            @unknown default:
                break
            }
        }
        
        // Observe route changes to ensure earpiece is maintained
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
            
            // Prevent recursive calls - if we're already setting earpiece, ignore
            if self.isSettingEarpiece {
                return
            }
            
            // Debounce - don't react to route changes too frequently
            let now = Date().timeIntervalSince1970
            if now - self.lastEarpieceSetTime < 0.5 {
                return
            }
            
            let route = self.audioSession.currentRoute
            let outputs = route.outputs.map { $0.portType }
            let outputStrings = route.outputs.map { $0.portType.rawValue }
            print("🔊 [VoiceCallSession] Route changed (reason: \(reason.rawValue)). Outputs: \(outputStrings)")
            
            // For incoming CallKit calls BEFORE dismiss, do NOT force earpiece.
            // After CallKit is dismissed, we MUST enforce earpiece ourselves.
            if !self.payload.isSender && CallKitManager.shared.isAudioSessionReady && !self.callKitDismissed {
                return
            }
            
            // If route changed to speaker and we want earpiece, force it back
            let hasSpeaker = outputs.contains(.builtInSpeaker)
            let hasReceiver = outputs.contains(.builtInReceiver)
            
            // For reason 8 (category change), be more aggressive since WebRTC might be changing it
            let isCategoryChange = reason == .categoryChange
            let minDelay: TimeInterval = isCategoryChange ? 0.3 : 0.5
            
            if self.shouldForceEarpiece && hasSpeaker && !hasReceiver {
                if now - self.lastEarpieceSetTime > minDelay {
                    print("⚠️ [VoiceCallSession] Route changed to speaker (reason: \(reason.rawValue)), forcing back to earpiece...")
                    self.lastEarpieceSetTime = now
                    if isCategoryChange {
                        self.forceEarpieceImmediate()
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.forceEarpieceImmediate()
                        }
                    }
                }
            }
        }
    }

    private func stopObservingAudioInterruptions() {
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
            interruptionObserver = nil
        }
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            routeChangeObserver = nil
        }
    }
    
    private func startEarpieceMonitor() {
        stopEarpieceMonitor()
        earpieceForceRetryCount = 0
        // Periodically check and enforce earpiece routing
        earpieceMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard self.shouldForceEarpiece else { return }
            guard !self.isSettingEarpiece else { return }
            guard self.audioSession.recordPermission == .granted else { return }
            guard self.isCallConnected else { return }
            
            let route = self.audioSession.currentRoute
            let outputs = route.outputs.map { $0.portType }
            let hasSpeaker = outputs.contains(.builtInSpeaker)
            let hasReceiver = outputs.contains(.builtInReceiver)
            
            if hasSpeaker && !hasReceiver {
                // Stop after 5 failed attempts (2.5 seconds).
                // WebContent's .defaultToSpeaker can't be overridden from app side.
                // More retries just create AudioSession interrupt spam.
                guard self.earpieceForceRetryCount < 5 else {
                    NSLog("🛑 [VoiceCallSession] Earpiece monitor: max retries reached (WebContent .defaultToSpeaker limitation)")
                    self.stopEarpieceMonitor()
                    return
                }
                self.earpieceForceRetryCount += 1
                let now = Date().timeIntervalSince1970
                if now - self.lastEarpieceSetTime > 0.5 {
                    print("⚠️ [VoiceCallSession] Monitor detected speaker routing (attempt \(self.earpieceForceRetryCount)/5), forcing earpiece...")
                    self.forceEarpieceImmediate()
                }
            } else if hasReceiver {
                // Reset retry count when earpiece is successfully active
                if self.earpieceForceRetryCount > 0 {
                    NSLog("✅ [VoiceCallSession] Earpiece confirmed active - resetting retry count")
                    self.earpieceForceRetryCount = 0
                }
            }
        }
    }
    
    private func stopEarpieceMonitor() {
        earpieceMonitorTimer?.invalidate()
        earpieceMonitorTimer = nil
    }

    private func ensureAudioSessionActive() {
        // For incoming CallKit calls BEFORE dismiss, do NOT touch the audio session.
        // After CallKit is dismissed, we MUST manage audio ourselves.
        if !payload.isSender && CallKitManager.shared.isAudioSessionReady && !callKitDismissed {
            NSLog("🚫 [VoiceCallSession] ensureAudioSessionActive BLOCKED - CallKit still active, hands off!")
            return
        }
        guard audioSession.recordPermission == .granted else {
            NSLog("⚠️ [VoiceCallSession] Cannot activate audio - permission not granted")
            return
        }
        guard !isAudioInterrupted else {
            NSLog("⚠️ [VoiceCallSession] Cannot activate audio - interrupted")
            return
        }
        let now = Date().timeIntervalSince1970
        if now - lastAudioActivationTime < 0.5 {
            NSLog("ℹ️ [VoiceCallSession] Skipping activation - too soon (debounced)")
            return
        }
        lastAudioActivationTime = now
        
        NSLog("🎤 [VoiceCallSession] ensureAudioSessionActive called")
        print("🎤 [VoiceCallSession] ensureAudioSessionActive called")
        
        do {
            // Use .default mode (NOT .voiceChat which conflicts with WebRTC → muted=true)
            // Always use .mixWithOthers (REQUIRED for WebContent to function)
            NSLog("🎤 [VoiceCallSession] Setting .default mode + .mixWithOthers")
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .mixWithOthers])
            
            if payload.isSender {
                NSLog("🎤 [VoiceCallSession] Activating audio session (outgoing call)")
                try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
                NSLog("✅ [VoiceCallSession] Audio session activated (outgoing call)")
            } else {
                NSLog("🎤 [VoiceCallSession] Activating audio session (incoming call)")
                do {
                    try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
                    NSLog("✅ [VoiceCallSession] Audio session activated (incoming call)")
                } catch {
                    NSLog("ℹ️ [VoiceCallSession] Audio session already active: \(error.localizedDescription)")
                }
            }
            // Route to earpiece by default - must be called after setActive
            if shouldForceEarpiece {
                if let builtInMic = audioSession.availableInputs?.first(where: { $0.portType == .builtInMic }) {
                    try audioSession.setPreferredInput(builtInMic)
                }
                try audioSession.overrideOutputAudioPort(.none)
                lastEarpieceSetTime = now
            }
            // Verify the route is set correctly and enforce earpiece if needed
            let route = audioSession.currentRoute
            let outputs = route.outputs.map { $0.portType }
            let outputStrings = route.outputs.map { $0.portType.rawValue }
            print("🔊 [VoiceCallSession] Audio route outputs: \(outputStrings)")
            let hasReceiver = outputs.contains(.builtInReceiver)
            let hasSpeaker = outputs.contains(.builtInSpeaker)
            if shouldForceEarpiece && !hasReceiver && hasSpeaker {
                print("⚠️ [VoiceCallSession] Warning: Audio still routing to speaker, forcing earpiece immediately...")
                // Force immediately and retry multiple times
                forceEarpieceImmediate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    self?.forceEarpieceImmediate()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.forceEarpieceImmediate()
                }
            }
        } catch {
            print("⚠️ [VoiceCallSession] Audio session error: \(error.localizedDescription)")
        }
    }

    private func forceEarpieceImmediate() {
        // For incoming CallKit calls BEFORE dismiss, hands off.
        // After CallKit is dismissed, we MUST force earpiece ourselves.
        if !payload.isSender && CallKitManager.shared.isAudioSessionReady && !callKitDismissed {
            return
        }
        guard audioSession.recordPermission == .granted else { return }
        guard !isAudioInterrupted else { return }
        guard !isSettingEarpiece else { return }
        
        isSettingEarpiece = true
        defer { 
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.isSettingEarpiece = false
            }
        }
        
        // Use .default mode (NOT .voiceChat which conflicts with WebRTC → muted=true)
        // Always use .mixWithOthers (REQUIRED for WebContent to function)
        // After 3 failed attempts, use aggressive approach: deactivate then reactivate
        let useAggressive = earpieceForceRetryCount >= 3
        
        do {
            if payload.isSender || callKitDismissed {
                if useAggressive {
                    // Aggressive: Deactivate first to reset audio routing, then reactivate
                    // Still use .mixWithOthers so WebContent keeps functioning
                    NSLog("💥 [VoiceCallSession] Aggressive earpiece: deactivate → reactivate .default (attempt \(earpieceForceRetryCount))")
                    try audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
                    try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .mixWithOthers])
                    try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
                } else {
                    try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .mixWithOthers])
                    try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
                }
                if let builtInMic = audioSession.availableInputs?.first(where: { $0.portType == .builtInMic }) {
                    try audioSession.setPreferredInput(builtInMic)
                }
            }
            try audioSession.overrideOutputAudioPort(.none)
            lastEarpieceSetTime = Date().timeIntervalSince1970
            
            // Verify after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                guard let self = self else { return }
                let route = self.audioSession.currentRoute
                let outputs = route.outputs.map { $0.portType }
                let outputStrings = route.outputs.map { $0.portType.rawValue }
                let hasReceiver = outputs.contains(.builtInReceiver)
                let hasSpeaker = outputs.contains(.builtInSpeaker)
                NSLog("🔊 [VoiceCallSession] Force earpiece result (aggressive=\(useAggressive)): \(outputStrings)")
                
                if hasReceiver && !hasSpeaker {
                    NSLog("✅ [VoiceCallSession] Earpiece routing CONFIRMED!")
                    self.earpieceForceRetryCount = 0
                } else if hasSpeaker && !hasReceiver {
                    // If aggressive reactivate didn't stick, try override again
                    if useAggressive {
                        NSLog("⚠️ [VoiceCallSession] Aggressive didn't stick, retrying override...")
                        do {
                            try self.audioSession.overrideOutputAudioPort(.none)
                        } catch {
                            NSLog("⚠️ [VoiceCallSession] Retry override failed: \(error.localizedDescription)")
                        }
                    }
                }
            }
        } catch {
            NSLog("⚠️ [VoiceCallSession] Failed to force earpiece (aggressive=\(useAggressive)): \(error.localizedDescription)")
        }
    }
    
    private func setAudioOutput(_ output: String) {
        // For incoming CallKit calls, do NOT touch audio while CallKit is still active.
        // Once CallKit is dismissed (callKitDismissed=true), we MUST reconfigure audio ourselves.
        if !payload.isSender && !callKitDismissed {
            NSLog("🚫 [VoiceCallSession] setAudioOutput('\(output)') BLOCKED - CallKit still active, hands off!")
            return
        }
        guard audioSession.recordPermission == .granted else { return }
        guard !isAudioInterrupted else { return }
        
        do {
            switch output {
            case "speaker":
                // BLOCKED: Always force earpiece — never allow speaker mode
                NSLog("🔊 [VoiceCallSession] Speaker request BLOCKED - forcing earpiece instead")
                shouldForceEarpiece = true
                guard !isSettingEarpiece else { return }
                isSettingEarpiece = true
                defer { isSettingEarpiece = false }
                try audioSession.overrideOutputAudioPort(.none)
                print("🔊 [VoiceCallSession] Audio output forced to EARPIECE (speaker blocked)")
            case "earpiece":
                shouldForceEarpiece = true
                guard !isSettingEarpiece else { return }
                
                isSettingEarpiece = true
                defer { isSettingEarpiece = false }
                
                // Use .default mode (NOT .voiceChat which conflicts with WebRTC → muted=true)
                // .mixWithOthers REQUIRED for WebContent to function
                // No .defaultToSpeaker → .playAndRecord defaults to earpiece (Receiver)
                if payload.isSender || callKitDismissed {
                    NSLog("🔊 [VoiceCallSession] Earpiece: .default mode + .mixWithOthers")
                    try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .mixWithOthers])
                    try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
                    if let builtInMic = audioSession.availableInputs?.first(where: { $0.portType == .builtInMic }) {
                        try audioSession.setPreferredInput(builtInMic)
                    }
                }
                try audioSession.overrideOutputAudioPort(.none)
                lastEarpieceSetTime = Date().timeIntervalSince1970
                
                // Verify it's actually set to earpiece
                let route = audioSession.currentRoute
                let outputs = route.outputs.map { $0.portType }
                let outputStrings = route.outputs.map { $0.portType.rawValue }
                print("🔊 [VoiceCallSession] Audio output set to EARPIECE. Current route: \(outputStrings)")
                let hasSpeaker = outputs.contains(.builtInSpeaker)
                let hasReceiver = outputs.contains(.builtInReceiver)
                if hasSpeaker && !hasReceiver {
                    print("⚠️ [VoiceCallSession] Earpiece override failed, will retry via route observer...")
                    // Don't retry here to avoid loops - let route observer handle it
                }
            case "bluetooth":
                try audioSession.overrideOutputAudioPort(.none)
                if let bluetoothInput = audioSession.availableInputs?.first(where: { $0.portType == .bluetoothHFP || $0.portType == .bluetoothA2DP }) {
                    try audioSession.setPreferredInput(bluetoothInput)
                }
            default:
                break
            }
        } catch {
            print("⚠️ [VoiceCallSession] Failed to set audio output: \(error.localizedDescription)")
        }
    }

    private func setMicrophoneMuted(_ muted: Bool) {
        if audioSession.isInputGainSettable {
            do {
                try audioSession.setInputGain(muted ? 0.0 : 1.0)
            } catch {
                print("⚠️ [VoiceCallSession] Failed to set input gain: \(error.localizedDescription)")
            }
        }
        UserDefaults.standard.set(muted, forKey: "voice_call_muted")
    }

    /// Toggle mute state and sync to native audio + WebView (stream and mute button UI).
    func toggleMute() {
        isMuted.toggle()
        setMicrophoneMuted(isMuted)
        let js = "if (typeof setMuteFromNative === 'function') setMuteFromNative(\(isMuted));"
        sendToWebView(js)
    }

    private func updateBluetoothAvailability() {
        let hasBluetooth = audioSession.availableInputs?.contains(where: { input in
            input.portType == .bluetoothHFP || input.portType == .bluetoothA2DP
        }) ?? false
        sendToWebView("setBluetoothAvailability(\(hasBluetooth ? "true" : "false"))")
    }

    private func endCall() {
        guard !isCallEnded else {
            NSLog("📞 [VoiceCallSession] endCall() IGNORED - already ended")
            return
        }
        isCallEnded = true
        NSLog("📞 [VoiceCallSession] User ended call")
        print("📞 [VoiceCallSession] Ending call and dismissing...")

        // Android behavior parity: sender sends removeCallNotification to dismiss
        // receiver's incoming-call/CallKit UI. Only sender sends (receiver's payload.receiverId
        // points to themselves, not the sender).
        if payload.isSender {
            sendRemoveCallNotificationIfNeeded()
        }
        // Always clean up any removeCallNotification entries addressed to us
        cleanupRemoveCallNotificationForSelf()
        
        stopRingtone(reason: "end_call")
        cleanupFirebaseListeners()
        disableProximitySensor()
        
        // End CallKit call if this was an incoming CallKit call
        if !payload.isSender {
            if let callKitUUID = CallKitManager.shared.getCallUUID(for: roomId) {
                NSLog("📞📞📞 [VoiceCallSession] ========================================")
                NSLog("📞 [VoiceCallSession] Ending CallKit call: \(callKitUUID)")
                NSLog("📞 [VoiceCallSession] Room: \(roomId)")
                NSLog("📞 [VoiceCallSession] Dismissing CallKit full-screen UI NOW")
                NSLog("📞📞📞 [VoiceCallSession] ========================================")
                print("📞 [VoiceCallSession] Dismissing CallKit full-screen UI...")
                CallKitManager.shared.endCall(uuid: callKitUUID, reason: .remoteEnded)
            } else {
                NSLog("⚠️ [VoiceCallSession] No active CallKit call found for room: \(roomId)")
                print("⚠️ [VoiceCallSession] CallKit call may have already ended")
            }
        }
        
        shouldDismiss = true
    }

    private func sendRemoveCallNotificationIfNeeded() {
        guard !removeCallNotificationSent else { return }
        let receiverId = payload.receiverId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !receiverId.isEmpty else {
            NSLog("⚠️ [VoiceCallSession] sendRemoveCallNotification: receiverId missing")
            return
        }
        removeCallNotificationSent = true

        let ref = Database.database().reference().child("removeCallNotification").child(receiverId).childByAutoId()
        let key = ref.key ?? UUID().uuidString
        ref.setValue(key) { error, _ in
            if let error = error {
                NSLog("⚠️ [VoiceCallSession] Failed to send removeCallNotification: \(error.localizedDescription)")
            } else {
                NSLog("✅ [VoiceCallSession] removeCallNotification sent to receiverId=\(receiverId), key=\(key)")
            }
        }
    }

    /// Clean up any removeCallNotification entries addressed to our own UID
    /// so they don't pile up in Firebase.
    private func cleanupRemoveCallNotificationForSelf() {
        let myUid = self.myUid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !myUid.isEmpty else { return }
        Database.database().reference().child("removeCallNotification").child(myUid).removeValue { error, _ in
            if let error = error {
                NSLog("⚠️ [VoiceCallSession] Failed to cleanup removeCallNotification for self: \(error.localizedDescription)")
            } else {
                NSLog("✅ [VoiceCallSession] Cleaned up removeCallNotification for myUid=\(myUid)")
            }
        }
    }

    private func sendToWebView(_ javascript: String) {
        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript("javascript:\(javascript)", completionHandler: nil)
        }
    }

    private func startRingtone() {
        guard ringtonePlayer == nil else { return }
        print("🔔 [VoiceCallRingtone] Starting ringtone for sender...")

        let mp3Url = Bundle.main.url(forResource: "ringtone", withExtension: "mp3", subdirectory: "VoiceCallAssets")
            ?? Bundle.main.url(forResource: "ringtone", withExtension: "mp3")
        let wavUrl = Bundle.main.url(forResource: "ringtone", withExtension: "wav", subdirectory: "VoiceCallAssets")
            ?? Bundle.main.url(forResource: "ringtone", withExtension: "wav")

        let candidateUrls = [mp3Url, wavUrl].compactMap { $0 }
        guard let ringtoneUrl = candidateUrls.first else {
            print("⚠️ [VoiceCallRingtone] Ringtone asset not found in bundle.")
            return
        }
        print("🔔 [VoiceCallRingtone] Using asset: \(ringtoneUrl.lastPathComponent)")
        if let size = fileSize(at: ringtoneUrl) {
            print("🔔 [VoiceCallRingtone] Asset size: \(size) bytes")
        }

        do {
            // Configure audio routing for ringtone playback (earpiece).
            // Use .playAndRecord with .voiceChat mode to ensure earpiece routing
            // CRITICAL: Add .mixWithOthers to allow WKWebView getUserMedia() to work
            try audioSession.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.allowBluetooth, .mixWithOthers]
            )
            try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
            // Route to earpiece - this works better with .playAndRecord category
            if let builtInMic = audioSession.availableInputs?.first(where: { $0.portType == .builtInMic }) {
                try audioSession.setPreferredInput(builtInMic)
            }
            try audioSession.overrideOutputAudioPort(.none)
            let route = audioSession.currentRoute
            let outputs = route.outputs.map { "\($0.portType.rawValue)" }.joined(separator: ", ")
            let inputs = route.inputs.map { "\($0.portType.rawValue)" }.joined(separator: ", ")
            print("🔔 [VoiceCallRingtone] Audio route inputs: \(inputs) outputs: \(outputs)")

            var lastError: Error?
            var player: AVAudioPlayer?
            for url in candidateUrls {
                do {
                    let candidatePlayer = try AVAudioPlayer(contentsOf: url)
                    candidatePlayer.numberOfLoops = -1
                    candidatePlayer.volume = 1.0
                    candidatePlayer.prepareToPlay()
                    player = candidatePlayer
                    print("🔔 [VoiceCallRingtone] AVAudioPlayer ready: \(url.lastPathComponent)")
                    break
                } catch {
                    lastError = error
                    print("⚠️ [VoiceCallRingtone] AVAudioPlayer failed for \(url.lastPathComponent): \(error.localizedDescription)")
                }
            }

            guard let activePlayer = player else {
                if let lastError {
                    print("⚠️ [VoiceCallRingtone] Failed to start ringtone: \(lastError.localizedDescription)")
                } else {
                    print("⚠️ [VoiceCallRingtone] Failed to start ringtone: unknown error")
                }
                startSystemRingtoneFallback()
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self else { return }
                // Verify earpiece routing before playing
                do {
                    // Ensure we're using the right category for earpiece
                    // CRITICAL: Add .mixWithOthers to allow WKWebView getUserMedia() to work
                    try self.audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .mixWithOthers])
                    try self.audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
                    if let builtInMic = self.audioSession.availableInputs?.first(where: { $0.portType == .builtInMic }) {
                        try self.audioSession.setPreferredInput(builtInMic)
                    }
                    
                    let route = self.audioSession.currentRoute
                    let outputs = route.outputs.map { $0.portType }
                    let hasSpeaker = outputs.contains(.builtInSpeaker)
                    let hasReceiver = outputs.contains(.builtInReceiver)
                    if hasSpeaker && !hasReceiver {
                        print("🔔 [VoiceCallRingtone] Ensuring earpiece before play...")
                        try self.audioSession.overrideOutputAudioPort(.none)
                    } else {
                        // Still override to ensure it stays on earpiece
                        try self.audioSession.overrideOutputAudioPort(.none)
                    }
                } catch {
                    print("⚠️ [VoiceCallRingtone] Failed to verify earpiece: \(error.localizedDescription)")
                }
                
                if !activePlayer.isPlaying {
                    activePlayer.play()
                }
                self.ringtonePlayer = activePlayer
                print("🔔 [VoiceCallRingtone] isPlaying=\(activePlayer.isPlaying)")
                self.startRingtoneKeepAlive()
            }
        } catch {
            print("⚠️ [VoiceCallRingtone] Failed to start ringtone: \(error.localizedDescription)")
            startSystemRingtoneFallback()
        }
    }

    private func stopRingtone(reason: String) {
        if ringtonePlayer != nil {
            print("🔕 [VoiceCallRingtone] Stopping ringtone (reason=\(reason))")
        }
        ringtoneKeepAliveTimer?.invalidate()
        ringtoneKeepAliveTimer = nil
        ringtonePlayer?.stop()
        ringtonePlayer = nil
        stopSystemRingtoneFallback()
    }

    private func startRingtoneKeepAlive() {
        ringtoneKeepAliveTimer?.invalidate()
        var lastRouteCheckTime: TimeInterval = 0
        ringtoneKeepAliveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard !self.isCallConnected else { return }
            guard let player = self.ringtonePlayer else { return }
            
            let now = Date().timeIntervalSince1970
            
            // Check audio route and force earpiece if needed (but not too frequently)
            if now - lastRouteCheckTime > 1.0 {
                lastRouteCheckTime = now
                let route = self.audioSession.currentRoute
                let outputs = route.outputs.map { $0.portType }
                let hasSpeaker = outputs.contains(.builtInSpeaker)
                let hasReceiver = outputs.contains(.builtInReceiver)
                
                // If routing to speaker instead of earpiece, force earpiece
                if hasSpeaker && !hasReceiver {
                    print("🔔 [VoiceCallRingtone] Route changed to speaker, forcing earpiece...")
                    do {
                        // Use .playAndRecord with .voiceChat for earpiece routing
                        // CRITICAL: Add .mixWithOthers to allow WKWebView getUserMedia() to work
                        try self.audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .mixWithOthers])
                        try self.audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
                        if let builtInMic = self.audioSession.availableInputs?.first(where: { $0.portType == .builtInMic }) {
                            try self.audioSession.setPreferredInput(builtInMic)
                        }
                        try self.audioSession.overrideOutputAudioPort(.none)
                        print("🔔 [VoiceCallRingtone] Earpiece forced for ringtone")
                    } catch {
                        print("⚠️ [VoiceCallRingtone] Failed to force earpiece: \(error.localizedDescription)")
                    }
                }
            }
            
            // Restart player if stopped
            if !player.isPlaying {
                print("🔔 [VoiceCallRingtone] Restarting ringtone (was stopped)")
                do {
                    // Use .playAndRecord with .voiceChat for earpiece routing
                    // CRITICAL: Add .mixWithOthers to allow WKWebView getUserMedia() to work
                    try self.audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .mixWithOthers])
                    try self.audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
                    // Ensure earpiece routing before playing
                    if let builtInMic = self.audioSession.availableInputs?.first(where: { $0.portType == .builtInMic }) {
                        try self.audioSession.setPreferredInput(builtInMic)
                    }
                    try self.audioSession.overrideOutputAudioPort(.none)
                } catch {
                    print("⚠️ [VoiceCallRingtone] Failed to reconfigure audio session: \(error.localizedDescription)")
                }
                player.play()
            }
        }
    }


    private func startSystemRingtoneFallback() {
        if ringtoneSystemSoundId != 0 || ringtoneSystemSoundTimer != nil {
            return
        }

        let wavUrl = Bundle.main.url(forResource: "ringtone", withExtension: "wav", subdirectory: "VoiceCallAssets")
            ?? Bundle.main.url(forResource: "ringtone", withExtension: "wav")
        guard let soundUrl = wavUrl else {
            print("⚠️ [VoiceCallRingtone] System sound fallback failed: wav not found")
            return
        }

        let status = AudioServicesCreateSystemSoundID(soundUrl as CFURL, &ringtoneSystemSoundId)
        if status != kAudioServicesNoError || ringtoneSystemSoundId == 0 {
            if let size = fileSize(at: soundUrl) {
                print("⚠️ [VoiceCallRingtone] System sound wav size: \(size) bytes")
            }
            print("⚠️ [VoiceCallRingtone] System sound fallback failed: status=\(status)")
            return
        }

        print("🔔 [VoiceCallRingtone] Using system sound fallback")
        // Configure audio session for earpiece before starting system sound
        // Use .playAndRecord with .voiceChat for earpiece routing
        do {
            // CRITICAL: Add .mixWithOthers to allow WKWebView getUserMedia() to work
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .mixWithOthers])
            try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
            if let builtInMic = audioSession.availableInputs?.first(where: { $0.portType == .builtInMic }) {
                try audioSession.setPreferredInput(builtInMic)
            }
            try audioSession.overrideOutputAudioPort(.none)
        } catch {
            print("⚠️ [VoiceCallRingtone] Failed to configure audio session for system sound: \(error.localizedDescription)")
        }
        
        ringtoneSystemSoundTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard !self.isCallConnected else { return }
            
            // Check route and force earpiece if needed
            let route = self.audioSession.currentRoute
            let outputs = route.outputs.map { $0.portType }
            let hasSpeaker = outputs.contains(.builtInSpeaker)
            let hasReceiver = outputs.contains(.builtInReceiver)
            
            // If on speaker, reconfigure to earpiece
            if hasSpeaker && !hasReceiver {
                do {
                    // Use .playAndRecord with .voiceChat for earpiece routing
                    // CRITICAL: Add .mixWithOthers to allow WKWebView getUserMedia() to work
                    try self.audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .mixWithOthers])
                    try self.audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
                    if let builtInMic = self.audioSession.availableInputs?.first(where: { $0.portType == .builtInMic }) {
                        try self.audioSession.setPreferredInput(builtInMic)
                    }
                    try self.audioSession.overrideOutputAudioPort(.none)
                    print("🔔 [VoiceCallRingtone] System sound: forced earpiece")
                } catch {
                    print("⚠️ [VoiceCallRingtone] Failed to route system sound to earpiece: \(error.localizedDescription)")
                }
            } else {
                // Just ensure earpiece routing before each playback
                do {
                    try self.audioSession.overrideOutputAudioPort(.none)
                } catch {
                    print("⚠️ [VoiceCallRingtone] Failed to route system sound to earpiece: \(error.localizedDescription)")
                }
            }
            AudioServicesPlaySystemSound(self.ringtoneSystemSoundId)
        }
    }

    private func stopSystemRingtoneFallback() {
        ringtoneSystemSoundTimer?.invalidate()
        ringtoneSystemSoundTimer = nil
        if ringtoneSystemSoundId != 0 {
            AudioServicesDisposeSystemSoundID(ringtoneSystemSoundId)
            ringtoneSystemSoundId = 0
        }
    }

    private func fileSize(at url: URL) -> Int? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int
    }

    private func jsEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private static func generateRoomId() -> String {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let random = Int.random(in: 1000...9999)
        return "\(timestamp)\(random)"
    }
    
    // MARK: - Proximity Sensor Management
    
    private func enableProximitySensor() {
        guard UIDevice.current.isProximityMonitoringEnabled == false else { return }
        
        UIDevice.current.isProximityMonitoringEnabled = true
        print("📱 [VoiceCallSession] Proximity sensor enabled")
        
        // Observe proximity state changes
        proximityObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.proximityStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            let isNear = UIDevice.current.proximityState
            print("📱 [VoiceCallSession] Proximity state changed: \(isNear ? "Near" : "Far")")
            // Re-force earpiece on every proximity transition to prevent speaker leaks
            if self.shouldForceEarpiece {
                do {
                    try self.audioSession.overrideOutputAudioPort(.none)
                    NSLog("📱 [VoiceCallSession] Proximity \(isNear ? "near" : "far") - earpiece re-enforced")
                } catch {
                    NSLog("⚠️ [VoiceCallSession] Proximity earpiece enforce failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func disableProximitySensor() {
        guard UIDevice.current.isProximityMonitoringEnabled == true else { return }
        
        // Remove observer first
        if let observer = proximityObserver {
            NotificationCenter.default.removeObserver(observer)
            proximityObserver = nil
        }
        
        UIDevice.current.isProximityMonitoringEnabled = false
        print("📱 [VoiceCallSession] Proximity sensor disabled")
    }
}
