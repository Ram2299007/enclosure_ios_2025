import SwiftUI

// MARK: - NativeVoiceCallScreen
/// Full native SwiftUI voice call UI — pixel-matched to indexVoice.html + stylesVoice.css
/// No WKWebView, no JavaScript. Uses NativeVoiceCallSession for WebRTC.
struct NativeVoiceCallScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session: NativeVoiceCallSession
    @State private var showAudioMenu = false

    init(payload: VoiceCallPayload) {
        // For incoming calls: reuse the already-running session from ActiveCallManager
        // (started immediately on CallKit answer, before UI appeared — audio already connected)
        // For outgoing calls: create a new session
        if !payload.isSender, let existingSession = ActiveCallManager.shared.activeSession {
            _session = StateObject(wrappedValue: existingSession)
            NSLog("🔥 [NativeVoiceCallScreen] init — reusing ActiveCallManager session (background start)")
        } else {
            let newSession = NativeVoiceCallSession(payload: payload)
            _session = StateObject(wrappedValue: newSession)
            // Register outgoing session with ActiveCallManager for CallKit sync
            if payload.isSender {
                ActiveCallManager.shared.setOutgoingSession(newSession)
            }
            NSLog("🔥 [NativeVoiceCallScreen] init — new session created (isSender=\(payload.isSender))")
        }
    }

    var body: some View {
        ZStack {
            // Background — matches .voice-container + .background-image
            backgroundView

            // Caller info — matches .participants-container + .caller-info
            // Positioned in upper-center area (top: 40px + margin-top: 40px in CSS)
            VStack(spacing: 0) {
                Spacer().frame(height: 80 + safeAreaTop) // ~top: 40px + safe area + caller-info margin-top: 40px
                callerInfoView
                Spacer()
            }

            // Top bar — matches .top-bar (absolute, top: calc(20px + safe-area))
            VStack {
                topBar
                Spacer()
            }

            // Bottom controls container — matches .controls-container
            VStack {
                Spacer()
                controlsContainer
            }

            // Audio output menu overlay
            if showAudioMenu {
                audioOutputMenu
            }
        }
        .ignoresSafeArea()
        .onAppear {
            // session.start() is idempotent (checks hasStarted flag).
            // For incoming calls from background: session already started via ActiveCallManager.
            // For outgoing calls: this is where it starts.
            NSLog("📺 [NativeVoiceCallScreen] appeared — ensuring session started")
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

    private var safeAreaTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 47
    }

    private var safeAreaBottom: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 34
    }

    // MARK: - Background
    // Matches: body { background: url('callnewmodernbg.png'); background-color: #000; }

    private var backgroundView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let uiImage = UIImage(named: "callnewmodernbg") {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: - Top Bar
    // Matches: .top-bar { top: calc(20px + env(safe-area-inset-top)); left: 10px; right: 10px; }
    // Matches: .top-btn { width: 44px; height: 44px; background-color: rgba(255,255,255,0.1); border-radius: 50%; }

    private var topBar: some View {
        HStack {
            Button(action: { session.endCall() }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 44, height: 44)
                    if let img = UIImage(named: "back_arrow") {
                        Image(uiImage: img)
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 24, height: 24)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
            Spacer()
            Button(action: { /* Add member */ }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 44, height: 44)
                    if let img = UIImage(named: "add_member") {
                        Image(uiImage: img)
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 24, height: 24)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding(.horizontal, 22) // left: 10px + padding: 0 12px
        .padding(.top, 20 + safeAreaTop) // top: calc(20px + env(safe-area-inset-top))
    }

    // MARK: - Caller Info
    // Matches: .caller-info { margin-top: 40px; }
    // .caller-image { width: 100px; height: 100px; } — visibility: hidden in HTML
    // .caller-name { margin-top: 17px; font-size: 14px; font-weight: 700; color: #ffffff; }
    // .call-timer  { margin-top: 10px; font-size: 14px; font-weight: 500; color: #808080; }
    // .call-status { margin-top: 17px; font-size: 12px; font-weight: 700; color: #9EA6B9; }

    private var callerInfoView: some View {
        VStack(spacing: 0) {
            // Caller photo — WhatsApp-style: show profile pic or first letter avatar
            AsyncImage(url: URL(string: session.callerPhoto)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    // WhatsApp-like first letter avatar
                    firstLetterAvatar(name: session.callerName)
                }
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())

            // Caller name — .caller-name { margin-top: 17px; font-size: 14px; font-weight: 700; }
            Text(session.callerName.isEmpty ? "Unknown" : session.callerName)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.top, 17)

            // Call timer — .call-timer { margin-top: 10px; font-size: 14px; font-weight: 500; color: #808080; }
            if session.isCallConnected {
                Text(formattedDuration(session.callDuration))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "#808080"))
                    .monospacedDigit()
                    .padding(.top, 10)
            }

            // Call status — .call-status { margin-top: 17px; font-size: 12px; font-weight: 700; color: #9EA6B9; }
            Text(session.isCallConnected ? "Connected" : "Connecting...")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#9EA6B9"))
                .padding(.top, 17)
        }
    }

    // MARK: - Controls Container
    // Matches: .controls-container { position: absolute; bottom: 0; height: 80px;
    //   padding-bottom: env(safe-area-inset-bottom); background-color: rgba(0,0,0,0.5);
    //   border-top-left-radius: 50px; border-top-right-radius: 50px; }
    // .controls { position: absolute; top: -28px; gap: 50px; }
    // .control-btn { width: 64px; height: 64px; background-color: rgba(255,255,255,0.1); }
    // .control-btn.end-call { background-color: rgba(211,47,47,0.7); }
    // .control-btn img { width: 28px; height: 28px; }

    private var controlsContainer: some View {
        ZStack(alignment: .top) {
            // Bottom container background — .controls-container
            VoiceCallRoundedCorner(radius: 50, corners: [.topLeft, .topRight])
                .fill(Color.black.opacity(0.5))
                .frame(height: 80 + safeAreaBottom)

            // Floating controls — .controls { top: -28px; }
            HStack(spacing: 50) {
                // Mute mic
                controlButton(
                    imageName: session.isMuted ? "mic_muted" : "mic",
                    systemFallback: session.isMuted ? "mic.slash.fill" : "mic.fill",
                    isActive: session.isMuted
                ) {
                    session.setMuted(!session.isMuted)
                }

                // End call — .control-btn.end-call { background-color: rgba(211,47,47,0.7); }
                Button(action: { session.endCall() }) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 211/255, green: 47/255, blue: 47/255).opacity(0.7))
                            .frame(width: 64, height: 64)
                        if let img = UIImage(named: "end_call") {
                            Image(uiImage: img)
                                .resizable()
                                .renderingMode(.template)
                                .frame(width: 28, height: 28)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                        }
                    }
                }

                // Audio output
                controlButton(
                    imageName: audioOutputImageName,
                    systemFallback: session.isSpeakerOn ? "speaker.wave.3.fill" : "speaker.fill",
                    isActive: session.isSpeakerOn
                ) {
                    showAudioMenu.toggle()
                }
            }
            .offset(y: -28) // .controls { top: -28px; }
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
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isActive ? Color(hex: "FF0000").opacity(0.7) : Color.white.opacity(0.1))
                    .frame(width: 64, height: 64)
                if let img = UIImage(named: imageName) {
                    Image(uiImage: img)
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 28, height: 28)
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
    // Matches: .audio-output-menu { bottom: 70px; background-color: #011224; border-radius: 12px; min-width: 120px; }
    // .audio-option { padding: 12px 24px; color: #ffffff; font-size: 16px; font-weight: 500; }

    private var audioOutputMenu: some View {
        ZStack {
            // Dismiss tap area
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { showAudioMenu = false }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 0) {
                        audioMenuOption(label: "Normal", icon: "earpiece", systemIcon: "ear") {
                            session.setAudioOutput(speaker: false)
                            showAudioMenu = false
                        }
                        audioMenuOption(label: "Speaker", icon: "speaker", systemIcon: "speaker.wave.3") {
                            session.setAudioOutput(speaker: true)
                            showAudioMenu = false
                        }
                        if session.isBluetoothAvailable {
                            audioMenuOption(label: "Bluetooth", icon: "bluetooth", systemIcon: "headphones") {
                                showAudioMenu = false
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .background(Color(hex: "#011224"))
                    .cornerRadius(12)
                    .frame(minWidth: 120)
                    .fixedSize()
                    Spacer().frame(width: 20)
                }
                .padding(.bottom, 80 + safeAreaBottom + 38) // above controls container + button offset
            }
        }
    }

    private func audioMenuOption(label: String, icon: String, systemIcon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let img = UIImage(named: icon) {
                    Image(uiImage: img)
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: systemIcon).font(.system(size: 18))
                }
                Text(label)
                    .font(.system(size: 16, weight: .medium))
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Helpers

    // WhatsApp-like first letter avatar — colored circle with caller's initial
    private func firstLetterAvatar(name: String) -> some View {
        let letter = String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
        let displayLetter = letter.isEmpty ? "?" : letter
        // Deterministic color based on name (same name → same color, like WhatsApp)
        let colors: [Color] = [
            Color(red: 0.13, green: 0.59, blue: 0.95), // blue
            Color(red: 0.30, green: 0.69, blue: 0.31), // green
            Color(red: 0.61, green: 0.15, blue: 0.69), // purple
            Color(red: 0.96, green: 0.49, blue: 0.0),  // orange
            Color(red: 0.0, green: 0.59, blue: 0.53),  // teal
            Color(red: 0.91, green: 0.26, blue: 0.21), // red
            Color(red: 0.48, green: 0.32, blue: 0.66), // deep purple
            Color(red: 0.0, green: 0.47, blue: 0.42),  // dark teal
        ]
        let hash = abs(name.hashValue)
        let color = colors[hash % colors.count]
        
        return ZStack {
            Circle().fill(color)
            Text(displayLetter)
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
    }

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

// MARK: - VoiceCallRoundedCorner Shape (top-left + top-right radius only)
// Matches: .controls-container { border-top-left-radius: 50px; border-top-right-radius: 50px; }
private struct VoiceCallRoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
