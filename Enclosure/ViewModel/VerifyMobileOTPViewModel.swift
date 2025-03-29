import Foundation
import SwiftUI

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

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyString = "uid=\(uid)&mob_otp=\(otp)&f_token=\(token)&device_id=\(deviceId)"
        request.httpBody = bodyString.data(using: .utf8)

        print("📤 Sending Request: \(bodyString)")

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

                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            print("🔹 Storing user data...\(cCode)")
                            self.phone = phone
                            UserDefaults.standard.set(phone, forKey: Constant.PHONE_NUMBERKEY)
                            UserDefaults.standard.set(uid, forKey: Constant.UID_KEY)
                            UserDefaults.standard.set(cCode,forKey: Constant.country_Code)
                            UserDefaults.standard.set(fcmToken, forKey: Constant.FCM_TOKEN)
                            self.errorMessage = nil

                            DispatchQueue.main.async {
                                // ✅ Start Loader after storing data
                                print("🚀 Starting Loader...")
                                self.isLoading = true
                                self.loadingMessage = "Your contacts are synchronizing..."
                            }
                            // ✅ Call another API here
                            print("📂 Current fileURL: \(self.fileURL?.absoluteString ?? "nil")")
                            print("📂File name \(self.fileName)");
                            print("📂countryCodeKey name \(self.countryCodeKey)");

                            ApiService.shared
                                .uploadUserContactList(
                                    uid: uid,
                                    fileURL: self.fileURL,
                                    fileName: self.fileName, countryCodeKey: self.countryCodeKey
                                ){
                                    success,
                                    message in
                                    DispatchQueue.main.async {

                                    }
                                    if success {
                                        print("✅ Success: \(message)")
                                        ApiService.shared
                                            .saveContactFile(
                                                fileName: self.fileName ?? "contact_.json"
                                            ) {
                                                success,
                                                message in DispatchQueue.main.async {
                                                    self.isLoading = false
                                                }
                                                if success {
                                                    print("✅ Success2: \(message)")
                                                    /// here we need to send go to lockscreen
                                                    ///Here we need to store local data here
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


                                    } else {
                                        print("❌ Failure: \(message)")
                                    }
                                }

                        }

                        print("✅ Verification Success: Phone = \(phone), FCM Token = NEED TO ADD FIREBASE NOW, UID = \(uid)")
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
