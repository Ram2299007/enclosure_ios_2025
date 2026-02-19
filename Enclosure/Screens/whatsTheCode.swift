import SwiftUI
import AVFoundation
import Photos
import Contacts
import UserNotifications
import PopGestureRecognizerSwiftUI

struct whatsTheCode: View {
    var uid: String
    var c_id: String
    var mobile_no: String
    var country_Code: String

    init(uid: String, c_id: String, mobile_no: String, country_Code: String) {
        self.uid = uid
        self.c_id = c_id
        self.mobile_no = mobile_no
        self.country_Code = country_Code
        print("✅ Init Called - UID: \(uid), Country Code: \(country_Code), Mobile No: \(mobile_no)")

        UserDefaults.standard.set(self.mobile_no, forKey: Constant.PHONE_NUMBERKEY)
        UserDefaults.standard.set(self.uid, forKey: Constant.UID_KEY)
        UserDefaults.standard.set(self.c_id, forKey: Constant.c_id)
        UserDefaults.standard.set(self.country_Code, forKey: Constant.country_Code)
    }


    @State private var otp: [String] = Array(repeating: "", count: 6)
    @FocusState private var focusedField: Int?
    @State private var isPressed = false
    @StateObject private var viewModel = SendOTPViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var resendTimer = 0
    @State private var isResendDisabled = false
    @State private var showInvalidOTP = false
    @StateObject private var verifyViewModel = VerifyMobileOTPViewModel()

    @State private var fcmToken = ""
    @State private var deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    @Environment(\.colorScheme) var colorScheme
    @State private var isProcessingInput = false // Prevent concurrent input processing
    /// When true, we are waiting for FCM token (via FCMTokenReceived) before calling performOTPVerification.
    @State private var verificationPending = false
    
    // Helper to dismiss keyboard on tap
    private func hideKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }


    var body: some View {
        // Remove NavigationStack wrapper - it should be provided by parent (like ForthView)
        ZStack(alignment: .bottom) { // Use ZStack to overlay content and keep bottom fixed
            Color("background_color")
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { hideKeyboard() }
            
            VStack {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                            // Back Button
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
                            .buttonStyle(.plain)
                            .padding(.top, 20)
                            .padding(.leading, 20)

                            // Title
                            Text("What's the\ncode?")
                                .font(.custom("Inter18pt-SemiBold", size: 40)) // inter_bold, 40dp, fontWeight 600
                                .foregroundColor(Color("TextColor"))
                                .lineSpacing(20) // lineHeight 60dp (40dp + 20dp spacing)
                                .padding(.leading, 20)
                                .padding(.top, 35.19) // marginTop="35.19dp"
                                .multilineTextAlignment(.leading)

                            // Subtitle
                            Text("Enter code we've sent to")
                                .font(.custom("Inter18pt-Medium", size: 16)) // inter_medium, 16dp, lineHeight 24dp
                                .foregroundColor(Color("TextColor"))
                                .lineSpacing(8) // lineHeight 24dp (16dp + 8dp spacing)
                                .padding(.leading, 20)
                                .padding(.top, 9) // marginTop="9dp"

                            // Mobile Number
                            Text(mobile_no)
                                .font(.custom("Inter18pt-SemiBold", size: 16)) // inter_bold, 16dp, lineHeight 24dp
                                .foregroundColor(Color("TextColor"))
                                .lineSpacing(8) // lineHeight 24dp (16dp + 8dp spacing)
                                .padding(.leading, 20)
                                .padding(.top, 5) // marginTop="5dp"

                            // OTP Input
                            HStack(spacing: 10) { // marginEnd="10dp" between fields
                                ForEach(0..<6, id: \.self) { index in
                                    let isFocused = focusedField == index
                                    TextField("", text: Binding(
                                        get: { 
                                            return otp[index] 
                                        },
                                        set: { newValue in
                                            // Limit input to prevent blocking - only process if value actually changed
                                            let filtered = newValue.filter { $0.isNumber }
                                            if filtered != otp[index] {
                                                handleOTPInput(filtered, at: index)
                                            }
                                        }
                                    ))
                                    .frame(width: 45, height: 48) // width="45dp", height="48dp"
                                    .background(
                                        RoundedRectangle(cornerRadius: 20) // corners android:radius="20dp"
                                            .stroke(
                                                Color(UIColor(red: 0.62, green: 0.65, blue: 0.73, alpha: 1.0)), // #9EA6B9 - works in both light and dark mode
                                                lineWidth: isFocused ? 1.5 : 1.0 // 1.5dp when focused, 1dp when not
                                            )
                                    ) // background="@drawable/button_color_hover_for_all" - transparent with stroke
                                    .font(.custom("Inter18pt-Regular", size: 14)) // inter, 14sp
                                    .foregroundColor(Color("TextColor")) // style="@style/TextColor" - adapts to dark/light mode
                                    .multilineTextAlignment(.center)
                                    .keyboardType(.numberPad)
                                    .textContentType(.oneTimeCode) // Helps iOS optimize keyboard
                                    .focused($focusedField, equals: index)
                                    .submitLabel(.done)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 35) // marginTop="35dp"

                            // Invalid OTP Text
                            if showInvalidOTP {
                                Text("Invalid OTP")
                                    .foregroundColor(.red)
                                    .font(.custom("Inter18pt-Medium", size: 14))
                                    .padding(.top, 10)
                            }

                            // Resend Code
                            HStack(spacing: 2) {
                                Text("Didn't receive code ?") // Matching Android text with space before ?
                                    .font(.custom("Inter18pt-Medium", size: 16)) // inter_medium, 16dp, lineHeight 24dp
                                    .foregroundColor(Color(UIColor(red: 0.62, green: 0.65, blue: 0.73, alpha: 1.0))) // #9EA6B9
                                    .lineSpacing(8) // lineHeight 24dp
                                    .padding(.leading, 20)

                                if isResendDisabled {
                                    Text("Send in \(resendTimer) sec.")
                                        .font(.custom("Inter18pt-Medium", size: 16))
                                        .foregroundColor(Color("TextColor"))
                                        .lineSpacing(8) // lineHeight 24dp
                                        .padding(.leading, 5) // marginStart="5dp"
                                } else {
                                    Button(action: {
                                        // Clear all OTP text fields
                                        otp = Array(repeating: "", count: 6)
                                        focusedField = 0 // Focus on first field
                                        showInvalidOTP = false // Clear any error message
                                        
                                        // Start resend timer and send OTP
                                        startResendTimer()
                                        viewModel.sendOTP(mobileNo: mobile_no, cID: c_id, cCode: country_Code)
                                    }) {
                                        Text("Send again")
                                            .font(.custom("Inter18pt-Medium", size: 16)) // inter_medium, 16dp, lineHeight 24dp
                                            .foregroundColor(Color("TextColor"))
                                            .lineSpacing(8) // lineHeight 24dp
                                    }
                                    .padding(.leading, 2) // marginStart="2dp"
                                }
                            }
                            .padding(.top, 28) // marginTop="28dp"
                        }
                        .id("otpContainer")
                        }
                        .simultaneousGesture(
                            TapGesture().onEnded { _ in hideKeyboard() }
                        )
                        // Scroll the OTP container into view when any field is focused (adjustPan-like)
                        // Removed to prevent UI blocking - scroll happens naturally with keyboard
                    }

                    Spacer() // Pushes the button to the bottom


                    NavigationLink(
                        destination: LockScreen2View(),
                        isActive: $verifyViewModel.isNavigating
                    ) {
                        EmptyView() // Hidden Navigation Link
                    }



                    // Verify Button
                    Button(action: ensureTokenAndVerify)
{
                        Text("Verify")
                            .font(.custom("Inter18pt-SemiBold", size: 16)) // inter_medium + fontWeight 600 = SemiBold, 16dp
                            .foregroundColor(.white) // textColor="@color/white"
                            .lineSpacing(8) // lineHeight 24dp
                            .frame(maxWidth: .infinity)
                            .frame(height: 55) // 55dp height matching Android CardView
                            .background(RoundedRectangle(cornerRadius: 20).fill(Color(UIColor(red: 0x03/255.0, green: 0x2F/255.0, blue: 0x60/255.0, alpha: 1.0)))) // backgroundTint #032F60, cornerRadius 20dp
                    }
                    .padding(.horizontal, 20) // marginHorizontal="20dp"
                    .padding(.bottom, 100) // marginBottom="100dp" matching Android
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)

                if verifyViewModel.isLoading {
                    ZStack {
                        VStack(spacing: 16) {
                            // Loader
                            HorizontalProgressBar()
                                .frame(width: 40, height: 2)

                            // Loading Text  Syncing Contacts...
                            Text("Your contacts are synchronizing...")
                                .foregroundColor(Color("TextColor"))
                                .font(.custom("Inter18pt-Medium", size: 16))
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(width: 220, height: 140)
                        .background(Color("cardBackgroundColornew").opacity(0.95))
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 2, y: 2)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.clear.ignoresSafeArea()) // Ensures full-screen coverage
                }
            }
            .navigationBarHidden(true)
            // PopGestureRecognizerSwiftUI: Gesture is enabled by default (like ForthView)
            // We don't call .swipeBackGestureDisabled(), so the native interactive pop gesture works
            .background(
                NavigationGestureEnabler()
            )
            .onAppear {
                print("UID: \(uid), Country Code: \(country_Code), Mobile No: \(mobile_no)")
                checkClipboardForOTP()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    focusedField = 0
                }
                // Request notification permission (Android-style dialog first) so FCM token is ready for verify API (avoids 406 Required Parameter Missing)
                AndroidStylePermissionManager.shared.requestPermissionWithDialogFromTopVC(for: .notifications) { granted in
                    if granted {
                        DispatchQueue.main.async {
                            UIApplication.shared.registerForRemoteNotifications()
                            FirebaseManager.shared.requestNotificationPermissions()
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            FirebaseManager.shared.getFCMToken { token in
                                DispatchQueue.main.async {
                                    if let token = token, !token.isEmpty {
                                        self.fcmToken = token
                                        UserDefaults.standard.set(token, forKey: Constant.FCM_TOKEN)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .onChange(of: focusedField) { newValue in
                // Check clipboard when first field gets focus (Android behavior)
                if newValue == 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        checkClipboardForOTP()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FCMTokenReceived"))) { notification in
                if let token = notification.object as? String, !token.isEmpty {
                    fcmToken = token
                    UserDefaults.standard.set(token, forKey: Constant.FCM_TOKEN)
                    if verificationPending {
                        verificationPending = false
                        performOTPVerification()
                    }
                }
            }
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
    
    private func startResendTimer() {
        resendTimer = 60
        isResendDisabled = true
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if resendTimer > 0 {
                resendTimer -= 1
            } else {
                timer.invalidate()
                isResendDisabled = false
            }
        }
    }


    func getContactList(uidKey: String, countryCodeKey: String, phoneKey: String, completion: @escaping ([ContactUploadModel]?, Error?) -> Void) {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, error in
            if granted {
                DispatchQueue.global(qos: .userInitiated).async {
                    let keys: [CNKeyDescriptor] = [
                        CNContactGivenNameKey as CNKeyDescriptor,
                        CNContactFamilyNameKey as CNKeyDescriptor,
                        CNContactMiddleNameKey as CNKeyDescriptor,
                        CNContactPhoneNumbersKey as CNKeyDescriptor,
                        CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
                    ]
                    let request = CNContactFetchRequest(keysToFetch: keys)

                    var contactList: [ContactUploadModel] = []
                    var mobileNoSet = Set<String>()
                    var arr = [[String: Any]]() // Array of dictionaries

                    do {
                        try store.enumerateContacts(with: request) { contact, stop in
                            if contactList.count >= 10000 { return } // Limit contacts to 10,000

                            let name = CNContactFormatter.string(from: contact, style: .fullName) ?? ""

                            for phoneNumber in contact.phoneNumbers {
                                var number = phoneNumber.value.stringValue
                                    .replacingOccurrences(of: "[()\\s-]+", with: "", options: .regularExpression)
                                    .trimmingCharacters(in: .whitespacesAndNewlines)

                                let formattedNumber = phoneNumberWithoutCountryCode(phoneNumber: number)
                                let contactNumber = normalizeContactNumber(countryCode: countryCodeKey, rawNumber: number)

                                // Ensure uniqueness by checking formatted number
                                if !mobileNoSet.contains(formattedNumber) {
                                    contactList.append(ContactUploadModel(name: name, phoneNumber: number))
                                    mobileNoSet.insert(formattedNumber)

                                    var obj: [String: Any] = [:]
                                    obj["uid"] = uidKey
                                    obj["mobile_no"] = phoneKey
                                    obj["contact_name"] = name
                                    obj["contact_number"] = contactNumber

                                    verifyViewModel.countryCodeKey = countryCodeKey;


                                    arr.append(obj)
                                }
                            }
                        }

                        // Create JSON Data
                        let finalData: [String: Any] = ["contact": arr]
                        if let jsonData = try? JSONSerialization.data(withJSONObject: finalData, options: .prettyPrinted) {

                            if let jsonString = String(data: jsonData, encoding: .utf8) {
                                print("Final JSON Data: \(jsonString)") // Print JSON
                            }

                            // Save JSON File in Cache Directory
                            let fileNameUid = "contact_\(uidKey).json"
                            verifyViewModel.fileName = fileNameUid;
                            if let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
                                let fileURL = cacheDir.appendingPathComponent(fileNameUid)
                                verifyViewModel.fileURL = fileURL

                                do {
                                    try jsonData.write(to: fileURL) // ✅ fileURL निश्चित असल्यामुळे unwrap करण्याची गरज नाही
                                    print("JSON Data saved at: \(fileURL)")
                                } catch {
                                    print("Error saving JSON file: \(error.localizedDescription)")
                                }
                            }

                        }

                        DispatchQueue.main.async {
                            completion(contactList, nil)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            completion(nil, error)
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil, error ?? NSError(domain: "Contact Access Denied", code: 0, userInfo: nil))
                }
            }
        }
    }



    func phoneNumberWithoutCountryCode(phoneNumber: String) -> String {
        // फक्त अंक आणि + चिन्ह सोडून बाकीचे काढून टाका
        let cleanedNumber = phoneNumber.replacingOccurrences(of: "[^+0-9]", with: "", options: .regularExpression)
        return cleanedNumber
    }

    /// Returns contact_number with country code applied once and leading + (e.g. +911800407267864).
    private func normalizeContactNumber(countryCode: String, rawNumber: String) -> String {
        let digitsOnly = rawNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        var numberDigits = digitsOnly
        while numberDigits.hasPrefix("0") && numberDigits.count > 1 {
            numberDigits.removeFirst()
        }
        guard !numberDigits.isEmpty else { return rawNumber }
        let countryDigits = countryCode.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        let fullDigits: String
        if countryDigits.isEmpty {
            fullDigits = numberDigits
        } else if numberDigits.hasPrefix(countryDigits) {
            fullDigits = numberDigits
        } else {
            fullDigits = countryDigits + numberDigits
        }
        return "+" + fullDigits
    }

    /// When getFCMToken returned nil (APNs not ready), retry once after 2s then wait for FCMTokenReceived or 6s timeout.
    private func waitForFCMTokenThenVerify() {
        print("⚠️ [FCM_TOKEN] FCM token not ready - retrying in 2s, then waiting for FCMTokenReceived (max 6s)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            FirebaseManager.shared.getFCMToken { token in
                DispatchQueue.main.async {
                    if let token = token, !token.isEmpty {
                        print("✅ [FCM_TOKEN] FCM token retrieved on retry: \(token.prefix(50))...")
                        self.fcmToken = token
                        UserDefaults.standard.set(token, forKey: Constant.FCM_TOKEN)
                        self.performOTPVerification()
                        return
                    }
                    // Still nil - wait for FCMTokenReceived (EnclosureApp posts when APNs is set) or timeout
                    self.verificationPending = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                        if self.verificationPending {
                            self.verificationPending = false
                            print("⚠️ [FCM_TOKEN] Timeout waiting for FCM token - proceeding with apns_missing")
                            self.fcmToken = "apns_missing"
                            self.performOTPVerification()
                        }
                    }
                }
            }
        }
    }

    /// Ensure we have an FCM token before verifying; fetch if missing.
    private func ensureTokenAndVerify() {
        if otp.contains("") {
            otp = Array(repeating: "", count: 6)
            focusedField = 0
            Constant.showToast(message: "Invalid OTP")
            return
        }

        // If token already available, proceed
        if !fcmToken.isEmpty && fcmToken != "apns_missing" {
            performOTPVerification()
            return
        }

        // Try fallback from UserDefaults
        if let savedToken = UserDefaults.standard.string(forKey: Constant.FCM_TOKEN), !savedToken.isEmpty, savedToken != "apns_missing" {
            fcmToken = savedToken
            performOTPVerification()
            return
        }

        // Ensure notification permissions are granted first, then fetch FCM token
        print("🔑 [FCM_TOKEN] Checking notification permissions before fetching FCM token...")
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .authorized {
                    // Permission granted - ensure we're registered for remote notifications
                    print("✅ [FCM_TOKEN] Notification permission granted - calling registerForRemoteNotifications()...")
                    UIApplication.shared.registerForRemoteNotifications()
                    print("📱 [FCM_TOKEN] registerForRemoteNotifications() CALLED - fetching FCM token immediately (no waiting)")
                    
                    // Fetch FCM token; if APNs not ready yet, retry once then wait for FCMTokenReceived (or timeout)
                    FirebaseManager.shared.getFCMToken { token in
                        DispatchQueue.main.async {
                            if let token = token, !token.isEmpty {
                                print("✅ [FCM_TOKEN] FCM token retrieved successfully: \(token.prefix(50))...")
                                self.fcmToken = token
                                UserDefaults.standard.set(token, forKey: Constant.FCM_TOKEN)
                                self.performOTPVerification()
                            } else {
                                self.waitForFCMTokenThenVerify()
                            }
                        }
                    }
                } else {
                    // Show Android-style custom dialog first, then system permission (required for FCM token / verify API)
                    print("🔑 [FCM_TOKEN] Showing notification permission dialog (custom first)...")
                    AndroidStylePermissionManager.shared.requestPermissionWithDialogFromTopVC(for: .notifications) { granted in
                        DispatchQueue.main.async {
                            if granted {
                                UIApplication.shared.registerForRemoteNotifications()
                                FirebaseManager.shared.requestNotificationPermissions()
                                print("📱 [FCM_TOKEN] registerForRemoteNotifications() - fetching FCM token...")
                                FirebaseManager.shared.getFCMToken { token in
                                    DispatchQueue.main.async {
                                        if let token = token, !token.isEmpty {
                                            self.fcmToken = token
                                            UserDefaults.standard.set(token, forKey: Constant.FCM_TOKEN)
                                            self.performOTPVerification()
                                        } else {
                                            self.waitForFCMTokenThenVerify()
                                        }
                                    }
                                }
                            } else {
                                print("⚠️ [FCM_TOKEN] Notification permission denied - proceeding with placeholder")
                                self.fcmToken = "apns_missing"
                                self.performOTPVerification()
                            }
                        }
                    }
                }
            }
        }
    }
    

    /// Performs OTP verification after prerequisites are satisfied.
    private func performOTPVerification() {
        let contactStore = CNContactStore()
        let authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
        
        // Get VoIP token from VoIPPushManager
        let voipToken = VoIPPushManager.shared.getVoIPToken() ?? ""

        // Build contact list file (sets verifyViewModel.fileURL, fileName, countryCodeKey) then verify — required for Sync Contacts API after verify (avoids 406).
        let doVerifyOTP: () -> Void = {
            self.getContactList(uidKey: self.uid, countryCodeKey: self.country_Code, phoneKey: self.mobile_no) { _, _ in
                DispatchQueue.main.async {
                    verifyViewModel.verifyOTP(
                        uid: uid,
                        otp: otp.joined(),
                        cCode: country_Code,
                        token: fcmToken,
                        deviceId: deviceId,
                        voipToken: voipToken
                    )
                }
            }
        }

        switch authorizationStatus {
        case .notDetermined:
            // Show Android-style custom dialog first, then system permission; then build contacts and verify
            AndroidStylePermissionManager.shared.requestPermissionWithDialogFromTopVC(for: .contacts) { granted in
                DispatchQueue.main.async {
                    if granted {
                        doVerifyOTP()
                    } else {
                        showPermissionAlert()
                    }
                }
            }

        case .authorized:
            // Permission already granted: build contact list then verify (so Sync Contacts API has fileURL, fileName, countryCodeKey)
            doVerifyOTP()

        case .denied, .restricted:
            // Permission denied, show alert to open settings
            showPermissionAlert()
        @unknown default:
            break
        }
    }

    /// Normalize OTP input to avoid flicker and only keep numeric characters
    private func handleOTPInput(_ newValue: String, at index: Int) {
        // Prevent concurrent processing to avoid UI blocking
        guard !isProcessingInput else { return }
        
        // Prevent processing if value hasn't actually changed (avoids infinite loops)
        let currentValue = otp[index]
        if newValue == currentValue {
            return
        }
        
        isProcessingInput = true
        defer { 
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isProcessingInput = false
            }
        }
        
        let digits = newValue.filter { $0.isNumber }
        
        // Handle paste: if 6 digits are pasted, distribute them across all fields (Android behavior)
        if digits.count >= 6 {
            // Extract first 6 digits
            let otpString = String(digits.prefix(6))
            for i in 0..<min(6, otp.count) {
                otp[i] = String(otpString[otpString.index(otpString.startIndex, offsetBy: i)])
            }
            // Focus on last field and hide keyboard (matching Android)
            DispatchQueue.main.async {
                self.focusedField = 5
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
            return
        }
        
        // Handle paste: if multiple digits pasted into a field, distribute from that field
        if digits.count > 1 {
            var currentIndex = index
            for digit in digits {
                guard currentIndex < otp.count else { break }
                otp[currentIndex] = String(digit)
                currentIndex += 1
            }
            // Focus on the last filled field or next empty field
            let nextFocus = min(currentIndex, otp.count - 1)
            DispatchQueue.main.async {
                self.focusedField = nextFocus
                if nextFocus >= self.otp.count - 1 && !self.otp[self.otp.count - 1].isEmpty {
                    // All fields filled, hide keyboard
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            return
        }

        // Backspace handling: if field becomes empty, move to previous field (Android behavior)
        if newValue.isEmpty {
            otp[index] = ""
            // If field was already empty or just became empty, move to previous field
            if index > 0 {
                DispatchQueue.main.async {
                    self.focusedField = index - 1
                }
            } else {
                // First field, clear focus
                DispatchQueue.main.async {
                    self.focusedField = nil
                }
            }
            return
        }

        // Single digit entry: only allow one digit per field (Android behavior)
        guard let firstDigit = digits.first else {
            // Non-digit character entered, restore old value
            otp[index] = currentValue
            return
        }

        // Set the digit (limit to single character)
        otp[index] = String(firstDigit)
        
        // Move focus to next field asynchronously with small delay to avoid blocking
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if index < self.otp.count - 1 {
                self.focusedField = index + 1
            } else {
                // Last field filled, hide keyboard
                self.focusedField = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    }


    func showPermissionAlert() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let topVC = windowScene.windows.first?.rootViewController else { return }

        let alert = UIAlertController(
            title: "Contacts Permission Required",
            message: "This feature requires access to your contacts. Please enable it in settings.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default, handler: { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        }))

        topVC.present(alert, animated: true)
    }
    
    /// Check clipboard for 6-digit OTP and auto-fill if found (matching Android behavior)
    private func checkClipboardForOTP() {
        let pasteboard = UIPasteboard.general
        guard let clipboardText = pasteboard.string else { return }
        
        // Extract only digits
        let digits = clipboardText.filter { $0.isNumber }
        
        // Check if clipboard contains 6-digit OTP and all fields are empty
        if digits.count >= 6 {
            let allFieldsEmpty = otp.allSatisfy { $0.isEmpty }
            
            if allFieldsEmpty {
                // Extract first 6 digits
                let otpString = String(digits.prefix(6))
                
                // Fill all fields
                for i in 0..<min(6, otp.count) {
                    otp[i] = String(otpString[otpString.index(otpString.startIndex, offsetBy: i)])
                }
                
                // Focus on last field and hide keyboard (matching Android)
                focusedField = 5
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    }

}

#Preview {
    whatsTheCode(uid: "123456", c_id: "CID789", mobile_no: "+911234567890", country_Code: "+91")
}
