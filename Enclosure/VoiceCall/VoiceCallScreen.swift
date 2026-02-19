import SwiftUI

struct VoiceCallScreen: View {
    let payload: VoiceCallPayload

    /// Always use native WebRTC. The JS (scriptVoice.js) on Android/legacy WebView
    /// now supports raw RTCPeerConnection for native iOS peers via Firebase signaling.
    /// Native iOS sends offer → JS detects real SDP → creates raw RTCPeerConnection → answers via Firebase.
    private var useNativeWebRTC: Bool {
        return true
    }

    var body: some View {
        if useNativeWebRTC {
            NativeVoiceCallScreen(payload: payload)
        } else {
            LegacyVoiceCallScreen(payload: payload)
        }
    }
}
