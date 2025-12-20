//
//  ShowDocumentScreen.swift
//  Enclosure
//
//  Created for document preview screen (matching Android show_document_screen.java)
//

import SwiftUI
import AVFoundation
import AVKit
import QuickLook
import Photos

struct ShowDocumentScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    let documentURL: URL
    let fileName: String
    let docSize: String?
    let fileExtension: String?
    let viewHolderType: String? // "sender" or "receiver" or nil
    let downloadUrl: String? // URL to download from if file doesn't exist locally
    
    init(documentURL: URL, fileName: String, docSize: String?, fileExtension: String?, viewHolderType: String?, downloadUrl: String?) {
        self.documentURL = documentURL
        self.fileName = fileName
        self.docSize = docSize
        self.fileExtension = fileExtension
        self.viewHolderType = viewHolderType
        self.downloadUrl = downloadUrl
        print("📄 [ShowDocumentScreen] INIT - fileName: \(fileName), documentURL: \(documentURL)")
    }
    
    @State private var isDownloaded: Bool = false
    @State private var isDownloading: Bool = false
    @State private var showImagePreview: Bool = false
    @State private var showVideoPlayer: Bool = false
    @State private var imageToDisplay: UIImage? = nil
    @State private var videoPlayer: AVPlayer? = nil
    @State private var showSaveMenu: Bool = false
    @State private var localFileURLForPreview: URL? = nil
    @State private var isMenuButtonPressed = false // Track menu button press state
    
    // Get theme color (matching Android Constant.getSF.getString(Constant.ThemeColorKey, "#00A3E9"))
    private var themeColor: String {
        return UserDefaults.standard.string(forKey: "ThemeColorKey") ?? "#00A3E9"
    }
    
    // Get local documents directory path
    private func getLocalDocumentsDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let docsDir = documentsPath.appendingPathComponent("Enclosure/Media/Documents", isDirectory: true)
        try? FileManager.default.createDirectory(at: docsDir, withIntermediateDirectories: true, attributes: nil)
        return docsDir
    }
    
    // Get local images directory path
    private func getLocalImagesDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagesDir = documentsPath.appendingPathComponent("Enclosure/Media/Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true, attributes: nil)
        return imagesDir
    }
    
    // Get local videos directory path
    private func getLocalVideosDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videosDir = documentsPath.appendingPathComponent("Enclosure/Media/Videos", isDirectory: true)
        try? FileManager.default.createDirectory(at: videosDir, withIntermediateDirectories: true, attributes: nil)
        return videosDir
    }
    
    // Check if file is image
    private var isImage: Bool {
        let ext = (fileName as NSString).pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "webp", "gif", "tiff", "psd", "heif", "svg"].contains(ext)
    }
    
    // Check if file is video
    private var isVideo: Bool {
        let ext = (fileName as NSString).pathExtension.lowercased()
        return ["mp4", "mov", "wmv", "flv", "mkv", "avi", "avchd", "webm", "hevc"].contains(ext)
    }
    
    // Check if file is audio
    private var isAudio: Bool {
        let ext = (fileName as NSString).pathExtension.lowercased()
        return ["mp3", "wav", "m4a", "aac", "flac", "ogg", "wma"].contains(ext)
    }
    
    // Check if file is PDF
    private var isPdf: Bool {
        let ext = (fileName as NSString).pathExtension.lowercased()
        return ext == "pdf"
    }
    
    // Find local file URL by checking multiple directories
    private func findLocalFileURL() -> URL? {
        print("📄 [ShowDocumentScreen] findLocalFileURL - fileName: \(fileName)")
        print("📄 [ShowDocumentScreen] documentURL: \(documentURL), isFileURL: \(documentURL.isFileURL)")
        
        // First check if documentURL is a local file (most direct path)
        if documentURL.isFileURL {
            let path = documentURL.path
            print("📄 [ShowDocumentScreen] Checking documentURL path: \(path)")
            if FileManager.default.fileExists(atPath: path) {
                print("✅ [ShowDocumentScreen] Found file at documentURL: \(path)")
                return documentURL
            } else {
                print("❌ [ShowDocumentScreen] documentURL path doesn't exist: \(path)")
            }
        } else {
            print("📄 [ShowDocumentScreen] documentURL is not a file URL, checking directories...")
        }
        
        // Check Images directory first for images (most likely location)
        if isImage {
            let imagesURL = getLocalImagesDirectory().appendingPathComponent(fileName)
            print("📄 [ShowDocumentScreen] Checking Images directory: \(imagesURL.path)")
            if FileManager.default.fileExists(atPath: imagesURL.path) {
                print("✅ [ShowDocumentScreen] Found file in Images directory")
                return imagesURL
            }
        }
        
        // Check Documents directory (for documents sent as documents)
        let docsURL = getLocalDocumentsDirectory().appendingPathComponent(fileName)
        print("📄 [ShowDocumentScreen] Checking Documents directory: \(docsURL.path)")
        if FileManager.default.fileExists(atPath: docsURL.path) {
            print("✅ [ShowDocumentScreen] Found file in Documents directory")
            return docsURL
        }
        
        // Check Videos directory (for videos sent as documents)
        if isVideo {
            let videosURL = getLocalVideosDirectory().appendingPathComponent(fileName)
            print("📄 [ShowDocumentScreen] Checking Videos directory: \(videosURL.path)")
            if FileManager.default.fileExists(atPath: videosURL.path) {
                print("✅ [ShowDocumentScreen] Found file in Videos directory")
                return videosURL
            }
        }
        
        print("❌ [ShowDocumentScreen] File not found in any directory")
        return nil
    }
    
    var body: some View {
        let _ = print("📄 [ShowDocumentScreen] body computed - fileName: \(fileName), documentURL: \(documentURL)")
        ZStack {
            // Full-screen black background (matching Android @color/black)
            Color.black
                .ignoresSafeArea()
            
            // Main content area
            ZStack {
                // Preview controls (shown when file is downloaded) - matching Android previewCtrl LinearLayout
                if isDownloaded {
                    if showImagePreview, let image = imageToDisplay {
                        // Image preview (matching Android PhotoView)
                        GeometryReader { geometry in
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                        }
                        .onAppear {
                            print("✅ [ShowDocumentScreen] Image preview is showing - image size: \(image.size)")
                        }
                    } else if showVideoPlayer, let player = videoPlayer {
                        // Video player (matching Android ExoPlayer PlayerView)
                        VideoPlayer(player: player)
                            .onAppear {
                                player.play()
                            }
                    } else if isAudio, let player = videoPlayer {
                        // Audio player
                        VideoPlayer(player: player)
                            .onAppear {
                                player.play()
                            }
                    } else if isPdf {
                        // PDF - show QLPreviewController directly
                        if let localURL = localFileURLForPreview {
                            DocumentQuickLookView(fileURL: localURL)
                        } else {
                            downloadControlsView(isDownloaded: true)
                        }
                    } else {
                        // Document - show download controls with done icon
                        downloadControlsView(isDownloaded: true)
                    }
                } else {
                    // Download controls (shown when file is not downloaded) - matching Android downloadCtrl LinearLayout
                    downloadControlsView(isDownloaded: false)
                }
            }
            
            // Top bar with back button and menu - matching Android backarrow34 and menu LinearLayout
            VStack {
                HStack {
                    // Back arrow button (matching Android backarrow34)
                    Button(action: {
                        // Light haptic feedback
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        // Release video player resources when navigating back
                        if let player = videoPlayer {
                            player.pause()
                            videoPlayer = nil
                        }
                        dismiss()
                    }) {
                        ZStack {
                            // Background matching Android black_background_hover
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.black.opacity(0.6))
                                .frame(width: 35, height: 36)
                            
                            Image("leftvector")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 25, height: 18)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.leading, 20)
                    .padding(.top, 50)
                    
                    Spacer()
                    
                    // Menu button (3 dots) - only show for sender/receiver view holders (matching Android menu LinearLayout)
                    // Design matches MainActivityOld.swift menu button exactly
                    if viewHolderType == "sender" || viewHolderType == "receiver" {
                        ZStack {
                            // Background circle for visual feedback
                            if isMenuButtonPressed {
                                Circle()
                                    .fill(Color("circlebtnhover").opacity(0.3))
                                    .frame(width: 44, height: 44)
                                    .transition(.opacity)
                            }
                            
                            VStack(spacing: 3) {
                                Circle()
                                    .fill(Color("menuPointColor"))
                                    .frame(width: 4, height: 4)
                                Circle()
                                    .fill(Color(hex: Constant.themeColor))
                                    .frame(width: 4, height: 4)
                                Circle()
                                    .fill(Color(red: 0x9E/255, green: 0xA6/255, blue: 0xB9/255))
                                    .frame(width: 4, height: 4)
                            }
                        }
                        .frame(width: 44, height: 44) // Standard iOS touch target size
                        .contentShape(Rectangle()) // Ensure entire area is tappable
                        .onTapGesture {
                            // Add haptic feedback for better UX
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            
                            // Visual feedback
                            withAnimation(.easeInOut(duration: 0.1)) {
                                isMenuButtonPressed = true
                            }
                            
                            // Show save menu
                            showSaveMenu = true
                            
                            // Reset pressed state
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    isMenuButtonPressed = false
                                }
                            }
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 50)
                        .confirmationDialog("Save", isPresented: $showSaveMenu) {
                            Button("Save") {
                                saveFileToGallery()
                            }
                        }
                    }
                }
                
                Spacer()
            }
        }
        .statusBarHidden(false)
        .task {
            // Use task instead of onAppear to ensure it runs
            print("📄 [ShowDocumentScreen] task started - fileName: \(fileName), documentURL: \(documentURL)")
            print("📄 [ShowDocumentScreen] isImage: \(isImage), isVideo: \(isVideo), isAudio: \(isAudio)")
            checkFileAndDisplay()
        }
        .onAppear {
            print("📄 [ShowDocumentScreen] onAppear - fileName: \(fileName), documentURL: \(documentURL)")
            print("📄 [ShowDocumentScreen] State - isDownloaded: \(isDownloaded), showImagePreview: \(showImagePreview), imageToDisplay: \(imageToDisplay != nil)")
            // Also check on appear as backup
            checkFileAndDisplay()
        }
        .onDisappear {
            print("📄 [ShowDocumentScreen] onDisappear")
            videoPlayer?.pause()
            videoPlayer = nil
        }
    }
    
    // Download controls view (matching Android downloadCtrl LinearLayout)
    @ViewBuilder
    private func downloadControlsView(isDownloaded: Bool) -> some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Document name (matching Android docName TextView)
            Text(fileName)
                .font(.custom("Inter18pt-Medium", size: 18))
                .foregroundColor(Color("gray3"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .lineLimit(3)
            
            // "size" label (matching Android TextView)
            Text("size")
                .font(.custom("Inter18pt-Medium", size: 15))
                .foregroundColor(Color("gray3"))
                .padding(.horizontal, 30)
                .padding(.top, 10)
            
            // File size value (matching Android size TextView)
            if let size = docSize {
                Text(size)
                    .font(.custom("Inter18pt-Medium", size: 15))
                    .foregroundColor(Color("gray3"))
                    .padding(.horizontal, 30)
            }
            
            // Download button or done icon (matching Android FloatingActionButton)
            if isDownloaded {
                // Done icon (matching Android done drawable) - opens file when clicked
                Button(action: {
                    openDownloadedFile()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: themeColor)) // Theme color
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "checkmark")
                            .foregroundColor(.white)
                            .font(.system(size: 20, weight: .bold))
                    }
                }
                .padding(.top, 10)
            } else {
                // Download button (matching Android downloaddown drawable)
                Button(action: {
                    downloadFile()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: themeColor)) // Theme color
                            .frame(width: 40, height: 40)
                        
                        Image("downloaddown")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.white)
                    }
                }
                .padding(.top, 10)
                
                // Progress bar (matching Android ProgressBar)
                if isDownloading {
                    ProgressView()
                        .progressViewStyle(LinearProgressViewStyle(tint: Color("TextColor")))
                        .frame(height: 4)
                        .padding(.top, 10)
                }
            }
            
            Spacer()
        }
    }
    
    // Check file and display accordingly (matching Android handleSenderFileDisplay/handleReceiverFileDisplay)
    private func checkFileAndDisplay() {
        print("📄 [ShowDocumentScreen] ===== checkFileAndDisplay START =====")
        print("📄 [ShowDocumentScreen] fileName: \(fileName)")
        print("📄 [ShowDocumentScreen] isImage: \(isImage), isVideo: \(isVideo), isAudio: \(isAudio)")
        print("📄 [ShowDocumentScreen] documentURL: \(documentURL)")
        print("📄 [ShowDocumentScreen] documentURL.isFileURL: \(documentURL.isFileURL)")
        print("📄 [ShowDocumentScreen] documentURL.path: \(documentURL.path)")
        
        if let localURL = findLocalFileURL() {
            print("📄 [ShowDocumentScreen] ✅ File found at: \(localURL.path)")
            print("📄 [ShowDocumentScreen] File exists check: \(FileManager.default.fileExists(atPath: localURL.path))")
            
            // Update state on main thread
            DispatchQueue.main.async {
                print("📄 [ShowDocumentScreen] Setting isDownloaded = true")
                self.isDownloaded = true
                
                if self.isImage {
                    // Load and display image
                    print("📄 [ShowDocumentScreen] Loading image from: \(localURL.path)")
                    if let image = UIImage(contentsOfFile: localURL.path) {
                        print("✅ [ShowDocumentScreen] Image loaded successfully, size: \(image.size)")
                        self.imageToDisplay = image
                        self.showImagePreview = true
                        print("✅ [ShowDocumentScreen] State updated - showImagePreview: \(self.showImagePreview), imageToDisplay: \(self.imageToDisplay != nil)")
                    } else {
                        print("❌ [ShowDocumentScreen] Failed to load image using UIImage(contentsOfFile:), trying Data method...")
                        // Try loading with different method
                        if let data = try? Data(contentsOf: localURL),
                           let image = UIImage(data: data) {
                            print("✅ [ShowDocumentScreen] Image loaded via Data method, size: \(image.size)")
                            self.imageToDisplay = image
                            self.showImagePreview = true
                            print("✅ [ShowDocumentScreen] State updated - showImagePreview: \(self.showImagePreview), imageToDisplay: \(self.imageToDisplay != nil)")
                        } else {
                            print("❌ [ShowDocumentScreen] Failed to load image with both methods")
                        }
                    }
                } else if self.isVideo || self.isAudio {
                    // Setup video/audio player
                    print("📄 [ShowDocumentScreen] Setting up player from: \(localURL.path)")
                    self.videoPlayer = AVPlayer(url: localURL)
                    self.showVideoPlayer = true
                } else if self.isPdf {
                    // PDF - will show QLPreviewController
                    print("📄 [ShowDocumentScreen] PDF type, will show QLPreviewController")
                    self.localFileURLForPreview = localURL
                    self.showImagePreview = false
                    self.showVideoPlayer = false
                } else {
                    // Document - will show done button
                    print("📄 [ShowDocumentScreen] Document type, showing done button")
                    self.showImagePreview = false
                    self.showVideoPlayer = false
                }
            }
        } else {
            print("❌ [ShowDocumentScreen] File not found locally, showing download controls")
            DispatchQueue.main.async {
                self.isDownloaded = false
            }
        }
        print("📄 [ShowDocumentScreen] ===== checkFileAndDisplay END =====")
    }
    
    // Download file (matching Android downloadFile)
    private func downloadFile() {
        guard let downloadUrl = downloadUrl, !downloadUrl.isEmpty else {
            print("❌ [ShowDocumentScreen] No download URL available")
            return
        }
        
        guard !fileName.isEmpty else {
            print("❌ [DOWNLOAD] No fileName available")
            return
        }
        
        // Determine destination directory based on file type
        let destinationDir: URL
        if isImage {
            destinationDir = getLocalImagesDirectory()
        } else if isVideo {
            destinationDir = getLocalVideosDirectory()
        } else {
            destinationDir = getLocalDocumentsDirectory()
        }
        
        let destinationFile = destinationDir.appendingPathComponent(fileName)
        
        // Check if file already exists
        if FileManager.default.fileExists(atPath: destinationFile.path) {
            // File already exists, mark as downloaded
            isDownloaded = true
            checkFileAndDisplay()
            return
        }
        
        // Check if already downloading
        if BackgroundDownloadManager.shared.isDownloading(fileName: fileName) {
            print("📱 [DOWNLOAD] Already downloading: \(fileName)")
            return
        }
        
        // Light haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Update UI: show progress
        isDownloading = true
        
        // Use BackgroundDownloadManager for background downloads
        BackgroundDownloadManager.shared.downloadImage(
            imageUrl: downloadUrl,
            fileName: fileName,
            destinationFile: destinationFile,
            onProgress: { progress in
                DispatchQueue.main.async {
                    // Progress is handled by BackgroundDownloadManager
                }
            },
            onSuccess: {
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.isDownloaded = true
                    // Refresh display
                    self.checkFileAndDisplay()
                }
            },
            onFailure: { error in
                DispatchQueue.main.async {
                    self.isDownloading = false
                    print("❌ [DOWNLOAD] Download failed: \(error.localizedDescription)")
                }
            }
        )
    }
    
    // Open downloaded file with external app (matching Android openDownloadedFile)
    private func openDownloadedFile() {
        guard let localURL = findLocalFileURL() else {
            print("❌ [ShowDocumentScreen] File not found locally")
            return
        }
        
        // Use QLPreviewController for document preview
        let previewController = QLPreviewController()
        previewController.dataSource = PreviewDataSource(fileURL: localURL)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(previewController, animated: true)
        }
    }
    
    // Preview data source for QLPreviewController
    class PreviewDataSource: NSObject, QLPreviewControllerDataSource {
        let fileURL: URL
        
        init(fileURL: URL) {
            self.fileURL = fileURL
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return fileURL as QLPreviewItem
        }
    }
    
    // Handle back press (matching Android handleBackPress)
    private func handleBackPress() {
        // Release video player resources when navigating back
        if let player = videoPlayer {
            player.pause()
            videoPlayer = nil
        }
        dismiss()
    }
    
    // Save file to gallery (matching Android saveFileToGallery)
    private func saveFileToGallery() {
        guard let localURL = findLocalFileURL() else {
            print("❌ [ShowDocumentScreen] File not found locally")
            return
        }
        
        if isImage {
            if let image = UIImage(contentsOfFile: localURL.path) {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                print("✅ Image saved to gallery")
            }
        } else if isVideo {
            // Save video to Photos library
            PHPhotoLibrary.requestAuthorization { status in
                if status == .authorized {
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: localURL)
                    }, completionHandler: { success, error in
                        DispatchQueue.main.async {
                            if success {
                                print("✅ Video saved successfully")
                            } else {
                                print("❌ Error saving video: \(error?.localizedDescription ?? "Unknown error")")
                            }
                        }
                    })
                }
            }
        } else {
            // Save document using UIActivityViewController
            let activityVC = UIActivityViewController(activityItems: [localURL], applicationActivities: nil)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(activityVC, animated: true)
            }
        }
    }
}

// MARK: - Document Quick Look View (for PDF preview)
struct DocumentQuickLookView: UIViewControllerRepresentable {
    let fileURL: URL
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(fileURL: fileURL)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let fileURL: URL
        
        init(fileURL: URL) {
            self.fileURL = fileURL
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return fileURL as QLPreviewItem
        }
    }
}

