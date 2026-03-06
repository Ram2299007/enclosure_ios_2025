//
//  ThemeColorResponse.swift
//  Enclosure
//
//  Created by Ram Lohar.
//

import Foundation

struct ThemeColorResponse: Codable {
    let success: String
    let error_code: String
    let message: String
    let data: ThemeColorData?

    enum CodingKeys: String, CodingKey {
        case success = "success"
        case error_code = "error_code"
        case message = "message"
        case data = "data"
    }
}

struct ThemeColorData: Codable {
    let uid: String
    let themeColor: String

    enum CodingKeys: String, CodingKey {
        case uid = "uid"
        case themeColor = "themeColor"
    }
}
