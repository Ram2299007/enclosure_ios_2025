import SwiftUI

struct ManageAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isPressed = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var themeColorHex: String = Constant.themeColor
    
    var newPhoneNumber: String = ""
    
    // Current user's phone number components
    @State private var currentCountryCode = ""
    @State private var currentPhoneNumber = ""
    
    // Navigation and loading states
    @State private var navigateToOTPVerify = false
    @State private var navigateToOTPVerifyDelete = false
    @State private var isLoading = false
    @State private var otpVerificationData: (uid: String, phoneNumber: String, countryCode: String)?
    @State private var otpVerificationDeleteData: (uid: String, phoneNumber: String, countryCode: String)?
    
    // Helper function to hide keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    var body: some View {
        ZStack {
            Color("background_color")
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { hideKeyboard() }

            VStack(spacing: 0) {
                androidToolbar

                ScrollView {
                    VStack(spacing: 0) {
                        // Change number section — only shown when navigating from AccountView
                        if !newPhoneNumber.isEmpty {
                            changeNumberSection
                        }

                        // Delete account section — always shown
                        deleteAccountSection

                        Rectangle()
                            .frame(height: 100)
                            .foregroundColor(Color.clear)
                    }
                    .padding(.top, 16)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .background(NavigationGestureEnabler())
        .onAppear {
            loadThemeColor()
            loadCurrentPhoneNumber()
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") {
                if alertTitle == "Success" { dismiss() }
            }
        } message: {
            Text(alertMessage)
        }
        .navigationDestination(isPresented: $navigateToOTPVerify) {
            if let data = otpVerificationData {
                whatsTheCode(
                    uid: data.uid,
                    c_id: UserDefaults.standard.string(forKey: Constant.c_id) ?? "",
                    mobile_no: data.phoneNumber,
                    country_Code: data.countryCode
                )
            }
        }
        .navigationDestination(isPresented: $navigateToOTPVerifyDelete) {
            if let data = otpVerificationDeleteData {
                OTPVerifyDeleteView(
                    uid: data.uid,
                    phoneNumber: data.phoneNumber,
                    countryCode: data.countryCode
                )
            }
        }
        .overlay(isLoading ? LoadingOverlay() : nil)
    }

    // MARK: - Change Number Section
    private var changeNumberSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            Text("CHANGE NUMBER")
                .font(.custom("Inter18pt-Medium", size: 11))
                .foregroundColor(Color("TextColor").opacity(0.45))
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 10)

            // Warning card
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image("redwarning")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 16)

                    Text("Change your number here :")
                        .font(.custom("Inter18pt-SemiBold", size: 15))
                        .foregroundColor(Color(hex: "#D31111"))

                    Spacer()
                }

                Text("All your current data will transfer to your new number.")
                    .font(.custom("Inter18pt-Regular", size: 14))
                    .foregroundColor(Color("TextColor").opacity(0.65))
                    .lineSpacing(4)

                // New number pill
                HStack(spacing: 8) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#D31111").opacity(0.7))
                    Text(newPhoneNumber)
                        .font(.custom("Inter18pt-SemiBold", size: 14))
                        .foregroundColor(Color(hex: "#D31111"))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "#D31111").opacity(0.08))
                )

                // Change Number Button
                Button(action: handleChangeNumber) {
                    HStack {
                        Spacer()
                        Text("Change Number")
                            .font(.custom("Inter18pt-Medium", size: 16))
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .frame(height: 49)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(hex: themeColorHex.isEmpty ? Constant.themeColor : themeColorHex))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex: "#D31111").opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(hex: "#D31111").opacity(0.18), lineWidth: 1)
            )
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Delete Account Section
    private var deleteAccountSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            Text("DELETE ACCOUNT")
                .font(.custom("Inter18pt-Medium", size: 11))
                .foregroundColor(Color("TextColor").opacity(0.45))
                .padding(.horizontal, 20)
                .padding(.top, newPhoneNumber.isEmpty ? 8 : 24)
                .padding(.bottom, 10)

            // Phone number info card
            VStack(spacing: 0) {
                // Country row
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color("TextColor").opacity(0.08))
                            .frame(width: 40, height: 40)
                        Image(systemName: "globe")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(Color("TextColor").opacity(0.55))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Country")
                            .font(.custom("Inter18pt-Regular", size: 12))
                            .foregroundColor(Color("TextColor").opacity(0.45))
                        Text("India")
                            .font(.custom("Inter18pt-Medium", size: 15))
                            .foregroundColor(Color("TextColor"))
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Rectangle()
                    .fill(Color("TextColor").opacity(0.08))
                    .frame(height: 1)
                    .padding(.horizontal, 16)

                // Phone row
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color("TextColor").opacity(0.08))
                            .frame(width: 40, height: 40)
                        Image(systemName: "phone.fill")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(Color("TextColor").opacity(0.55))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Phone")
                            .font(.custom("Inter18pt-Regular", size: 12))
                            .foregroundColor(Color("TextColor").opacity(0.45))
                        Text(currentCountryCode.isEmpty ? "Loading..." : "+\(currentCountryCode) \(currentPhoneNumber)")
                            .font(.custom("Inter18pt-Medium", size: 15))
                            .foregroundColor(Color("TextColor"))
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color("TextColor").opacity(0.05))
            )
            .padding(.horizontal, 20)

            // Warning note
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(Color.red.opacity(0.6))
                Text("This action is permanent and cannot be undone.")
                    .font(.custom("Inter18pt-Regular", size: 13))
                    .foregroundColor(Color("TextColor").opacity(0.5))
                    .lineSpacing(3)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // Delete Button
            Button(action: handleDeleteAccount) {
                HStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "trash")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                    Text("Delete my account")
                        .font(.custom("Inter18pt-Medium", size: 16))
                        .foregroundColor(.white)
                        .fontWeight(.medium)
                    Spacer()
                }
                .frame(height: 49)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.red)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 16)
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
                        withAnimation { isPressed = false }
                    }
            )
            .buttonStyle(.plain)

            Text("Manage my account")
                .font(.custom("Inter18pt-Medium", size: 16))
                .foregroundColor(Color("TextColor"))
                .fontWeight(.medium)
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
    
    private func handleChangeNumber() {
        // Get current user data
        guard let uid = UserDefaults.standard.string(forKey: Constant.UID_KEY),
              let oldPhoneNumber = UserDefaults.standard.string(forKey: Constant.PHONE_NUMBERKEY) else {
            showAlert(title: "Error", message: "User data not found. Please login again.")
            return
        }
        
        // Show loading
        isLoading = true
        
        // Call change number API (matching Android Webservice.change_number)
        ApiService.shared.changeNumber(
            uid: uid,
            oldPhoneNumber: oldPhoneNumber,
            newPhoneNumber: newPhoneNumber
        ) { [self] result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let response):
                    if response.errorCode == "200" {
                        // Success - navigate to OTP verification (matching Android flow)
                        let components = splitCountryCodeAndNationalNumber(phoneNumber: newPhoneNumber)
                        otpVerificationData = (
                            uid: uid,
                            phoneNumber: newPhoneNumber,
                            countryCode: components.0
                        )
                        navigateToOTPVerify = true
                    } else {
                        showAlert(title: "Error", message: response.message ?? "Failed to change number")
                    }
                case .failure(let error):
                    showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func handleDeleteAccount() {
        // Get current user data
        guard let uid = UserDefaults.standard.string(forKey: Constant.UID_KEY),
              let oldPhoneNumber = UserDefaults.standard.string(forKey: Constant.PHONE_NUMBERKEY) else {
            showAlert(title: "Error", message: "User data not found. Please login again.")
            return
        }
        
        // Show loading
        isLoading = true
        
        // Call send OTP for delete account API (matching Android Webservice.send_otpDelete)
        ApiService.shared.sendOtpForDelete(mobileNo: oldPhoneNumber) { [self] result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let response):
                    if response.errorCode == "200" {
                        // Success - navigate to OTP verification for delete (matching Android flow)
                        let components = splitCountryCodeAndNationalNumber(phoneNumber: oldPhoneNumber)
                        otpVerificationDeleteData = (
                            uid: uid,
                            phoneNumber: oldPhoneNumber,
                            countryCode: components.0
                        )
                        navigateToOTPVerifyDelete = true
                    } else {
                        showAlert(title: "Error", message: response.message ?? "Failed to send OTP")
                    }
                case .failure(let error):
                    showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
    
    private func loadThemeColor() {
        if let savedThemeColor = UserDefaults.standard.string(forKey: Constant.ThemeColorKey), !savedThemeColor.isEmpty {
            themeColorHex = savedThemeColor
        }
    }
    
    private func loadCurrentPhoneNumber() {
        if let phoneNumber = UserDefaults.standard.string(forKey: Constant.PHONE_NUMBERKEY) {
            let components = splitCountryCodeAndNationalNumber(phoneNumber: phoneNumber)
            currentCountryCode = components.0
            currentPhoneNumber = components.1
        }
    }
    
    private func splitCountryCodeAndNationalNumber(phoneNumber: String) -> (String, String) {
        // Simple parsing - in real app you might want to use a proper phone number library
        if phoneNumber.hasPrefix("+") {
            let withoutPlus = String(phoneNumber.dropFirst())
            if withoutPlus.count >= 2 {
                let countryCode = String(withoutPlus.prefix(2))
                let nationalNumber = String(withoutPlus.dropFirst(2))
                return (countryCode, nationalNumber)
            }
        }
        return ("91", phoneNumber) // Default fallback
    }
}

// MARK: - Loading Overlay
struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text("Processing...")
                    .foregroundColor(.white)
                    .font(.custom("Inter18pt-Medium", size: 16))
            }
            .padding()
            .background(Color.black.opacity(0.8))
            .cornerRadius(12)
        }
    }
}

struct ManageAccountView_Previews: PreviewProvider {
    static var previews: some View {
        ManageAccountView(newPhoneNumber: "+919876543210")
    }
}
