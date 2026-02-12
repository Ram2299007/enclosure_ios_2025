import Foundation
import WebRTC
import FirebaseDatabase
import AVFoundation

/// Native WebRTC Call Manager
/// Replaces WebView-based calling with native implementation
/// Compatible with Android WebView (uses same Firebase signaling)
class NativeCallManager: NSObject {
    
    // MARK: - Properties
    
    static let shared = NativeCallManager()
    
    private let factory: RTCPeerConnectionFactory
    private var peerConnection: RTCPeerConnection?
    private var localAudioTrack: RTCAudioTrack?
    private var remoteAudioTrack: RTCAudioTrack?
    
    private let databaseRef = Database.database().reference()
    private var roomId: String = ""
    private var myUid: String = ""
    private var remoteUid: String = ""
    
    private var peersObserver: DatabaseHandle?
    private var signalingObserver: DatabaseHandle?
    
    // Audio session
    private let audioSession = AVAudioSession.sharedInstance()
    
    // Callbacks
    var onCallConnected: (() -> Void)?
    var onCallDisconnected: (() -> Void)?
    var onCallFailed: ((Error) -> Void)?
    
    // MARK: - Initialization
    
    private override init() {
        // Initialize WebRTC factory
        RTCInitializeSSL()
        
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        let decoderFactory = RTCDefaultVideoDecoderFactory()
        
        self.factory = RTCPeerConnectionFactory(
            encoderFactory: encoderFactory,
            decoderFactory: decoderFactory
        )
        
        super.init()
        
        print("✅ [NativeCallManager] Initialized with native WebRTC")
    }
    
    deinit {
        RTCCleanupSSL()
    }
    
    // MARK: - Public API
    
    /// Start a call
    /// - Parameters:
    ///   - roomId: Firebase room ID
    ///   - myUid: Current user ID
    ///   - remoteUid: Remote user ID
    ///   - isSender: true if initiating call, false if receiving
    func startCall(roomId: String, myUid: String, remoteUid: String, isSender: Bool) {
        print("📞 [NativeCallManager] Starting call - Room: \(roomId), Sender: \(isSender)")
        
        self.roomId = roomId
        self.myUid = myUid
        self.remoteUid = remoteUid
        
        // Setup audio session
        configureAudioSession()
        
        // Setup peer connection
        setupPeerConnection()
        
        // Add local audio track
        addLocalAudioTrack()
        
        // Register in Firebase
        registerPeerInFirebase()
        
        // Listen for remote peer
        listenForPeers()
        
        // Listen for signaling messages
        listenForSignaling()
        
        // If sender, create offer
        if isSender {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.createOffer()
            }
        }
    }
    
    /// End the call
    func endCall() {
        print("📞 [NativeCallManager] Ending call")
        
        // Close peer connection
        peerConnection?.close()
        peerConnection = nil
        
        // Stop local audio
        localAudioTrack = nil
        remoteAudioTrack = nil
        
        // Remove Firebase observers
        cleanupFirebaseListeners()
        
        // Deactivate audio session
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        
        onCallDisconnected?()
    }
    
    /// Toggle microphone
    func toggleMicrophone(muted: Bool) {
        localAudioTrack?.isEnabled = !muted
        print("🎤 [NativeCallManager] Microphone \(muted ? "muted" : "unmuted")")
    }
    
    /// Set audio output
    func setAudioOutput(_ output: String) {
        do {
            switch output {
            case "speaker":
                try audioSession.overrideOutputAudioPort(.speaker)
                print("🔊 [NativeCallManager] Audio output: Speaker")
            case "earpiece":
                try audioSession.overrideOutputAudioPort(.none)
                print("🔊 [NativeCallManager] Audio output: Earpiece")
            case "bluetooth":
                // Bluetooth routing handled automatically by iOS
                print("🔊 [NativeCallManager] Audio output: Bluetooth")
            default:
                break
            }
        } catch {
            print("❌ [NativeCallManager] Failed to set audio output: \(error)")
        }
    }
    
    // MARK: - Audio Session
    
    private func configureAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
            
            // Set preferred input
            if let builtInMic = audioSession.availableInputs?.first(where: { $0.portType == .builtInMic }) {
                try audioSession.setPreferredInput(builtInMic)
            }
            
            print("✅ [NativeCallManager] Audio session configured")
        } catch {
            print("❌ [NativeCallManager] Audio session error: \(error)")
        }
    }
    
    // MARK: - Peer Connection Setup
    
    private func setupPeerConnection() {
        let config = RTCConfiguration()
        
        // STUN/TURN servers (same as Android WebView)
        config.iceServers = [
            RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
            RTCIceServer(urlStrings: ["stun:stun1.l.google.com:19302"]),
            RTCIceServer(urlStrings: ["stun:stun2.l.google.com:19302"]),
            RTCIceServer(
                urlStrings: ["turn:openrelay.metered.ca:80"],
                username: "openrelay.project",
                credential: "openrelay"
            )
        ]
        
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually
        
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: nil
        )
        
        peerConnection = factory.peerConnection(
            with: config,
            constraints: constraints,
            delegate: self
        )
        
        print("✅ [NativeCallManager] Peer connection created")
    }
    
    private func addLocalAudioTrack() {
        let audioConstraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = factory.audioSource(with: audioConstraints)
        localAudioTrack = factory.audioTrack(with: audioSource, trackId: "audio0")
        
        if let peerConnection = peerConnection, let localAudioTrack = localAudioTrack {
            peerConnection.add(localAudioTrack, streamIds: ["stream0"])
            print("✅ [NativeCallManager] Local audio track added")
        }
    }
    
    // MARK: - Firebase Signaling
    
    private func registerPeerInFirebase() {
        let peerData: [String: Any] = [
            "peerId": myUid,
            "name": "User",  // Get from user profile
            "photo": ""      // Get from user profile
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: peerData),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        databaseRef
            .child("rooms")
            .child(roomId)
            .child("peers")
            .child(myUid)
            .setValue(jsonString)
        
        print("✅ [NativeCallManager] Registered in Firebase room: \(roomId)")
    }
    
    private func listenForPeers() {
        peersObserver = databaseRef
            .child("rooms")
            .child(roomId)
            .child("peers")
            .observe(.value) { [weak self] snapshot in
                guard let self = self else { return }
                
                print("👥 [NativeCallManager] Peers updated in room")
                
                // Check if remote peer joined
                for child in snapshot.children {
                    guard let childSnapshot = child as? DataSnapshot else { continue }
                    let peerId = childSnapshot.key
                    
                    if peerId != self.myUid {
                        print("✅ [NativeCallManager] Remote peer joined: \(peerId)")
                    }
                }
            }
    }
    
    private func listenForSignaling() {
        signalingObserver = databaseRef
            .child("rooms")
            .child(roomId)
            .child("signaling")
            .observe(.childAdded) { [weak self] snapshot in
                guard let self = self else { return }
                guard let value = snapshot.value as? String else { return }
                guard let data = value.data(using: .utf8) else { return }
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
                
                self.handleSignalingMessage(json)
            }
    }
    
    private func handleSignalingMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        guard let sender = message["sender"] as? String else { return }
        
        // Ignore our own messages
        if sender == myUid { return }
        
        print("📨 [NativeCallManager] Received signaling: \(type) from \(sender)")
        
        switch type {
        case "offer":
            handleOffer(message)
        case "answer":
            handleAnswer(message)
        case "candidate":
            handleIceCandidate(message)
        default:
            break
        }
    }
    
    // MARK: - SDP Handling
    
    private func createOffer() {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveAudio": "true"],
            optionalConstraints: nil
        )
        
        peerConnection?.offer(for: constraints) { [weak self] sdp, error in
            guard let self = self, let sdp = sdp, error == nil else {
                print("❌ [NativeCallManager] Failed to create offer: \(error?.localizedDescription ?? "unknown")")
                return
            }
            
            self.peerConnection?.setLocalDescription(sdp) { error in
                if let error = error {
                    print("❌ [NativeCallManager] Failed to set local description: \(error)")
                    return
                }
                
                print("✅ [NativeCallManager] Offer created, sending to Firebase")
                self.sendOffer(sdp: sdp)
            }
        }
    }
    
    private func sendOffer(sdp: RTCSessionDescription) {
        let offerData: [String: Any] = [
            "type": "offer",
            "sender": myUid,
            "receiver": remoteUid,
            "sdp": sdp.sdp
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: offerData),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        databaseRef
            .child("rooms")
            .child(roomId)
            .child("signaling")
            .childByAutoId()
            .setValue(jsonString)
        
        print("📤 [NativeCallManager] Offer sent to Firebase")
    }
    
    private func handleOffer(_ message: [String: Any]) {
        guard let sdpString = message["sdp"] as? String else { return }
        
        let remoteSdp = RTCSessionDescription(type: .offer, sdp: sdpString)
        
        peerConnection?.setRemoteDescription(remoteSdp) { [weak self] error in
            if let error = error {
                print("❌ [NativeCallManager] Failed to set remote description: \(error)")
                return
            }
            
            print("✅ [NativeCallManager] Remote offer set, creating answer")
            self?.createAnswer()
        }
    }
    
    private func createAnswer() {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveAudio": "true"],
            optionalConstraints: nil
        )
        
        peerConnection?.answer(for: constraints) { [weak self] sdp, error in
            guard let self = self, let sdp = sdp, error == nil else {
                print("❌ [NativeCallManager] Failed to create answer: \(error?.localizedDescription ?? "unknown")")
                return
            }
            
            self.peerConnection?.setLocalDescription(sdp) { error in
                if let error = error {
                    print("❌ [NativeCallManager] Failed to set local description: \(error)")
                    return
                }
                
                print("✅ [NativeCallManager] Answer created, sending to Firebase")
                self.sendAnswer(sdp: sdp)
            }
        }
    }
    
    private func sendAnswer(sdp: RTCSessionDescription) {
        let answerData: [String: Any] = [
            "type": "answer",
            "sender": myUid,
            "receiver": remoteUid,
            "sdp": sdp.sdp
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: answerData),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        databaseRef
            .child("rooms")
            .child(roomId)
            .child("signaling")
            .childByAutoId()
            .setValue(jsonString)
        
        print("📤 [NativeCallManager] Answer sent to Firebase")
    }
    
    private func handleAnswer(_ message: [String: Any]) {
        guard let sdpString = message["sdp"] as? String else { return }
        
        let remoteSdp = RTCSessionDescription(type: .answer, sdp: sdpString)
        
        peerConnection?.setRemoteDescription(remoteSdp) { error in
            if let error = error {
                print("❌ [NativeCallManager] Failed to set remote answer: \(error)")
                return
            }
            
            print("✅ [NativeCallManager] Remote answer set")
        }
    }
    
    // MARK: - ICE Candidate Handling
    
    private func handleIceCandidate(_ message: [String: Any]) {
        guard let candidateDict = message["candidate"] as? [String: Any],
              let sdp = candidateDict["candidate"] as? String,
              let sdpMLineIndex = candidateDict["sdpMLineIndex"] as? Int32,
              let sdpMid = candidateDict["sdpMid"] as? String else { return }
        
        let candidate = RTCIceCandidate(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
        
        peerConnection?.add(candidate) { error in
            if let error = error {
                print("❌ [NativeCallManager] Failed to add ICE candidate: \(error)")
            } else {
                print("✅ [NativeCallManager] ICE candidate added")
            }
        }
    }
    
    private func sendIceCandidate(_ candidate: RTCIceCandidate) {
        let candidateData: [String: Any] = [
            "type": "candidate",
            "sender": myUid,
            "receiver": remoteUid,
            "candidate": [
                "candidate": candidate.sdp,
                "sdpMLineIndex": candidate.sdpMLineIndex,
                "sdpMid": candidate.sdpMid ?? ""
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: candidateData),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        databaseRef
            .child("rooms")
            .child(roomId)
            .child("signaling")
            .childByAutoId()
            .setValue(jsonString)
        
        print("📤 [NativeCallManager] ICE candidate sent to Firebase")
    }
    
    // MARK: - Cleanup
    
    private func cleanupFirebaseListeners() {
        if let peersObserver = peersObserver {
            databaseRef
                .child("rooms")
                .child(roomId)
                .child("peers")
                .removeObserver(withHandle: peersObserver)
        }
        
        if let signalingObserver = signalingObserver {
            databaseRef
                .child("rooms")
                .child(roomId)
                .child("signaling")
                .removeObserver(withHandle: signalingObserver)
        }
        
        // Remove our peer from Firebase
        databaseRef
            .child("rooms")
            .child(roomId)
            .child("peers")
            .child(myUid)
            .removeValue()
    }
}

// MARK: - RTCPeerConnectionDelegate

extension NativeCallManager: RTCPeerConnectionDelegate {
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print("📡 [NativeCallManager] Signaling state: \(stateChanged.rawValue)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print("✅ [NativeCallManager] Remote stream added")
        
        if let audioTrack = stream.audioTracks.first {
            self.remoteAudioTrack = audioTrack
            print("🎵 [NativeCallManager] Remote audio track received - you should hear audio now!")
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        print("⚠️ [NativeCallManager] Remote stream removed")
        self.remoteAudioTrack = nil
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        print("🔄 [NativeCallManager] Should negotiate")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        print("🧊 [NativeCallManager] ICE connection state: \(newState.rawValue)")
        
        switch newState {
        case .connected:
            print("✅✅✅ [NativeCallManager] CALL CONNECTED!")
            DispatchQueue.main.async {
                self.onCallConnected?()
            }
        case .disconnected:
            print("⚠️ [NativeCallManager] Call disconnected")
        case .failed:
            print("❌ [NativeCallManager] Call failed")
            DispatchQueue.main.async {
                self.onCallFailed?(NSError(domain: "WebRTC", code: -1, userInfo: [NSLocalizedDescriptionKey: "Connection failed"]))
            }
        case .closed:
            print("📞 [NativeCallManager] Call closed")
            DispatchQueue.main.async {
                self.onCallDisconnected?()
            }
        default:
            break
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        print("🧊 [NativeCallManager] ICE gathering state: \(newState.rawValue)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        print("🧊 [NativeCallManager] ICE candidate generated")
        sendIceCandidate(candidate)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        print("🧊 [NativeCallManager] ICE candidates removed")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        print("📊 [NativeCallManager] Data channel opened")
    }
}
