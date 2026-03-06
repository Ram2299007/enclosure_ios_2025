//
//  CountryResponse.swift
//  Enclosure
//
//  Created by Ram Lohar on 18/03/25.
//

import SwiftUI

struct CountryResponse: Codable {
    let success: StringOrInt
    let error_code: StringOrInt
    let message: String
    let data: [FlagModel]
}
