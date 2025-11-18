//
//  GroupListModel.swift
//  Enclosure
//
//  Created by Ram Lohar on 19/11/25.
//

import Foundation

struct GroupListResponse: Codable {
    let success: String
    let error_code: String
    let message: String
    let data: [GroupListItem]?
    
    private enum CodingKeys: String, CodingKey {
        case success
        case error_code
        case message
        case data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decodeFlexibleString(forKey: .success)
        error_code = try container.decodeFlexibleString(forKey: .error_code)
        message = try container.decodeFlexibleString(forKey: .message)
        data = try container.decodeIfPresent([GroupListItem].self, forKey: .data)
    }
}

struct GroupListItem: Codable, Identifiable {
    let id = UUID()
    let sr_nos: Int?
    let group_id: String
    let group_name: String
    let group_icon: String
    let group_created_by: String
    let f_token: String?
    let group_members_count: String?
    let group_members: [GroupMember]?
    let sent_time: String?
    let dec_flg: String?
    let l_msg: String?
    let data_type: String?
    
    private enum CodingKeys: String, CodingKey {
        case sr_nos
        case group_id
        case group_name
        case group_icon
        case group_created_by
        case f_token
        case group_members_count
        case group_members
        case sent_time
        case dec_flg
        case l_msg
        case data_type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sr_nos = try container.decodeIfPresent(Int.self, forKey: .sr_nos)
        group_id = try container.decodeFlexibleString(forKey: .group_id)
        group_name = try container.decodeFlexibleString(forKey: .group_name)
        group_icon = try container.decodeFlexibleString(forKey: .group_icon)
        group_created_by = try container.decodeFlexibleString(forKey: .group_created_by)
        f_token = try container.decodeFlexibleStringIfPresent(forKey: .f_token)
        group_members_count = try container.decodeFlexibleStringIfPresent(forKey: .group_members_count)
        group_members = try container.decodeIfPresent([GroupMember].self, forKey: .group_members)
        sent_time = try container.decodeFlexibleStringIfPresent(forKey: .sent_time)
        dec_flg = try container.decodeFlexibleStringIfPresent(forKey: .dec_flg)
        l_msg = try container.decodeFlexibleStringIfPresent(forKey: .l_msg)
        data_type = try container.decodeFlexibleStringIfPresent(forKey: .data_type)
    }
}

struct GroupMember: Codable, Identifiable {
    let id = UUID()
    let uid: String?
    let full_name: String?
    let mobile_no: String?
    let photo: String?
    let caption: String?
    let status: String?
    let block: String?
    let themeColor: String?
    
    private enum CodingKeys: String, CodingKey {
        case uid
        case full_name
        case mobile_no
        case photo
        case caption
        case status
        case block
        case themeColor
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uid = try container.decodeFlexibleStringIfPresent(forKey: .uid)
        full_name = try container.decodeFlexibleStringIfPresent(forKey: .full_name)
        mobile_no = try container.decodeFlexibleStringIfPresent(forKey: .mobile_no)
        photo = try container.decodeFlexibleStringIfPresent(forKey: .photo)
        caption = try container.decodeFlexibleStringIfPresent(forKey: .caption)
        status = try container.decodeFlexibleStringIfPresent(forKey: .status)
        block = try container.decodeFlexibleStringIfPresent(forKey: .block)
        themeColor = try container.decodeFlexibleStringIfPresent(forKey: .themeColor)
    }
}

fileprivate extension KeyedDecodingContainer {
    func decodeFlexibleString(forKey key: Key) throws -> String {
        if let value = try? decode(String.self, forKey: key) {
            return value
        }
        if let value = try? decode(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decode(Double.self, forKey: key) {
            return String(value)
        }
        if let value = try? decode(Bool.self, forKey: key) {
            return value ? "1" : "0"
        }
        return ""
    }
    
    func decodeFlexibleStringIfPresent(forKey key: Key) throws -> String? {
        guard contains(key) else { return nil }
        let value = try decodeFlexibleString(forKey: key)
        return value.isEmpty ? nil : value
    }
}

