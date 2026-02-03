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
    let block: Bool              // block status (current user blocked the other user)
    let iamblocked: Bool         // iamblocked status (other user blocked current user)

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
        case block
        case iamblocked
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
        notification = (try? container.decode(Int.self, forKey: .notification)) ?? 0
        msgLimit = (try? container.decode(Int.self, forKey: .msgLimit)) ?? 0
        deviceType = try container.decode(String.self, forKey: .deviceType)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        
        // Handle message_id as either Int or String
        if let messageIdInt = try? container.decode(Int.self, forKey: .messageId) {
            messageId = String(messageIdInt)
        } else {
            messageId = try container.decode(String.self, forKey: .messageId)
        }
        
        // Handle block as Bool or String (default to false if missing)
        if let blockBool = try? container.decode(Bool.self, forKey: .block) {
            block = blockBool
        } else if let blockString = try? container.decode(String.self, forKey: .block) {
            block = blockString.lowercased() == "true" || blockString == "1"
        } else {
            block = false
        }
        
        // Handle iamblocked as Bool or String (default to false if missing)
        if let iamblockedBool = try? container.decode(Bool.self, forKey: .iamblocked) {
            iamblocked = iamblockedBool
        } else if let iamblockedString = try? container.decode(String.self, forKey: .iamblocked) {
            iamblocked = iamblockedString.lowercased() == "true" || iamblockedString == "1"
        } else {
            iamblocked = false
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
        createdAt: String,
        block: Bool = false,
        iamblocked: Bool = false
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
        self.block = block
        self.iamblocked = iamblocked
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(uid)
    }
    
    static func == (lhs: UserActiveContactModel, rhs: UserActiveContactModel) -> Bool {
        lhs.uid == rhs.uid
    }
    
    /// Build contact from chat FCM notification payload (matching Android Intent extras: friendUidKey, nameKey, device_type, etc.)
    /// Extracts all available data from notification userInfo (matching Android FirebaseMessagingService.getData())
    static func fromChatNotification(userInfo: [String: Any]) -> UserActiveContactModel? {
        // Extract friendUidKey (receiverKey) - required field (matching Android Intent "friendUidKey")
        let friendUidKey = userInfo["friendUidKey"] as? String ?? ""
        guard !friendUidKey.isEmpty else {
            print("🚫 [fromChatNotification] Missing friendUidKey in userInfo")
            return nil
        }
        
        // Extract name fields (matching Android Intent "nameKey")
        let name = userInfo["name"] as? String ?? ""
        let user_nameKey = userInfo["user_nameKey"] as? String ?? ""
        let fullName = user_nameKey.isEmpty ? (name.isEmpty ? "Unknown" : name) : user_nameKey
        
        // Extract other contact fields from notification payload
        let phone = userInfo["phone"] as? String ?? ""
        let photo = userInfo["photo"] as? String ?? ""
        let device_type = userInfo["device_type"] as? String ?? ""
        let msgKey = userInfo["msgKey"] as? String ?? ""
        let currentDateTimeString = userInfo["currentDateTimeString"] as? String ?? ""
        let token = userInfo["token"] as? String ?? ""
        
        // Extract additional fields that might be in notification (matching Android notification payload)
        // These are available in userInfo but not always used for navigation
        let uidPower = userInfo["uidPower"] as? String ?? ""
        let messagePower = userInfo["messagePower"] as? String ?? ""
        let timePower = userInfo["timePower"] as? String ?? ""
        let dataTypePower = userInfo["dataTypePower"] as? String ?? ""
        let selectionCount = userInfo["selectionCount"] as? String ?? "1"
        
        print("✅ [fromChatNotification] Creating contact from notification:")
        print("   - friendUidKey: \(friendUidKey)")
        print("   - fullName: \(fullName)")
        print("   - phone: \(phone.isEmpty ? "nil" : phone)")
        print("   - photo: \(photo.isEmpty ? "nil" : "set")")
        print("   - device_type: \(device_type.isEmpty ? "nil" : device_type)")
        print("   - msgKey: \(msgKey.isEmpty ? "nil" : "\(msgKey.prefix(50))...")")
        
        return UserActiveContactModel(
            photo: photo,
            fullName: fullName,
            mobileNo: phone,
            caption: "",
            uid: friendUidKey,
            sentTime: currentDateTimeString.isEmpty ? (timePower.isEmpty ? "" : timePower) : currentDateTimeString,
            dataType: dataTypePower.isEmpty ? "Text" : dataTypePower,
            message: msgKey.isEmpty ? messagePower : msgKey,
            fToken: token,
            notification: 1,
            msgLimit: 0,
            deviceType: device_type,
            messageId: uidPower.isEmpty ? "" : uidPower,
            createdAt: currentDateTimeString.isEmpty ? (userInfo["currentDatePower"] as? String ?? "") : currentDateTimeString,
            block: false,
            iamblocked: false
        )
    }
}





