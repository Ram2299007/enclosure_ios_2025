// VideoCallPiPController.swift
// Enclosure
//
// System-level PiP using AVPictureInPictureController for video calls.
// Shows remote video in a native iOS PiP window when the app goes to background.
// Uses AVPictureInPictureVideoCallViewController (iOS 15+).

import AVKit
import UIKit
import WebRTC

// MARK: - SampleBufferRenderer
// Receives WebRTC video frames and feeds them to an AVSampleBufferDisplayLayer.

final class SampleBufferRenderer: NSObject, RTCVideoRenderer {
    let displayLayer = AVSampleBufferDisplayLayer()

    func setSize(_ size: CGSize) {
        // No-op — layer resizes automatically
    }

    func renderFrame(_ frame: RTCVideoFrame?) {
        guard let frame = frame else { return }

        // Get CVPixelBuffer from the frame
        let pixelBuffer: CVPixelBuffer?
        if let cvBuffer = frame.buffer as? RTCCVPixelBuffer {
            pixelBuffer = cvBuffer.pixelBuffer
        } else if let i420 = frame.buffer as? RTCI420Buffer {
            pixelBuffer = Self.pixelBuffer(from: i420)
        } else {
            return
        }
        guard let pb = pixelBuffer else { return }

        // Create CMSampleBuffer
        var formatDescription: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: nil,
            imageBuffer: pb,
            formatDescriptionOut: &formatDescription
        )
        guard let format = formatDescription else { return }

        var timing = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: CMTime(value: CMTimeValue(CACurrentMediaTime() * 1000), timescale: 1000),
            decodeTimeStamp: .invalid
        )

        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(
            allocator: nil,
            imageBuffer: pb,
            formatDescription: format,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        guard let buffer = sampleBuffer else { return }

        DispatchQueue.main.async { [weak self] in
            guard let layer = self?.displayLayer else { return }
            if layer.status == .failed {
                layer.flush()
            }
            layer.enqueue(buffer)
        }
    }

    // Convert I420 buffer to CVPixelBuffer (fallback for software-decoded frames)
    private static func pixelBuffer(from i420: RTCI420Buffer) -> CVPixelBuffer? {
        let width = Int(i420.width)
        let height = Int(i420.height)

        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any]
        ]
        let status = CVPixelBufferCreate(
            nil, width, height,
            kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            attrs as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pb = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }

        // Copy Y plane
        let yDest = CVPixelBufferGetBaseAddressOfPlane(pb, 0)!
        let yDestStride = CVPixelBufferGetBytesPerRowOfPlane(pb, 0)
        let ySrc = i420.dataY
        let ySrcStride = Int(i420.strideY)
        for row in 0..<height {
            memcpy(yDest + row * yDestStride, ySrc + row * ySrcStride, min(width, ySrcStride))
        }

        // Interleave U+V into UV plane (NV12 format)
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

// MARK: - SampleBufferVideoCallView
// UIView backed by AVSampleBufferDisplayLayer for PiP content.

final class SampleBufferVideoCallView: UIView {
    override class var layerClass: AnyClass { AVSampleBufferDisplayLayer.self }

    var sampleBufferLayer: AVSampleBufferDisplayLayer {
        return layer as! AVSampleBufferDisplayLayer
    }
}

// MARK: - VideoCallPiPController
// Manages system-level PiP for video calls using AVPictureInPictureController.

final class VideoCallPiPController: NSObject, AVPictureInPictureControllerDelegate {

    private var pipController: AVPictureInPictureController?
    private var pipVideoCallVC: AVPictureInPictureVideoCallViewController?
    private var sourceView: UIView?
    private(set) var sampleBufferRenderer: SampleBufferRenderer?
    private var isSetUp = false

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

        // Create the renderer that feeds WebRTC frames to AVSampleBufferDisplayLayer
        let renderer = SampleBufferRenderer()
        self.sampleBufferRenderer = renderer

        // Create PiP video call VC
        let pipVC = AVPictureInPictureVideoCallViewController()
        pipVC.preferredContentSize = CGSize(width: 1080, height: 1920)

        // Add the display layer to the PiP VC's view
        renderer.displayLayer.frame = pipVC.view.bounds
        renderer.displayLayer.videoGravity = .resizeAspectFill
        pipVC.view.layer.addSublayer(renderer.displayLayer)
        self.pipVideoCallVC = pipVC

        // Create PiP content source
        let contentSource = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: sourceView,
            contentViewController: pipVC
        )

        let controller = AVPictureInPictureController(contentSource: contentSource)
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.delegate = self
        self.pipController = controller

        NSLog("✅ [PiPController] System PiP set up")
    }

    func startPiP() {
        guard let controller = pipController, !controller.isPictureInPictureActive else { return }
        controller.startPictureInPicture()
        NSLog("▶️ [PiPController] Starting system PiP")
    }

    func stopPiP() {
        guard let controller = pipController, controller.isPictureInPictureActive else { return }
        controller.stopPictureInPicture()
        NSLog("⏹️ [PiPController] Stopping system PiP")
    }

    func tearDown() {
        stopPiP()
        sampleBufferRenderer = nil
        pipController = nil
        pipVideoCallVC = nil
        sourceView = nil
        isSetUp = false
        NSLog("🔴 [PiPController] Torn down")
    }

    // Attach renderer to a WebRTC video track
    func attachToTrack(_ track: RTCVideoTrack) {
        guard let renderer = sampleBufferRenderer else { return }
        track.add(renderer)
        NSLog("📹 [PiPController] Attached SampleBufferRenderer to video track")
    }

    func detachFromTrack(_ track: RTCVideoTrack) {
        guard let renderer = sampleBufferRenderer else { return }
        track.remove(renderer)
        NSLog("📹 [PiPController] Detached SampleBufferRenderer from video track")
    }

    // Update display layer frame when PiP VC layout changes
    func updateLayout() {
        guard let pipVC = pipVideoCallVC, let renderer = sampleBufferRenderer else { return }
        renderer.displayLayer.frame = pipVC.view.bounds
    }

    // MARK: - AVPictureInPictureControllerDelegate

    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        NSLog("📹 [PiPController] System PiP will start")
    }

    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        NSLog("✅ [PiPController] System PiP started")
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        NSLog("⏹️ [PiPController] System PiP stopped")
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                     restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        NSLog("📹 [PiPController] Restore UI from system PiP")
        onRestoreFromPiP?()
        completionHandler(true)
    }
}
