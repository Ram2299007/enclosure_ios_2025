// VideoCallPiPView.swift
// Enclosure
//
// Floating PiP overlay for video calls — shows a small draggable
// video thumbnail when user presses back during a call.
// Tap to return to full screen, X button to end the call.

import SwiftUI
import WebRTC

/// Simple UIViewRepresentable for PiP — avoids the constraint-based
/// AspectFillContainer that crashes when RTCEAGLVideoView moves hierarchies.
private struct PiPVideoWrapper: UIViewRepresentable {
    let videoView: RTCEAGLVideoView

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .black
        container.clipsToBounds = true

        // Remove from old superview if still attached
        videoView.removeFromSuperview()
        // Remove all existing constraints on the video view
        videoView.removeConstraints(videoView.constraints)
        videoView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(videoView)

        // Simple fill — just pin edges (PiP is small, no need for aspect-fill)
        NSLayoutConstraint.activate([
            videoView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            videoView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            videoView.topAnchor.constraint(equalTo: container.topAnchor),
            videoView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct VideoCallPiPView: View {
    @ObservedObject var session: NativeVideoCallSession
    @ObservedObject var callManager: ActiveCallManager

    @State private var position = CGPoint(x: UIScreen.main.bounds.width - 90, y: 120)
    @State private var dragOffset = CGSize.zero

    private let pipSize = CGSize(width: 130, height: 180)

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Video content — use simple wrapper to avoid constraint crashes
            Group {
                if session.isCallConnected, let remote = session.remoteRenderer {
                    PiPVideoWrapper(videoView: remote)
                } else if let local = session.localRenderer {
                    PiPVideoWrapper(videoView: local)
                        .scaleEffect(x: -1, y: 1)
                } else {
                    Color.black
                }
            }
            .frame(width: pipSize.width, height: pipSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Duration badge
            if session.isCallConnected {
                Text(formattedDuration)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                    .padding(6)
                    .allowsHitTesting(false)
            }

            // End call (X) button
            VStack {
                Spacer()
                HStack {
                    // End call
                    Button {
                        session.endCall()
                    } label: {
                        Circle()
                            .fill(Color.red.opacity(0.9))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "phone.down.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white)
                            )
                    }

                    Spacer()

                    // Expand to full screen
                    Button {
                        callManager.isInPiPMode = false
                    } label: {
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white)
                            )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .frame(width: pipSize.width, height: pipSize.height)
        }
        .frame(width: pipSize.width, height: pipSize.height)
        .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)
        .position(
            x: position.x + dragOffset.width,
            y: position.y + dragOffset.height
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    position.x += value.translation.width
                    position.y += value.translation.height
                    dragOffset = .zero
                    snapToEdge()
                }
        )
        .onTapGesture {
            callManager.isInPiPMode = false
        }
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(response: 0.3), value: callManager.isInPiPMode)
    }

    private var formattedDuration: String {
        let m = Int(session.callDuration) / 60
        let s = Int(session.callDuration) % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func snapToEdge() {
        let screenW = UIScreen.main.bounds.width
        let screenH = UIScreen.main.bounds.height
        let hw = pipSize.width / 2
        let hh = pipSize.height / 2
        let margin: CGFloat = 12

        // Snap X to nearest edge
        if position.x < screenW / 2 {
            position.x = hw + margin
        } else {
            position.x = screenW - hw - margin
        }

        // Clamp Y
        let minY = hh + 60  // below status bar
        let maxY = screenH - hh - 40
        position.y = min(max(position.y, minY), maxY)
    }
}
