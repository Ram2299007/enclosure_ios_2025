//
//  InviteContactModel.swift
//  Enclosure
//
//  Created by ChatGPT on 19/11/25.
//

import Foundation

struct InviteContactModel: Codable, Identifiable, Equatable {
    let cFlag: String
    let uid: String
    let photo: String
    let fullName: String
    let mobileNo: String
    let caption: String
    let fToken: String
    let deviceType: String
    let contactName: String
    let contactNumber: String
    let block: Bool
    let iamBlocked: Bool
    let themeColor: String
    
    var id: String { uniqueKey }
    var uniqueKey: String { isActiveUser ? uid : contactNumber }
    var isActiveUser: Bool { cFlag == "1" }
    
    var displayName: String {
        if isActiveUser {
            return fullName.isEmpty ? mobileNo : fullName
        }
        return contactName.isEmpty ? contactNumber : contactName
    }
    
    var displayNumber: String {
        isActiveUser ? mobileNo : contactNumber
    }
    
    var resolvedThemeColor: String {
        themeColor.isEmpty ? "#00A3E9" : themeColor
    }
    
    var canInvite: Bool { !isActiveUser }
    
    enum CodingKeys: String, CodingKey {
        case cFlag = "c_flag"
        case uid
        case photo
        case fullName = "full_name"
        case mobileNo = "mobile_no"
        case caption
        case fToken = "f_token"
        case deviceType = "device_type"
        case contactName = "contact_name"
        case contactNumber = "contact_number"
        case block
        case iamBlocked = "iamblocked"
        case themeColor
    }
    
    init(
        cFlag: String,
        uid: String,
        photo: String,
        fullName: String,
        mobileNo: String,
        caption: String,
        fToken: String,
        deviceType: String,
        contactName: String,
        contactNumber: String,
        block: Bool,
        iamBlocked: Bool,
        themeColor: String
    ) {
        self.cFlag = cFlag
        self.uid = uid
        self.photo = photo
        self.fullName = fullName
        self.mobileNo = mobileNo
        self.caption = caption
        self.fToken = fToken
        self.deviceType = deviceType
        self.contactName = contactName
        self.contactNumber = contactNumber
        self.block = block
        self.iamBlocked = iamBlocked
        self.themeColor = themeColor
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        cFlag = try container.decodeIfPresent(String.self, forKey: .cFlag) ?? "0"
        uid = try container.decodeIfPresent(String.self, forKey: .uid) ?? ""
        photo = try container.decodeIfPresent(String.self, forKey: .photo) ?? ""
        fullName = try container.decodeIfPresent(String.self, forKey: .fullName) ?? ""
        mobileNo = try container.decodeIfPresent(String.self, forKey: .mobileNo) ?? ""
        caption = try container.decodeIfPresent(String.self, forKey: .caption) ?? ""
        fToken = try container.decodeIfPresent(String.self, forKey: .fToken) ?? ""
        deviceType = try container.decodeIfPresent(String.self, forKey: .deviceType) ?? ""
        contactName = try container.decodeIfPresent(String.self, forKey: .contactName) ?? ""
        contactNumber = try container.decodeIfPresent(String.self, forKey: .contactNumber) ?? ""
        block = InviteContactModel.decodeFlexibleBool(from: container, key: .block)
        iamBlocked = InviteContactModel.decodeFlexibleBool(from: container, key: .iamBlocked)
        themeColor = try container.decodeIfPresent(String.self, forKey: .themeColor) ?? ""
    }
    
    private static func decodeFlexibleBool(from container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Bool {
        if let boolValue = try? container.decode(Bool.self, forKey: key) {
            return boolValue
        }
        if let stringValue = try? container.decode(String.self, forKey: key) {
            return stringValue == "1" || stringValue.lowercased() == "true"
        }
        if let intValue = try? container.decode(Int.self, forKey: key) {
            return intValue == 1
        }
        return false
    }
}

struct InviteContactResponse: Codable {
    let errorCode: String
    let message: String
    let data: [InviteContactModel]?
    
    enum CodingKeys: String, CodingKey {
        case errorCode = "error_code"
        case message
        case data
    }
}


