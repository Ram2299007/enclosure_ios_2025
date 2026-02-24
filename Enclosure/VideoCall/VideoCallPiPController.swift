// VideoCallPiPController.swift
// Enclosure
//
// System-level PiP using AVPictureInPictureController for video calls.
// Shows both local + remote video and a timer in a native iOS PiP window
// when the app goes to background. Same design as the in-app PiP overlay.
// Uses AVPictureInPictureVideoCallViewController (iOS 15+).

import AVKit
import UIKit
import WebRTC

// MARK: - SampleBufferRenderer
// Receives WebRTC video frames and feeds them to an AVSampleBufferDisplayLayer.

final class SampleBufferRenderer: NSObject, RTCVideoRenderer {
    let displayLayer: AVSampleBufferDisplayLayer

    init(displayLayer: AVSampleBufferDisplayLayer) {
        self.displayLayer = displayLayer
        super.init()
    }

    func setSize(_ size: CGSize) {}

    func renderFrame(_ frame: RTCVideoFrame?) {
        guard let frame = frame else { return }

        let pixelBuffer: CVPixelBuffer?
        if let cvBuffer = frame.buffer as? RTCCVPixelBuffer {
            pixelBuffer = cvBuffer.pixelBuffer
        } else if let i420 = frame.buffer as? RTCI420Buffer {
            pixelBuffer = Self.pixelBuffer(from: i420)
        } else {
            return
        }
        guard let pb = pixelBuffer else { return }

        var formatDescription: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: nil, imageBuffer: pb, formatDescriptionOut: &formatDescription
        )
        guard let format = formatDescription else { return }

        var timing = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: CMTime(value: CMTimeValue(CACurrentMediaTime() * 1000), timescale: 1000),
            decodeTimeStamp: .invalid
        )

        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(
            allocator: nil, imageBuffer: pb, formatDescription: format,
            sampleTiming: &timing, sampleBufferOut: &sampleBuffer
        )
        guard let buffer = sampleBuffer else { return }

        DispatchQueue.main.async { [weak self] in
            guard let layer = self?.displayLayer else { return }
            if layer.status == .failed { layer.flush() }
            layer.enqueue(buffer)
        }
    }

    // Convert I420 → NV12 CVPixelBuffer (fallback for software-decoded frames)
    static func pixelBuffer(from i420: RTCI420Buffer) -> CVPixelBuffer? {
        let width = Int(i420.width)
        let height = Int(i420.height)

        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any]
        ]
        let status = CVPixelBufferCreate(
            nil, width, height,
            kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            attrs as CFDictionary, &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pb = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }

        // Y plane
        let yDest = CVPixelBufferGetBaseAddressOfPlane(pb, 0)!
        let yDestStride = CVPixelBufferGetBytesPerRowOfPlane(pb, 0)
        let ySrc = i420.dataY
        let ySrcStride = Int(i420.strideY)
        for row in 0..<height {
            memcpy(yDest + row * yDestStride, ySrc + row * ySrcStride, min(width, ySrcStride))
        }

        // Interleave U+V → UV plane (NV12)
        let uvDest = CVPixelBufferGetBaseAddressOfPlane(pb, 1)!
        let uvDestStride = CVPixelBufferGetBytesPerRowOfPlane(pb, 1)
        let uSrc = i420.dataU
        let vSrc = i420.dataV
        let uStride = Int(i420.strideU)
        let vStride = Int(i420.strideV)
        let halfHeight = height / 2
        let halfWidth = width / 2
        for row in 0..<halfHeight {
            let uvRowPtr = (uvDest + row * uvDestStride).assumingMemoryBound(to: UInt8.self)
            let uRowPtr = uSrc + row * uStride
            let vRowPtr = vSrc + row * vStride
            for col in 0..<halfWidth {
                uvRowPtr[col * 2] = uRowPtr[col]
                uvRowPtr[col * 2 + 1] = vRowPtr[col]
            }
        }
        return pb
    }
}

// MARK: - PiPContentViewController
// Custom VC for the PiP window: remote (full), local (small corner), timer badge.

final class PiPContentViewController: AVPictureInPictureVideoCallViewController {
    let remoteLayer = AVSampleBufferDisplayLayer()
    let localLayer = AVSampleBufferDisplayLayer()
    let timerLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        // Remote video — fills entire PiP
        remoteLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(remoteLayer)

        // Local video — small overlay in top-right
        localLayer.videoGravity = .resizeAspectFill
        localLayer.cornerRadius = 6
        localLayer.masksToBounds = true
        localLayer.borderColor = UIColor.white.cgColor
        localLayer.borderWidth = 1.5
        view.layer.addSublayer(localLayer)

        // Timer badge — bottom center
        timerLabel.text = "00:00"
        timerLabel.textColor = .white
        timerLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        timerLabel.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        timerLabel.textAlignment = .center
        timerLabel.layer.cornerRadius = 8
        timerLabel.clipsToBounds = true
        view.addSubview(timerLabel)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let b = view.bounds

        // Remote fills everything
        remoteLayer.frame = b

        // Local: 30% width, 4:3 aspect, top-right with padding
        let localW = b.width * 0.30
        let localH = localW * (4.0 / 3.0)
        localLayer.frame = CGRect(
            x: b.width - localW - 6,
            y: 6,
            width: localW,
            height: localH
        )

        // Timer: bottom center
        let timerW: CGFloat = 58
        let timerH: CGFloat = 20
        timerLabel.frame = CGRect(
            x: (b.width - timerW) / 2,
            y: b.height - timerH - 6,
            width: timerW,
            height: timerH
        )
    }
}

// MARK: - VideoCallPiPController
// Manages system-level PiP for video calls. Shows both videos + timer.

final class VideoCallPiPController: NSObject, AVPictureInPictureControllerDelegate {

    private var pipController: AVPictureInPictureController?
    private var pipContentVC: PiPContentViewController?
    private var sourceView: UIView?
    private var remoteRenderer: SampleBufferRenderer?
    private var localRenderer: SampleBufferRenderer?
    private var isSetUp = false

    // Timer
    private var timerUpdateTimer: Timer?
    var callDurationProvider: (() -> TimeInterval)?

    // Called when PiP is restored (user taps to return to app)
    var onRestoreFromPiP: (() -> Void)?

    func setup(sourceView: UIView) {
        guard !isSetUp else { return }
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            NSLog("⚠️ [PiPController] PiP not supported on this device")
            return
        }

        self.sourceView = sourceView
        isSetUp = true

        // Create PiP content VC with both layers
        let contentVC = PiPContentViewController()
        contentVC.preferredContentSize = CGSize(width: 1080, height: 1920)
        self.pipContentVC = contentVC

        // Renderers feed WebRTC frames → display layers
        let remote = SampleBufferRenderer(displayLayer: contentVC.remoteLayer)
        let local = SampleBufferRenderer(displayLayer: contentVC.localLayer)
        self.remoteRenderer = remote
        self.localRenderer = local

        // PiP content source
        let contentSource = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: sourceView,
            contentViewController: contentVC
        )

        let controller = AVPictureInPictureController(contentSource: contentSource)
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.delegate = self
        self.pipController = controller

        NSLog("✅ [PiPController] System PiP set up (local + remote + timer)")
    }

    func startPiP() {
        guard let controller = pipController, !controller.isPictureInPictureActive else { return }
        controller.startPictureInPicture()
        startTimerUpdates()
        NSLog("▶️ [PiPController] Starting system PiP")
    }

    func stopPiP() {
        guard let controller = pipController, controller.isPictureInPictureActive else { return }
        controller.stopPictureInPicture()
        stopTimerUpdates()
        NSLog("⏹️ [PiPController] Stopping system PiP")
    }

    func tearDown() {
        stopPiP()
        stopTimerUpdates()
        remoteRenderer = nil
        localRenderer = nil
        pipController = nil
        pipContentVC = nil
        sourceView = nil
        isSetUp = false
        NSLog("🔴 [PiPController] Torn down")
    }

    // MARK: - Track attachment

    func attachRemoteTrack(_ track: RTCVideoTrack) {
        guard let renderer = remoteRenderer else { return }
        track.add(renderer)
        NSLog("📹 [PiPController] Attached remote renderer")
    }

    func detachRemoteTrack(_ track: RTCVideoTrack) {
        guard let renderer = remoteRenderer else { return }
        track.remove(renderer)
        NSLog("📹 [PiPController] Detached remote renderer")
    }

    func attachLocalTrack(_ track: RTCVideoTrack) {
        guard let renderer = localRenderer else { return }
        track.add(renderer)
        NSLog("📹 [PiPController] Attached local renderer")
    }

    func detachLocalTrack(_ track: RTCVideoTrack) {
        guard let renderer = localRenderer else { return }
        track.remove(renderer)
        NSLog("📹 [PiPController] Detached local renderer")
    }

    // MARK: - Timer

    private func startTimerUpdates() {
        timerUpdateTimer?.invalidate()
        timerUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let duration = self.callDurationProvider?() else { return }
            let mins = Int(duration) / 60
            let secs = Int(duration) % 60
            self.pipContentVC?.timerLabel.text = String(format: "%02d:%02d", mins, secs)
        }
    }

    private func stopTimerUpdates() {
        timerUpdateTimer?.invalidate()
        timerUpdateTimer = nil
    }

    // MARK: - AVPictureInPictureControllerDelegate

    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        NSLog("📹 [PiPController] System PiP will start")
    }

    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        NSLog("✅ [PiPController] System PiP started")
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        stopTimerUpdates()
        NSLog("⏹️ [PiPController] System PiP stopped")
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                     restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        NSLog("📹 [PiPController] Restore UI from system PiP")
        onRestoreFromPiP?()
        completionHandler(true)
    }
}

// MARK: - PiPSourceViewBridge
// Invisible UIViewRepresentable that captures a UIView reference for AVPictureInPictureController.
// Must be placed in a persistent view hierarchy (e.g. MainActivityOld) so the source view
// remains alive when the full-screen video call is dismissed for in-app PiP.

import SwiftUI

struct PiPSourceViewBridge: UIViewRepresentable {
    let onViewReady: (UIView) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        DispatchQueue.main.async { onViewReady(view) }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
