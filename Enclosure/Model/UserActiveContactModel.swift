//
//  FlagModel.swift
//  Enclosure
//
//  Created by Ram Lohar on 18/03/25.
//


import SwiftUI

struct UserActiveContactModel: Codable, Identifiable, Hashable {
    var id: String { uid }
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
    let messageId: String        // message_id can be Int or String in the JSON
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
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        photo = try container.decode(String.self, forKey: .photo)
        fullName = try container.decode(String.self, forKey: .fullName)
        mobileNo = try container.decode(String.self, forKey: .mobileNo)
        caption = try container.decode(String.self, forKey: .caption)
        uid = try container.decode(String.self, forKey: .uid)
        sentTime = try container.decode(String.self, forKey: .sentTime)
        dataType = try container.decode(String.self, forKey: .dataType)
        message = try container.decode(String.self, forKey: .message)
        fToken = try container.decode(String.self, forKey: .fToken)
        notification = try container.decode(Int.self, forKey: .notification)
        msgLimit = try container.decode(Int.self, forKey: .msgLimit)
        deviceType = try container.decode(String.self, forKey: .deviceType)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        
        // Handle message_id as either Int or String
        if let messageIdInt = try? container.decode(Int.self, forKey: .messageId) {
            messageId = String(messageIdInt)
        } else {
            messageId = try container.decode(String.self, forKey: .messageId)
        }
    }

    init(
        photo: String,
        fullName: String,
        mobileNo: String,
        caption: String,
        uid: String,
        sentTime: String,
        dataType: String,
        message: String,
        fToken: String,
        notification: Int,
        msgLimit: Int,
        deviceType: String,
        messageId: String,
        createdAt: String
    ) {
        self.photo = photo
        self.fullName = fullName
        self.mobileNo = mobileNo
        self.caption = caption
        self.uid = uid
        self.sentTime = sentTime
        self.dataType = dataType
        self.message = message
        self.fToken = fToken
        self.notification = notification
        self.msgLimit = msgLimit
        self.deviceType = deviceType
        self.messageId = messageId
        self.createdAt = createdAt
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(uid)
    }
    
    static func == (lhs: UserActiveContactModel, rhs: UserActiveContactModel) -> Bool {
        lhs.uid == rhs.uid
    }
}





