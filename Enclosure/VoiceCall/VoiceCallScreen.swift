import SwiftUI

struct VoiceCallScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session: VoiceCallSession
    @State private var hasStarted = false

    init(payload: VoiceCallPayload) {
        let newSession = VoiceCallSession(payload: payload)
        _session = StateObject(wrappedValue: newSession)
        
        // CRITICAL: Start session immediately, even if view hasn't appeared yet
        // This allows WebRTC to connect in background while device is locked (WhatsApp behavior)
        // CallKit audio session + audio background mode make this possible
        print("🔥 [VoiceCallScreen] Starting session IMMEDIATELY for background connection")
        NSLog("🔥 [VoiceCallScreen] Session starting in init - will connect even while locked")
        
        // Start on next run loop to ensure session is fully initialized
        DispatchQueue.main.async {
            newSession.start()
            NSLog("✅ [VoiceCallScreen] Session started! WebRTC connecting in background...")
        }
    }

    var body: some View {
        VoiceCallWebView(session: session)
            .ignoresSafeArea()
            .onAppear {
                NSLog("📺 [VoiceCallScreen] View appeared - UI now visible")
                print("📺 [VoiceCallScreen] onAppear called - device unlocked, UI showing")
                
                // Session already started in init, but ensure it's running
                if !hasStarted {
                    NSLog("⚠️ [VoiceCallScreen] Backup start call (should not happen)")
                    session.start()
                    hasStarted = true
                }
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
    }
}
