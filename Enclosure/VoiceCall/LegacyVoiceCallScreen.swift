import SwiftUI

/// WKWebView + PeerJS based voice call screen.
/// Used for outgoing calls to Android devices.
struct LegacyVoiceCallScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session: VoiceCallSession

    init(payload: VoiceCallPayload) {
        _session = StateObject(wrappedValue: VoiceCallSession(payload: payload))
    }

    var body: some View {
        VoiceCallWebView(session: session)
            .ignoresSafeArea()
            .onAppear {
                NSLog("📺 [LegacyVoiceCallScreen] appeared — starting session")
                session.start()
            }
            .onDisappear {
                NSLog("📺 [LegacyVoiceCallScreen] disappeared — stopping session")
                session.stop()
            }
            .onReceive(session.$shouldDismiss) { should in
                if should { dismiss() }
            }
    }
}
