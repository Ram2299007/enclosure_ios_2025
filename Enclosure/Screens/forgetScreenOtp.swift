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

    @State private var fcmToken = "NEED TO ADD FIREBASE NOW"
    @State private var deviceId = "2" // युजरच्या डिव्हाइसचा UUID


    var body: some View {


        NavigationStack {
            ZStack { // Use ZStack to overlay content
                VStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Back Button
                            Button(action: {
                                withAnimation {
                                    isPressed = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    dismiss()
                                }
                            }) {
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
                            .padding(.top, 20)
                            .padding(.leading, 20)

                            // Title
                            Text("Verify\nYour number ?")
                                .font(.custom("Inter18pt-SemiBold", size: 40))
                                .foregroundColor(Color("TextColor"))
                                .padding(.leading, 20)
                                .padding(.top, 10)
                                .multilineTextAlignment(.leading)

                            // Subtitle
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Enter code we’ve sent to")
                                    .font(.custom("Inter18pt-Medium", size: 16))
                                    .foregroundColor(Color("TextColor"))

                                Text(mobile_no)
                                    .font(.custom("Inter18pt-Medium", size: 16))
                                    .foregroundColor(Color("TextColor"))
                            }
                            .padding(.leading, 20)

                            // OTP Input
                            HStack(spacing: 15) {
                                ForEach(0..<6, id: \.self) { index in
                                    TextField("", text: Binding(
                                        get: { otp[index] },
                                        set: { newValue in
                                            if newValue.count > 1 {
                                                otp[index] = String(newValue.prefix(1))
                                            } else {
                                                otp[index] = newValue
                                            }

                                            DispatchQueue.main.async {
                                                if !newValue.isEmpty {
                                                    if index < 5 {
                                                        focusedField = index + 1
                                                    } else {
                                                        focusedField = nil
                                                    }
                                                } else {
                                                    if index > 0 {
                                                        focusedField = index - 1
                                                    }
                                                }
                                            }
                                        }
                                    ))
                                    .frame(width: 50, height: 50)
                                    .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray, lineWidth: 1))
                                    .font(.custom("Inter18pt-Regular", size: 20))
                                    .multilineTextAlignment(.center)
                                    .keyboardType(.numberPad)
                                    .focused($focusedField, equals: index)
                                    .onTapGesture {
                                        focusedField = index
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 35)

                            // Invalid OTP Text
                            if showInvalidOTP {
                                Text("Invalid OTP")
                                    .foregroundColor(.red)
                                    .font(.custom("Inter18pt-Medium", size: 14))
                                    .padding(.top, 10)
                            }

                            // Resend Code
                            HStack(spacing: 2) {
                                Text("Didn't receive code?")
                                    .font(.custom("Inter18pt-Medium", size: 16))
                                    .foregroundColor(Color.gray)
                                    .padding(.leading, 20)

                                if isResendDisabled {
                                    Text("Send in \(resendTimer) sec.")
                                        .font(.custom("Inter18pt-Medium", size: 16))
                                        .foregroundColor(Color.gray)
                                } else {
                                    Button(action: {
                                        startResendTimer()
                                        //    viewModel.sendOTP(mobileNo: mobile_no, cID: c_id, cCode: country_Code)

                                        ApiService.shared
                                            .reSendOtpForget(mobile_no: self.mobile_no) { success, msg in
                                                if success
                                                {
                                                    Constant.showToast(message: msg)
                                                }else{
                                                    Constant.showToast(message: msg)
                                                }
                                            }

                                    }) {
                                        Text("Send again")
                                            .font(.custom("Inter18pt-Medium", size: 16))
                                            .foregroundColor(Color("TextColor"))
                                    }
                                }
                            }
                            .padding(.top, 48)
                        }
                    }

                    Spacer() // Pushes the button to the bottom



                    Button(
                        action: {
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
                            .font(.custom("Inter18pt-Medium", size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 55)
                            .background(RoundedRectangle(cornerRadius: 15).fill(Color("btn_color")))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }

                if verifyViewModel.isLoading {
                    ZStack {
                        VStack(spacing: 16) {
                            // Loader
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint:Color("TextColor")))
                                .scaleEffect(1.8)

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
            .onAppear {
                print("UID: \(uid), Country Code: \(country_Code), Mobile No: \(mobile_no)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // requestPermissions()
                }

            }
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

                                // Ensure uniqueness by checking formatted number
                                if !mobileNoSet.contains(formattedNumber) {
                                    contactList.append(ContactUploadModel(name: name, phoneNumber: number))
                                    mobileNoSet.insert(formattedNumber)

                                    var obj: [String: Any] = [:]
                                    obj["uid"] = uidKey
                                    obj["mobile_no"] = phoneKey
                                    obj["contact_name"] = name
                                    obj["contact_number"] = countryCodeKey + formattedNumber

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
