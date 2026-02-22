import SwiftUI
import UIKit
import WebKit
import AVFoundation

struct VideoCallScreen: View {
    @Environment(\.dismiss) private var dismiss
    private let payload: VideoCallPayload
    
    init(payload: VideoCallPayload) {
        self.payload = payload
    }

    var body: some View {
        NativeVideoCallScreen(payload: payload)
    }
}

// Coordinator class for WebView message handling
class VideoCallWebViewCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate {
    static let messageHandlerName = "videoCall"
    static let bridgeScript = """
    window.__muteState = window.__muteState || false;
    window.Android = {
      isWifiConnected: function() {
        try { window.webkit.messageHandlers.videoCall.postMessage({type: 'isWifiConnected'}); } catch (e) {}
        return true;
      },
      toggleMicrophone: function(mute) {
        window.webkit.messageHandlers.videoCall.postMessage({type: 'toggleMicrophone', mute: mute});
      },
      saveMuteState: function(mute) {
        window.__muteState = !!mute;
        window.webkit.messageHandlers.videoCall.postMessage({type: 'saveMuteState', mute: mute});
      },
      getMuteState: function() {
        return !!window.__muteState;
      },
      sendPeerId: function(peerId) {
        window.webkit.messageHandlers.videoCall.postMessage({type: 'sendPeerId', peerId: peerId});
      },
      sendSignalingData: function(data) {
        window.webkit.messageHandlers.videoCall.postMessage({type: 'sendSignalingData', data: data});
      },
      onPeerConnected: function() {
        window.webkit.messageHandlers.videoCall.postMessage({type: 'onPeerConnected'});
      },
      onCallConnected: function() {
        window.webkit.messageHandlers.videoCall.postMessage({type: 'onCallConnected'});
      },
      endCall: function() {
        window.webkit.messageHandlers.videoCall.postMessage({type: 'endCall'});
      },
      callOnBackPressed: function() {
        window.webkit.messageHandlers.videoCall.postMessage({type: 'callOnBackPressed'});
      },
      addMemberBtn: function() {
        window.webkit.messageHandlers.videoCall.postMessage({type: 'addMemberBtn'});
      },
      onPageReady: function() {
        window.webkit.messageHandlers.videoCall.postMessage({type: 'onPageReady'});
      },
      toggleFullScreen: function() {
        window.webkit.messageHandlers.videoCall.postMessage({type: 'toggleFullScreen'});
      },
      enterPiPModes: function() {
        window.webkit.messageHandlers.videoCall.postMessage({type: 'enterPiPMode'});
      }
    };
    """
    
    static let cssFixScript = """
    (function() {
        var style = document.createElement('style');
        // Use black background as fallback if WEBP fails, but try to load WEBP
        var css = '* { margin: 0 !important; padding: 0 !important; box-sizing: border-box !important; } ' +
            'html { margin: 0 !important; padding: 0 !important; width: 100% !important; height: 100% !important; ' +
            'overflow: hidden !important; background-color: #000 !important; ' +
            'background-image: url(\\'bg_blur.webp\\') !important; ' +
            'background-repeat: no-repeat !important; background-position: center center !important; ' +
            'background-attachment: fixed !important; background-size: cover !important; ' +
            'position: fixed !important; top: 0 !important; left: 0 !important; ' +
            'right: 0 !important; bottom: 0 !important; } ' +
            'body { margin: 0 !important; padding: 0 !important; width: 100% !important; ' +
            'height: 100% !important; overflow: hidden !important; ' +
            'background-color: #000 !important; ' +
            'background-image: url(\\'bg_blur.webp\\') !important; ' +
            'background-repeat: no-repeat !important; background-position: center center !important; ' +
            'background-attachment: fixed !important; background-size: cover !important; ' +
            'position: fixed !important; top: 0 !important; left: 0 !important; ' +
            'right: 0 !important; bottom: 0 !important; } ' +
            '.video-container { position: fixed !important; top: 0 !important; left: 0 !important; ' +
            'right: 0 !important; bottom: 0 !important; width: 100% !important; ' +
            'height: 100% !important; min-width: 100% !important; min-height: 100% !important; ' +
            'background-color: #000 !important; ' +
            'background-image: url(\\'bg_blur.webp\\') !important; ' +
            'background-repeat: no-repeat !important; background-position: center center !important; ' +
            'background-attachment: fixed !important; background-size: cover !important; ' +
            'margin: 0 !important; padding: 0 !important; } ' +
            'video { background-color: #000 !important; ' +
            'background-image: url(\\'bg_blur.webp\\') !important; ' +
            'background-size: cover !important; background-position: center center !important; }';
        style.textContent = css;
        document.head.appendChild(style);
        
        // Preload bg_blur.webp to catch errors early
        var bgImage = new Image();
        bgImage.onload = function() {
            console.log('bg_blur.webp preloaded successfully');
        };
        bgImage.onerror = function() {
            console.warn('bg_blur.webp failed to load - using black background fallback');
            // Fallback to solid black if WEBP fails
            document.documentElement.style.backgroundImage = 'none';
            document.body.style.backgroundImage = 'none';
            var container = document.querySelector('.video-container');
            if (container) {
                container.style.backgroundImage = 'none';
            }
        };
        bgImage.src = 'bg_blur.webp';
        
        // Force full screen coverage using screen dimensions including status bar
        function setFullScreen() {
            // Use screen dimensions which include status bar area
            var screenHeight = window.screen.height;
            var screenWidth = window.screen.width;
            var outerHeight = window.outerHeight || screenHeight;
            var outerWidth = window.outerWidth || screenWidth;
            
            // Use maximum to ensure we cover status bar area
            var fullHeight = Math.max(screenHeight, outerHeight, window.innerHeight);
            var fullWidth = Math.max(screenWidth, outerWidth, window.innerWidth);
            
            // Set document dimensions
            document.documentElement.style.width = fullWidth + 'px';
            document.documentElement.style.height = fullHeight + 'px';
            document.documentElement.style.minHeight = fullHeight + 'px';
            document.documentElement.style.margin = '0';
            document.documentElement.style.padding = '0';
            document.documentElement.style.position = 'fixed';
            document.documentElement.style.top = '0';
            document.documentElement.style.left = '0';
            document.documentElement.style.right = '0';
            document.documentElement.style.bottom = '0';
            
            // Set body dimensions
            document.body.style.width = fullWidth + 'px';
            document.body.style.height = fullHeight + 'px';
            document.body.style.minHeight = fullHeight + 'px';
            document.body.style.margin = '0';
            document.body.style.padding = '0';
            document.body.style.position = 'fixed';
            document.body.style.top = '0';
            document.body.style.left = '0';
            document.body.style.right = '0';
            document.body.style.bottom = '0';
            
            // Set container dimensions
            var container = document.querySelector('.video-container');
            if (container) {
                container.style.width = fullWidth + 'px';
                container.style.height = fullHeight + 'px';
                container.style.minHeight = fullHeight + 'px';
                container.style.position = 'fixed';
                container.style.top = '0';
                container.style.left = '0';
                container.style.right = '0';
                container.style.bottom = '0';
                container.style.margin = '0';
                container.style.padding = '0';
            }
        }
        
        // Apply immediately and on multiple intervals to ensure it sticks
        setFullScreen();
        setTimeout(setFullScreen, 50);
        setTimeout(setFullScreen, 100);
        setTimeout(setFullScreen, 300);
        setTimeout(setFullScreen, 500);
        setTimeout(setFullScreen, 1000);
        
        window.addEventListener('resize', setFullScreen);
        window.addEventListener('orientationchange', function() {
            setTimeout(setFullScreen, 50);
            setTimeout(setFullScreen, 200);
        });
        
        // Also try on load
        window.addEventListener('load', setFullScreen);
        if (document.readyState === 'complete') {
            setFullScreen();
        }
    })();
    """
    
    private let session: VideoCallSession
    
    init(session: VideoCallSession) {
        self.session = session
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == Self.messageHandlerName,
              let body = message.body as? [String: Any] else { return }
        session.handleMessage(body)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Request camera + mic so WKWebView getUserMedia sees granted state (especially camera)
        session.requestCameraAndMicrophonePermissionIfNeeded()

        // Force full screen again after page load including status bar area
        let js = """
        (function() {
            // Use screen dimensions which include status bar
            var screenHeight = window.screen.height;
            var screenWidth = window.screen.width;
            var outerHeight = window.outerHeight || screenHeight;
            var outerWidth = window.outerWidth || screenWidth;
            
            // Use the larger dimension to ensure we cover status bar
            var fullHeight = Math.max(screenHeight, outerHeight, window.innerHeight);
            var fullWidth = Math.max(screenWidth, outerWidth, window.innerWidth);
            
            var d = document.documentElement, b = document.body;
            var style = 'margin:0;padding:0;width:'+fullWidth+'px;height:'+fullHeight+'px;min-height:'+fullHeight+'px;overflow:hidden;position:fixed;top:0;left:0;right:0;bottom:0;';
            d.style.cssText = style;
            if (b) b.style.cssText = style;
            
            var c = document.querySelector('.video-container');
            if (c) {
                c.style.width = fullWidth + 'px';
                c.style.height = fullHeight + 'px';
                c.style.minHeight = fullHeight + 'px';
                c.style.position = 'fixed';
                c.style.top = '0';
                c.style.left = '0';
                c.style.right = '0';
                c.style.bottom = '0';
                c.style.margin = '0';
                c.style.padding = '0';
            }
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)

        // Show caller name/photo as soon as page loads (from videoCallView payload: receiverName = contact fullName)
        session.sendCallerInfoToWebViewIfNeeded()

        // Start local stream after page is ready (page also runs at 600ms; guard in JS prevents double init)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak webView] in
            guard let webView else { return }
            let startStreamJS = "if (typeof startLocalStreamWithRetry === 'function') { startLocalStreamWithRetry(0); } else if (typeof initializeLocalStream === 'function') { initializeLocalStream().catch(function(){}); }"
            webView.evaluateJavaScript(startStreamJS) { _, error in
                if let error = error {
                    print("⚠️ [VideoCallScreen] Failed to trigger startLocalStreamWithRetry: \(error.localizedDescription)")
                } else {
                    print("📹 [VideoCallScreen] Triggered startLocalStreamWithRetry after page load")
                }
            }
        }
    }
    
    @available(iOS 15.0, *)
    func webView(_ webView: WKWebView,
                 requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo,
                 type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        let typeLabel: String
        switch type {
        case .camera:
            typeLabel = "camera"
        case .microphone:
            typeLabel = "microphone"
        case .cameraAndMicrophone:
            typeLabel = "cameraAndMicrophone"
        @unknown default:
            typeLabel = "unknown"
        }
        print("📹 [VideoCallScreen] Media capture permission requested - type: \(typeLabel)")
        
        func complete(_ decision: WKPermissionDecision) {
            DispatchQueue.main.async {
                decisionHandler(decision)
            }
        }

        let audioSession = AVAudioSession.sharedInstance()
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let micStatus = audioSession.recordPermission

        func grantIfPossible() {
            let cameraOK = (cameraStatus == .authorized)
            let micOK = (micStatus == .granted)
            if type == .camera {
                complete(cameraOK ? .grant : .deny)
            } else if type == .microphone {
                complete(micOK ? .grant : .deny)
            } else if type == .cameraAndMicrophone {
                complete((cameraOK && micOK) ? .grant : .deny)
            } else {
                complete(.deny)
            }
        }

        // Fast path
        if type == .camera {
            if cameraStatus == .authorized {
                print("✅ [VideoCallScreen] Camera permission granted")
                complete(.grant)
                return
            }
        } else if type == .microphone {
            if micStatus == .granted {
                print("✅ [VideoCallScreen] Microphone permission granted")
                complete(.grant)
                return
            }
        } else if type == .cameraAndMicrophone {
            if cameraStatus == .authorized, micStatus == .granted {
                print("✅ [VideoCallScreen] Camera+Microphone permissions granted")
                complete(.grant)
                return
            }
        }

        // Request missing permissions and then decide.
        func requestMic(_ done: @escaping () -> Void) {
            if audioSession.recordPermission == .undetermined {
                audioSession.requestRecordPermission { granted in
                    print("🎤 [VideoCallScreen] Microphone permission result: \(granted)")
                    DispatchQueue.main.async { done() }
                }
            } else {
                done()
            }
        }

        func requestCamera(_ done: @escaping () -> Void) {
            if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    print("📹 [VideoCallScreen] Camera permission result: \(granted)")
                    DispatchQueue.main.async { done() }
                }
            } else {
                done()
            }
        }

        if type == .camera {
            requestCamera {
                let status = AVCaptureDevice.authorizationStatus(for: .video)
                if status == .authorized {
                    print("✅ [VideoCallScreen] Camera permission granted")
                    complete(.grant)
                } else {
                    print("⚠️ [VideoCallScreen] Camera denied (status: \(status.rawValue))")
                    complete(.deny)
                }
            }
            return
        }

        if type == .microphone {
            requestMic {
                let status = AVAudioSession.sharedInstance().recordPermission
                if status == .granted {
                    print("✅ [VideoCallScreen] Microphone permission granted")
                    complete(.grant)
                } else {
                    print("⚠️ [VideoCallScreen] Microphone denied")
                    complete(.deny)
                }
            }
            return
        }

        if type == .cameraAndMicrophone {
            requestCamera {
                requestMic {
                    let cam = AVCaptureDevice.authorizationStatus(for: .video)
                    let mic = AVAudioSession.sharedInstance().recordPermission
                    let ok = (cam == .authorized && mic == .granted)
                    if ok {
                        print("✅ [VideoCallScreen] Camera+Microphone permissions granted")
                    } else {
                        print("⚠️ [VideoCallScreen] Camera+Microphone not granted (camera=\(cam.rawValue), mic=\(mic.rawValue))")
                    }
                    complete(ok ? .grant : .deny)
                }
            }
            return
        }

        grantIfPossible()
    }
}

// Direct UIViewControllerRepresentable that embeds WebView without SwiftUI wrapper
struct FullScreenVideoCallViewControllerRepresentable: UIViewControllerRepresentable {
    @ObservedObject var session: VideoCallSession
    
    func makeUIViewController(context: Context) -> FullScreenVideoCallViewController {
        let controller = FullScreenVideoCallViewController()
        controller.session = session
        return controller
    }
    
    func updateUIViewController(_ uiViewController: FullScreenVideoCallViewController, context: Context) {
        // Update if needed
    }
}

class FullScreenVideoCallViewController: UIViewController {
    var session: VideoCallSession?
    private var webView: WKWebView?
    
    /// Status bar height (safe area top) so we can extend content under it.
    private var statusBarHeight: CGFloat {
        var top: CGFloat = 0
        if #available(iOS 11.0, *) {
            top = view.safeAreaInsets.top
            if top <= 0, let w = view.window { top = w.safeAreaInsets.top }
            if top <= 0 {
                let keyWindow = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .flatMap { $0.windows }
                    .first { $0.isKeyWindow }
                top = keyWindow?.safeAreaInsets.top ?? 0
            }
            if top <= 0 { top = 47 }
        } else {
            top = 20
        }
        return top
    }
    
    /// Full-screen frame for WebView: extends under status bar (negative Y) so bg_blur and video fill the top.
    private func webViewFullScreenFrame() -> CGRect {
        let screenBounds = UIScreen.main.bounds
        let topInset = statusBarHeight
        let y: CGFloat = -topInset
        let h: CGFloat = screenBounds.height + topInset
        return CGRect(x: 0, y: y, width: screenBounds.width, height: h)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        // Allow WebView to draw above view bounds (under status bar)
        view.clipsToBounds = false
        
        // Extend under status bar and home indicator
        if #available(iOS 11.0, *) {
            additionalSafeAreaInsets = .zero
            view.insetsLayoutMarginsFromSafeArea = false
            edgesForExtendedLayout = .all
            if #available(iOS 13.0, *) {
                view.overrideUserInterfaceStyle = .dark
            }
        }
        
        let screenBounds = UIScreen.main.bounds
        view.frame = CGRect(x: 0, y: 0, width: screenBounds.width, height: screenBounds.height)
        
        setupWebView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if #available(iOS 11.0, *) {
            view.insetsLayoutMarginsFromSafeArea = false
            edgesForExtendedLayout = .all
            additionalSafeAreaInsets = .zero
        }
        let screenBounds = UIScreen.main.bounds
        view.frame = CGRect(x: 0, y: 0, width: screenBounds.width, height: screenBounds.height)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let webView = webView {
            webView.frame = webViewFullScreenFrame()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let webView = webView else { return }
        
        // Position WebView so it extends UNDER the status bar (negative y) — fills white strip with bg_blur/video
        webView.frame = webViewFullScreenFrame()
        
        // Also inject JavaScript to force full screen including status bar area
        let js = """
        (function() {
            // Use screen dimensions which include status bar
            var screenHeight = window.screen.height;
            var screenWidth = window.screen.width;
            var outerHeight = window.outerHeight || screenHeight;
            var outerWidth = window.outerWidth || screenWidth;
            
            // Use the larger of screen height or outer height to ensure we cover status bar
            var fullHeight = Math.max(screenHeight, outerHeight, window.innerHeight);
            var fullWidth = Math.max(screenWidth, outerWidth, window.innerWidth);
            
            // Set document to full screen dimensions
            document.documentElement.style.width = fullWidth + 'px';
            document.documentElement.style.height = fullHeight + 'px';
            document.documentElement.style.minHeight = fullHeight + 'px';
            document.documentElement.style.margin = '0';
            document.documentElement.style.padding = '0';
            document.documentElement.style.position = 'fixed';
            document.documentElement.style.top = '0';
            document.documentElement.style.left = '0';
            document.documentElement.style.right = '0';
            document.documentElement.style.bottom = '0';
            
            // Set body to full screen dimensions
            document.body.style.width = fullWidth + 'px';
            document.body.style.height = fullHeight + 'px';
            document.body.style.minHeight = fullHeight + 'px';
            document.body.style.margin = '0';
            document.body.style.padding = '0';
            document.body.style.position = 'fixed';
            document.body.style.top = '0';
            document.body.style.left = '0';
            document.body.style.right = '0';
            document.body.style.bottom = '0';
            
            // Set container to full screen dimensions
            var container = document.querySelector('.video-container');
            if (container) {
                container.style.width = fullWidth + 'px';
                container.style.height = fullHeight + 'px';
                container.style.minHeight = fullHeight + 'px';
                container.style.position = 'fixed';
                container.style.top = '0';
                container.style.left = '0';
                container.style.right = '0';
                container.style.bottom = '0';
                container.style.margin = '0';
                container.style.padding = '0';
            }
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            if let webView = self.webView {
                webView.frame = self.webViewFullScreenFrame()
            }
        })
    }
    
    private func setupWebView() {
        guard let session = session else { return }
    
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        if #available(iOS 14.0, *) {
            let prefs = WKWebpagePreferences()
            prefs.allowsContentJavaScript = true
            configuration.defaultWebpagePreferences = prefs
        }
        if #available(iOS 15.0, *) {
            configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        
        let controller = WKUserContentController()
        let coordinator = VideoCallWebViewCoordinator(session: session)
        controller.add(coordinator, name: "videoCall")
        
        let bridgeScript = WKUserScript(
            source: VideoCallWebViewCoordinator.bridgeScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        controller.addUserScript(bridgeScript)
        
        // Inject at document start: force html/body full screen before first paint including status bar
        let fullScreenStartScript = WKUserScript(
            source: """
            (function() {
                var d = document.documentElement;
                var b = document.body;
                var style = 'margin:0;padding:0;width:100%;height:100%;min-height:100%;overflow:hidden;position:fixed;top:0;left:0;right:0;bottom:0;';
                d.style.cssText = style;
                if (b) b.style.cssText = style;
                var setSize = function() {
                    // Use screen dimensions which include status bar area
                    var screenH = window.screen.height;
                    var screenW = window.screen.width;
                    var outerH = window.outerHeight || screenH;
                    var outerW = window.outerWidth || screenW;
                    
                    // Use maximum to ensure we cover status bar
                    var w = Math.max(screenW, outerW, window.innerWidth || document.documentElement.clientWidth);
                    var h = Math.max(screenH, outerH, window.innerHeight || document.documentElement.clientHeight);
                    
                    d.style.width = w + 'px';
                    d.style.height = h + 'px';
                    d.style.minHeight = h + 'px';
                    if (b) {
                        b.style.width = w + 'px';
                        b.style.height = h + 'px';
                        b.style.minHeight = h + 'px';
                    }
                };
                setSize();
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        controller.addUserScript(fullScreenStartScript)
        
        // Inject CSS to fix background-image and ensure full screen coverage
        let cssFixScript = WKUserScript(
            source: VideoCallWebViewCoordinator.cssFixScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        controller.addUserScript(cssFixScript)
        
        configuration.userContentController = controller
        
        // Use window bounds if available, otherwise view bounds
        let webViewFrame: CGRect
        if let window = view.window {
            webViewFrame = window.bounds
        } else {
            webViewFrame = view.bounds
        }
        
        let webView = WKWebView(frame: webViewFrame, configuration: configuration)
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        webView.scrollView.backgroundColor = UIColor.clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.contentInset = .zero
        webView.scrollView.scrollIndicatorInsets = .zero
        
        // Disable safe area insets completely
        if #available(iOS 11.0, *) {
            webView.scrollView.contentInsetAdjustmentBehavior = .never
            webView.scrollView.insetsLayoutMarginsFromSafeArea = false
        }
        
        view.addSubview(webView)
        
        // Extend WebView under status bar (negative y) so bg_blur and video fill the top
        webView.frame = webViewFullScreenFrame()
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        session.attach(webView: webView)
        self.webView = webView
        
        // Request camera/mic before loading so WKWebView getUserMedia sees granted permissions
        session.requestCameraAndMicrophonePermissionIfNeeded()
        
        // Load via file URL so the page has a proper origin (required for getUserMedia on iOS)
        let assetURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "VoiceCallAssets")
            ?? Bundle.main.url(forResource: "index", withExtension: "html")
        
        if let url = assetURL {
            let baseDir = url.deletingLastPathComponent()
            // Grant read access only to VoiceCallAssets dir to avoid sandbox "no access" / unresponsive WebContent
            webView.loadFileURL(url, allowingReadAccessTo: baseDir)
        } else {
            let fallbackHTML = """
            <!doctype html>
            <html>
            <head><meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover"></head>
            <body style="margin:0;padding:0;width:100%;height:100%;overflow:hidden;background:#000;color:#fff;font-family:-apple-system;">
              Video call assets not found.
            </body>
            </html>
            """
            webView.loadHTMLString(fallbackHTML, baseURL: nil)
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .fade
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return false
    }
    
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return []
    }
}
