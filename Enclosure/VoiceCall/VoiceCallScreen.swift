import SwiftUI

struct VoiceCallScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session: VoiceCallSession

    init(payload: VoiceCallPayload) {
        _session = StateObject(wrappedValue: VoiceCallSession(payload: payload))
        NSLog("🔥 [VoiceCallScreen] VoiceCallScreen init - session created")
    }

    var body: some View {
        VoiceCallWebView(session: session)
            .ignoresSafeArea()
            .onAppear {
                NSLog("📺 [VoiceCallScreen] View appeared - starting session")
                session.start()
                NSLog("✅ [VoiceCallScreen] Session started! WebRTC connecting...")
            }
            .onDisappear {
                NSLog("📺 [VoiceCallScreen] View disappeared - stopping session")
                session.stop()
            }
            .onReceive(session.$shouldDismiss) { shouldDismiss in
                if shouldDismiss {
                    dismiss()
                }
            }
            .onReceive(session.$isCallConnected) { connected in
                if connected {
                    NSLog("✅✅✅ [VoiceCallScreen] ========================================")
                    NSLog("✅ [VoiceCallScreen] CALL CONNECTED!")
                    NSLog("✅ [VoiceCallScreen] WebRTC peer connection established")
                    NSLog("✅ [VoiceCallScreen] User can now hear audio")
                    NSLog("✅✅✅ [VoiceCallScreen] ========================================")
                    print("✅ [VoiceCallScreen] CALL STATUS: CONNECTED")
                }
            }
    }
}
