//
//  GroupMultiVideoPreviewDialog.swift
//  Enclosure
//
//  Created by Ram Lohar on 30/04/25.
//

import SwiftUI
import AVFoundation
import AVKit
import Photos
import FirebaseStorage
import FirebaseDatabase

// MARK: - Group Multi-Video Preview Dialog (matching MultiVideoPreviewDialog design)
struct GroupMultiVideoPreviewDialog: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Binding var selectedAssetIds: Set<String>
    let videoAssets: [PHAsset]
    let imageManager: PHCachingImageManager
    @Binding var caption: String
    let group: GroupModel
    let onSend: (String) -> Void
    let onDismiss: () -> Void
    let onMessageAdded: ((ChatMessage) -> Void)? = nil // Callback to add message immediately to list (optional, defaults to nil)
    
    @State private var currentIndex: Int = 0
    @State private var videoPlayers: [AVPlayer?] = []
    @State private var videoThumbnails: [UIImage?] = []
    @State private var isLoading: Bool = true
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
    
    // Helper function to hide keyboard
    private func hideKeyboard() {
        isCaptionFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    var body: some View {
        ZStack {
            // Full-screen background (matching Android transparent background)
            Color.black
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    hideKeyboard()
                }
            
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isCaptionFocused ? Color("TextColor") : Color.gray, lineWidth: isCaptionFocused ? 1.5 : 1.0)
                    )
                    .animation(.easeInOut(duration: 0.2), value: isCaptionFocused)
                    .padding(.leading, 10)
                    .padding(.trailing, 5)
                    
                    // Send button group (matching sendGrpLyt from WhatsAppLikeImagePicker)
                    VStack(spacing: 0) {
                        Button(action: {
                            // Light haptic feedback (guarded to avoid errors on unsupported devices)
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.prepare()
                            generator.impactOccurred()
                            pauseAllVideos()
                            
                            // Dismiss keyboard first to avoid constraint warnings
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            
                            let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
                            print("GroupMultiVideoPreviewDialog: Send button clicked - Caption: '\(trimmedCaption)' (length: \(trimmedCaption.count))")
                            
                            // Small delay to let keyboard dismiss animation complete
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                self.handleMultiVideoSend(caption: trimmedCaption)
                            }
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
                .padding(.bottom, 10)
                .background(Color.black)
            }
        }
        .simultaneousGesture(
            TapGesture().onEnded { _ in
                hideKeyboard()
            }
        )
        .ignoresSafeArea(.keyboard)
        .onAppear {
            print("GroupMultiVideoPreviewDialog: onAppear - Initial caption: '\(caption)' (length: \(caption.count))")
            loadAllVideos()
        }
        .onDisappear {
            pauseAllVideos()
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    // Handle swipe down to dismiss (optional)
                    if value.translation.height > 100 {
                        pauseAllVideos()
                        onDismiss()
                    }
                }
        )
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
    
    // MARK: - Video Upload Functions (matching Android sendMultipleVideos)
    
    enum MultiVideoUploadError: Error {
        case dataUnavailable
        case thumbnailGenerationFailed
        case downloadURLMissing
        case uploadFailed(String)
    }
    
    /// Check if message exists in Firebase and stop progress bar (matching Android behavior)
    private func checkMessageInFirebaseAndStopProgress(messageId: String, groupId: String) {
        let database = Database.database().reference()
        let messageRef = database.child(Constant.GROUPCHAT).child(groupId).child(messageId)
        
        print("🔍 [ProgressBar] Checking if video message exists in Firebase: \(messageId)")
        
        // Check if message exists in Firebase (matching Android addListenerForSingleValueEvent)
        messageRef.observeSingleEvent(of: .value) { snapshot in
            if snapshot.exists() {
                print("✅ [ProgressBar] Video message confirmed in Firebase, stopping animation and updating receiverLoader")
                
                // Remove from pending table (matching Android removePendingMessage)
                let removed = DatabaseHelper.shared.removePendingMessage(modelId: messageId, receiverUid: groupId)
                if removed {
                    print("✅ [PendingMessages] Removed pending video message from SQLite: \(messageId)")
                }
                
                // Update receiverLoader to 1 to stop progress bar (matching Android setIndeterminate(false))
                let receiverLoaderRef = database.child(Constant.GROUPCHAT).child(groupId).child(messageId).child("receiverLoader")
                receiverLoaderRef.setValue(1) { error, _ in
                    if let error = error {
                        print("🚫 [ProgressBar] Error updating receiverLoader: \(error.localizedDescription)")
                    } else {
                        print("✅ [ProgressBar] receiverLoader updated to 1 for video message: \(messageId)")
                    }
                }
            } else {
                print("⚠️ [ProgressBar] Video message not found in Firebase yet, keeping animation")
                // Keep receiverLoader as 0, animation continues
            }
        }
    }
    
    private func handleMultiVideoSend(caption: String) {
        print("GroupMultiVideoPreviewDialog: === MULTI-VIDEO SEND ===")
        print("GroupMultiVideoPreviewDialog: Selected videos count: \(selectedAssets.count)")
        print("GroupMultiVideoPreviewDialog: Caption: '\(caption)'")
        
        guard !selectedAssets.isEmpty else {
            print("GroupMultiVideoPreviewDialog: No videos selected, returning")
            return
        }
        
        // Close the preview dialog
        onDismiss()
        
        let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let groupId = group.groupId
        let senderId = Constant.SenderIdMy
        let userName = UserDefaults.standard.string(forKey: Constant.full_name) ?? ""
        let micPhoto = UserDefaults.standard.string(forKey: Constant.profilePic) ?? ""
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "hh:mm a"
        let currentDateTimeString = timeFormatter.string(from: Date())
        
        let currentDateFormatter = DateFormatter()
        currentDateFormatter.dateFormat = "yyyy-MM-dd"
        let currentDateString = currentDateFormatter.string(from: Date())
        
        let timestamp = Date().timeIntervalSince1970
        
        // Upload all videos to Firebase Storage, then push to API + RTDB
        let dispatchGroup = DispatchGroup()
        let lockQueue = DispatchQueue(label: "com.enclosure.groupMultiVideoUpload.lock")
        
        struct UploadedVideoResult {
            let index: Int
            let videoDownloadURL: String
            let thumbnailDownloadURL: String
            let videoFileName: String
            let thumbnailFileName: String
            let width: Int
            let height: Int
        }
        
        var uploadResults: [UploadedVideoResult] = []
        var uploadErrors: [Error] = []
        
        for (index, asset) in selectedAssets.enumerated() {
            dispatchGroup.enter()
            let videoModelId = UUID().uuidString
            let videoFileName = "\(videoModelId).mp4"
            let thumbnailFileName = "thumb_\(videoModelId).jpg"
            
            // Step 1: Generate thumbnail
            generateVideoThumbnail(asset: asset) { thumbnailResult in
                switch thumbnailResult {
                case .failure(let error):
                    lockQueue.sync { uploadErrors.append(error) }
                    dispatchGroup.leave()
                case .success(let thumbnailData):
                    // Step 2: Upload thumbnail
                    self.uploadThumbnailToFirebase(data: thumbnailData, remoteFileName: thumbnailFileName) { thumbnailUploadResult in
                        switch thumbnailUploadResult {
                        case .failure(let error):
                            lockQueue.sync { uploadErrors.append(error) }
                            dispatchGroup.leave()
                        case .success(let thumbnailURL):
                            // Step 3: Export and upload video
                            self.exportVideoAsset(asset, fileName: videoFileName) { videoExportResult in
                                switch videoExportResult {
                                case .failure(let error):
                                    lockQueue.sync { uploadErrors.append(error) }
                                    dispatchGroup.leave()
                                case .success(let videoData):
                                    // Save video to local storage (matching Android Enclosure/Media/Videos)
                                    self.saveVideoToLocalStorage(data: videoData, fileName: videoFileName)
                                    
                                    self.uploadVideoFileToFirebase(data: videoData, remoteFileName: videoFileName) { videoUploadResult in
                                        switch videoUploadResult {
                                        case .failure(let error):
                                            lockQueue.sync { uploadErrors.append(error) }
                                        case .success(let videoURL):
                                            // Get dimensions from thumbnail
                                            let image = UIImage(data: thumbnailData)
                                            let width = image?.cgImage?.width ?? Int(asset.pixelWidth)
                                            let height = image?.cgImage?.height ?? Int(asset.pixelHeight)
                                            
                                            let result = UploadedVideoResult(
                                                index: index,
                                                videoDownloadURL: videoURL,
                                                thumbnailDownloadURL: thumbnailURL,
                                                videoFileName: videoFileName,
                                                thumbnailFileName: thumbnailFileName,
                                                width: width,
                                                height: height
                                            )
                                            lockQueue.sync { uploadResults.append(result) }
                                        }
                                        dispatchGroup.leave()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            if uploadResults.isEmpty {
                print("🚫 [GROUP_MULTI_VIDEO] Upload failed - no results")
                Constant.showToast(message: "Unable to upload videos. Please try again.")
                return
            }
            
            if !uploadErrors.isEmpty {
                print("⚠️ [GROUP_MULTI_VIDEO] Some uploads failed: \(uploadErrors.count) errors")
            }
            
            let sortedResults = uploadResults.sorted { $0.index < $1.index }
            
            // Send each video as a separate message (matching Android behavior)
            for result in sortedResults {
                let videoModelId = UUID().uuidString
                
                let aspectRatioValue: String
                if result.height > 0 {
                    aspectRatioValue = String(format: "%.2f", Double(result.width) / Double(result.height))
                } else {
                    aspectRatioValue = ""
                }
                
                print("GroupMultiVideoPreviewDialog: Creating GroupChatMessage \(result.index + 1)/\(sortedResults.count) with caption: '\(trimmedCaption)'")
                // Create message with group information using GroupChatMessage
                let createdBy = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
                let newMessage = GroupChatMessage(
                    id: videoModelId,
                    uid: senderId,
                    message: "",
                    time: currentDateTimeString,
                    document: result.videoDownloadURL,
                    dataType: Constant.video,
                    fileExtension: "mp4",
                    name: nil,
                    phone: nil,
                    miceTiming: nil,
                    micPhoto: micPhoto,
                    createdBy: createdBy,
                    userName: userName,
                    receiverUid: groupId, // Use groupId as receiverUid for groups
                    docSize: nil,
                    fileName: result.videoFileName,
                    thumbnail: result.thumbnailDownloadURL,
                    fileNameThumbnail: result.thumbnailFileName,
                    caption: trimmedCaption,
                    currentDate: currentDateString,
                    imageWidth: "\(result.width)",
                    imageHeight: "\(result.height)",
                    aspectRatio: aspectRatioValue,
                    active: 0, // 0 = sending, 1 = sent
                    selectionCount: "1",
                    selectionBunch: nil
                )
                print("GroupMultiVideoPreviewDialog: GroupChatMessage created with caption: '\(newMessage.caption ?? "nil")'")
                
                // Convert GroupChatMessage to ChatMessage for database storage
                let chatMessageForDB = ChatMessage(
                    id: newMessage.id,
                    uid: newMessage.uid,
                    message: newMessage.message,
                    time: newMessage.time,
                    document: newMessage.document,
                    dataType: newMessage.dataType,
                    fileExtension: newMessage.fileExtension,
                    name: newMessage.name,
                    phone: newMessage.phone,
                    micPhoto: newMessage.micPhoto,
                    miceTiming: newMessage.miceTiming,
                    userName: newMessage.userName,
                    receiverId: newMessage.receiverUid, // Use receiverUid as receiverId
                    replytextData: nil,
                    replyKey: nil,
                    replyType: nil,
                    replyOldData: nil,
                    replyCrtPostion: nil,
                    forwaredKey: nil,
                    groupName: group.name, // Set group name
                    docSize: newMessage.docSize,
                    fileName: newMessage.fileName,
                    thumbnail: newMessage.thumbnail,
                    fileNameThumbnail: newMessage.fileNameThumbnail,
                    caption: newMessage.caption,
                    notification: 1,
                    currentDate: newMessage.currentDate,
                    emojiModel: [EmojiModel(name: "", emoji: "")],
                    emojiCount: nil,
                    timestamp: timestamp,
                    imageWidth: newMessage.imageWidth,
                    imageHeight: newMessage.imageHeight,
                    aspectRatio: newMessage.aspectRatio,
                    selectionCount: newMessage.selectionCount,
                    selectionBunch: newMessage.selectionBunch,
                    receiverLoader: 0
                )
                
                // Store message in SQLite pending table before upload (matching Android insertPendingMessage)
                DatabaseHelper.shared.insertPendingMessage(chatMessageForDB)
                print("✅ [PendingMessages] Group video message stored in pending table: \(videoModelId)")
                
                // Add message to UI immediately with progress bar (matching Android messageList.add + itemAdd)
                onMessageAdded?(chatMessageForDB)
                
                let userFTokenKey = UserDefaults.standard.string(forKey: Constant.FCM_TOKEN) ?? ""
                
                // Upload message via GROUP API (not individual chat API)
                MessageUploadService.shared.uploadGroupMessage(
                    model: newMessage,
                    filePath: nil,
                    userFTokenKey: userFTokenKey
                ) { success, errorMessage in
                    if success {
                        print("✅ [GROUP_MULTI_VIDEO] Uploaded video \(result.index + 1)/\(sortedResults.count) for modelId=\(videoModelId) using GROUP API")
                        // Check if message exists in Firebase and stop progress bar
                        self.checkMessageInFirebaseAndStopProgress(messageId: videoModelId, groupId: groupId)
                    } else {
                        print("🚫 [GROUP_MULTI_VIDEO] Upload error: \(errorMessage ?? "Unknown error")")
                        Constant.showToast(message: "Failed to send video. Please try again.")
                    }
                }
            }
            
            // Clear selected assets after sending
            self.selectedAssetIds.removeAll()
            
            // Call the original onSend callback for any additional handling
            onSend(trimmedCaption)
        }
    }
    
    // Generate thumbnail from video asset
    private func generateVideoThumbnail(asset: PHAsset, completion: @escaping (Result<Data, Error>) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.resizeMode = .exact
        
        let thumbnailSize = CGSize(width: 800, height: 800)
        
        imageManager.requestImage(
            for: asset,
            targetSize: thumbnailSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            guard let image = image else {
                completion(.failure(MultiVideoUploadError.thumbnailGenerationFailed))
                return
            }
            
            // Convert to JPEG
            guard let jpegData = image.jpegData(compressionQuality: 0.85) else {
                completion(.failure(MultiVideoUploadError.thumbnailGenerationFailed))
                return
            }
            
            completion(.success(jpegData))
        }
    }
    
    // Export video asset to Data
    private func exportVideoAsset(_ asset: PHAsset, fileName: String, completion: @escaping (Result<Data, Error>) -> Void) {
        let videoOptions = PHVideoRequestOptions()
        videoOptions.deliveryMode = .highQualityFormat
        videoOptions.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestAVAsset(forVideo: asset, options: videoOptions) { avAsset, _, _ in
            guard let avAsset = avAsset else {
                completion(.failure(MultiVideoUploadError.dataUnavailable))
                return
            }
            
            // Export AVAsset to Data
            if let urlAsset = avAsset as? AVURLAsset {
                // Direct file URL available
                do {
                    let videoData = try Data(contentsOf: urlAsset.url)
                    completion(.success(videoData))
                } catch {
                    completion(.failure(error))
                }
            } else {
                // Need to export the asset
                self.exportAVAssetToData(avAsset, completion: completion)
            }
        }
    }
    
    // Export AVAsset to Data using AVAssetExportSession
    private func exportAVAssetToData(_ asset: AVAsset, completion: @escaping (Result<Data, Error>) -> Void) {
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            completion(.failure(MultiVideoUploadError.dataUnavailable))
            return
        }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        exportSession.outputURL = tempURL
        exportSession.outputFileType = .mp4
        
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                do {
                    let videoData = try Data(contentsOf: tempURL)
                    try? FileManager.default.removeItem(at: tempURL) // Clean up temp file
                    completion(.success(videoData))
                } catch {
                    completion(.failure(error))
                }
            case .failed, .cancelled:
                completion(.failure(exportSession.error ?? MultiVideoUploadError.dataUnavailable))
            default:
                completion(.failure(MultiVideoUploadError.dataUnavailable))
            }
        }
    }
    
    // Upload thumbnail to Firebase Storage
    // Note: Firebase Storage handles background uploads automatically, so we don't need background tasks
    private func uploadThumbnailToFirebase(data: Data, remoteFileName: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Use GROUPCHAT constant and group.groupId for storage path
        let storagePath = "\(Constant.GROUPCHAT)/\(group.groupId)/\(remoteFileName)"
        let ref = Storage.storage().reference().child(storagePath)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        ref.putData(data, metadata: metadata) { _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            ref.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let url = url else {
                    completion(.failure(MultiVideoUploadError.downloadURLMissing))
                    return
                }
                
                completion(.success(url.absoluteString))
            }
        }
    }
    
    // MARK: - Local Storage Functions (matching ChattingScreen)
    
    /// Get local videos directory path (matching Android Enclosure/Media/Videos)
    private func getLocalVideosDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videosDir = documentsPath.appendingPathComponent("Enclosure/Media/Videos", isDirectory: true)
        try? FileManager.default.createDirectory(at: videosDir, withIntermediateDirectories: true, attributes: nil)
        return videosDir
    }
    
    /// Save video to local storage (matching Android file saving logic)
    private func saveVideoToLocalStorage(data: Data, fileName: String) {
        let videosDir = getLocalVideosDirectory()
        let fileURL = videosDir.appendingPathComponent(fileName)
        
        // Check if file already exists (matching Android doesFileExist check)
        guard !FileManager.default.fileExists(atPath: fileURL.path) else {
            print("📱 [LOCAL_STORAGE] Video already exists locally: \(fileName)")
            return
        }
        
        do {
            try data.write(to: fileURL, options: .atomic)
            print("📱 [LOCAL_STORAGE] ✅ Saved video to local storage")
            print("📱 [LOCAL_STORAGE] File: \(fileName)")
            print("📱 [LOCAL_STORAGE] File Path: \(fileURL.path)")
            print("📱 [LOCAL_STORAGE] Size: \(data.count) bytes (\(String(format: "%.2f", Double(data.count) / 1024.0 / 1024.0)) MB)")
        } catch {
            print("🚫 [LOCAL_STORAGE] Error saving video to local storage: \(error.localizedDescription)")
        }
    }
    
    // Upload video to Firebase Storage
    // Note: Firebase Storage handles background uploads automatically, so we don't need background tasks
    // Video uploads can take minutes, which exceeds the 30-second background task limit
    private func uploadVideoFileToFirebase(data: Data, remoteFileName: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Use GROUPCHAT constant and group.groupId for storage path
        let storagePath = "\(Constant.GROUPCHAT)/\(group.groupId)/\(remoteFileName)"
        let ref = Storage.storage().reference().child(storagePath)
        let metadata = StorageMetadata()
        metadata.contentType = "video/mp4"
        
        ref.putData(data, metadata: metadata) { _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            ref.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let url = url else {
                    completion(.failure(MultiVideoUploadError.downloadURLMissing))
                    return
                }
                
                completion(.success(url.absoluteString))
            }
        }
    }
}

