//
//  FlagModel.swift
//  Enclosure
//
//  Created by Ram Lohar on 18/03/25.
//


import SwiftUI

struct UserContactResponse: Codable {
    let success: String?
    let errorCode: String
    let message: String
    let data: [UserActiveContactModel]?
    /// Current user's device_type from get_user_active_chat_list (same format as list: "1" or "2"). Use this for sender in send_notification_api instead of static "2".
    let myDeviceType: String?

    enum CodingKeys: String, CodingKey {
        case success
        case errorCode = "error_code"
        case message
        case data
        case myDeviceType = "my_device_type"
    }

    init(success: String?, errorCode: String, message: String, data: [UserActiveContactModel]?, myDeviceType: String? = nil) {
        self.success = success
        self.errorCode = errorCode
        self.message = message
        self.data = data
        self.myDeviceType = myDeviceType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decodeIfPresent(String.self, forKey: .success)
        errorCode = try container.decode(String.self, forKey: .errorCode)
        message = try container.decode(String.self, forKey: .message)
        data = try container.decodeIfPresent([UserActiveContactModel].self, forKey: .data)
        myDeviceType = try container.decodeIfPresent(String.self, forKey: .myDeviceType)
    }
}


