//
//  get_profileResponse.swift
//  Enclosure
//
//  Created by Ram Lohar on 08/05/25.
//

import Foundation

struct GetUserProfileImagesModel: Codable, Equatable {
    let id: String
    let photo: String
 

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case photo = "photo"

    }
}
