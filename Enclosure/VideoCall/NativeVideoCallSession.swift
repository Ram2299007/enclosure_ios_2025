//
//  NativeVideoCallSession.swift
//  Enclosure
//
//  Native WebRTC video call session management
//

import Foundation
import WebRTC
import FirebaseDatabase
import AVFoundation
import UIKit

final class NativeVideoCallSession: ObservableObject {
    @Published var shouldDismiss = false
    @Published var isCallConnected = false
    @Published var isMicrophoneMuted = false
    @Published var isCameraOff = false
    @Published var callerName = "Unknown"
    
    // Video views
    var localVideoView: RTCVideoRenderer?
    var remoteVideoView: RTCVideoRenderer?
    
    private let payload: VideoCallPayload
    private let roomId: String
    private let myUid: String
    private let myName: String
    private let myPhoto: String
    
    // WebRTC components
    private let peerConnection: RTCPeerConnection
    private var localVideoTrack: RTCVideoTrack?
    private var localAudioTrack: RTCAudioTrack?
    private var remoteVideoTrack: RTCVideoTrack?
    private var remoteAudioTrack: RTCAudioTrack?
    
    // Firebase
    private var databaseRef: DatabaseReference?
    private var peersHandle: DatabaseHandle?
    private var signalingHandle: DatabaseHandle?
    
    // Camera management
    private var videoCapturer: RTCVideoCapturer?
    private var currentCameraPosition = AVCaptureDevice.Position.front
    
    init(payload: VideoCallPayload) {
        self.payload = payload
        self.roomId = payload.roomId ?? Self.generateRoomId()
        self.myUid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        self.myName = UserDefaults.standard.string(forKey: Constant.full_name) ?? "Name"
        self.myPhoto = UserDefaults.standard.string(forKey: Constant.profilePic) ?? ""
        
        // Set caller name
        self.callerName = payload.receiverName.isEmpty ? "Unknown" : payload.receiverName
        
        // Initialize WebRTC with ICE servers
        let iceServers = [
            RTCIceServer(url: "stun:stun.l.google.com:19302"),
            RTCIceServer(url: "stun:stun1.l.google.com:19302"),
            RTCIceServer(url: "turn:openrelay.metered.ca:80", username: "openrelay.project", credential: "openrelay")
        ]
        
        let config = RTCConfiguration()
        config.iceServers = iceServers
        config.sdpSemantics = .unifiedPlan
        
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let factory = RTCPeerConnectionFactory()
        self.peerConnection = factory.peerConnection(with: config, constraints: constraints, delegate: self)
    }
    
    func start() {
        setupFirebaseListeners()
        setupLocalMedia()
        
        if payload.isSender {
            // Outgoing call - initiate connection
            initiateCall()
        } else {
            // Incoming call - wait for offer
            listenForIncomingCall()
        }
    }
    
    func stop() {
        peerConnection.close()
        videoCapturer?.stopCapture()
        cleanupFirebaseListeners()
    }
    
    func toggleMicrophone() {
        isMicrophoneMuted.toggle()
        localAudioTrack?.isEnabled = !isMicrophoneMuted
    }
    
    func toggleCamera() {
        isCameraOff.toggle()
        localVideoTrack?.isEnabled = !isCameraOff
    }
    
    func switchCamera() {
        guard !isCameraOff else { return }
        
        currentCameraPosition = currentCameraPosition == .front ? .back : .front
        
        // Reconfigure video capturer with new camera position
        setupVideoCapturer()
    }
    
    func endCall() {
        // Send end call signal to Firebase
        if let databaseRef = databaseRef {
            let endCallData: [String: Any] = [
                "type": "endCall",
                "sender": myUid,
                "timestamp": ServerValue.timestamp()
            ]
            databaseRef.child("signaling").child(roomId).setValue(endCallData)
        }
        
        shouldDismiss = true
    }
    
    // MARK: - Private Methods
    
    private func setupLocalMedia() {
        let factory = RTCPeerConnectionFactory()
        
        // Setup audio
        let audioConstraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = factory.audioSource(with: audioConstraints)
        localAudioTrack = factory.audioTrack(with: audioSource, trackId: "audio0")
        
        // Setup video
        setupVideoCapturer()
        
        // Create media stream and add tracks
        let mediaStream = factory.mediaStream(withStreamId: "ARDAMS")
        mediaStream.addAudioTrack(localAudioTrack!)
        
        // Add video track if available
        if let videoTrack = localVideoTrack {
            mediaStream.addVideoTrack(videoTrack)
        }
        
        // Add stream to peer connection
        peerConnection.add(mediaStream)
    }
    
    private func setupVideoCapturer() {
        // Find camera device
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition) else {
            print("Failed to find camera")
            return
        }
        
        // Create WebRTC video source and capturer
        let factory = RTCPeerConnectionFactory()
        let videoSource = factory.videoSource()
        videoCapturer = RTCVideoCapturer(delegate: videoSource)
        
        // Create video track
        localVideoTrack = factory.videoTrack(with: videoSource, trackId: "video0")
        
        // Setup camera input
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            
            // Create session
            let session = AVCaptureSession()
            session.sessionPreset = .medium
            
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            // Setup video output
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }
            
            // Start session
            session.startRunning()
            
            // Link with WebRTC capturer
            if let capturer = videoCapturer as? RTCCameraVideoCapturer {
                capturer.captureSession = session
            }
            
        } catch {
            print("Failed to setup camera: \(error)")
        }
    }
    
    private func setupFirebaseListeners() {
        databaseRef = Database.database().reference()
        
        // Listen for peers in the room
        peersHandle = databaseRef?.child("rooms").child(roomId).child("peers").observe(.value) { snapshot in
            // Handle peer list updates
        }
        
        // Listen for signaling messages
        signalingHandle = databaseRef?.child("signaling").child(roomId).observe(.childAdded) { snapshot in
            guard let data = snapshot.value as? [String: Any],
                  let type = data["type"] as? String,
                  let sender = data["sender"] as? String,
                  sender != self.myUid else { return }
            
            self.handleSignalingMessage(data: data, from: sender)
        }
    }
    
    private func cleanupFirebaseListeners() {
        if let handle = peersHandle {
            databaseRef?.child("rooms").child(roomId).child("peers").removeObserver(withHandle: handle)
        }
        if let handle = signalingHandle {
            databaseRef?.child("signaling").child(roomId).removeObserver(withHandle: handle)
        }
    }
    
    private func initiateCall() {
        // Create and send offer
        peerConnection.offer(for: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)) { sdp, error in
            guard let sdp = sdp else { return }
            
            self.peerConnection.setLocalDescription(sdp) { error in
                guard error == nil else { return }
                
                // Send offer to Firebase
                let offerData: [String: Any] = [
                    "type": "offer",
                    "sdp": sdp.toJSON(),
                    "sender": self.myUid,
                    "timestamp": ServerValue.timestamp()
                ]
                
                self.databaseRef?.child("signaling").child(self.roomId).setValue(offerData)
            }
        }
    }
    
    private func listenForIncomingCall() {
        // Waiting for offer in signaling listener
    }
    
    private func handleSignalingMessage(data: [String: Any], from sender: String) {
        guard let type = data["type"] as? String else { return }
        
        switch type {
        case "offer":
            handleOffer(data: data, from: sender)
        case "answer":
            handleAnswer(data: data, from: sender)
        case "ice-candidate":
            handleIceCandidate(data: data)
        case "endCall":
            shouldDismiss = true
        default:
            break
        }
    }
    
    private func handleOffer(data: [String: Any], from sender: String) {
        guard let sdpDict = data["sdp"] as? [String: Any],
              let sdp = RTCSessionDescription(from: sdpDict) else { return }
        
        peerConnection.setRemoteDescription(sdp) { error in
            guard error == nil else { return }
            
            // Create and send answer
            self.peerConnection.answer(for: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)) { sdp, error in
                guard let sdp = sdp else { return }
                
                self.peerConnection.setLocalDescription(sdp) { error in
                    guard error == nil else { return }
                    
                    let answerData: [String: Any] = [
                        "type": "answer",
                        "sdp": sdp.toJSON(),
                        "sender": self.myUid,
                        "timestamp": ServerValue.timestamp()
                    ]
                    
                    self.databaseRef?.child("signaling").child(self.roomId).setValue(answerData)
                }
            }
        }
    }
    
    private func handleAnswer(data: [String: Any], from sender: String) {
        guard let sdpDict = data["sdp"] as? [String: Any],
              let sdp = RTCSessionDescription(from: sdpDict) else { return }
        
        peerConnection.setRemoteDescription(sdp) { error in
            // Connection established
        }
    }
    
    private func handleIceCandidate(data: [String: Any]) {
        guard let candidateDict = data["candidate"] as? [String: Any],
              let candidate = RTCIceCandidate(from: candidateDict) else { return }
        
        peerConnection.add(candidate)
    }
    
    private static func generateRoomId() -> String {
        return "\(Int(Date().timeIntervalSince1970 * 1000))\(Int.random(in: 1000...9999))"
    }
}

// MARK: - RTCPeerConnectionDelegate

extension NativeVideoCallSession: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print("Signaling state changed: \(stateChanged)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        DispatchQueue.main.async {
            if let videoTrack = stream.videoTracks.first {
                self.remoteVideoTrack = videoTrack
                videoTrack.add(self.remoteVideoView!)
                self.isCallConnected = true
            }
            
            if let audioTrack = stream.audioTracks.first {
                self.remoteAudioTrack = audioTrack
                audioTrack.isEnabled = true
            }
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        DispatchQueue.main.async {
            if let videoTrack = stream.videoTracks.first, videoTrack == self.remoteVideoTrack {
                self.remoteVideoTrack = nil
                self.isCallConnected = false
            }
            
            if let audioTrack = stream.audioTracks.first, audioTrack == self.remoteAudioTrack {
                self.remoteAudioTrack = nil
            }
        }
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) -> Bool {
        return true
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCIceConnectionState) {
        DispatchQueue.main.async {
            switch stateChanged {
            case .connected:
                self.isCallConnected = true
            case .disconnected, .failed, .closed:
                self.isCallConnected = false
            default:
                break
            }
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCIceGatheringState) {
        print("ICE gathering state changed: \(stateChanged)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        let candidateData: [String: Any] = [
            "type": "ice-candidate",
            "candidate": candidate.toJSON(),
            "sender": myUid,
            "timestamp": ServerValue.timestamp()
        ]
        
        databaseRef?.child("signaling").child(roomId).setValue(candidateData)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        print("Removed ICE candidates")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        print("Data channel opened")
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension NativeVideoCallSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Forward video frames to WebRTC capturer
        videoCapturer?.captureSampleBuffer(sampleBuffer)
    }
}
