//
//  NativeVideoCallSession.swift
//  Enclosure
//
//  Native WebRTC video call session management.
//  Uses PeerJS signaling server (matching Android WebView) + Firebase peer discovery.
//  GoogleWebRTC Plan B (addStream, not addTrack).
//

import Foundation
import WebRTC
import FirebaseDatabase
import AVFoundation
import UIKit

final class NativeVideoCallSession: NSObject, ObservableObject {

    // MARK: - Published state (drives UI)

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

    // MARK: - Private state

    private let roomId: String
    private let myUid: String
    private let myName: String
    private let myPhoto: String

    // WebRTC
    private let factory: RTCPeerConnectionFactory
    private var peerConnection: RTCPeerConnection?
    private var pcDelegate: VideoCallPCDelegate?
    private var localVideoTrack: RTCVideoTrack?
    private var localAudioTrack: RTCAudioTrack?
    private var localStream: RTCMediaStream?
    private var remoteVideoTrack: RTCVideoTrack?

    // Camera
    private var cameraCapturer: RTCCameraVideoCapturer?
    private var videoSource: RTCVideoSource?
    private var currentCameraPosition: AVCaptureDevice.Position = .front

    // PeerJS signaling (matches Android WebView's PeerJS protocol)
    private let peerJSClient = PeerJSClient()
    private var connectionId: String = ""       // mc_<uuid> — unique per media connection
    private var remotePeerId: String?            // PeerJS ID of the remote peer
    private var hasSentOffer = false

    // Firebase peer discovery (same paths as VideoCallSession WebView)
    private var databaseRef: DatabaseReference?
    private var peersHandle: DatabaseHandle?
    private var isCallEnded = false
    private var removeCallNotificationSent = false

    // Timer
    private var callTimer: Timer?

    // ICE servers (matching Android script.js getIceServers)
    private let iceServers: [RTCIceServer] = [
        RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
        RTCIceServer(urlStrings: ["stun:stun1.l.google.com:19302"]),
        RTCIceServer(urlStrings: ["stun:stun2.l.google.com:19302"]),
        RTCIceServer(
            urlStrings: ["turn:openrelay.metered.ca:80"],
            username: "openrelay.project",
            credential: "openrelay"
        )
    ]

    // MARK: - Init

    init(payload: VideoCallPayload) {
        self.payload = payload
        self.roomId = payload.roomId ?? Self.generateRoomId()
        self.myUid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        self.myName = UserDefaults.standard.string(forKey: Constant.full_name) ?? "Name"
        self.myPhoto = UserDefaults.standard.string(forKey: Constant.profilePic) ?? ""
        self.callerName = payload.receiverName.isEmpty ? "Unknown" : payload.receiverName
        self.connectionId = "mc_\(UUID().uuidString.prefix(8))"

        RTCInitializeSSL()
        self.factory = RTCPeerConnectionFactory()

        super.init()
        peerJSClient.delegate = self
        NSLog("📹 [VideoSession] init roomId=\(roomId) isSender=\(payload.isSender)")
    }

    deinit {
        stop()
        RTCCleanupSSL()
    }

    // MARK: - Public API

    func start() {
        guard !isCallEnded else { return }
        configureAudioSession()
        createLocalTracks()

        // Connect to PeerJS server (same as Android WebView does)
        peerJSClient.connect()
        NSLog("📹 [VideoSession] start() — connecting to PeerJS server")
    }

    func stop() {
        guard !isCallEnded else { return }
        isCallEnded = true
        callTimer?.invalidate()
        callTimer = nil

        // Stop camera
        cameraCapturer?.stopCapture()
        cameraCapturer = nil

        // Remove renderers
        if let lr = localRenderer { localVideoTrack?.remove(lr) }
        if let rr = remoteRenderer { remoteVideoTrack?.remove(rr) }

        // Close peer connection
        peerConnection?.close()
        peerConnection = nil

        // Disconnect PeerJS
        peerJSClient.disconnect()

        // Remove from Firebase
        cleanupFirebase()

        localVideoTrack = nil
        localAudioTrack = nil
        localStream = nil
        remoteVideoTrack = nil
        NSLog("📹 [VideoSession] stop()")
    }

    func toggleMicrophone() {
        isMicrophoneMuted.toggle()
        localAudioTrack?.isEnabled = !isMicrophoneMuted
        NSLog("🎤 [VideoSession] mic \(isMicrophoneMuted ? "MUTED" : "UNMUTED")")
    }

    func toggleCamera() {
        isCameraOff.toggle()
        localVideoTrack?.isEnabled = !isCameraOff
        NSLog("📷 [VideoSession] camera \(isCameraOff ? "OFF" : "ON")")
    }

    func switchCamera() {
        guard !isCameraOff, let capturer = cameraCapturer else { return }
        currentCameraPosition = (currentCameraPosition == .front) ? .back : .front
        startCapture(with: capturer)
        NSLog("🔄 [VideoSession] switched to \(currentCameraPosition == .front ? "front" : "back") camera")
    }

    func endCall() {
        guard !isCallEnded else { return }

        // Remove room from Firebase (matches Android behaviour — room deletion auto-ends other side)
        if let ref = databaseRef {
            ref.child("rooms").child(roomId).removeValue()
        }

        // Send removeVideoCallNotification (matches VideoCallSession.sendRemoveCallNotificationIfNeeded)
        if payload.isSender {
            sendRemoveCallNotificationIfNeeded()
        }
        cleanupRemoveCallNotificationForSelf()

        stop()
        DispatchQueue.main.async { self.shouldDismiss = true }
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .videoChat,
                                    options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker])
            try session.setPreferredSampleRate(48000)
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true, options: [.notifyOthersOnDeactivation])
            NSLog("✅ [VideoSession] audio configured")
        } catch {
            NSLog("❌ [VideoSession] audio error: \(error)")
        }
    }

    // MARK: - Local Tracks

    private func createLocalTracks() {
        // Audio
        let audioConstraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["echoCancellation": "true",
                                  "noiseSuppression": "true",
                                  "autoGainControl": "true"]
        )
        let audioSource = factory.audioSource(with: audioConstraints)
        localAudioTrack = factory.audioTrack(with: audioSource, trackId: "audio0")
        localAudioTrack?.isEnabled = true

        // Video
        videoSource = factory.videoSource()
        let capturer = RTCCameraVideoCapturer(delegate: videoSource!)
        cameraCapturer = capturer
        localVideoTrack = factory.videoTrack(with: videoSource!, trackId: "video0")
        localVideoTrack?.isEnabled = true

        // Attach local renderer
        if let lr = localRenderer { localVideoTrack?.add(lr) }

        // Start camera
        startCapture(with: capturer)

        // Media stream (Plan B)
        let stream = factory.mediaStream(withStreamId: "localStream")
        stream.addAudioTrack(localAudioTrack!)
        stream.addVideoTrack(localVideoTrack!)
        localStream = stream
        NSLog("✅ [VideoSession] local tracks created")
    }

    private func startCapture(with capturer: RTCCameraVideoCapturer) {
        let devices = RTCCameraVideoCapturer.captureDevices()
        guard let device = devices.first(where: { $0.position == currentCameraPosition })
                ?? devices.first else {
            NSLog("❌ [VideoSession] no camera found"); return
        }

        // Pick format closest to 640×480 (matches Android getOptimalCameraConstraints)
        let formats = RTCCameraVideoCapturer.supportedFormats(for: device)
        let tw: Int32 = 640, th: Int32 = 480
        var best: AVCaptureDevice.Format?
        var bestDiff = Int32.max
        for f in formats {
            let d = CMVideoFormatDescriptionGetDimensions(f.formatDescription)
            let diff = abs(d.width - tw) + abs(d.height - th)
            if diff < bestDiff { bestDiff = diff; best = f }
        }
        guard let format = best else { NSLog("❌ [VideoSession] no format"); return }

        capturer.startCapture(with: device, format: format, fps: 30)
        let d = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        NSLog("📷 [VideoSession] capturing \(d.width)×\(d.height)@30fps")
    }

    // MARK: - RTCPeerConnection

    private func createPeerConnection() {
        guard peerConnection == nil else { return }

        let config = RTCConfiguration()
        config.iceServers = iceServers
        config.continualGatheringPolicy = .gatherContinually
        config.iceCandidatePoolSize = 10
        config.bundlePolicy = .maxBundle
        config.rtcpMuxPolicy = .require
        config.tcpCandidatePolicy = .enabled

        let constraints = RTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveAudio": "true", "OfferToReceiveVideo": "true"],
            optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
        )
        let wrapper = VideoCallPCDelegate(session: self)
        pcDelegate = wrapper

        let pc = factory.peerConnection(with: config, constraints: constraints, delegate: wrapper)
        if let stream = localStream { pc.add(stream) }
        peerConnection = pc
        NSLog("✅ [VideoSession] RTCPeerConnection created")
    }

    // MARK: - Firebase peer discovery (same paths as VideoCallSession WebView)

    private func setupFirebasePeerDiscovery() {
        databaseRef = Database.database().reference()
        let myPeerJSId = peerJSClient.peerId

        // Store our PeerJS ID in Firebase (exact format Android WebView uses)
        let peerPayload: [String: Any] = [
            "peerId": myPeerJSId,
            "name": myName,
            "photo": myPhoto.isEmpty ? "user.png" : myPhoto
        ]
        if let data = try? JSONSerialization.data(withJSONObject: peerPayload),
           let jsonString = String(data: data, encoding: .utf8) {
            databaseRef?.child("rooms").child(roomId).child("peers").child(myPeerJSId).setValue(jsonString)
        }
        NSLog("📹 [VideoSession] registered in Firebase rooms/\(roomId)/peers/\(myPeerJSId)")

        // Watch for peer list changes
        peersHandle = databaseRef?.child("rooms").child(roomId).child("peers")
            .observe(.value) { [weak self] snapshot in
                guard let self = self, !self.isCallEnded else { return }
                let myId = self.peerJSClient.peerId

                var peerIds: [String] = []
                for child in snapshot.children {
                    guard let snap = child as? DataSnapshot,
                          let value = snap.value as? String,
                          let data = value.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let peerId = json["peerId"] as? String,
                          !peerId.isEmpty, peerId != myId else { continue }
                    peerIds.append(peerId)
                }

                // Auto-end if room cleared (other side left)
                let totalPeers = snapshot.childrenCount
                if totalPeers == 0 && !self.isCallEnded && self.peerJSClient.isConnected {
                    NSLog("📹 [VideoSession] room empty — ending call")
                    DispatchQueue.main.async { self.endCall() }
                    return
                }

                // Connect to new peers — only initiate if we are the SENDER.
                // Android always calls connectToPeer() when it discovers a peer,
                // so when iOS is receiver we just wait for the PeerJS OFFER.
                for pid in peerIds {
                    if self.remotePeerId == nil {
                        self.remotePeerId = pid
                        NSLog("📹 [VideoSession] peer discovered: \(pid) (isSender=\(self.payload.isSender))")
                        if self.payload.isSender && !self.hasSentOffer {
                            NSLog("📹 [VideoSession] I am sender — initiating call to \(pid)")
                            self.initiateCallToPeer(pid)
                        } else {
                            NSLog("📹 [VideoSession] I am receiver — waiting for OFFER from \(pid)")
                        }
                    }
                }
            }
    }

    private func cleanupFirebase() {
        if let h = peersHandle {
            databaseRef?.child("rooms").child(roomId).child("peers").removeObserver(withHandle: h)
        }
        // Remove entire room on end (matches Android VideoCallSession)
        if isCallEnded {
            databaseRef?.child("rooms").child(roomId).removeValue()
        } else {
            let myId = peerJSClient.peerId
            if !myId.isEmpty {
                databaseRef?.child("rooms").child(roomId).child("peers").child(myId).removeValue()
            }
        }
    }

    // MARK: - removeVideoCallNotification (matches VideoCallSession)

    private func sendRemoveCallNotificationIfNeeded() {
        guard !removeCallNotificationSent else { return }
        let receiverId = payload.receiverId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !receiverId.isEmpty else { return }
        removeCallNotificationSent = true
        let ref = Database.database().reference().child("removeVideoCallNotification").child(receiverId).childByAutoId()
        let key = ref.key ?? UUID().uuidString
        ref.setValue(key)
        NSLog("✅ [VideoSession] removeVideoCallNotification sent to \(receiverId)")
    }

    private func cleanupRemoveCallNotificationForSelf() {
        let uid = myUid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uid.isEmpty else { return }
        Database.database().reference().child("removeVideoCallNotification").child(uid).removeValue()
    }

    // MARK: - Call initiation via PeerJS

    private func initiateCallToPeer(_ peerId: String) {
        guard !hasSentOffer else { return }
        hasSentOffer = true

        createPeerConnection()
        guard let pc = peerConnection else { return }

        let constraints = RTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveAudio": "true", "OfferToReceiveVideo": "true"],
            optionalConstraints: nil
        )
        pc.offer(for: constraints) { [weak self] sdp, error in
            guard let self = self, let sdp = sdp else {
                NSLog("❌ [VideoSession] createOffer failed: \(error?.localizedDescription ?? "")")
                return
            }
            pc.setLocalDescription(sdp) { error in
                if let error = error {
                    NSLog("❌ [VideoSession] setLocal offer: \(error)")
                    return
                }
                // Send OFFER through PeerJS server (not Firebase)
                self.peerJSClient.sendOffer(sdp: sdp.sdp, to: peerId, connectionId: self.connectionId)
                NSLog("📤 [VideoSession] OFFER sent via PeerJS to \(peerId)")
            }
        }
    }

    // MARK: - Helpers

    fileprivate func onICECandidate(_ candidate: RTCIceCandidate) {
        guard let dst = remotePeerId else {
            NSLog("⚠️ [VideoSession] ICE candidate generated but no remotePeerId yet — dropping")
            return
        }
        NSLog("📤 [VideoSession] Sending ICE candidate to \(dst) connId=\(connectionId) mid=\(candidate.sdpMid ?? "nil")")
        peerJSClient.sendCandidate(
            candidate: candidate.sdp,
            sdpMid: candidate.sdpMid ?? "0",
            sdpMLineIndex: candidate.sdpMLineIndex,
            to: dst,
            connectionId: connectionId
        )
    }

    fileprivate func onRemoteStreamAdded(_ stream: RTCMediaStream) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let vt = stream.videoTracks.first {
                self.remoteVideoTrack = vt
                if let rr = self.remoteRenderer { vt.add(rr) }
                NSLog("📹 [VideoSession] remote video attached")
            }
            if !stream.audioTracks.isEmpty {
                NSLog("🔊 [VideoSession] remote audio received")
            }
        }
    }

    fileprivate func onICEConnected() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isCallConnected else { return }
            self.isCallConnected = true
            self.startCallTimer()
            NSLog("✅ [VideoSession] call connected!")
        }
    }

    fileprivate func onICEDisconnected() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isCallEnded else { return }
            self.isCallConnected = false
            NSLog("🔴 [VideoSession] ICE disconnected")
        }
    }

    private func startCallTimer() {
        callTimer?.invalidate()
        callDuration = 0
        callTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.callDuration += 1 }
        }
    }

    private static func generateRoomId() -> String {
        "\(Int(Date().timeIntervalSince1970 * 1000))\(Int.random(in: 1000...9999))"
    }
}

// MARK: - PeerJSClientDelegate

extension NativeVideoCallSession: PeerJSClientDelegate {

    func peerJSClientDidOpen(_ client: PeerJSClient, peerId: String) {
        NSLog("📹 [VideoSession] PeerJS open — peerId=\(peerId)")
        // Now register in Firebase so the other side can discover us
        setupFirebasePeerDiscovery()
    }

    func peerJSClient(_ client: PeerJSClient, didReceiveOffer sdp: [String: Any], connectionId connId: String, from peerId: String) {
        NSLog("📥 [VideoSession] OFFER from \(peerId) connId=\(connId)")

        // Skip data-channel offers (dc_*) — they don't carry media SDP
        if connId.hasPrefix("dc_") {
            NSLog("⏭️ [VideoSession] Ignoring data-channel offer (dc_*) from \(peerId)")
            return
        }

        // If we already sent our own offer (glare), ignore the incoming offer.
        // Our OFFER→ANSWER flow is already in progress.
        if hasSentOffer {
            NSLog("⏭️ [VideoSession] Ignoring incoming OFFER — we already sent our own offer (glare)")
            return
        }

        guard let sdpString = sdp["sdp"] as? String, !sdpString.isEmpty else {
            NSLog("⚠️ [VideoSession] OFFER has no valid SDP — sdp keys=\(sdp.keys.sorted()), types=\(sdp.mapValues { type(of: $0) })")
            return
        }

        let preview = sdpString.prefix(200)
        NSLog("📋 [VideoSession] SDP string length=\(sdpString.count) preview=\(preview)")
        NSLog("📋 [VideoSession] SDP starts with v=0? \(sdpString.hasPrefix("v=0"))")

        remotePeerId = peerId
        connectionId = connId // use the caller's connectionId for this media connection

        createPeerConnection()
        guard let pc = peerConnection else { return }

        NSLog("📋 [VideoSession] PC signaling state before setRemote: \(pc.signalingState.rawValue)")
        let remoteDesc = RTCSessionDescription(type: .offer, sdp: sdpString)
        pc.setRemoteDescription(remoteDesc) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                NSLog("❌ [VideoSession] setRemote offer: \(error)")
                NSLog("❌ [VideoSession] SDP was length=\(sdpString.count) firstLine=\(sdpString.components(separatedBy: "\n").first ?? "empty")")
                return
            }
            let constraints = RTCMediaConstraints(
                mandatoryConstraints: ["OfferToReceiveAudio": "true", "OfferToReceiveVideo": "true"],
                optionalConstraints: nil
            )
            pc.answer(for: constraints) { sdp, error in
                guard let sdp = sdp else {
                    NSLog("❌ [VideoSession] createAnswer: \(error?.localizedDescription ?? "")"); return
                }
                pc.setLocalDescription(sdp) { error in
                    if let error = error {
                        NSLog("❌ [VideoSession] setLocal answer: \(error)"); return
                    }
                    client.sendAnswer(sdp: sdp.sdp, to: peerId, connectionId: connId)
                    NSLog("� [VideoSession] ANSWER sent via PeerJS to \(peerId)")
                }
            }
        }
    }

    func peerJSClient(_ client: PeerJSClient, didReceiveAnswer sdp: [String: Any], connectionId: String, from peerId: String) {
        NSLog("📥 [VideoSession] ANSWER from \(peerId)")
        guard let sdpString = sdp["sdp"] as? String, let pc = peerConnection else { return }
        let remoteDesc = RTCSessionDescription(type: .answer, sdp: sdpString)
        pc.setRemoteDescription(remoteDesc) { error in
            if let error = error {
                NSLog("❌ [VideoSession] setRemote answer: \(error)")
            } else {
                NSLog("✅ [VideoSession] remote answer set")
            }
        }
    }

    func peerJSClient(_ client: PeerJSClient, didReceiveCandidate candidate: [String: Any], connectionId: String, from peerId: String) {
        guard let sdp = candidate["candidate"] as? String,
              let sdpMid = candidate["sdpMid"] as? String else {
            NSLog("⚠️ [VideoSession] Received malformed ICE candidate from \(peerId)")
            return
        }
        let sdpMLineIndex = (candidate["sdpMLineIndex"] as? Int32) ?? 0
        NSLog("📥 [VideoSession] ICE candidate from \(peerId) mid=\(sdpMid)")
        let ice = RTCIceCandidate(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
        peerConnection?.add(ice)
    }

    func peerJSClient(_ client: PeerJSClient, didReceiveLeave peerId: String) {
        guard peerId == remotePeerId else { return }
        NSLog("📹 [VideoSession] remote peer left — ending call")
        DispatchQueue.main.async { [weak self] in self?.endCall() }
    }

    func peerJSClient(_ client: PeerJSClient, didDisconnectWithError error: Error?) {
        NSLog("📹 [VideoSession] PeerJS disconnected: \(error?.localizedDescription ?? "nil")")
    }
}

// MARK: - PeerConnection Delegate Wrapper

private final class VideoCallPCDelegate: NSObject, RTCPeerConnectionDelegate {
    weak var session: NativeVideoCallSession?
    init(session: NativeVideoCallSession) { self.session = session }

    func peerConnection(_ pc: RTCPeerConnection, didChange s: RTCSignalingState) {
        NSLog("📹 [PC] signaling: \(s.rawValue)")
    }
    func peerConnection(_ pc: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        session?.onRemoteStreamAdded(stream)
    }
    func peerConnection(_ pc: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ pc: RTCPeerConnection) {}
    func peerConnection(_ pc: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        NSLog("📹 [PC] ICE: \(newState.rawValue)")
        switch newState {
        case .connected, .completed: session?.onICEConnected()
        case .disconnected, .failed, .closed: session?.onICEDisconnected()
        default: break
        }
    }
    func peerConnection(_ pc: RTCPeerConnection, didChange s: RTCIceGatheringState) {}
    func peerConnection(_ pc: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        session?.onICECandidate(candidate)
    }
    func peerConnection(_ pc: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    func peerConnection(_ pc: RTCPeerConnection, didOpen dc: RTCDataChannel) {}
}
