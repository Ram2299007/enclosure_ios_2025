//
//  SendOTPViewModel.swift
//  Enclosure
//
//  Created by Ram Lohar on 18/03/25.
//


import Foundation
import UIKit

enum PhoneIdMatchStatus {
    case match
    case partialMatch
    case failure(String)
}

class SendOTPViewModel: ObservableObject {
    @Published var isNavigating = false
    @Published var isLoading = false

    @Published var uid = ""
    @Published var c_id = ""
    @Published var mobile_no = ""
    @Published var country_Code = ""
    
    func checkPhoneIdMatch(mobileNo: String, completion: @escaping (PhoneIdMatchStatus) -> Void) {
        let phoneId = UIDevice.current.identifierForVendor?.uuidString ?? ""
        guard !phoneId.isEmpty else {
            completion(.failure("Missing phone ID"))
            return
        }
        
        let allowedQuery = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "+"))
        let encodedMobile = mobileNo.addingPercentEncoding(withAllowedCharacters: allowedQuery) ?? mobileNo
        let encodedPhoneId = phoneId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? phoneId
        
        var components = URLComponents(string: Constant.baseURL + "check_phone_id_match")
        components?.percentEncodedQuery = "mobile_no=\(encodedMobile)&phone_id=\(encodedPhoneId)"
        
        guard let url = components?.url else {
            completion(.failure("Invalid URL"))
            return
        }
        
        print("🟠 [SendOTPViewModel] checkPhoneIdMatch request: \(url.absoluteString)")
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    print("🟠 [SendOTPViewModel] checkPhoneIdMatch error: \(error.localizedDescription)")
                    completion(.failure(error.localizedDescription))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    print("🟠 [SendOTPViewModel] checkPhoneIdMatch no data")
                    completion(.failure("No data received"))
                }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("🟠 [SendOTPViewModel] checkPhoneIdMatch response: \(json)")
                    let errorCode: Int? = {
                        if let codeInt = json["error_code"] as? Int {
                            return codeInt
                        }
                        if let codeString = json["error_code"] as? String {
                            return Int(codeString)
                        }
                        return nil
                    }()
                    
                    let message = json["message"] as? String ?? ""
                    
                    DispatchQueue.main.async {
                        switch errorCode {
                        case 200:
                            completion(.match)
                        case 409:
                            completion(.partialMatch)
                        default:
                            completion(.failure(message.isEmpty ? "Unknown error" : message))
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure("Invalid response format"))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error.localizedDescription))
                }
            }
        }.resume()
    }

    func sendOTP(mobileNo: String, cID: String,cCode:String) {
        isLoading = true
        guard let url = URL(string: Constant.baseURL + "send_otp") else {
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let encodedMobileNo = mobileNo.replacingOccurrences(of: "+", with: "%2B")
        let parameters = "mobile_no=\(encodedMobileNo)&c_id=\(cID)"
        request.httpBody = parameters.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
            }

            if let error = error {
                print("🚫 Error: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                print("🚫 No Data")
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let dataArray = json["data"] as? [[String: Any]],
                   let firstObj = dataArray.first,
                   let uid = firstObj["uid"] as? String {

                    DispatchQueue.main.async {
                        self.uid = uid
                        self.c_id = cID
                        self.mobile_no = mobileNo
                        self.country_Code = cCode // (जर वेगवेगळे देश असतील तर योग्य व्हॅल्यू द्या)
                        self.isNavigating = true
                    }
                }
            } catch {
                print("🚫 JSON Parsing Error: \(error.localizedDescription)")
            }
        }.resume()
    }
}

