import SwiftUI
import WebKit

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var isPressed = false
    
    // Privacy Policy URLs - exactly like Android
    private var privacyPolicyURL: String {
        // Dark mode: black_policy, Light mode: white_policy (same as Android)
        return colorScheme == .dark 
            ? "https://enclosureapp.com/black_policy"
            : "https://enclosureapp.com/white_policy"
    }
    
    // Helper function to hide keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    var body: some View {
        ZStack {
            // Android-style background
            Color("background_color")
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    hideKeyboard()
                }
            
            VStack(spacing: 0) {
                // Custom Android-style toolbar
                androidToolbar
                
                // WebView Content
                ZStack {
                    // Background to prevent any white flashing
                    Color("background_color")
                        .ignoresSafeArea()
                    
                    // WebView - always present to allow loading
                    WebView(url: privacyPolicyURL)
                        .id(colorScheme) // Force recreation only when color scheme changes
                        .background(Color("background_color"))
                        .padding(.top, 40)
                }
            }
        }
        .navigationBarHidden(true)
        .background(NavigationGestureEnabler())
        .onAppear {
            // WebView will handle loading automatically
            print("🔵 PrivacyPolicyView appeared, loading URL: \(privacyPolicyURL)")
        }
    }
    
    // MARK: - Android-style Toolbar
    private var androidToolbar: some View {
        HStack {
            // Back button - same as SettingsView
            Button(action: handleBackTap) {
                ZStack {
                    if isPressed {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 40, height: 40)
                            .scaleEffect(isPressed ? 1.2 : 1.0)
                            .animation(.easeOut(duration: 0.3), value: isPressed)
                    }

                    Image("leftvector")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 25, height: 18)
                        .foregroundColor(Color("icontintGlobal"))
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { _ in
                        withAnimation {
                            isPressed = false
                        }
                    }
            )
            .buttonStyle(.plain)
            
            // Title
            Text("Privacy Policy")
                .font(.custom("Inter18pt-Medium", size: 16))
                .foregroundColor(Color("TextColor"))
                .fontWeight(.medium)
                .lineSpacing(24)
                .padding(.leading, 6)
            
            Spacer()
        }
        .padding(.top, 0)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color("background_color"))
    }
    
    // MARK: - Functions
    private func handleBackTap() {
        withAnimation {
            isPressed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            dismiss()
            isPressed = false
        }
    }
}


// MARK: - WebView Component
struct WebView: UIViewRepresentable {
    let url: String
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptEnabled = true
        
        // Enable cache memory for better performance
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        configuration.processPool = WKProcessPool()
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
        // Enable caching
        webView.configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        webView.allowsBackForwardNavigationGestures = false
        
        // Disable WebView's internal loading indicators to prevent double progress bars
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        
        // Disable WebView's built-in progress view
        if #available(iOS 15.0, *) {
            webView.configuration.preferences.setValue(false, forKey: "developerExtrasEnabled")
        }
        
        // Set background color based on theme (like Android) and prevent white flashing
        if context.environment.colorScheme == .dark {
            webView.backgroundColor = UIColor.black
            webView.scrollView.backgroundColor = UIColor.black
            webView.underPageBackgroundColor = UIColor.black
        } else {
            // Use our custom light color #F6F7FF
            let customLightColor = UIColor(red: 0xF6/255, green: 0xF7/255, blue: 0xFF/255, alpha: 1.0)
            webView.backgroundColor = customLightColor
            webView.scrollView.backgroundColor = customLightColor
            webView.underPageBackgroundColor = customLightColor
        }
        
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.isOpaque = false // Set to false to prevent white flashing
        webView.scrollView.bounces = false
        
        
        // Load the initial URL with cache policy
        if let url = URL(string: url) {
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad // Use cache if available
            request.timeoutInterval = 30.0
            print("🔵 Loading WebView URL: \(url)")
            webView.load(request)
        } else {
            print("❌ Invalid URL: \(url)")
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        
        // Only update if the URL actually changed to prevent unnecessary reloads
        let currentURL = webView.url?.absoluteString
        if currentURL != url {
            // Update background color when theme changes
            if context.environment.colorScheme == .dark {
                webView.backgroundColor = UIColor.black
                webView.scrollView.backgroundColor = UIColor.black
                webView.underPageBackgroundColor = UIColor.black
            } else {
                // Use our custom light color #F6F7FF
                let customLightColor = UIColor(red: 0xF6/255, green: 0xF7/255, blue: 0xFF/255, alpha: 1.0)
                webView.backgroundColor = customLightColor
                webView.scrollView.backgroundColor = customLightColor
                webView.underPageBackgroundColor = customLightColor
            }
            
            // Load new URL only if it's different
            if let newURL = URL(string: url) {
                var request = URLRequest(url: newURL)
                request.cachePolicy = .returnCacheDataElseLoad // Use cache if available
                request.timeoutInterval = 30.0
                webView.load(request)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("🔵 WebView started loading: \(webView.url?.absoluteString ?? "unknown")")
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ WebView finished loading: \(webView.url?.absoluteString ?? "unknown")")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView navigation failed: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            // Don't log cancelled errors (code -999) as they're expected during theme changes
            if nsError.code != NSURLErrorCancelled {
                print("❌ WebView provisional navigation failed: \(error.localizedDescription)")
            }
        }
        
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            print("🔄 WebView committed navigation: \(webView.url?.absoluteString ?? "unknown")")
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Allow all navigation (like Android WebViewClient)
            decisionHandler(.allow)
        }
    }
}



struct PrivacyPolicyView_Previews: PreviewProvider {
    static var previews: some View {
        PrivacyPolicyView()
    }
}
