import Foundation
import FirebaseDatabase
import AVFoundation
import AudioToolbox
import UIKit
import WebRTC

// MARK: - NativeVoiceCallSession
/// Replaces WKWebView-based VoiceCallSession with fully native WebRTC.
/// - Full AVAudioSession control → earpiece works correctly
/// - No WKWebView, no PeerJS, no JavaScript
/// - Same Firebase signaling structure (Android compatible)
final class NativeVoiceCallSession: ObservableObject {

    // MARK: - Published State
    @Published var shouldDismiss = false
    @Published var isCallConnected = false
    @Published var isMuted: Bool
    @Published var isSpeakerOn: Bool = false
    @Published var callerName: String = ""
    @Published var callerPhoto: String = ""
    @Published var callDuration: TimeInterval = 0
    @Published var isBluetoothAvailable: Bool = false

    // MARK: - Private
    private let payload: VoiceCallPayload
    private let roomId: String
    private let myUid: String
    private let myName: String
    private let myPhoto: String
    private let myPeerId: String  // UUID used as peer ID in Firebase

    private var webRTCManager: NativeWebRTCManager?
    private var signalingService: FirebaseSignalingService?

    private let audioSession = AVAudioSession.sharedInstance()
    private var routeChangeObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var proximityObserver: NSObjectProtocol?
    private var callKitAudioReadyObserver: NSObjectProtocol?
    private var earpieceMonitorTimer: Timer?
    private var callTimer: Timer?
    private var ringtonePlayer: AVAudioPlayer?

    private var hasStarted = false
    private var isCallEnded = false
    private var removeCallNotificationSent = false
    private(set) var callKitUUID: UUID?  // Track our CallKit call (outgoing or incoming)
    private var callKitEndObserver: NSObjectProtocol?

    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 3
    private var reconnectTimer: Timer?
    private var disconnectedPeerId: String?  // Track which peer disconnected for ICE restart

    // MARK: - Init
    init(payload: VoiceCallPayload) {
        self.payload = payload
        self.roomId = payload.roomId ?? NativeVoiceCallSession.generateRoomId()
        self.myUid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        self.myName = UserDefaults.standard.string(forKey: Constant.full_name) ?? "Me"
        self.myPhoto = UserDefaults.standard.string(forKey: Constant.profilePic) ?? ""
        self.myPeerId = UUID().uuidString
        self.isMuted = UserDefaults.standard.bool(forKey: "voice_call_muted")

        // Pre-fill caller info from payload
        self.callerName = payload.receiverName
        self.callerPhoto = payload.receiverPhoto

        // For incoming calls: grab the CallKit UUID that was already reported
        if !payload.isSender, let rId = payload.roomId {
            self.callKitUUID = CallKitManager.shared.getCallUUID(for: rId)
        }

        NSLog("✅ [NativeSession] Init — room: \(roomId), myPeerId: \(myPeerId), isSender: \(payload.isSender), callKitUUID: \(callKitUUID?.uuidString ?? "nil")")
    }

    // MARK: - Start

    func start() {
        guard !hasStarted else {
            NSLog("⚠️ [NativeSession] start() already called")
            return
        }
        hasStarted = true

        if payload.isSender {
            // Outgoing call: start CallKit for Dynamic Island / green status bar
            startOutgoingCallKit()
            proceedWithStart()
        } else {
            // Incoming call: proceed immediately with WebRTC setup.
            // Audio activation is deferred until CallKit's didActivate fires.
            NSLog("📞 [NativeSession] Incoming — setting up WebRTC immediately, audio deferred to didActivate")
            proceedWithStart()
        }
    }

    // MARK: - Outgoing CallKit

    private func startOutgoingCallKit() {
        let displayName = payload.receiverName.isEmpty ? "Voice Call" : payload.receiverName
        let uuid = CallKitManager.shared.startOutgoingCall(
            callerName: displayName,
            roomId: roomId,
            receiverId: payload.receiverId
        )
        callKitUUID = uuid
        NSLog("📞 [NativeSession] Started outgoing CallKit call: \(uuid)")
    }

    private func proceedWithStart() {
        setupWebRTC()
        setupSignaling()
        startObservingAudio()
        observeCallKitEnd()

        if payload.isSender {
            configureAudioForOutgoing()
            // Bridge audio session to WebRTC for mic capture
            webRTCManager?.activateAudioSession()
            startRingtone()
            enableProximitySensor()
        } else {
            // Incoming call: CallKit owns the audio session.
            // We MUST wait for didActivate before activating WebRTC audio.
            // Activating before didActivate causes AURemoteIO format errors (no mic in background).
            if CallKitManager.shared.isAudioSessionReady {
                NSLog("✅ [NativeSession] CallKit audio already active — activating WebRTC audio now")
                webRTCManager?.activateAudioSession()
            } else {
                NSLog("📞 [NativeSession] Deferring WebRTC audio until CallKit didActivate...")
                callKitAudioReadyObserver = NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("CallKitAudioSessionReady"),
                    object: nil, queue: .main
                ) { [weak self] _ in
                    guard let self = self else { return }
                    NSLog("✅ [NativeSession] CallKit didActivate fired — activating WebRTC audio now")
                    self.webRTCManager?.activateAudioSession()
                    if let obs = self.callKitAudioReadyObserver {
                        NotificationCenter.default.removeObserver(obs)
                        self.callKitAudioReadyObserver = nil
                    }
                }
                // Fallback: If didActivate still hasn't fired after 3s (cold start edge case),
                // force-activate audio anyway. Better late mic than no mic.
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    guard let self = self, !self.isCallEnded else { return }
                    if self.callKitAudioReadyObserver != nil {
                        NSLog("⚠️ [NativeSession] Audio fallback timer — force-activating WebRTC audio")
                        self.webRTCManager?.activateAudioSession()
                        if let obs = self.callKitAudioReadyObserver {
                            NotificationCenter.default.removeObserver(obs)
                            self.callKitAudioReadyObserver = nil
                        }
                    }
                }
            }
        }
    }

    // MARK: - WebRTC Setup

    private func setupWebRTC() {
        let manager = NativeWebRTCManager()
        manager.delegate = self
        manager.createLocalAudioTrack()
        self.webRTCManager = manager
        NSLog("✅ [NativeSession] WebRTC manager ready")
    }

    // MARK: - Signaling Setup

    private func setupSignaling() {
        let service = FirebaseSignalingService(
            roomId: roomId,
            myPeerId: myPeerId,
            myName: myName,
            myPhoto: myPhoto
        )
        service.delegate = self
        service.start()
        self.signalingService = service
        NSLog("✅ [NativeSession] Signaling service started")

        // Outgoing call: send offer signal to room so receiver knows to call us
        // (Receiver's signalingService peerJoined will trigger createOffer)
        if payload.isSender {
            NSLog("📞 [NativeSession] Outgoing — waiting for receiver to join room")
        }
    }

    // MARK: - Audio Configuration

    /// Called from ActiveCallManager when CallKit didActivate fires.
    /// Activates the RTCAudioSession so WebRTC can capture mic audio.
    func activateWebRTCAudio() {
        guard let mgr = webRTCManager else {
            NSLog("⚠️ [NativeSession] activateWebRTCAudio called but webRTCManager is nil")
            return
        }
        mgr.activateAudioSession()
        NSLog("✅ [NativeSession] WebRTC audio activated via CallKit didActivate")
        // Clean up observer if it was still registered
        if let obs = callKitAudioReadyObserver {
            NotificationCenter.default.removeObserver(obs)
            callKitAudioReadyObserver = nil
        }
    }

    private func configureAudioForOutgoing() {
        webRTCManager?.configureAudioSession(useEarpiece: true)
        NSLog("✅ [NativeSession] Audio configured for outgoing call (earpiece)")
    }

    func setAudioOutput(speaker: Bool) {
        isSpeakerOn = speaker
        webRTCManager?.setAudioOutput(speaker: speaker)
        NSLog("🔊 [NativeSession] Speaker: \(speaker)")
    }

    // MARK: - Mute

    func setMuted(_ muted: Bool) {
        isMuted = muted
        webRTCManager?.setMuted(muted)
        UserDefaults.standard.set(muted, forKey: "voice_call_muted")
        // Sync mute state to CallKit (Dynamic Island / green bar shows correct icon)
        if let uuid = callKitUUID {
            CallKitManager.shared.reportMuteState(uuid: uuid, muted: muted)
        }
    }

    // MARK: - Call Timer

    private func startCallTimer() {
        callTimer?.invalidate()
        callTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.callDuration += 1
        }
    }

    // MARK: - Ringtone

    private func startRingtone() {
        guard payload.isSender else { return }
        if let url = Bundle.main.url(forResource: "ringtone", withExtension: "mp3") {
            ringtonePlayer = try? AVAudioPlayer(contentsOf: url)
            ringtonePlayer?.numberOfLoops = -1
            ringtonePlayer?.play()
        }
    }

    private func stopRingtone() {
        ringtonePlayer?.stop()
        ringtonePlayer = nil
    }

    // MARK: - Proximity Sensor

    private func enableProximitySensor() {
        UIDevice.current.isProximityMonitoringEnabled = true
        proximityObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.proximityStateDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            let near = UIDevice.current.proximityState
            if !self.isSpeakerOn {
                self.webRTCManager?.setAudioOutput(speaker: !near)
            }
        }
    }

    private func disableProximitySensor() {
        UIDevice.current.isProximityMonitoringEnabled = false
        if let obs = proximityObserver {
            NotificationCenter.default.removeObserver(obs)
            proximityObserver = nil
        }
    }

    // MARK: - Audio Interruption / Route Observers

    private func startObservingAudio() {
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil, queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt ?? 0
            let route = self.audioSession.currentRoute
            let outputs = route.outputs.map { $0.portType.rawValue }
            NSLog("🔊 [NativeSession] Route changed (reason: \(reason)). Outputs: \(outputs)")
            // CallKit manages earpiece routing — no manual override needed
        }

        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil, queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt ?? 0
            if type == AVAudioSession.InterruptionType.ended.rawValue {
                NSLog("🔊 [NativeSession] Audio interruption ended — reactivating")
                try? self.audioSession.setActive(true)
            }
        }
    }

    private func stopObservingAudio() {
        if let obs = routeChangeObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = interruptionObserver { NotificationCenter.default.removeObserver(obs) }
        routeChangeObserver = nil
        interruptionObserver = nil
    }

    // MARK: - CallKit End Observer

    private func observeCallKitEnd() {
        callKitEndObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CallKitEndedCall"),
            object: nil, queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            let notifRoom = notification.userInfo?["roomId"] as? String ?? ""
            if notifRoom == self.roomId {
                NSLog("📞 [NativeSession] CallKit ended call from Dynamic Island/UI")
                if !self.isCallEnded {
                    self.endCall()
                }
            }
        }
    }

    // MARK: - Call Connected

    private func onCallConnected() {
        guard !isCallConnected else { return }
        reconnectAttempts = 0  // Reset reconnect counter on successful connection
        reconnectTimer?.invalidate()
        reconnectTimer = nil

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isCallConnected = true
            self.stopRingtone()
            self.startCallTimer()
            self.enableProximitySensor()
            NSLog("✅✅✅ [NativeSession] CALL CONNECTED!")
        }

        // For outgoing calls: report connected to CallKit (updates Dynamic Island)
        if payload.isSender, let uuid = callKitUUID {
            CallKitManager.shared.reportCallConnected(uuid: uuid)
            NSLog("📞 [NativeSession] Reported outgoing call connected to CallKit")
        }

        // For incoming calls: keep CallKit ACTIVE throughout the call.
        // CallKit provides: earpiece routing, Dynamic Island, green status bar, mute sync.
        if !payload.isSender {
            NSLog("📞 [NativeSession] Incoming — CallKit active (WhatsApp-style)")
        }
    }

    // MARK: - End Call

    func endCall() {
        guard !isCallEnded else { return }
        isCallEnded = true
        NSLog("📞 [NativeSession] User ended call")

        signalingService?.sendEndCall()
        performCleanup(removeRoom: true)

        DispatchQueue.main.async { [weak self] in
            self?.shouldDismiss = true
        }
    }

    private func performCleanup(removeRoom: Bool) {
        callTimer?.invalidate()
        callTimer = nil
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        stopRingtone()
        stopObservingAudio()
        disableProximitySensor()
        earpieceMonitorTimer?.invalidate()
        earpieceMonitorTimer = nil

        if let obs = callKitAudioReadyObserver {
            NotificationCenter.default.removeObserver(obs)
            callKitAudioReadyObserver = nil
        }

        webRTCManager?.deactivateAudioSession()
        webRTCManager?.stopAll()
        webRTCManager = nil

        signalingService?.stop(removeRoom: removeRoom)
        signalingService = nil

        // End CallKit if still active (both incoming and outgoing)
        if let uuid = callKitUUID ?? CallKitManager.shared.getCallUUID(for: roomId) {
            CallKitManager.shared.endCall(uuid: uuid, reason: .remoteEnded)
            NSLog("📞 [NativeSession] Ended CallKit call: \(uuid)")
        }
        callKitUUID = nil

        // Remove CallKit end observer
        if let obs = callKitEndObserver {
            NotificationCenter.default.removeObserver(obs)
            callKitEndObserver = nil
        }

        // Clear from ActiveCallManager
        ActiveCallManager.shared.clearSession()

        NSLog("🔴 [NativeSession] Cleanup complete")
    }

    // MARK: - Notifications (for outgoing call — send removeCall when ending)

    private func sendRemoveCallNotificationIfNeeded() {
        guard payload.isSender, !removeCallNotificationSent else { return }
        removeCallNotificationSent = true
        // Post notification to Firebase so receiver knows call ended
        // (same as existing VoiceCallSession logic)
        let ref = Database.database().reference()
        let data: [String: Any] = [
            "senderId": myUid,
            "receiverId": payload.receiverId,
            "type": "removeCall"
        ]
        ref.child("removeCallNotification").child(payload.receiverId).setValue(data)
        NSLog("📤 [NativeSession] Sent removeCall notification")
    }

    // MARK: - Helpers

    private static func generateRoomId() -> String {
        return "room_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
    }

    func stop() {
        if isCallEnded && payload.isSender {
            sendRemoveCallNotificationIfNeeded()
        }
        performCleanup(removeRoom: isCallEnded)
    }
}

// MARK: - NativeWebRTCManagerDelegate
extension NativeVoiceCallSession: NativeWebRTCManagerDelegate {

    func webRTCManager(_ manager: NativeWebRTCManager, didGenerateLocalSDP sdp: RTCSessionDescription, forPeer peerId: String) {
        NSLog("📤 [NativeSession] Local SDP generated (\(sdp.type.rawValue)) for peer: \(peerId)")
        switch sdp.type {
        case .offer:
            signalingService?.sendOffer(sdp: sdp, toPeer: peerId)
        case .answer:
            signalingService?.sendAnswer(sdp: sdp, toPeer: peerId)
        default:
            break
        }
    }

    func webRTCManager(_ manager: NativeWebRTCManager, didGenerateICECandidate candidate: RTCIceCandidate, forPeer peerId: String) {
        signalingService?.sendICECandidate(candidate, toPeer: peerId)
    }

    func webRTCManager(_ manager: NativeWebRTCManager, didConnectPeer peerId: String) {
        NSLog("✅ [NativeSession] Peer connected: \(peerId)")
        onCallConnected()
    }

    func webRTCManager(_ manager: NativeWebRTCManager, didDisconnectPeer peerId: String) {
        NSLog("🔴 [NativeSession] Peer disconnected: \(peerId) (attempt \(reconnectAttempts)/\(maxReconnectAttempts))")
        guard !isCallEnded else { return }
        disconnectedPeerId = peerId
        attemptICERestart(forPeer: peerId)
    }

    /// Attempt ICE restart with retry logic. Called on disconnect and on timeout.
    private func attemptICERestart(forPeer peerId: String) {
        guard !isCallEnded else { return }

        if reconnectAttempts < maxReconnectAttempts {
            reconnectAttempts += 1
            NSLog("🔄 [NativeSession] Attempting ICE restart #\(reconnectAttempts) for: \(peerId)")
            webRTCManager?.restartICE(forPeer: peerId)

            // Set a timeout — if not reconnected within 5s, try again or end
            reconnectTimer?.invalidate()
            reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                guard let self = self, !self.isCallEnded else { return }
                if self.reconnectAttempts < self.maxReconnectAttempts {
                    NSLog("⏱️ [NativeSession] Reconnect timeout — retrying ICE restart")
                    self.attemptICERestart(forPeer: peerId)
                } else {
                    NSLog("❌ [NativeSession] Max reconnect attempts reached — ending call")
                    DispatchQueue.main.async { self.endCall() }
                }
            }
        } else {
            NSLog("❌ [NativeSession] Max reconnect attempts reached — ending call")
            DispatchQueue.main.async { [weak self] in
                self?.endCall()
            }
        }
    }

    func webRTCManagerDidReceiveRemoteAudio(_ manager: NativeWebRTCManager) {
        NSLog("🔊 [NativeSession] Remote audio received")
    }

    func webRTCManagerCallEnded(_ manager: NativeWebRTCManager) {
        DispatchQueue.main.async { [weak self] in
            self?.endCall()
        }
    }
}

// MARK: - FirebaseSignalingDelegate
extension NativeVoiceCallSession: FirebaseSignalingDelegate {

    func signalingService(_ service: FirebaseSignalingService, peerJoined peerId: String, name: String, photo: String) {
        NSLog("👤 [NativeSession] Peer joined: \(peerId) (\(name))")
        DispatchQueue.main.async { [weak self] in
            self?.callerName = name
            if !photo.isEmpty && photo != "user.svg" {
                self?.callerPhoto = photo
            }
        }

        // Both sides create offer — needed for cross-platform compatibility.
        // If both are native iOS, the first answer received wins (idempotent).
        // If caller is Android/old-iOS (PeerJS), they won't send Firebase SDP,
        // so the native receiver must initiate the offer instead.
        NSLog("📞 [NativeSession] Peer joined — creating offer for: \(peerId) (isSender=\(payload.isSender))")
        webRTCManager?.createOffer(forPeer: peerId)
    }

    func signalingService(_ service: FirebaseSignalingService, didReceiveOffer sdp: String, fromPeer peerId: String) {
        NSLog("📨 [NativeSession] Received offer from: \(peerId)")
        webRTCManager?.handleRemoteOffer(sdp, fromPeer: peerId)
    }

    func signalingService(_ service: FirebaseSignalingService, didReceiveAnswer sdp: String, fromPeer peerId: String) {
        NSLog("📨 [NativeSession] Received answer from: \(peerId)")
        webRTCManager?.handleRemoteAnswer(sdp, fromPeer: peerId)
    }

    func signalingService(_ service: FirebaseSignalingService, didReceiveICECandidate candidate: [String: Any], fromPeer peerId: String) {
        webRTCManager?.handleRemoteICECandidate(candidate, fromPeer: peerId)
    }

    func signalingServicePeerCountDroppedToZero(_ service: FirebaseSignalingService) {
        NSLog("📞 [NativeSession] Peer count 0 — other side ended call")
        if !isCallEnded {
            DispatchQueue.main.async { [weak self] in
                self?.endCall()
            }
        }
    }

    func signalingServiceReceivedEndCall(_ service: FirebaseSignalingService, fromPeer peerId: String) {
        NSLog("📞 [NativeSession] Received endCall from: \(peerId)")
        if !isCallEnded {
            DispatchQueue.main.async { [weak self] in
                self?.endCall()
            }
        }
    }
}
