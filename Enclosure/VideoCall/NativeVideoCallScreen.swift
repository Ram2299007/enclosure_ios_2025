//
//  NativeVideoCallScreen.swift
//  Enclosure
//
//  Native video call screen that replaces WebView implementation.
//  Creates RTCEAGLVideoView renderers, attaches them to the session,
//  then hands everything to the SwiftUI view layer.
//

import SwiftUI
import WebRTC

struct NativeVideoCallScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session: NativeVideoCallSession

    init(payload: VideoCallPayload) {
        let s = NativeVideoCallSession(payload: payload)

        // Create EAGL renderers (OpenGL — works on all iOS devices)
        let local = RTCEAGLVideoView(frame: .zero)
        let remote = RTCEAGLVideoView(frame: .zero)
        s.localRenderer = local
        s.remoteRenderer = remote

        _session = StateObject(wrappedValue: s)
    }

    var body: some View {
        NativeVideoCallView(session: session)
            .onAppear {
                session.start()
            }
            .onDisappear {
                session.stop()
            }
            .onReceive(session.$shouldDismiss) { shouldDismiss in
                if shouldDismiss {
                    dismiss()
                }
            }
    }
}
