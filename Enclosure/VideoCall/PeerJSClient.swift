//
//  PeerJSClient.swift
//  Enclosure
//
//  Native PeerJS signaling client that connects to the same PeerJS server
//  used by Android WebView (0.peerjs.com). Handles WebSocket messaging for
//  OFFER / ANSWER / CANDIDATE exchange so native iOS can connect to Android.
//

import Foundation

// MARK: - Delegate

protocol PeerJSClientDelegate: AnyObject {
    func peerJSClientDidOpen(_ client: PeerJSClient, peerId: String)
    func peerJSClient(_ client: PeerJSClient, didReceiveOffer sdp: [String: Any], connectionId: String, from peerId: String)
    func peerJSClient(_ client: PeerJSClient, didReceiveAnswer sdp: [String: Any], connectionId: String, from peerId: String)
    func peerJSClient(_ client: PeerJSClient, didReceiveCandidate candidate: [String: Any], connectionId: String, from peerId: String)
    func peerJSClient(_ client: PeerJSClient, didReceiveLeave peerId: String)
    func peerJSClient(_ client: PeerJSClient, didDisconnectWithError error: Error?)
}

// MARK: - PeerJSClient

final class PeerJSClient: NSObject, URLSessionWebSocketDelegate {
    weak var delegate: PeerJSClientDelegate?

    private(set) var peerId: String = ""
    private(set) var isConnected = false

    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var heartbeatTimer: Timer?

    // PeerJS server config (matching Android script.js)
    private let primaryHost = "0.peerjs.com"
    private let fallbackHost = "peer.enclosureapp.com"
    private let port = 443
    private let path = "/"
    private let secure = true
    private let key = "peerjs"
    private let connectionTimeoutSec: TimeInterval = 10

    private var hasFallenBack = false
    private var connectionTimer: Timer?

    // MARK: - Public

    func connect() {
        fetchPeerId(host: primaryHost) { [weak self] fetchedId in
            guard let self = self else { return }
            let id = fetchedId ?? UUID().uuidString
            self.connectWebSocket(host: self.primaryHost, peerId: id)

            // Fallback timer
            DispatchQueue.main.async {
                self.connectionTimer = Timer.scheduledTimer(withTimeInterval: self.connectionTimeoutSec, repeats: false) { [weak self] _ in
                    guard let self = self, !self.isConnected, !self.hasFallenBack else { return }
                    NSLog("⚠️ [PeerJS] Primary server timeout — falling back to \(self.fallbackHost)")
                    self.hasFallenBack = true
                    self.disconnectSocket()
                    self.fetchPeerId(host: self.fallbackHost) { [weak self] fallbackId in
                        guard let self = self else { return }
                        let fbId = fallbackId ?? id
                        self.connectWebSocket(host: self.fallbackHost, peerId: fbId)
                    }
                }
            }
        }
    }

    func disconnect() {
        connectionTimer?.invalidate()
        connectionTimer = nil
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        disconnectSocket()
        isConnected = false
        NSLog("🔴 [PeerJS] Disconnected")
    }

    // MARK: - Send messages

    func sendOffer(sdp: String, to dst: String, connectionId: String) {
        let msg: [String: Any] = [
            "type": "OFFER",
            "dst": dst,
            "payload": [
                "sdp": ["type": "offer", "sdp": sdp],
                "type": "media",
                "connectionId": connectionId,
                "browser": "Safari",
                "metadata": [String: Any]()
            ] as [String: Any]
        ]
        send(msg)
    }

    func sendAnswer(sdp: String, to dst: String, connectionId: String) {
        let msg: [String: Any] = [
            "type": "ANSWER",
            "dst": dst,
            "payload": [
                "sdp": ["type": "answer", "sdp": sdp],
                "type": "media",
                "connectionId": connectionId,
                "browser": "Safari"
            ] as [String: Any]
        ]
        send(msg)
    }

    func sendCandidate(candidate: String, sdpMid: String, sdpMLineIndex: Int32, to dst: String, connectionId: String) {
        let msg: [String: Any] = [
            "type": "CANDIDATE",
            "dst": dst,
            "payload": [
                "candidate": [
                    "candidate": candidate,
                    "sdpMid": sdpMid,
                    "sdpMLineIndex": sdpMLineIndex
                ] as [String: Any],
                "type": "media",
                "connectionId": connectionId
            ] as [String: Any]
        ]
        send(msg)
    }

    // MARK: - Private — networking

    private func fetchPeerId(host: String, completion: @escaping (String?) -> Void) {
        let scheme = secure ? "https" : "http"
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        guard let url = URL(string: "\(scheme)://\(host):\(port)\(path)peerjs/id?ts=\(ts)") else {
            completion(nil)
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let data = data,
               let id = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !id.isEmpty {
                NSLog("✅ [PeerJS] Fetched peer ID: \(id) from \(host)")
                completion(id)
            } else {
                NSLog("⚠️ [PeerJS] Failed to fetch ID from \(host): \(error?.localizedDescription ?? "nil")")
                completion(nil)
            }
        }.resume()
    }

    private func connectWebSocket(host: String, peerId: String) {
        self.peerId = peerId
        let scheme = secure ? "wss" : "ws"
        let token = generateToken()
        let urlStr = "\(scheme)://\(host):\(port)\(path)peerjs?key=\(key)&id=\(peerId)&token=\(token)"

        guard let url = URL(string: urlStr) else { return }
        NSLog("🔗 [PeerJS] Connecting WebSocket to \(host) as \(peerId)")

        urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        webSocket = urlSession?.webSocketTask(with: url)
        webSocket?.resume()
        scheduleReceive()
    }

    private func disconnectSocket() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
    }

    private func scheduleReceive() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text): self.handleText(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) { self.handleText(text) }
                @unknown default: break
                }
                self.scheduleReceive()
            case .failure(let error):
                NSLog("❌ [PeerJS] WebSocket receive error: \(error.localizedDescription)")
                self.isConnected = false
                self.delegate?.peerJSClient(self, didDisconnectWithError: error)
            }
        }
    }

    // MARK: - Message handling

    private func handleText(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "OPEN":
            NSLog("✅ [PeerJS] OPEN — connected as \(peerId)")
            isConnected = true
            connectionTimer?.invalidate()
            connectionTimer = nil
            startHeartbeat()
            delegate?.peerJSClientDidOpen(self, peerId: peerId)

        case "OFFER":
            guard let src = json["src"] as? String,
                  let payload = json["payload"] as? [String: Any],
                  let connId = payload["connectionId"] as? String else {
                NSLog("⚠️ [PeerJS] OFFER missing src/payload/connectionId")
                return
            }

            // Robust SDP extraction — handle dict, JSON string, or raw SDP string
            var sdpDict: [String: Any]?
            if let dict = payload["sdp"] as? [String: Any] {
                sdpDict = dict
            } else if let sdpJsonStr = payload["sdp"] as? String,
                      let d = sdpJsonStr.data(using: .utf8),
                      let parsed = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                sdpDict = parsed
            } else if let rawSdp = payload["sdp"] as? String {
                // Raw SDP string (not wrapped in {type, sdp})
                sdpDict = ["type": "offer", "sdp": rawSdp]
            }

            guard let sdp = sdpDict else {
                NSLog("⚠️ [PeerJS] OFFER has unrecognized sdp format: \(type(of: payload["sdp"]))")
                return
            }

            let sdpPreview = String(describing: sdp).prefix(300)
            NSLog("📥 [PeerJS] OFFER from \(src) connId=\(connId) sdpKeys=\(sdp.keys.sorted()) preview=\(sdpPreview)")
            delegate?.peerJSClient(self, didReceiveOffer: sdp, connectionId: connId, from: src)

        case "ANSWER":
            guard let src = json["src"] as? String,
                  let payload = json["payload"] as? [String: Any],
                  let connId = payload["connectionId"] as? String else { return }

            var sdpDict: [String: Any]?
            if let dict = payload["sdp"] as? [String: Any] {
                sdpDict = dict
            } else if let sdpJsonStr = payload["sdp"] as? String,
                      let d = sdpJsonStr.data(using: .utf8),
                      let parsed = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                sdpDict = parsed
            } else if let rawSdp = payload["sdp"] as? String {
                sdpDict = ["type": "answer", "sdp": rawSdp]
            }

            guard let sdp = sdpDict else { return }
            NSLog("📥 [PeerJS] ANSWER from \(src) sdpKeys=\(sdp.keys.sorted())")
            delegate?.peerJSClient(self, didReceiveAnswer: sdp, connectionId: connId, from: src)

        case "CANDIDATE":
            guard let src = json["src"] as? String,
                  let payload = json["payload"] as? [String: Any],
                  let candidate = payload["candidate"] as? [String: Any],
                  let connId = payload["connectionId"] as? String else { return }
            delegate?.peerJSClient(self, didReceiveCandidate: candidate, connectionId: connId, from: src)

        case "LEAVE":
            if let src = json["src"] as? String {
                NSLog("👋 [PeerJS] LEAVE from \(src)")
                delegate?.peerJSClient(self, didReceiveLeave: src)
            }

        case "HEARTBEAT":
            break // server ping — no action needed

        case "ID-TAKEN":
            NSLog("⚠️ [PeerJS] ID taken — reconnecting with new ID")
            disconnectSocket()
            let newId = UUID().uuidString
            let host = hasFallenBack ? fallbackHost : primaryHost
            connectWebSocket(host: host, peerId: newId)

        case "ERROR":
            NSLog("❌ [PeerJS] Server error: \(json)")

        default:
            NSLog("⚠️ [PeerJS] Unknown type: \(type)")
        }
    }

    // MARK: - Helpers

    private func send(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8) else { return }
        webSocket?.send(.string(text)) { error in
            if let error = error {
                NSLog("❌ [PeerJS] Send error: \(error.localizedDescription)")
            }
        }
    }

    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.send(["type": "HEARTBEAT"])
        }
    }

    private func generateToken() -> String {
        let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        return String((0..<20).map { _ in chars.randomElement()! })
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        NSLog("🔗 [PeerJS] WebSocket didOpen")
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        NSLog("🔗 [PeerJS] WebSocket didClose code=\(closeCode.rawValue)")
        isConnected = false
    }
}
