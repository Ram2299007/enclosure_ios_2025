import Foundation
import SwiftUI
import UIKit

class VerifyMobileOTPViewModel: ObservableObject {
    @Published var isNavigating = false
    @Published var isLoading = false
    @Published var loadingMessage: String?
    @Published var errorMessage: String?
    @Published var phone: String?
    @Published var fileName: String?
    @Published var countryCodeKey: String?
    @Published var fileURL: URL?

    func verifyOTP(uid: String, otp: String,cCode:String, token: String, deviceId: String) {
        self.errorMessage = nil
        self.isLoading = true

        let urlString = Constant.baseURL + "verify_mobile_otp"
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            return
        }

        // Get phone_id (equivalent to Android's Settings.Secure.ANDROID_ID)
        let phoneId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        print("📱 Phone ID: \(phoneId)")

        // Resolve FCM token (required by backend). Prefer passed token, fallback to stored.
        let resolvedToken = token.isEmpty
            ? (UserDefaults.standard.string(forKey: Constant.FCM_TOKEN) ?? "")
            : token

        // If we still do not have a token (APNs not ready), use a safe placeholder so
        // the backend gets a non-empty value while we surface a warning.
        let finalToken: String
        if resolvedToken.isEmpty {
            finalToken = "apns_missing"
            print("⚠️ Missing f_token; using placeholder \(finalToken)")
        } else {
            finalToken = resolvedToken
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Matching Android parameters: uid, mob_otp, f_token, device_id, phone_id (+ country code)
        let params: [String: String] = [
            "uid": uid,
            "mob_otp": otp,
            "f_token": finalToken,
            "device_id": deviceId,
            "phone_id": phoneId,
            "country_code": cCode
        ]

        let bodyString = params
            .map { key, value in
                let escaped = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                return "\(key)=\(escaped)"
            }
            .joined(separator: "&")

        request.httpBody = bodyString.data(using: .utf8)

        print("📤 API: verify_mobile_otp")
        print("📤 Parameters: uid=\(uid), mob_otp=\(otp), f_token=\(resolvedToken), device_id=\(deviceId), phone_id=\(phoneId), country_code=\(cCode)")
        print("📤 Full Request Body: \(bodyString)")

        URLSession.shared.dataTask(with: request) {
            data,
            response,
            error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                }
                print("❌ Network Error: \(error.localizedDescription)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid Response")
                return
            }
            print("📩 Response Status Code: \(httpResponse.statusCode)")

            guard let data = data else {
                DispatchQueue.main.async {
                    self.errorMessage = "No data received"
                }
                print("❌ No data received")
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
                            self.errorMessage = nil
                            
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
                                                        print("❌ Error: \(message)")
                                                    }
                                                }
                                            }
                                    } else {
                                        print("❌ Failure: \(message)")
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
                        print("❌ Error: Invalid data format from API")
                    }
                } else {

                    DispatchQueue.main.async {

                    }
                    let message = json?["message"] as? String ?? "Unknown error"
                    print("❌ API returned an error: \(message)")


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
                print("❌ JSON Parsing Error: \(error.localizedDescription)")
            }
        }.resume()
    }


}
