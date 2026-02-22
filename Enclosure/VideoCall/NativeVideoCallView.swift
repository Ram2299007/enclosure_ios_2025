//
//  NativeVideoCallView.swift
//  Enclosure
//
//  Native iOS video call UI matching Android design (styles.css + index.html).
//  WhatsApp-style: sender sees local full-screen initially, then local moves
//  to draggable secondary PiP when remote connects.
//

import SwiftUI
import AVFoundation
import WebRTC

// MARK: - Helper: Color from hex string
private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 0; g = 0.64; b = 0.91 // fallback #00A3E9
        }
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - NativeVideoCallView

struct NativeVideoCallView: View {
    @ObservedObject var session: NativeVideoCallSession
    @Environment(\.dismiss) private var dismiss

    @State private var showControls = true
    @State private var controlsTimer: Timer?
    @State private var secondaryVideoOffset = CGSize.zero
    @State private var secondaryVideoSize = CGSize(width: 120, height: 160)

    /// Theme color derived from Constant.themeColor (a hex String)
    private var themeColor: Color { Color(hex: Constant.themeColor) }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // ── Background ──
                Color.black.ignoresSafeArea()

                // ── Full-screen video (remote when connected, local otherwise) ──
                fullScreenVideo

                // ── Caller name overlay (visible before + after connect) ──
                callerNameOverlay
                    .opacity(showControls ? 1 : 0)
                    .animation(.easeInOut(duration: 0.4), value: showControls)

                // ── Top bar ──
                topBar
                    .opacity(showControls ? 1 : 0)
                    .offset(y: showControls ? 0 : -80)
                    .animation(.easeInOut(duration: 0.4), value: showControls)

                // ── Controls bar ──
                controlsBar
                    .opacity(showControls ? 1 : 0)
                    .offset(y: showControls ? 0 : 120)
                    .animation(.easeInOut(duration: 0.4), value: showControls)

                // ── Secondary video (local PiP when connected) ──
                secondaryVideo(geometry: geometry)

                // ── Tap catcher for show/hide controls ──
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { toggleControls() }
            }
        }
        .statusBar(hidden: true)
        .ignoresSafeArea()
        .onAppear { resetControlsTimer() }
        .onDisappear { controlsTimer?.invalidate() }
        .onReceive(session.$isCallConnected) { connected in
            if connected {
                withAnimation(.easeInOut(duration: 0.3)) {
                    secondaryVideoOffset = .zero
                }
            }
        }
    }

    // MARK: - Sub-views

    private var fullScreenVideo: some View {
        Group {
            if session.isCallConnected, let remote = session.remoteRenderer {
                EAGLVideoViewWrapper(view: remote)
                    .ignoresSafeArea()
            } else if let local = session.localRenderer {
                EAGLVideoViewWrapper(view: local)
                    .ignoresSafeArea()
                    .scaleEffect(x: -1, y: 1) // mirror front camera
            } else {
                Color.black.ignoresSafeArea()
            }
        }
    }

    private var callerNameOverlay: some View {
        VStack {
            Spacer().frame(height: 80)
            Text(session.callerName)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 4, x: 2, y: 2)
            if session.isCallConnected {
                Text(formattedDuration)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }
            Spacer()
        }
    }

    private var topBar: some View {
        VStack {
            HStack {
                // Back button
                Button {
                    session.endCall()
                } label: {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "chevron.left")
                                .foregroundColor(.white)
                                .font(.system(size: 20, weight: .medium))
                        )
                }

                Spacer()

                // Placeholder add-member
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .medium))
                    )
            }
            .padding(.horizontal, 12)
            .padding(.top, 20)
            Spacer()
        }
    }

    private var controlsBar: some View {
        VStack {
            Spacer()

            // Semi-transparent container (matches Android .controls-container)
            ZStack {
                RoundedRectangle(cornerRadius: 50, style: .continuous)
                    .fill(Color.black.opacity(0.5))
                    .frame(height: 80)

                HStack(spacing: 35) {
                    // Mute
                    controlButton(
                        icon: session.isMicrophoneMuted ? "mic.slash.fill" : "mic.fill",
                        isActive: session.isMicrophoneMuted
                    ) { session.toggleMicrophone() }

                    // Camera toggle
                    controlButton(
                        icon: session.isCameraOff ? "video.slash.fill" : "video.fill",
                        isActive: session.isCameraOff
                    ) { session.toggleCamera() }

                    // Switch camera
                    controlButton(icon: "camera.rotate", isActive: false) {
                        session.switchCamera()
                    }

                    // End call
                    Button { session.endCall() } label: {
                        Circle()
                            .fill(Color(red: 0.83, green: 0.18, blue: 0.18).opacity(0.85))
                            .frame(width: 64, height: 64)
                            .overlay(
                                Image(systemName: "phone.down.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 24))
                            )
                    }
                }
                .offset(y: -28) // matches Android .controls top: -28px
            }
        }
    }

    @ViewBuilder
    private func secondaryVideo(geometry: GeometryProxy) -> some View {
        if session.isCallConnected, let local = session.localRenderer, !session.isCameraOff {
            let defaultX = geometry.size.width - secondaryVideoSize.width / 2 - 20
            let defaultY = geometry.size.height - secondaryVideoSize.height / 2 - 140

            EAGLVideoViewWrapper(view: local)
                .frame(width: secondaryVideoSize.width, height: secondaryVideoSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .scaleEffect(x: -1, y: 1) // mirror
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                .position(
                    x: defaultX + secondaryVideoOffset.width,
                    y: defaultY + secondaryVideoOffset.height
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            secondaryVideoOffset = value.translation
                        }
                        .onEnded { value in
                            withAnimation(.spring()) {
                                snapToEdge(translation: value.translation, geometry: geometry, defaultX: defaultX, defaultY: defaultY)
                            }
                        }
                )
                .zIndex(22)
        }
    }

    // MARK: - Helpers

    private func controlButton(icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(isActive ? themeColor.opacity(0.7) : Color.white.opacity(0.1))
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: icon)
                        .foregroundColor(.white)
                        .font(.system(size: 24, weight: .medium))
                )
        }
    }

    private var formattedDuration: String {
        let m = Int(session.callDuration) / 60
        let s = Int(session.callDuration) % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.4)) { showControls.toggle() }
        resetControlsTimer()
    }

    private func resetControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.4)) { showControls = false }
        }
    }

    private func snapToEdge(translation: CGSize, geometry: GeometryProxy, defaultX: CGFloat, defaultY: CGFloat) {
        let currentX = defaultX + translation.width
        let currentY = defaultY + translation.height
        let hw = secondaryVideoSize.width / 2
        let hh = secondaryVideoSize.height / 2
        let margin: CGFloat = 20

        // Snap X to nearest horizontal edge
        var snapX: CGFloat
        if currentX < geometry.size.width / 2 {
            snapX = hw + margin
        } else {
            snapX = geometry.size.width - hw - margin
        }

        // Clamp Y
        var snapY = currentY
        if snapY < hh + 80 { snapY = hh + 80 }
        if snapY > geometry.size.height - hh - 120 { snapY = geometry.size.height - hh - 120 }

        secondaryVideoOffset = CGSize(
            width: snapX - defaultX,
            height: snapY - defaultY
        )
    }
}

// MARK: - RTCEAGLVideoView SwiftUI Wrapper

struct EAGLVideoViewWrapper: UIViewRepresentable {
    let view: RTCEAGLVideoView

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .black
        container.clipsToBounds = true

        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFill
        container.addSubview(view)

        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
