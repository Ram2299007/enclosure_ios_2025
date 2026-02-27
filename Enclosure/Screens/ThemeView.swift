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
    
    // Helper function to hide keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    var body: some View {
        ZStack {
            Color("background_color")
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    hideKeyboard()
                }
            
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
        .navigationBarBackButtonHidden(true)
        .background(NavigationGestureEnabler())
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
    
    private func getAlternateIconName(for color: String) -> String? {
        switch color {
        case "#00A3E9": return nil // default theme → primary AppIcon
        case "#ff0080": return "SplashScreenMyAliasPink"
        case "#7adf2a": return "SplashScreenMyAliasPopati"
        case "#ec0001": return "SplashScreenMyAliasRed"
        case "#16f3ff": return "SplashScreenMyAliasLightBlue"
        case "#FF8A00": return "SplashScreenMyAliasOrange"
        case "#7F7F7F": return "SplashScreenMyAliasgray"
        case "#D9B845": return "SplashScreenMyAliasyellow"
        case "#346667": return "SplashScreenMyAliasrichgreen"
        case "#9846D9": return "SplashScreenMyAliasVoilet"
        case "#A81010": return "SplashScreenMyAliasred2"
        default: return nil
        }
    }
    
    private func changeAppIconSilently(to color: String) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let iconName = getAlternateIconName(for: color)
        
        // Swizzle present(_:animated:completion:) to suppress the system alert
        let presentSel = #selector(UIViewController.present(_:animated:completion:))
        let noopSel = #selector(UIViewController._noopPresent(_:animated:completion:))
        guard let originalMethod = class_getInstanceMethod(UIViewController.self, presentSel),
              let swizzledMethod = class_getInstanceMethod(UIViewController.self, noopSel) else {
            // Fallback: change icon normally if swizzle fails
            UIApplication.shared.setAlternateIconName(iconName)
            return
        }
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
        
        UIApplication.shared.setAlternateIconName(iconName) { error in
            // Restore original present method immediately
            method_exchangeImplementations(swizzledMethod, originalMethod)
            if let error = error {
                print("Error changing app icon: \(error.localizedDescription)")
            }
        }
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
                    
                    // Silently change app icon (no system alert = no stuck screen)
                    changeAppIconSilently(to: selectedThemeColor)
                    
                    // Dismiss immediately — smooth transition
                    dismiss()
                } else {
                    alertTitle = "Error"
                    alertMessage = message
                    showAlert = true
                }
            }
        }
    }
}

// MARK: - Suppress icon-change alert via swizzle
extension UIViewController {
    @objc func _noopPresent(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        // Intentionally empty — blocks the system icon-change alert from appearing
        completion?()
    }
}

// Note: CircularRippleStyle is defined in Utility/ButtonStyles.swift
// Note: Color hex extension is already defined in callView.swift

struct ThemeView_Previews: PreviewProvider {
    static var previews: some View {
        ThemeView()
    }
}

