//
//  NativeVideoCallScreen.swift
//  Enclosure
//
//  Native video call screen that replaces WebView implementation.
//  Creates RTCEAGLVideoView renderers, attaches them to the session,
//  then hands everything to the SwiftUI view layer.
//

#if !targetEnvironment(simulator)
import SwiftUI
import WebRTC

struct NativeVideoCallScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session: NativeVideoCallSession

    init(payload: VideoCallPayload) {
        // Reuse existing session from ActiveCallManager (started immediately on answer,
        // before UI appears — like voice calls). Only create new for outgoing calls.
        let session: NativeVideoCallSession
        if let existing = ActiveCallManager.shared.activeVideoSession {
            session = existing
        } else {
            session = NativeVideoCallSession(payload: payload)
            // Register outgoing session with ActiveCallManager
            ActiveCallManager.shared.setOutgoingVideoSession(session, payload: payload)
        }
        // Create renderers eagerly so video shows immediately (no black screen)
        if session.localRenderer == nil {
            session.localRenderer = RTCEAGLVideoView(frame: .zero)
            session.remoteRenderer = RTCEAGLVideoView(frame: .zero)
        }
        _session = StateObject(wrappedValue: session)
    }

    @ObservedObject private var callManager = ActiveCallManager.shared

    var body: some View {
        NativeVideoCallView(session: session)
            .onAppear {
                // Exiting PiP → back to full screen
                ActiveCallManager.shared.isInPiPMode = false
                // Late-attach renderers to already-running tracks (incoming call path)
                if let local = session.localRenderer, let vt = session.webRTCManager?.localVideoTrack {
                    vt.add(local)
                    NSLog("📹 [VideoScreen] Late-attached local renderer to running session")
                }
                if let remote = session.remoteRenderer, let rt = session.remoteVideoTrack {
                    rt.add(remote)
                    NSLog("📹 [VideoScreen] Late-attached remote renderer to running session")
                }
                session.start() // no-op if already started (guard !hasStarted)
            }
            .onDisappear {
                // Only stop session if NOT entering PiP (call ended or navigated away)
                if !ActiveCallManager.shared.isInPiPMode {
                    session.stop()
                    ActiveCallManager.shared.clearVideoSession()
                }
            }
            .onReceive(session.$shouldDismiss) { shouldDismiss in
                if shouldDismiss {
                    dismiss()
                }
            }
            .onChange(of: callManager.isInPiPMode) { isPiP in
                if isPiP {
                    dismiss()
                }
            }
    }
}
#endif
