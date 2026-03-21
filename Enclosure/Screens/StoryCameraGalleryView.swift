import SwiftUI
import Photos
import AVFoundation

// MARK: - Story Camera Gallery View
// Mirrors CameraGalleryView structure exactly — camera preview + draggable gallery bottom sheet
// Uses a completion callback instead of direct chat upload.
struct StoryCameraGalleryView: View {
    var onMediaSelected: (([PHAsset], String) -> Void)? = nil

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
    @State private var bottomSheetHeight: CGFloat = 250
    @State private var isBottomSheetExpanded = false
    @State private var dragOffset: CGFloat = 0
    @State private var isPressed: Bool = false
    @State private var showMultiImagePreview: Bool = false
    @State private var multiImagePreviewCaption: String = ""
    @State private var videoAssets: [PHAsset] = []

    private let imageManager = PHCachingImageManager()
    private let maxBottomSheetHeight: CGFloat = 620
    private let peekHeight: CGFloat = 250

    // Typography
    private var messageInputFont: Font {
        let pref = UserDefaults.standard.string(forKey: "Font_Size") ?? "medium"
        let size: CGFloat
        switch pref {
        case "small": return .custom("Inter18pt-Regular", size: 13)
        case "large": return .custom("Inter18pt-Regular", size: 19)
        default: return .custom("Inter18pt-Regular", size: 16)
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-screen camera preview
            CameraPreviewView(cameraManager: cameraManager)
                .ignoresSafeArea()
                .contentShape(Rectangle())

            // Bottom sheet with swipe gesture
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
                                let translation = -value.translation.height
                                let newHeight = bottomSheetHeight + translation
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
            Button(action: handleBackTap) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.4))
                        .frame(width: 40, height: 40)
                    if isPressed {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 40, height: 40)
                            .scaleEffect(1.2)
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
            // Flash | Capture | Switch Camera
            HStack {
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

                Button(action: {
                    if isPhotoMode { capturePhoto() } else { toggleVideoRecording() }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 80, height: 80)
                            .overlay(Circle().stroke(Color("TextColor"), lineWidth: 3))
                    }
                    .padding(5)
                }

                Spacer()

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

            // Photo/Video tabs
            HStack(spacing: 2) {
                Button(action: { isPhotoMode = true }) {
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
                Button(action: { isPhotoMode = false }) {
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
            .background(RoundedRectangle(cornerRadius: 20).fill(Color("circlebtnhover").opacity(0.2)))
            .padding(.top, 7)
            .padding(.bottom, 7)

            if isRecording {
                Text(formatTime(recordingTime))
                    .font(.custom("Inter18pt-Regular", size: 18))
                    .foregroundColor(Color("TextColor"))
                    .padding(.top, 7)
            }

            if showPermissionText && isBottomSheetExpanded {
                Text("You've given Enclosure permission to access only a select number of photos. Manage")
                    .font(.custom("Inter18pt-Medium", size: 13))
                    .foregroundColor(Color("chtbtncolor"))
                    .padding(10)
                    .lineSpacing(2)
            }

            // Gallery grid
            if isBottomSheetExpanded {
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
                                    Image("multitick").resizable().frame(width: 20, height: 20).padding(10)
                                }
                            }
                            .onTapGesture { toggleSelection(for: asset) }
                        }
                    }
                    .padding(.top, 10).padding(.horizontal, 10).padding(.bottom, 10)
                }
                .frame(minHeight: 360)
            } else {
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
                                Image("multitick").resizable().frame(width: 20, height: 20).padding(10)
                            }
                        }
                        .onTapGesture { toggleSelection(for: asset) }
                    }
                }
                .padding(.top, 10).padding(.horizontal, 10).padding(.bottom, 10)
            }

            // Caption + Send (only when expanded)
            if isBottomSheetExpanded {
                HStack(spacing: 0) {
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            TextField("Add Caption", text: $captionText, axis: .vertical)
                                .font(messageInputFont)
                                .foregroundColor(Color("black_white_cross"))
                                .lineLimit(4)
                                .frame(maxWidth: 180, alignment: .leading)
                                .padding(.leading, 10)
                                .padding(.trailing, 20)
                                .padding(.top, 5)
                                .padding(.bottom, 5)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 50)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color("circlebtnhover")))
                    .padding(.leading, 10)
                    .padding(.trailing, 5)

                    ZStack(alignment: .topTrailing) {
                        VStack(spacing: 0) {
                            Button(action: { handleSend() }) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: Constant.themeColor))
                                        .frame(width: 50, height: 50)
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
                            .disabled(selectedAssetIds.isEmpty)
                            .opacity(selectedAssetIds.isEmpty ? 0.5 : 1.0)
                        }
                        if selectedAssetIds.count > 0 {
                            Text("\(selectedAssetIds.count)")
                                .font(.custom("Inter18pt-Bold", size: 12))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(Color(hex: Constant.themeColor)))
                                .offset(x: -13, y: -30)
                        }
                    }
                    .padding(.horizontal, 5)
                }
                .padding(.bottom, 50)
            }
        }
    }

    // MARK: - Logic

    private func capturePhoto() {
        cameraManager.capturePhoto { image in
            if let image = image { savePhotoToLibrary(image: image) }
        }
    }

    private func savePhotoToLibrary(image: UIImage) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { s in
                if s == .authorized || s == .limited { self.performSavePhoto(image: image) }
            }
        } else if status == .authorized || status == .limited {
            performSavePhoto(image: image)
        }
    }

    private func performSavePhoto(image: UIImage) {
        var placeholder: PHObjectPlaceholder?
        PHPhotoLibrary.shared().performChanges({
            let req = PHAssetChangeRequest.creationRequestForAsset(from: image)
            placeholder = req.placeholderForCreatedAsset
        }) { success, _ in
            guard success, let id = placeholder?.localIdentifier else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let result = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
                if let asset = result.firstObject {
                    if !self.photoAssets.contains(where: { $0.localIdentifier == asset.localIdentifier }) {
                        self.photoAssets.insert(asset, at: 0)
                    }
                    self.selectedAssetIds = [asset.localIdentifier]
                    self.multiImagePreviewCaption = self.captionText
                    self.showMultiImagePreview = true
                }
            }
        }
    }

    private func toggleVideoRecording() {
        if isRecording { stopVideoRecording() } else { startVideoRecording() }
    }

    private func startVideoRecording() {
        isRecording = true
        recordingTime = 0
        cameraManager.startVideoRecording()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingTime += 0.1
            if recordingTime >= 60.0 { stopVideoRecording() }
        }
    }

    private func stopVideoRecording() {
        isRecording = false
        timer?.invalidate()
        cameraManager.stopVideoRecording { url in
            if let url = url { saveVideoToLibrary(url: url) }
        }
    }

    private func saveVideoToLibrary(url: URL) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .authorized || status == .limited {
            performSaveVideo(url: url)
        } else if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { s in
                if s == .authorized || s == .limited { self.performSaveVideo(url: url) }
            }
        }
    }

    private func performSaveVideo(url: URL) {
        var placeholder: PHObjectPlaceholder?
        PHPhotoLibrary.shared().performChanges({
            let req = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            placeholder = req?.placeholderForCreatedAsset
        }) { success, _ in
            guard success, let id = placeholder?.localIdentifier else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let result = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
                if let asset = result.firstObject {
                    if !self.videoAssets.contains(where: { $0.localIdentifier == asset.localIdentifier }) {
                        self.videoAssets.insert(asset, at: 0)
                    }
                    // For video: call callback directly and dismiss
                    self.onMediaSelected?([asset], self.captionText)
                    DispatchQueue.main.async { self.dismiss() }
                }
            }
        }
    }

    private func handleSend() {
        guard !selectedAssetIds.isEmpty else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        multiImagePreviewCaption = captionText
        showMultiImagePreview = true
    }

    private func handleMultiImageSend(caption: String) {
        let selectedAssets = photoAssets.filter { selectedAssetIds.contains($0.localIdentifier) }
        guard !selectedAssets.isEmpty else { return }
        showMultiImagePreview = false
        onMediaSelected?(selectedAssets, caption)
        selectedAssetIds.removeAll()
        captionText = ""
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { dismiss() }
    }

    private func toggleSelection(for asset: PHAsset) {
        if selectedAssetIds.contains(asset.localIdentifier) {
            selectedAssetIds.remove(asset.localIdentifier)
            if selectedAssetIds.isEmpty && isBottomSheetExpanded {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    bottomSheetHeight = peekHeight
                    isBottomSheetExpanded = false
                }
            }
        } else {
            selectedAssetIds.insert(asset.localIdentifier)
            if !isBottomSheetExpanded {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    bottomSheetHeight = maxBottomSheetHeight
                    isBottomSheetExpanded = true
                }
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(time) / 60, Int(time) % 60)
    }

    private func requestCameraPermissionAndSetup() {
        AndroidStylePermissionManager.shared.requestPermissionWithDialogFromTopVC(for: .camera) { granted in
            DispatchQueue.main.async {
                if granted { cameraManager.setupCamera(isBackCamera: isBackCamera) }
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
        var list: [PHAsset] = []
        assets.enumerateObjects { a, _, _ in list.append(a) }
        DispatchQueue.main.async { photoAssets = list }
    }

    private func checkPhotoLibraryPermission() {
        if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited {
            showPermissionText = true
        }
    }

    private func handleBackTap() {
        withAnimation { isPressed = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            dismiss()
            isPressed = false
        }
    }
}
