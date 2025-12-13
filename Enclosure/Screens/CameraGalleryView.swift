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
        cameraManager.capturePhoto { image in
            // Handle captured photo
            if let image = image {
                // Save and process photo
                print("Photo captured: \(image)")
            }
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
        // Handle send action with selected assets and caption
        print("Sending \(selectedAssetIds.count) items with caption: \(captionText)")
        // TODO: Implement send logic
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
    
    func setupCamera(isBackCamera: Bool) {
        currentCameraPosition = isBackCamera ? .back : .front
        
        let session = AVCaptureSession()
        session.sessionPreset = .high
        
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
        }
        
        // Video output
        let videoOut = AVCaptureMovieFileOutput()
        if session.canAddOutput(videoOut) {
            session.addOutput(videoOut)
            videoOutput = videoOut
        }
        
        captureSession = session
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
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
        guard let photoOutput = photoOutput else { return }
        
        let settings = AVCapturePhotoSettings()
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition),
           device.hasFlash {
            settings.flashMode = isFlashOn ? .on : .off
        }
        
        photoOutput.capturePhoto(with: settings, delegate: PhotoCaptureDelegate(completion: completion))
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
    
    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            completion(nil)
            return
        }
        completion(image)
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
