import SwiftUI

struct OTPVerifyDeleteView: View {
    let uid: String
    let phoneNumber: String
    let countryCode: String
    
    @State private var otp: [String] = Array(repeating: "", count: 6)
    @FocusState private var focusedField: Int?
    @State private var isPressed = false
    @Environment(\.dismiss) var dismiss
    @State private var resendTimer = 0
    @State private var isResendDisabled = false
    @State private var showInvalidOTP = false
    @State private var isLoading = false
    @State private var showConfirmDeleteDialog = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var navigateToSplash = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("background_color")
                    .ignoresSafeArea()
                
                VStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            backButton
                            headerSection
                            otpInputSection
                            invalidOTPMessage
                            resendSection
                        }
                    }
                    
                    Spacer()
                    
                    verifyButton
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                startResendTimer()
                focusedField = 0
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK") {
                    if navigateToSplash {
                        clearUserDataAndNavigate()
                    }
                }
            } message: {
                Text(alertMessage)
            }
            .confirmationDialog("Delete Account", isPresented: $showConfirmDeleteDialog, titleVisibility: .visible) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone.")
            }
            .overlay(
                isLoading ? DeleteAccountLoadingOverlay() : nil
            )
        }
    }
    
    // MARK: - View Components
    private var backButton: some View {
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
        .padding(.top, 20)
        .padding(.leading, 20)
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("What's the\ncode?")
                .font(.custom("Inter18pt-SemiBold", size: 40))
                .foregroundColor(Color("TextColor"))
                .lineSpacing(20)
                .padding(.leading, 20)
                .padding(.top, 35.19)
                .multilineTextAlignment(.leading)
            
            Text("Enter code we've sent to")
                .font(.custom("Inter18pt-Medium", size: 16))
                .foregroundColor(Color("TextColor"))
                .lineSpacing(8)
                .padding(.leading, 20)
                .padding(.top, 9)
            
            Text("+\(countryCode) \(phoneNumber)")
                .font(.custom("Inter18pt-SemiBold", size: 16))
                .foregroundColor(Color("TextColor"))
                .lineSpacing(8)
                .padding(.leading, 20)
                .padding(.top, 5)
        }
    }
    
    private var otpInputSection: some View {
        HStack(spacing: 10) {
            ForEach(0..<6, id: \.self) { index in
                otpTextField(at: index)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 35)
    }
    
    private func otpTextField(at index: Int) -> some View {
        let isFocused = focusedField == index
        return TextField("", text: Binding(
            get: {
                return otp[index]
            },
            set: { newValue in
                let oldValue = otp[index]
                
                // Extract only digits from input
                let digits = newValue.filter { $0.isNumber }
                
                // Handle paste or multiple characters
                if digits.count > 1 {
                    // Fill current and subsequent fields
                    var currentIndex = index
                    for digit in digits {
                        if currentIndex < 6 {
                            otp[currentIndex] = String(digit)
                            currentIndex += 1
                        }
                    }
                    
                    // Focus on the last filled field or next empty field with animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if currentIndex < 6 {
                                focusedField = currentIndex
                            } else {
                                focusedField = 5
                            }
                        }
                    }
                } else if newValue.isEmpty {
                    // Backspace/Delete handling
                    otp[index] = ""
                    
                    // If field was already empty, move to previous field
                    if oldValue.isEmpty && index > 0 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                focusedField = index - 1
                            }
                        }
                    }
                } else {
                    // Single character entered - extract first digit if available
                    if let firstDigit = digits.first {
                        let digit = String(firstDigit)
                        otp[index] = digit
                        
                        // Move to next field smoothly with animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if index < 5 {
                                    focusedField = index + 1
                                } else {
                                    // Last field - dismiss keyboard
                                    focusedField = nil
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                }
                            }
                        }
                    } else {
                        // Non-digit character entered - keep old value
                        otp[index] = oldValue
                    }
                }
            }
        ))
        .frame(width: 45, height: 48)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    Color(UIColor(red: 0.62, green: 0.65, blue: 0.73, alpha: 1.0)), // #9EA6B9
                    lineWidth: isFocused ? 1.5 : 1.0
                )
        )
        .font(.custom("Inter18pt-Regular", size: 14))
        .foregroundColor(Color("TextColor"))
        .multilineTextAlignment(.center)
        .keyboardType(.numberPad)
        .focused($focusedField, equals: index)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                focusedField = index
            }
        }
    }
    
    private var invalidOTPMessage: some View {
        Group {
            if showInvalidOTP {
                Text("Invalid OTP")
                    .foregroundColor(.red)
                    .font(.custom("Inter18pt-Medium", size: 14))
                    .padding(.top, 10)
            }
        }
    }
    
    private var resendSection: some View {
        HStack(spacing: 2) {
            Text("Didn't receive code ?")
                .font(.custom("Inter18pt-Medium", size: 16))
                .foregroundColor(Color(UIColor(red: 0.62, green: 0.65, blue: 0.73, alpha: 1.0))) // #9EA6B9
                .lineSpacing(8)
                .padding(.leading, 20)
            
            if isResendDisabled {
                Text("Send in \(resendTimer) sec.")
                    .font(.custom("Inter18pt-Medium", size: 16))
                    .foregroundColor(Color("TextColor"))
                    .lineSpacing(8)
                    .padding(.leading, 5)
            } else {
                Button(action: {
                    // Clear all OTP text fields
                    otp = Array(repeating: "", count: 6)
                    focusedField = 0
                    showInvalidOTP = false
                    
                    // Start resend timer and send OTP
                    startResendTimer()
                    resendOTP()
                }) {
                    Text("Send again")
                        .font(.custom("Inter18pt-Medium", size: 16))
                        .foregroundColor(Color("TextColor"))
                        .lineSpacing(8)
                }
                .padding(.leading, 2)
            }
        }
        .padding(.top, 28)
    }
    
    private var verifyButton: some View {
        Button(action: verifyOTP) {
            Text("Verify")
                .font(.custom("Inter18pt-SemiBold", size: 16))
                .foregroundColor(.white)
                .lineSpacing(8)
                .frame(maxWidth: .infinity)
                .frame(height: 55)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(UIColor(red: 0x03/255.0, green: 0x2F/255.0, blue: 0x60/255.0, alpha: 1.0))) // #032F60
                )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 100)
        .disabled(isLoading)
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
    
    private func verifyOTP() {
        let otpString = otp.joined()
        
        // Validate OTP
        if otpString.count != 6 {
            showInvalidOTP = true
            // Clear OTP fields
            otp = Array(repeating: "", count: 6)
            focusedField = 0
            return
        }
        
        showInvalidOTP = false
        isLoading = true
        
        // Call verify OTP for delete account API
        ApiService.shared.verifyOtpForDelete(uid: uid, otp: otpString) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let response):
                    if response.errorCode == "200" {
                        // Show confirmation dialog before deleting
                        showConfirmDeleteDialog = true
                    } else {
                        showInvalidOTP = true
                        otp = Array(repeating: "", count: 6)
                        focusedField = 0
                        showAlert(title: "Error", message: response.message ?? "Invalid OTP")
                    }
                case .failure(let error):
                    showInvalidOTP = true
                    otp = Array(repeating: "", count: 6)
                    focusedField = 0
                    showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func deleteAccount() {
        isLoading = true
        
        // Call delete account API
        ApiService.shared.deleteMyAccount(uid: uid) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let response):
                    if response.errorCode == "200" {
                        // Success - clear user data and navigate to splash
                        clearUserDataAndNavigate()
                    } else {
                        showAlert(title: "Error", message: response.message ?? "Failed to delete account")
                    }
                case .failure(let error):
                    showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func clearUserDataAndNavigate() {
        // Clear all user data (matching Android behavior)
        let defaults = UserDefaults.standard
        defaults.set("0", forKey: Constant.UID_KEY)
        defaults.set("", forKey: Constant.PHONE_NUMBERKEY)
        defaults.set("", forKey: Constant.country_Code)
        defaults.set("0", forKey: "lockKey")
        defaults.set("sleepKeyCheckOFF", forKey: "sleepKeyCheckOFF")
        defaults.removeObject(forKey: Constant.loggedInKey)
        defaults.synchronize()
        
        // Post notification to trigger app restart/navigation
        NotificationCenter.default.post(name: NSNotification.Name("AccountDeleted"), object: nil)
        
        // Show success message
        showAlert(title: "Success", message: "Your account has been deleted successfully. Please restart the app.")
    }
    
    private func resendOTP() {
        if isResendDisabled || resendTimer > 0 {
            return
        }
        
        isLoading = true
        
        // Call resend OTP API
        ApiService.shared.sendOtpForDelete(mobileNo: phoneNumber) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let response):
                    if response.errorCode == "200" {
                        // Clear OTP fields and restart timer
                        otp = Array(repeating: "", count: 6)
                        focusedField = 0
                        startResendTimer()
                    } else {
                        showAlert(title: "Error", message: response.message ?? "Failed to resend OTP")
                    }
                case .failure(let error):
                    showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func startResendTimer() {
        resendTimer = 60
        isResendDisabled = true
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            resendTimer -= 1
            
            if resendTimer <= 0 {
                timer.invalidate()
                isResendDisabled = false
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

// MARK: - Loading Overlay
struct DeleteAccountLoadingOverlay: View {
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

struct OTPVerifyDeleteView_Previews: PreviewProvider {
    static var previews: some View {
        OTPVerifyDeleteView(uid: "1", phoneNumber: "8379887185", countryCode: "91")
    }
}

