//
//  NativeVideoCallScreen.swift
//  Enclosure
//
//  Native video call screen that replaces WebView implementation
//

import SwiftUI

struct NativeVideoCallScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session: NativeVideoCallSession
    
    init(payload: VideoCallPayload) {
        _session = StateObject(wrappedValue: NativeVideoCallSession(payload: payload))
    }
    
    var body: some View {
        NativeVideoCallView(session: session)
            .onAppear {
                // Setup video views
                setupVideoViews()
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
    
    private func setupVideoViews() {
        // Create video renderers with proper frame
        let screenBounds = UIScreen.main.bounds
        let localVideoView = RTCMTLVideoView(frame: CGRect(x: 0, y: 0, width: screenBounds.width, height: screenBounds.height))
        let remoteVideoView = RTCMTLVideoView(frame: CGRect(x: 0, y: 0, width: screenBounds.width, height: screenBounds.height))
        
        // Configure video views
        localVideoView.contentMode = .scaleAspectFill
        remoteVideoView.contentMode = .scaleAspectFill
        
        // Set them on the session
        session.localVideoView = localVideoView
        session.remoteVideoView = remoteVideoView
    }
}

// Preview
struct NativeVideoCallScreen_Previews: PreviewProvider {
    static var previews: some View {
        let payload = VideoCallPayload(
            receiverId: "123",
            receiverName: "Test User",
            receiverPhoto: "",
            receiverToken: "",
            receiverDeviceType: "",
            receiverPhone: "",
            roomId: "test_room",
            isSender: true
        )
        
        NativeVideoCallScreen(payload: payload)
    }
}
