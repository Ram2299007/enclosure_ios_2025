import SwiftUI

struct SettingsView: View {
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    // Profile states
    @State private var userProfile: GetProfileModel?
    @State private var navigateToPrivacyPolicy = false
    @State private var navigateToContactUs = false
    @State private var navigateToAccount = false
    @State private var navigateToManageAccount = false
    
    // Helper function to hide keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    var body: some View {
        ZStack {
            // Android-style background with dynamic color
            Color("background_color")
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    hideKeyboard()
                }
            
            VStack(spacing: 0) {
                // Settings List
                ScrollView {
                    LazyVStack(spacing: 0) {
                        settingsItemsList
                    }
                    .padding(.top, 20)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Text("Settings")
                    .font(.custom("Inter18pt-SemiBold", size: 16))
                    .foregroundColor(Color("TextColor"))
            }
        }
        .background(NavigationGestureEnabler())
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
        .navigationDestination(isPresented: $navigateToAccount) {
            AccountView()
        }
        .navigationDestination(isPresented: $navigateToManageAccount) {
            ManageAccountView(newPhoneNumber: "")
        }
    }
    
    // MARK: - Settings Items List
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
            
            // Account — navigates directly to change number screen
            AndroidSettingsItem(
                icon: "accountsvg",
                title: "Account",
                subtitle: "Change your phone number"
            ) {
                navigateToAccount = true
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

            // Delete Account — always visible top-level row (Guideline 5.1.1(v))
            AndroidSettingsItem(
                icon: "trash",
                title: "Delete my account",
                subtitle: "Permanently delete your account and data",
                isDestructive: true
            ) {
                handleDeleteAccount()
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
                    // Only save device_type when it matches get_user_active_chat_list format ("1" or "2"), not UUID
                    if !profile.device_type.isEmpty, (profile.device_type == "1" || profile.device_type == "2") {
                        UserDefaults.standard.set(profile.device_type, forKey: Constant.DEVICE_TYPE_KEY)
                    }
                } else {
                    showAlert(title: "Error", message: message)
                }
            }
        }
    }
    
    private func handleBlockedContacts() {
        showAlert(title: "Blocked contacts", message: "No blocked contacts found.")
    }
    
    private func handleDeleteAccount() {
        navigateToManageAccount = true
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
                        .fill(isDestructive ? Color.red.opacity(0.12) : Color("TextColor").opacity(0.1))
                        .frame(width: 40, height: 40)

                    // Check if it's a custom image or system icon
                    if icon.contains("svg") || icon.contains("png") || icon == "accountsvg" {
                        Image(icon)
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .foregroundColor(isDestructive ? Color.red : Color("TextColor").opacity(0.6))
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(isDestructive ? Color.red : Color("TextColor").opacity(0.6))
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
