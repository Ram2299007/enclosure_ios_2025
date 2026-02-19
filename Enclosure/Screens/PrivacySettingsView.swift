import SwiftUI

struct PrivacySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isPressed = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    
    // Privacy Settings States
    @State private var profileVisibility: ProfileVisibility = .everyone
    @State private var lastSeenVisibility: LastSeenVisibility = .everyone
    @State private var readReceiptsEnabled = true
    @State private var onlineStatusVisible = true
    @State private var allowGroupInvites = true
    @State private var allowCallsFrom: CallsFromSetting = .everyone
    @State private var blockScreenshots = false
    
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
                // Toolbar
                androidToolbar
                
                // Content
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Profile Privacy Section
                        profilePrivacySection
                        
                        // Activity Privacy Section
                        activityPrivacySection
                        
                        // Communication Privacy Section
                        communicationPrivacySection
                        
                        // Security Section
                        securitySection
                        
                        // Bottom spacing
                        Rectangle()
                            .frame(height: 100)
                            .foregroundColor(Color.clear)
                    }
                    .padding(.top, 20)
                }
            }
        }
        .navigationBarHidden(true)
        .background(NavigationGestureEnabler())
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Toolbar
    private var androidToolbar: some View {
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

            Text("Privacy settings")
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
    }
    
    // MARK: - Profile Privacy Section
    private var profilePrivacySection: some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                Text("Profile Privacy")
                    .font(.custom("Inter18pt-SemiBold", size: 18))
                    .foregroundColor(Color("TextColor"))
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            
            // Profile Visibility
            PrivacySettingItem(
                icon: "person.circle",
                title: "Profile visibility",
                subtitle: "Who can see your profile information"
            ) {
                // Handle profile visibility tap
                showAlert(title: "Profile Visibility", message: "Profile visibility settings will be available soon.")
            }
        }
    }
    
    // MARK: - Activity Privacy Section
    private var activityPrivacySection: some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                Text("Activity Privacy")
                    .font(.custom("Inter18pt-SemiBold", size: 18))
                    .foregroundColor(Color("TextColor"))
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 12)
            
            // Last Seen
            PrivacySettingItem(
                icon: "clock",
                title: "Last seen",
                subtitle: "Who can see when you were last online"
            ) {
                showAlert(title: "Last Seen", message: "Last seen privacy settings will be available soon.")
            }
            
            // Read Receipts Toggle
            PrivacyToggleItem(
                icon: "checkmark.circle.fill",
                title: "Read receipts",
                subtitle: "Show when you've read messages",
                isOn: $readReceiptsEnabled
            )
            
            // Online Status Toggle
            PrivacyToggleItem(
                icon: "circle.fill",
                title: "Online status",
                subtitle: "Show when you're online",
                isOn: $onlineStatusVisible
            )
        }
    }
    
    // MARK: - Communication Privacy Section
    private var communicationPrivacySection: some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                Text("Communication Privacy")
                    .font(.custom("Inter18pt-SemiBold", size: 18))
                    .foregroundColor(Color("TextColor"))
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 12)
            
            // Group Invites Toggle
            PrivacyToggleItem(
                icon: "person.3.fill",
                title: "Group invites",
                subtitle: "Allow others to add you to groups",
                isOn: $allowGroupInvites
            )
            
            // Calls From
            PrivacySettingItem(
                icon: "phone.fill",
                title: "Calls from",
                subtitle: "Who can call you"
            ) {
                showAlert(title: "Calls From", message: "Call privacy settings will be available soon.")
            }
        }
    }
    
    // MARK: - Security Section
    private var securitySection: some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                Text("Security")
                    .font(.custom("Inter18pt-SemiBold", size: 18))
                    .foregroundColor(Color("TextColor"))
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 12)
            
            // Block Screenshots Toggle
            PrivacyToggleItem(
                icon: "camera.fill",
                title: "Block screenshots",
                subtitle: "Prevent others from taking screenshots",
                isOn: $blockScreenshots
            )
        }
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
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

// MARK: - Privacy Setting Item
struct PrivacySettingItem: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon with circular background
                ZStack {
                    Circle()
                        .fill(Color("TextColor").opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color("TextColor").opacity(0.6))
                }
                
                // Content
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.custom("Inter18pt-Medium", size: 16))
                        .foregroundColor(Color("TextColor"))
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(subtitle)
                        .font(.custom("Inter18pt-Regular", size: 14))
                        .foregroundColor(Color("TextColor").opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color("TextColor").opacity(0.4))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Privacy Toggle Item
struct PrivacyToggleItem: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon with circular background
            ZStack {
                Circle()
                    .fill(Color("TextColor").opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color("TextColor").opacity(0.6))
            }
            
            // Content
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.custom("Inter18pt-Medium", size: 16))
                    .foregroundColor(Color("TextColor"))
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(subtitle)
                    .font(.custom("Inter18pt-Regular", size: 14))
                    .foregroundColor(Color("TextColor").opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

// MARK: - Enums
enum ProfileVisibility: String, CaseIterable {
    case everyone = "Everyone"
    case contacts = "My contacts"
    case nobody = "Nobody"
}

enum LastSeenVisibility: String, CaseIterable {
    case everyone = "Everyone"
    case contacts = "My contacts"
    case nobody = "Nobody"
}

enum CallsFromSetting: String, CaseIterable {
    case everyone = "Everyone"
    case contacts = "My contacts"
    case nobody = "Nobody"
}

struct PrivacySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        PrivacySettingsView()
    }
}
