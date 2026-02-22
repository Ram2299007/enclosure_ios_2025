import Foundation
import FirebaseDatabase
import WebRTC

// MARK: - Signaling Message Types
enum SignalingMessageType: String {
    case offer      = "offer"
    case answer     = "answer"
    case candidate  = "candidate"
    case candidates = "candidates"
    case endCall    = "endCall"
}

// MARK: - Delegate
protocol FirebaseSignalingDelegate: AnyObject {
    /// Remote peer sent us an SDP offer
    func signalingService(_ service: FirebaseSignalingService, didReceiveOffer sdp: String, fromPeer peerId: String)
    /// Remote peer sent us an SDP answer
    func signalingService(_ service: FirebaseSignalingService, didReceiveAnswer sdp: String, fromPeer peerId: String)
    /// Remote peer sent an ICE candidate
    func signalingService(_ service: FirebaseSignalingService, didReceiveICECandidate candidate: [String: Any], fromPeer peerId: String)
    /// Remote peer joined the room (new peer ID appeared)
    func signalingService(_ service: FirebaseSignalingService, peerJoined peerId: String, name: String, photo: String)
    /// Peer count dropped to 0 — other side ended the call
    func signalingServicePeerCountDroppedToZero(_ service: FirebaseSignalingService)
    /// Remote peer sent endCall signal
    func signalingServiceReceivedEndCall(_ service: FirebaseSignalingService, fromPeer peerId: String)
}

// MARK: - FirebaseSignalingService
/// Handles Firebase-based signaling for Native WebRTC.
/// Firebase structure (same as existing Android/JS):
///   rooms/{roomId}/peers/{peerId}  → JSON string with peerId, name, photo
///   rooms/{roomId}/signaling/{key} → JSON string with type, sender, receiver, sdp/candidate
final class FirebaseSignalingService {

    weak var delegate: FirebaseSignalingDelegate?

    private let roomId: String
    private let myPeerId: String
    private let myName: String
    private let myPhoto: String

    private var databaseRef: DatabaseReference?
    private var peersHandle: DatabaseHandle?
    private var signalingHandle: DatabaseHandle?
    private var knownPeers: Set<String> = []

    // ICE candidate batching — collect candidates for 150ms then send as single Firebase write
    private var pendingCandidates: [String: [RTCIceCandidate]] = [:]
    private var candidateBatchTimers: [String: DispatchWorkItem] = [:]

    // MARK: - Init
    init(roomId: String, myPeerId: String, myName: String, myPhoto: String) {
        self.roomId = roomId
        self.myPeerId = myPeerId
        self.myName = myName
        self.myPhoto = myPhoto
    }

    // MARK: - Start / Stop

    func start() {
        databaseRef = Database.database().reference()
        registerMyPeer()
        listenForPeers()
        listenForSignaling()
        NSLog("✅ [Signaling] Started for room: \(roomId), myPeerId: \(myPeerId)")
    }

    func stop(removeRoom: Bool) {
        guard let ref = databaseRef else { return }

        if let h = peersHandle {
            ref.child("rooms").child(roomId).child("peers").removeObserver(withHandle: h)
            peersHandle = nil
        }
        if let h = signalingHandle {
            ref.child("rooms").child(roomId).child("signaling").removeObserver(withHandle: h)
            signalingHandle = nil
        }

        if removeRoom {
            ref.child("rooms").child(roomId).removeValue { error, _ in
                if let error = error {
                    NSLog("⚠️ [Signaling] Failed to remove room: \(error.localizedDescription)")
                } else {
                    NSLog("✅ [Signaling] Room removed: \(self.roomId)")
                }
            }
        } else {
            ref.child("rooms").child(roomId).child("peers").child(myPeerId).removeValue()
        }

        databaseRef = nil
        NSLog("🔴 [Signaling] Stopped for room: \(roomId)")
    }

    // MARK: - Register Self

    private func registerMyPeer() {
        guard let ref = databaseRef else { return }
        let payload: [String: Any] = [
            "peerId": myPeerId,
            "name": myName,
            "photo": myPhoto.isEmpty ? "user.svg" : myPhoto,
            "native": true
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let jsonString = String(data: data, encoding: .utf8) {
            ref.child("rooms").child(roomId).child("peers").child(myPeerId).setValue(jsonString)
            NSLog("✅ [Signaling] Registered peer: \(myPeerId) in room: \(roomId)")
        }
    }

    // MARK: - Listen for Peers

    private func listenForPeers() {
        guard let ref = databaseRef else { return }
        peersHandle = ref.child("rooms").child(roomId).child("peers")
            .observe(.value) { [weak self] snapshot in
                guard let self = self else { return }

                var currentPeerIds = Set<String>()

                for child in snapshot.children {
                    guard let childSnapshot = child as? DataSnapshot,
                          let value = childSnapshot.value as? String,
                          let data = value.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                    else { continue }

                    let peerId = json["peerId"] as? String ?? ""
                    guard !peerId.isEmpty, peerId != self.myPeerId else { continue }
                    currentPeerIds.insert(peerId)

                    // New peer joined
                    if !self.knownPeers.contains(peerId) {
                        self.knownPeers.insert(peerId)
                        let name = json["name"] as? String ?? "Unknown"
                        let photo = json["photo"] as? String ?? ""
                        NSLog("👤 [Signaling] New peer joined: \(peerId) (\(name))")
                        self.delegate?.signalingService(self, peerJoined: peerId, name: name, photo: photo)
                    }
                }

                // Check if all peers left (only after we've registered ourselves)
                let peerCount = snapshot.childrenCount
                NSLog("📞 [Signaling] Peers in room: \(peerCount)")
                if peerCount == 0 {
                    NSLog("📞 [Signaling] Peer count dropped to 0 — other side ended call")
                    self.delegate?.signalingServicePeerCountDroppedToZero(self)
                }
            }
    }

    // MARK: - Listen for Signaling Messages

    private func listenForSignaling() {
        guard let ref = databaseRef else { return }
        signalingHandle = ref.child("rooms").child(roomId).child("signaling")
            .observe(.childAdded) { [weak self] snapshot in
                guard let self = self,
                      let value = snapshot.value as? String,
                      let data = value.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else { return }

                let receiver = json["receiver"] as? String ?? ""
                guard receiver == self.myPeerId || receiver == "all" else { return }

                // Consume message (remove from Firebase)
                snapshot.ref.removeValue()

                let sender = json["sender"] as? String ?? ""
                let typeStr = json["type"] as? String ?? ""
                let snapshotKey = snapshot.key
                guard let type = SignalingMessageType(rawValue: typeStr) else { return }

                NSLog("📨 [Signaling] Received \(typeStr) from \(sender) (key=\(snapshotKey))")

                switch type {
                case .offer:
                    if let sdp = json["sdp"] as? String {
                        self.delegate?.signalingService(self, didReceiveOffer: sdp, fromPeer: sender)
                    }
                case .answer:
                    if let sdp = json["sdp"] as? String {
                        self.delegate?.signalingService(self, didReceiveAnswer: sdp, fromPeer: sender)
                    }
                case .candidate:
                    if let candidateDict = json["candidate"] as? [String: Any] {
                        self.delegate?.signalingService(self, didReceiveICECandidate: candidateDict, fromPeer: sender)
                    }
                case .candidates:
                    // Batch: array of ICE candidates in one message
                    if let arr = json["candidates"] as? [[String: Any]] {
                        NSLog("📨 [Signaling] Received \(arr.count) batched candidates from \(sender)")
                        for c in arr {
                            self.delegate?.signalingService(self, didReceiveICECandidate: c, fromPeer: sender)
                        }
                    }
                case .endCall:
                    self.delegate?.signalingServiceReceivedEndCall(self, fromPeer: sender)
                }
            }
    }

    // MARK: - Send Signaling Messages

    func sendOffer(sdp: RTCSessionDescription, toPeer peerId: String) {
        let message: [String: Any] = [
            "type": SignalingMessageType.offer.rawValue,
            "sender": myPeerId,
            "receiver": peerId,
            "sdp": sdp.sdp
        ]
        sendMessage(message)
    }

    func sendAnswer(sdp: RTCSessionDescription, toPeer peerId: String) {
        let message: [String: Any] = [
            "type": SignalingMessageType.answer.rawValue,
            "sender": myPeerId,
            "receiver": peerId,
            "sdp": sdp.sdp
        ]
        sendMessage(message)
    }

    func sendICECandidate(_ candidate: RTCIceCandidate, toPeer peerId: String) {
        // Batch ICE candidates: collect for 150ms then send all in one Firebase write
        if pendingCandidates[peerId] == nil {
            pendingCandidates[peerId] = []
        }
        pendingCandidates[peerId]?.append(candidate)

        // Cancel existing timer for this peer and start a new 150ms debounce
        candidateBatchTimers[peerId]?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.flushCandidates(forPeer: peerId)
        }
        candidateBatchTimers[peerId] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)
    }

    /// Flush all pending ICE candidates for a peer as a single batched Firebase write
    private func flushCandidates(forPeer peerId: String) {
        guard let candidates = pendingCandidates[peerId], !candidates.isEmpty else { return }
        pendingCandidates[peerId] = nil
        candidateBatchTimers[peerId] = nil

        let candidatesArray: [[String: Any]] = candidates.map { c in
            ["candidate": c.sdp, "sdpMid": c.sdpMid ?? "", "sdpMLineIndex": c.sdpMLineIndex]
        }
        let message: [String: Any] = [
            "type": SignalingMessageType.candidates.rawValue,
            "sender": myPeerId,
            "receiver": peerId,
            "candidates": candidatesArray
        ]
        sendMessage(message)
        NSLog("📤 [Signaling] Sent \(candidates.count) batched candidates to \(peerId)")
    }

    func sendEndCall() {
        let message: [String: Any] = [
            "type": SignalingMessageType.endCall.rawValue,
            "sender": myPeerId,
            "receiver": "all"
        ]
        sendMessage(message)
        NSLog("📤 [Signaling] Sent endCall to all")
    }

    // MARK: - Private Send Helper

    private func sendMessage(_ message: [String: Any]) {
        guard let ref = databaseRef,
              let data = try? JSONSerialization.data(withJSONObject: message),
              let jsonString = String(data: data, encoding: .utf8)
        else {
            NSLog("❌ [Signaling] Failed to serialize message: \(message["type"] ?? "?")")
            return
        }
        let key = ref.child("rooms").child(roomId).child("signaling").childByAutoId().key ?? UUID().uuidString
        ref.child("rooms").child(roomId).child("signaling").child(key).setValue(jsonString)
        NSLog("📤 [Signaling] Sent \(message["type"] ?? "?") to \(message["receiver"] ?? "?")")
    }
}
