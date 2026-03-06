import Foundation
import SwiftUI
import UIKit
import FirebaseMessaging

class VerifyMobileOTPViewModel: ObservableObject {
    @Published var isNavigating = false
    @Published var isLoading = false
    @Published var loadingMessage: String?
    @Published var errorMessage: String?
    @Published var phone: String?
    @Published var fileName: String?
    @Published var countryCodeKey: String?
    @Published var fileURL: URL?

    func verifyOTP(uid: String, otp: String,cCode:String, token: String, deviceId: String, voipToken: String? = nil) {
        self.errorMessage = nil
        self.isLoading = true

        let urlString = Constant.baseURL + "verify_mobile_otp"
        guard let url = URL(string: urlString) else {
            print("🚫 Invalid URL: \(urlString)")
            return
        }

        // Get phone_id (equivalent to Android's Settings.Secure.ANDROID_ID)
        let phoneId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        print("📱 Phone ID: \(phoneId)")

        // Resolve FCM token (required by backend). Prefer passed token, fallback to stored.
        let resolvedToken = token.isEmpty
            ? (UserDefaults.standard.string(forKey: Constant.FCM_TOKEN) ?? "")
            : token

        print("🔑 [VERIFY_OTP] FCM Token Check:")
        print("🔑 [VERIFY_OTP]   - Passed token: \(token.isEmpty ? "EMPTY" : "\(token.prefix(50))...")")
        print("🔑 [VERIFY_OTP]   - UserDefaults token: \(UserDefaults.standard.string(forKey: Constant.FCM_TOKEN) ?? "EMPTY")")
        print("🔑 [VERIFY_OTP]   - Resolved token: \(resolvedToken.isEmpty ? "EMPTY" : "\(resolvedToken.prefix(50))...")")
        
        // If we still do not have a token (APNs not ready), check notification permissions and try to get token
        let finalToken: String
        if resolvedToken.isEmpty || resolvedToken == "apns_missing" {
            print("⚠️ [VERIFY_OTP] Token is empty or 'apns_missing' - checking notification permissions...")
            
            // Check notification permission status first
            let semaphore = DispatchSemaphore(value: 0)
            var permissionGranted = false
            var fetchedToken: String? = nil
            
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                print("🔑 [VERIFY_OTP] ===== NOTIFICATION PERMISSION CHECK =====")
                print("🔑 [VERIFY_OTP] Authorization status: \(settings.authorizationStatus.rawValue)")
                print("🔑 [VERIFY_OTP] Authorization status string: \(self.authorizationStatusString(settings.authorizationStatus))")
                print("🔑 [VERIFY_OTP] Alert setting: \(settings.alertSetting.rawValue)")
                print("🔑 [VERIFY_OTP] Badge setting: \(settings.badgeSetting.rawValue)")
                print("🔑 [VERIFY_OTP] Sound setting: \(settings.soundSetting.rawValue)")
                print("🔑 [VERIFY_OTP] Is simulator: \(self.isSimulator())")
                print("🔑 [VERIFY_OTP] =========================================")
                
                permissionGranted = (settings.authorizationStatus == .authorized)
                
                if !permissionGranted {
                    print("🚫 [VERIFY_OTP] Notification permission not granted (status: \(settings.authorizationStatus.rawValue)) - cannot get APNs token")
                    semaphore.signal()
                    return
                }
                
                if self.isSimulator() {
                    print("⚠️ [VERIFY_OTP] Running on simulator - APNs tokens only work on real devices!")
                    semaphore.signal()
                    return
                }
                
                // Permission granted - ensure we're registered for remote notifications
                print("✅ [VERIFY_OTP] Notification permission granted - checking if registered for remote notifications...")
                DispatchQueue.main.async {
                    // Check if APNs token is already set
                    if Messaging.messaging().apnsToken != nil {
                        print("✅ [VERIFY_OTP] APNs token already set - fetching FCM token...")
                        Messaging.messaging().token { token, error in
                            if let error = error {
                                print("🚫 [VERIFY_OTP] Error fetching FCM token: \(error.localizedDescription)")
                            } else if let token = token, !token.isEmpty {
                                print("✅ [VERIFY_OTP] FCM token fetched successfully: \(token.prefix(50))...")
                                fetchedToken = token
                                UserDefaults.standard.set(token, forKey: Constant.FCM_TOKEN)
                            } else {
                                print("🚫 [VERIFY_OTP] FCM token is nil")
                            }
                            semaphore.signal()
                        }
                    } else {
                        print("⚠️ [VERIFY_OTP] APNs token not set - registering for remote notifications...")
                        UIApplication.shared.registerForRemoteNotifications()
                        print("📱 [VERIFY_OTP] registerForRemoteNotifications() called - returning immediately (no waiting)")
                        // Return immediately instead of waiting
                        // FCM token will be available via MessagingDelegate callback when APNs token is ready
                        semaphore.signal()
                    }
                }
            }
            
            // Wait briefly for token (no waiting for APNs - returns immediately)
            let result = semaphore.wait(timeout: .now() + 1.0)
            
            if result == .timedOut {
                print("⏱️ [VERIFY_OTP] Timeout waiting for FCM token (1 second)")
                finalToken = "apns_missing"
            } else if let token = fetchedToken, !token.isEmpty {
                print("✅ [VERIFY_OTP] Using fetched FCM token")
                finalToken = token
            } else {
                print("⚠️ [VERIFY_OTP] Still no token available - using placeholder")
                finalToken = "apns_missing"
            }
        } else {
            finalToken = resolvedToken
            print("✅ [VERIFY_OTP] Using resolved token")
        }
        
        print("🔑 [VERIFY_OTP] Final token to send: \(finalToken == "apns_missing" ? "apns_missing" : "\(finalToken.prefix(50))...")")

        // Get VoIP token from VoIPPushManager or use passed token
        let currentVoIPToken = voipToken ?? VoIPPushManager.shared.getVoIPToken() ?? ""
        
        print("🔑 [VERIFY_OTP] Sending tokens to backend:")
        print("🔑 [VERIFY_OTP]   - FCM Token: \(finalToken == "apns_missing" ? "apns_missing" : "\(finalToken.prefix(20))...")")
        print("🔑 [VERIFY_OTP]   - VoIP Token: \(currentVoIPToken.isEmpty ? "EMPTY - will be sent later" : "\(currentVoIPToken.prefix(20))...")")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Matching Android parameters: uid, mob_otp, f_token, voip_token, device_id, phone_id, country_code, device_type (2 = iOS for backend to store)
        let params: [String: String] = [
            "uid": uid,
            "mob_otp": otp,
            "f_token": finalToken,
            "voip_token": currentVoIPToken,  // VoIP token for CallKit push notifications
            "device_id": deviceId,
            "phone_id": phoneId,
            "country_code": cCode,
            "device_type": "2"  // iOS; backend stores this so send_notification_api can add FCM notification block for iOS receivers
        ]

        let bodyString = params
            .map { key, value in
                let escaped = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                return "\(key)=\(escaped)"
            }
            .joined(separator: "&")

        request.httpBody = bodyString.data(using: .utf8)

        print("📤 API: verify_mobile_otp")
        print("📤 Parameters: uid=\(uid), mob_otp=\(otp), f_token=\(finalToken == "apns_missing" ? "apns_missing" : "\(finalToken.prefix(50))..."), voip_token=\(currentVoIPToken.isEmpty ? "EMPTY" : "\(currentVoIPToken.prefix(20))..."), device_id=\(deviceId), phone_id=\(phoneId), country_code=\(cCode)")
        print("📤 Full Request Body: \(bodyString)")

        URLSession.shared.dataTask(with: request) {
            data,
            response,
            error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                }
                print("🚫 Network Error: \(error.localizedDescription)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("🚫 Invalid Response")
                return
            }
            print("📩 Response Status Code: \(httpResponse.statusCode)")

            guard let data = data else {
                DispatchQueue.main.async {
                    self.errorMessage = "No data received"
                }
                print("🚫 No data received")
                return
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                print("📩 Response JSON: \(json ?? [:])")

                if let errorCodeString = json?["error_code"] as? String,
                   let errorCode = Int(errorCodeString),
                   errorCode == 200 {
                    if let dataArray = json?["data"] as? [[String: Any]],
                       let firstObject = dataArray.first {
                        let phone = firstObject["mobile_no"] as? String ?? ""
                        let fcmToken = firstObject["f_token"] as? String ?? ""
                        let deviceTypeFromApi = firstObject["device_type"] as? String ?? "2"

                        DispatchQueue.main.async {
                            // ✅ Start Loader immediately (matching Android - no delay)
                            print("🚀 Starting Loader...")
                            self.isLoading = true
                            self.loadingMessage = "Your contacts are synchronizing..."
                            
                            // Store user data (matching Android - country_codeKey stored later)
                            print("🔹 Storing user data...")
                            self.phone = phone
                            UserDefaults.standard.set(phone, forKey: Constant.PHONE_NUMBERKEY)
                            UserDefaults.standard.set(uid, forKey: Constant.UID_KEY)
                            UserDefaults.standard.set(fcmToken, forKey: Constant.FCM_TOKEN)
                            UserDefaults.standard.set(deviceTypeFromApi, forKey: Constant.DEVICE_TYPE_KEY)
                            self.errorMessage = nil
                            
                            // Fetch get_profile; only save device_type when it matches get_user_active_chat_list format ("1" or "2"), not UUID
                            ApiService.get_profile(uid: uid) { _, profile, _ in
                                if let dt = profile?.device_type, !dt.isEmpty, (dt == "1" || dt == "2") {
                                    UserDefaults.standard.set(dt, forKey: Constant.DEVICE_TYPE_KEY)
                                }
                            }
                            
                            // ✅ Call upload_user_contact_list immediately (matching Android)
                            print("📂 Current fileURL: \(self.fileURL?.absoluteString ?? "nil")")
                            print("📂File name \(self.fileName ?? "nil")")
                            print("📂countryCodeKey name \(self.countryCodeKey ?? "nil")")

                            ApiService.shared
                                .uploadUserContactList(
                                    uid: uid,
                                    fileURL: self.fileURL,
                                    fileName: self.fileName, countryCodeKey: self.countryCodeKey
                                ){
                                    success,
                                    message in
                                    if success {
                                        print("✅ Success: \(message)")
                                        ApiService.shared
                                            .saveContactFile(
                                                fileName: self.fileName ?? "contact_.json"
                                            ) {
                                                success,
                                                message in
                                                DispatchQueue.main.async {
                                                    // Dismiss loader (matching Android progressBar.dismiss())
                                                    self.isLoading = false
                                                    
                                                    if success {
                                                        print("✅ Success2: \(message)")
                                                        // Store data and navigate (matching Android)
                                                        UserDefaults.standard.set(
                                                            Constant.loggedInKey,
                                                            forKey: Constant.loggedInKey
                                                        )
                                                        UserDefaults.standard.set(
                                                            cCode,
                                                            forKey: Constant.country_Code
                                                        )

                                                        self.isNavigating = true
                                                    } else {
                                                        print("🚫 Error: \(message)")
                                                    }
                                                }
                                            }
                                    } else {
                                        print("🚫 Failure: \(message)")
                                        DispatchQueue.main.async {
                                            self.isLoading = false
                                        }
                                    }
                                }
                        }

                        print("✅ Verification Success: Phone = \(phone), FCM Token = \(fcmToken), UID = \(uid)")
                    } else {
                        DispatchQueue.main.async {
                            self.errorMessage = "Invalid data format from API"
                        }
                        print("🚫 Error: Invalid data format from API")
                    }
                } else {

                    DispatchQueue.main.async {

                    }
                    let message = json?["message"] as? String ?? "Unknown error"
                    print("🚫 API returned an error: \(message)")


                    DispatchQueue.main.async {
                        self.errorMessage = message
                        // ✅ Start Loader after storing data
                        print("🚀 Starting Loader...")
                        self.isLoading = false
                        self.loadingMessage = ""

                        Constant.showToast(message: message)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to parse response"
                }
                print("🚫 JSON Parsing Error: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    private func authorizationStatusString(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .denied: return "denied"
        case .authorized: return "authorized"
        case .provisional: return "provisional"
        case .ephemeral: return "ephemeral"
        @unknown default: return "unknown"
        }
    }
    
    private func isSimulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }


}
