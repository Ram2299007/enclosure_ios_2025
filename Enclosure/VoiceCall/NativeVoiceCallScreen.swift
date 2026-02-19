import SwiftUI

// MARK: - NativeVoiceCallScreen
/// Full native SwiftUI voice call UI — same design as indexVoice.html
/// No WKWebView, no JavaScript. Uses NativeVoiceCallSession for WebRTC.
struct NativeVoiceCallScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session: NativeVoiceCallSession
    @State private var showAudioMenu = false

    init(payload: VoiceCallPayload) {
        _session = StateObject(wrappedValue: NativeVoiceCallSession(payload: payload))
        NSLog("🔥 [NativeVoiceCallScreen] init — session created")
    }

    var body: some View {
        ZStack {
            // Background
            backgroundView

            VStack(spacing: 0) {
                // Top bar (back + add member)
                topBar

                Spacer()

                // Caller info (photo, name, timer, status)
                callerInfoView

                Spacer()

                // Bottom controls (mute, end, audio output)
                controlsView
                    .padding(.bottom, 48)
            }

            // Audio output menu overlay
            if showAudioMenu {
                audioOutputMenu
            }
        }
        .ignoresSafeArea()
        .onAppear {
            NSLog("📺 [NativeVoiceCallScreen] appeared — starting session")
            session.start()
        }
        .onDisappear {
            NSLog("📺 [NativeVoiceCallScreen] disappeared — stopping session")
            session.stop()
        }
        .onReceive(session.$shouldDismiss) { should in
            if should { dismiss() }
        }
        .onReceive(session.$isCallConnected) { connected in
            if connected {
                NSLog("✅ [NativeVoiceCallScreen] CALL CONNECTED!")
            }
        }
    }

    // MARK: - Background

    private var backgroundView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let uiImage = UIImage(named: "callnewmodernbg") {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .opacity(0.85)
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button(action: { session.endCall() }) {
                Image(uiImage: UIImage(named: "back_arrow") ?? UIImage(systemName: "chevron.left")!)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.white)
                    .padding(12)
            }
            Spacer()
            Button(action: { /* Add member */ }) {
                Image(uiImage: UIImage(named: "add_member") ?? UIImage(systemName: "person.badge.plus")!)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.white)
                    .padding(12)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 56)
    }

    // MARK: - Caller Info

    private var callerInfoView: some View {
        VStack(spacing: 12) {
            // Caller photo
            AsyncImage(url: URL(string: session.callerPhoto)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(uiImage: UIImage(named: "user") ?? UIImage(systemName: "person.circle.fill")!)
                    .resizable()
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 2))

            // Caller name
            Text(session.callerName.isEmpty ? "Unknown" : session.callerName)
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            // Call timer / status
            if session.isCallConnected {
                Text(formattedDuration(session.callDuration))
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .monospacedDigit()
            } else {
                Text("Connecting...")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Controls

    private var controlsView: some View {
        HStack(spacing: 32) {
            // Mute mic
            controlButton(
                imageName: session.isMuted ? "mic_muted" : "mic",
                systemFallback: session.isMuted ? "mic.slash.fill" : "mic.fill",
                isActive: session.isMuted,
                activeColor: .red.opacity(0.8)
            ) {
                session.setMuted(!session.isMuted)
            }

            // End call
            Button(action: { session.endCall() }) {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 68, height: 68)
                    Image(uiImage: UIImage(named: "end_call") ?? UIImage(systemName: "phone.down.fill")!)
                        .resizable()
                        .frame(width: 28, height: 28)
                        .foregroundColor(.white)
                }
            }

            // Audio output (earpiece / speaker / bluetooth)
            ZStack(alignment: .top) {
                controlButton(
                    imageName: audioOutputImageName,
                    systemFallback: session.isSpeakerOn ? "speaker.wave.3.fill" : "speaker.fill",
                    isActive: session.isSpeakerOn,
                    activeColor: .blue.opacity(0.8)
                ) {
                    showAudioMenu.toggle()
                }
            }
        }
    }

    private var audioOutputImageName: String {
        if session.isBluetoothAvailable { return "bluetooth" }
        return session.isSpeakerOn ? "speaker" : "earpiece"
    }

    private func controlButton(
        imageName: String,
        systemFallback: String,
        isActive: Bool,
        activeColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isActive ? activeColor : Color.white.opacity(0.2))
                    .frame(width: 60, height: 60)
                if let img = UIImage(named: imageName) {
                    Image(uiImage: img)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: systemFallback)
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
            }
        }
    }

    // MARK: - Audio Output Menu

    private var audioOutputMenu: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 0) {
                    audioMenuOption(label: "Earpiece", icon: "earpiece", systemIcon: "ear") {
                        session.setAudioOutput(speaker: false)
                        showAudioMenu = false
                    }
                    Divider().background(Color.white.opacity(0.3))
                    audioMenuOption(label: "Speaker", icon: "speaker", systemIcon: "speaker.wave.3") {
                        session.setAudioOutput(speaker: true)
                        showAudioMenu = false
                    }
                    if session.isBluetoothAvailable {
                        Divider().background(Color.white.opacity(0.3))
                        audioMenuOption(label: "Bluetooth", icon: "bluetooth", systemIcon: "headphones") {
                            // Bluetooth auto-routes when headset connected
                            showAudioMenu = false
                        }
                    }
                }
                .background(Color.black.opacity(0.85))
                .cornerRadius(12)
                .frame(width: 160)
                .padding(.trailing, 24)
            }
            .padding(.bottom, 130)
        }
        .onTapGesture { showAudioMenu = false }
    }

    private func audioMenuOption(label: String, icon: String, systemIcon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let img = UIImage(named: icon) {
                    Image(uiImage: img).resizable().frame(width: 20, height: 20)
                } else {
                    Image(systemName: systemIcon).font(.system(size: 18))
                }
                Text(label).font(.system(size: 15))
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Helpers

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let total = Int(duration)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}
