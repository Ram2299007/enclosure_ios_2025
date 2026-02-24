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
import ObjectiveC

// Persist last known video size on RTCEAGLVideoView so new coordinators can recover it
private var _lastVideoSizeKey: UInt8 = 0
extension RTCEAGLVideoView {
    var lastKnownVideoSize: CGSize {
        get { objc_getAssociatedObject(self, &_lastVideoSizeKey) as? CGSize ?? .zero }
        set { objc_setAssociatedObject(self, &_lastVideoSizeKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
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
                    .onTapGesture { toggleControls() }

                // ── Caller name overlay ──
                callerNameOverlay
                    .allowsHitTesting(false)
                    .opacity(showControls ? 1 : 0)
                    .animation(.easeInOut(duration: 0.4), value: showControls)

                // ── Top bar ──
                topBar
                    .allowsHitTesting(showControls)
                    .opacity(showControls ? 1 : 0)
                    .offset(y: showControls ? 0 : -80)
                    .animation(.easeInOut(duration: 0.4), value: showControls)

                // ── Controls bar ──
                controlsBar
                    .allowsHitTesting(showControls)
                    .opacity(showControls ? 1 : 0)
                    .offset(y: showControls ? 0 : 120)
                    .animation(.easeInOut(duration: 0.4), value: showControls)

                // ── Secondary video (local PiP when connected) ──
                secondaryVideo(geometry: geometry)
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
            Spacer().frame(height: 120)
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
                // Back button → PiP mode (call keeps running)
                Button {
                    ActiveCallManager.shared.isInPiPMode = true
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

                // Add member button (same line as back arrow)
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
            .padding(.top, 60)
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

// MARK: - RTCEAGLVideoView SwiftUI Wrapper (Aspect-Fill / Center-Crop)

struct EAGLVideoViewWrapper: UIViewRepresentable {
    let view: RTCEAGLVideoView

    func makeCoordinator() -> Coordinator {
        let coord = Coordinator(videoView: view)
        // Recover persisted video size so aspect-fill works immediately on reuse
        coord.videoSize = view.lastKnownVideoSize
        return coord
    }

    func makeUIView(context: Context) -> AspectFillContainer {
        let container = AspectFillContainer()
        container.coordinator = context.coordinator
        container.backgroundColor = .black
        container.clipsToBounds = true

        view.translatesAutoresizingMaskIntoConstraints = false
        view.delegate = context.coordinator
        container.addSubview(view)

        // Center the video view inside the container
        let centerX = view.centerXAnchor.constraint(equalTo: container.centerXAnchor)
        let centerY = view.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        // Initial size = container size (will be updated by delegate for aspect-fill)
        let width = view.widthAnchor.constraint(equalTo: container.widthAnchor)
        let height = view.heightAnchor.constraint(equalTo: container.heightAnchor)

        // Lower priority so aspect-fill constraints can override
        width.priority = .defaultLow
        height.priority = .defaultLow

        NSLayoutConstraint.activate([centerX, centerY, width, height])

        context.coordinator.container = container
        context.coordinator.widthConstraint = width
        context.coordinator.heightConstraint = height

        return container
    }

    func updateUIView(_ uiView: AspectFillContainer, context: Context) {
        // Ensure delegate is always the current coordinator
        view.delegate = context.coordinator
        // Re-parent video view if it was moved (e.g. returned from PiP)
        if view.superview !== uiView {
            // Remove all existing constraints referencing the video view
            for constraint in view.constraints {
                view.removeConstraint(constraint)
            }
            view.removeFromSuperview()
            view.translatesAutoresizingMaskIntoConstraints = false
            uiView.addSubview(view)
            NSLayoutConstraint.activate([
                view.centerXAnchor.constraint(equalTo: uiView.centerXAnchor),
                view.centerYAnchor.constraint(equalTo: uiView.centerYAnchor)
            ])
            context.coordinator.container = uiView
            // Reset constraints so aspect-fill recalculates
            let w = view.widthAnchor.constraint(equalTo: uiView.widthAnchor)
            let h = view.heightAnchor.constraint(equalTo: uiView.heightAnchor)
            w.priority = .defaultLow
            h.priority = .defaultLow
            w.isActive = true
            h.isActive = true
            context.coordinator.widthConstraint = w
            context.coordinator.heightConstraint = h
        }
        // Trigger aspect-fill update on next layout pass
        uiView.setNeedsLayout()
    }

    // Custom container that re-triggers aspect-fill when its layout changes
    class AspectFillContainer: UIView {
        weak var coordinator: Coordinator?
        override func layoutSubviews() {
            super.layoutSubviews()
            coordinator?.retryAspectFill()
        }
    }

    // Coordinator tracks video frame size and applies aspect-fill constraints
    class Coordinator: NSObject, RTCEAGLVideoViewDelegate {
        weak var container: UIView?
        var widthConstraint: NSLayoutConstraint?
        var heightConstraint: NSLayoutConstraint?
        private let videoView: RTCEAGLVideoView
        var videoSize: CGSize = .zero

        init(videoView: RTCEAGLVideoView) {
            self.videoView = videoView
        }

        /// Called by AspectFillContainer.layoutSubviews when container bounds change
        func retryAspectFill() {
            updateAspectFill()
        }

        func videoView(_ videoView: RTCEAGLVideoView, didChangeVideoSize size: CGSize) {
            guard size.width > 0, size.height > 0 else { return }
            videoSize = size
            videoView.lastKnownVideoSize = size
            DispatchQueue.main.async { [weak self] in
                self?.updateAspectFill()
            }
        }

        private func updateAspectFill() {
            guard let container = container, videoSize.width > 0, videoSize.height > 0 else { return }
            // Safety: skip if video view was moved to a different hierarchy (e.g. PiP)
            guard videoView.superview === container else { return }
            let containerSize = container.bounds.size
            guard containerSize.width > 0, containerSize.height > 0 else { return }

            let videoAspect = videoSize.width / videoSize.height
            let containerAspect = containerSize.width / containerSize.height

            // Aspect-fill: scale video to FILL container (overflow is clipped)
            if videoAspect > containerAspect {
                // Video is wider → match height, overflow width
                widthConstraint?.isActive = false
                heightConstraint?.isActive = false
                widthConstraint = videoView.widthAnchor.constraint(
                    equalTo: container.heightAnchor, multiplier: videoAspect)
                heightConstraint = videoView.heightAnchor.constraint(
                    equalTo: container.heightAnchor)
            } else {
                // Video is taller → match width, overflow height
                widthConstraint?.isActive = false
                heightConstraint?.isActive = false
                widthConstraint = videoView.widthAnchor.constraint(
                    equalTo: container.widthAnchor)
                heightConstraint = videoView.heightAnchor.constraint(
                    equalTo: container.widthAnchor, multiplier: 1.0 / videoAspect)
            }
            widthConstraint?.priority = .required
            heightConstraint?.priority = .required
            widthConstraint?.isActive = true
            heightConstraint?.isActive = true
            container.layoutIfNeeded()
        }
    }
}
