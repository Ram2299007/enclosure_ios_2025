import Foundation
import WebRTC
import AVFoundation

// MARK: - Delegate Protocol
protocol NativeWebRTCManagerDelegate: AnyObject {
    func webRTCManager(_ manager: NativeWebRTCManager, didGenerateLocalSDP sdp: RTCSessionDescription, forPeer peerId: String)
    func webRTCManager(_ manager: NativeWebRTCManager, didGenerateICECandidate candidate: RTCIceCandidate, forPeer peerId: String)
    func webRTCManager(_ manager: NativeWebRTCManager, didConnectPeer peerId: String)
    func webRTCManager(_ manager: NativeWebRTCManager, didDisconnectPeer peerId: String)
    func webRTCManagerDidReceiveRemoteAudio(_ manager: NativeWebRTCManager)
    func webRTCManagerCallEnded(_ manager: NativeWebRTCManager)
}

// MARK: - NativeWebRTCManager
final class NativeWebRTCManager: NSObject {

    weak var delegate: NativeWebRTCManagerDelegate?

    // MARK: - Private State
    private let factory: RTCPeerConnectionFactory
    private var peerConnections: [String: RTCPeerConnection] = [:]
    private var delegateWrappers: [String: PeerConnectionDelegateWrapper] = [:]
    private var localAudioTrack: RTCAudioTrack?
    private var localStream: RTCMediaStream?
    private var isMuted: Bool = false
    private let audioSession = AVAudioSession.sharedInstance()

    // ICE servers (STUN + TURN)
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
    override init() {
        // Tell WebRTC to use manual audio — required for CallKit integration.
        // Without this, WebRTC fights CallKit for audio session and mic capture fails.
        let rtcAudioSession = RTCAudioSession.sharedInstance()
        rtcAudioSession.useManualAudio = true
        
        // CRITICAL: On lock screen + cold start, didActivate may fire BEFORE this init.
        // If CallKit already activated audio, do NOT reset isAudioEnabled — that undoes
        // the activation and causes "no mic" on lock screen answered calls.
        // Only disable audio if CallKit hasn't activated yet (normal flow).
        if !CallKitManager.shared.isAudioSessionReady {
            rtcAudioSession.isAudioEnabled = false
            NSLog("📞 [NativeWebRTC] Audio not yet active — isAudioEnabled=false (will activate on didActivate)")
        } else {
            NSLog("📞 [NativeWebRTC] CallKit audio ALREADY active — keeping isAudioEnabled=\(rtcAudioSession.isAudioEnabled)")
        }
        
        // Pre-configure the audio session settings WebRTC should use.
        // These are applied when RTCAudioSession is activated (via didActivate).
        // Do NOT configure AVAudioSession directly — let CallKit + RTCAudioSession manage it.
        let config = RTCAudioSessionConfiguration.webRTC()
        config.category = AVAudioSession.Category.playAndRecord.rawValue
        config.categoryOptions = [.allowBluetooth, .allowBluetoothA2DP]
        config.mode = AVAudioSession.Mode.voiceChat.rawValue
        RTCAudioSessionConfiguration.setWebRTC(config)
        NSLog("✅ [NativeWebRTC] RTCAudioSession: useManualAudio=true, config=voiceChat+bluetooth")

        RTCInitializeSSL()
        factory = RTCPeerConnectionFactory()
        super.init()
        NSLog("✅ [NativeWebRTC] RTCPeerConnectionFactory created")
    }

    deinit {
        stopAll()
        RTCCleanupSSL()
    }

    // MARK: - Audio Setup

    /// Configure AVAudioSession for HD voice call (earpiece by default).
    /// Call this AFTER CallKit didActivate fires for incoming calls.
    func configureAudioSession(useEarpiece: Bool = true) {
        do {
            try audioSession.setCategory(.playAndRecord,
                                         mode: .voiceChat,
                                         options: [.allowBluetooth, .allowBluetoothA2DP])
            // HD audio: 48kHz sample rate for Opus wideband
            try audioSession.setPreferredSampleRate(48000)
            // Low-latency buffer for real-time voice
            try audioSession.setPreferredIOBufferDuration(0.005) // 5ms
            try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
            if useEarpiece {
                try audioSession.overrideOutputAudioPort(.none)
            } else {
                try audioSession.overrideOutputAudioPort(.speaker)
            }
            let route = audioSession.currentRoute
            NSLog("✅ [NativeWebRTC] HD audio configured. Rate: \(audioSession.sampleRate)Hz, Buffer: \(audioSession.ioBufferDuration)s, Output: \(route.outputs.map { $0.portType.rawValue })")
        } catch {
            NSLog("❌ [NativeWebRTC] Audio session config failed: \(error.localizedDescription)")
        }
    }

    func setAudioOutput(speaker: Bool) {
        do {
            try audioSession.overrideOutputAudioPort(speaker ? .speaker : .none)
            NSLog("🔊 [NativeWebRTC] Audio output → \(speaker ? "Speaker" : "Earpiece")")
        } catch {
            NSLog("❌ [NativeWebRTC] setAudioOutput failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Local Audio Track

    func createLocalAudioTrack() {
        guard localAudioTrack == nil else {
            NSLog("ℹ️ [NativeWebRTC] Local audio track already exists")
            return
        }
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["echoCancellation": "true",
                                  "noiseSuppression": "true",
                                  "autoGainControl": "true"]
        )
        let audioSource = factory.audioSource(with: constraints)
        let track = factory.audioTrack(with: audioSource, trackId: "audio0")
        track.isEnabled = true
        localAudioTrack = track
        let stream = factory.mediaStream(withStreamId: "localStream")
        stream.addAudioTrack(track)
        localStream = stream
        NSLog("✅ [NativeWebRTC] Local audio track + stream created")
    }

    // MARK: - Peer Connection

    func createPeerConnection(forPeer peerId: String) -> RTCPeerConnection? {
        if let existing = peerConnections[peerId] {
            NSLog("ℹ️ [NativeWebRTC] Peer connection already exists for: \(peerId)")
            return existing
        }

        let config = RTCConfiguration()
        config.iceServers = iceServers
        config.continualGatheringPolicy = .gatherContinually
        config.iceCandidatePoolSize = 10
        // Network resilience: allow ICE restart and use both IPv4/IPv6
        config.bundlePolicy = .maxBundle
        config.rtcpMuxPolicy = .require
        config.tcpCandidatePolicy = .enabled

        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
        )

        let wrapper = PeerConnectionDelegateWrapper(peerId: peerId, manager: self)
        delegateWrappers[peerId] = wrapper

        let pc = factory.peerConnection(with: config, constraints: constraints, delegate: wrapper)

        // Add local stream (GoogleWebRTC 1.0 Plan B — addStream not addTrack)
        if let stream = localStream {
            pc.add(stream)
            NSLog("✅ [NativeWebRTC] Added local stream to peer: \(peerId)")
        }

        peerConnections[peerId] = pc
        NSLog("✅ [NativeWebRTC] RTCPeerConnection created for peer: \(peerId)")
        return pc
    }

    // MARK: - Offer / Answer

    /// Caller side: create offer and set local SDP
    func createOffer(forPeer peerId: String) {
        guard let pc = createPeerConnection(forPeer: peerId) else { return }

        let constraints = RTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveAudio": "true"],
            optionalConstraints: nil
        )

        pc.offer(for: constraints) { [weak self] sdp, error in
            guard let self = self, let sdp = sdp else {
                NSLog("❌ [NativeWebRTC] createOffer failed for \(peerId): \(error?.localizedDescription ?? "nil")")
                return
            }
            pc.setLocalDescription(sdp) { error in
                if let error = error {
                    NSLog("❌ [NativeWebRTC] setLocalDescription (offer) failed: \(error.localizedDescription)")
                    return
                }
                NSLog("✅ [NativeWebRTC] Local SDP (offer) set for peer: \(peerId)")
                if self.delegate == nil {
                    NSLog("❌ [NativeWebRTC] DELEGATE IS NIL — offer will NOT be sent to Firebase!")
                } else {
                    NSLog("📤 [NativeWebRTC] Calling delegate.didGenerateLocalSDP for offer")
                }
                self.delegate?.webRTCManager(self, didGenerateLocalSDP: sdp, forPeer: peerId)
            }
        }
    }

    /// Receiver side: set remote offer SDP, create answer
    func handleRemoteOffer(_ sdpString: String, fromPeer peerId: String) {
        let sdp = RTCSessionDescription(type: .offer, sdp: sdpString)
        guard let pc = createPeerConnection(forPeer: peerId) else { return }

        pc.setRemoteDescription(sdp) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                NSLog("❌ [NativeWebRTC] setRemoteDescription (offer) failed for \(peerId): \(error.localizedDescription)")
                return
            }
            NSLog("✅ [NativeWebRTC] Remote offer set for peer: \(peerId)")
            self.createAnswer(forPeer: peerId, pc: pc)
        }
    }

    private func createAnswer(forPeer peerId: String, pc: RTCPeerConnection) {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveAudio": "true"],
            optionalConstraints: nil
        )
        pc.answer(for: constraints) { [weak self] sdp, error in
            guard let self = self, let sdp = sdp else {
                NSLog("❌ [NativeWebRTC] createAnswer failed for \(peerId): \(error?.localizedDescription ?? "nil")")
                return
            }
            pc.setLocalDescription(sdp) { error in
                if let error = error {
                    NSLog("❌ [NativeWebRTC] setLocalDescription (answer) failed: \(error.localizedDescription)")
                    return
                }
                NSLog("✅ [NativeWebRTC] Local SDP (answer) set for peer: \(peerId)")
                self.delegate?.webRTCManager(self, didGenerateLocalSDP: sdp, forPeer: peerId)
            }
        }
    }

    /// Caller side: set remote answer SDP
    func handleRemoteAnswer(_ sdpString: String, fromPeer peerId: String) {
        guard let pc = peerConnections[peerId] else {
            NSLog("⚠️ [NativeWebRTC] No peer connection for answer from: \(peerId)")
            return
        }
        let sdp = RTCSessionDescription(type: .answer, sdp: sdpString)
        pc.setRemoteDescription(sdp) { error in
            if let error = error {
                NSLog("❌ [NativeWebRTC] setRemoteDescription (answer) failed for \(peerId): \(error.localizedDescription)")
            } else {
                NSLog("✅ [NativeWebRTC] Remote answer set for peer: \(peerId)")
            }
        }
    }

    // MARK: - ICE Candidates

    func handleRemoteICECandidate(_ candidateDict: [String: Any], fromPeer peerId: String) {
        guard let sdpMid = candidateDict["sdpMid"] as? String,
              let sdpMLineIndex = candidateDict["sdpMLineIndex"] as? Int32,
              let sdp = candidateDict["candidate"] as? String else {
            NSLog("⚠️ [NativeWebRTC] Invalid ICE candidate dict from: \(peerId)")
            return
        }
        let candidate = RTCIceCandidate(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
        guard let pc = peerConnections[peerId] else {
            NSLog("⚠️ [NativeWebRTC] No peer connection for ICE from: \(peerId)")
            return
        }
        pc.add(candidate)
    }

    // MARK: - Mute / Unmute

    func setMuted(_ muted: Bool) {
        isMuted = muted
        localAudioTrack?.isEnabled = !muted
        NSLog("🎤 [NativeWebRTC] Mic \(muted ? "MUTED" : "UNMUTED")")
    }

    // MARK: - RTCAudioSession (CallKit bridge)

    /// Call when CallKit audio session is active (didActivate or audio ready).
    /// This tells WebRTC's audio engine to start capturing mic audio.
    /// NOTE: didActivate now directly activates RTCAudioSession, so this may be a no-op.
    func activateAudioSession() {
        let rtcAudioSession = RTCAudioSession.sharedInstance()
        // ALWAYS call audioSessionDidActivate — even if isAudioEnabled is already true.
        // On lock screen + cold start, didActivate may have set isAudioEnabled=true before
        // the RTCPeerConnectionFactory and audio tracks existed. Re-calling ensures the
        // audio pipeline is properly connected to the now-existing tracks.
        let wasEnabled = rtcAudioSession.isAudioEnabled
        rtcAudioSession.audioSessionDidActivate(audioSession)
        rtcAudioSession.isAudioEnabled = true
        NSLog("✅ [NativeWebRTC] RTCAudioSession activated — mic capture enabled (wasEnabled=\(wasEnabled))")
    }

    /// Call on cleanup to release WebRTC audio.
    func deactivateAudioSession() {
        let rtcAudioSession = RTCAudioSession.sharedInstance()
        rtcAudioSession.audioSessionDidDeactivate(audioSession)
        rtcAudioSession.isAudioEnabled = false
        NSLog("🔴 [NativeWebRTC] RTCAudioSession deactivated")
    }

    // MARK: - ICE Restart (Network Resilience)

    /// Trigger ICE restart for a specific peer when connection drops.
    /// Creates a new offer with iceRestart=true to re-establish connectivity.
    func restartICE(forPeer peerId: String) {
        guard let pc = peerConnections[peerId] else {
            NSLog("⚠️ [NativeWebRTC] No peer connection for ICE restart: \(peerId)")
            return
        }

        NSLog("🔄 [NativeWebRTC] ICE restart for peer: \(peerId)")
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: ["IceRestart": "true", "OfferToReceiveAudio": "true"],
            optionalConstraints: nil
        )

        pc.offer(for: constraints) { [weak self] sdp, error in
            guard let self = self, let sdp = sdp else {
                NSLog("❌ [NativeWebRTC] ICE restart offer failed: \(error?.localizedDescription ?? "nil")")
                return
            }
            pc.setLocalDescription(sdp) { error in
                if let error = error {
                    NSLog("❌ [NativeWebRTC] ICE restart setLocal failed: \(error.localizedDescription)")
                    return
                }
                NSLog("✅ [NativeWebRTC] ICE restart offer set — sending to peer")
                self.delegate?.webRTCManager(self, didGenerateLocalSDP: sdp, forPeer: peerId)
            }
        }
    }

    // MARK: - Cleanup

    func removePeer(_ peerId: String) {
        guard let pc = peerConnections[peerId] else { return }
        pc.close()
        peerConnections.removeValue(forKey: peerId)
        NSLog("🔴 [NativeWebRTC] Peer connection closed for: \(peerId)")
    }

    func stopAll() {
        peerConnections.values.forEach { $0.close() }
        peerConnections.removeAll()
        delegateWrappers.removeAll()
        localAudioTrack = nil
        localStream = nil
        NSLog("🔴 [NativeWebRTC] All peer connections closed")
    }

    // MARK: - Internal Callbacks (called by PeerConnectionDelegateWrapper)

    fileprivate func onICECandidate(_ candidate: RTCIceCandidate, peerId: String) {
        NSLog("🧊 [NativeWebRTC] ICE candidate for \(peerId): \(candidate.sdpMid ?? "nil")")
        delegate?.webRTCManager(self, didGenerateICECandidate: candidate, forPeer: peerId)
    }

    fileprivate func onRemoteStreamAdded(_ stream: RTCMediaStream, peerId: String) {
        NSLog("🔊 [NativeWebRTC] Remote stream from peer: \(peerId), audioTracks: \(stream.audioTracks.count)")
        if !stream.audioTracks.isEmpty {
            delegate?.webRTCManagerDidReceiveRemoteAudio(self)
        }
    }
}

// MARK: - PeerConnectionDelegateWrapper
private final class PeerConnectionDelegateWrapper: NSObject, RTCPeerConnectionDelegate {
    let peerId: String
    weak var manager: NativeWebRTCManager?
    private var connectedReported = false

    init(peerId: String, manager: NativeWebRTCManager) {
        self.peerId = peerId
        self.manager = manager
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        NSLog("🔗 [NativeWebRTC] Peer \(peerId) signaling: \(stateChanged.rawValue)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        manager?.onRemoteStreamAdded(stream, peerId: peerId)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        NSLog("🔴 [NativeWebRTC] Peer \(peerId) removed stream")
    }

    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        NSLog("🔗 [NativeWebRTC] Peer \(peerId) ICE: \(newState.rawValue)")
        switch newState {
        case .connected, .completed:
            if !connectedReported {
                connectedReported = true
            }
            // Always report connect — needed for ICE restart reconnection
            manager?.delegate?.webRTCManager(manager!, didConnectPeer: peerId)
        case .disconnected:
            // Temporary disconnect — ICE restart may recover this
            // Reset connectedReported so reconnection can be reported
            connectedReported = false
            manager?.delegate?.webRTCManager(manager!, didDisconnectPeer: peerId)
        case .failed, .closed:
            // Permanent failure — report disconnect
            connectedReported = false
            manager?.delegate?.webRTCManager(manager!, didDisconnectPeer: peerId)
        default: break
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        NSLog("🔗 [NativeWebRTC] Peer \(peerId) ICE gathering: \(newState.rawValue)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        manager?.onICECandidate(candidate, peerId: peerId)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}
