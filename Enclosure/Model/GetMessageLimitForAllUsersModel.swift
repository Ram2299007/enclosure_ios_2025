//
//  get_profileResponse.swift
//  Enclosure
//
//  Created by Ram Lohar on 08/05/25.
//

import Foundation

struct GetMessageLimitForAllUsersModel: Codable {
    let msg_limit: String

    enum CodingKeys: String, CodingKey {
        case msg_limit = "msg_limit"


    }
}
