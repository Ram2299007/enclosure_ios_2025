//
//  GroupCameraGalleryView.swift
//  Enclosure
//
//  Created by Ram Lohar on 30/04/25.
//

import SwiftUI
import AVFoundation
import Photos
import FirebaseStorage

struct GroupCameraGalleryView: View {
    let group: GroupModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cameraManager = CameraManager()
    @State private var isPhotoMode = true
    @State private var isFlashOn = false
    @State private var isBackCamera = true
    @State private var recordingTime: TimeInterval = 0
    @State private var isRecording = false
    @State private var timer: Timer?
    @State private var captionText = ""
    @State private var selectedAssetIds: Set<String> = []
    @State private var photoAssets: [PHAsset] = []
    @State private var showPermissionText = false
    @State private var bottomSheetHeight: CGFloat = 250 // Increased initial height to show half row naturally
    @State private var isBottomSheetExpanded = false
    @State private var dragOffset: CGFloat = 0
    @State private var isPressed: Bool = false
    @State private var showMultiImagePreview: Bool = false
    @State private var multiImagePreviewCaption: String = ""
    @State private var showMultiVideoPreview: Bool = false
    @State private var multiVideoPreviewCaption: String = ""
    @State private var videoAssets: [PHAsset] = []
    private let imageManager = PHCachingImageManager()
    private let maxBottomSheetHeight: CGFloat = 620 // Full height (matching Android height="620dp")
    private let peekHeight: CGFloat = 250 // Increased peek height to show partial row naturally

    private enum MultiImageUploadError: Error {
        case dataUnavailable
        case downloadURLMissing
    }
    
    // MARK: - Helpers (shared with ChattingScreen)
    private func exportImageAsset(_ asset: PHAsset, fileName: String, completion: @escaping (Result<(data: Data, width: Int, height: Int), Error>) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.version = .current
        
        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
            guard let data = data else {
                completion(.failure(MultiImageUploadError.dataUnavailable))
                return
            }
            
            let image = UIImage(data: data)
            let jpegData = image?.jpegData(compressionQuality: 0.85) ?? data
            let width = image?.cgImage?.width ?? Int(asset.pixelWidth)
            let height = image?.cgImage?.height ?? Int(asset.pixelHeight)
            completion(.success((jpegData, width, height)))
        }
    }
    
    private func uploadImageFileToFirebase(data: Data, remoteFileName: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Use GROUPCHAT constant and group.groupId for storage path
        let storagePath = "\(Constant.GROUPCHAT)/\(group.groupId)/\(remoteFileName)"
        let ref = Storage.storage().reference().child(storagePath)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        DispatchQueue.main.async {
            bgTask = UIApplication.shared.beginBackgroundTask(withName: "UploadImage") {
                UIApplication.shared.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
        }
        let endTask: () -> Void = {
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
        }
        
        ref.putData(data, metadata: metadata) { _, error in
            if let error = error {
                endTask()
                completion(.failure(error))
                return
            }
            
            ref.downloadURL { url, error in
                endTask()
                
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let url = url else {
                    completion(.failure(MultiImageUploadError.downloadURLMissing))
                    return
                }
                
                completion(.success(url.absoluteString))
            }
        }
    }
    
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
        // Android uses a regular weight for the messageBox text
        return .custom("Inter18pt-Regular", size: size)
    }
    
    // Helper function to hide keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-screen camera preview
            CameraPreviewView(cameraManager: cameraManager)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    hideKeyboard()
                }
            
            // Bottom sheet with swipe gesture - full from bottom
            VStack(spacing: 0) {
                Spacer()
                
                bottomSheetView
                    .frame(height: max(bottomSheetHeight + dragOffset, peekHeight))
                    .background(
                        RoundedRectangle(cornerRadius: 40)
                            .fill(Color("chattingMessageBox"))
                            .cornerRadius(40, corners: [.topLeft, .topRight])
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                // Calculate new height directly to prevent flickering
                                let translation = -value.translation.height
                                let newHeight = bottomSheetHeight + translation
                                
                                // Constrain the drag smoothly
                                if newHeight >= peekHeight && newHeight <= maxBottomSheetHeight {
                                    dragOffset = translation
                                } else if newHeight < peekHeight {
                                    dragOffset = peekHeight - bottomSheetHeight
                                } else {
                                    dragOffset = maxBottomSheetHeight - bottomSheetHeight
                                }
                            }
                            .onEnded { value in
                                let finalHeight = bottomSheetHeight + dragOffset
                                let threshold: CGFloat = (peekHeight + maxBottomSheetHeight) / 2
                                
                                // Smooth spring animation
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    if finalHeight > threshold {
                                        bottomSheetHeight = maxBottomSheetHeight
                                        isBottomSheetExpanded = true
                                    } else {
                                        bottomSheetHeight = peekHeight
                                        isBottomSheetExpanded = false
                                    }
                                    dragOffset = 0
                                }
                            }
                    )
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .topLeading) {
            // Back arrow button at top-left (matching editmyProfile.swift)
            Button(action: handleBackTap) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.4))
                        .frame(width: 40, height: 40)
                    
                    if isPressed {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 40, height: 40)
                            .scaleEffect(isPressed ? 1.2 : 1.0)
                            .animation(.easeOut(duration: 0.3), value: isPressed)
                    }
                    
                    Image("leftvector")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 25, height: 18)
                        .foregroundColor(.white)
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { _ in
                        withAnimation {
                            isPressed = false
                        }
                    }
            )
            .buttonStyle(.plain)
            .padding(.leading, 16)
            .padding(.top, 16)
        }
        .onAppear {
            requestCameraPermissionAndSetup()
            requestPhotosAndLoad()
            checkPhotoLibraryPermission()
        }
        .onDisappear {
            cameraManager.stopSession()
            timer?.invalidate()
        }
        .fullScreenCover(isPresented: $showMultiImagePreview, onDismiss: {
            // Reset caption when dialog is dismissed
            multiImagePreviewCaption = ""
        }) {
            MultiImagePreviewDialog(
                selectedAssetIds: $selectedAssetIds,
                photoAssets: photoAssets,
                imageManager: imageManager,
                caption: $multiImagePreviewCaption,
                onSend: { caption in
                    handleMultiImageSend(caption: caption)
                },
                onDismiss: {
                    showMultiImagePreview = false
                }
            )
        }
        .fullScreenCover(isPresented: $showMultiVideoPreview, onDismiss: {
            // Reset caption when dialog is dismissed
            multiVideoPreviewCaption = ""
        }) {
            // Note: MultiVideoPreviewDialog may need group support - using placeholder for now
            Text("Video preview for groups - to be implemented")
                .foregroundColor(.white)
                .background(Color.black)
        }
    }
    
    // MARK: - Bottom Sheet View
    private var bottomSheetView: some View {
        VStack(spacing: 0) {
            // Top controls: Flash, Capture, Switch Camera
            HStack {
                // Flash button
                Button(action: {
                    isFlashOn.toggle()
                    cameraManager.toggleFlash(isOn: isFlashOn)
                }) {
                    ZStack {
                        Circle()
                            .fill(Color("circlebtnhover").opacity(0.1))
                            .frame(width: 40, height: 40)
                        
                        Image(isFlashOn ? "flash_onn" : "flash_off")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .foregroundColor(Color("TextColor"))
                    }
                    .padding(5)
                }
                
                Spacer()
                
                // Capture button
                Button(action: {
                    if isPhotoMode {
                        capturePhoto()
                    } else {
                        toggleVideoRecording()
                    }
                }) {
                    ZStack {
                        // Outer circle with transparent fill and stroke (matching capture_button_background.xml)
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Circle()
                                    .stroke(Color("TextColor"), lineWidth: 3)
                            )
                    }
                    .padding(5)
                }
                
                Spacer()
                
                // Switch camera button
                Button(action: {
                    isBackCamera.toggle()
                    cameraManager.switchCamera()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color("circlebtnhover").opacity(0.1))
                            .frame(width: 40, height: 40)
                        
                        Image("flipcamera")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .foregroundColor(Color("TextColor"))
                    }
                    .padding(5)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .padding(.bottom, 4)
            
            // Photo/Video mode tabs
            HStack(spacing: 2) {
                // Photo tab
                Button(action: {
                    isPhotoMode = true
                }) {
                    Text("Photo")
                        .font(.custom("Inter18pt-Regular", size: 12))
                        .foregroundColor(isPhotoMode ? Color("edittextBg") : Color("TextColor"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(isPhotoMode ? Color("TextColor") : Color.clear)
                        )
                }
                
                // Video tab
                Button(action: {
                    isPhotoMode = false
                }) {
                    Text("Video")
                        .font(.custom("Inter18pt-Regular", size: 12))
                        .foregroundColor(!isPhotoMode ? Color("edittextBg") : Color("TextColor"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(!isPhotoMode ? Color("TextColor") : Color.clear)
                        )
                }
            }
            .padding(2)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color("circlebtnhover").opacity(0.2))
            )
            .padding(.top, 7)
            .padding(.bottom, 7)
            
            // Timer text (for video recording)
            if isRecording {
                Text(formatTime(recordingTime))
                    .font(.custom("Inter18pt-Regular", size: 18))
                    .foregroundColor(Color("TextColor"))
                    .padding(.top, 7)
            }
            
            // Permission text (only visible when expanded)
            if showPermissionText && isBottomSheetExpanded {
                Text("You've given Enclosure permission to access only a select number of photos. Manage")
                    .font(.custom("Inter18pt-Medium", size: 13))
                    .foregroundColor(Color("chtbtncolor"))
                    .padding(10)
                    .lineSpacing(2)
            }
            
            // Gallery grid view - show 4 images when collapsed, full grid when expanded
            if isBottomSheetExpanded {
                // Full gallery grid when expanded
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 2) {
                        ForEach(photoAssets, id: \.localIdentifier) { asset in
                            GalleryAssetThumbnail(
                                asset: asset,
                                imageManager: imageManager,
                                isSelected: selectedAssetIds.contains(asset.localIdentifier)
                            )
                            .padding(.top, 10)
                            .overlay(alignment: .topTrailing) {
                                if selectedAssetIds.contains(asset.localIdentifier) {
                                    Image("multitick")
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                        .padding(10) // padding 10px for multitick
                                }
                            }
                            .onTapGesture {
                                toggleSelection(for: asset)
                            }
                        }
                    }
                    .padding(.top, 10)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
                }
                .frame(minHeight: 360)
            } else {
                // Show only 4 images in grid when collapsed (same height and width)
                LazyVGrid(columns: [GridItem(.fixed(80)), GridItem(.fixed(80)), GridItem(.fixed(80)), GridItem(.fixed(80))], spacing: 2) {
                    ForEach(Array(photoAssets.prefix(4)), id: \.localIdentifier) { asset in
                        GalleryAssetThumbnail(
                            asset: asset,
                            imageManager: imageManager,
                            isSelected: selectedAssetIds.contains(asset.localIdentifier)
                        )
                        .frame(width: 80, height: 80)
                        .overlay(alignment: .topTrailing) {
                            if selectedAssetIds.contains(asset.localIdentifier) {
                                Image("multitick")
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                    .padding(10) // padding 10px for multitick
                            }
                        }
                        .onTapGesture {
                            toggleSelection(for: asset)
                        }
                    }
                }
                .padding(.top, 10)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
            
            // Caption bar + Send button (only visible when expanded)
            if isBottomSheetExpanded {
                HStack(spacing: 0) {
                    // Caption input container (matching messageBox design)
                    HStack(spacing: 0) {
                        // Message input field container - layout_weight="1"
                        VStack(alignment: .leading, spacing: 0) {
                            TextField("Add Caption", text: $captionText, axis: .vertical)
                                .font(messageInputFont)
                                .foregroundColor(Color("black_white_cross"))
                                .lineLimit(4)
                                .frame(maxWidth: 180, alignment: .leading)
                                .padding(.leading, 10) // start padding 10px
                                .padding(.trailing, 20)
                                .padding(.top, 5)
                                .padding(.bottom, 5)
                                .background(Color.clear)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 50) // Match send button height (50dp)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color("circlebtnhover")) // match Android backgroundTint on message_box_bg
                    )
                    .padding(.leading, 10)
                    .padding(.trailing, 5)
                    
                    // Send button group (matching sendGrpLyt)
                    ZStack(alignment: .topTrailing) {
                        VStack(spacing: 0) {
                            Button(action: {
                                handleSend()
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(selectedAssetIds.count > 0 ? Color(hex: Constant.themeColor) : Color(hex: Constant.themeColor))
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
                            .disabled(selectedAssetIds.count == 0)
                            .opacity(selectedAssetIds.count > 0 ? 1.0 : 0.5)
                        }
                        
                        // Small counter badge (Android multiSelectSmallCounterText)
                        if selectedAssetIds.count > 0 {
                            Text("\(selectedAssetIds.count)")
                                .font(.custom("Inter18pt-Bold", size: 12))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(
                                    Circle()
                                        .fill(Color(hex: Constant.themeColor)) // match Android counter tint
                                )
                                .offset(x: -13, y: -30) // lift badge above send button with extra right margin
                        }
                    }
                    .padding(.horizontal, 5)
                }
                .padding(.bottom, 50)
            }
        }
    }
    
    // MARK: - Helper Functions
    private func capturePhoto() {
        print("GroupCameraGalleryView: === CAPTURE PHOTO CALLED ===")
        cameraManager.capturePhoto { image in
            // Handle captured photo
            if let image = image {
                print("GroupCameraGalleryView: Photo captured successfully, size: \(image.size)")
                // Save photo to photo library and get PHAsset
                savePhotoToLibrary(image: image)
            } else {
                print("GroupCameraGalleryView: ERROR - No image returned from capture")
            }
        }
    }
    
    private func savePhotoToLibrary(image: UIImage) {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if currentStatus == .notDetermined {
            AndroidStylePermissionManager.shared.requestPermissionWithDialogFromTopVC(for: .photos) { granted in
                DispatchQueue.main.async {
                    if granted { self.performSavePhoto(image: image) }
                    else { self.showPreviewWithImage(image: image) }
                }
            }
        } else if currentStatus == .authorized || currentStatus == .limited {
            performSavePhoto(image: image)
        } else {
            DispatchQueue.main.async { self.showPreviewWithImage(image: image) }
        }
    }
    
    private func performSavePhoto(image: UIImage) {
        var placeholder: PHObjectPlaceholder?
        
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
            placeholder = request.placeholderForCreatedAsset
        }) { success, error in
            if let error = error {
                print("GroupCameraGalleryView: Error saving photo: \(error.localizedDescription)")
                // Show preview with UIImage directly if save fails
                DispatchQueue.main.async {
                    self.showPreviewWithImage(image: image)
                }
                return
            }
            
            guard success, let placeholderId = placeholder?.localIdentifier else {
                print("GroupCameraGalleryView: Failed to save photo or get placeholder")
                DispatchQueue.main.async {
                    self.showPreviewWithImage(image: image)
                }
                return
            }
            
            // Wait a moment for the asset to be fully created, then fetch using placeholder ID
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [placeholderId], options: nil)
                
                if let newAsset = fetchResult.firstObject {
                    DispatchQueue.main.async {
                        print("GroupCameraGalleryView: Photo saved successfully, asset ID: \(newAsset.localIdentifier)")
                        
                        // Add to photoAssets if not already there
                        if !self.photoAssets.contains(where: { $0.localIdentifier == newAsset.localIdentifier }) {
                            self.photoAssets.insert(newAsset, at: 0) // Insert at beginning
                        }
                        
                        // Select the captured image
                        self.selectedAssetIds = [newAsset.localIdentifier]
                        
                        // Set caption (empty initially)
                        self.multiImagePreviewCaption = self.captionText
                        
                        // Show preview dialog
                        self.showMultiImagePreview = true
                    }
                } else {
                    print("GroupCameraGalleryView: Could not fetch saved asset with placeholder ID: \(placeholderId)")
                    // Try fetching by creation date as fallback
                    let fetchOptions = PHFetchOptions()
                    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                    fetchOptions.fetchLimit = 1
                    
                    let recentAssets = PHAsset.fetchAssets(with: fetchOptions)
                    if let recentAsset = recentAssets.firstObject {
                        DispatchQueue.main.async {
                            if !self.photoAssets.contains(where: { $0.localIdentifier == recentAsset.localIdentifier }) {
                                self.photoAssets.insert(recentAsset, at: 0)
                            }
                            
                            self.selectedAssetIds = [recentAsset.localIdentifier]
                            self.multiImagePreviewCaption = self.captionText
                            self.showMultiImagePreview = true
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.showPreviewWithImage(image: image)
                        }
                    }
                }
            }
        }
    }
    
    private func showPreviewWithImage(image: UIImage) {
        // Fallback: Try to save again after a short delay
        print("GroupCameraGalleryView: Retrying save after delay...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.performSavePhoto(image: image)
        }
    }
    
    private func toggleVideoRecording() {
        if isRecording {
            stopVideoRecording()
        } else {
            startVideoRecording()
        }
    }
    
    private func startVideoRecording() {
        isRecording = true
        recordingTime = 0
        cameraManager.startVideoRecording()
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingTime += 0.1
            if recordingTime >= 60.0 { // Max 1 minute
                stopVideoRecording()
            }
        }
    }
    
    private func stopVideoRecording() {
        isRecording = false
        timer?.invalidate()
        cameraManager.stopVideoRecording { url in
            if let url = url {
                // Handle recorded video - save to photo library and show preview
                print("GroupCameraGalleryView: Video recorded: \(url)")
                saveVideoToLibrary(url: url)
            }
        }
    }
    
    private func saveVideoToLibrary(url: URL) {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if currentStatus == .notDetermined {
            AndroidStylePermissionManager.shared.requestPermissionWithDialogFromTopVC(for: .photos) { granted in
                DispatchQueue.main.async {
                    if granted { self.performSaveVideo(url: url) }
                }
            }
        } else if currentStatus == .authorized || currentStatus == .limited {
            performSaveVideo(url: url)
        }
    }
    
    private func performSaveVideo(url: URL) {
        var placeholder: PHObjectPlaceholder?
        
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            placeholder = request?.placeholderForCreatedAsset
        }) { success, error in
            if let error = error {
                print("GroupCameraGalleryView: Error saving video: \(error.localizedDescription)")
                return
            }
            
            guard success, let placeholderId = placeholder?.localIdentifier else {
                print("GroupCameraGalleryView: Failed to save video or get placeholder")
                return
            }
            
            // Wait a moment for the asset to be fully created, then fetch using placeholder ID
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [placeholderId], options: nil)
                
                if let newAsset = fetchResult.firstObject {
                    DispatchQueue.main.async {
                        print("GroupCameraGalleryView: Video saved successfully, asset ID: \(newAsset.localIdentifier)")
                        
                        // Add to videoAssets if not already there
                        if !self.videoAssets.contains(where: { $0.localIdentifier == newAsset.localIdentifier }) {
                            self.videoAssets.insert(newAsset, at: 0)
                        }
                        
                        // Select the recorded video
                        self.selectedAssetIds = [newAsset.localIdentifier]
                        
                        // Set caption from GroupCameraGalleryView
                        self.multiVideoPreviewCaption = self.captionText
                        
                        // Show preview dialog
                        self.showMultiVideoPreview = true
                    }
                }
            }
        }
    }
    
    // MARK: - Haptics
    private func triggerLightHapticIfAvailable() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
    
    // MARK: - Handle Multi-Video Send (matching Android upload logic)
    private func handleMultiVideoSend(caption: String) {
        print("GroupCameraGalleryView: === MULTI-VIDEO SEND ===")
        print("GroupCameraGalleryView: Selected videos count: \(selectedAssetIds.count)")
        print("GroupCameraGalleryView: Caption: '\(caption)'")
        
        // Not implemented yet (parity work pending)
        showMultiVideoPreview = false
        selectedAssetIds.removeAll()
        captionText = ""
        Constant.showToast(message: "Video upload from camera is not yet supported on iOS.")
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func toggleSelection(for asset: PHAsset) {
        if selectedAssetIds.contains(asset.localIdentifier) {
            selectedAssetIds.remove(asset.localIdentifier)
            // Auto-collapse bottom sheet when selection count becomes 0
            if selectedAssetIds.count == 0 && isBottomSheetExpanded {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    bottomSheetHeight = peekHeight
                    isBottomSheetExpanded = false
                }
            }
        } else {
            selectedAssetIds.insert(asset.localIdentifier)
            // Auto-expand bottom sheet when image is selected
            if !isBottomSheetExpanded {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    bottomSheetHeight = maxBottomSheetHeight
                    isBottomSheetExpanded = true
                }
            }
        }
    }
    
    private func handleSend() {
        // Check if images are selected
        guard !selectedAssetIds.isEmpty else { return }
        
        print("GroupCameraGalleryView: === SEND BUTTON CLICKED ===")
        print("GroupCameraGalleryView: Selected images count: \(selectedAssetIds.count)")
        print("GroupCameraGalleryView: Caption from bottom sheet: '\(captionText)'")
        
        // Light haptic feedback
        triggerLightHapticIfAvailable()
        
        // Set caption from GroupCameraGalleryView bottom sheet to preview dialog
        multiImagePreviewCaption = captionText
        
        // Show full-screen dialog for multi-image preview
        showMultiImagePreview = true
    }
    
    // MARK: - Handle Multi-Image Send (matching Android upload logic)
    private func handleMultiImageSend(caption: String) {
        print("GroupCameraGalleryView: === MULTI-IMAGE SEND ===")
        print("GroupCameraGalleryView: Selected images count: \(selectedAssetIds.count)")
        print("GroupCameraGalleryView: Caption received from dialog: '\(caption)'")
        
        let selectedAssets = photoAssets.filter { selectedAssetIds.contains($0.localIdentifier) }
        guard !selectedAssets.isEmpty else {
            print("GroupCameraGalleryView: No assets selected, returning")
            return
        }
        
        // Close the preview dialog
        showMultiImagePreview = false
        
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
        let modelId = UUID().uuidString
        
        let dispatchGroup = DispatchGroup()
        let lockQueue = DispatchQueue(label: "com.enclosure.groupCamera.multiImage.lock")
        
        struct UploadedImageResult {
            let index: Int
            let downloadURL: String
            let fileName: String
            let width: Int
            let height: Int
        }
        
        var uploadResults: [UploadedImageResult] = []
        var uploadErrors: [Error] = []
        
        for (index, asset) in selectedAssets.enumerated() {
            dispatchGroup.enter()
            let remoteFileName = "\(modelId)_\(index).jpg"
            
            exportImageAsset(asset, fileName: remoteFileName) { exportResult in
                switch exportResult {
                case .failure(let error):
                    lockQueue.sync { uploadErrors.append(error) }
                    dispatchGroup.leave()
                case .success(let export):
                    self.uploadImageFileToFirebase(data: export.data, remoteFileName: remoteFileName) { uploadResult in
                        switch uploadResult {
                        case .failure(let error):
                            lockQueue.sync { uploadErrors.append(error) }
                        case .success(let downloadURL):
                            let result = UploadedImageResult(
                                index: index,
                                downloadURL: downloadURL,
                                fileName: remoteFileName,
                                width: export.width,
                                height: export.height
                            )
                            lockQueue.sync { uploadResults.append(result) }
                        }
                        dispatchGroup.leave()
                    }
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            if uploadResults.isEmpty {
                print("❌ [GROUP_CAMERA_MULTI_IMAGE] Upload failed - no results")
                Constant.showToast(message: "Unable to upload images. Please try again.")
                return
            }
            
            if !uploadErrors.isEmpty {
                print("⚠️ [GROUP_CAMERA_MULTI_IMAGE] Some uploads failed: \(uploadErrors.count) errors")
            }
            
            let sortedResults = uploadResults.sorted { $0.index < $1.index }
            let selectionBunchModels = sortedResults.map { SelectionBunchModel(imgUrl: $0.downloadURL, fileName: $0.fileName) }
            
            guard let first = sortedResults.first else {
                Constant.showToast(message: "Unable to prepare images. Please try again.")
                return
            }
            
            let aspectRatioValue: String
            if first.height > 0 {
                aspectRatioValue = String(format: "%.2f", Double(first.width) / Double(first.height))
            } else {
                aspectRatioValue = ""
            }
            
            print("GroupCameraGalleryView: Creating ChatMessage with caption: '\(trimmedCaption)'")
            // Create message with groupName and receiverId set to groupId
            let newMessage = ChatMessage(
                id: modelId,
                uid: senderId,
                message: "",
                time: currentDateTimeString,
                document: first.downloadURL,
                dataType: Constant.img,
                fileExtension: "jpg",
                name: nil,
                phone: nil,
                micPhoto: micPhoto,
                miceTiming: nil,
                userName: userName,
                receiverId: groupId, // Use groupId as receiverId for groups
                replytextData: nil,
                replyKey: nil,
                replyType: nil,
                replyOldData: nil,
                replyCrtPostion: nil,
                forwaredKey: nil,
                groupName: group.name, // Set group name
                docSize: nil,
                fileName: first.fileName,
                thumbnail: nil,
                fileNameThumbnail: nil,
                caption: trimmedCaption,
                notification: 1,
                currentDate: currentDateString,
                emojiModel: [EmojiModel(name: "", emoji: "")],
                emojiCount: nil,
                timestamp: timestamp,
                imageWidth: "\(first.width)",
                imageHeight: "\(first.height)",
                aspectRatio: aspectRatioValue,
                selectionCount: "\(sortedResults.count)",
                selectionBunch: selectionBunchModels,
                receiverLoader: 0
            )
            
            // Clear selected assets after sending
            self.selectedAssetIds.removeAll()
            self.captionText = ""
            
            // Upload message
            let userFTokenKey = UserDefaults.standard.string(forKey: Constant.FCM_TOKEN) ?? ""
            
            MessageUploadService.shared.uploadMessage(
                model: newMessage,
                filePath: nil,
                userFTokenKey: userFTokenKey
            ) { success, errorMessage in
                if success {
                    print("✅ [GROUP_CAMERA_MULTI_IMAGE] Uploaded \(sortedResults.count) images for modelId=\(modelId)")
                } else {
                    print("❌ [GROUP_CAMERA_MULTI_IMAGE] Upload error: \(errorMessage ?? "Unknown error")")
                    Constant.showToast(message: "Failed to send images. Please try again.")
                }
            }
            
            // Dismiss keyboard first to avoid constraint warnings, then dismiss view
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            
            // Small delay to let keyboard dismiss animation complete before dismissing view
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.dismiss()
            }
        }
    }
    
    private func requestCameraPermissionAndSetup() {
        AndroidStylePermissionManager.shared.requestPermissionWithDialogFromTopVC(for: .camera) { granted in
            DispatchQueue.main.async {
                if granted {
                    cameraManager.setupCamera(isBackCamera: isBackCamera)
                } else {
                    print("Camera permission denied")
                }
            }
        }
    }
    
    private func requestPhotosAndLoad() {
        AndroidStylePermissionManager.shared.requestPermissionWithDialogFromTopVC(for: .photos) { granted in
            DispatchQueue.main.async {
                if granted { loadPhotos() }
            }
        }
    }
    
    private func loadPhotos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 100
        
        let assets = PHAsset.fetchAssets(with: fetchOptions)
        var assetList: [PHAsset] = []
        
        assets.enumerateObjects { asset, _, _ in
            assetList.append(asset)
        }
        
        DispatchQueue.main.async {
            photoAssets = assetList
        }
    }
    
    private func checkPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .limited {
            showPermissionText = true
        }
    }
    
    // MARK: - Back Button Handler (matching editmyProfile.swift)
    private func handleBackTap() {
        withAnimation {
            isPressed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            dismiss()
            isPressed = false
        }
    }
}

