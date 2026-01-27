import Foundation
import FirebaseDatabase
import AVFoundation
import WebKit

final class VoiceCallSession: ObservableObject {
    @Published var shouldDismiss = false

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
    private var isAudioInterrupted = false
    private var lastAudioActivationTime: TimeInterval = 0

    init(payload: VoiceCallPayload) {
        self.payload = payload
        self.roomId = payload.roomId ?? Self.generateRoomId()
        self.myUid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        self.myName = UserDefaults.standard.string(forKey: Constant.full_name) ?? "Name"
        self.myPhoto = UserDefaults.standard.string(forKey: Constant.profilePic) ?? ""
    }

    func attach(webView: WKWebView) {
        self.webView = webView
    }

    func start() {
        requestMicrophoneAccess()
        databaseRef = Database.database().reference()
        setupFirebaseListeners()
        startObservingAudioInterruptions()
    }

    func stop() {
        cleanupFirebaseListeners()
        stopObservingAudioInterruptions()
    }

    func handleMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        switch type {
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
                setMicrophoneMuted(mute)
            }
        case "saveMuteState":
            if let mute = message["mute"] as? Bool {
                UserDefaults.standard.set(mute, forKey: "voice_call_muted")
            }
        case "checkBluetoothAvailability":
            updateBluetoothAvailability()
        case "onPeerConnected":
            requestMicrophonePermissionIfNeeded()
        case "onCallConnected":
            ensureAudioSessionActive()
        case "sendBroadcast":
            break
        case "endCall":
            endCall()
        case "callOnBackPressed":
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
            if let enabled = message["enabled"] as? Bool {
                setAudioOutput(enabled ? "speaker" : "earpiece")
            }
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
        if let peerId = myPeerId {
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
                // Resume audio when interruption ends
                if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        self.ensureAudioSessionActive()
                    }
                } else {
                    self.ensureAudioSessionActive()
                }
            @unknown default:
                break
            }
        }
    }

    private func stopObservingAudioInterruptions() {
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
            interruptionObserver = nil
        }
    }

    private func ensureAudioSessionActive() {
        guard audioSession.recordPermission == .granted else { return }
        guard !isAudioInterrupted else { return }
        let now = Date().timeIntervalSince1970
        if now - lastAudioActivationTime < 0.5 {
            return
        }
        lastAudioActivationTime = now
        do {
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker])
            try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
        } catch {
            print("⚠️ [VoiceCallSession] Audio session error: \(error.localizedDescription)")
        }
    }

    private func setAudioOutput(_ output: String) {
        guard audioSession.recordPermission == .granted else { return }
        guard !isAudioInterrupted else { return }
        ensureAudioSessionActive()

        do {
            switch output {
            case "speaker":
                try audioSession.overrideOutputAudioPort(.speaker)
            case "earpiece":
                try audioSession.overrideOutputAudioPort(.none)
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

    private func updateBluetoothAvailability() {
        let hasBluetooth = audioSession.availableInputs?.contains(where: { input in
            input.portType == .bluetoothHFP || input.portType == .bluetoothA2DP
        }) ?? false
        sendToWebView("setBluetoothAvailability(\(hasBluetooth ? "true" : "false"))")
    }

    private func endCall() {
        cleanupFirebaseListeners()
        shouldDismiss = true
    }

    private func sendToWebView(_ javascript: String) {
        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript("javascript:\(javascript)", completionHandler: nil)
        }
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
}
