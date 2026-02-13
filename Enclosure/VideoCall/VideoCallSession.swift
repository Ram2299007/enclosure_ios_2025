import Foundation
import FirebaseDatabase
import AVFoundation
import AudioToolbox
import WebKit
import UIKit

final class VideoCallSession: ObservableObject {
    @Published var shouldDismiss = false

    private let payload: VideoCallPayload
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
    private var routeChangeObserver: NSObjectProtocol?
    private var isAudioInterrupted = false
    private var isReconfiguringAudioForCall = false
    private var ringtonePlayer: AVAudioPlayer?
    private var ringtoneKeepAliveTimer: Timer?
    private var isCallConnected = false
    private var ringtoneSystemSoundId: SystemSoundID = 0
    private var ringtoneSystemSoundTimer: Timer?
    private var proximityObserver: NSObjectProtocol?

    private var callKitAudioReadyObserver: NSObjectProtocol?
    private var isWaitingForCallKitAudio = false

    private var mediaStartRetryWorkItem: DispatchWorkItem?

    private var isPageReady = false

    private var removeCallNotificationSent = false

    init(payload: VideoCallPayload) {
        self.payload = payload
        self.roomId = payload.roomId ?? Self.generateRoomId()
        self.myUid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        self.myName = UserDefaults.standard.string(forKey: Constant.full_name) ?? "Name"
        self.myPhoto = UserDefaults.standard.string(forKey: Constant.profilePic) ?? ""
    }

    func attach(webView: WKWebView) {
        self.webView = webView
    }

    /// Call from WKNavigationDelegate didFinish so caller name/photo show as soon as page loads (before onPageReady from script).
    func sendCallerInfoToWebViewIfNeeded() {
        let safePhoto = payload.receiverPhoto.isEmpty ? "user.png" : payload.receiverPhoto
        let safeName = payload.receiverName.isEmpty ? "Name" : payload.receiverName
        sendToWebView("if (typeof setRemoteCallerInfo === 'function') { setRemoteCallerInfo('\(jsEscaped(safePhoto))', '\(jsEscaped(safeName))'); }")
        sendToWebView("if (typeof setThemeColor === 'function') { setThemeColor('\(jsEscaped(Constant.themeColor))'); }")
    }

    /// Call before loading the WebView URL so camera/mic are requested and WKWebView getUserMedia sees granted state.
    func requestCameraAndMicrophoneAccessIfNeeded() {
        requestCameraAndMicrophoneAccess()
    }

    func start() {
        isCallConnected = false
        isPageReady = false
        requestCameraAndMicrophoneAccess()
        databaseRef = Database.database().reference()
        setupFirebaseListeners()
        startObservingAudioInterruptions()
        if payload.isSender {
            startRingtone()
        } else {
            // Incoming CallKit call: wait for CallKit to finish activating audio session before starting getUserMedia.
            if CallKitManager.shared.isAudioSessionReady {
                attemptStartLocalMedia(reason: "callkit_audio_already_ready")
            } else {
                isWaitingForCallKitAudio = true
                callKitAudioReadyObserver = NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("CallKitAudioSessionReady"),
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    guard let self, self.isWaitingForCallKitAudio else { return }
                    self.isWaitingForCallKitAudio = false
                    self.attemptStartLocalMedia(reason: "callkit_audio_ready")
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    guard let self, self.isWaitingForCallKitAudio else { return }
                    self.isWaitingForCallKitAudio = false
                    self.attemptStartLocalMedia(reason: "callkit_audio_timeout")
                }
            }
        }
    }

    func stop() {
        cleanupFirebaseListeners()
        stopObservingAudioInterruptions()
        stopRingtone(reason: "session_stop")
        disableProximitySensor()

        mediaStartRetryWorkItem?.cancel()
        mediaStartRetryWorkItem = nil

        if let observer = callKitAudioReadyObserver {
            NotificationCenter.default.removeObserver(observer)
            callKitAudioReadyObserver = nil
        }
        isWaitingForCallKitAudio = false
    }

    func handleMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        switch type {
        case "sendPeerId":
            if let peerId = message["peerId"] as? String {
                handleSendPeerId(peerId)
            }
        case "toggleMicrophone":
            if let mute = message["mute"] as? Bool {
                setMicrophoneMuted(mute)
            }
        case "saveMuteState":
            if let mute = message["mute"] as? Bool {
                UserDefaults.standard.set(mute, forKey: "video_call_muted")
            }
        case "onPeerConnected":
            requestCameraAndMicrophonePermissionIfNeeded()
        case "onCallConnected":
            isCallConnected = true
            stopRingtone(reason: "call_connected")
            enableProximitySensor()
            reconfigureAudioSessionForCall()
            requestCameraAndMicrophonePermissionIfNeeded()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.sendToWebView("if (typeof initializeLocalStream === 'function') { initializeLocalStream().catch(function(){}); }")
            }
            // Force WebView to show receiver in primary, my video in secondary (like Android)
            let layoutJS = "updateVideoLayout(); updateVideoMirroring(); if (typeof applyConnectedLayoutFromPeers === 'function') applyConnectedLayoutFromPeers();"
            DispatchQueue.main.async { [weak self] in
                self?.sendToWebView(layoutJS)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.sendToWebView(layoutJS)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.sendToWebView(layoutJS)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
                self?.sendToWebView(layoutJS)
            }
        case "endCall":
            endCall()
        case "callOnBackPressed":
            shouldDismiss = true
            stopRingtone(reason: "back_pressed")
            disableProximitySensor()
        case "addMemberBtn":
            // TODO: Implement add member functionality
            break
        case "onPageReady":
            handlePageReady()
        case "toggleFullScreen":
            // Video calls handle fullscreen in WebView
            break
        case "enterPiPMode":
            // Picture-in-picture mode handled in WebView
            break
        case "sendSignalingData":
            if let data = message["data"] as? String {
                sendSignalingData(data)
            }
        default:
            break
        }
    }

    private func handlePageReady() {
        sendToWebView("setRoomId('\(jsEscaped(roomId))')")
        let safePhoto = payload.receiverPhoto.isEmpty ? "user.png" : payload.receiverPhoto
        let safeName = payload.receiverName.isEmpty ? "Name" : payload.receiverName
        sendToWebView("setRemoteCallerInfo('\(jsEscaped(safePhoto))', '\(jsEscaped(safeName))')")
        sendToWebView("setThemeColor('\(jsEscaped(Constant.themeColor))')")
        isPageReady = true
        // Default: start unmuted (do not restore saved mute state so mic is unmuted by default)
        // Start local media after page is ready (guard in JS prevents double init)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.attemptStartLocalMedia(reason: "page_ready")
        }
    }

    private func handleSendPeerId(_ peerId: String) {
        myPeerId = peerId

        guard let databaseRef else { return }
        let peerPayload: [String: Any] = [
            "peerId": peerId,
            "name": myName,
            "photo": myPhoto.isEmpty ? "user.png" : myPhoto
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

                    // Note: Video call script.js uses updatePeers and setRemoteCallerInfo, not setCallerInfo
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

    func requestCameraAndMicrophonePermissionIfNeeded() {
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let micStatus = audioSession.recordPermission

        print("📹 [VideoCallSession] Checking permissions - Camera: \(cameraStatus.rawValue), Mic: \(micStatus.rawValue)")

        if cameraStatus == .notDetermined {
            print("📹 [VideoCallSession] Requesting camera permission...")
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                print("📹 [VideoCallSession] Camera permission result: \(granted)")
                DispatchQueue.main.async {
                    self?.attemptStartLocalMedia(reason: "camera_permission_result")
                }
            }
        }

        if micStatus == .undetermined {
            print("🎤 [VideoCallSession] Requesting microphone permission...")
            audioSession.requestRecordPermission { [weak self] granted in
                print("🎤 [VideoCallSession] Microphone permission result: \(granted)")
                DispatchQueue.main.async {
                    self?.attemptStartLocalMedia(reason: "mic_permission_result")
                }
            }
        }

        attemptStartLocalMedia(reason: "permission_check")
    }

    private func attemptStartLocalMedia(reason: String) {
        guard let webView else { return }

        // Don't start getUserMedia until the page JS is ready.
        guard isPageReady else { return }

        // For incoming CallKit calls, don't start getUserMedia until CallKit has activated audio.
        if !payload.isSender, !CallKitManager.shared.isAudioSessionReady {
            return
        }

        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let micStatus = audioSession.recordPermission
        guard cameraStatus == .authorized, micStatus == .granted else {
            return
        }

        let js = "if (typeof startLocalStreamWithRetry === 'function') { startLocalStreamWithRetry(0); } else if (typeof initializeLocalStream === 'function') { initializeLocalStream().catch(function(){}); }"
        webView.evaluateJavaScript(js) { _, error in
            if let error = error {
                print("⚠️ [VideoCallSession] Failed to start local media (\(reason)): \(error.localizedDescription)")
            } else {
                print("📹 [VideoCallSession] Triggered local media start (\(reason))")
            }
        }

        scheduleMediaStartVerificationAndRetry(webView: webView)
    }

    private func scheduleMediaStartVerificationAndRetry(webView: WKWebView) {
        guard !payload.isSender else { return }

        mediaStartRetryWorkItem?.cancel()

        let work = DispatchWorkItem { [weak self, weak webView] in
            guard let self, let webView else { return }

            if UIApplication.shared.applicationState != .active {
                return
            }

            let checkJS = "(function(){try{var s=window.localStream; if(!s) return false; var ts=s.getTracks? s.getTracks(): []; if(!ts||!ts.length) return false; for(var i=0;i<ts.length;i++){var t=ts[i]; if(t && t.readyState==='live') return true;} return false;}catch(e){return false;}})();"
            webView.evaluateJavaScript(checkJS) { [weak self] result, _ in
                guard let self else { return }
                let started = (result as? Bool) ?? false
                if started {
                    return
                }

                let retryJS = "if (typeof startLocalStreamWithRetry === 'function') { startLocalStreamWithRetry(0); } else if (typeof initializeLocalStream === 'function') { initializeLocalStream().catch(function(){}); }"
                webView.evaluateJavaScript(retryJS, completionHandler: nil)

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.scheduleMediaStartVerificationAndRetry(webView: webView)
                }
            }
        }

        mediaStartRetryWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    private func requestCameraAndMicrophoneAccess() {
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let micStatus = audioSession.recordPermission
        
        if cameraStatus == .denied || micStatus == .denied {
            DispatchQueue.main.async {
                Constant.showToast(message: "Camera and microphone permissions are required for video calls.")
            }
            return
        }
        
        if cameraStatus == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.requestMicrophoneAccess()
                } else {
                    DispatchQueue.main.async {
                        Constant.showToast(message: "Camera permission is required for video calls.")
                    }
                }
            }
        } else {
            requestMicrophoneAccess()
        }
    }

    private func requestMicrophoneAccess() {
        switch audioSession.recordPermission {
        case .granted:
            ensureAudioSessionActive()
            attemptStartLocalMedia(reason: "mic_already_granted")
        case .denied:
            DispatchQueue.main.async {
                Constant.showToast(message: "Microphone permission is required for video calls.")
            }
        case .undetermined:
            audioSession.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.ensureAudioSessionActive()
                        self?.attemptStartLocalMedia(reason: "mic_granted_request")
                    } else {
                        Constant.showToast(message: "Microphone permission is required for video calls.")
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
                if self.isReconfiguringAudioForCall { return }
                if !self.isAudioInterrupted {
                    self.isAudioInterrupted = true
                    print("🔇 [VideoCallSession] Audio interruption began")
                }
            case .ended:
                if self.isAudioInterrupted {
                    self.isAudioInterrupted = false
                    print("🔊 [VideoCallSession] Audio interruption ended")
                    if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                        if options.contains(.shouldResume) {
                            // Small delay to avoid "already interrupted" errors
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                self.ensureAudioSessionActive()
                            }
                        }
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.ensureAudioSessionActive()
                        }
                    }
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
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            routeChangeObserver = nil
        }
    }

    /// Call when the call connects: deactivate session to clear "already interrupted" state, then reconfigure for video chat.
    private func reconfigureAudioSessionForCall() {
        guard audioSession.recordPermission == .granted else { return }
        isReconfiguringAudioForCall = true
        do {
            try audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            // Ignore
        }
        isAudioInterrupted = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self else { return }
            self.ensureAudioSessionActive()
            self.isReconfiguringAudioForCall = false
        }
    }

    private func ensureAudioSessionActive() {
        guard audioSession.recordPermission == .granted else { return }
        
        // Don't try to activate if already interrupted - wait for interruption to end
        if isAudioInterrupted {
            return
        }
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .videoChat, options: [.allowBluetooth, .defaultToSpeaker])
            try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
        } catch {
            // Ignore "already active" or "already interrupted" errors as they're harmless
            let errorDescription = error.localizedDescription
            if !errorDescription.contains("already") && !errorDescription.contains("interrupted") {
                print("⚠️ [VideoCallSession] Audio session error: \(errorDescription)")
            }
        }
    }

    private func setMicrophoneMuted(_ muted: Bool) {
        if audioSession.isInputGainSettable {
            do {
                try audioSession.setInputGain(muted ? 0.0 : 1.0)
            } catch {
                print("⚠️ [VideoCallSession] Failed to set input gain: \(error.localizedDescription)")
            }
        }
        UserDefaults.standard.set(muted, forKey: "video_call_muted")
    }

    private func endCall() {
        // Android behavior parity: if caller ends immediately, signal receiver to dismiss incoming-call UI.
        // Firebase path: removeVideoCallNotification/<receiverId>/<pushKey> = <pushKey>
        if payload.isSender {
            sendRemoveCallNotificationIfNeeded()
        }

        stopRingtone(reason: "end_call")
        cleanupFirebaseListeners()
        disableProximitySensor()
        shouldDismiss = true
    }

    private func sendRemoveCallNotificationIfNeeded() {
        guard !removeCallNotificationSent else { return }
        let receiverId = payload.receiverId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !receiverId.isEmpty else {
            NSLog("⚠️ [VideoCallSession] sendRemoveCallNotification: receiverId missing")
            return
        }
        removeCallNotificationSent = true

        let ref = Database.database().reference().child("removeVideoCallNotification").child(receiverId).childByAutoId()
        let key = ref.key ?? UUID().uuidString
        ref.setValue(key) { error, _ in
            if let error = error {
                NSLog("⚠️ [VideoCallSession] Failed to send removeCallNotification: \(error.localizedDescription)")
            } else {
                NSLog("✅ [VideoCallSession] removeCallNotification sent to receiverId=\(receiverId), key=\(key)")
            }
        }
    }

    private func sendSignalingData(_ data: String) {
        guard let databaseRef else { return }
        databaseRef.child("rooms").child(roomId).child("signaling").childByAutoId().setValue(data)
    }

    private func sendToWebView(_ javascript: String) {
        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript("javascript:\(javascript)", completionHandler: nil)
        }
    }

    private func startRingtone() {
        guard ringtonePlayer == nil else { return }
        print("🔔 [VideoCallRingtone] Starting ringtone for sender...")

        let mp3Url = Bundle.main.url(forResource: "ringtone", withExtension: "mp3", subdirectory: "VoiceCallAssets")
            ?? Bundle.main.url(forResource: "ringtone", withExtension: "mp3")
        let wavUrl = Bundle.main.url(forResource: "ringtone", withExtension: "wav", subdirectory: "VoiceCallAssets")
            ?? Bundle.main.url(forResource: "ringtone", withExtension: "wav")

        let candidateUrls = [mp3Url, wavUrl].compactMap { $0 }
        guard let ringtoneUrl = candidateUrls.first else {
            print("⚠️ [VideoCallRingtone] Ringtone asset not found in bundle.")
            return
        }

        do {
            try audioSession.setCategory(.playAndRecord, mode: .videoChat, options: [.allowBluetooth])
            try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
            
            var lastError: Error?
            var player: AVAudioPlayer?
            for url in candidateUrls {
                do {
                    let candidatePlayer = try AVAudioPlayer(contentsOf: url)
                    candidatePlayer.numberOfLoops = -1
                    candidatePlayer.volume = 1.0
                    candidatePlayer.prepareToPlay()
                    player = candidatePlayer
                    break
                } catch {
                    lastError = error
                }
            }

            guard let activePlayer = player else {
                if let lastError {
                    print("⚠️ [VideoCallRingtone] Failed to start ringtone: \(lastError.localizedDescription)")
                }
                startSystemRingtoneFallback()
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self else { return }
                if !activePlayer.isPlaying {
                    activePlayer.play()
                }
                self.ringtonePlayer = activePlayer
                self.startRingtoneKeepAlive()
            }
        } catch {
            print("⚠️ [VideoCallRingtone] Failed to start ringtone: \(error.localizedDescription)")
            startSystemRingtoneFallback()
        }
    }

    private func stopRingtone(reason: String) {
        if ringtonePlayer != nil {
            print("🔕 [VideoCallRingtone] Stopping ringtone (reason=\(reason))")
        }
        ringtoneKeepAliveTimer?.invalidate()
        ringtoneKeepAliveTimer = nil
        ringtonePlayer?.stop()
        ringtonePlayer = nil
        stopSystemRingtoneFallback()
    }

    private func startRingtoneKeepAlive() {
        ringtoneKeepAliveTimer?.invalidate()
        ringtoneKeepAliveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard !self.isCallConnected else { return }
            guard let player = self.ringtonePlayer else { return }
            
            if !player.isPlaying {
                player.play()
            }
        }
    }

    private func startSystemRingtoneFallback() {
        if ringtoneSystemSoundId != 0 || ringtoneSystemSoundTimer != nil {
            return
        }

        let wavUrl = Bundle.main.url(forResource: "ringtone", withExtension: "wav", subdirectory: "VoiceCallAssets")
            ?? Bundle.main.url(forResource: "ringtone", withExtension: "wav")
        guard let soundUrl = wavUrl else {
            print("⚠️ [VideoCallRingtone] System sound fallback failed: wav not found")
            return
        }

        let status = AudioServicesCreateSystemSoundID(soundUrl as CFURL, &ringtoneSystemSoundId)
        if status != kAudioServicesNoError || ringtoneSystemSoundId == 0 {
            print("⚠️ [VideoCallRingtone] System sound fallback failed: status=\(status)")
            return
        }

        print("🔔 [VideoCallRingtone] Using system sound fallback")
        ringtoneSystemSoundTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard !self.isCallConnected else { return }
            AudioServicesPlaySystemSound(self.ringtoneSystemSoundId)
        }
    }

    private func stopSystemRingtoneFallback() {
        ringtoneSystemSoundTimer?.invalidate()
        ringtoneSystemSoundTimer = nil
        if ringtoneSystemSoundId != 0 {
            AudioServicesDisposeSystemSoundID(ringtoneSystemSoundId)
            ringtoneSystemSoundId = 0
        }
    }

    // MARK: - Proximity Sensor Management
    
    private func enableProximitySensor() {
        guard UIDevice.current.isProximityMonitoringEnabled == false else { return }
        
        UIDevice.current.isProximityMonitoringEnabled = true
        print("📱 [VideoCallSession] Proximity sensor enabled")
        
        proximityObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.proximityStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            let isNear = UIDevice.current.proximityState
            print("📱 [VideoCallSession] Proximity state changed: \(isNear ? "Near" : "Far")")
        }
    }
    
    private func disableProximitySensor() {
        guard UIDevice.current.isProximityMonitoringEnabled == true else { return }
        
        if let observer = proximityObserver {
            NotificationCenter.default.removeObserver(observer)
            proximityObserver = nil
        }
        
        UIDevice.current.isProximityMonitoringEnabled = false
        print("📱 [VideoCallSession] Proximity sensor disabled")
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
