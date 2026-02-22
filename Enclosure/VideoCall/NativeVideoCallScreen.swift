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
        _session = StateObject(wrappedValue: NativeVideoCallSession(payload: payload))
    }

    var body: some View {
        NativeVideoCallView(session: session)
            .onAppear {
                // Create renderers once (onAppear only fires once, unlike init which
                // SwiftUI may call multiple times during parent re-renders)
                if session.localRenderer == nil {
                    let local = RTCEAGLVideoView(frame: .zero)
                    let remote = RTCEAGLVideoView(frame: .zero)
                    session.localRenderer = local
                    session.remoteRenderer = remote
                }
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
