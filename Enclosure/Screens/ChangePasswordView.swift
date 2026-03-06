import SwiftUI

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isPressed = false
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var showCurrentPassword = false
    @State private var showNewPassword = false
    @State private var showConfirmPassword = false
    
    @FocusState private var isCurrentPasswordFocused: Bool
    @FocusState private var isNewPasswordFocused: Bool
    @FocusState private var isConfirmPasswordFocused: Bool
    
    // Helper function to hide keyboard
    private func hideKeyboard() {
        isCurrentPasswordFocused = false
        isNewPasswordFocused = false
        isConfirmPasswordFocused = false
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
                    VStack(spacing: 24) {
                        // Instructions
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Change your password")
                                .font(.custom("Inter18pt-SemiBold", size: 20))
                                .foregroundColor(Color("TextColor"))
                                .fontWeight(.semibold)
                            
                            Text("Enter your current password and choose a new secure password for your account.")
                                .font(.custom("Inter18pt-Regular", size: 14))
                                .foregroundColor(Color("TextColor").opacity(0.7))
                                .lineSpacing(4)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Password Fields
                        VStack(spacing: 20) {
                            // Current Password
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Current password")
                                    .font(.custom("Inter18pt-Medium", size: 16))
                                    .foregroundColor(Color("TextColor"))
                                
                                HStack {
                                    if showCurrentPassword {
                                        TextField("Enter current password", text: $currentPassword)
                                    } else {
                                        SecureField("Enter current password", text: $currentPassword)
                                    }
                                    
                                    Button(action: { showCurrentPassword.toggle() }) {
                                        Image(systemName: showCurrentPassword ? "eye.slash" : "eye")
                                            .foregroundColor(Color("TextColor").opacity(0.6))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 56)
                                .background(Color("background_color"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color("TextColor").opacity(0.2), lineWidth: 1)
                                )
                                .font(.custom("Inter18pt-Regular", size: 16))
                                .foregroundColor(Color("TextColor"))
                                .focused($isCurrentPasswordFocused)
                            }
                            
                            // New Password
                            VStack(alignment: .leading, spacing: 8) {
                                Text("New password")
                                    .font(.custom("Inter18pt-Medium", size: 16))
                                    .foregroundColor(Color("TextColor"))
                                
                                HStack {
                                    if showNewPassword {
                                        TextField("Enter new password", text: $newPassword)
                                    } else {
                                        SecureField("Enter new password", text: $newPassword)
                                    }
                                    
                                    Button(action: { showNewPassword.toggle() }) {
                                        Image(systemName: showNewPassword ? "eye.slash" : "eye")
                                            .foregroundColor(Color("TextColor").opacity(0.6))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 56)
                                .background(Color("background_color"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color("TextColor").opacity(0.2), lineWidth: 1)
                                )
                                .font(.custom("Inter18pt-Regular", size: 16))
                                .foregroundColor(Color("TextColor"))
                                .focused($isNewPasswordFocused)
                                
                                // Password strength indicator
                                if !newPassword.isEmpty {
                                    PasswordStrengthView(password: newPassword)
                                }
                            }
                            
                            // Confirm Password
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Confirm new password")
                                    .font(.custom("Inter18pt-Medium", size: 16))
                                    .foregroundColor(Color("TextColor"))
                                
                                HStack {
                                    if showConfirmPassword {
                                        TextField("Confirm new password", text: $confirmPassword)
                                    } else {
                                        SecureField("Confirm new password", text: $confirmPassword)
                                    }
                                    
                                    Button(action: { showConfirmPassword.toggle() }) {
                                        Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                                            .foregroundColor(Color("TextColor").opacity(0.6))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 56)
                                .background(Color("background_color"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(passwordsMatch ? Color.green.opacity(0.5) : Color("TextColor").opacity(0.2), lineWidth: 1)
                                )
                                .font(.custom("Inter18pt-Regular", size: 16))
                                .foregroundColor(Color("TextColor"))
                                .focused($isConfirmPasswordFocused)
                                
                                // Password match indicator
                                if !confirmPassword.isEmpty {
                                    HStack {
                                        Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundColor(passwordsMatch ? .green : .red)
                                        Text(passwordsMatch ? "Passwords match" : "Passwords don't match")
                                            .font(.custom("Inter18pt-Regular", size: 12))
                                            .foregroundColor(passwordsMatch ? .green : .red)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Change Password Button
                        Button(action: handleChangePassword) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Change password")
                                        .font(.custom("Inter18pt-SemiBold", size: 16))
                                        .foregroundColor(.white)
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue)
                            )
                        }
                        .disabled(isLoading || !isFormValid)
                        .opacity(isFormValid ? 1.0 : 0.6)
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 50)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .background(NavigationGestureEnabler())
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") {
                if alertTitle == "Success" {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Computed Properties
    private var passwordsMatch: Bool {
        !confirmPassword.isEmpty && newPassword == confirmPassword
    }
    
    private var isFormValid: Bool {
        !currentPassword.isEmpty && 
        !newPassword.isEmpty && 
        !confirmPassword.isEmpty && 
        passwordsMatch && 
        isPasswordStrong(newPassword)
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

            Text("Change password")
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
    
    private func handleChangePassword() {
        guard isFormValid else {
            showAlert(title: "Error", message: "Please check all fields and ensure passwords match")
            return
        }
        
        isLoading = true
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isLoading = false
            showAlert(title: "Success", message: "Your password has been successfully changed")
        }
    }
    
    private func isPasswordStrong(_ password: String) -> Bool {
        return password.count >= 8 && 
               password.contains { $0.isUppercase } &&
               password.contains { $0.isLowercase } &&
               password.contains { $0.isNumber }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

// MARK: - Password Strength View
struct PasswordStrengthView: View {
    let password: String
    
    private var strength: PasswordStrength {
        if password.count < 6 {
            return .weak
        } else if password.count >= 8 && 
                  password.contains { $0.isUppercase } &&
                  password.contains { $0.isLowercase } &&
                  password.contains { $0.isNumber } {
            return .strong
        } else {
            return .medium
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Rectangle()
                        .frame(height: 4)
                        .foregroundColor(strengthColor(for: index))
                        .cornerRadius(2)
                }
            }
            
            Text(strength.description)
                .font(.custom("Inter18pt-Regular", size: 12))
                .foregroundColor(strength.color)
        }
    }
    
    private func strengthColor(for index: Int) -> Color {
        switch strength {
        case .weak:
            return index == 0 ? .red : Color.gray.opacity(0.3)
        case .medium:
            return index <= 1 ? .orange : Color.gray.opacity(0.3)
        case .strong:
            return .green
        }
    }
}

enum PasswordStrength {
    case weak, medium, strong
    
    var description: String {
        switch self {
        case .weak: return "Weak password"
        case .medium: return "Medium password"
        case .strong: return "Strong password"
        }
    }
    
    var color: Color {
        switch self {
        case .weak: return .red
        case .medium: return .orange
        case .strong: return .green
        }
    }
}

struct ChangePasswordView_Previews: PreviewProvider {
    static var previews: some View {
        ChangePasswordView()
    }
}
