import SwiftUI
import WebKit
import AVFoundation

struct VideoCallWebView: UIViewRepresentable {
    @ObservedObject var session: VideoCallSession

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // Enable media capture permissions for camera and microphone
        if #available(iOS 15.0, *) {
            configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        
        // Set preferences for media capture
        let preferences = WKWebpagePreferences()
        if #available(iOS 14.0, *) {
            preferences.allowsContentJavaScript = true
        }
        configuration.defaultWebpagePreferences = preferences

        let controller = WKUserContentController()
        controller.add(context.coordinator, name: Coordinator.messageHandlerName)
        controller.add(context.coordinator, name: "jsConsole")

        let bridgeScript = WKUserScript(
            source: Coordinator.bridgeScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        controller.addUserScript(bridgeScript)
        
        // Inject CSS to fix background-image and ensure full screen coverage
        let cssFixScript = WKUserScript(
            source: Coordinator.cssFixScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        controller.addUserScript(cssFixScript)
        
        configuration.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        webView.scrollView.backgroundColor = UIColor.clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.contentInset = .zero
        webView.scrollView.scrollIndicatorInsets = .zero

        session.attach(webView: webView)

        // Load via file URL so the page has a proper origin (required for getUserMedia on iOS)
        let assetURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "VoiceCallAssets")
            ?? Bundle.main.url(forResource: "index", withExtension: "html")
        
        if let url = assetURL {
            let baseDir = url.deletingLastPathComponent()
            // Allow read access to bundle root so all assets (script.js, peerjs.js, etc.) load
            let readAccessURL = baseDir.deletingLastPathComponent()
            webView.loadFileURL(url, allowingReadAccessTo: readAccessURL)
        } else {
            let fallbackHTML = """
            <!doctype html>
            <html>
            <head><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
            <body style="margin:0;display:flex;align-items:center;justify-content:center;background:#000;color:#fff;font-family:-apple-system;">
              Video call assets not found.
            </body>
            </html>
            """
            webView.loadHTMLString(fallbackHTML, baseURL: nil)
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        session.attach(webView: uiView)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate {
        static let messageHandlerName = "videoCall"
        static let bridgeScript = """
        // Intercept console.log/warn/error and forward to native
        (function() {
          var origLog = console.log, origWarn = console.warn, origErr = console.error;
          function send(level, args) {
            try {
              var msg = Array.prototype.slice.call(args).map(function(a) {
                return typeof a === 'object' ? JSON.stringify(a) : String(a);
              }).join(' ');
              window.webkit.messageHandlers.jsConsole.postMessage({level: level, message: msg});
            } catch(e) {}
          }
          console.log = function() { send('log', arguments); origLog.apply(console, arguments); };
          console.warn = function() { send('warn', arguments); origWarn.apply(console, arguments); };
          console.error = function() { send('error', arguments); origErr.apply(console, arguments); };
        })();
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
            style.textContent = `
                html, body {
                    margin: 0 !important;
                    padding: 0 !important;
                    width: 100% !important;
                    height: 100% !important;
                    overflow: hidden !important;
                    background-image: url('bg_blur.webp') !important;
                    background-repeat: no-repeat !important;
                    background-position: center center !important;
                    background-attachment: fixed !important;
                    background-size: cover !important;
                    background-color: #000 !important;
                    position: fixed !important;
                    top: 0 !important;
                    left: 0 !important;
                    right: 0 !important;
                    bottom: 0 !important;
                }
                .video-container {
                    width: 100vw !important;
                    height: 100vh !important;
                    min-height: 100vh !important;
                    max-height: 100vh !important;
                    background-image: url('bg_blur.webp') !important;
                    background-repeat: no-repeat !important;
                    background-position: center center !important;
                    background-attachment: fixed !important;
                    background-size: cover !important;
                    background-color: #000 !important;
                    position: fixed !important;
                    top: 0 !important;
                    left: 0 !important;
                    right: 0 !important;
                    bottom: 0 !important;
                    overflow: hidden !important;
                }
                .controls-container {
                    bottom: 65px !important;
                    max-width: 100vw !important;
                    box-sizing: border-box !important;
                    overflow: visible !important;
                }
                .top-bar {
                    top: calc(env(safe-area-inset-top, 0) + 50px) !important;
                    gap: 10px !important;
                }
            `;
            document.head.appendChild(style);
            
            // Ensure controls container stays within viewport
            function ensureControlsInBounds() {
                var container = document.querySelector('.controls-container');
                if (container) {
                    var safeAreaBottom = getComputedStyle(document.documentElement).getPropertyValue('env(safe-area-inset-bottom)') || '0px';
                    var bottomInset = parseInt(safeAreaBottom) || 0;
                    var viewportHeight = window.innerHeight || window.screen.height;
                    var containerRect = container.getBoundingClientRect();
                    
                    if (containerRect.bottom > viewportHeight) {
                        container.style.bottom = '65px';
                        container.style.paddingBottom = Math.max(bottomInset, 10) + 'px';
                    }
                }
            }
            
            // Run on load and resize
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', ensureControlsInBounds);
            } else {
                ensureControlsInBounds();
            }
            window.addEventListener('resize', ensureControlsInBounds);
        })();
        """

        private let session: VideoCallSession

        init(session: VideoCallSession) {
            self.session = session
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "jsConsole",
               let body = message.body as? [String: Any],
               let level = body["level"] as? String,
               let msg = body["message"] as? String {
                let prefix = level == "error" ? "❌" : level == "warn" ? "⚠️" : "🌐"
                print("\(prefix) [JS] \(msg)")
                return
            }
            guard message.name == Self.messageHandlerName,
                  let body = message.body as? [String: Any] else { return }
            session.handleMessage(body)
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("📹 [VideoCallWebView] Page finished loading")
            // Native side handles media start via attemptStartLocalMedia → startLocalStreamWithRetry.
            // Do NOT call initializeLocalStream() here — it creates a NEW getUserMedia stream
            // that overwrites the one already connected to the peer, breaking remote video.
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
            print("📹 [VideoCallWebView] Media capture permission requested - type: \(typeLabel)")
            
            func complete(_ decision: WKPermissionDecision) {
                DispatchQueue.main.async {
                    decisionHandler(decision)
                }
            }

            let audioSession = AVAudioSession.sharedInstance()

            func requestMic(_ done: @escaping () -> Void) {
                if audioSession.recordPermission == .undetermined {
                    audioSession.requestRecordPermission { granted in
                        print("🎤 [VideoCallWebView] Microphone permission request result: \(granted)")
                        DispatchQueue.main.async { done() }
                    }
                } else {
                    done()
                }
            }

            func requestCamera(_ done: @escaping () -> Void) {
                if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
                    AVCaptureDevice.requestAccess(for: .video) { granted in
                        print("📹 [VideoCallWebView] Camera permission request result: \(granted)")
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
                        print("✅ [VideoCallWebView] Camera permission granted")
                        complete(.grant)
                    } else {
                        print("⚠️ [VideoCallWebView] Camera permission denied (status: \(status.rawValue))")
                        complete(.deny)
                    }
                }
                return
            }

            if type == .microphone {
                requestMic {
                    let status = AVAudioSession.sharedInstance().recordPermission
                    if status == .granted {
                        print("✅ [VideoCallWebView] Microphone permission granted")
                        complete(.grant)
                    } else {
                        print("⚠️ [VideoCallWebView] Microphone permission denied")
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
                            print("✅ [VideoCallWebView] Camera+Microphone permissions granted")
                        } else {
                            print("⚠️ [VideoCallWebView] Camera+Microphone not granted (camera=\(cam.rawValue), mic=\(mic.rawValue))")
                        }
                        complete(ok ? .grant : .deny)
                    }
                }
                return
            }

            complete(.deny)
        }
    }
}
