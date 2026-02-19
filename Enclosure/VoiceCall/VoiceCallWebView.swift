import SwiftUI
import WebKit

struct VoiceCallWebView: UIViewRepresentable {
    @ObservedObject var session: VoiceCallSession

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // CRITICAL: Enable getUserMedia() for WebRTC microphone access
        configuration.allowsPictureInPictureMediaPlayback = true
        if #available(iOS 14.3, *) {
            configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        }

        let controller = WKUserContentController()
        controller.add(context.coordinator, name: Coordinator.messageHandlerName)

        let bridgeScript = WKUserScript(
            source: Coordinator.bridgeScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        controller.addUserScript(bridgeScript)
        configuration.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = true
        webView.backgroundColor = UIColor.black
        webView.scrollView.backgroundColor = UIColor.black
        
        // Log WebView configuration for debugging
        NSLog("🎤 [VoiceCallWebView] WebView created with microphone permissions")
        print("🎤 [VoiceCallWebView] allowsInlineMediaPlayback: true")
        print("🎤 [VoiceCallWebView] mediaTypesRequiringUserActionForPlayback: []")

        session.attach(webView: webView)

        let assetURL = Bundle.main.url(forResource: "indexVoice", withExtension: "html", subdirectory: "VoiceCallAssets")
            ?? Bundle.main.url(forResource: "indexVoice", withExtension: "html")
        
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
              Voice call assets not found.
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
        static let messageHandlerName = "voiceCall"
        static let bridgeScript = """
        window.__muteState = window.__muteState || false;
        window.Android = {
          logToNative: function(message) {
            try { window.webkit.messageHandlers.voiceCall.postMessage({type: 'logToNative', message: message}); } catch (e) {}
          },
          isWifiConnected: function() {
            try { window.webkit.messageHandlers.voiceCall.postMessage({type: 'isWifiConnected'}); } catch (e) {}
            return true;
          },
          setAudioOutput: function(output) {
            window.webkit.messageHandlers.voiceCall.postMessage({type: 'setAudioOutput', output: output});
          },
          toggleMicrophone: function(mute) {
            window.webkit.messageHandlers.voiceCall.postMessage({type: 'toggleMicrophone', mute: mute});
          },
          saveMuteState: function(mute) {
            window.__muteState = !!mute;
            window.webkit.messageHandlers.voiceCall.postMessage({type: 'saveMuteState', mute: mute});
          },
          getMuteState: function() {
            return !!window.__muteState;
          },
          sendPeerId: function(peerId) {
            window.webkit.messageHandlers.voiceCall.postMessage({type: 'sendPeerId', peerId: peerId});
          },
          checkBluetoothAvailability: function() {
            window.webkit.messageHandlers.voiceCall.postMessage({type: 'checkBluetoothAvailability'});
          },
          onPeerConnected: function() {
            window.webkit.messageHandlers.voiceCall.postMessage({type: 'onPeerConnected'});
          },
          onCallConnected: function() {
            window.webkit.messageHandlers.voiceCall.postMessage({type: 'onCallConnected'});
          },
          sendBroadcast: function(action) {
            window.webkit.messageHandlers.voiceCall.postMessage({type: 'sendBroadcast', action: action});
          },
          endCall: function() {
            window.webkit.messageHandlers.voiceCall.postMessage({type: 'endCall'});
          },
          callOnBackPressed: function() {
            window.webkit.messageHandlers.voiceCall.postMessage({type: 'callOnBackPressed'});
          },
          addMemberBtn: function() {
            window.webkit.messageHandlers.voiceCall.postMessage({type: 'addMemberBtn'});
          },
          onPageReady: function() {
            window.webkit.messageHandlers.voiceCall.postMessage({type: 'onPageReady'});
          },
          testInterface: function() {
            window.webkit.messageHandlers.voiceCall.postMessage({type: 'testInterface'});
          },
          sendRejoinSignal: function(uid) {
            window.webkit.messageHandlers.voiceCall.postMessage({type: 'sendRejoinSignal', uid: uid});
          },
          setSpeakerphoneOn: function(enabled) {
            window.webkit.messageHandlers.voiceCall.postMessage({type: 'setSpeakerphoneOn', enabled: enabled});
          },
          sendSignaling: function(jsonString) {
            window.webkit.messageHandlers.voiceCall.postMessage({type: 'sendSignaling', data: jsonString});
          }
        };
        """

        private let session: VoiceCallSession

        init(session: VoiceCallSession) {
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
            NSLog("🎤🎤🎤 [VoiceCallWebView] ========================================")
            NSLog("🎤 [VoiceCallWebView] Media capture permission requested (iOS 15+)")
            NSLog("🎤 [VoiceCallWebView] Type: \(type.rawValue)")
            NSLog("🎤 [VoiceCallWebView] Origin: \(origin)")
            NSLog("🎤 [VoiceCallWebView] GRANTING permission")
            NSLog("🎤🎤🎤 [VoiceCallWebView] ========================================")
            
            print("🎤 [VoiceCallWebView] Granting media capture permission for type: \(type.rawValue)")
            decisionHandler(.grant)
        }
        
        // For iOS 14 and earlier
        func webView(_ webView: WKWebView,
                     runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping () -> Void) {
            NSLog("📱 [VoiceCallWebView] JavaScript alert: \(message)")
            completionHandler()
        }
        
        func webView(_ webView: WKWebView,
                     didFinish navigation: WKNavigation!) {
            NSLog("📱 [VoiceCallWebView] Page loaded successfully")
            print("📱 [VoiceCallWebView] indexVoice.html loaded - WebRTC should initialize")
            
            // Ensure JavaScript execution is allowed
            webView.evaluateJavaScript("typeof Android !== 'undefined'") { result, error in
                if let error = error {
                    NSLog("❌ [VoiceCallWebView] Android bridge check failed: \(error.localizedDescription)")
                } else if let isAvailable = result as? Bool, isAvailable {
                    NSLog("✅ [VoiceCallWebView] Android bridge available")
                    print("✅ [VoiceCallWebView] JavaScript bridge ready for WebRTC")
                } else {
                    NSLog("⚠️ [VoiceCallWebView] Android bridge not found")
                }
            }
            
            // Check getUserMedia() availability
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                webView.evaluateJavaScript("typeof navigator.mediaDevices !== 'undefined' && typeof navigator.mediaDevices.getUserMedia !== 'undefined'") { result, error in
                    if let error = error {
                        NSLog("❌ [VoiceCallWebView] getUserMedia check failed: \(error.localizedDescription)")
                    } else if let isAvailable = result as? Bool, isAvailable {
                        NSLog("✅✅✅ [VoiceCallWebView] getUserMedia() available - microphone can be captured")
                        print("✅ [VoiceCallWebView] WebRTC getUserMedia() supported")
                    } else {
                        NSLog("❌ [VoiceCallWebView] getUserMedia() NOT available - microphone won't work!")
                    }
                }
                
                // Check if microphone is muted
                webView.evaluateJavaScript("window.Android && window.Android.getMuteState ? window.Android.getMuteState() : false") { result, error in
                    if let isMuted = result as? Bool {
                        if isMuted {
                            NSLog("⚠️⚠️⚠️ [VoiceCallWebView] MICROPHONE IS MUTED!")
                            print("⚠️ [VoiceCallWebView] Mic is muted - Android won't hear audio")
                        } else {
                            NSLog("✅ [VoiceCallWebView] Microphone is NOT muted")
                            print("✅ [VoiceCallWebView] Mic unmuted - should send audio")
                        }
                    }
                }
            }
        }
        
        func webView(_ webView: WKWebView,
                     didFail navigation: WKNavigation!,
                     withError error: Error) {
            NSLog("❌ [VoiceCallWebView] Page load failed: \(error.localizedDescription)")
        }
    }
}
