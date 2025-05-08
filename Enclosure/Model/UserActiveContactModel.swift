//
//  FlagModel.swift
//  Enclosure
//
//  Created by Ram Lohar on 18/03/25.
//


import SwiftUI

struct UserActiveContactModel: Codable {
    let photo: String
    let fullName: String
    let mobileNo: String
    let caption: String
    let uid: String
    let sentTime: String
    let dataType: String
    let message: String
    let fToken: String
    let notification: Int
    let msgLimit: Int
    let deviceType: String        // device_type is a string in the JSON
    let messageId: String        // message_id is a string in the JSON
    let createdAt: String        // created_at is a string in the JSON

    enum CodingKeys: String, CodingKey {
        case photo
        case fullName = "full_name"
        case mobileNo = "mobile_no"
        case caption
        case uid
        case sentTime = "sent_time"
        case dataType
        case message
        case fToken = "f_token"
        case notification
        case msgLimit = "msg_limit"
        case deviceType = "device_type"
        case messageId = "message_id"
        case createdAt = "created_at"
    }
}





