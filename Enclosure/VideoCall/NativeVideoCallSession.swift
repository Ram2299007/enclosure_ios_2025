//
//  NativeVideoCallSession.swift
//  Enclosure
//
//  Fully native WebRTC video call session.
//  Uses NativeWebRTCManager + FirebaseSignalingService — same pattern as NativeVoiceCallSession.
//  No PeerJS, no WebView.
//

#if !targetEnvironment(simulator)
import Foundation
import WebRTC
import FirebaseDatabase
import AVFoundation
import AVKit
import UIKit

final class NativeVideoCallSession: ObservableObject {

    // MARK: - Published State (drives UI)

    @Published var shouldDismiss = false
    @Published var isCallConnected = false
    @Published var isMicrophoneMuted = false
    @Published var isCameraOff = false
    @Published var callerName = "Unknown"
    @Published var callDuration: TimeInterval = 0

    // Video renderers — set by NativeVideoCallScreen before start()
    var localRenderer: RTCEAGLVideoView?
    var remoteRenderer: RTCEAGLVideoView?

    let payload: VideoCallPayload

    // MARK: - Private

    private let roomId: String
    private let myUid: String
    private let myName: String
    private let myPhoto: String
    private let myPeerId: String

    private(set) var webRTCManager: NativeWebRTCManager?
    private var signalingService: FirebaseSignalingService?

    private(set) var remoteVideoTrack: RTCVideoTrack?
    private var callTimer: Timer?
    private var callKitAudioReadyObserver: NSObjectProtocol?

    private var hasStarted = false
    private var isCallEnded = false
    private var removeCallNotificationSent = false
    private var disconnectWorkItem: DispatchWorkItem?
    private var ringtonePlayer: AVAudioPlayer?
    private let audioSession = AVAudioSession.sharedInstance()

    // System PiP (background PiP)
    private(set) var systemPiPController: VideoCallPiPController?
    private var appBackgroundObserver: NSObjectProtocol?
    private var appForegroundObserver: NSObjectProtocol?

    // MARK: - Init

    init(payload: VideoCallPayload) {
        self.payload = payload
        self.roomId = payload.roomId ?? Self.generateRoomId()
        self.myUid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        self.myName = UserDefaults.standard.string(forKey: Constant.full_name) ?? "Name"
        self.myPhoto = UserDefaults.standard.string(forKey: Constant.profilePic) ?? ""
        self.myPeerId = UUID().uuidString
        self.callerName = payload.receiverName.isEmpty ? "Unknown" : payload.receiverName

        NSLog("📹 [VideoSession] init roomId=\(roomId) isSender=\(payload.isSender) myPeerId=\(myPeerId)")
    }

    // MARK: - Start

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        setupWebRTC()
        setupSignaling()

        // Handle audio: for incoming calls, CallKit owns audio session.
        if payload.isSender {
            webRTCManager?.configureAudioSession(useEarpiece: false) // speaker for video
            webRTCManager?.activateAudioSession()
            startRingtone()
        } else {
            if CallKitManager.shared.isAudioSessionReady {
                NSLog("✅ [VideoSession] CallKit audio already active")
                webRTCManager?.activateAudioSession()
            } else {
                NSLog("📞 [VideoSession] Deferring audio until CallKit didActivate")
                callKitAudioReadyObserver = NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("CallKitAudioSessionReady"),
                    object: nil, queue: .main
                ) { [weak self] _ in
                    guard let self = self else { return }
                    NSLog("✅ [VideoSession] CallKit didActivate → activating WebRTC audio")
                    self.webRTCManager?.activateAudioSession()
                    if let obs = self.callKitAudioReadyObserver {
                        NotificationCenter.default.removeObserver(obs)
                        self.callKitAudioReadyObserver = nil
                    }
                }
                // Fallback
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    guard let self = self, !self.isCallEnded, self.callKitAudioReadyObserver != nil else { return }
                    NSLog("⚠️ [VideoSession] Audio fallback timer — force-activating")
                    self.webRTCManager?.activateAudioSession()
                    if let obs = self.callKitAudioReadyObserver {
                        NotificationCenter.default.removeObserver(obs)
                        self.callKitAudioReadyObserver = nil
                    }
                }
            }
        }
        // Observe app lifecycle for system PiP
        appBackgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.systemPiPController?.startPiP()
        }
        appForegroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.systemPiPController?.stopPiP()
        }

        NSLog("📹 [VideoSession] start() complete")
    }

    /// Set up system PiP — call from MainActivityOld (persistent view hierarchy)
    func setupSystemPiP(sourceView: UIView) {
        guard systemPiPController == nil else { return }
        let controller = VideoCallPiPController()
        controller.setup(sourceView: sourceView)
        controller.onRestoreFromPiP = { [weak self] in
            guard self != nil else { return }
            DispatchQueue.main.async {
                ActiveCallManager.shared.isInPiPMode = false
            }
        }
        self.systemPiPController = controller
        // Attach tracks that are already available
        if let track = remoteVideoTrack {
            controller.attachRemoteTrack(track)
        }
        if let localTrack = webRTCManager?.localVideoTrack {
            controller.attachLocalTrack(localTrack)
        }
        NSLog("✅ [VideoSession] System PiP controller set up (local + remote)")
    }

    // MARK: - WebRTC Setup

    private func setupWebRTC() {
        let manager = NativeWebRTCManager(isVideo: true)
        manager.delegate = self
        manager.createLocalAudioTrack()
        manager.createLocalVideoTrack()
        self.webRTCManager = manager

        // Attach local renderer to local video track
        if let lr = localRenderer, let vt = manager.localVideoTrack {
            vt.add(lr)
            NSLog("📹 [VideoSession] local renderer attached")
        }
        // Attach local track to system PiP if already set up
        if let vt = manager.localVideoTrack {
            systemPiPController?.attachLocalTrack(vt)
        }
        NSLog("✅ [VideoSession] WebRTC manager ready (audio + video)")
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
        NSLog("✅ [VideoSession] Signaling service started")
    }

    // MARK: - Public API

    func stop() {
        // Only send removeVideoCallNotification if call was NOT connected (missed call).
        // Sending after a connected call leaves stale entries in Firebase.
        if isCallEnded && payload.isSender && !isCallConnected {
            sendRemoveCallNotificationIfNeeded()
        }
        performCleanup(removeRoom: isCallEnded)
    }

    /// Called by ActiveCallManager when CallKit didActivate fires
    func activateWebRTCAudio() {
        webRTCManager?.activateAudioSession()
        NSLog("✅ [VideoSession] WebRTC audio activated via ActiveCallManager")
        // Start ringtone for outgoing calls after audio activation (incoming path)
        if payload.isSender && !isCallConnected && !(ringtonePlayer?.isPlaying ?? false) {
            startRingtone()
        }
    }

    func toggleMicrophone() {
        isMicrophoneMuted.toggle()
        webRTCManager?.setMuted(isMicrophoneMuted)
        NSLog("🎤 [VideoSession] mic \(isMicrophoneMuted ? "MUTED" : "UNMUTED")")
    }

    func toggleCamera() {
        isCameraOff.toggle()
        webRTCManager?.setVideoEnabled(!isCameraOff)
        NSLog("📷 [VideoSession] camera \(isCameraOff ? "OFF" : "ON")")
    }

    func switchCamera() {
        guard !isCameraOff else { return }
        webRTCManager?.switchCamera()
        NSLog("🔄 [VideoSession] camera switched")
    }

    func endCall() {
        guard !isCallEnded else { return }
        isCallEnded = true
        NSLog("📹 [VideoSession] ending call")

        // Dismiss UI immediately
        DispatchQueue.main.async { self.shouldDismiss = true }

        // Send end signal
        signalingService?.sendEndCall()

        // End CallKit
        if let uuid = CallKitManager.shared.getCallUUID(for: roomId) {
            CallKitManager.shared.endCall(uuid: uuid, reason: .remoteEnded)
        }

        cleanupRemoveCallNotificationForSelf()

        // Cleanup
        DispatchQueue.main.async { [weak self] in
            self?.performCleanup(removeRoom: true)
        }
    }

    // MARK: - Cleanup

    private func performCleanup(removeRoom: Bool) {
        // Send removeVideoCallNotification for missed calls (sender, not connected).
        // Same pattern as voice calls — only when call ended without connecting.
        if isCallEnded && payload.isSender && !isCallConnected {
            sendRemoveCallNotificationIfNeeded()
        }
        stopRingtone()
        disconnectWorkItem?.cancel()
        disconnectWorkItem = nil
        callTimer?.invalidate()
        callTimer = nil

        if let obs = callKitAudioReadyObserver {
            NotificationCenter.default.removeObserver(obs)
            callKitAudioReadyObserver = nil
        }

        // Remove renderers
        if let lr = localRenderer { webRTCManager?.localVideoTrack?.remove(lr) }
        if let rr = remoteRenderer { remoteVideoTrack?.remove(rr) }
        if let track = remoteVideoTrack { systemPiPController?.detachRemoteTrack(track) }
        if let localTrack = webRTCManager?.localVideoTrack { systemPiPController?.detachLocalTrack(localTrack) }
        remoteVideoTrack = nil

        // Tear down system PiP
        systemPiPController?.tearDown()
        systemPiPController = nil
        if let obs = appBackgroundObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = appForegroundObserver { NotificationCenter.default.removeObserver(obs) }
        appBackgroundObserver = nil
        appForegroundObserver = nil

        webRTCManager?.deactivateAudioSession()
        webRTCManager?.stopAll()
        webRTCManager = nil

        signalingService?.stop(removeRoom: removeRoom)
        signalingService = nil

        // Clear from ActiveCallManager (dismisses in-app PiP overlay)
        ActiveCallManager.shared.clearVideoSession()

        NSLog("🔴 [VideoSession] cleanup complete")
    }

    // MARK: - Call Connected

    private func onCallConnected() {
        guard !isCallConnected else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isCallConnected = true
            self.stopRingtone()
            self.startCallTimer()
            NSLog("✅✅✅ [VideoSession] CALL CONNECTED!")
        }
    }

    // MARK: - Timer

    private func startCallTimer() {
        callTimer?.invalidate()
        callDuration = 0
        callTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.callDuration += 1 }
        }
    }

    // MARK: - Ringtone

    private func startRingtone() {
        guard payload.isSender else { return }
        ringtonePlayer?.stop()
        ringtonePlayer = nil
        if let url = Bundle.main.url(forResource: "ringtone", withExtension: "mp3") {
            do {
                ringtonePlayer = try AVAudioPlayer(contentsOf: url)
                ringtonePlayer?.numberOfLoops = -1
                ringtonePlayer?.volume = 1.0
                ringtonePlayer?.prepareToPlay()
                // Video calls default to speaker
                try audioSession.overrideOutputAudioPort(.speaker)
                ringtonePlayer?.play()
                NSLog("🔔 [VideoSession] Ringtone started (speaker)")
            } catch {
                NSLog("❌ [VideoSession] Failed to start ringtone: \(error.localizedDescription)")
            }
        } else {
            NSLog("❌ [VideoSession] ringtone.mp3 not found in bundle")
        }
    }

    private func stopRingtone() {
        ringtonePlayer?.stop()
        ringtonePlayer = nil
    }

    // MARK: - Notifications

    private func sendRemoveCallNotificationIfNeeded() {
        guard !removeCallNotificationSent else { return }
        let receiverId = payload.receiverId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !receiverId.isEmpty else { return }
        removeCallNotificationSent = true
        let ref = Database.database().reference().child("removeVideoCallNotification").child(receiverId).childByAutoId()
        ref.setValue(ref.key ?? UUID().uuidString)
        NSLog("📤 [VideoSession] removeVideoCallNotification sent to \(receiverId)")
    }

    private func cleanupRemoveCallNotificationForSelf() {
        let uid = myUid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uid.isEmpty else { return }
        Database.database().reference().child("removeVideoCallNotification").child(uid).removeValue()
    }

    private static func generateRoomId() -> String {
        "room_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
    }
}

// MARK: - NativeWebRTCManagerDelegate

extension NativeVideoCallSession: NativeWebRTCManagerDelegate {

    func webRTCManager(_ manager: NativeWebRTCManager, didGenerateLocalSDP sdp: RTCSessionDescription, forPeer peerId: String) {
        NSLog("📤 [VideoSession] SDP (\(sdp.type.rawValue)) for peer: \(peerId)")
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
        NSLog("✅ [VideoSession] Peer connected: \(peerId)")
        // Cancel any pending disconnect timer — ICE recovered
        disconnectWorkItem?.cancel()
        disconnectWorkItem = nil
        onCallConnected()
    }

    func webRTCManager(_ manager: NativeWebRTCManager, didDisconnectPeer peerId: String) {
        NSLog("🔴 [VideoSession] Peer disconnected: \(peerId)")
        guard !isCallEnded else { return }
        // ICE 'closed' fires during cleanup — ignore if webRTCManager already nil
        guard webRTCManager != nil else { return }
        // Cancel any existing timer before starting a new one
        disconnectWorkItem?.cancel()
        // Allow brief recovery window before ending (ICE disconnects can be transient)
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, !self.isCallEnded else { return }
            NSLog("🔴 [VideoSession] Peer still disconnected after 3s — ending call")
            self.endCall()
        }
        disconnectWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: workItem)
    }

    func webRTCManagerDidReceiveRemoteAudio(_ manager: NativeWebRTCManager) {
        NSLog("🔊 [VideoSession] Remote audio received")
    }

    func webRTCManagerCallEnded(_ manager: NativeWebRTCManager) {
        DispatchQueue.main.async { [weak self] in self?.endCall() }
    }

    func webRTCManager(_ manager: NativeWebRTCManager, didReceiveRemoteVideoTrack track: RTCVideoTrack, forPeer peerId: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.remoteVideoTrack = track
            if let rr = self.remoteRenderer {
                track.add(rr)
                NSLog("📹 [VideoSession] Remote video attached to renderer")
            }
            // Also attach system PiP remote renderer
            self.systemPiPController?.attachRemoteTrack(track)
        }
    }
}

// MARK: - FirebaseSignalingDelegate

extension NativeVideoCallSession: FirebaseSignalingDelegate {

    func signalingService(_ service: FirebaseSignalingService, peerJoined peerId: String, name: String, photo: String) {
        NSLog("👤 [VideoSession] Peer joined: \(peerId) (\(name))")
        DispatchQueue.main.async { [weak self] in
            self?.callerName = name
        }
        // Only sender creates the offer; receiver waits for it via didReceiveOffer.
        // This avoids SDP glare (both sides sending offers simultaneously) which
        // causes intermittent connection failures — same fix as Android.
        if payload.isSender {
            NSLog("📹 [VideoSession] Sender — creating offer for peer: \(peerId)")
            webRTCManager?.createOffer(forPeer: peerId)
        } else {
            NSLog("📹 [VideoSession] Receiver — waiting for offer from: \(peerId)")
        }
    }

    func signalingService(_ service: FirebaseSignalingService, didReceiveOffer sdp: String, fromPeer peerId: String) {
        NSLog("📨 [VideoSession] Received offer from: \(peerId)")
        webRTCManager?.handleRemoteOffer(sdp, fromPeer: peerId)
    }

    func signalingService(_ service: FirebaseSignalingService, didReceiveAnswer sdp: String, fromPeer peerId: String) {
        NSLog("📨 [VideoSession] Received answer from: \(peerId)")
        webRTCManager?.handleRemoteAnswer(sdp, fromPeer: peerId)
    }

    func signalingService(_ service: FirebaseSignalingService, didReceiveICECandidate candidate: [String: Any], fromPeer peerId: String) {
        webRTCManager?.handleRemoteICECandidate(candidate, fromPeer: peerId)
    }

    func signalingServicePeerCountDroppedToZero(_ service: FirebaseSignalingService) {
        // If call was already connected via WebRTC, ignore Firebase peer count
        // (WebRTC connection is independent of Firebase peer entries)
        if isCallConnected {
            NSLog("📹 [VideoSession] Peer count 0 but call already connected — ignoring")
            return
        }
        NSLog("📹 [VideoSession] Peer count 0 — ending call")
        if !isCallEnded {
            DispatchQueue.main.async { [weak self] in self?.endCall() }
        }
    }

    func signalingServiceReceivedEndCall(_ service: FirebaseSignalingService, fromPeer peerId: String) {
        NSLog("📹 [VideoSession] Received endCall from: \(peerId)")
        if !isCallEnded {
            DispatchQueue.main.async { [weak self] in self?.endCall() }
        }
    }
}
#endif
