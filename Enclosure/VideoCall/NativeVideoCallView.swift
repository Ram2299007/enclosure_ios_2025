//
//  NativeVideoCallView.swift
//  Enclosure
//
//  Native iOS video call UI matching Android design (styles.css + index.html).
//  WhatsApp-style: sender sees local full-screen initially, then local moves
//  to draggable secondary PiP when remote connects.
//

#if !targetEnvironment(simulator)
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
    @State private var showAddMemberSheet = false
    @State private var secondaryVideoAppeared = false
    @State private var isDragging = false
    /// Absolute snapped position of secondary video center. nil = use default.
    @State private var secondaryPosition: CGPoint? = nil
    /// Live drag offset from current position (reset to .zero on drag end)
    @State private var dragOffset: CGSize = .zero

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
                    secondaryPosition = nil  // reset to default position
                    dragOffset = .zero
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
                Button {
                    showAddMemberSheet = true
                } label: {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "person.badge.plus")
                                .foregroundColor(.white)
                                .font(.system(size: 18, weight: .medium))
                        )
                }
                .sheet(isPresented: $showAddMemberSheet) {
                    AddMemberSheet(
                        roomId: session.payload.roomId ?? "",
                        isVideoCall: true,
                        currentReceiverId: session.payload.receiverId
                    )
                }
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

    /// Secondary video size: compact (controls hidden) vs expanded (controls visible)
    /// Android: compact = max-width:20%, expanded = max-width:50%
    private var secondaryVideoSize: CGSize {
        showControls ? CGSize(width: 140, height: 186) : CGSize(width: 90, height: 120)
    }

    /// Default position for the secondary video (bottom-right, accounting for controls)
    private func defaultPosition(geometry: GeometryProxy) -> CGPoint {
        let size = secondaryVideoSize
        return CGPoint(
            x: geometry.size.width - size.width / 2 - edgeMargin,
            y: geometry.size.height - size.height / 2 - (showControls ? 120 : 20) - edgeMargin
        )
    }

    @ViewBuilder
    private func secondaryVideo(geometry: GeometryProxy) -> some View {
        if session.isCallConnected, let local = session.localRenderer, !session.isCameraOff {
            let size = secondaryVideoSize
            let pos = secondaryPosition ?? defaultPosition(geometry: geometry)

            EAGLVideoViewWrapper(view: local)
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .scaleEffect(x: -1, y: 1) // mirror
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 4)
                .scaleEffect(secondaryVideoAppeared ? 1.0 : 0.3)
                .opacity(secondaryVideoAppeared ? 1.0 : 0.0)
                .position(
                    x: pos.x + dragOffset.width,
                    y: pos.y + dragOffset.height
                )
                .gesture(
                    DragGesture(minimumDistance: 4)
                        .onChanged { value in
                            isDragging = true
                            // Clamp drag so video stays within safe bounds
                            let bounds = safeBounds(for: size, geometry: geometry)
                            let rawX = pos.x + value.translation.width
                            let rawY = pos.y + value.translation.height
                            let clampedX = min(max(rawX, bounds.minX), bounds.maxX)
                            let clampedY = min(max(rawY, bounds.minY), bounds.maxY)
                            dragOffset = CGSize(
                                width: clampedX - pos.x,
                                height: clampedY - pos.y
                            )
                        }
                        .onEnded { value in
                            isDragging = false
                            let bounds = safeBounds(for: size, geometry: geometry)
                            let rawX = pos.x + value.translation.width
                            let rawY = pos.y + value.translation.height
                            let clampedX = min(max(rawX, bounds.minX), bounds.maxX)
                            let clampedY = min(max(rawY, bounds.minY), bounds.maxY)

                            // Snap to nearest horizontal edge, clamp Y (same as Android)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                secondaryPosition = snapToEdge(
                                    currentX: clampedX,
                                    currentY: clampedY,
                                    geometry: geometry
                                )
                                dragOffset = .zero
                            }
                        }
                )
                .animation(isDragging ? nil : .easeInOut(duration: 0.3), value: showControls)
                .zIndex(22)
                .onAppear {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        secondaryVideoAppeared = true
                    }
                }
                .onDisappear {
                    secondaryVideoAppeared = false
                }
        }
    }

    // (Arrow tabs removed — matching Android: no hide-to-side feature)

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
        withAnimation(.easeInOut(duration: 0.4)) {
            showControls.toggle()
        }
        // Re-clamp position for new size after controls toggle
        reclampPosition()
        resetControlsTimer()
    }

    private func resetControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.4)) {
                showControls = false
            }
            // Re-clamp position for compact size
            self.reclampPosition()
        }
    }

    private let edgeMargin: CGFloat = 10

    /// Safe bounds for the secondary video center point (stays within screen, respects top bar & controls)
    private func safeBounds(for size: CGSize, geometry: GeometryProxy) -> (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) {
        let hw = size.width / 2
        let hh = size.height / 2
        let minX = hw + edgeMargin
        let maxX = geometry.size.width - hw - edgeMargin
        let minY = hh + 80  // below top bar
        let maxY = geometry.size.height - hh - (showControls ? 120 : 20) - edgeMargin  // above controls
        return (minX, maxX, minY, maxY)
    }

    /// Snap to nearest corner (same as Android: determines nearest corner based on current position)
    private func snapToEdge(currentX: CGFloat, currentY: CGFloat, geometry: GeometryProxy) -> CGPoint {
        let size = secondaryVideoSize
        let hw = size.width / 2
        let hh = size.height / 2
        let bounds = safeBounds(for: size, geometry: geometry)

        // Determine nearest corner
        let isLeft = currentX < geometry.size.width / 2
        let isTop = currentY < geometry.size.height / 2

        let snapX: CGFloat = isLeft ? (hw + edgeMargin) : (geometry.size.width - hw - edgeMargin)
        let snapY: CGFloat = isTop ? bounds.minY : bounds.maxY

        return CGPoint(x: snapX, y: snapY)
    }

    /// When controls toggle, snap PiP to nearest corner with smooth animation (same as Android)
    private func reclampPosition() {
        guard let pos = secondaryPosition else { return }
        let screen = UIScreen.main.bounds
        let size = secondaryVideoSize
        let hw = size.width / 2
        let hh = size.height / 2

        let minY = hh + 80
        let maxY = screen.height - hh - (showControls ? 120 : 20) - edgeMargin

        // Determine nearest corner based on current position
        let isLeft = pos.x < screen.width / 2
        let isTop = pos.y < screen.height / 2

        let snapX: CGFloat = isLeft ? (hw + edgeMargin) : (screen.width - hw - edgeMargin)
        let snapY: CGFloat = isTop ? minY : maxY

        withAnimation(.easeInOut(duration: 0.3)) {
            secondaryPosition = CGPoint(x: snapX, y: snapY)
        }
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
#endif
