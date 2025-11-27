import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var isPressed = false
    
    // Profile states
    @State private var userProfile: GetProfileModel?
    @State private var navigateToPrivacyPolicy = false
    @State private var navigateToContactUs = false
    
    var body: some View {
        ZStack {
            // Android-style background with dynamic color
            Color("background_color")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Android-style toolbar
                androidToolbar
                
                // Settings List - Android RecyclerView style
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Settings Items List
                        settingsItemsList
                    }
                    .padding(.top, 20)
                }
            }
        }
        .navigationBarHidden(true)
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            loadUserProfile()
        }
        .navigationDestination(isPresented: $navigateToPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .navigationDestination(isPresented: $navigateToContactUs) {
            ContactUsView()
        }
    }
    
    // MARK: - Android-style Toolbar
    private var androidToolbar: some View {
        HStack {
            // Back button - exact same as editmyProfile.swift
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
            
            // Title - same font style as editmyProfile.swift
            Text("Settings")
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
        .background(Color("background_color"))
    }
    
    
    // MARK: - Settings Items List (Android RecyclerView style)
    private var settingsItemsList: some View {
        VStack(spacing: 0) {
            // Blocked contacts
            AndroidSettingsItem(
                icon: "nosign",
                title: "Blocked contacts",
                subtitle: "0"
            ) {
                handleBlockedContacts()
            }
            
            // Account
            AndroidSettingsItem(
                icon: "accountsvg",
                title: "Account",
                subtitle: "Change number, Delete account"
            ) {
                handleAccount()
            }
            
            // Contact us
            AndroidSettingsItem(
                icon: "globe",
                title: "Contact us",
                subtitle: "Get in touch !"
            ) {
                handleContactSupport()
            }
            
            // Privacy Policy
            AndroidSettingsItem(
                icon: "info.circle",
                title: "Privacy Policy",
                subtitle: "Privacy policy"
            ) {
                handlePrivacyPolicy()
            }
            
            // Bottom spacing
            Rectangle()
                .frame(height: 100)
                .foregroundColor(Color.clear)
        }
    }
    
    // MARK: - API Functions (same as before)
    private func loadUserProfile() {
        ApiService.get_profile(uid: Constant.SenderIdMy) { success, response, message in
            DispatchQueue.main.async {
                if success, let profile = response {
                    userProfile = profile
                } else {
                    showAlert(title: "Error", message: message)
                }
            }
        }
    }
    
    
    private func handleBlockedContacts() {
        showAlert(title: "Blocked contacts", message: "No blocked contacts found.")
    }
    
    private func handleAccount() {
        showAlert(title: "Account", message: "Account management options will be available soon.")
    }
    
    private func handleContactSupport() {
        navigateToContactUs = true
    }
    
    private func handlePrivacyPolicy() {
        navigateToPrivacyPolicy = true
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
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
}

// MARK: - Android-style Components

struct AndroidSettingsItem: View {
    let icon: String
    let title: String
    let subtitle: String
    let isDestructive: Bool
    let action: () -> Void
    
    init(icon: String, title: String, subtitle: String, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.isDestructive = isDestructive
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon with circular background (Android style)
                ZStack {
                    Circle()
                        .fill(Color("TextColor").opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    // Check if it's a custom image or system icon
                    if icon.contains("svg") || icon.contains("png") || icon == "accountsvg" {
                        Image(icon)
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .foregroundColor(Color("TextColor").opacity(0.6))
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color("TextColor").opacity(0.6))
                    }
                }
                
                // Content - Android font styling
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.custom("Inter18pt-Medium", size: 16))
                        .foregroundColor(Color("TextColor"))
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.custom("Inter18pt-Regular", size: 14))
                            .foregroundColor(Color("TextColor").opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
    }
}




struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
