//
//  MultiVideoPreviewDialog.swift
//  Enclosure
//
//  Created by Ram Lohar on 14/12/25.
//

import SwiftUI
import AVFoundation
import AVKit
import Photos

// MARK: - Multi-Video Preview Dialog (matching MultiImagePreviewDialog design)
struct MultiVideoPreviewDialog: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Binding var selectedAssetIds: Set<String>
    let videoAssets: [PHAsset]
    let imageManager: PHCachingImageManager
    @Binding var caption: String
    let onSend: (String) -> Void
    let onDismiss: () -> Void
    
    @State private var currentIndex: Int = 0
    @State private var videoPlayers: [AVPlayer?] = []
    @State private var videoThumbnails: [UIImage?] = []
    @State private var isLoading: Bool = true
    @State private var keyboardHeight: CGFloat = 0
    @State private var isPlaying: [Bool] = [] // Track playing state for each video
    @State private var showVideoPlayer: Bool = false
    @State private var playerToShow: AVPlayer? = nil
    @FocusState private var isCaptionFocused: Bool
    
    // Typography (match Android messageBox sizing prefs)
    private var messageInputFont: Font {
        let pref = UserDefaults.standard.string(forKey: "Font_Size") ?? "medium"
        let size: CGFloat
        switch pref {
        case "small":
            size = 13
        case "large":
            size = 19
        default:
            size = 16
        }
        return .custom("Inter18pt-Regular", size: size)
    }
    
    private var selectedAssets: [PHAsset] {
        videoAssets.filter { selectedAssetIds.contains($0.localIdentifier) }
    }
    
    var body: some View {
        ZStack {
            // Full-screen background (matching Android transparent background)
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar with back button and video count (matching Android header)
                HStack {
                    // Back button
                    Button(action: {
                        // Light haptic feedback
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        pauseAllVideos()
                        onDismiss()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 40, height: 40)
                            
                            Image("leftvector")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 25, height: 18)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.leading, 16)
                    
                    Spacer()
                    
                    // Video count indicator (matching Android counter) - always show
                    Text("\(currentIndex + 1) / \(selectedAssets.count)")
                        .font(.custom("Inter18pt-Medium", size: 16))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Spacer to balance layout (send button is in bottom caption bar)
                    Spacer()
                        .frame(width: 40)
                }
                .frame(height: 60)
                .background(Color.black.opacity(0.3))
                
                // Video preview area (matching Android video preview)
                GeometryReader { geometry in
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        TabView(selection: $currentIndex) {
                            ForEach(Array(selectedAssets.enumerated()), id: \.element.localIdentifier) { index, asset in
                                ZStack {
                                    Color.black
                                    
                                    // Show thumbnail
                                    if index < videoThumbnails.count, let thumbnail = videoThumbnails[index] {
                                        Image(uiImage: thumbnail)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    } else {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    }
                                    
                                    // Play icon overlay (show when not playing)
                                    if index >= isPlaying.count || !isPlaying[index] {
                                        ZStack {
                                            // Black circle background (matching Android black_circle)
                                            Circle()
                                                .fill(Color.black.opacity(0.7))
                                                .frame(width: 64, height: 64)
                                            
                                            // Play arrow icon (matching Android baseline_play_arrow_24)
                                            Image(systemName: "play.fill")
                                                .font(.system(size: 32, weight: .medium))
                                                .foregroundColor(.white)
                                                .offset(x: 2) // Slight offset to center the play icon better
                                        }
                                    }
                                }
                                .tag(index)
                                .onTapGesture {
                                    playVideoWithNativePlayer(at: index)
                                }
                                .sheet(isPresented: $showVideoPlayer) {
                                    if let player = playerToShow {
                                        VideoPlayerViewController(player: player)
                                    }
                                }
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .onChange(of: currentIndex) { newIndex in
                            // Pause previous video when switching
                            pauseAllVideos()
                            loadVideoIfNeeded(at: newIndex)
                        }
                    }
                }
                
                // Spacing between video and caption area (5px)
                Spacer()
                    .frame(height: 5)
                
                // Bottom caption input area (matching WhatsAppLikeImagePicker captionBarView design)
                HStack(spacing: 0) {
                    // Caption input container (matching messageBox design from WhatsAppLikeImagePicker)
                    HStack(spacing: 0) {
                        // Message input field container - layout_weight="1"
                        VStack(alignment: .leading, spacing: 0) {
                            ZStack(alignment: .leading) {
                                // Placeholder text (matching Android textColorHint="#9EA6B9")
                                if caption.isEmpty {
                                    Text("Add Caption")
                                        .font(.custom("Inter18pt-Medium", size: 17))
                                        .foregroundColor(Color(hex: "#9EA6B9"))
                                        .padding(.leading, 15)
                                        .padding(.trailing, 20)
                                        .padding(.top, 5)
                                        .padding(.bottom, 5)
                                }
                                
                                // TextField (matching Android EditText properties)
                                TextField("", text: $caption, axis: .vertical)
                                    .font(.custom("Inter18pt-Medium", size: 17)) // textSize="17sp", textFontWeight="500"
                                    .foregroundColor(.white) // textColor="@color/white"
                                    .lineLimit(4) // maxLines="4"
                                    .lineSpacing(4) // lineHeight="21dp" (21 - 17 = 4dp spacing)
                                    .frame(maxWidth: 180, alignment: .leading) // maxWidth="180dp"
                                    .padding(.leading, 15) // paddingStart="15dp"
                                    .padding(.trailing, 20) // paddingEnd="20dp"
                                    .padding(.top, 5) // paddingTop="5dp"
                                    .padding(.bottom, 5) // paddingBottom="5dp"
                                    .background(Color.clear) // background="#00000000"
                                    .focused($isCaptionFocused)
                                    .accentColor(Color("black_white_crossEmoji")) // textColorHighlight
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 50) // Match send button height (50dp)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(hex: "#1B1C1C")) // Use specified color for caption message box
                    )
                    .padding(.leading, 10)
                    .padding(.trailing, 5)
                    
                    // Send button group (matching sendGrpLyt from WhatsAppLikeImagePicker)
                    VStack(spacing: 0) {
                        Button(action: {
                            // Light haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            pauseAllVideos()
                            onSend(caption.trimmingCharacters(in: .whitespacesAndNewlines))
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: Constant.themeColor))
                                    .frame(width: 50, height: 50)
                                
                                // Send icon (keyboard double arrow right) - same as Android
                                Image("baseline_keyboard_double_arrow_right_24")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 26, height: 26)
                                    .foregroundColor(.white)
                                    .padding(.top, 4)
                                    .padding(.bottom, 8)
                            }
                        }
                    }
                    .padding(.horizontal, 5)
                }
                .padding(.bottom, keyboardHeight > 0 ? keyboardHeight - 20 : 10)
                .background(Color.black)
            }
        }
        .onAppear {
            loadAllVideos()
            setupKeyboardObservers()
        }
        .onDisappear {
            pauseAllVideos()
            removeKeyboardObservers()
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded { value in
                    // Handle swipe down to dismiss (optional)
                    if value.translation.height > 100 {
                        pauseAllVideos()
                        onDismiss()
                    }
                }
        )
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            keyboardHeight = 0
        }
    }
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func loadAllVideos() {
        isLoading = true
        videoPlayers = Array(repeating: nil, count: selectedAssets.count)
        videoThumbnails = Array(repeating: nil, count: selectedAssets.count)
        isPlaying = Array(repeating: false, count: selectedAssets.count)
        
        let group = DispatchGroup()
        
        for (index, asset) in selectedAssets.enumerated() {
            group.enter()
            loadVideoForAsset(asset, at: index) {
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            isLoading = false
            // Load first video thumbnail immediately (but don't play)
            if !selectedAssets.isEmpty {
                loadVideoIfNeeded(at: 0)
            }
        }
    }
    
    private func loadVideoIfNeeded(at index: Int) {
        guard index < selectedAssets.count else { return }
        guard index >= videoPlayers.count || videoPlayers[index] == nil else { return }
        
        let asset = selectedAssets[index]
        loadVideoForAsset(asset, at: index)
    }
    
    private func loadVideoForAsset(_ asset: PHAsset, at index: Int, completion: (() -> Void)? = nil) {
        // Load thumbnail first
        let thumbnailSize = CGSize(width: UIScreen.main.bounds.width * 2, height: UIScreen.main.bounds.height * 2)
        let thumbnailOptions = PHImageRequestOptions()
        thumbnailOptions.deliveryMode = .highQualityFormat
        thumbnailOptions.resizeMode = .exact
        thumbnailOptions.isSynchronous = false
        
        imageManager.requestImage(
            for: asset,
            targetSize: thumbnailSize,
            contentMode: .aspectFit,
            options: thumbnailOptions
        ) { image, _ in
            DispatchQueue.main.async {
                if index < self.videoThumbnails.count {
                    self.videoThumbnails[index] = image
                }
            }
        }
        
        // Load video
        let videoOptions = PHVideoRequestOptions()
        videoOptions.deliveryMode = .highQualityFormat
        videoOptions.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestAVAsset(forVideo: asset, options: videoOptions) { avAsset, _, _ in
            DispatchQueue.main.async {
                if let avAsset = avAsset {
                    let player = AVPlayer(playerItem: AVPlayerItem(asset: avAsset))
                    if index < self.videoPlayers.count {
                        self.videoPlayers[index] = player
                    }
                }
                completion?()
            }
        }
    }
    
    private func playVideoWithNativePlayer(at index: Int) {
        guard index < selectedAssets.count else { return }
        
        let asset = selectedAssets[index]
        
        // Load video if not already loaded
        if index >= videoPlayers.count || videoPlayers[index] == nil {
            loadVideoForAsset(asset, at: index) {
                DispatchQueue.main.async {
                    if index < self.videoPlayers.count, let player = self.videoPlayers[index] {
                        self.playerToShow = player
                        self.showVideoPlayer = true
                    }
                }
            }
        } else {
            // Video already loaded, show player
            if index < videoPlayers.count, let player = videoPlayers[index] {
                playerToShow = player
                showVideoPlayer = true
            }
        }
    }
    
    private func pauseAllVideos() {
        for player in videoPlayers {
            player?.pause()
        }
    }
}

// MARK: - Video Player View Controller (Native Apple Player)
struct VideoPlayerViewController: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.allowsPictureInPicturePlayback = false
        controller.videoGravity = .resizeAspect
        
        // Auto-play when presented
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            player.play()
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // Update if needed
    }
}

