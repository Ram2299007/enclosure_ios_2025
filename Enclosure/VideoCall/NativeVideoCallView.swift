//
//  NativeVideoCallView.swift
//  Enclosure
//
//  Native iOS video call UI matching Android design
//

import SwiftUI
import AVFoundation
import WebRTC

struct NativeVideoCallView: View {
    @StateObject private var session: NativeVideoCallSession
    @Environment(\.dismiss) private var dismiss
    @State private var showControls = true
    @State private var controlsTimer: Timer?
    @State private var secondaryVideoPosition = CGPoint(x: UIScreen.main.bounds.width - 110, y: UIScreen.main.bounds.height - 250)
    @State private var isDraggingSecondary = false
    @State private var secondaryVideoSize = CGSize(width: 120, height: 160)
    
    init(payload: VideoCallPayload) {
        _session = StateObject(wrappedValue: NativeVideoCallSession(payload: payload))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                // Main video view (remote or local)
                Group {
                    if let remoteView = session.remoteVideoView, session.isCallConnected {
                        RTCVideoView(view: remoteView)
                            .ignoresSafeArea()
                    } else if let localView = session.localVideoView {
                        RTCVideoView(view: localView)
                            .ignoresSafeArea()
                            .scaleEffect(x: -1, y: 1) // Mirror for selfie
                    } else {
                        // Placeholder with blur background
                        Image("bg_blur")
                            .resizable()
                            .scaledToFill()
                            .ignoresSafeArea()
                    }
                }
                
                // Top bar with caller info
                VStack {
                    HStack {
                        // Back button
                        Button(action: {
                            dismiss()
                        }) {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: "chevron.left")
                                        .foregroundColor(.white)
                                        .font(.system(size: 20, weight: .medium))
                                )
                        }
                        
                        Spacer()
                        
                        // Caller name
                        Text(session.callerName)
                            .font(.custom("Inter", size: 20))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
                        
                        Spacer()
                        
                        // Add member button (placeholder)
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "person.badge.plus")
                                    .foregroundColor(.white)
                                    .font(.system(size: 20, weight: .medium))
                            )
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 20)
                    .opacity(showControls ? 1 : 0)
                    .animation(.easeInOut(duration: 0.4), value: showControls)
                    
                    Spacer()
                    
                    // Controls
                    HStack {
                        Spacer()
                        
                        // Mute button
                        Button(action: {
                            session.toggleMicrophone()
                        }) {
                            Circle()
                                .fill(session.isMicrophoneMuted ? Constant.themeColor : Color.white.opacity(0.1))
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Image(systemName: session.isMicrophoneMuted ? "mic.slash.fill" : "mic.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size: 24, weight: .medium))
                                )
                        }
                        
                        // Camera toggle button
                        Button(action: {
                            session.toggleCamera()
                        }) {
                            Circle()
                                .fill(session.isCameraOff ? Constant.themeColor : Color.white.opacity(0.1))
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Image(systemName: session.isCameraOff ? "camera.fill" : "camera")
                                        .foregroundColor(.white)
                                        .font(.system(size: 24, weight: .medium))
                                )
                        }
                        
                        // Switch camera button
                        Button(action: {
                            session.switchCamera()
                        }) {
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Image(systemName: "camera.rotate")
                                        .foregroundColor(.white)
                                        .font(.system(size: 24, weight: .medium))
                                )
                        }
                        
                        // End call button
                        Button(action: {
                            session.endCall()
                            dismiss()
                        }) {
                            Circle()
                                .fill(Color.red.opacity(0.7))
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Image(systemName: "phone.down.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size: 24, weight: .medium))
                                )
                        }
                        
                        Spacer()
                    }
                    .padding(.bottom, 100)
                    .opacity(showControls ? 1 : 0)
                    .animation(.easeInOut(duration: 0.4), value: showControls)
                }
                
                // Secondary video (local video when connected)
                if session.isCallConnected, let localView = session.localVideoView, !session.isCameraOff {
                    RTCVideoView(view: localView)
                        .frame(width: secondaryVideoSize.width, height: secondaryVideoSize.height)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .scaleEffect(x: -1, y: 1) // Mirror for selfie
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                        .position(secondaryVideoPosition)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDraggingSecondary = true
                                    secondaryVideoPosition = value.location
                                }
                                .onEnded { value in
                                    isDraggingSecondary = false
                                    // Snap to edges
                                    let snapDistance: CGFloat = 20
                                    let screenBounds = geometry.size
                                    
                                    // Snap to right edge
                                    if value.location.x > screenBounds.width - 100 {
                                        secondaryVideoPosition.x = screenBounds.width - secondaryVideoSize.width/2 - 20
                                    }
                                    // Snap to left edge
                                    else if value.location.x < 100 {
                                        secondaryVideoPosition.x = secondaryVideoSize.width/2 + 20
                                    }
                                    
                                    // Snap to bottom edge
                                    if value.location.y > screenBounds.height - 150 {
                                        secondaryVideoPosition.y = screenBounds.height - secondaryVideoSize.height/2 - 120
                                    }
                                    // Snap to top edge
                                    else if value.location.y < 150 {
                                        secondaryVideoPosition.y = secondaryVideoSize.height/2 + 100
                                    }
                                }
                        )
                }
                
                // Tap gesture to show/hide controls
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleControls()
                    }
            }
        }
        .onAppear {
            session.start()
            resetControlsTimer()
        }
        .onDisappear {
            session.stop()
            controlsTimer?.invalidate()
        }
        .onReceive(session.$shouldDismiss) { shouldDismiss in
            if shouldDismiss {
                dismiss()
            }
        }
        .onReceive(session.$isCallConnected) { isConnected in
            if isConnected {
                // When call connects, move local video to secondary position
                withAnimation(.easeInOut(duration: 0.3)) {
                    secondaryVideoPosition = CGPoint(
                        x: UIScreen.main.bounds.width - 110,
                        y: UIScreen.main.bounds.height - 250
                    )
                }
            }
        }
    }
    
    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.4)) {
            showControls.toggle()
        }
        resetControlsTimer()
    }
    
    private func resetControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.4)) {
                showControls = false
            }
        }
    }
}

// RTCVideoView wrapper for SwiftUI
struct RTCVideoView: UIViewRepresentable {
    let view: RTCVideoRenderer
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .black
        
        if let rtcView = view as? UIView {
            rtcView.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(rtcView)
            
            NSLayoutConstraint.activate([
                rtcView.topAnchor.constraint(equalTo: containerView.topAnchor),
                rtcView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                rtcView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                rtcView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
        }
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No updates needed as the RTCVideoRenderer handles its own rendering
    }
}
