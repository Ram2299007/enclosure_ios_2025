import SwiftUI

struct VoiceCallScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session: VoiceCallSession

    init(payload: VoiceCallPayload) {
        _session = StateObject(wrappedValue: VoiceCallSession(payload: payload))
    }

    var body: some View {
        VoiceCallWebView(session: session)
            .ignoresSafeArea()
            .onAppear {
                session.start()
            }
            .onDisappear {
                session.stop()
            }
            .onReceive(session.$shouldDismiss) { shouldDismiss in
                if shouldDismiss {
                    dismiss()
                }
            }
    }
}
