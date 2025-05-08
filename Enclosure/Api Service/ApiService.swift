import Alamofire
import Foundation
import AVFoundation
import SwiftUI
import Photos
import Contacts
import UserNotifications

class ApiService {
    static let shared = ApiService()
    @State private var isActive = false



    private init() {}

    func uploadUserContactList(uid: String, fileURL: URL?, fileName: String?, countryCodeKey: String?, completion: @escaping (Bool, String) -> Void) {
        print("📡 Calling Sync Contacts API...")
        let endpoint = Constant.baseURL + "upload_user_contact_list"
        let headers: HTTPHeaders = [
            "Content-Type": "multipart/form-data"
        ]

        AF.upload(
            multipartFormData: { multipartFormData in
                if let fileURL = fileURL, let fileName = fileName {
                    multipartFormData.append(fileURL, withName: "cjson", fileName: fileName, mimeType: "application/json")
                }
                multipartFormData.append(Data(uid.utf8), withName: "uid")
            },
            to: endpoint,
            method: .post,
            headers: headers
        ).response { response in
            if let data = response.data, let rawResponse = String(data: data, encoding: .utf8) {
                print("🔍 Raw Server Response: \(rawResponse)")

                // JSON डेटा वेगळा करा
                if let jsonStartIndex = rawResponse.range(of: "{") {
                    let jsonString = String(rawResponse[jsonStartIndex.lowerBound...]) // फक्त JSON ठेवा
                    if let jsonData = jsonString.data(using: .utf8) {
                        do {
                            if let jsonResponse = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                                print("✅ Extracted JSON Response: \(jsonResponse)")

                                if let errorCode = jsonResponse["error_code"] as? String, errorCode == "200" {
                                    print("🎉 Contact list uploaded successfully!")
                                    completion(true, "Contact list uploaded successfully.")
                                } else {
                                    let message = jsonResponse["message"] as? String ?? "Unknown error"
                                    print("⚠️ Error: \(message)")
                                    completion(false, message)
                                }
                            }
                        } catch {
                            print("❌ JSON Parsing Error: \(error.localizedDescription)")
                            completion(false, "JSON Parsing Error")
                        }
                    }
                } else {
                    print("❌ Invalid Response Format")
                    completion(false, "Invalid Response Format")
                }
            } else {
                print("❌ No Response Data")
                completion(false, "No Response Data")
            }
        }
    }


    func saveContactFile(fileName: String, completion: @escaping (Bool, String) -> Void) {
        let url = Constant.baseURL + "PageController/contact_file_save"
        let parameters: [String: String] = ["file_name": fileName]

        AF.request(url, method: .get, parameters: parameters)
            .validate()
            .responseJSON { response in
                switch response.result {
                case .success(let data):
                    if let json = data as? [String: Any],
                       let status = json["status"] as? String,
                       let message = json["message"] as? String {

                        let isSuccess = (status.lowercased() == "success") // ✅ Success चेक
                        completion(isSuccess, message)
                    } else {
                        completion(false, "Invalid response")
                    }
                case .failure(let error):
                    completion(false, error.localizedDescription)
                }
            }
    }


    func lockScreen(uid: String, lockScreen: String, lockScreenPin: String, lock3: String, completion: @escaping (Bool, String) -> Void) {
        let url = Constant.baseURL + "lock_screen"
        let parameters: [String: Any] = [
            "uid": uid,
            "lock_screen": lockScreen,
            "lock_screen_pin": lockScreenPin
        ]

        print("Request URL: \(url)")
        print("Parameters: \(parameters)")

        AF.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default)
            .validate()
            .responseJSON { response in
                print("Response received: \(response)")

                // Debug: Print raw response
                if let data = response.data, let rawString = String(data: data, encoding: .utf8) {
                    print("Raw Response String: \(rawString)")
                }

                switch response.result {
                case .success(let value):
                    print("Response Data: \(value)")

                    if let json = value as? [String: Any],
                       let errorCodeString = json["error_code"] as? String,
                       let errorCode = Int(errorCodeString),
                       let message = json["message"] as? String {

                        print("Error Code: \(errorCode), Message: \(message)")

                        if errorCode == 200 {
                            DispatchQueue.main.async {
                                if lockScreen == "1" {
                                    UserDefaults.standard.set(lockScreenPin, forKey: "lockKey")
                                    UserDefaults.standard.set("", forKey: Constant.sleepKeyCheckOFF)

                                    ///print("Lock screen set. lockScreenPin: \(lockScreenPin), sleepKeyCheckOFF: \(UserDefaults.standard.string(forKey: "sleepKeyCheckOFF") ?? "nil")")

                                    if lockScreenPin == "360" && UserDefaults.standard.string(forKey: Constant.sleepKey) == Constant.sleepKey {
                                        Constant.showToast(message: "Sleep mode activated !")
                                        completion(true, "Sleep mode is activated !!")
                                    } else {

                                        // TODO: MAIN ACTIVITY HERE NEED TO CALL

                                        Constant.showToast(message: "Screen locked !")
                                        completion(true, "Screen locked!")
                                    }
                                } else if lockScreen == "0" {
                                    if lock3 == "lock3" {

                                        // TODO: NEED TO CALL LOCKSCREEN.SWIFT ACTIVITY HERE

                                        self.isActive = true

                                        NavigationLink(
                                            destination: LockScreenView(),
                                            isActive: self.$isActive
                                        ) {
                                            EmptyView() // Hidden Navigation Link
                                        }



                                        print("Navigating to lock screen")
                                        completion(true, "Navigate to lock screen")
                                    } else if message == "Screen unlocked !" {

                                        if let sleepKey = UserDefaults.standard.string(forKey: Constant.sleepKey), sleepKey == Constant.sleepKey {
                                            UserDefaults.standard.set("", forKey: Constant.sleepKey)
                                            UserDefaults.standard.set(Constant.sleepKeyCheckOFF, forKey: Constant.sleepKeyCheckOFF)
                                        }


                                        // TODO: MAIN ACTIVITY HERE NEED TO CALL pass data lockScreen to main activity use below commented android code

                                        /* Intent intent = new Intent(mContext, MainActivityOld.class);
                                         intent.putExtra("lockSuccess", "lockSuccess");
                                         mContext.startActivity(intent);*/

                                        print("Screen unlocked. sleepKey: \(UserDefaults.standard.string(forKey: "sleepKey") ?? "nil")")

                                        completion(true, message)
                                    } else {
                                        print("Unlock failed: \(message)")
                                        completion(false, message)
                                    }
                                }
                            }
                        } else {
                            print("Error from server: \(message)")
                            completion(false, message)
                        }
                    } else {
                        print("Invalid JSON response")
                        completion(false, "Invalid response format")
                    }
                case .failure(let error):
                    print("Request failed: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                }
            }
    }






    //TODO: form data - Postman

    func reSendOtpForget(mobile_no: String, completion: @escaping (Bool, String) -> Void) {
        let url = Constant.baseURL + "send_otp_common"
        let parameters: [String: Any] = [
            "mobile_no": mobile_no,

        ]
        print("Request URL: \(url)")
        print("Parameters: \(parameters)")

        AF.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default)
            .validate()
            .responseJSON { response in
                print("Response received: \(response)")

                // Debug: Print raw response
                if let data = response.data, let rawString = String(data: data, encoding: .utf8) {
                    print("Raw Response String: \(rawString)")
                }

                switch response.result {
                case .success(let value):
                    print("Response Data: \(value)")

                    if let json = value as? [String: Any],
                       let errorCodeString = json["error_code"] as? String, // String म्हणून घ्या
                       let errorCode = Int(errorCodeString),

                        let message = json["message"] as? String {

                        print("Error Code: \(errorCode), Message: \(message)")

                        if errorCode == 200 {
                            completion(true, message)
                            DispatchQueue.main.async {


                            }
                        } else {
                            completion(false, message)
                            print("Error from server: \(message)")
                            completion(false, message)
                            Constant.showToast(message: message)
                        }
                    } else {
                        print("Invalid JSON response")
                        completion(false, "Invalid response format")
                    }
                case .failure(let error):
                    print("Request failed: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                }
            }
    }





    //TODO: form data - Postman

    func verify_otp_for_forgetOtp(uid: String,otp: String, completion: @escaping (Bool, String) -> Void) {
        let url = Constant.baseURL + "verify_otp_common"
        let parameters: [String: Any] = [
            "uid": uid,
            "otp": otp

        ]

        print("Request URL: \(url)")
        print("Parameters: \(parameters)")

        AF.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default)
            .validate()
            .responseJSON { response in
                print("Response received: \(response)")

                // Debug: Print raw response
                if let data = response.data, let rawString = String(data: data, encoding: .utf8) {
                    print("Raw Response String: \(rawString)")
                }

                switch response.result {
                case .success(let value):
                    print("Response Data: \(value)")

                    if let json = value as? [String: Any],
                       let errorCodeString = json["error_code"] as? String, // String म्हणून घ्या
                       let errorCode = Int(errorCodeString),

                        let message = json["message"] as? String {

                        print("Error Code: \(errorCode), Message: \(message)")

                        if errorCode == 200 {
                            completion(true, message)
                            DispatchQueue.main.async {




                            }
                        } else {
                            completion(false, message)
                            print("Error from server: \(message)")
                            completion(false, message)

                        }
                    } else {
                        print("Invalid JSON response")
                        completion(false, "Invalid response format")
                    }
                case .failure(let error):
                    print("Request failed: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                }
            }
    }





    //TODO: form data - Postman

    func forget_lock_screen(uid: String, mobile_no: String, completion: @escaping (Bool, String, [String: Any]?) -> Void) {
        let url = Constant.baseURL + "forget_lock_screen"
        let parameters: [String: Any] = [
            "uid": uid,
            "mobile_no": mobile_no
        ]

        print("Request URL: \(url)")
        print("Parameters: \(parameters)")

        AF.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default)
            .validate()
            .responseJSON { response in
                print("Response received: \(response)")

                if let data = response.data, let rawString = String(data: data, encoding: .utf8) {
                    print("Raw Response String: \(rawString)")
                }

                switch response.result {
                case .success(let value):
                    print("Response Data: \(value)")

                    if let json = value as? [String: Any],
                       let success = json["success"] as? String,
                       let errorCodeString = json["error_code"] as? String,
                       let errorCode = Int(errorCodeString),
                       let message = json["message"] as? String {

                        print("Success: \(success), Error Code: \(errorCode), Message: \(message)")

                        // "data" मधील सर्व व्हॅल्यू काढणे
                        var extractedData: [String: Any]? = nil
                        if let dataArray = json["data"] as? [[String: Any]], let firstItem = dataArray.first {
                            extractedData = firstItem
                            print("Extracted Data: \(extractedData!)")
                        }

                        if errorCode == 200 {
                            completion(true, message, extractedData)
                        } else {
                            completion(false, message, extractedData)
                        }
                    } else {
                        print("Invalid JSON response")
                        completion(false, "Invalid response format", nil)
                    }
                case .failure(let error):
                    print("Request failed: \(error.localizedDescription)")
                    completion(false, error.localizedDescription, nil)
                }
            }

    }




    static func get_user_active_chat_list(uid: String, completion: @escaping (Bool, String, [UserActiveContactModel]?) -> Void) {
        let url = Constant.baseURL+"get_user_active_chat_list"
        let parameters: [String: Any] = ["uid": uid]
        
        AF.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default)
            .validate()
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do {
                        let decoded = try JSONDecoder().decode(UserContactResponse.self, from: data)
                        if decoded.errorCode == "200" {
                            completion(true, decoded.message, decoded.data)
                        } else {
                            completion(false, decoded.message, decoded.data)
                        }
                    } catch {
                        print("Decoding error: \(error.localizedDescription)")
                        completion(false, "Decoding failed", nil)
                    }

                case .failure(let error):
                    print("Request error: \(error.localizedDescription)")
                    completion(false, error.localizedDescription, nil)
                }
            }
    }



    static func get_profile_YouFragment(uid: String, completion: @escaping (Bool, String, [GetProfileModel]?) -> Void) {
        let url = Constant.baseURL+"get_profile"
        let parameters: [String: Any] = ["uid": uid]

        AF.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default)
            .validate()
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do {
                        let decoded = try JSONDecoder().decode(GetProfileResponse.self, from: data)
                        if decoded.error_code == "200" {
                            completion(true, decoded.message, decoded.data)
                        } else {
                            completion(false, decoded.message, decoded.data)
                        }
                    } catch {
                        print("Decoding error: \(error.localizedDescription)")
                        completion(false, "Decoding failed", nil)
                    }

                case .failure(let error):
                    print("Request error: \(error.localizedDescription)")
                    completion(false, error.localizedDescription, nil)
                }
            }
    }



    static func get_user_profile_images_youFragment(uid: String, completion: @escaping (Bool, String, [GetUserProfileImagesModel]?) -> Void) {
        let url = Constant.baseURL+"get_user_profile_images"
        let parameters: [String: Any] = ["uid": uid]

        AF.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default)
            .validate()
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do {
                        let decoded = try JSONDecoder().decode(GetUserProfileImagesResponse.self, from: data)
                        if decoded.error_code == "200" {
                            completion(true, decoded.message, decoded.data)
                        } else {
                            completion(false, decoded.message, decoded.data)
                        }
                    } catch {
                        print("Decoding error: \(error.localizedDescription)")
                        completion(false, "Decoding failed", nil)
                    }

                case .failure(let error):
                    print("Request error: \(error.localizedDescription)")
                    completion(false, error.localizedDescription, nil)
                }
            }
    }


}
