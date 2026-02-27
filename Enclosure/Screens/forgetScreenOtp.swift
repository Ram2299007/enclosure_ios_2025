import SwiftUI
import AVFoundation
import Photos
import Contacts
import UserNotifications

struct forgetScreenOtp: View {
    var uid: String

    var mobile_no: String
    var country_Code: String

    init(uid: String, mobile_no: String, country_Code: String) {
        self.uid = uid

        self.mobile_no = mobile_no
        self.country_Code = country_Code
        print("✅ Init Called - UID: \(uid), Country Code: \(country_Code), Mobile No: \(mobile_no)")

        UserDefaults.standard.set(self.mobile_no, forKey: Constant.PHONE_NUMBERKEY)
        UserDefaults.standard.set(self.uid, forKey: Constant.UID_KEY)

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


    // Helper function to hide keyboard
    private func hideKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    var body: some View {


        NavigationStack {
            ZStack { // Use ZStack to overlay content
                Color("background_color")
                    .ignoresSafeArea()
                
                VStack {
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
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onEnded { _ in
                                        withAnimation {
                                            isPressed = false
                                        }
                                    }
                            )
                            .buttonStyle(.plain)
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onEnded { _ in
                                        withAnimation {
                                            isPressed = false
                                        }
                                    }
                            )
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
                                    .focused($focusedField, equals: index)
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                        focusedField = index
                                        }
                                    }
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
                                        ApiService.shared
                                            .reSendOtpForget(mobile_no: self.mobile_no) { success, msg in
                                                if success {
                                                    Constant.showToast(message: msg)
                                                } else {
                                                    Constant.showToast(message: msg)
                                                }
                                            }
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
                    }
                    .simultaneousGesture(
                        TapGesture().onEnded { _ in hideKeyboard() }
                    )

                    Spacer() // Pushes the button to the bottom



                    // Verify Button
                    Button(action: {
                            if otp.contains("") {
                                otp = Array(repeating: "", count: 6)
                                focusedField = 0
                                Constant.showToast(message: "Invalid OTP")
                            } else {
                                let contactStore = CNContactStore()
                                let authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)

                                switch authorizationStatus {
                                case .notDetermined:
                                    // Request permission
                                    contactStore.requestAccess(for: .contacts) {
                                        granted,
                                        error in
                                        DispatchQueue.main.async {
                                            if granted {
                                                ApiService.shared
                                                    .verify_otp_for_forgetOtp(
                                                        uid: uid,
                                                        otp: otp.joined()) {
                                                            success,
                                                            msg in
                                                            if success{

                                                                /// inside get pin api
                                                                ApiService.shared
                                                                    .forget_lock_screen(
                                                                        uid: self.uid,
                                                                        mobile_no: self.mobile_no
                                                                    ) { success, message, data in
                                                                        if success {
                                                                            print("Success: \(message)")
                                                                            if let data = data {
                                                                                print("Mobile No: \(data["mobile_no"] as? String ?? "N/A")")
                                                                                print("Lock Screen: \(data["lock_screen"] as? String ?? "N/A")")
                                                                                print("Lock Screen PIN: \(data["lock_screen_pin"] as? String ?? "N/A")")

                                                                                dismiss()
                                                                                Constant
                                                                                    .showToast(
                                                                                        message: "\(data["lock_screen_pin"] as? String ?? "N/A")°"
                                                                                    )

                                                                            }
                                                                        } else {
                                                                            print("Failed: \(message)")
                                                                        }
                                                                    }

                                                            }else{
                                                                Constant.showToast(message: msg)
                                                            }
                                                        }
                                            } else {
                                                showPermissionAlert()
                                            }
                                        }
                                    }

                                case .authorized:
                                    // Permission already granted, proceed with OTP verification
                                ApiService.shared
                                    .verify_otp_for_forgetOtp(
                                        uid: uid,
                                        otp: otp.joined()) {
                                            success,
                                            msg in
                                            if success{

                                                /// inside get pin api
                                    ApiService.shared
                                        .forget_lock_screen(
                                            uid: self.uid,
                                            mobile_no: self.mobile_no
                                        ) { success, message, data in
                                            if success {
                                                print("Success: \(message)")
                                                if let data = data {
                                                    print("Mobile No: \(data["mobile_no"] as? String ?? "N/A")")
                                                    print("Lock Screen: \(data["lock_screen"] as? String ?? "N/A")")
                                                    print("Lock Screen PIN: \(data["lock_screen_pin"] as? String ?? "N/A")")

                                                    dismiss()
                                                    Constant
                                                        .showToast(
                                                            message: "\(data["lock_screen_pin"] as? String ?? "N/A")°"
                                                        )

                                                }
                                            } else {
                                                print("Failed: \(message)")
                                            }
                                        }

                                            }else{
                                                Constant.showToast(message: msg)
                                            }
                                        }

                                case .denied,
                                        .restricted:
                                    // Permission denied, show alert to open settings
                                    showPermissionAlert()
                                @unknown default:
                                    break
                                }
                            }
                        })
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
            .background(NavigationGestureEnabler())
            .onAppear {
                print("UID: \(uid), Country Code: \(country_Code), Mobile No: \(mobile_no)")
                
                // Get FCM token
                FirebaseManager.shared.getFCMToken { token in
                    if let token = token {
                        DispatchQueue.main.async {
                            self.fcmToken = token
                        }
                    } else {
                        // Fallback: try to get from UserDefaults if available
                        if let savedToken = UserDefaults.standard.string(forKey: Constant.FCM_TOKEN) {
                            DispatchQueue.main.async {
                                self.fcmToken = savedToken
                            }
                        }
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // requestPermissions()
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


    /// Function to request necessary permissions
    private func requestPermissions() {
        requestContactsPermission()
        requestPhotoLibraryPermission()
        requestCameraPermission()
        requestMicrophonePermission()
        requestNotificationPermission()
    }

    /// Request Contacts Permission
    private func requestContactsPermission() {
        DispatchQueue.main.async {
            let store = CNContactStore()
            store.requestAccess(for: .contacts) { granted, error in
                if granted {
                    print("Contacts permission granted")

                    // Provide the necessary parameters for getContactList
                    let uidKey = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? "Not Found" // Assuming 'uid' is a property of your struct
                    let countryCodeKey = UserDefaults.standard.string(forKey: Constant.country_Code) ?? "Not Found" // Assuming 'country_Code' is a property of your struct
                    let phoneKey = UserDefaults.standard.string(forKey: Constant.PHONE_NUMBERKEY) ?? "Not Found" // Assuming 'mobile_no' is a property of your struct



                    self.getContactList(uidKey: uidKey, countryCodeKey: countryCodeKey, phoneKey: phoneKey) { contacts, error in
                        if let contacts = contacts {
                            // Handle the list of contacts
                            print("1 \(contacts.count) contacts")
                            print("uid \(uid)")
                            print("mobile_no \(mobile_no)")
                            //Process the contacts here.
                        } else if let error = error {
                            // Handle the error
                            print("Error retrieving contacts: \(error)")
                        }
                    }
                } else {
                    print("Contacts permission denied: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }


    /// Request Photo Library Permission
    private func requestPhotoLibraryPermission() {
        DispatchQueue.main.async {
            PHPhotoLibrary.requestAuthorization { status in
                switch status {
                case .authorized, .limited:
                    print("Photo Library permission granted")
                case .denied, .restricted:
                    print("Photo Library permission denied")
                case .notDetermined:
                    print("Photo Library permission not determined yet")
                @unknown default:
                    break
                }
            }
        }
    }


    /// Request Camera Permission
    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            print(granted ? "Camera permission granted" : "Camera permission denied")
        }
    }


    /// Request Microphone Permission
    private func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            print(granted ? "Microphone permission granted" : "Microphone permission denied")
        }
    }


    /// Request Notification Permission
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print(granted ? "Notification permission granted" : "Notification permission denied: \(error?.localizedDescription ?? "Unknown error")")
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


    func showPermissionAlert() {
        guard let topVC = UIApplication.shared.windows.first?.rootViewController else { return }

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



}

#Preview {
    forgetScreenOtp(uid: "123456", mobile_no: "+911234567890", country_Code: "+91")
}
