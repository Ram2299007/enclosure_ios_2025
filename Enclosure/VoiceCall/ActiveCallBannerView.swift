import SwiftUI

/// WhatsApp-like active call banner — shown at top of MainActivityOld when
/// the user presses back on the call screen while a call is still running.
/// Modern design with app theme color, Inter font, and smooth animations.
struct ActiveCallBannerView: View {
    @ObservedObject var session: NativeVoiceCallSession
    var onTap: () -> Void

    @State private var isPulsing = false

    private let themeColor = Color(hex: Constant.themeColor)
    private let darkBg = Color(hex: "#011224")

    var body: some View {
        Button(action: onTap) {
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

                // Caller name + status
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.callerName.isEmpty ? "Voice Call" : session.callerName)
                        .font(.custom("Inter18pt-SemiBold", size: 14))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 9))
                            .foregroundColor(themeColor)
                        Text(session.isCallConnected ? "Ongoing · \(formattedDuration(session.callDuration))" : "Connecting...")
                            .font(.custom("Inter18pt-Medium", size: 11))
                            .foregroundColor(.white.opacity(0.7))
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
                            .fill(session.isMuted ? themeColor.opacity(0.7) : Color.white.opacity(0.12))
                            .frame(width: 34, height: 34)
                        Image(systemName: session.isMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)

                // Tap to return
                Text("RETURN")
                    .font(.custom("Inter18pt-Bold", size: 10))
                    .foregroundColor(themeColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(themeColor.opacity(0.15))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                darkBg
                    .overlay(
                        LinearGradient(
                            colors: [themeColor.opacity(0.15), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
        }
        .buttonStyle(.plain)
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
