//
//  get_profileResponse.swift
//  Enclosure
//
//  Created by Ram Lohar on 08/05/25.
//

import Foundation

struct GlobalResponse: Codable {
    let success: String
    let error_code: String
    let message: String


    enum CodingKeys: String, CodingKey {
        case success = "success"
        case error_code = "error_code"
        case message = "message"

    }
}
