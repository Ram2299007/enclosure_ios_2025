//
//  get_profileResponse.swift
//  Enclosure
//
//  Created by Ram Lohar on 08/05/25.
//

import Foundation

struct GetUserProfileImagesResponse: Codable {
    let success: String
    let error_code: String
    let message: String
    let data: [GetUserProfileImagesModel]

    enum CodingKeys: String, CodingKey {
        case success = "success"
        case error_code = "error_code"
        case message = "message"
        case data = "data"
    }
}
