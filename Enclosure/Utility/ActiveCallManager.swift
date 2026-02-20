import Foundation
import Combine

/// Singleton bridge between CallKit ↔ NativeVoiceCallSession.
/// - Starts WebRTC session IMMEDIATELY when user answers (before UI appears)
/// - CallKit mute/end actions route through here to the live session
/// - NativeVoiceCallScreen connects to the already-running session
/// - Like WhatsApp: CallKit stays active, controls are synced, audio works in background
final class ActiveCallManager: ObservableObject {
    static let shared = ActiveCallManager()

    /// The currently active voice call session (started on CallKit answer, before UI)
    @Published private(set) var activeSession: NativeVoiceCallSession?

    /// Whether a voice call is currently active
    var hasActiveCall: Bool { activeSession != nil }

    private init() {
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
        
        DispatchQueue.main.async {
            self.activeSession = session
            NSLog("✅ [ActiveCallManager] Session created — starting WebRTC immediately")
            session.start()
        }
    }

    /// Set an outgoing session (created by NativeVoiceCallScreen for outgoing calls)
    func setOutgoingSession(_ session: NativeVoiceCallSession) {
        DispatchQueue.main.async {
            self.activeSession = session
            NSLog("✅ [ActiveCallManager] Outgoing session registered")
        }
    }

    // MARK: - CallKit → Session Control

    /// Called from CallKit CXSetMutedCallAction
    func setMutedFromCallKit(_ muted: Bool) {
        guard let session = activeSession else { return }
        DispatchQueue.main.async {
            session.setMuted(muted)
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

    // MARK: - Cleanup

    func clearSession() {
        DispatchQueue.main.async {
            self.activeSession = nil
            NSLog("🔴 [ActiveCallManager] Session cleared")
        }
    }
}
