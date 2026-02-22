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
        // Reuse existing session from ActiveCallManager (started immediately on answer,
        // before UI appears — like voice calls). Only create new for outgoing calls.
        if let existing = ActiveCallManager.shared.activeVideoSession {
            _session = StateObject(wrappedValue: existing)
        } else {
            let s = NativeVideoCallSession(payload: payload)
            _session = StateObject(wrappedValue: s)
        }
    }

    var body: some View {
        NativeVideoCallView(session: session)
            .onAppear {
                // Attach renderers (session may already be running from ActiveCallManager)
                if session.localRenderer == nil {
                    let local = RTCEAGLVideoView(frame: .zero)
                    let remote = RTCEAGLVideoView(frame: .zero)
                    session.localRenderer = local
                    session.remoteRenderer = remote
                    // Attach local renderer to already-running video track
                    if let vt = session.webRTCManager?.localVideoTrack {
                        vt.add(local)
                        NSLog("📹 [VideoScreen] Late-attached local renderer to running session")
                    }
                    // Attach remote renderer to already-received remote video track
                    if let rt = session.remoteVideoTrack {
                        rt.add(remote)
                        NSLog("📹 [VideoScreen] Late-attached remote renderer to running session")
                    }
                }
                session.start() // no-op if already started (guard !hasStarted)
            }
            .onDisappear {
                session.stop()
                ActiveCallManager.shared.clearVideoSession()
            }
            .onReceive(session.$shouldDismiss) { shouldDismiss in
                if shouldDismiss {
                    dismiss()
                }
            }
    }
}
