import Foundation

struct CallLogResponse: Codable {
    let success: String?
    let errorCode: String
    let message: String
    let data: [CallLogSection]
    
    enum CodingKeys: String, CodingKey {
        case success
        case errorCode = "error_code"
        case message
        case data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decodeIfPresent(String.self, forKey: .success)
        
        if let stringCode = try container.decodeIfPresent(String.self, forKey: .errorCode) {
            errorCode = stringCode
        } else if let intCode = try container.decodeIfPresent(Int.self, forKey: .errorCode) {
            errorCode = String(intCode)
        } else {
            errorCode = ""
        }
        
        message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
        data = try container.decodeIfPresent([CallLogSection].self, forKey: .data) ?? []
    }
}

struct CallLogSection: Identifiable, Codable {
    let date: String
    let srNos: Int
    var userInfo: [CallLogUserInfo]
    
    var id: String {
        "\(date)-\(srNos)"
    }
    
    enum CodingKeys: String, CodingKey {
        case date
        case srNos = "sr_nos"
        case userInfo = "user_info"
    }
    
    init(date: String, srNos: Int, userInfo: [CallLogUserInfo]) {
        self.date = date
        self.srNos = srNos
        self.userInfo = userInfo
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decodeIfPresent(String.self, forKey: .date) ?? ""
        
        if let intValue = try container.decodeIfPresent(Int.self, forKey: .srNos) {
            srNos = intValue
        } else if let stringValue = try container.decodeIfPresent(String.self, forKey: .srNos),
                  let intFromString = Int(stringValue) {
            srNos = intFromString
        } else {
            srNos = 0
        }
        
        userInfo = try container.decodeIfPresent([CallLogUserInfo].self, forKey: .userInfo) ?? []
    }
}

struct CallLogUserInfo: Identifiable, Codable {
    let id: String
    let lastId: String
    let friendId: String
    let photo: String
    let fullName: String
    let fToken: String
    let deviceType: String
    let mobileNo: String
    let date: String
    let startTime: String
    let endTime: String
    let callingFlag: String
    let callType: String
    let callHistory: [CallHistoryEntry]
    let block: Bool
    let themeColor: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case lastId = "last_id"
        case friendId = "friend_id"
        case photo
        case fullName = "full_name"
        case fToken = "f_token"
        case deviceType = "device_type"
        case mobileNo = "mobile_no"
        case date
        case startTime = "start_time"
        case endTime = "end_time"
        case callingFlag = "calling_flag"
        case callType = "call_type"
        case callHistory = "call_history"
        case block
        case themeColor
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        lastId = try container.decodeIfPresent(String.self, forKey: .lastId) ?? ""
        friendId = try container.decodeIfPresent(String.self, forKey: .friendId) ?? ""
        photo = try container.decodeIfPresent(String.self, forKey: .photo) ?? ""
        fullName = try container.decodeIfPresent(String.self, forKey: .fullName) ?? ""
        fToken = try container.decodeIfPresent(String.self, forKey: .fToken) ?? ""
        deviceType = try container.decodeIfPresent(String.self, forKey: .deviceType) ?? ""
        mobileNo = try container.decodeIfPresent(String.self, forKey: .mobileNo) ?? ""
        date = try container.decodeIfPresent(String.self, forKey: .date) ?? ""
        startTime = try container.decodeIfPresent(String.self, forKey: .startTime) ?? ""
        endTime = try container.decodeIfPresent(String.self, forKey: .endTime) ?? ""
        callingFlag = try container.decodeIfPresent(String.self, forKey: .callingFlag) ?? ""
        callType = try container.decodeIfPresent(String.self, forKey: .callType) ?? ""
        callHistory = try container.decodeIfPresent([CallHistoryEntry].self, forKey: .callHistory) ?? []
        themeColor = try container.decodeIfPresent(String.self, forKey: .themeColor) ?? "#00A3E9"
        
        if let boolValue = try container.decodeIfPresent(Bool.self, forKey: .block) {
            block = boolValue
        } else if let stringValue = try container.decodeIfPresent(String.self, forKey: .block) {
            block = (stringValue == "1")
        } else if let intValue = try container.decodeIfPresent(Int.self, forKey: .block) {
            block = (intValue == 1)
        } else {
            block = false
        }
    }
}

struct CallHistoryEntry: Codable {
    let id: String
    let uid: String
    let friendId: String
    let date: String
    let startTime: String
    let endTime: String
    let callingFlag: String
    let callType: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case uid
        case friendId = "friend_id"
        case date
        case startTime = "start_time"
        case endTime = "end_time"
        case callingFlag = "calling_flag"
        case callType = "call_type"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        uid = try container.decodeIfPresent(String.self, forKey: .uid) ?? ""
        friendId = try container.decodeIfPresent(String.self, forKey: .friendId) ?? ""
        date = try container.decodeIfPresent(String.self, forKey: .date) ?? ""
        startTime = try container.decodeIfPresent(String.self, forKey: .startTime) ?? ""
        endTime = try container.decodeIfPresent(String.self, forKey: .endTime) ?? ""
        callingFlag = try container.decodeIfPresent(String.self, forKey: .callingFlag) ?? ""
        callType = try container.decodeIfPresent(String.self, forKey: .callType) ?? ""
    }
}

