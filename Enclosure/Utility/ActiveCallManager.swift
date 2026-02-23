import Foundation
import Combine
import os.log

/// Singleton bridge between CallKit ↔ NativeVoiceCallSession / NativeVideoCallSession.
/// - Starts WebRTC session IMMEDIATELY when user answers (before UI appears)
/// - CallKit mute/end actions route through here to the live session
/// - Call screens connect to the already-running session
/// - Like WhatsApp: audio/video connects in background before UI
final class ActiveCallManager: ObservableObject {
    static let shared = ActiveCallManager()

    /// The currently active voice call session (started on CallKit answer, before UI)
    @Published private(set) var activeSession: NativeVoiceCallSession?

    /// Payload for the active call — used to re-present call screen from banner
    @Published private(set) var activePayload: VoiceCallPayload?

    /// The currently active video call session (started on CallKit answer, before UI)
    @Published private(set) var activeVideoSession: NativeVideoCallSession?

    /// Payload for the active video call
    @Published private(set) var activeVideoPayload: VideoCallPayload?

    /// Whether a voice call is currently active
    var hasActiveCall: Bool { activeSession != nil || activeVideoSession != nil }

    /// Whether the video call is currently in PiP (Picture-in-Picture) mode
    @Published var isInPiPMode = false

    private init() {
        CallLogger.log("ActiveCallManager initialized", category: .session)
        NSLog("✅ [ActiveCallManager] Initialized")
    }

    // MARK: - Start Session Immediately (called from VoIPPushManager on answer)

    /// Start a voice call session RIGHT NOW — called when user answers via CallKit.
    /// This runs in background before NativeVoiceCallScreen appears.
    /// Audio connects immediately (like WhatsApp).
    func startIncomingSession(
        roomId: String,
        receiverId: String,
        receiverPhone: String,
        callerName: String,
        callerPhoto: String
    ) {
        // Don't start duplicate sessions
        guard activeSession == nil else {
            NSLog("⚠️ [ActiveCallManager] Session already active, ignoring duplicate start")
            return
        }

        let payload = VoiceCallPayload(
            receiverId: receiverId,
            receiverName: callerName,
            receiverPhoto: callerPhoto,
            receiverToken: "",
            receiverDeviceType: "",
            receiverPhone: receiverPhone,
            roomId: roomId,
            isSender: false
        )

        let session = NativeVoiceCallSession(payload: payload)
        
        // Set session SYNCHRONOUSLY — no async dispatch.
        // This is already called from main queue (CXProvider delegate).
        // CRITICAL: Session must exist BEFORE action.fulfill() triggers didActivate,
        // otherwise activateAudioForCallKit() finds nil session on cold start.
        self.activeSession = session
        self.activePayload = payload
        CallLogger.success("Session created for room=\(roomId), caller=\(callerName) — starting WebRTC (isAudioReady=\(CallKitManager.shared.isAudioSessionReady))", category: .session)
        NSLog("✅ [ActiveCallManager] Session created — starting WebRTC immediately (isAudioReady=\(CallKitManager.shared.isAudioSessionReady))")
        session.start()
    }

    /// Set an outgoing session (created by NativeVoiceCallScreen for outgoing calls)
    func setOutgoingSession(_ session: NativeVoiceCallSession, payload: VoiceCallPayload? = nil) {
        DispatchQueue.main.async {
            self.activeSession = session
            if let payload = payload {
                self.activePayload = payload
            }
            NSLog("✅ [ActiveCallManager] Outgoing session registered")
        }
    }

    // MARK: - CallKit → Session Control

    /// Called from CallKit CXSetMutedCallAction
    func setMutedFromCallKit(_ muted: Bool) {
        guard let session = activeSession else { return }
        DispatchQueue.main.async {
            session.setMuted(muted, fromCallKit: true)
            NSLog("📞 [ActiveCallManager] CallKit → mute: \(muted)")
        }
    }

    /// Called from CallKit CXEndCallAction
    func endCallFromCallKit() {
        guard let session = activeSession else { return }
        DispatchQueue.main.async {
            session.endCall()
            NSLog("📞 [ActiveCallManager] CallKit → end call")
        }
    }

    // MARK: - Session → CallKit Sync

    /// Get the CallKit UUID for the active call
    func getCallKitUUID() -> UUID? {
        return activeSession?.callKitUUID
    }

    // MARK: - CallKit Audio Activation

    /// Called from CallKit didActivate to bridge the audio session to WebRTC.
    /// This ensures the RTCAudioSession is activated AFTER CallKit has activated AVAudioSession.
    func activateAudioForCallKit() {
        if let session = activeSession {
            DispatchQueue.main.async {
                session.activateWebRTCAudio()
                CallLogger.success("CallKit didActivate → WebRTC audio activated (voice)", category: .audio)
                NSLog("✅ [ActiveCallManager] CallKit didActivate → WebRTC audio activated (voice)")
            }
            return
        }
        if let videoSession = activeVideoSession {
            DispatchQueue.main.async {
                videoSession.activateWebRTCAudio()
                NSLog("✅ [ActiveCallManager] CallKit didActivate → WebRTC audio activated (video)")
            }
            return
        }
        CallLogger.log("activateAudioForCallKit: session nil — will check when created", category: .audio)
        NSLog("📞 [ActiveCallManager] activateAudioForCallKit: session nil — session will check isAudioSessionReady when created")
    }

    // MARK: - Video Session (immediate start, like voice)

    /// Start a video call session RIGHT NOW — called when user answers via CallKit.
    /// WebRTC + signaling start immediately. Renderers attach later when UI appears.
    func startIncomingVideoSession(
        roomId: String,
        receiverId: String,
        receiverPhone: String,
        callerName: String,
        callerPhoto: String
    ) {
        guard activeVideoSession == nil else {
            NSLog("⚠️ [ActiveCallManager] Video session already active, ignoring duplicate")
            return
        }

        let payload = VideoCallPayload(
            receiverId: receiverId,
            receiverName: callerName,
            receiverPhoto: callerPhoto,
            receiverToken: "",
            receiverDeviceType: "",
            receiverPhone: receiverPhone,
            roomId: roomId,
            isSender: false
        )

        let session = NativeVideoCallSession(payload: payload)
        self.activeVideoSession = session
        self.activeVideoPayload = payload
        NSLog("✅ [ActiveCallManager] Video session created — starting WebRTC immediately")
        session.start()
    }

    /// Called from NativeVideoCallScreen to set an outgoing video session
    func setOutgoingVideoSession(_ session: NativeVideoCallSession, payload: VideoCallPayload? = nil) {
        DispatchQueue.main.async {
            self.activeVideoSession = session
            if let payload = payload {
                self.activeVideoPayload = payload
            }
            NSLog("✅ [ActiveCallManager] Outgoing video session registered")
        }
    }

    // MARK: - Cleanup

    func clearSession() {
        DispatchQueue.main.async {
            self.activeSession = nil
            self.activePayload = nil
            NSLog("🔴 [ActiveCallManager] Session cleared")
        }
    }

    func clearVideoSession() {
        DispatchQueue.main.async {
            self.activeVideoSession = nil
            self.activeVideoPayload = nil
            self.isInPiPMode = false
            NSLog("🔴 [ActiveCallManager] Video session cleared")
        }
    }
}
