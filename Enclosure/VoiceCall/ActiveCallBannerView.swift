import SwiftUI

/// WhatsApp-like active call banner — shown at top of MainActivityOld when
/// the user presses back on the call screen while a call is still running.
/// Extends behind status bar. Supports dark/light mode. Inter font throughout.
struct ActiveCallBannerView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var session: NativeVoiceCallSession
    var onTap: () -> Void

    @State private var isPulsing = false

    private let themeColor = Color(hex: Constant.themeColor)

    // Dark/light adaptive colors
    private var bannerBg: Color {
        colorScheme == .dark ? Color(hex: "#011224") : Color.white
    }
    private var primaryText: Color {
        colorScheme == .dark ? .white : Color(hex: "#011224")
    }
    private var secondaryText: Color {
        colorScheme == .dark ? .white.opacity(0.6) : Color(hex: "#011224").opacity(0.55)
    }
    private var muteBtnBg: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color(hex: "#011224").opacity(0.08)
    }
    private var gradientOpacity: Double {
        colorScheme == .dark ? 0.15 : 0.08
    }

    private var statusBarHeight: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 47
    }

    // Call direction text
    private var callDirectionText: String {
        session.isSender ? "Outgoing" : "Incoming"
    }

    // Status subtitle
    private var statusText: String {
        if session.isCallConnected {
            return "\(callDirectionText) · \(formattedDuration(session.callDuration))"
        } else {
            return "\(callDirectionText) · Connecting..."
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Status bar area — same background, seamless
                Color.clear
                    .frame(height: statusBarHeight)

                // Banner content
                HStack(spacing: 12) {

                    // Pulsing call indicator
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.3))
                            .frame(width: 20, height: 20)
                            .scaleEffect(isPulsing ? 1.4 : 1.0)
                            .opacity(isPulsing ? 0 : 0.6)
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                    }

                    // Caller name + status (same left alignment)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.callerName.isEmpty ? "Voice Call" : session.callerName)
                            .font(.custom("Inter18pt-SemiBold", size: 14))
                            .foregroundColor(primaryText)
                            .lineLimit(1)

                        HStack(spacing: 4) {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 9))
                                .foregroundColor(themeColor)
                            Text(statusText)
                                .font(.custom("Inter18pt-Medium", size: 11))
                                .foregroundColor(secondaryText)
                                .monospacedDigit()
                        }
                    }

                    Spacer()

                    // Mute toggle
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        session.setMuted(!session.isMuted)
                    }) {
                        ZStack {
                            Circle()
                                .fill(session.isMuted ? themeColor.opacity(0.7) : muteBtnBg)
                                .frame(width: 34, height: 34)
                            Image(systemName: session.isMuted ? "mic.slash.fill" : "mic.fill")
                                .font(.system(size: 14))
                                .foregroundColor(session.isMuted ? .white : primaryText)
                        }
                    }
                    .buttonStyle(.plain)

                    // Tap to return
                    Text("RETURN")
                        .font(.custom("Inter18pt-Bold", size: 10))
                        .foregroundColor(themeColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(themeColor.opacity(colorScheme == .dark ? 0.15 : 0.1))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(
                bannerBg
                    .overlay(
                        LinearGradient(
                            colors: [themeColor.opacity(gradientOpacity), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
        .ignoresSafeArea(.container, edges: .top)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
