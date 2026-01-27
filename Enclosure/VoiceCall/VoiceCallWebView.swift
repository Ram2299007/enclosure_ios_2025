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
            decisionHandler(.grant)
        }
    }
}
