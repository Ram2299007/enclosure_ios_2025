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
            .validate(statusCode: 200..<500)
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
        
        print("🟢 [ApiService] get_user_active_chat_list - URL: \(url)")
        print("🟢 [ApiService] get_user_active_chat_list - Parameters: \(parameters)")

        AF.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default)
            .validate()
            .responseData { response in
                print("🟢 [ApiService] Response received - Status: \(response.response?.statusCode ?? 0)")
                
                switch response.result {
                case .success(let data):
                    print("🟢 [ApiService] Response success - Data size: \(data.count) bytes")
                    if let rawString = String(data: data, encoding: .utf8) {
                        print("🟢 [ApiService] Raw response: \(rawString)")
                    }
                    
                    do {
                        let decoded = try JSONDecoder().decode(UserContactResponse.self, from: data)
                        let chatList = decoded.data ?? []
                        let message = decoded.message.lowercased()
                        
                        print("🟢 [ApiService] Decoded - errorCode: '\(decoded.errorCode)', message: '\(decoded.message)', data count: \(chatList.count)")
                        
                        // Treat "Data not found" as success with empty data, not an error
                        if decoded.errorCode == "200" || message.contains("data not found") || message.contains("no data") {
                            // Success case: return empty array if no data
                            print("🟢 [ApiService] Treating as SUCCESS - calling completion(true, \"\", \(chatList.count) items)")
                            completion(true, "", chatList)
                        } else {
                            // Actual error case
                            print("🟢 [ApiService] Treating as ERROR - calling completion(false, '\(decoded.message)', \(chatList.count) items)")
                            completion(false, decoded.message, chatList)
                        }
                    } catch {
                        print("🔴 [ApiService] Decoding error: \(error.localizedDescription)")
                        print("🔴 [ApiService] Decoding error details: \(error)")
                        
                        // Try to extract data from raw response if decoding fails
                        if let rawString = String(data: data, encoding: .utf8),
                           let jsonData = rawString.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                            
                            let errorCode = json["error_code"] as? String ?? ""
                            let message = json["message"] as? String ?? ""
                            let lowerMessage = message.lowercased()
                            
                            print("🟢 [ApiService] Extracted from raw response - errorCode: '\(errorCode)', message: '\(message)'")
                            
                            // If error_code is "200" and message is "Success", treat as success even if decoding failed
                            if errorCode == "200" && (lowerMessage == "success" || lowerMessage.contains("success")) {
                                print("🟢 [ApiService] error_code is 200 and message is Success - treating as SUCCESS")
                                
                                // Try to manually parse the data array
                                var parsedChatList: [UserActiveContactModel] = []
                                if let dataArray = json["data"] as? [[String: Any]] {
                                    print("🟢 [ApiService] Found data array with \(dataArray.count) items, attempting manual parsing")
                                    
                                    for item in dataArray {
                                        do {
                                            let itemData = try JSONSerialization.data(withJSONObject: item)
                                            let chatItem = try JSONDecoder().decode(UserActiveContactModel.self, from: itemData)
                                            parsedChatList.append(chatItem)
                                        } catch {
                                            print("🔴 [ApiService] Failed to parse individual item: \(error)")
                                        }
                                    }
                                    
                                    print("🟢 [ApiService] Successfully parsed \(parsedChatList.count) items")
                                    completion(true, "", parsedChatList)
                                } else {
                                    print("🟢 [ApiService] No data array found or empty - treating as SUCCESS with empty array")
                                    completion(true, "", [])
                                }
                            } else if lowerMessage.contains("data not found") || lowerMessage.contains("no data") {
                                print("🟢 [ApiService] Message contains 'data not found' - treating as SUCCESS")
                                completion(true, "", [])
                            } else {
                                print("🟢 [ApiService] Treating as ERROR - errorCode: '\(errorCode)', message: '\(message)'")
                                completion(false, message.isEmpty ? "Decoding failed: \(error.localizedDescription)" : message, nil)
                            }
                        } else {
                            print("🔴 [ApiService] Could not extract data from raw response")
                            completion(false, "Decoding failed: \(error.localizedDescription)", nil)
                        }
                    }

                case .failure(let error):
                    print("🔴 [ApiService] Request error: \(error.localizedDescription)")
                    completion(false, error.localizedDescription, nil)
                }
            }
    }
    
    // Delete individual user chat
    static func delete_individual_user_chatting(uid: String, friendId: String, completion: @escaping (Bool, String) -> Void) {
        let url = Constant.baseURL + "delete_individual_user_chatting"
        let parameters: [String: Any] = ["uid": uid, "friend_id": friendId]
        
        print("🔴 [ApiService] delete_individual_user_chatting - URL: \(url)")
        print("🔴 [ApiService] delete_individual_user_chatting - Parameters: \(parameters)")
        
        AF.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default)
            .validate()
            .responseJSON { response in
                print("🔴 [ApiService] Response received - Status: \(response.response?.statusCode ?? 0)")
                
                switch response.result {
                case .success(let value):
                    if let json = value as? [String: Any] {
                        print("🔴 [ApiService] Response JSON: \(json)")
                        
                        if let errorCodeString = json["error_code"] as? String,
                           let errorCode = Int(errorCodeString),
                           errorCode == 200 {
                            let message = json["message"] as? String ?? "Chat deleted successfully"
                            print("🔴 [ApiService] SUCCESS - calling completion(true, '\(message)')")
                            completion(true, message)
                        } else {
                            let message = json["message"] as? String ?? "Failed to delete chat"
                            print("🔴 [ApiService] ERROR - calling completion(false, '\(message)')")
                            completion(false, message)
                        }
                    } else {
                        print("🔴 [ApiService] Invalid response format")
                        completion(false, "Invalid response format")
                    }
                    
                case .failure(let error):
                    print("🔴 [ApiService] Request failed - error: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                }
            }
    }
    
    // Delete voice call log
    static func delete_voice_call_log(uid: String, friendId: String, callType: String, completion: @escaping (Bool, String) -> Void) {
        let url = Constant.baseURL + "delete_voice_call_log"
        let parameters: [String: Any] = ["uid": uid, "f_id": friendId, "call_type": callType]
        
        print("🟢 [ApiService] delete_voice_call_log - URL: \(url)")
        print("🟢 [ApiService] delete_voice_call_log - Parameters: \(parameters)")
        
        AF.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default)
            .validate()
            .responseJSON { response in
                print("🟢 [ApiService] Response received - Status: \(response.response?.statusCode ?? 0)")
                
                switch response.result {
                case .success(let value):
                    if let json = value as? [String: Any] {
                        print("🟢 [ApiService] Response JSON: \(json)")
                        
                        if let errorCodeString = json["error_code"] as? String,
                           let errorCode = Int(errorCodeString),
                           errorCode == 200 {
                            let message = json["message"] as? String ?? "Call log deleted successfully"
                            print("🟢 [ApiService] SUCCESS - calling completion(true, '\(message)')")
                            completion(true, message)
                        } else {
                            let message = json["message"] as? String ?? "Failed to delete call log"
                            print("🟢 [ApiService] ERROR - calling completion(false, '\(message)')")
                            completion(false, message)
                        }
                    } else {
                        print("🟢 [ApiService] Invalid response format")
                        completion(false, "Invalid response format")
                    }
                    
                case .failure(let error):
                    print("🟢 [ApiService] Request failed - error: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                }
            }
    }
    
    // Clear voice calling list - deletes all voice call logs
    static func clear_voice_calling_list(uid: String, callType: String, completion: @escaping (Bool, String) -> Void) {
        let url = Constant.baseURL + "clear_voice_calling_list"
        let parameters: [String: Any] = ["uid": uid, "call_type": callType]
        
        print("🟣 [ApiService] clear_voice_calling_list - URL: \(url)")
        print("🟣 [ApiService] clear_voice_calling_list - Parameters: \(parameters)")
        
        AF.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default)
            .validate()
            .responseJSON { response in
                print("🟣 [ApiService] Response received - Status: \(response.response?.statusCode ?? 0)")
                
                switch response.result {
                case .success(let value):
                    if let json = value as? [String: Any] {
                        print("🟣 [ApiService] Response JSON: \(json)")
                        
                        if let errorCode = json["error_code"] as? Int,
                           errorCode == 200 {
                            let message = json["message"] as? String ?? "All call logs cleared successfully"
                            print("🟣 [ApiService] SUCCESS - calling completion(true, '\(message)')")
                            completion(true, message)
                        } else {
                            let message = json["message"] as? String ?? "Failed to clear call logs"
                            print("🟣 [ApiService] ERROR - calling completion(false, '\(message)')")
                            completion(false, message)
                        }
                    } else {
                        print("🟣 [ApiService] Invalid response format")
                        completion(false, "Invalid response format")
                    }
                    
                case .failure(let error):
                    print("🟣 [ApiService] Request failed - error: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                }
            }
    }
    
    // Clear video calling list - deletes all video call logs
    static func clear_video_calling_list(uid: String, callType: String, completion: @escaping (Bool, String) -> Void) {
        let url = Constant.baseURL + "clear_video_calling_list"
        let parameters: [String: Any] = ["uid": uid, "call_type": callType]
        
        print("🔵 [ApiService] clear_video_calling_list - URL: \(url)")
        print("🔵 [ApiService] clear_video_calling_list - Parameters: \(parameters)")
        
        AF.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default)
            .validate()
            .responseJSON { response in
                print("🔵 [ApiService] Response received - Status: \(response.response?.statusCode ?? 0)")
                
                switch response.result {
                case .success(let value):
                    if let json = value as? [String: Any] {
                        print("🔵 [ApiService] Response JSON: \(json)")
                        
                        if let errorCode = json["error_code"] as? Int,
                           errorCode == 200 {
                            let message = json["message"] as? String ?? "All video call logs cleared successfully"
                            print("🔵 [ApiService] SUCCESS - calling completion(true, '\(message)')")
                            completion(true, message)
                        } else {
                            let message = json["message"] as? String ?? "Failed to clear video call logs"
                            print("🔵 [ApiService] ERROR - calling completion(false, '\(message)')")
                            completion(false, message)
                        }
                    } else {
                        print("🔵 [ApiService] Invalid response format")
                        completion(false, "Invalid response format")
                    }
                    
                case .failure(let error):
                    print("🔵 [ApiService] Request failed - error: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                }
            }
    }
    
    // Delete video call log
    static func delete_video_call_log(uid: String, friendId: String, callType: String, completion: @escaping (Bool, String) -> Void) {
        let url = Constant.baseURL + "delete_video_call_log"
        let parameters: [String: Any] = ["uid": uid, "f_id": friendId, "call_type": callType]
        
        print("🔵 [ApiService] delete_video_call_log - URL: \(url)")
        print("🔵 [ApiService] delete_video_call_log - Parameters: \(parameters)")
        
        AF.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default)
            .validate()
            .responseJSON { response in
                print("🔵 [ApiService] Response received - Status: \(response.response?.statusCode ?? 0)")
                
                switch response.result {
                case .success(let value):
                    if let json = value as? [String: Any] {
                        print("🔵 [ApiService] Response JSON: \(json)")
                        
                        if let errorCodeString = json["error_code"] as? String,
                           let errorCode = Int(errorCodeString),
                           errorCode == 200 {
                            let message = json["message"] as? String ?? "Video call log deleted successfully"
                            print("🔵 [ApiService] SUCCESS - calling completion(true, '\(message)')")
                            completion(true, message)
                        } else {
                            let message = json["message"] as? String ?? "Failed to delete video call log"
                            print("🔵 [ApiService] ERROR - calling completion(false, '\(message)')")
                            completion(false, message)
                        }
                    } else {
                        print("🔵 [ApiService] Invalid response format")
                        completion(false, "Invalid response format")
                    }
                    
                case .failure(let error):
                    print("🔵 [ApiService] Request failed - error: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                }
            }
    }
    
    // Delete group
    static func delete_groupp(groupId: String, completion: @escaping (Bool, String) -> Void) {
        let url = Constant.baseURL + "delete_groupp"
        let parameters: [String: Any] = ["group_id": groupId]
        
        print("👥 [ApiService] delete_groupp - URL: \(url)")
        print("👥 [ApiService] delete_groupp - Parameters: \(parameters)")
        
        AF.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default)
            .validate()
            .responseJSON { response in
                print("👥 [ApiService] Response received - Status: \(response.response?.statusCode ?? 0)")
                
                switch response.result {
                case .success(let value):
                    if let json = value as? [String: Any] {
                        print("👥 [ApiService] Response JSON: \(json)")
                        
                        if let errorCodeString = json["error_code"] as? String,
                           let errorCode = Int(errorCodeString),
                           errorCode == 200 {
                            let message = json["message"] as? String ?? "Group deleted successfully"
                            print("👥 [ApiService] SUCCESS - calling completion(true, '\(message)')")
                            completion(true, message)
                        } else {
                            let message = json["message"] as? String ?? "Failed to delete group"
                            print("👥 [ApiService] ERROR - calling completion(false, '\(message)')")
                            completion(false, message)
                        }
                    } else {
                        print("👥 [ApiService] Invalid response format")
                        completion(false, "Invalid response format")
                    }
                    
                case .failure(let error):
                    print("👥 [ApiService] Request failed - error: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                }
            }
    }



    // MARK: - Settings API Methods
    static func get_profile(uid: String, completion: @escaping (Bool, GetProfileModel?, String) -> Void) {
        let url = Constant.baseURL+"get_profile"
        let parameters: [String: Any] = ["uid": uid]

        AF.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default)
            .validate()
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do {
                        let decoded = try JSONDecoder().decode(GetProfileResponse.self, from: data)
                        if decoded.error_code == "200", let profile = decoded.data.first {
                            completion(true, profile, decoded.message)
                        } else {
                            completion(false, nil, decoded.message)
                        }
                    } catch {
                        print("Decoding error: \(error.localizedDescription)")
                        completion(false, nil, "Decoding failed")
                    }

                case .failure(let error):
                    print("Request error: \(error.localizedDescription)")
                    completion(false, nil, error.localizedDescription)
                }
            }
    }
    
    static func update_profile(data: [String: Any], completion: @escaping (Bool, String) -> Void) {
        let url = Constant.baseURL+"update_profile"
        
        AF.request(url, method: .post, parameters: data, encoding: URLEncoding.default)
            .validate()
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                            let errorCode = json["error_code"] as? String ?? ""
                            let message = json["message"] as? String ?? "Unknown error"
                            
                            if errorCode == "200" {
                                completion(true, message)
                            } else {
                                completion(false, message)
                            }
                        } else {
                            completion(false, "Invalid response format")
                        }
                    } catch {
                        print("JSON parsing error: \(error.localizedDescription)")
                        completion(false, "Response parsing failed")
                    }

                case .failure(let error):
                    print("Request error: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
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

    static func get_group_list(uid: String, completion: @escaping (Bool, String, [GroupListItem]) -> Void) {
        let url = Constant.baseURL + "get_group_list"
        let parameters: [String: Any] = ["uid": uid]
        
        AF.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default)
            .validate()
            .responseData { response in
                switch response.result {
                case .success(let data):
                    if let raw = String(data: data, encoding: .utf8) {
                        print("[get_group_list] raw response -> \(raw)")
                    }
                    do {
                        let decoded = try JSONDecoder().decode(GroupListResponse.self, from: data)
                        if decoded.error_code == "200" {
                            completion(true, decoded.message, decoded.data ?? [])
                        } else {
                            completion(false, decoded.message, decoded.data ?? [])
                        }
                    } catch {
                        print("Decoding error: \(error.localizedDescription)")
                        completion(false, "Decoding failed", [])
                    }
                    
                case .failure(let error):
                    print("Request error: \(error.localizedDescription)")
                    completion(false, error.localizedDescription, [])
                }
            }
    }
    
    static func create_group_for_chatting(uid: String, groupName: String, invitedFriendList: String, groupIcon: URL?, completion: @escaping (Bool, String) -> Void) {
        let url = Constant.baseURL + "create_group_for_chatting"
        
        AF.upload(
            multipartFormData: { multipartFormData in
                multipartFormData.append(Data(uid.utf8), withName: "uid")
                multipartFormData.append(Data(groupName.utf8), withName: "group_name")
                multipartFormData.append(Data(invitedFriendList.utf8), withName: "invited_friend_list")
                
                if let iconURL = groupIcon {
                    multipartFormData.append(iconURL, withName: "group_icon", fileName: "group_icon.jpg", mimeType: "image/jpeg")
                } else {
                    multipartFormData.append(Data("".utf8), withName: "group_icon")
                }
            },
            to: url,
            method: .post
        )
        .validate()
        .responseData { response in
            switch response.result {
            case .success(let data):
                if let raw = String(data: data, encoding: .utf8) {
                    print("[create_group_for_chatting] raw response -> \(raw)")
                }
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorCode = json["error_code"] as? String {
                        let message = json["message"] as? String ?? ""
                        if errorCode == "200" {
                            completion(true, message)
                        } else {
                            completion(false, message)
                        }
                    } else {
                        completion(false, "Invalid response format")
                    }
                } catch {
                    print("Decoding error: \(error.localizedDescription)")
                    completion(false, "Decoding failed")
                }
                
            case .failure(let error):
                print("Request error: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
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


    static func get_user_profile_images_EditProfile(uid: String, completion: @escaping (Bool, String, [GetUserProfileImagesModel]?) -> Void) {
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




    static func profile_update(uid: String, full_name: String, caption: String, photo: Data?, completion: @escaping (Bool, String) -> Void) {
        let url = Constant.baseURL + "profile_update"

        AF.upload(multipartFormData: { formData in
            formData.append(Data(uid.utf8), withName: "uid")
            formData.append(Data(full_name.utf8), withName: "full_name")
            formData.append(Data(caption.utf8), withName: "caption")

            // Attach image if provided
            if let imageData = photo {
                formData.append(imageData, withName: "photo", fileName: "profile.jpg", mimeType: "image/jpeg")
            }

        }, to: url)
        .validate()
        .responseData { response in
            switch response.result {
            case .success(let data):
                do {
                    let decoded = try JSONDecoder().decode(GlobalResponse.self, from: data)
                    completion(decoded.error_code == "200", decoded.message)
                } catch {
                    print("Decoding error:", error)
                    completion(false, "Decoding failed")
                }
            case .failure(let error):
                print("Request error:", error)
                completion(false, error.localizedDescription)
            }
        }
    }


    static func get_profile_EditProfile(uid: String, completion: @escaping (Bool, String, [GetProfileModel]?) -> Void) {
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



    static func upload_user_profile_images(uid: String, photo: Data?, completion: @escaping (Bool, String) -> Void) {
        let url = Constant.baseURL + "upload_user_profile_images"

        AF.upload(multipartFormData: { formData in
            formData.append(Data(uid.utf8), withName: "uid")
            // Attach image if provided
            if let imageData = photo {
                formData.append(imageData, withName: "photo", fileName: "profile.jpg", mimeType: "image/jpeg")
            }

        }, to: url)
        .validate()
        .responseData { response in
            switch response.result {
            case .success(let data):
                do {
                    let decoded = try JSONDecoder().decode(GlobalResponse.self, from: data)
                    completion(decoded.error_code == "200", decoded.message)
                } catch {
                    print("Decoding error:", error)
                    completion(false, "Decoding failed")
                }
            case .failure(let error):
                print("Request error:", error)
                completion(false, error.localizedDescription)
            }
        }
    }



    static func delete_user_profile_image(uid: String, completion: @escaping (Bool, String) -> Void) {
        let url = Constant.baseURL+"delete_user_profile_image"
        let parameters: [String: Any] = ["uid": uid]

        AF.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default)
            .validate()
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do {
                        let decoded = try JSONDecoder().decode(
                            GlobalResponse.self,
                            from: data
                        )
                        if decoded.error_code == "200" {
                            completion(true, decoded.message)
                        } else {
                            completion(false, decoded.message)
                        }
                    } catch {
                        print("Decoding error: \(error.localizedDescription)")
                        completion(false, "Decoding failed")
                    }

                case .failure(let error):
                    print("Request error: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                }
            }
    }


    static func delete_user_single_status_image(uid: String,id: String ,completion: @escaping (Bool, String) -> Void) {
        let url = Constant.baseURL+"delete_user_single_status_image"
        let parameters: [String: Any] = ["uid": uid,"id": id]

        AF.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default)
            .validate()
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do {
                        let decoded = try JSONDecoder().decode(
                            GlobalResponse.self,
                            from: data
                        )
                        if decoded.error_code == "200" {
                            completion(true, decoded.message)
                        } else {
                            completion(false, decoded.message)
                        }
                    } catch {
                        print("Decoding error: \(error.localizedDescription)")
                        completion(false, "Decoding failed")
                    }

                case .failure(let error):
                    print("Request error: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                }
            }
    }



    static func get_user_active_chat_list_for_msgLmt(uid: String, completion: @escaping (Bool, String, [UserActiveContactModel]?) -> Void) {
        let url = Constant.baseURL+"get_user_active_chat_list"
        let parameters: [String: Any] = ["uid": uid]

        AF.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default)
            .validate()
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do {
                        let decoded = try JSONDecoder().decode(UserContactResponse.self, from: data)
                        let chatList = decoded.data ?? []
                        let message = decoded.message.lowercased()
                        
                        // Treat "Data not found" as success with empty data, not an error
                        if decoded.errorCode == "200" || message.contains("data not found") || message.contains("no data") {
                            // Success case: return empty array if no data
                            completion(true, "", chatList)
                        } else {
                            // Actual error case
                            completion(false, decoded.message, chatList)
                        }
                    } catch {
                        print("Decoding error: \(error.localizedDescription)")
                        // Try to extract message from raw response if decoding fails
                        if let rawString = String(data: data, encoding: .utf8),
                           let jsonData = rawString.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                           let message = json["message"] as? String {
                            let lowerMessage = message.lowercased()
                            // If message is "Data not found", treat as success with empty data
                            if lowerMessage.contains("data not found") || lowerMessage.contains("no data") {
                                completion(true, "", [])
                            } else {
                                completion(false, message, nil)
                            }
                        } else {
                            completion(false, "Decoding failed: \(error.localizedDescription)", nil)
                        }
                    }

                case .failure(let error):
                    print("Request error: \(error.localizedDescription)")
                    completion(false, error.localizedDescription, nil)
                }
            }
    }


    static func get_message_limit_for_all_users(uid: String, completion: @escaping (Bool, String, [GetMessageLimitForAllUsersModel]?) -> Void) {
        let url = Constant.baseURL+"get_message_limit_for_all_users"
        let parameters: [String: Any] = ["uid": uid]

        AF.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default)
            .validate()
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do {
                        let decoded = try JSONDecoder().decode(GetMessageLimitForAllUsersResponse.self, from: data)
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
    
    static func set_message_limit_for_all_users(uid: String, msg_limit: String, completion: @escaping (Bool, String) -> Void) {
        let url = Constant.baseURL+"set_message_limit_for_all_users"
        let parameters: [String: Any] = ["uid": uid, "msg_limit": msg_limit]

        AF.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default)
            .validate()
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let errorCode = json["error_code"] as? String {
                            let message = json["message"] as? String ?? ""
                            if errorCode == "200" {
                                // Save to UserDefaults
                                UserDefaults.standard.set(msg_limit, forKey: "msg_limitFORALL")
                                completion(true, message)
                            } else {
                                completion(false, message)
                            }
                        } else {
                            completion(false, "Invalid response format")
                        }
                    } catch {
                        print("Decoding error: \(error.localizedDescription)")
                        completion(false, "Decoding failed")
                    }

                case .failure(let error):
                    print("Request error: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                }
            }
    }
    
    static func set_message_limit_for_user_chat(uid: String, friend_id: String, msg_limit: String, completion: @escaping (Bool, String) -> Void) {
        let url = Constant.baseURL+"set_message_limit_for_user_chat"
        let parameters: [String: Any] = ["uid": uid, "friend_id": friend_id, "msg_limit": msg_limit]

        AF.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default)
            .validate()
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let errorCode = json["error_code"] as? String {
                            let message = json["message"] as? String ?? ""
                            if errorCode == "200" {
                                completion(true, message)
                            } else {
                                completion(false, message)
                            }
                        } else {
                            completion(false, "Invalid response format")
                        }
                    } catch {
                        print("Decoding error: \(error.localizedDescription)")
                        completion(false, "Decoding failed")
                    }

                case .failure(let error):
                    print("Request error: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                }
            }
    }





    static func get_voice_call_log(uid: String, completion: @escaping (Bool, String, [CallLogSection]?) -> Void) {
        let url = Constant.baseURL + "get_voice_call_log"
        let parameters: [String: Any] = ["uid": uid]
        
        print("📞 [ApiService] get_voice_call_log - URL: \(url), uid: \(uid)")
        
        AF.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default)
            .validate(statusCode: 200..<500)
            .responseData { response in
                print("📞 [ApiService] Call log response status: \(response.response?.statusCode ?? 0)")
                
                switch response.result {
                case .success(let data):
                    if let rawString = String(data: data, encoding: .utf8) {
                        print("📞 [ApiService] Call log raw response: \(rawString)")
                    }
                    
                    do {
                        let decoded = try JSONDecoder().decode(CallLogResponse.self, from: data)
                        let sections = decoded.data
                        let message = decoded.message
                        let lowerMessage = message.lowercased()
                        
                        if sections.count > 0 {
                            completion(true, message, sections)
                        } else if decoded.errorCode == "200" || lowerMessage.contains("success") || lowerMessage.contains("no data") {
                            completion(true, message, [])
                        } else {
                            completion(false, message, nil)
                        }
                    } catch {
                        print("🔴 [ApiService] Call log decoding error: \(error.localizedDescription)")
                        
                        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                            completion(false, "Decoding failed: \(error.localizedDescription)", nil)
                            return
                        }
                        
                        var errorCode = ""
                        if let codeString = jsonObject["error_code"] as? String {
                            errorCode = codeString
                        } else if let codeInt = jsonObject["error_code"] as? Int {
                            errorCode = String(codeInt)
                        }
                        
                        let message = (jsonObject["message"] as? String) ?? ""
                        let lowerMessage = message.lowercased()
                        
                        var parsedSections: [CallLogSection] = []
                        if let dataArray = jsonObject["data"] as? [[String: Any]] {
                            for item in dataArray {
                                do {
                                    let itemData = try JSONSerialization.data(withJSONObject: item)
                                    let section = try JSONDecoder().decode(CallLogSection.self, from: itemData)
                                    parsedSections.append(section)
                                } catch {
                                    print("🔴 [ApiService] Failed to parse call log section: \(error.localizedDescription)")
                                }
                            }
                        }
                        
                        if parsedSections.count > 0 {
                            completion(true, message, parsedSections)
                        } else if errorCode == "200" || lowerMessage.contains("success") || lowerMessage.contains("no data") {
                            completion(true, message, [])
                        } else {
                            completion(false, message.isEmpty ? "Unknown error" : message, nil)
                        }
                    }
                    
                case .failure(let error):
                    print("🔴 [ApiService] Call log request error: \(error.localizedDescription)")
                    completion(false, error.localizedDescription, nil)
                }
            }
    }



    static func get_video_call_log(uid: String, completion: @escaping (Bool, String, [CallLogSection]?) -> Void) {
        let url = Constant.baseURL + "get_call_log_1"
        let parameters: [String: Any] = ["uid": uid]
        
        print("📹 [ApiService] get_call_log_1 (video) - URL: \(url), uid: \(uid)")
        
        AF.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default)
            .validate(statusCode: 200..<500)
            .responseData { response in
                print("📹 [ApiService] Video call log response status: \(response.response?.statusCode ?? 0)")
                
                switch response.result {
                case .success(let data):
                    if let rawString = String(data: data, encoding: .utf8) {
                        print("📹 [ApiService] Video call log raw response: \(rawString)")
                    }
                    
                    do {
                        let decoded = try JSONDecoder().decode(CallLogResponse.self, from: data)
                        let sections = decoded.data
                        let message = decoded.message
                        let lowerMessage = message.lowercased()
                        
                        if sections.count > 0 {
                            completion(true, message, sections)
                        } else if decoded.errorCode == "200" || lowerMessage.contains("success") || lowerMessage.contains("no data") {
                            completion(true, message, [])
                        } else {
                            completion(false, message, nil)
                        }
                    } catch {
                        print("🔴 [ApiService] Video call log decoding error: \(error.localizedDescription)")
                        
                        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                            completion(false, "Decoding failed: \(error.localizedDescription)", nil)
                            return
                        }
                        
                        var errorCode = ""
                        if let codeString = jsonObject["error_code"] as? String {
                            errorCode = codeString
                        } else if let codeInt = jsonObject["error_code"] as? Int {
                            errorCode = String(codeInt)
                        }
                        
                        let message = (jsonObject["message"] as? String) ?? ""
                        let lowerMessage = message.lowercased()
                        
                        var parsedSections: [CallLogSection] = []
                        if let dataArray = jsonObject["data"] as? [[String: Any]] {
                            for item in dataArray {
                                do {
                                    let itemData = try JSONSerialization.data(withJSONObject: item)
                                    let section = try JSONDecoder().decode(CallLogSection.self, from: itemData)
                                    parsedSections.append(section)
                                } catch {
                                    print("🔴 [ApiService] Failed to parse video call log section: \(error.localizedDescription)")
                                }
                            }
                        }
                        
                        if parsedSections.count > 0 {
                            completion(true, message, parsedSections)
                        } else if errorCode == "200" || lowerMessage.contains("success") || lowerMessage.contains("no data") {
                            completion(true, message, [])
                        } else {
                            completion(false, message.isEmpty ? "Unknown error" : message, nil)
                        }
                    }
                    
                case .failure(let error):
                    print("🔴 [ApiService] Video call log request error: \(error.localizedDescription)")
                    completion(false, error.localizedDescription, nil)
                }
            }
    }
    
    
    static func getUsersAllContact(uid: String, page: Int = 1, completion: @escaping (Bool, String, [InviteContactModel]?) -> Void) {
        let url = Constant.baseURL + "get_users_all_contact"
        let parameters: [String: Any] = [
            "uid": uid,
            "page_no": page
        ]
        
        print("📇 [ApiService] get_users_all_contact - URL: \(url), params: \(parameters)")
        
        AF.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default)
            .validate(statusCode: 200..<500)
            .responseData { response in
                print("📇 [ApiService] get_users_all_contact status: \(response.response?.statusCode ?? 0)")
                
                switch response.result {
                case .success(let data):
                    if let rawString = String(data: data, encoding: .utf8) {
                        print("📇 [ApiService] get_users_all_contact raw: \(rawString)")
                    }
                    
                    do {
                        let decoded = try JSONDecoder().decode(InviteContactResponse.self, from: data)
                        let contacts = decoded.data ?? []
                        let lowerMessage = decoded.message.lowercased()
                        let isSuccess = decoded.errorCode == "200"
                            || lowerMessage.contains("data not found")
                            || lowerMessage.contains("no data")
                            || lowerMessage.contains("success")
                        
                        completion(isSuccess, decoded.message, contacts)
                    } catch {
                        print("🔴 [ApiService] get_users_all_contact decode error: \(error.localizedDescription)")
                        
                        guard
                            let rawString = String(data: data, encoding: .utf8),
                            let jsonData = rawString.data(using: .utf8),
                            let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                        else {
                            completion(false, "Decoding failed: \(error.localizedDescription)", nil)
                            return
                        }
                        
                        let message = json["message"] as? String ?? ""
                        let lowerMessage = message.lowercased()
                        let errorCode: String = {
                            if let codeString = json["error_code"] as? String {
                                return codeString
                            }
                            if let codeInt = json["error_code"] as? Int {
                                return String(codeInt)
                            }
                            return ""
                        }()
                        
                        var parsedContacts: [InviteContactModel] = []
                        if let dataArray = json["data"] as? [[String: Any]] {
                            for item in dataArray {
                                do {
                                    let itemData = try JSONSerialization.data(withJSONObject: item)
                                    let contact = try JSONDecoder().decode(InviteContactModel.self, from: itemData)
                                    parsedContacts.append(contact)
                                } catch {
                                    print("🔴 [ApiService] Failed to parse invite contact row: \(error.localizedDescription)")
                                }
                            }
                        }
                        
                        let isSuccess = errorCode == "200"
                            || lowerMessage.contains("data not found")
                            || lowerMessage.contains("no data")
                            || lowerMessage.contains("success")
                        
                        completion(isSuccess, message, parsedContacts)
                    }
                    
                case .failure(let error):
                    print("🔴 [ApiService] get_users_all_contact request error: \(error.localizedDescription)")
                    completion(false, error.localizedDescription, nil)
                }
            }
    }
    
    
    static func searchInviteContacts(uid: String, keyword: String, completion: @escaping (Bool, String, [InviteContactModel]?) -> Void) {
        let url = Constant.baseURL + "search_from_all_contact"
        let parameters: [String: Any] = [
            "uid": uid,
            "srch_keyword": keyword
        ]
        
        print("🔍 [ApiService] search_from_all_contact - URL: \(url), params: \(parameters)")
        
        AF.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default)
            .validate(statusCode: 200..<500)
            .responseData { response in
                print("🔍 [ApiService] search_from_all_contact status: \(response.response?.statusCode ?? 0)")
                
                switch response.result {
                case .success(let data):
                    if let rawString = String(data: data, encoding: .utf8) {
                        print("🔍 [ApiService] search_from_all_contact raw: \(rawString)")
                    }
                    
                    do {
                        let decoded = try JSONDecoder().decode(InviteContactResponse.self, from: data)
                        let contacts = decoded.data ?? []
                        let lowerMessage = decoded.message.lowercased()
                        let isSuccess = decoded.errorCode == "200"
                            || lowerMessage.contains("data not found")
                            || lowerMessage.contains("no data")
                            || lowerMessage.contains("success")
                        
                        completion(isSuccess, decoded.message, contacts)
                    } catch {
                        print("🔴 [ApiService] search_from_all_contact decode error: \(error.localizedDescription)")
                        
                        guard
                            let rawString = String(data: data, encoding: .utf8),
                            let jsonData = rawString.data(using: .utf8),
                            let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                        else {
                            completion(false, "Decoding failed: \(error.localizedDescription)", nil)
                            return
                        }
                        
                        let message = json["message"] as? String ?? ""
                        let lowerMessage = message.lowercased()
                        let errorCode: String = {
                            if let codeString = json["error_code"] as? String {
                                return codeString
                            }
                            if let codeInt = json["error_code"] as? Int {
                                return String(codeInt)
                            }
                            return ""
                        }()
                        
                        var parsedContacts: [InviteContactModel] = []
                        if let dataArray = json["data"] as? [[String: Any]] {
                            for item in dataArray {
                                do {
                                    let itemData = try JSONSerialization.data(withJSONObject: item)
                                    let contact = try JSONDecoder().decode(InviteContactModel.self, from: itemData)
                                    parsedContacts.append(contact)
                                } catch {
                                    print("🔴 [ApiService] Failed to parse invite contact search row: \(error.localizedDescription)")
                                }
                            }
                        }
                        
                        let isSuccess = errorCode == "200"
                            || lowerMessage.contains("data not found")
                            || lowerMessage.contains("no data")
                            || lowerMessage.contains("success")
                        
                        completion(isSuccess, message, parsedContacts)
                    }
                    
                case .failure(let error):
                    print("🔴 [ApiService] search_from_all_contact request error: \(error.localizedDescription)")
                    completion(false, error.localizedDescription, nil)
                }
            }
    }
    
    
    
    static func get_calling_contact_list(uid: String, completion: @escaping (Bool, String, [CallingContactModel]?) -> Void) {
        let url = Constant.baseURL + "get_calling_contact_list"
        let parameters: [String: Any] = ["uid": uid]
        
        print("📞 [ApiService] get_calling_contact_list - URL: \(url), uid: \(uid)")
        
        AF.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default)
            .validate()
            .responseData { response in
                print("📞 [ApiService] Response received - Status: \(response.response?.statusCode ?? 0)")
                
                switch response.result {
                case .success(let data):
                    print("📞 [ApiService] Response success - Data size: \(data.count) bytes")
                    if let rawString = String(data: data, encoding: .utf8) {
                        print("📞 [ApiService] Raw response: \(rawString)")
                    }
                    
                    do {
                        let decoded = try JSONDecoder().decode(CallingContactResponse.self, from: data)
                        let contactList = decoded.data ?? []
                        let message = decoded.message.lowercased()
                        
                        print("📞 [ApiService] Decoded - success: '\(decoded.success ?? "nil")', errorCode: '\(decoded.errorCode)', message: '\(decoded.message)', data count: \(contactList.count)")
                        print("📞 [ApiService] Contact list details: \(contactList)")
                        
                        // Check if we have data or if error code is 200
                        // Even if error_code is 404 but we have data, return it
                        if contactList.count > 0 {
                            print("📞 [ApiService] Has data (\(contactList.count) items) - calling completion(true, \"\", \(contactList.count) items)")
                            completion(true, "", contactList)
                        } else if decoded.errorCode == "200" {
                            print("📞 [ApiService] errorCode is 200 - calling completion(true, \"\", \(contactList.count) items)")
                            completion(true, "", contactList)
                        } else if message.contains("data not found") || message.contains("no data") || message.contains("no contacts found") {
                            print("📞 [ApiService] No data message - calling completion(true, \"\", 0 items)")
                            completion(true, "", [])
                        } else {
                            print("📞 [ApiService] Other error - calling completion(true, '\(decoded.message)', \(contactList.count) items)")
                            // Still return the data (even if empty) so UI can show empty state
                            completion(true, decoded.message, contactList)
                        }
                    } catch {
                        print("🔴 [ApiService] Decoding error: \(error.localizedDescription)")
                        
                        if let rawString = String(data: data, encoding: .utf8),
                           let jsonData = rawString.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                            
                            // Handle error_code as String or Int
                            var errorCode = ""
                            if let errorCodeStr = json["error_code"] as? String {
                                errorCode = errorCodeStr
                            } else if let errorCodeInt = json["error_code"] as? Int {
                                errorCode = String(errorCodeInt)
                            }
                            
                            let message = json["message"] as? String ?? ""
                            let lowerMessage = message.lowercased()
                            
                            print("📞 [ApiService] Extracted from raw response - errorCode: '\(errorCode)', message: '\(message)'")
                            
                            // Always try to parse data array if it exists
                            var parsedContactList: [CallingContactModel] = []
                            if let dataArray = json["data"] as? [[String: Any]] {
                                print("📞 [ApiService] Found data array with \(dataArray.count) items, attempting manual parsing")
                                
                                for item in dataArray {
                                    do {
                                        let itemData = try JSONSerialization.data(withJSONObject: item)
                                        let contactItem = try JSONDecoder().decode(CallingContactModel.self, from: itemData)
                                        parsedContactList.append(contactItem)
                                    } catch {
                                        print("🔴 [ApiService] Failed to parse individual item: \(error)")
                                        print("🔴 [ApiService] Item data: \(item)")
                                    }
                                }
                                
                                print("📞 [ApiService] Successfully parsed \(parsedContactList.count) items")
                            }
                            
                            // If we have data, always return it as success
                            if parsedContactList.count > 0 {
                                print("📞 [ApiService] Has parsed data (\(parsedContactList.count) items) - returning as success")
                                completion(true, "", parsedContactList)
                            } else if errorCode == "200" || (lowerMessage == "success" || lowerMessage.contains("success")) {
                                print("📞 [ApiService] errorCode is 200 or success message - treating as SUCCESS with empty array")
                                completion(true, "", [])
                            } else if lowerMessage.contains("data not found") || lowerMessage.contains("no data") || lowerMessage.contains("no contacts found") {
                                print("📞 [ApiService] Message contains 'no data' - treating as SUCCESS with empty array")
                                completion(true, "", [])
                            } else {
                                print("📞 [ApiService] Other case - returning empty array as success")
                                completion(true, message, [])
                            }
                        } else {
                            print("🔴 [ApiService] Could not extract data from raw response")
                            completion(false, "Decoding failed: \(error.localizedDescription)", nil)
                        }
                    }
                    
                case .failure(let error):
                    print("🔴 [ApiService] Request error: \(error.localizedDescription)")
                    completion(false, error.localizedDescription, nil)
                }
            }
    }
    
    // MARK: - Change Number API (matching Android Webservice.change_number)
    func changeNumber(uid: String, oldPhoneNumber: String, newPhoneNumber: String, completion: @escaping (Result<ChangeNumberResponse, Error>) -> Void) {
        let endpoint = Constant.baseURL + "change_numberrold"
        
        print("📱 [ApiService] Change Number API Call")
        print("📱 [ApiService] Endpoint: \(endpoint)")
        print("📱 [ApiService] UID: \(uid)")
        print("📱 [ApiService] Old Phone: \(oldPhoneNumber)")
        print("📱 [ApiService] New Phone: \(newPhoneNumber)")
        
        // Use multipart form data (matching Android MultipartBody.FORM)
        AF.upload(
            multipartFormData: { multipartFormData in
                multipartFormData.append(Data(uid.utf8), withName: "uid")
                multipartFormData.append(Data(oldPhoneNumber.utf8), withName: "mobile_no_old")
                multipartFormData.append(Data(newPhoneNumber.utf8), withName: "mobile_no_new")
            },
            to: endpoint,
            method: .post,
            headers: ["Content-Type": "multipart/form-data"]
        )
        .responseData { response in
            let statusCode = response.response?.statusCode ?? 0
            print("📱 [ApiService] Change Number Response Status: \(statusCode)")
            
            switch response.result {
            case .success(let data):
                if let rawResponse = String(data: data, encoding: .utf8) {
                    print("📱 [ApiService] Raw Response: \(rawResponse.prefix(500))") // Log first 500 chars
                    
                    // Check if response is HTML (error page)
                    if rawResponse.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<") {
                        print("🔴 [ApiService] Server returned HTML error page (likely 500 error)")
                        
                        // Try to extract error message from HTML
                        var errorMessage = "Server error occurred. Please try again later."
                        
                        // Try multiple patterns to extract error message
                        if let messageRange = rawResponse.range(of: "<p>Message: ") {
                            let afterMessage = String(rawResponse[messageRange.upperBound...])
                            if let endRange = afterMessage.range(of: "</p>") {
                                errorMessage = String(afterMessage[..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        } else if let messageRange = rawResponse.range(of: "Message: ") {
                            let afterMessage = String(rawResponse[messageRange.upperBound...])
                            if let endRange = afterMessage.range(of: "</p>") {
                                errorMessage = String(afterMessage[..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                            } else if let endRange = afterMessage.range(of: "<") {
                                errorMessage = String(afterMessage[..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        }
                        
                        // If we found a database error, make it more user-friendly
                        if errorMessage.contains("Unknown column") {
                            errorMessage = "Database error: \(errorMessage). Please contact support."
                        }
                        
                        // Return error response with 500 status
                        let errorResponse = ChangeNumberResponse(errorCode: "500", message: errorMessage)
                        completion(.success(errorResponse))
                        return
                    }
                    
                    // Try to find JSON in the response
                    var cleanedData = data
                    if let jsonStart = rawResponse.range(of: "{") {
                        let jsonString = String(rawResponse[jsonStart.lowerBound...])
                        if let jsonData = jsonString.data(using: .utf8) {
                            cleanedData = jsonData
                        }
                    } else {
                        // No JSON found, return error
                        let errorResponse = ChangeNumberResponse(errorCode: String(statusCode), message: "Invalid response from server")
                        completion(.success(errorResponse))
                        return
                    }
                    
                    // Try to decode JSON
                    do {
                        let changeNumberResponse = try JSONDecoder().decode(ChangeNumberResponse.self, from: cleanedData)
                        print("📱 [ApiService] Decoded Response: \(changeNumberResponse)")
                        completion(.success(changeNumberResponse))
                    } catch {
                        print("🔴 [ApiService] Decoding Error: \(error)")
                        // Try to parse raw response manually if JSON decoding fails
                        if let jsonData = rawResponse.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                            var errorCode = ""
                            if let errorCodeString = json["error_code"] as? String {
                                errorCode = errorCodeString
                            } else if let errorCodeInt = json["error_code"] as? Int {
                                errorCode = String(errorCodeInt)
                            }
                            let message = json["message"] as? String ?? "Unknown error"
                            let response = ChangeNumberResponse(errorCode: errorCode, message: message)
                            completion(.success(response))
                        } else {
                            // Return error response instead of throwing
                            let errorResponse = ChangeNumberResponse(errorCode: String(statusCode), message: "Failed to parse server response")
                            completion(.success(errorResponse))
                        }
                    }
                } else {
                    // No valid string data
                    let errorResponse = ChangeNumberResponse(errorCode: String(statusCode), message: "Invalid response data")
                    completion(.success(errorResponse))
                }
                
            case .failure(let error):
                print("🔴 [ApiService] Network Error: \(error)")
                // Convert network error to ChangeNumberResponse
                let errorResponse = ChangeNumberResponse(errorCode: "NETWORK_ERROR", message: error.localizedDescription)
                completion(.success(errorResponse))
            }
        }
    }
    
    // MARK: - Delete Account APIs (matching Android Webservice)
    
    /// Send OTP for delete account (uses send_otp_common endpoint)
    func sendOtpForDelete(mobileNo: String, completion: @escaping (Result<SendOtpResponse, Error>) -> Void) {
        let endpoint = Constant.baseURL + "send_otp_common"
        
        print("📱 [ApiService] Send OTP for Delete - Mobile: \(mobileNo)")
        
        AF.request(
            endpoint,
            method: .post,
            parameters: ["mobile_no": mobileNo],
            encoding: URLEncoding.default
        )
        .responseData { response in
            let statusCode = response.response?.statusCode ?? 0
            print("📱 [ApiService] Send OTP for Delete Response Status: \(statusCode)")
            
            switch response.result {
            case .success(let data):
                if let rawResponse = String(data: data, encoding: .utf8) {
                    print("📱 [ApiService] Raw Response: \(rawResponse.prefix(500))")
                    
                    // Check if response is HTML (error page)
                    if rawResponse.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<") {
                        let errorResponse = SendOtpResponse(errorCode: "500", message: "Server error occurred")
                        completion(.success(errorResponse))
                        return
                    }
                    
                    do {
                        let sendOtpResponse = try JSONDecoder().decode(SendOtpResponse.self, from: data)
                        print("📱 [ApiService] Decoded SendOtpResponse: \(sendOtpResponse)")
                        completion(.success(sendOtpResponse))
                    } catch {
                        print("🔴 [ApiService] Decoding Error: \(error)")
                        // Try manual parsing
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            var errorCode = ""
                            if let errorCodeString = json["error_code"] as? String {
                                errorCode = errorCodeString
                            } else if let errorCodeInt = json["error_code"] as? Int {
                                errorCode = String(errorCodeInt)
                            }
                            let message = json["message"] as? String ?? "Unknown error"
                            let response = SendOtpResponse(errorCode: errorCode, message: message)
                            completion(.success(response))
                        } else {
                            let errorResponse = SendOtpResponse(errorCode: String(statusCode), message: "Failed to parse response")
                            completion(.success(errorResponse))
                        }
                    }
                } else {
                    let errorResponse = SendOtpResponse(errorCode: String(statusCode), message: "Invalid response data")
                    completion(.success(errorResponse))
                }
                
            case .failure(let error):
                print("🔴 [ApiService] Network Error: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    /// Verify OTP for delete account
    func verifyOtpForDelete(uid: String, otp: String, completion: @escaping (Result<ChangeNumberResponse, Error>) -> Void) {
        let endpoint = Constant.baseURL + "verify_otp_common"
        
        print("📱 [ApiService] Verify OTP for Delete - UID: \(uid)")
        
        AF.upload(
            multipartFormData: { multipartFormData in
                multipartFormData.append(Data(uid.utf8), withName: "uid")
                multipartFormData.append(Data(otp.utf8), withName: "otp")
            },
            to: endpoint,
            method: .post,
            headers: ["Content-Type": "multipart/form-data"]
        )
        .responseData { response in
            let statusCode = response.response?.statusCode ?? 0
            print("📱 [ApiService] Verify OTP for Delete Response Status: \(statusCode)")
            
            switch response.result {
            case .success(let data):
                if let rawResponse = String(data: data, encoding: .utf8) {
                    print("📱 [ApiService] Raw Response: \(rawResponse.prefix(500))")
                    
                    // Check if response is HTML (error page)
                    if rawResponse.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<") {
                        let errorResponse = ChangeNumberResponse(errorCode: "500", message: "Server error occurred")
                        completion(.success(errorResponse))
                        return
                    }
                    
                    var cleanedData = data
                    if let jsonStart = rawResponse.range(of: "{") {
                        let jsonString = String(rawResponse[jsonStart.lowerBound...])
                        if let jsonData = jsonString.data(using: .utf8) {
                            cleanedData = jsonData
                        }
                    }
                    
                    do {
                        let verifyResponse = try JSONDecoder().decode(ChangeNumberResponse.self, from: cleanedData)
                        print("📱 [ApiService] Decoded VerifyResponse: \(verifyResponse)")
                        completion(.success(verifyResponse))
                    } catch {
                        print("🔴 [ApiService] Decoding Error: \(error)")
                        if let json = try? JSONSerialization.jsonObject(with: cleanedData) as? [String: Any] {
                            var errorCode = ""
                            if let errorCodeString = json["error_code"] as? String {
                                errorCode = errorCodeString
                            } else if let errorCodeInt = json["error_code"] as? Int {
                                errorCode = String(errorCodeInt)
                            }
                            let message = json["message"] as? String ?? "Unknown error"
                            let response = ChangeNumberResponse(errorCode: errorCode, message: message)
                            completion(.success(response))
                        } else {
                            let errorResponse = ChangeNumberResponse(errorCode: String(statusCode), message: "Failed to parse response")
                            completion(.success(errorResponse))
                        }
                    }
                } else {
                    let errorResponse = ChangeNumberResponse(errorCode: String(statusCode), message: "Invalid response data")
                    completion(.success(errorResponse))
                }
                
            case .failure(let error):
                print("🔴 [ApiService] Network Error: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    /// Delete my account
    func deleteMyAccount(uid: String, completion: @escaping (Result<ChangeNumberResponse, Error>) -> Void) {
        let endpoint = Constant.baseURL + "delete_my_account"
        
        print("📱 [ApiService] Delete Account - UID: \(uid)")
        
        AF.upload(
            multipartFormData: { multipartFormData in
                multipartFormData.append(Data(uid.utf8), withName: "uid")
            },
            to: endpoint,
            method: .post,
            headers: ["Content-Type": "multipart/form-data"]
        )
        .responseData { response in
            let statusCode = response.response?.statusCode ?? 0
            print("📱 [ApiService] Delete Account Response Status: \(statusCode)")
            
            switch response.result {
            case .success(let data):
                if let rawResponse = String(data: data, encoding: .utf8) {
                    print("📱 [ApiService] Raw Response: \(rawResponse.prefix(500))")
                    
                    // Check if response is HTML (error page)
                    if rawResponse.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<") {
                        let errorResponse = ChangeNumberResponse(errorCode: "500", message: "Server error occurred")
                        completion(.success(errorResponse))
                        return
                    }
                    
                    var cleanedData = data
                    if let jsonStart = rawResponse.range(of: "{") {
                        let jsonString = String(rawResponse[jsonStart.lowerBound...])
                        if let jsonData = jsonString.data(using: .utf8) {
                            cleanedData = jsonData
                        }
                    }
                    
                    do {
                        let deleteResponse = try JSONDecoder().decode(ChangeNumberResponse.self, from: cleanedData)
                        print("📱 [ApiService] Decoded DeleteResponse: \(deleteResponse)")
                        completion(.success(deleteResponse))
                    } catch {
                        print("🔴 [ApiService] Decoding Error: \(error)")
                        if let json = try? JSONSerialization.jsonObject(with: cleanedData) as? [String: Any] {
                            var errorCode = ""
                            if let errorCodeString = json["error_code"] as? String {
                                errorCode = errorCodeString
                            } else if let errorCodeInt = json["error_code"] as? Int {
                                errorCode = String(errorCodeInt)
                            }
                            let message = json["message"] as? String ?? "Unknown error"
                            let response = ChangeNumberResponse(errorCode: errorCode, message: message)
                            completion(.success(response))
                        } else {
                            let errorResponse = ChangeNumberResponse(errorCode: String(statusCode), message: "Failed to parse response")
                            completion(.success(errorResponse))
                        }
                    }
                } else {
                    let errorResponse = ChangeNumberResponse(errorCode: String(statusCode), message: "Invalid response data")
                    completion(.success(errorResponse))
                }
                
            case .failure(let error):
                print("🔴 [ApiService] Network Error: \(error)")
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Send OTP Response Model
struct SendOtpResponse: Codable {
    let errorCode: String
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case error_code
        case message
    }
    
    init(errorCode: String, message: String?) {
        self.errorCode = errorCode
        self.message = message
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let errorCodeString = try? container.decode(String.self, forKey: .error_code) {
            self.errorCode = errorCodeString
        } else if let errorCodeInt = try? container.decode(Int.self, forKey: .error_code) {
            self.errorCode = String(errorCodeInt)
        } else {
            self.errorCode = ""
        }
        
        self.message = try? container.decode(String.self, forKey: .message)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(errorCode, forKey: .error_code)
        try container.encodeIfPresent(message, forKey: .message)
    }
}

// MARK: - Change Number Response Model
struct ChangeNumberResponse: Codable {
    let errorCode: String
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case error_code
        case message
    }
    
    init(errorCode: String, message: String?) {
        self.errorCode = errorCode
        self.message = message
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let errorCodeString = try? container.decode(String.self, forKey: .error_code) {
            self.errorCode = errorCodeString
        } else if let errorCodeInt = try? container.decode(Int.self, forKey: .error_code) {
            self.errorCode = String(errorCodeInt)
        } else {
            self.errorCode = ""
        }
        
        self.message = try? container.decode(String.self, forKey: .message)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(errorCode, forKey: .error_code)
        try container.encodeIfPresent(message, forKey: .message)
    }
}
