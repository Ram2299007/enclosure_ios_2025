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
import FirebaseStorage
import FirebaseDatabase

// MARK: - Multi-Video Preview Dialog (matching MultiImagePreviewDialog design)
struct MultiVideoPreviewDialog: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Binding var selectedAssetIds: Set<String>
    let videoAssets: [PHAsset]
    let imageManager: PHCachingImageManager
    @Binding var caption: String
    let contact: UserActiveContactModel
    let onSend: (String) -> Void
    let onDismiss: () -> Void
    let onMessageAdded: ((ChatMessage) -> Void)? = nil // Callback to add message immediately to list (optional, defaults to nil)
    
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
                            // Light haptic feedback (guarded to avoid errors on unsupported devices)
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.prepare()
                            generator.impactOccurred()
                            pauseAllVideos()
                            
                            // Dismiss keyboard first to avoid constraint warnings
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            
                            let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
                            print("MultiVideoPreviewDialog: Send button clicked - Caption: '\(trimmedCaption)' (length: \(trimmedCaption.count))")
                            
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
                .padding(.bottom, keyboardHeight > 0 ? keyboardHeight - 20 : 10)
                .background(Color.black)
            }
        }
        .onAppear {
            print("MultiVideoPreviewDialog: onAppear - Initial caption: '\(caption)' (length: \(caption.count))")
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
    
    // MARK: - Video Upload Functions (matching Android sendMultipleVideos)
    
    enum MultiVideoUploadError: Error {
        case dataUnavailable
        case thumbnailGenerationFailed
        case downloadURLMissing
        case uploadFailed(String)
    }
    
    /// Check if message exists in Firebase and stop progress bar (matching Android behavior)
    private func checkMessageInFirebaseAndStopProgress(messageId: String, receiverUid: String) {
        let senderId = Constant.SenderIdMy
        let receiverRoom = receiverUid + senderId
        let database = Database.database().reference()
        let messageRef = database.child(Constant.CHAT).child(receiverRoom).child(messageId)
        
        print("🔍 [ProgressBar] Checking if video message exists in Firebase: \(messageId)")
        
        // Check if message exists in Firebase (matching Android addListenerForSingleValueEvent)
        messageRef.observeSingleEvent(of: .value) { snapshot in
            if snapshot.exists() {
                print("✅ [ProgressBar] Video message confirmed in Firebase, stopping animation and updating receiverLoader")
                
                // Remove from pending table (matching Android removePendingMessage)
                let removed = DatabaseHelper.shared.removePendingMessage(modelId: messageId, receiverUid: receiverUid)
                if removed {
                    print("✅ [PendingMessages] Removed pending video message from SQLite: \(messageId)")
                }
                
                // Update receiverLoader to 1 to stop progress bar (matching Android setIndeterminate(false))
                let receiverLoaderRef = database.child(Constant.CHAT).child(receiverRoom).child(messageId).child("receiverLoader")
                receiverLoaderRef.setValue(1) { error, _ in
                    if let error = error {
                        print("❌ [ProgressBar] Error updating receiverLoader: \(error.localizedDescription)")
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
        print("MultiVideoPreviewDialog: === MULTI-VIDEO SEND ===")
        print("MultiVideoPreviewDialog: Selected videos count: \(selectedAssets.count)")
        print("MultiVideoPreviewDialog: Caption: '\(caption)'")
        
        guard !selectedAssets.isEmpty else {
            print("MultiVideoPreviewDialog: No videos selected, returning")
            return
        }
        
        // Close the preview dialog
        onDismiss()
        
        let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let receiverUid = contact.uid
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
        let lockQueue = DispatchQueue(label: "com.enclosure.multiVideoUpload.lock")
        
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
                print("❌ [MULTI_VIDEO] Upload failed - no results")
                Constant.showToast(message: "Unable to upload videos. Please try again.")
                return
            }
            
            if !uploadErrors.isEmpty {
                print("⚠️ [MULTI_VIDEO] Some uploads failed: \(uploadErrors.count) errors")
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
                
                print("MultiVideoPreviewDialog: Creating ChatMessage \(result.index + 1)/\(sortedResults.count) with caption: '\(trimmedCaption)'")
                let newMessage = ChatMessage(
                    id: videoModelId,
                    uid: senderId,
                    message: "",
                    time: currentDateTimeString,
                    document: result.videoDownloadURL,
                    dataType: Constant.video,
                    fileExtension: "mp4",
                    name: nil,
                    phone: nil,
                    micPhoto: micPhoto,
                    miceTiming: nil,
                    userName: userName,
                    receiverId: receiverUid,
                    replytextData: nil,
                    replyKey: nil,
                    replyType: nil,
                    replyOldData: nil,
                    replyCrtPostion: nil,
                    forwaredKey: nil,
                    groupName: nil,
                    docSize: nil,
                    fileName: result.videoFileName,
                    thumbnail: result.thumbnailDownloadURL,
                    fileNameThumbnail: result.thumbnailFileName,
                    caption: trimmedCaption,
                    notification: 1,
                    currentDate: currentDateString,
                    emojiModel: [EmojiModel(name: "", emoji: "")],
                    emojiCount: nil,
                    timestamp: timestamp,
                    imageWidth: "\(result.width)",
                    imageHeight: "\(result.height)",
                    aspectRatio: aspectRatioValue,
                    selectionCount: "1",
                    selectionBunch: nil,
                    receiverLoader: 0
                )
                print("MultiVideoPreviewDialog: ChatMessage created with caption: '\(newMessage.caption ?? "nil")'")
                
                // Store message in SQLite pending table before upload (matching Android insertPendingMessage)
                DatabaseHelper.shared.insertPendingMessage(newMessage)
                print("✅ [PendingMessages] Video message stored in pending table: \(videoModelId)")
                
                // Add message to UI immediately with progress bar (matching Android messageList.add + itemAdd)
                onMessageAdded?(newMessage)
                
                let userFTokenKey = UserDefaults.standard.string(forKey: Constant.FCM_TOKEN) ?? ""
                
                MessageUploadService.shared.uploadMessage(
                    model: newMessage,
                    filePath: nil,
                    userFTokenKey: userFTokenKey,
                    deviceType: "2"
                ) { success, errorMessage in
                    if success {
                        print("✅ [MULTI_VIDEO] Uploaded video \(result.index + 1)/\(sortedResults.count) for modelId=\(videoModelId)")
                    } else {
                        print("❌ [MULTI_VIDEO] Upload error: \(errorMessage ?? "Unknown error")")
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
        let storagePath = "\(Constant.CHAT)/\(Constant.SenderIdMy)_\(contact.uid)/\(remoteFileName)"
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
    
    // Upload video to Firebase Storage
    // Note: Firebase Storage handles background uploads automatically, so we don't need background tasks
    // Video uploads can take minutes, which exceeds the 30-second background task limit
    private func uploadVideoFileToFirebase(data: Data, remoteFileName: String, completion: @escaping (Result<String, Error>) -> Void) {
        let storagePath = "\(Constant.CHAT)/\(Constant.SenderIdMy)_\(contact.uid)/\(remoteFileName)"
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

