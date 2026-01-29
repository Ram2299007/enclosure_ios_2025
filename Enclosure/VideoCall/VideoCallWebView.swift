import SwiftUI
import WebKit

struct VideoCallWebView: UIViewRepresentable {
    @ObservedObject var session: VideoCallSession

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let controller = WKUserContentController()
        controller.add(context.coordinator, name: Coordinator.messageHandlerName)

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

        let assetURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "VoiceCallAssets")
            ?? Bundle.main.url(forResource: "index", withExtension: "html")
        
        if let url = assetURL {
            if let html = try? String(contentsOf: url, encoding: .utf8) {
                webView.loadHTMLString(html, baseURL: url.deletingLastPathComponent())
            } else {
                webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            }
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
            `;
            document.head.appendChild(style);
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

        @available(iOS 15.0, *)
        func webView(_ webView: WKWebView,
                     requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                     initiatedByFrame frame: WKFrameInfo,
                     type: WKMediaCaptureType,
                     decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            decisionHandler(.grant)
        }
    }
}
