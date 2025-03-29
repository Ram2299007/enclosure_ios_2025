//
//  SendOTPViewModel.swift
//  Enclosure
//
//  Created by Ram Lohar on 18/03/25.
//


import Foundation

class SendOTPViewModel: ObservableObject {
    @Published var isNavigating = false
    @Published var isLoading = false

    @Published var uid = ""
    @Published var c_id = ""
    @Published var mobile_no = ""
    @Published var country_Code = ""

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
                print("❌ Error: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                print("❌ No Data")
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
                print("❌ JSON Parsing Error: \(error.localizedDescription)")
            }
        }.resume()
    }
}

