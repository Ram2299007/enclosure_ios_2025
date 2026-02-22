//
//  NativeVideoCallSession.swift
//  Enclosure
//
//  Native WebRTC video call session management
//  Uses same WebRTC API patterns as NativeWebRTCManager (GoogleWebRTC Plan B).
//

import Foundation
import WebRTC
import FirebaseDatabase
import AVFoundation
import UIKit

final class NativeVideoCallSession: NSObject, ObservableObject {
    @Published var shouldDismiss = false
    @Published var isCallConnected = false
    @Published var isMicrophoneMuted = false
    @Published var isCameraOff = false
    @Published var callerName = "Unknown"
    @Published var callDuration: TimeInterval = 0

    // Video renderers — set by the screen before start()
    var localRenderer: RTCEAGLVideoView?
    var remoteRenderer: RTCEAGLVideoView?

    let payload: VideoCallPayload
    private let roomId: String
    private let myUid: String
    private let myName: String
    private let myPhoto: String

    // WebRTC
    private let factory: RTCPeerConnectionFactory
    private var peerConnection: RTCPeerConnection?
    private var delegateWrapper: VideoCallPCDelegate?
    private var localVideoTrack: RTCVideoTrack?
    private var localAudioTrack: RTCAudioTrack?
    private var localStream: RTCMediaStream?
    private var remoteVideoTrack: RTCVideoTrack?

    // Camera
    private var cameraCapturer: RTCCameraVideoCapturer?
    private var videoSource: RTCVideoSource?
    private var currentCameraPosition: AVCaptureDevice.Position = .front

    // Firebase signaling
    private var databaseRef: DatabaseReference?
    private var signalingHandle: DatabaseHandle?
    private var peersHandle: DatabaseHandle?
    private var myPeerId: String = ""
    private var isCallEnded = false

    // Timer
    private var callTimer: Timer?

    // ICE servers (matching NativeWebRTCManager)
    private let iceServers: [RTCIceServer] = [
        RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
        RTCIceServer(urlStrings: ["stun:stun1.l.google.com:19302"]),
        RTCIceServer(urlStrings: ["stun:stun2.l.google.com:19302"]),
        RTCIceServer(
            urlStrings: ["turn:relay1.expressturn.com:3478"],
            username: "efWBBHBEBKZEFW8XHM",
            credential: "7Dn4xMUvLCGCnMBL"
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

        RTCInitializeSSL()
        self.factory = RTCPeerConnectionFactory()

        super.init()
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
        setupFirebaseSignaling()

        if payload.isSender {
            // Register ourselves in room, then wait for receiver to join
            registerInRoom()
        }
        NSLog("📹 [VideoSession] start() complete")
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
        // Notify remote via Firebase
        let ref = databaseRef ?? Database.database().reference()
        let endData: [String: Any] = [
            "type": "endCall",
            "sender": myPeerId
        ]
        ref.child("videoSignaling").child(roomId).childByAutoId().setValue(endData)
        // Remove ourselves from room
        ref.child("videoRooms").child(roomId).child("peers").child(myPeerId).removeValue()

        stop()
        DispatchQueue.main.async {
            self.shouldDismiss = true
        }
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
            NSLog("✅ [VideoSession] audio session configured for videoChat + speaker")
        } catch {
            NSLog("❌ [VideoSession] audio config error: \(error)")
        }
    }

    // MARK: - Local Tracks

    private func createLocalTracks() {
        // Audio track
        let audioConstraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["echoCancellation": "true",
                                  "noiseSuppression": "true",
                                  "autoGainControl": "true"]
        )
        let audioSource = factory.audioSource(with: audioConstraints)
        localAudioTrack = factory.audioTrack(with: audioSource, trackId: "audio0")
        localAudioTrack?.isEnabled = true

        // Video track
        videoSource = factory.videoSource()
        let capturer = RTCCameraVideoCapturer(delegate: videoSource!)
        cameraCapturer = capturer
        localVideoTrack = factory.videoTrack(with: videoSource!, trackId: "video0")
        localVideoTrack?.isEnabled = true

        // Attach local renderer
        if let lr = localRenderer {
            localVideoTrack?.add(lr)
        }

        // Start camera capture
        startCapture(with: capturer)

        // Create media stream (Plan B — addStream)
        let stream = factory.mediaStream(withStreamId: "localStream")
        stream.addAudioTrack(localAudioTrack!)
        stream.addVideoTrack(localVideoTrack!)
        localStream = stream

        NSLog("✅ [VideoSession] local tracks created (audio + video)")
    }

    private func startCapture(with capturer: RTCCameraVideoCapturer) {
        // Find the right camera device
        let devices = RTCCameraVideoCapturer.captureDevices()
        guard let device = devices.first(where: { $0.position == currentCameraPosition })
                ?? devices.first else {
            NSLog("❌ [VideoSession] no camera device found")
            return
        }

        // Pick a suitable format (640x480 or closest)
        let formats = RTCCameraVideoCapturer.supportedFormats(for: device)
        let targetWidth: Int32 = 640
        let targetHeight: Int32 = 480
        var selectedFormat: AVCaptureDevice.Format?
        var currentDiff = Int32.max

        for format in formats {
            let desc = format.formatDescription
            let dimensions = CMVideoFormatDescriptionGetDimensions(desc)
            let diff = abs(dimensions.width - targetWidth) + abs(dimensions.height - targetHeight)
            if diff < currentDiff {
                currentDiff = diff
                selectedFormat = format
            }
        }

        guard let format = selectedFormat else {
            NSLog("❌ [VideoSession] no suitable camera format")
            return
        }

        let fps = 30
        capturer.startCapture(with: device, format: format, fps: fps)
        let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        NSLog("📷 [VideoSession] capturing \(dims.width)x\(dims.height)@\(fps)fps pos=\(currentCameraPosition == .front ? "front" : "back")")
    }

    // MARK: - Peer Connection

    private func createPeerConnection() {
        let config = RTCConfiguration()
        config.iceServers = iceServers
        config.continualGatheringPolicy = .gatherContinually
        config.iceCandidatePoolSize = 10
        config.bundlePolicy = .maxBundle
        config.rtcpMuxPolicy = .require
        config.tcpCandidatePolicy = .enabled

        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "true",
                "OfferToReceiveVideo": "true"
            ],
            optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
        )

        let wrapper = VideoCallPCDelegate(session: self)
        delegateWrapper = wrapper

        let pc = factory.peerConnection(with: config, constraints: constraints, delegate: wrapper)

        // Add local stream (Plan B)
        if let stream = localStream {
            pc.add(stream)
        }

        peerConnection = pc
        NSLog("✅ [VideoSession] RTCPeerConnection created")
    }

    // MARK: - Firebase Signaling

    private func setupFirebaseSignaling() {
        databaseRef = Database.database().reference()
        myPeerId = myUid.isEmpty ? UUID().uuidString : myUid

        // Listen for signaling messages
        signalingHandle = databaseRef?.child("videoSignaling").child(roomId)
            .observe(.childAdded) { [weak self] snapshot in
                guard let self = self,
                      let data = snapshot.value as? [String: Any],
                      let sender = data["sender"] as? String,
                      sender != self.myPeerId else { return }
                self.handleSignalingMessage(data)
            }

        // Listen for peers
        peersHandle = databaseRef?.child("videoRooms").child(roomId).child("peers")
            .observe(.childAdded) { [weak self] snapshot in
                guard let self = self,
                      snapshot.key != self.myPeerId else { return }
                NSLog("📹 [VideoSession] peer joined: \(snapshot.key)")
                // Create PC and send offer
                if self.peerConnection == nil {
                    self.createPeerConnection()
                }
                self.createOffer()
            }
    }

    private func registerInRoom() {
        let peerData: [String: Any] = [
            "name": myName,
            "photo": myPhoto,
            "joinedAt": ServerValue.timestamp()
        ]
        databaseRef?.child("videoRooms").child(roomId).child("peers")
            .child(myPeerId).setValue(peerData)
        NSLog("📹 [VideoSession] registered in room \(roomId) as \(myPeerId)")
    }

    private func cleanupFirebase() {
        if let h = signalingHandle {
            databaseRef?.child("videoSignaling").child(roomId).removeObserver(withHandle: h)
        }
        if let h = peersHandle {
            databaseRef?.child("videoRooms").child(roomId).child("peers").removeObserver(withHandle: h)
        }
        databaseRef?.child("videoRooms").child(roomId).child("peers").child(myPeerId).removeValue()
    }

    // MARK: - Offer / Answer

    private func createOffer() {
        guard let pc = peerConnection else { return }
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "true",
                "OfferToReceiveVideo": "true"
            ],
            optionalConstraints: nil
        )
        pc.offer(for: constraints) { [weak self] sdp, error in
            guard let self = self, let sdp = sdp else {
                NSLog("❌ [VideoSession] createOffer failed: \(error?.localizedDescription ?? "")")
                return
            }
            pc.setLocalDescription(sdp) { error in
                if let error = error {
                    NSLog("❌ [VideoSession] setLocal offer error: \(error)")
                    return
                }
                let msg: [String: Any] = [
                    "type": "offer",
                    "sender": self.myPeerId,
                    "sdp": sdp.sdp
                ]
                self.databaseRef?.child("videoSignaling").child(self.roomId).childByAutoId().setValue(msg)
                NSLog("📤 [VideoSession] sent offer")
            }
        }
    }

    private func handleOffer(sdpString: String, from sender: String) {
        if peerConnection == nil {
            createPeerConnection()
        }
        guard let pc = peerConnection else { return }

        let sdp = RTCSessionDescription(type: .offer, sdp: sdpString)
        pc.setRemoteDescription(sdp) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                NSLog("❌ [VideoSession] setRemote offer error: \(error)")
                return
            }
            // Create answer
            let constraints = RTCMediaConstraints(
                mandatoryConstraints: [
                    "OfferToReceiveAudio": "true",
                    "OfferToReceiveVideo": "true"
                ],
                optionalConstraints: nil
            )
            pc.answer(for: constraints) { sdp, error in
                guard let sdp = sdp else {
                    NSLog("❌ [VideoSession] createAnswer error: \(error?.localizedDescription ?? "")")
                    return
                }
                pc.setLocalDescription(sdp) { error in
                    if let error = error {
                        NSLog("❌ [VideoSession] setLocal answer error: \(error)")
                        return
                    }
                    let msg: [String: Any] = [
                        "type": "answer",
                        "sender": self.myPeerId,
                        "sdp": sdp.sdp
                    ]
                    self.databaseRef?.child("videoSignaling").child(self.roomId).childByAutoId().setValue(msg)
                    NSLog("📤 [VideoSession] sent answer")
                }
            }
        }
    }

    private func handleAnswer(sdpString: String) {
        guard let pc = peerConnection else { return }
        let sdp = RTCSessionDescription(type: .answer, sdp: sdpString)
        pc.setRemoteDescription(sdp) { error in
            if let error = error {
                NSLog("❌ [VideoSession] setRemote answer error: \(error)")
            } else {
                NSLog("✅ [VideoSession] remote answer set")
            }
        }
    }

    private func handleIceCandidate(data: [String: Any]) {
        guard let sdp = data["candidate"] as? String,
              let sdpMid = data["sdpMid"] as? String,
              let sdpMLineIndex = data["sdpMLineIndex"] as? Int32 else { return }
        let candidate = RTCIceCandidate(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
        peerConnection?.add(candidate)
    }

    private func handleSignalingMessage(_ data: [String: Any]) {
        guard let type = data["type"] as? String else { return }
        let sender = data["sender"] as? String ?? ""

        switch type {
        case "offer":
            if let sdp = data["sdp"] as? String {
                handleOffer(sdpString: sdp, from: sender)
            }
        case "answer":
            if let sdp = data["sdp"] as? String {
                handleAnswer(sdpString: sdp)
            }
        case "ice-candidate":
            if let candidateDict = data["candidate"] as? [String: Any] {
                handleIceCandidate(data: candidateDict)
            }
        case "endCall":
            DispatchQueue.main.async { [weak self] in
                self?.stop()
                self?.shouldDismiss = true
            }
        default:
            break
        }
    }

    // MARK: - Internal Callbacks (from delegate wrapper)

    fileprivate func onICECandidate(_ candidate: RTCIceCandidate) {
        let candidateDict: [String: Any] = [
            "candidate": candidate.sdp,
            "sdpMid": candidate.sdpMid ?? "",
            "sdpMLineIndex": candidate.sdpMLineIndex
        ]
        let msg: [String: Any] = [
            "type": "ice-candidate",
            "sender": myPeerId,
            "candidate": candidateDict
        ]
        databaseRef?.child("videoSignaling").child(roomId).childByAutoId().setValue(msg)
    }

    fileprivate func onRemoteStreamAdded(_ stream: RTCMediaStream) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let videoTrack = stream.videoTracks.first {
                self.remoteVideoTrack = videoTrack
                if let rr = self.remoteRenderer {
                    videoTrack.add(rr)
                }
                NSLog("📹 [VideoSession] remote video track attached")
            }
            if !stream.audioTracks.isEmpty {
                NSLog("🔊 [VideoSession] remote audio track received")
            }
        }
    }

    fileprivate func onICEConnected() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if !self.isCallConnected {
                self.isCallConnected = true
                self.startCallTimer()
                NSLog("✅ [VideoSession] call connected")
            }
        }
    }

    fileprivate func onICEDisconnected() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isCallEnded else { return }
            self.isCallConnected = false
            NSLog("🔴 [VideoSession] call disconnected")
        }
    }

    private func startCallTimer() {
        callTimer?.invalidate()
        callDuration = 0
        callTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.callDuration += 1
            }
        }
    }

    private static func generateRoomId() -> String {
        return "\(Int(Date().timeIntervalSince1970 * 1000))\(Int.random(in: 1000...9999))"
    }
}

// MARK: - PeerConnection Delegate Wrapper (NSObject required for RTCPeerConnectionDelegate)

private final class VideoCallPCDelegate: NSObject, RTCPeerConnectionDelegate {
    weak var session: NativeVideoCallSession?

    init(session: NativeVideoCallSession) {
        self.session = session
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        NSLog("📹 [VideoPC] signaling: \(stateChanged.rawValue)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        session?.onRemoteStreamAdded(stream)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        NSLog("📹 [VideoPC] stream removed")
    }

    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        NSLog("📹 [VideoPC] ICE: \(newState.rawValue)")
        switch newState {
        case .connected, .completed:
            session?.onICEConnected()
        case .disconnected, .failed, .closed:
            session?.onICEDisconnected()
        default:
            break
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        NSLog("📹 [VideoPC] ICE gathering: \(newState.rawValue)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        session?.onICECandidate(candidate)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}
