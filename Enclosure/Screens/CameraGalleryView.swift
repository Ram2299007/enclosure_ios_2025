//
//  CameraGalleryView.swift
//  Enclosure
//
//  Created by Ram Lohar on 11/12/25.
//

import SwiftUI
import AVFoundation
import Photos

struct CameraGalleryView: View {
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
    private let imageManager = PHCachingImageManager()
    private let maxBottomSheetHeight: CGFloat = 620 // Full height (matching Android height="620dp")
    private let peekHeight: CGFloat = 250 // Increased peek height to show partial row naturally
    
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
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-screen camera preview
            CameraPreviewView(cameraManager: cameraManager)
                .ignoresSafeArea()
            
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
                        
                        // Inner camera icon (70dp, visibility gone in Android but kept for reference)
                        // Image("camera")
                        //     .resizable()
                        //     .scaledToFit()
                        //     .frame(width: 70, height: 70)
                        //     .hidden()
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
        print("CameraGalleryView: === CAPTURE PHOTO CALLED ===")
        cameraManager.capturePhoto { image in
            // Handle captured photo
            if let image = image {
                print("CameraGalleryView: Photo captured successfully, size: \(image.size)")
                // Save photo to photo library and get PHAsset
                savePhotoToLibrary(image: image)
            } else {
                print("CameraGalleryView: ERROR - No image returned from capture")
            }
        }
    }
    
    private func savePhotoToLibrary(image: UIImage) {
        // Check current authorization status
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        if currentStatus == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                if status == .authorized || status == .limited {
                    self.performSavePhoto(image: image)
                } else {
                    print("CameraGalleryView: Photo library permission denied")
                    // Show preview with UIImage directly if permission denied
                    DispatchQueue.main.async {
                        self.showPreviewWithImage(image: image)
                    }
                }
            }
        } else if currentStatus == .authorized || currentStatus == .limited {
            performSavePhoto(image: image)
        } else {
            print("CameraGalleryView: Photo library permission not available")
            // Show preview with UIImage directly if permission not available
            DispatchQueue.main.async {
                self.showPreviewWithImage(image: image)
            }
        }
    }
    
    private func performSavePhoto(image: UIImage) {
        var placeholder: PHObjectPlaceholder?
        
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
            placeholder = request.placeholderForCreatedAsset
        }) { success, error in
            if let error = error {
                print("CameraGalleryView: Error saving photo: \(error.localizedDescription)")
                // Show preview with UIImage directly if save fails
                DispatchQueue.main.async {
                    self.showPreviewWithImage(image: image)
                }
                return
            }
            
            guard success, let placeholderId = placeholder?.localIdentifier else {
                print("CameraGalleryView: Failed to save photo or get placeholder")
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
                        print("CameraGalleryView: Photo saved successfully, asset ID: \(newAsset.localIdentifier)")
                        print("CameraGalleryView: Asset creation date: \(newAsset.creationDate?.description ?? "nil")")
                        
                        // Add to photoAssets if not already there
                        if !self.photoAssets.contains(where: { $0.localIdentifier == newAsset.localIdentifier }) {
                            self.photoAssets.insert(newAsset, at: 0) // Insert at beginning
                            print("CameraGalleryView: Added asset to photoAssets, count: \(self.photoAssets.count)")
                        }
                        
                        // Select the captured image
                        self.selectedAssetIds = [newAsset.localIdentifier]
                        print("CameraGalleryView: Selected asset ID: \(newAsset.localIdentifier)")
                        
                        // Set caption (empty initially)
                        self.multiImagePreviewCaption = self.captionText
                        print("CameraGalleryView: Caption set: '\(self.multiImagePreviewCaption)'")
                        
                        // Show preview dialog
                        print("CameraGalleryView: Showing preview dialog...")
                        self.showMultiImagePreview = true
                    }
                } else {
                    print("CameraGalleryView: Could not fetch saved asset with placeholder ID: \(placeholderId)")
                    // Try fetching by creation date as fallback
                    let fetchOptions = PHFetchOptions()
                    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                    fetchOptions.fetchLimit = 1
                    
                    let recentAssets = PHAsset.fetchAssets(with: fetchOptions)
                    if let recentAsset = recentAssets.firstObject {
                        DispatchQueue.main.async {
                            print("CameraGalleryView: Found asset by creation date, ID: \(recentAsset.localIdentifier)")
                            
                            if !self.photoAssets.contains(where: { $0.localIdentifier == recentAsset.localIdentifier }) {
                                self.photoAssets.insert(recentAsset, at: 0)
                            }
                            
                            self.selectedAssetIds = [recentAsset.localIdentifier]
                            self.multiImagePreviewCaption = self.captionText
                            self.showMultiImagePreview = true
                        }
                    } else {
                        print("CameraGalleryView: Could not find asset by creation date either")
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
        // This handles cases where the photo library might need a moment to process
        print("CameraGalleryView: Retrying save after delay...")
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
                // Handle recorded video
                print("Video recorded: \(url)")
            }
        }
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
        
        print("CameraGalleryView: === SEND BUTTON CLICKED ===")
        print("CameraGalleryView: Selected images count: \(selectedAssetIds.count)")
        print("CameraGalleryView: Caption: '\(captionText)'")
        
        // Light haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Set caption from CameraGalleryView
        multiImagePreviewCaption = captionText
        
        // Show full-screen dialog for multi-image preview (matching Android setupMultiImagePreviewWithData)
        showMultiImagePreview = true
    }
    
    // MARK: - Handle Multi-Image Send (matching Android upload logic)
    private func handleMultiImageSend(caption: String) {
        print("CameraGalleryView: === MULTI-IMAGE SEND ===")
        print("CameraGalleryView: Selected images count: \(selectedAssetIds.count)")
        print("CameraGalleryView: Caption: '\(caption)'")
        
        // Get selected assets from photoAssets
        let selectedAssets = photoAssets.filter { selectedAssetIds.contains($0.localIdentifier) }
        
        guard !selectedAssets.isEmpty else {
            print("CameraGalleryView: No assets selected, returning")
            return
        }
        
        // Close the preview dialog
        showMultiImagePreview = false
        
        // Clear selected assets after sending
        selectedAssetIds.removeAll()
        captionText = ""
        
        // TODO: Process and upload selected images with caption
        // This should match Android's upload logic for multi-image messages
        // For now, we'll just log the action
        print("CameraGalleryView: Would upload \(selectedAssets.count) images with caption: '\(caption)'")
        
        // TODO: Implement actual upload logic using MessageUploadService or similar
        // Similar to how single images are uploaded
    }
    
    private func requestCameraPermissionAndSetup() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
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
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized || status == .limited {
                DispatchQueue.main.async {
                    loadPhotos()
                }
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

// MARK: - Camera Manager
class CameraManager: ObservableObject {
    @Published var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureMovieFileOutput?
    private var photoOutput: AVCapturePhotoOutput?
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private var isFlashOn = false
    private var photoCaptureDelegate: PhotoCaptureDelegate? // Retain delegate until capture completes
    
    func setupCamera(isBackCamera: Bool) {
        currentCameraPosition = isBackCamera ? .back : .front
        
        let session = AVCaptureSession()
        // Use photo preset for 4:3 aspect ratio (matching Android camera aspect ratio)
        session.sessionPreset = .photo
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            return
        }
        
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        }
        
        // Photo output
        let photoOut = AVCapturePhotoOutput()
        if session.canAddOutput(photoOut) {
            session.addOutput(photoOut)
            photoOutput = photoOut
            print("CameraManager: Photo output added successfully")
        } else {
            print("CameraManager: ERROR - Cannot add photo output")
        }
        
        // Video output (only add if needed for video recording)
        // Note: Having both outputs can sometimes cause issues, so we'll add video output conditionally
        // For now, we'll skip video output to avoid conflicts with photo capture
        // Video output can be added dynamically when needed for video recording
        // let videoOut = AVCaptureMovieFileOutput()
        // if session.canAddOutput(videoOut) {
        //     session.addOutput(videoOut)
        //     videoOutput = videoOut
        //     print("CameraManager: Video output added successfully")
        // } else {
        //     print("CameraManager: WARNING - Cannot add video output")
        // }
        
        captureSession = session
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
            print("CameraManager: Capture session started, isRunning: \(session.isRunning)")
        }
    }
    
    func switchCamera() {
        guard let session = captureSession else { return }
        
        session.beginConfiguration()
        
        // Remove existing inputs
        session.inputs.forEach { session.removeInput($0) }
        
        currentCameraPosition = currentCameraPosition == .back ? .front : .back
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            session.commitConfiguration()
            return
        }
        
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        }
        
        session.commitConfiguration()
    }
    
    func toggleFlash(isOn: Bool) {
        isFlashOn = isOn
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition),
              device.hasFlash else { return }
        
        do {
            try device.lockForConfiguration()
            device.torchMode = isOn ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Error toggling flash: \(error)")
        }
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        print("CameraManager: capturePhoto called")
        guard let photoOutput = photoOutput else {
            print("CameraManager: ERROR - photoOutput is nil")
            completion(nil)
            return
        }
        
        guard let captureSession = captureSession, captureSession.isRunning else {
            print("CameraManager: ERROR - Capture session is not running")
            completion(nil)
            return
        }
        
        print("CameraManager: photoOutput exists, creating settings...")
        print("CameraManager: Session isRunning: \(captureSession.isRunning)")
        print("CameraManager: Session inputs: \(captureSession.inputs.count)")
        print("CameraManager: Session outputs: \(captureSession.outputs.count)")
        
        // Create photo settings
        let settings = AVCapturePhotoSettings()
        
        // Enable high-resolution capture if available
        if photoOutput.isHighResolutionCaptureEnabled {
            settings.isHighResolutionPhotoEnabled = true
            print("CameraManager: High resolution enabled")
        }
        
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition),
           device.hasFlash {
            settings.flashMode = isFlashOn ? .on : .off
            print("CameraManager: Flash mode set to: \(isFlashOn ? "on" : "off")")
        }
        
        // Retain the delegate to prevent deallocation
        let isFront = currentCameraPosition == .front
        let delegate = PhotoCaptureDelegate(isFrontCamera: isFront) { [weak self] image in
            print("CameraManager: Delegate completion called")
            // Clear the retained delegate after completion
            self?.photoCaptureDelegate = nil
            completion(image)
        }
        photoCaptureDelegate = delegate
        
        print("CameraManager: Calling capturePhoto with delegate...")
        // Capture photo - should be called from main thread
        photoOutput.capturePhoto(with: settings, delegate: delegate)
        print("CameraManager: capturePhoto call completed")
    }
    
    func startVideoRecording() {
        guard let videoOutput = videoOutput else { return }
        
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("video_\(UUID().uuidString).mov")
        videoOutput.startRecording(to: url, recordingDelegate: VideoRecordingDelegate())
    }
    
    func stopVideoRecording(completion: @escaping (URL?) -> Void) {
        videoOutput?.stopRecording()
        // Completion handled in delegate
    }
    
    func stopSession() {
        captureSession?.stopRunning()
    }
}

// MARK: - Camera Preview View
struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        attachPreviewLayer(to: view)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if cameraManager.previewLayer == nil {
            attachPreviewLayer(to: uiView)
        } else {
            cameraManager.previewLayer?.frame = uiView.bounds
        }
    }
    
    private func attachPreviewLayer(to view: UIView) {
        guard let session = cameraManager.captureSession else { return }
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        previewLayer.frame = view.bounds
        cameraManager.previewLayer = previewLayer
    }
}

// MARK: - Photo Capture Delegate
class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (UIImage?) -> Void
    private let isFrontCamera: Bool
    
    init(isFrontCamera: Bool, completion: @escaping (UIImage?) -> Void) {
        print("PhotoCaptureDelegate: Initialized, isFrontCamera: \(isFrontCamera)")
        self.isFrontCamera = isFrontCamera
        self.completion = completion
        super.init()
    }
    
    // iOS 11+ method with error parameter
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print("PhotoCaptureDelegate: didFinishProcessingPhoto called (with error parameter)")
        handlePhoto(photo: photo, error: error)
    }
    
    // Alternative method that might be called in some iOS versions
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto) {
        print("PhotoCaptureDelegate: didFinishProcessingPhoto called (without error parameter)")
        handlePhoto(photo: photo, error: nil)
    }
    
    private func handlePhoto(photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("PhotoCaptureDelegate: ERROR - \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.completion(nil)
            }
            return
        }
        
        print("PhotoCaptureDelegate: Processing photo data...")
        guard let imageData = photo.fileDataRepresentation() else {
            print("PhotoCaptureDelegate: ERROR - No image data from fileDataRepresentation()")
            // Try using cgImageRepresentation() as fallback
            if let cgImage = photo.cgImageRepresentation() {
                var image = UIImage(cgImage: cgImage)
                // Apply 4:3 crop and mirror if front camera
                image = processImage(image: image)
                print("PhotoCaptureDelegate: Image created from CGImage, size: \(image.size)")
                DispatchQueue.main.async {
                    self.completion(image)
                }
            } else {
                print("PhotoCaptureDelegate: ERROR - Could not get image from either method")
                DispatchQueue.main.async {
                    self.completion(nil)
                }
            }
            return
        }
        
        guard var image = UIImage(data: imageData) else {
            print("PhotoCaptureDelegate: ERROR - Could not create UIImage from data, data size: \(imageData.count)")
            DispatchQueue.main.async {
                self.completion(nil)
            }
            return
        }
        
        // Process image: crop to 4:3 and mirror if front camera
        image = processImage(image: image)
        
        print("PhotoCaptureDelegate: Image processed successfully, final size: \(image.size)")
        DispatchQueue.main.async {
            self.completion(image)
        }
    }
    
    private func processImage(image: UIImage) -> UIImage {
        var processedImage = image
        
        // For front camera, mirror first before cropping to ensure proper centering
        if isFrontCamera {
            processedImage = flipImageHorizontally(image: processedImage)
            print("PhotoCaptureDelegate: Image mirrored for front camera")
        }
        
        // Crop to 4:3 aspect ratio (after mirroring for front camera)
        let targetAspectRatio: CGFloat = 4.0 / 3.0
        let imageSize = processedImage.size
        let imageAspectRatio = imageSize.width / imageSize.height
        
        var cropRect: CGRect
        
        if imageAspectRatio > targetAspectRatio {
            // Image is wider than 4:3, crop width (center the crop)
            let newWidth = imageSize.height * targetAspectRatio
            let xOffset = (imageSize.width - newWidth) / 2.0
            cropRect = CGRect(x: xOffset, y: 0, width: newWidth, height: imageSize.height)
        } else {
            // Image is taller than 4:3, crop height (center the crop)
            let newHeight = imageSize.width / targetAspectRatio
            let yOffset = (imageSize.height - newHeight) / 2.0
            cropRect = CGRect(x: 0, y: yOffset, width: imageSize.width, height: newHeight)
        }
        
        // Crop the image
        if let cgImage = processedImage.cgImage?.cropping(to: cropRect) {
            processedImage = UIImage(cgImage: cgImage, scale: processedImage.scale, orientation: processedImage.imageOrientation)
        }
        
        // Rotate if needed for front camera to match preview orientation
        if isFrontCamera {
            processedImage = rotateImageRight(image: processedImage)
            print("PhotoCaptureDelegate: Image rotated for front camera")
        }
        
        return processedImage
    }
    
    private func flipImageHorizontally(image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else {
            return image
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return image
        }
        
        // Apply horizontal flip transformation
        context.translateBy(x: CGFloat(width), y: 0)
        context.scaleBy(x: -1.0, y: 1.0)
        
        // Draw the image
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Create new image from context
        guard let flippedCGImage = context.makeImage() else {
            return image
        }
        
        return UIImage(cgImage: flippedCGImage, scale: image.scale, orientation: .up)
    }
    
    private func rotateImageRight(image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else {
            return image
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        // Swap width and height for 90-degree rotation
        guard let context = CGContext(
            data: nil,
            width: height,
            height: width,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return image
        }
        
        // Rotate 90 degrees clockwise (to the right) - centered
        // Translate to center of new dimensions, rotate, then translate back
        context.translateBy(x: CGFloat(height) / 2.0, y: CGFloat(width) / 2.0)
        context.rotate(by: .pi / 2)
        context.translateBy(x: -CGFloat(width) / 2.0, y: -CGFloat(height) / 2.0)
        
        // Draw the image centered
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Create new image from context
        guard let rotatedCGImage = context.makeImage() else {
            return image
        }
        
        return UIImage(cgImage: rotatedCGImage, scale: image.scale, orientation: .up)
    }
}

// MARK: - Video Recording Delegate
class VideoRecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        // Handle video recording completion
        print("Video saved to: \(outputFileURL)")
    }
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// GalleryAssetThumbnail is defined in ChattingScreen.swift and reused here
