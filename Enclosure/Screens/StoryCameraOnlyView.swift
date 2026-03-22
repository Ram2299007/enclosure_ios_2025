import SwiftUI
import Photos
import AVFoundation

// MARK: - Story Camera Only View
// Full-screen camera for story creation — photo capture + video recording only.
// No gallery, no caption, no send button, no bottom sheet.
struct StoryCameraOnlyView: View {
    var onMediaSelected: (([PHAsset], String) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @StateObject private var cameraManager = CameraManager()

    @State private var isPhotoMode = true
    @State private var isFlashOn = false
    @State private var isBackCamera = true
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var isPressed = false

    var body: some View {
        ZStack {
            // Full-screen camera preview
            CameraPreviewView(cameraManager: cameraManager)
                .ignoresSafeArea()

            // Top bar: back + flash
            VStack {
                HStack {
                    // Back button
                    Button(action: handleBackTap) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.4))
                                .frame(width: 40, height: 40)
                            Image("leftvector")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 25, height: 18)
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Flash toggle
                    Button(action: {
                        isFlashOn.toggle()
                        cameraManager.toggleFlash(isOn: isFlashOn)
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.4))
                                .frame(width: 40, height: 40)
                            Image(isFlashOn ? "flash_onn" : "flash_off")
                                .resizable()
                                .renderingMode(.template)
                                .scaledToFit()
                                .frame(width: 26, height: 26)
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                Spacer()

                // Recording timer
                if isRecording {
                    Text(formatTime(recordingTime))
                        .font(.custom("Inter18pt-Regular", size: 18))
                        .foregroundColor(.white)
                        .padding(.bottom, 12)
                }

                // Bottom controls: flash | capture | flip
                HStack {
                    // Switch camera
                    Button(action: {
                        isBackCamera.toggle()
                        cameraManager.switchCamera()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.4))
                                .frame(width: 50, height: 50)
                            Image("flipcamera")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28, height: 28)
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Capture / Record button
                    Button(action: {
                        if isPhotoMode { capturePhoto() } else { toggleVideoRecording() }
                    }) {
                        ZStack {
                            // Outer ring
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 78, height: 78)
                            // Inner fill — red when recording
                            Circle()
                                .fill(isRecording ? Color.red : Color.white.opacity(0.25))
                                .frame(width: 62, height: 62)
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Placeholder to balance layout (same size as flip button)
                    Color.clear.frame(width: 50, height: 50)
                }
                .padding(.horizontal, 40)

                // Photo / Video tabs
                HStack(spacing: 2) {
                    Button(action: { isPhotoMode = true }) {
                        Text("Photo")
                            .font(.custom("Inter18pt-Regular", size: 13))
                            .foregroundColor(isPhotoMode ? .black : .white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(isPhotoMode ? Color.white : Color.clear)
                            )
                    }
                    Button(action: { isPhotoMode = false }) {
                        Text("Video")
                            .font(.custom("Inter18pt-Regular", size: 13))
                            .foregroundColor(!isPhotoMode ? .black : .white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(!isPhotoMode ? Color.white : Color.clear)
                            )
                    }
                }
                .padding(3)
                .background(
                    Capsule().fill(Color.white.opacity(0.2))
                )
                .padding(.top, 20)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            AndroidStylePermissionManager.shared.requestPermissionWithDialogFromTopVC(for: .camera) { granted in
                DispatchQueue.main.async {
                    if granted { cameraManager.setupCamera(isBackCamera: isBackCamera) }
                }
            }
        }
        .onDisappear {
            cameraManager.stopSession()
            timer?.invalidate()
        }
    }

    // MARK: - Capture Photo

    private func capturePhoto() {
        cameraManager.capturePhoto { image in
            guard let image else { return }
            savePhotoToLibrary(image: image)
        }
    }

    private func savePhotoToLibrary(image: UIImage) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .authorized || status == .limited {
            performSavePhoto(image: image)
        } else if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { s in
                if s == .authorized || s == .limited { self.performSavePhoto(image: image) }
            }
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
                    self.onMediaSelected?([asset], "")
                    self.dismiss()
                }
            }
        }
    }

    // MARK: - Video Recording

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
            if let url { saveVideoToLibrary(url: url) }
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
                    self.onMediaSelected?([asset], "")
                    self.dismiss()
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatTime(_ time: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(time) / 60, Int(time) % 60)
    }

    private func handleBackTap() {
        withAnimation { isPressed = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            dismiss()
        }
    }
}
