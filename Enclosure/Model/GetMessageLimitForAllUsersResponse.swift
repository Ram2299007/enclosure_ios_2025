//
//  FlagModel.swift
//  Enclosure
//
//  Created by Ram Lohar on 18/03/25.
//


import SwiftUI

struct GetMessageLimitForAllUsersResponse: Codable {
    let success: String
    let errorCode: String
    let message: String
    let data: [GetMessageLimitForAllUsersModel]?

    enum CodingKeys: String, CodingKey {
        case success
        case errorCode = "error_code"
        case message
        case data
    }
}

