import SwiftUI
import UIKit

struct ThemeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedThemeColor: String = Constant.themeColor
    @State private var isPressed = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var isSubmitting = false
    @State private var iconChangeRetryCount = 0
    private let maxIconChangeRetries = 2
    
    // Theme colors mapping (matching Android)
    private let themeColors: [(color: String, name: String, logoImage: String)] = [
        ("#00A3E9", "default", "ec_modern"),
        ("#ff0080", "pink", "pinklogopng"),
        ("#7adf2a", "popati", "popatilogopng"),
        ("#ec0001", "red1", "redlogopng"),
        ("#16f3ff", "blue", "bluelogopng"),
        ("#FF8A00", "orange", "orangelogopng"),
        ("#7F7F7F", "faintblack", "graylogopng"),
        ("#D9B845", "yellow", "yellowlogopng"),
        ("#346667", "greensvg", "greenlogoppng"),
        ("#9846D9", "darkpink", "voiletlogopng"),
        ("#A81010", "red2", "red2logopng")
    ]
    
    // Background tint colors for dark mode (matching Android)
    private func getBackgroundTintColor(for color: String) -> Color {
        if colorScheme == .dark {
            switch color {
            case "#ff0080": return Color(hex: "#4D0026")
            case "#00A3E9": return Color(hex: "#01253B")
            case "#7adf2a": return Color(hex: "#25430D")
            case "#ec0001": return Color(hex: "#470000")
            case "#16f3ff": return Color(hex: "#05495D")
            case "#FF8A00": return Color(hex: "#663700")
            case "#7F7F7F": return Color(hex: "#2B3137")
            case "#D9B845": return Color(hex: "#413815")
            case "#346667": return Color(hex: "#1F3D3E")
            case "#9846D9": return Color(hex: "#2d1541")
            case "#A81010": return Color(hex: "#430706")
            default: return Color(hex: "#01253B")
            }
        } else {
            return Color(hex: "#011224")
        }
    }
    
    // Computed property for background tint: appThemeColor in light mode, darker tint in dark mode
    // Matching MainActivityOld.swift backgroundTintColor logic
    private var backgroundTintColor: Color {
        if colorScheme == .light {
            return Color("appThemeColor") // Use appThemeColor in light mode
        } else {
            return getBackgroundTintColor(for: selectedThemeColor) // Use darker tint in dark mode
        }
    }
    
    var body: some View {
        ZStack {
            Color("background_color")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Main content with preview
                ScrollView {
                    previewCardView
                        .padding(.horizontal, 16) // Give space so left/right shadow is visible
                        .padding(.top, 31)
                        .padding(.bottom, 30)
                }
                
                // Bottom theme selector and submit button
                bottomView
            }
        }
        .navigationBarHidden(true)
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            selectedThemeColor = Constant.themeColor
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
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
            
            Text("Themes")
                .font(.custom("Inter18pt-Medium", size: 16))
                .foregroundColor(Color("TextColor"))
                .fontWeight(.medium)
                .lineSpacing(24) // Equivalent to lineHeight
                .padding(.leading, 6)
            
            Spacer()
        }
        .padding(.top, 0)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
    
    private func handleBackTap() {
        withAnimation {
            isPressed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            dismiss()
            isPressed = false
        }
    }
    
    // MARK: - Preview Card View
    private var previewCardView: some View {
        VStack(spacing: 0) {
            // Top empty ImageView (matching Android - just for spacing)
            Color.clear
                .frame(height: 0)
            
            // Logo and search section (logoandsearch)
            VStack(spacing: 0) {
                // Top row with search icon and menu points
                HStack {
                    Spacer()
                    
                    // Search icon (15dp x 15dp, matching Android)
                    Image("search")
                        .resizable()
                        .frame(width: 15, height: 15)
                        .padding(.trailing, 5)
                    
                    // Menu points (matching Android menu LinearLayout)
                    VStack(spacing: 3) {
                        Circle()
                            .fill(Color("menuPointColor"))
                            .frame(width: 2.5, height: 2.5)
                        Circle()
                            .fill(Color(hex: selectedThemeColor))
                            .frame(width: 2.5, height: 2.5)
                        Circle()
                            .fill(Color(red: 0x9E/255, green: 0xA6/255, blue: 0xB9/255))
                            .frame(width: 2.5, height: 2.5)
                    }
                    .frame(width: 30)
                    .padding(.trailing, 5)
                }
                .padding(.top, 10)
                .padding(.trailing, 5)
                
                // Logo section (logoandmenu)
                HStack {
                    Image(getLogoImage(for: selectedThemeColor))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 42.75, height: 42.75)
                        .padding(.leading, 25)
                    
                    Spacer()
                }
                .padding(.top, 7)
            }
            
            // Main linear background (matching Android mainlinear)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image("downarrowslide")
                        .resizable()
                        .frame(width: 16, height: 16)
                        .padding(.trailing, 12)
                        .padding(.top,20)
                }
                Spacer()
            }
            .frame(height: 71)
            .background(
                Image("bg")
                    .renderingMode(.template)
                    .resizable()
                    .foregroundColor(backgroundTintColor)
            )
            .padding(.top, 3)
            
            // Sample chat list preview (matching Android ScrollView)
            ScrollView {
                VStack(spacing: 0) {
                    sampleChatItem(name: "Elmond Tesla", time: "7:01 am", message: "Good morning ☺️", showNotification: true, notificationCount: "1", timeColor: selectedThemeColor, avatarImage: "i")
                    sampleChatItem(name: "Jenny Wilson", time: "09:10 am", message: "Bye bye", showNotification: false, notificationCount: "", timeColor: "", avatarImage: "v")
                    sampleChatItem(name: "Darlene Robertson", time: "12:20 pm", message: "You have a new Image", showNotification: true, notificationCount: "94", timeColor: selectedThemeColor, avatarImage: "iv")
                    sampleChatItem(name: "Charlotte wolf", time: "06:00 pm", message: "How are you ?", showNotification: false, notificationCount: "", timeColor: "", avatarImage: "ii")
                    sampleChatItem(name: "Cameron Williamson", time: "08:34 am", message: "Hey,What's up ?", showNotification: true, notificationCount: "87", timeColor: selectedThemeColor, avatarImage: "iii")
                    sampleChatItem(name: "Annette Black", time: "05:00 am", message: "Work from office", showNotification: false, notificationCount: "", timeColor: "", avatarImage: "ix")
                    sampleChatItem(name: "Joey Banks", time: "09:55 am", message: "I am so happy and you.", showNotification: true, notificationCount: "65", timeColor: selectedThemeColor, avatarImage: "vii")
                    sampleChatItem(name: "Arlene Mcc", time: "01:06 am", message: "This is a document file .....", showNotification: false, notificationCount: "", timeColor: "", avatarImage: "vi")
                }
                .padding(.top, 8)
            }
        }
        .frame(width: 241.5, height: 490)
        .background(Color("BackgroundColor"))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Sample Chat Item
    private func sampleChatItem(name: String, time: String, message: String, showNotification: Bool, notificationCount: String, timeColor: String, avatarImage: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Avatar in CardView (matching Android CardView with circular image)
                ZStack {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 30, height: 30)
                    
                    Image(avatarImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 30, height: 30)
                        .clipShape(Circle())
                }
                .padding(.leading, 1)
                .padding(.trailing, 16)
                
                VStack(alignment: .leading, spacing: 0) {
                    // Name and time row
                    HStack {
                        Text(name)
                            .font(.custom("Inter18pt-Bold", size: 10))
                            .foregroundColor(Color("TextColor"))
                            .fontWeight(.semibold)
                            .lineSpacing(18 - 10) // lineHeight 18dp
                        
                        Spacer()
                        
                        Text(time)
                            .font(.custom("Inter18pt-Medium", size: 7))
                            .foregroundColor(timeColor.isEmpty ? Color("gray3") : Color(hex: timeColor))
                            .fontWeight(.semibold)
                            .lineSpacing(18 - 7) // lineHeight 18dp
                            .padding(.trailing, 8)
                    }
                    
                    // Message and notification row
                    HStack(spacing: 0) {
                        Text(message)
                            .font(.custom("Inter18pt-Medium", size: 8))
                            .foregroundColor(Color("gray3"))
                            .fontWeight(.medium)
                            .lineSpacing(18 - 8) // lineHeight 18dp
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        if showNotification {
                            ZStack {
                                // Dynamic notification background using theme color
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(Color(hex: selectedThemeColor))
                                    .frame(width: 26, height: 14)
                                
                                Text(notificationCount)
                                    .font(.custom("Inter", size: 7))
                                    .foregroundColor(.white)
                                    .lineSpacing(14.52 - 7) // lineHeight 14.52dp
                            }
                            .padding(.top, 3)
                        } else {
                            // Invisible notification placeholder to maintain layout
                            Color.clear
                                .frame(width: 26, height: 14)
                                .padding(.top, 3)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            
            // Invisible divider (matching Android View with visibility="invisible")
            Color.clear
                .frame(height: 0.5)
                .padding(.horizontal, 7)
                .padding(.top, 8)
        }
    }
    
    // MARK: - Bottom View
    private var bottomView: some View {
        VStack(spacing: 0) {
            // Horizontal scrollable theme colors
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(themeColors, id: \.color) { theme in
                        Button(action: {
                            // Haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            
                            selectedThemeColor = theme.color
                        }) {
                            // Theme color image - using placeholder names matching Android
                            Image(theme.name == "default" ? "mainthemesvg" : 
                                  theme.name == "pink" ? "pinksvg" :
                                  theme.name == "popati" ? "popati" :
                                  theme.name == "red1" ? "redsvg" :
                                  theme.name == "blue" ? "bluesvg" :
                                  theme.name == "orange" ? "orngsvg" :
                                  theme.name == "faintblack" ? "graysvg" :
                                  theme.name == "yellow" ? "faintyellosvg" :
                                  theme.name == "greensvg" ? "greensvgnew" :
                                  theme.name == "darkpink" ? "voiletsvg" :
                                  "red2svg")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 60)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
            .padding(.top, 10)
            
            // Submit button
            Button(action: {
                handleSubmit()
            }) {
                Image("tick_new_dvg")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .foregroundColor(Color("icontintGlobal"))
            }
            .frame(width: 52, height: 52)
          
            .padding(.top, 10)
            .padding(.bottom, 50)
            .disabled(isSubmitting)
            .opacity(isSubmitting ? 0.6 : 1.0)
        }
        .background(Color("edittextBg"))
    }
    
    // MARK: - Helper Functions
    private func getLogoImage(for color: String) -> String {
        switch color {
        case "#ff0080": return "pinklogopng"
        case "#00A3E9": return "ec_modern"
        case "#7adf2a": return "popatilogopng"
        case "#ec0001": return "redlogopng"
        case "#16f3ff": return "bluelogopng"
        case "#FF8A00": return "orangelogopng"
        case "#7F7F7F": return "graylogopng"
        case "#D9B845": return "yellowlogopng"
        case "#346667": return "greenlogoppng"
        case "#9846D9": return "voiletlogopng"
        case "#A81010": return "red2logopng"
        default: return "ec_modern"
        }
    }
    
    // MARK: - Change App Icon (matching Android changeAppIcon)
    
    // Synchronous version - tries immediately, sets up observer if app is inactive
    private func changeAppIconSync(for themeColor: String) {
        // Ensure we're on the main thread
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.changeAppIconSync(for: themeColor)
            }
            return
        }
        
        // Map theme colors to alternate icon names
        let iconName: String?
        switch themeColor {
        case "#ff0080": iconName = "SplashScreenMyAliasPink"
        case "#00A3E9": iconName = "SplashScreenMyAliasDefault"
        case "#7adf2a": iconName = "SplashScreenMyAliasPopati"
        case "#ec0001": iconName = "SplashScreenMyAliasRed"
        case "#16f3ff": iconName = "SplashScreenMyAliasLightBlue"
        case "#FF8A00": iconName = "SplashScreenMyAliasOrange"
        case "#7F7F7F": iconName = "SplashScreenMyAliasgray"
        case "#D9B845": iconName = "SplashScreenMyAliasyellow"
        case "#346667": iconName = "SplashScreenMyAliasrichgreen"
        case "#9846D9": iconName = "SplashScreenMyAliasVoilet"
        case "#A81010": iconName = "SplashScreenMyAliasred2"
        default: iconName = "SplashScreenMyAliasDefault"
        }
        
        guard UIApplication.shared.supportsAlternateIcons else {
            print("⚠️ Alternate app icons not supported")
            return
        }
        
        let currentIcon = UIApplication.shared.alternateIconName
        let targetIcon = iconName == "SplashScreenMyAliasDefault" ? nil : iconName
        
        guard currentIcon != targetIcon else {
            print("ℹ️ App icon already set to: \(iconName ?? "default")")
            return
        }
        
        let appState = UIApplication.shared.applicationState
        let appStateRaw = appState.rawValue
        print("🚀 changeAppIconSync - App state: \(appStateRaw) (0=inactive, 1=active, 2=background), Target: \(iconName ?? "default")")
        
        // Explicitly check for active state (rawValue must be 1)
        if appState == .active && appStateRaw == 1 {
            // App is active - change icon with a small delay to ensure system is ready
            print("✅ App is active (confirmed state: \(appStateRaw)), scheduling icon change")
            // Small delay to ensure system resources are ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                // Re-check state before attempting change
                let finalState = UIApplication.shared.applicationState
                let finalStateRaw = finalState.rawValue
                if finalState == .active && finalStateRaw == 1 {
                    print("✅ Final check: App still active (state: \(finalStateRaw)), changing icon now")
                    UIApplication.shared.setAlternateIconName(targetIcon) { error in
                        if let error = error {
                            let nsError = error as NSError
                            print("❌ Failed to change app icon: \(error.localizedDescription) (code: \(nsError.code))")
                            if nsError.code == 35 {
                                print("   - Error 35: System resources temporarily unavailable")
                                print("   - This often requires: Clean build, delete app, rebuild & reinstall")
                                print("   - Or try changing the icon again after a few seconds")
                            }
                        } else {
                            print("✅ App icon changed successfully to: \(iconName ?? "default")")
                        }
                    }
                } else {
                    print("⚠️ App became inactive during delay (state: \(finalStateRaw)), setting up observer")
                    // Set up observer to retry when app becomes active
                    var observer: NSObjectProtocol?
                    observer = NotificationCenter.default.addObserver(
                        forName: UIApplication.didBecomeActiveNotification,
                        object: nil,
                        queue: .main
                    ) { _ in
                        if let observer = observer {
                            NotificationCenter.default.removeObserver(observer)
                        }
                        print("✅ App became active, retrying icon change")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.changeAppIconSync(for: themeColor)
                        }
                    }
                }
            }
        } else {
            // App not active - set up observer to retry when active
            print("⚠️ App not active (state: \(appStateRaw)), will retry when active")
            var observer: NSObjectProtocol?
            observer = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                if let observer = observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                print("✅ App became active, retrying icon change")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.changeAppIconSync(for: themeColor)
                }
            }
        }
    }
    
    private func changeAppIcon(for themeColor: String, completion: (() -> Void)? = nil) {
        // Ensure we're on the main thread
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.changeAppIcon(for: themeColor)
            }
            return
        }
        
        // Map theme colors to alternate icon names (matching Android aliases)
        let iconName: String?
        
        switch themeColor {
        case "#ff0080":
            iconName = "SplashScreenMyAliasPink"
        case "#00A3E9":
            iconName = "SplashScreenMyAliasDefault"
        case "#7adf2a":
            iconName = "SplashScreenMyAliasPopati"
        case "#ec0001":
            iconName = "SplashScreenMyAliasRed"
        case "#16f3ff":
            iconName = "SplashScreenMyAliasLightBlue"
        case "#FF8A00":
            iconName = "SplashScreenMyAliasOrange"
        case "#7F7F7F":
            iconName = "SplashScreenMyAliasgray"
        case "#D9B845":
            iconName = "SplashScreenMyAliasyellow"
        case "#346667":
            iconName = "SplashScreenMyAliasrichgreen"
        case "#9846D9":
            iconName = "SplashScreenMyAliasVoilet"
        case "#A81010":
            iconName = "SplashScreenMyAliasred2"
        default:
            iconName = "SplashScreenMyAliasDefault"
        }
        
        // Change app icon if supported
        guard UIApplication.shared.supportsAlternateIcons else {
            print("⚠️ Alternate app icons not supported on this device")
            completion?()
            return
        }
        
        // Wait for app to be in active state with polling
        // Sometimes the app state check happens before the app is fully active
        let maxRetries = 20 // Maximum 2 seconds of waiting (20 * 0.1s)
        
        func attemptIconChange(retryCount: Int = 0) {
            let appState = UIApplication.shared.applicationState
            let appStateRaw = appState.rawValue
            print("🔍 Checking app state: \(appStateRaw) (0=inactive, 1=active, 2=background), attempt \(retryCount + 1)")
            
            // Explicitly check for active state (rawValue == 1)
            if appState == .active && appStateRaw == 1 {
                // App is active, proceed with icon change
                print("✅ App is active (state: \(appStateRaw)), proceeding with icon change")
                performIconChange()
                return // Explicit return to prevent fall-through
            } else if retryCount < maxRetries {
                // App not active, wait a bit and retry
                print("⚠️ App not active (state: \(appStateRaw)), waiting... (attempt \(retryCount + 1)/\(maxRetries))")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    attemptIconChange(retryCount: retryCount + 1)
                }
            } else {
                // Max retries reached, set up observer for when app becomes active
                print("⚠️ Max retries reached, setting up observer for app activation")
                var observer: NSObjectProtocol?
                observer = NotificationCenter.default.addObserver(
                    forName: UIApplication.didBecomeActiveNotification,
                    object: nil,
                    queue: .main
                ) { _ in
                    if let observer = observer {
                        NotificationCenter.default.removeObserver(observer)
                    }
                    print("✅ App became active, retrying icon change")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.changeAppIcon(for: themeColor, completion: completion)
                    }
                }
                // Don't call completion here since we're waiting for app to become active
            }
        }
        
        func performIconChange() {
            // CRITICAL: Check app state FIRST before doing anything
            let initialState = UIApplication.shared.applicationState
            let initialStateRaw = initialState.rawValue
            print("🔍 performIconChange called - App state: \(initialStateRaw)")
            
            guard initialState == .active && initialStateRaw == 1 else {
                print("❌ performIconChange: App is NOT active (state: \(initialStateRaw)), aborting and retrying")
                attemptIconChange(retryCount: 0)
                return
            }
            
            let currentIcon = UIApplication.shared.alternateIconName
            let targetIcon = iconName == "SplashScreenMyAliasDefault" ? nil : iconName
            
            // Only change if different from current
            if currentIcon != targetIcon {
                print("🔄 Changing app icon:")
                print("   - Current: \(currentIcon ?? "default")")
                print("   - Target: \(iconName ?? "default")")
                
                // Final check: ensure app is still active right before changing icon
                let finalState = UIApplication.shared.applicationState
                let finalStateRaw = finalState.rawValue
                guard finalState == .active && finalStateRaw == 1 else {
                    print("⚠️ App became inactive right before icon change (state: \(finalStateRaw)), retrying...")
                    // Retry the whole process
                    attemptIconChange(retryCount: 0)
                    return
                }
                
                print("✅ Final confirmation: App is active (state: \(finalStateRaw)), calling setAlternateIconName")
                
                // Call setAlternateIconName immediately while app is confirmed active
                UIApplication.shared.setAlternateIconName(targetIcon) { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            let nsError = error as NSError
                            print("❌ Failed to change app icon:")
                            print("   - Icon name: \(iconName ?? "default")")
                            print("   - Error: \(error.localizedDescription)")
                            print("   - Error code: \(nsError.code)")
                            print("   - Error domain: \(nsError.domain)")
                            print("   - User info: \(nsError.userInfo)")
                            
                            if nsError.code == 35 {
                                print("   - Error 35 (EAGAIN): Resource temporarily unavailable")
                                print("   - This often means:")
                                print("     • App needs full rebuild (Clean Build Folder)")
                                print("     • App needs to be deleted and reinstalled")
                                print("     • Icon change attempted too quickly")
                                print("   - Try: Clean build, delete app, rebuild & reinstall")
                            }
                        } else {
                            print("✅ App icon changed successfully to: \(iconName ?? "default")")
                            print("   - Note: Icon change takes effect after app restart")
                        }
                        // Call completion after icon change attempt (success or failure)
                        completion?()
                    }
                }
            } else {
                print("ℹ️ App icon already set to: \(iconName ?? "default")")
                // Icon already set, call completion immediately
                completion?()
            }
        }
        
        // Start the attempt
        attemptIconChange()
    }
    
    private func handleSubmit() {
        isSubmitting = true
        
        // Save to UserDefaults
        UserDefaults.standard.set(selectedThemeColor, forKey: Constant.ThemeColorKey)
        
        // Upload to server
        let uid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? "0"
        
        ApiService.upload_theme(uid: uid, themeColor: selectedThemeColor) { success, message in
            DispatchQueue.main.async {
                isSubmitting = false
                
                if success {
                    // Post notification to update UI first
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ThemeColorUpdated"),
                        object: nil,
                        userInfo: ["themeColor": selectedThemeColor]
                    )
                    
                    // Change app icon BEFORE dismissing (matching Android behavior)
                    // Android calls themeScreen.changeAppIcon() after API success (line 1321 in Webservice.java)
                    // Reset retry count
                    self.iconChangeRetryCount = 0
                    
                    // Attempt icon change immediately - the waitForAppActiveAndChangeIcon will handle waiting
                    // We do this BEFORE dismissing to ensure the app stays active
                    self.changeAppIconDirectly(for: selectedThemeColor)
                    
                    // Dismiss after a delay to allow icon change to complete
                    // Keep the view open longer to ensure app stays active during icon change
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        dismiss()
                    }
                } else {
                    alertTitle = "Error"
                    alertMessage = message
                    showAlert = true
                }
            }
        }
    }
    
    // Direct app icon change (matching Android changeAppIcon behavior)
    private func changeAppIconDirectly(for themeColor: String) {
        // Ensure we're on the main thread
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.changeAppIconDirectly(for: themeColor)
            }
            return
        }
        
        // Map theme colors to alternate icon names (matching Android aliases)
        let iconName: String?
        switch themeColor {
        case "#ff0080": iconName = "SplashScreenMyAliasPink"
        case "#00A3E9": iconName = "SplashScreenMyAliasDefault"
        case "#7adf2a": iconName = "SplashScreenMyAliasPopati"
        case "#ec0001": iconName = "SplashScreenMyAliasRed"
        case "#16f3ff": iconName = "SplashScreenMyAliasLightBlue"
        case "#FF8A00": iconName = "SplashScreenMyAliasOrange"
        case "#7F7F7F": iconName = "SplashScreenMyAliasgray"
        case "#D9B845": iconName = "SplashScreenMyAliasyellow"
        case "#346667": iconName = "SplashScreenMyAliasrichgreen"
        case "#9846D9": iconName = "SplashScreenMyAliasVoilet"
        case "#A81010": iconName = "SplashScreenMyAliasred2"
        default: iconName = "SplashScreenMyAliasDefault"
        }
        
        guard UIApplication.shared.supportsAlternateIcons else {
            print("⚠️ Alternate app icons not supported on this device")
            return
        }
        
        let currentIcon = UIApplication.shared.alternateIconName
        let targetIcon = iconName == "SplashScreenMyAliasDefault" ? nil : iconName
        
        // Only change if different from current
        guard currentIcon != targetIcon else {
            print("ℹ️ App icon already set to: \(iconName ?? "default")")
            return
        }
        
        print("🔄 [changeAppIconDirectly] Changing app icon:")
        print("   - Current: \(currentIcon ?? "default")")
        print("   - Target: \(iconName ?? "default")")
        print("   - App State: \(UIApplication.shared.applicationState.rawValue)")
        print("   - Supports Alternate Icons: \(UIApplication.shared.supportsAlternateIcons)")
        
        // Wait for app to be active before attempting icon change
        // This is critical - icon changes only work when app is in .active state
        self.waitForAppActiveAndChangeIcon(targetIcon: targetIcon, iconName: iconName, themeColor: themeColor)
    }
    
    // Wait for app to become active, then change icon
    private func waitForAppActiveAndChangeIcon(targetIcon: String?, iconName: String?, themeColor: String, attemptCount: Int = 0) {
        let maxAttempts = 10 // Maximum 2 seconds of waiting (10 * 0.2s)
        
        let appState = UIApplication.shared.applicationState
        let appStateRaw = appState.rawValue
        print("🔍 [waitForAppActiveAndChangeIcon] Attempt \(attemptCount + 1)/\(maxAttempts), App State: \(appStateRaw) (0=inactive, 1=active, 2=background)")
        
        // Explicitly check for active state (rawValue must be 1)
        if appState == .active && appStateRaw == 1 {
            // App is active, proceed with icon change
            print("✅ App is active (confirmed state: \(appStateRaw)), proceeding with icon change")
            self.performIconChange(targetIcon: targetIcon, iconName: iconName, themeColor: themeColor)
        } else if attemptCount < maxAttempts {
            // App not active yet, wait and retry
            print("⚠️ App not active (state: \(appStateRaw)), waiting 0.2s and retrying...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.waitForAppActiveAndChangeIcon(targetIcon: targetIcon, iconName: iconName, themeColor: themeColor, attemptCount: attemptCount + 1)
            }
        } else {
            // Max attempts reached, set up observer for when app becomes active
            print("⚠️ Max attempts reached, setting up observer for app activation")
            #if targetEnvironment(simulator)
            print("⚠️ Running on simulator - app icon changes may not work")
            print("⚠️ App state staying inactive is a known simulator limitation")
            print("⚠️ Please test app icon changes on a real device")
            #endif
            
            var observer: NSObjectProtocol?
            observer = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                if let observer = observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                let finalState = UIApplication.shared.applicationState
                let finalStateRaw = finalState.rawValue
                print("✅ App became active (state: \(finalStateRaw)), attempting icon change")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.performIconChange(targetIcon: targetIcon, iconName: iconName, themeColor: themeColor)
                }
            }
            
            // Also try one more time after a longer delay in case app becomes active
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let delayedState = UIApplication.shared.applicationState
                let delayedStateRaw = delayedState.rawValue
                if delayedState == .active && delayedStateRaw == 1 {
                    print("✅ App became active after delay (state: \(delayedStateRaw)), attempting icon change")
                    self.performIconChange(targetIcon: targetIcon, iconName: iconName, themeColor: themeColor)
                } else {
                    print("⚠️ App still inactive after delay (state: \(delayedStateRaw))")
                    #if targetEnvironment(simulator)
                    print("⚠️ This is expected on simulators - app icon changes require a real device")
                    #endif
                }
            }
        }
    }
    
    // Perform the actual icon change
    private func performIconChange(targetIcon: String?, iconName: String?, themeColor: String) {
        // Final check - ensure app is still active (explicitly check rawValue)
        let appState = UIApplication.shared.applicationState
        let appStateRaw = appState.rawValue
        guard appState == .active && appStateRaw == 1 else {
            print("⚠️ [performIconChange] App not active (state: \(appStateRaw)), retrying...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.waitForAppActiveAndChangeIcon(targetIcon: targetIcon, iconName: iconName, themeColor: themeColor)
            }
            return
        }
        
        // Check if we've exceeded max retries
        guard iconChangeRetryCount < maxIconChangeRetries else {
            print("⚠️ [performIconChange] Max retries (\(maxIconChangeRetries)) reached, giving up")
            print("   - Note: Error 35 (Resource temporarily unavailable) is common on iOS simulators")
            print("   - Note: App icon changes may not work reliably on simulators")
            print("   - Note: Please test on a real device for proper icon change functionality")
            return
        }
        
        print("🚀 [performIconChange] Calling setAlternateIconName... (Attempt \(iconChangeRetryCount + 1)/\(maxIconChangeRetries))")
        UIApplication.shared.setAlternateIconName(targetIcon) { error in
            DispatchQueue.main.async {
                if let error = error {
                    let nsError = error as NSError
                    print("❌ [performIconChange] Failed to change app icon:")
                    print("   - Error: \(error.localizedDescription)")
                    print("   - Code: \(nsError.code)")
                    print("   - Domain: \(nsError.domain)")
                    print("   - UserInfo: \(nsError.userInfo)")
                    
                    // Increment retry count
                    self.iconChangeRetryCount += 1
                    
                    // For error 35, use longer delay and check if we should continue
                    if nsError.code == 35 {
                        if self.iconChangeRetryCount < self.maxIconChangeRetries {
                            let retryDelay: TimeInterval = 2.0 // Longer delay for error 35
                            print("   - Error 35: Resource temporarily unavailable")
                            print("   - Retrying after \(retryDelay) seconds... (Attempt \(self.iconChangeRetryCount + 1)/\(self.maxIconChangeRetries))")
                            print("   - Note: This error is common on iOS simulators")
                            DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) {
                                self.changeAppIconDirectly(for: themeColor)
                            }
                        } else {
                            print("   - Max retries reached for error 35")
                            print("   - This is a known iOS simulator limitation")
                            print("   - Icon changes work reliably on real devices")
                        }
                    } else {
                        // For other errors, retry with shorter delay
                        if self.iconChangeRetryCount < self.maxIconChangeRetries {
                            let retryDelay: TimeInterval = 0.5
                            print("   - Retrying after \(retryDelay) seconds... (Attempt \(self.iconChangeRetryCount + 1)/\(self.maxIconChangeRetries))")
                            DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) {
                                self.changeAppIconDirectly(for: themeColor)
                            }
                        } else {
                            print("   - Max retries reached")
                        }
                    }
                } else {
                    print("✅ [performIconChange] App icon changed successfully to: \(iconName ?? "default")")
                    print("   - Note: Icon change may take a moment to appear on home screen")
                    #if targetEnvironment(simulator)
                    print("   - Note: On simulator, you may need to restart the app to see the change")
                    #endif
                    self.iconChangeRetryCount = 0 // Reset on success
                }
            }
        }
    }
}

// Note: CircularRippleStyle is defined in Utility/ButtonStyles.swift
// Note: Color hex extension is already defined in callView.swift

struct ThemeView_Previews: PreviewProvider {
    static var previews: some View {
        ThemeView()
    }
}

