import SwiftUI

/// WhatsApp-like active call banner — shown at top of MainActivityOld when
/// the user presses back on the call screen while a call is still running.
/// Displays: green bar with caller name, timer, mute button.
/// Tapping the banner re-opens the call screen.
struct ActiveCallBannerView: View {
    @ObservedObject var session: NativeVoiceCallSession
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Pulsing green dot
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)

                // Caller name
                Text(session.callerName.isEmpty ? "Voice Call" : session.callerName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                // Timer
                Text(formattedDuration(session.callDuration))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .monospacedDigit()

                Spacer()

                // Mute toggle
                Button(action: {
                    session.setMuted(!session.isMuted)
                }) {
                    Image(systemName: session.isMuted ? "mic.slash.fill" : "mic.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                // Tap to return indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.green)
        }
        .buttonStyle(.plain)
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
