//
//  FlagModel.swift
//  Enclosure
//
//  Created by Ram Lohar on 18/03/25.
//


import SwiftUI

// ✅ `id` डिकोडिंगमध्ये अडथळा ठरू नये म्हणून default value दिली आहे
struct FlagModel: Identifiable, Codable {
    var id = UUID()
    let c_id: String
    let country_c_code: String
    let country_name: String
    let country_code: String

    enum CodingKeys: String, CodingKey {
        case c_id, country_c_code, country_name, country_code
    }
}
