import SwiftUI

struct OTPVerifyDeleteView: View {
    let uid: String
    let phoneNumber: String
    let countryCode: String
    
    @State private var otp: [String] = Array(repeating: "", count: 6)
    @FocusState private var focusedField: Int?
    @Environment(\.dismiss) var dismiss
    @State private var resendTimer = 0
    @State private var isResendDisabled = false
    @State private var showInvalidOTP = false
    @State private var isLoading = false
    @State private var showConfirmDeleteDialog = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @Environment(\.colorScheme) var colorScheme
    @State private var isProcessingInput = false
    
    // Helper function to hide keyboard
    private func hideKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color("background_color")
                .ignoresSafeArea()

            VStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        headerSection
                        otpInputSection
                        invalidOTPMessage
                        resendSection
                    }
                }
                .simultaneousGesture(
                    TapGesture().onEnded { _ in hideKeyboard() }
                )

                Spacer()

                verifyButton
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Text("Verify OTP")
                    .font(.custom("Inter18pt-SemiBold", size: 16))
                    .foregroundColor(Color("TextColor"))
            }
        }
        .background(NavigationGestureEnabler())
        .onAppear {
            startResendTimer()
            checkClipboardForOTP()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focusedField = 0
            }
        }
        .onChange(of: focusedField) { newValue in
            if newValue == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    checkClipboardForOTP()
                }
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") { }
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
    
    // MARK: - View Components
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
            
            Text(phoneNumber)
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
                let filtered = newValue.filter { $0.isNumber }
                if filtered != otp[index] {
                    handleOTPInput(filtered, at: index)
                }
            }
        ))
        .frame(width: 45, height: 48)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    Color(UIColor(red: 0.62, green: 0.65, blue: 0.73, alpha: 1.0)),
                    lineWidth: isFocused ? 1.5 : 1.0
                )
        )
        .font(.custom("Inter18pt-Regular", size: 14))
        .foregroundColor(Color("TextColor"))
        .multilineTextAlignment(.center)
        .keyboardType(.numberPad)
        .textContentType(.oneTimeCode)
        .focused($focusedField, equals: index)
        .submitLabel(.done)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
    }

    private func handleOTPInput(_ newValue: String, at index: Int) {
        guard !isProcessingInput else { return }

        let currentValue = otp[index]
        if newValue == currentValue { return }

        isProcessingInput = true
        defer {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isProcessingInput = false
            }
        }

        let digits = newValue.filter { $0.isNumber }

        // Handle paste: 6+ digits distributed across all fields
        if digits.count >= 6 {
            let otpString = String(digits.prefix(6))
            for i in 0..<min(6, otp.count) {
                otp[i] = String(otpString[otpString.index(otpString.startIndex, offsetBy: i)])
            }
            DispatchQueue.main.async {
                self.focusedField = 5
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
            return
        }

        // Handle paste: multiple digits from a specific field
        if digits.count > 1 {
            var currentIndex = index
            for digit in digits {
                guard currentIndex < otp.count else { break }
                otp[currentIndex] = String(digit)
                currentIndex += 1
            }
            let nextFocus = min(currentIndex, otp.count - 1)
            DispatchQueue.main.async {
                self.focusedField = nextFocus
                if nextFocus >= self.otp.count - 1 && !self.otp[self.otp.count - 1].isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            return
        }

        // Backspace
        if newValue.isEmpty {
            otp[index] = ""
            if index > 0 {
                DispatchQueue.main.async { self.focusedField = index - 1 }
            } else {
                DispatchQueue.main.async { self.focusedField = nil }
            }
            return
        }

        // Single digit
        guard let firstDigit = digits.first else {
            otp[index] = currentValue
            return
        }

        otp[index] = String(firstDigit)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if index < self.otp.count - 1 {
                self.focusedField = index + 1
            } else {
                self.focusedField = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    }

    private func checkClipboardForOTP() {
        let pasteboard = UIPasteboard.general
        guard let clipboardText = pasteboard.string else { return }

        let digits = clipboardText.filter { $0.isNumber }

        if digits.count >= 6 {
            let allFieldsEmpty = otp.allSatisfy { $0.isEmpty }
            if allFieldsEmpty {
                let otpString = String(digits.prefix(6))
                for i in 0..<min(6, otp.count) {
                    otp[i] = String(otpString[otpString.index(otpString.startIndex, offsetBy: i)])
                }
                focusedField = 5
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
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
                switch result {
                case .success(let response):
                    if response.errorCode == "200" {
                        clearUserDataAndRestart()
                    } else {
                        isLoading = false
                        showAlert(title: "Error", message: response.message ?? "Failed to delete account")
                    }
                case .failure(let error):
                    isLoading = false
                    showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }

    private func clearUserDataAndRestart() {
        // Clear all user data
        let defaults = UserDefaults.standard
        defaults.set("0", forKey: Constant.UID_KEY)
        defaults.set("", forKey: Constant.PHONE_NUMBERKEY)
        defaults.set("", forKey: Constant.country_Code)
        defaults.set("0", forKey: "lockKey")
        defaults.set("sleepKeyCheckOFF", forKey: "sleepKeyCheckOFF")
        defaults.removeObject(forKey: Constant.loggedInKey)
        defaults.synchronize()

        // Auto-restart: keep loading overlay visible, then terminate after brief delay
        // iOS will start fresh from splash screen on next launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            exit(0)
        }
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

