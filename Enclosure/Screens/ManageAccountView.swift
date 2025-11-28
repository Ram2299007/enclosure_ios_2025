import SwiftUI

struct ManageAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isPressed = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var themeColorHex: String = UserDefaults.standard.string(forKey: Constant.ThemeColorKey) ?? "#00A3E9"
    
    let newPhoneNumber: String
    
    // Current user's phone number components
    @State private var currentCountryCode = ""
    @State private var currentPhoneNumber = ""
    
    // Navigation and loading states
    @State private var navigateToOTPVerify = false
    @State private var navigateToOTPVerifyDelete = false
    @State private var isLoading = false
    @State private var otpVerificationData: (uid: String, phoneNumber: String, countryCode: String)?
    @State private var otpVerificationDeleteData: (uid: String, phoneNumber: String, countryCode: String)?
    
    var body: some View {
        ZStack {
            Color("background_color")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Toolbar
                androidToolbar
                
                // Content
                ScrollView {
                    VStack(spacing: 0) {
                        // Warning Section
                        HStack(spacing: 0) {
                            Image("redwarning")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 25, height: 19)
                                .padding(.top, 3)
                            
                            Text("Change your number here :")
                                .font(.custom("Inter18pt-SemiBold", size: 16))
                                .foregroundColor(Color(hex: "#D31111"))
                                .fontWeight(.semibold)
                                .lineSpacing(5) // lineHeight="21dp"
                                .padding(.leading, 10)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 23)
                        
                        // Description Text (matching Android layout)
                        HStack(spacing: 0) {
                            Text("All your current data from here - will transfer on your new number")
                                .font(.custom("Inter18pt-Medium", size: 15))
                                .foregroundColor(Color("TextColor"))
                                .fontWeight(.medium)
                                .lineSpacing(3) // lineHeight="18dp"
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 30) // layout_marginStart="10dp" (20dp container + 10dp = 30dp)
                        .padding(.top, 15) // layout_marginTop="15dp"
                        
                        // Additional Options (previously hidden in Android)
                        VStack(alignment: .leading, spacing: 2) {
                            // Erase message history option
                            HStack(spacing: 0) {
                                Circle()
                                    .fill(Color(hex: "#9EA6B9"))
                                    .frame(width: 7, height: 7)
                                
                                Text("Erase your message history")
                                    .font(.custom("Inter18pt-Medium", size: 15))
                                    .foregroundColor(Color(hex: "#4E4E52"))
                                    .fontWeight(.medium)
                                    .lineSpacing(3) // lineHeight="18dp"
                                    .padding(.leading, 10) // layout_marginStart="10dp"
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 2) // layout_marginTop="2dp"
                            
                            // Delete from groups option
                            HStack(spacing: 0) {
                                Circle()
                                    .fill(Color(hex: "#9EA6B9"))
                                    .frame(width: 7, height: 7)
                                    .padding(.bottom, 8.5) // layout_marginBottom="8.5dp"
                                
                                Text("Delete you from all of your Enclosure\ngroups")
                                    .font(.custom("Inter18pt-Medium", size: 15))
                                    .foregroundColor(Color(hex: "#4E4E52"))
                                    .fontWeight(.medium)
                                    .lineSpacing(3) // lineHeight="18dp"
                                    .padding(.leading, 10) // layout_marginStart="10dp"
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 2) // layout_marginTop="2dp"
                            
                            // Delete payment info option
                            HStack(spacing: 0) {
                                Circle()
                                    .fill(Color(hex: "#9EA6B9"))
                                    .frame(width: 7, height: 7)
                                
                                Text("Delete you payment info")
                                    .font(.custom("Inter18pt-Medium", size: 15))
                                    .foregroundColor(Color(hex: "#4E4E52"))
                                    .fontWeight(.medium)
                                    .lineSpacing(3) // lineHeight="18dp"
                                    .padding(.leading, 10) // layout_marginStart="10dp"
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 2) // layout_marginTop="2dp"
                        }
                        
                        // Change number instead option
                        HStack(spacing: 0) {
                            Image("rightarrownew")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 13, height: 11)
                            
                            Text("Change number instead?")
                                .font(.custom("Inter18pt-Bold", size: 15))
                                .foregroundColor(Color("TextColor"))
                                .fontWeight(.bold)
                                .lineSpacing(5) // lineHeight="21dp"
                                .padding(.leading, 10) // layout_marginStart="10dp"
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 39) // layout_marginTop="39dp"
                        
                        // Change Number Button (matching Android layout)
                        Button(action: handleChangeNumber) {
                            Text("Change number")
                                .font(.custom("Inter18pt-Medium", size: 16))
                                .foregroundColor(.white)
                                .fontWeight(.medium)
                                .lineSpacing(8) // lineHeight="24dp"
                        }
                        .frame(height: 49)
                        .padding(.horizontal, 20) // paddingStart="20dp" paddingEnd="20dp"
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: themeColorHex.isEmpty ? "#00A3E9" : themeColorHex))
                        )
                        .buttonStyle(.plain) // textAllCaps="false"
                        .padding(.horizontal, 20)
                        .padding(.top, 23) // layout_marginTop="23dp"
                        
                        // Delete Account Section
                        HStack(spacing: 0) {
                            Text("Delete your account here :")
                                .font(.custom("Inter18pt-SemiBold", size: 15))
                                .foregroundColor(Color("TextColor"))
                                .fontWeight(.semibold)
                                .lineSpacing(3) // lineHeight="18dp"
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 23) // layout_marginTop="23dp"
                        
                        // Country Section
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Country")
                                .font(.custom("Inter18pt-Bold", size: 15))
                                .foregroundColor(Color("TextColor"))
                                .fontWeight(.bold)
                                .lineSpacing(3) // lineHeight="18dp"
                                .padding(.horizontal, 20)
                                .padding(.top, 23) // layout_marginTop="23dp"
                            
                            // Country Input
                            VStack(spacing: 0) {
                                TextField("India", text: .constant("India"))
                                    .font(.custom("Inter18pt-Medium", size: 15))
                                    .foregroundColor(Color("TextColor"))
                                    .fontWeight(.medium)
                                    .disabled(true)
                                    .background(Color.clear)
                                
                                Rectangle()
                                    .fill(Color(hex: "#4E4E52"))
                                    .frame(height: 1)
                                    .padding(.top, 4) // layout_marginTop="4dp"
                                    .padding(.trailing, 18) // layout_marginEnd="18dp"
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 7) // layout_marginTop="7dp"
                        }
                        
                        // Phone Section
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Phone")
                                .font(.custom("Inter18pt-Medium", size: 15))
                                .foregroundColor(Color("TextColor"))
                                .fontWeight(.medium)
                                .lineSpacing(3) // lineHeight="18dp"
                                .padding(.horizontal, 20)
                                .padding(.top, 27) // layout_marginTop="27dp"
                            
                            // Phone Input (matching Android layout)
                            HStack(spacing: 0) {
                                // Country code section
                                VStack(spacing: 0) {
                                    HStack(spacing: 0) {
                                        Text("+")
                                            .font(.custom("Inter18pt-SemiBold", size: 15))
                                            .foregroundColor(Color(hex: "#9EA6B9"))
                                            .fontWeight(.semibold)
                                            .lineSpacing(5) // lineHeight="21dp"
                                        
                                        TextField("91", text: .constant(currentCountryCode))
                                            .font(.custom("Inter18pt-SemiBold", size: 15))
                                            .foregroundColor(Color("TextColor"))
                                            .fontWeight(.semibold)
                                            .keyboardType(.phonePad)
                                            .disabled(true) // android:enabled="false"
                                            .background(Color.clear)
                                            .frame(minWidth: 30)
                                            .lineSpacing(3) // lineHeight="18dp"
                                    }
                                    .frame(width: 60, alignment: .center) // android:layout_width="60dp" android:gravity="center"
                                    
                                    Rectangle()
                                        .fill(Color(hex: "#9EA6B9"))
                                        .frame(height: 1)
                                        .padding(.top, 4.5)
                                }
                                
                                // Phone number section
                                VStack(spacing: 0) {
                                    TextField("Phone Number", text: .constant(currentPhoneNumber))
                                        .font(.custom("Inter18pt-Medium", size: 15))
                                        .foregroundColor(Color("TextColor"))
                                        .fontWeight(.medium)
                                        .keyboardType(.phonePad)
                                        .disabled(true) // android:enabled="false"
                                        .background(Color.clear)
                                        .lineSpacing(3) // lineHeight="18dp"
                                    
                                    Rectangle()
                                        .fill(Color(hex: "#9EA6B9"))
                                        .frame(height: 1)
                                        .padding(.top, 4.5)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 11) // layout_marginTop="11dp"
                            .padding(.trailing, 18) // layout_marginEnd="18dp"
                        }
                        
                        // Delete Account Button
                        Button(action: handleDeleteAccount) {
                            Text("Delete my account")
                                .font(.custom("Inter18pt-Medium", size: 16))
                                .foregroundColor(.white)
                                .fontWeight(.medium)
                                .lineSpacing(8) // lineHeight="24dp"
                        }
                        .frame(width: 181, height: 49) // android:layout_width="181dp"
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red) // @drawable/delete_btn_bg (red background)
                        )
                        .buttonStyle(.plain) // android:textAllCaps="false"
                        .padding(.horizontal, 20)
                        .padding(.top, 23) // layout_marginTop="23dp"
                        
                        Spacer(minLength: 100)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadThemeColor()
            loadCurrentPhoneNumber()
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") {
                if alertTitle == "Success" {
                    dismiss()
                }
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
        .overlay(
            // Loading overlay
            isLoading ? LoadingOverlay() : nil
        )
    }
    
    // MARK: - Toolbar
    private var androidToolbar: some View {
        VStack(spacing: 0) {
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
                        
                        ZStack {
                            Image("leftvector")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 25, height: 18)
                                .foregroundColor(Color("icontintGlobal"))
                                .padding(2)
                        }
                        .frame(width: 26, height: 26)
                    }
                    .frame(width: 40, height: 40)
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
                .padding(.trailing, 5)
                
                Text("Manage my account")
                    .font(.custom("Inter18pt-Medium", size: 16))
                    .foregroundColor(Color("TextColor"))
                    .fontWeight(.medium)
                    .padding(.leading, 15)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .frame(height: 50)
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
