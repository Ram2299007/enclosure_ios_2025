//
//  CallingContactModel.swift
//  Enclosure
//
//  Created by Ram Lohar on 30/04/25.
//

import Foundation

struct CallingContactModel: Codable {
    let uid: String
    let photo: String
    let fullName: String
    let mobileNo: String
    let caption: String
    let fToken: String
    let voipToken: String  // 🆕 VoIP token for iOS CallKit
    let deviceType: String
    let block: Bool
    let themeColor: String
    
    enum CodingKeys: String, CodingKey {
        case uid
        case photo
        case fullName = "full_name"
        case mobileNo = "mobile_no"
        case caption
        case fToken = "f_token"
        case voipToken = "voip_token"  // 🆕 VoIP token
        case deviceType = "device_type"
        case block
        case themeColor
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // API returns uid as Int or String
        if let uidInt = try? container.decode(Int.self, forKey: .uid) {
            uid = String(uidInt)
        } else {
            uid = try container.decode(String.self, forKey: .uid)
        }
        photo = try container.decode(String.self, forKey: .photo)
        fullName = try container.decode(String.self, forKey: .fullName)
        mobileNo = try container.decode(String.self, forKey: .mobileNo)
        caption = try container.decode(String.self, forKey: .caption)
        fToken = try container.decode(String.self, forKey: .fToken)
        voipToken = (try? container.decode(String.self, forKey: .voipToken)) ?? ""  // 🆕 Optional VoIP token
        deviceType = try container.decode(String.self, forKey: .deviceType)
        
        // Handle block as Bool or String
        if let blockBool = try? container.decode(Bool.self, forKey: .block) {
            block = blockBool
        } else if let blockString = try? container.decode(String.self, forKey: .block) {
            block = blockString.lowercased() == "true" || blockString == "1"
        } else {
            block = false
        }
        
        // Handle themeColor as optional, default to empty string
        themeColor = (try? container.decode(String.self, forKey: .themeColor)) ?? ""
    }
}

struct CallingContactResponse: Codable {
    let success: String?
    let errorCode: String
    let message: String
    let data: [CallingContactModel]?
    
    enum CodingKeys: String, CodingKey {
        case success
        case errorCode = "error_code"
        case message
        case data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle success field (optional)
        success = try? container.decode(String.self, forKey: .success)
        
        // Handle error_code as String or Int
        if let errorCodeString = try? container.decode(String.self, forKey: .errorCode) {
            errorCode = errorCodeString
        } else if let errorCodeInt = try? container.decode(Int.self, forKey: .errorCode) {
            errorCode = String(errorCodeInt)
        } else {
            errorCode = "0"
        }
        
        message = try container.decode(String.self, forKey: .message)
        
        // Handle data - try to decode, if fails or null, return empty array
        if let dataArray = try? container.decode([CallingContactModel].self, forKey: .data) {
            data = dataArray
        } else {
            data = []
        }
    }
}

