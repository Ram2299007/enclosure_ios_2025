import Foundation
import Combine

/// Singleton that reliably stores pending call data when user answers via CallKit.
/// Solves the race condition where NotificationCenter's `AnswerIncomingCall` fires
/// before MainActivityOld's SwiftUI `.onReceive` is active (background / lock screen).
/// MainActivityOld observes `@Published` properties + checks on `scenePhase` → `.active`.
final class PendingCallManager: ObservableObject {
    static let shared = PendingCallManager()

    @Published var pendingVoiceCall: VoiceCallPayload?
    @Published var pendingVideoCall: VideoCallPayload?

    private init() {}

    /// Called from VoIPPushManager / NotificationDelegate / AppDelegate when user answers.
    func setPendingVoiceCall(
        roomId: String,
        receiverId: String,
        receiverPhone: String,
        callerName: String,
        callerPhoto: String
    ) {
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
        NSLog("📞 [PendingCallManager] Stored pending VOICE call: room=\(roomId), caller=\(callerName)")
        DispatchQueue.main.async {
            self.pendingVoiceCall = payload
        }
    }

    func setPendingVideoCall(
        roomId: String,
        receiverId: String,
        receiverPhone: String,
        callerName: String,
        callerPhoto: String
    ) {
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
        NSLog("📞 [PendingCallManager] Stored pending VIDEO call: room=\(roomId), caller=\(callerName)")
        DispatchQueue.main.async {
            self.pendingVideoCall = payload
        }
    }

    /// Consume the pending voice call (returns it and clears).
    func consumePendingVoiceCall() -> VoiceCallPayload? {
        guard let payload = pendingVoiceCall else { return nil }
        NSLog("📞 [PendingCallManager] Consumed pending voice call: room=\(payload.roomId ?? "")")
        pendingVoiceCall = nil
        return payload
    }

    /// Consume the pending video call (returns it and clears).
    func consumePendingVideoCall() -> VideoCallPayload? {
        guard let payload = pendingVideoCall else { return nil }
        NSLog("📞 [PendingCallManager] Consumed pending video call: room=\(payload.roomId ?? "")")
        pendingVideoCall = nil
        return payload
    }

    func clearAll() {
        pendingVoiceCall = nil
        pendingVideoCall = nil
    }
}
