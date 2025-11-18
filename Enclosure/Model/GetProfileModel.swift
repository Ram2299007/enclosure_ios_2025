//
//  get_profileResponse.swift
//  Enclosure
//
//  Created by Ram Lohar on 08/05/25.
//

import Foundation

struct GetProfileModel: Codable {
    let full_name: String
    let caption: String
    let mobile_no: String
    let photo: String
    let status: String
    let f_token: String
    let device_type: String
    let themeColor: String?

    enum CodingKeys: String, CodingKey {
        case full_name = "full_name"
        case caption = "caption"
        case mobile_no = "mobile_no"
        case photo = "photo"
        case status = "status"
        case f_token = "f_token"
        case device_type = "device_type"
        case themeColor = "themeColor"
    }
}
