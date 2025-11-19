//
//  CallCacheManager.swift
//  Enclosure
//
//  Created by ChatGPT on 19/11/25.
//

import Foundation
import SQLite3

enum CallLogCacheType: String {
    case voice
    case video
}

final class CallCacheManager {
    static let shared = CallCacheManager()

    private let queue = DispatchQueue(label: "com.enclosure.callCacheQueue")
    private let databaseURL: URL
    private var db: OpaquePointer?

    private init() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        databaseURL = documentsDirectory.appendingPathComponent("call_cache.sqlite")
        openDatabase()
        createTableIfNeeded()
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Public API

    func cacheContacts(_ contacts: [CallingContactModel]) {
        store(contacts, for: "contacts")
    }

    func fetchContacts(completion: @escaping ([CallingContactModel]) -> Void) {
        load(key: "contacts", completion: completion)
    }

    func cacheCallLogs(_ sections: [CallLogSection], type: CallLogCacheType) {
        store(sections, for: cacheKey(for: type))
    }

    func fetchCallLogs(type: CallLogCacheType, completion: @escaping ([CallLogSection]) -> Void) {
        load(key: cacheKey(for: type), completion: completion)
    }

    func cacheGroupMessages(_ groups: [GroupModel]) {
        store(groups, for: "group_messages")
    }

    func fetchGroupMessages(completion: @escaping ([GroupModel]) -> Void) {
        load(key: "group_messages", completion: completion)
    }

    func cacheMsgLimitContacts(_ contacts: [UserActiveContactModel]) {
        store(contacts, for: "msg_limit_contacts")
    }

    func fetchMsgLimitContacts(completion: @escaping ([UserActiveContactModel]) -> Void) {
        load(key: "msg_limit_contacts", completion: completion)
    }

    func cacheYouProfiles(_ profiles: [GetProfileModel]) {
        store(profiles, for: "you_profiles")
    }

    func fetchYouProfiles(completion: @escaping ([GetProfileModel]) -> Void) {
        load(key: "you_profiles", completion: completion)
    }

    func cacheYouProfileImages(_ images: [GetUserProfileImagesModel]) {
        store(images, for: "you_profile_images")
    }

    func fetchYouProfileImages(completion: @escaping ([GetUserProfileImagesModel]) -> Void) {
        load(key: "you_profile_images", completion: completion)
    }

    // MARK: - Private helpers

    private func cacheKey(for type: CallLogCacheType) -> String {
        "call_logs_\(type.rawValue)"
    }

    private func store<T: Codable>(_ value: [T], for key: String) {
        queue.async {
            guard let db = self.db else { return }
            guard let data = try? JSONEncoder().encode(value) else {
                print("⚠️ [CallCacheManager] Failed to encode data for key \(key)")
                return
            }

            let sql = """
            INSERT INTO call_cache (cache_key, payload, updated_at)
            VALUES (?, ?, ?)
            ON CONFLICT(cache_key) DO UPDATE SET payload = excluded.payload, updated_at = excluded.updated_at;
            """

            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, key, -1, SQLITE_TRANSIENT)
                sqlite3_bind_blob(statement, 2, (data as NSData).bytes, Int32(data.count), SQLITE_TRANSIENT)
                sqlite3_bind_double(statement, 3, Date().timeIntervalSince1970)

                if sqlite3_step(statement) != SQLITE_DONE {
                    print("⚠️ [CallCacheManager] Failed to store data for key \(key): \(String(cString: sqlite3_errmsg(db)))")
                }
            } else {
                print("⚠️ [CallCacheManager] Prepare failed for key \(key): \(String(cString: sqlite3_errmsg(db)))")
            }

            sqlite3_finalize(statement)
        }
    }

    private func load<T: Codable>(key: String, completion: @escaping ([T]) -> Void) {
        queue.async {
            guard let db = self.db else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            let sql = "SELECT payload FROM call_cache WHERE cache_key = ? LIMIT 1;"
            var statement: OpaquePointer?
            var result: [T] = []

            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, key, -1, SQLITE_TRANSIENT)

                if sqlite3_step(statement) == SQLITE_ROW {
                    if let blobPointer = sqlite3_column_blob(statement, 0) {
                        let size = Int(sqlite3_column_bytes(statement, 0))
                        let data = Data(bytes: blobPointer, count: size)
                        if let decoded = try? JSONDecoder().decode([T].self, from: data) {
                            result = decoded
                        } else {
                            print("⚠️ [CallCacheManager] Failed to decode data for key \(key)")
                        }
                    }
                }
            } else {
                print("⚠️ [CallCacheManager] Prepare fetch failed for key \(key): \(String(cString: sqlite3_errmsg(db)))")
            }

            sqlite3_finalize(statement)

            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    private func openDatabase() {
        if sqlite3_open(databaseURL.path, &db) != SQLITE_OK {
            print("⚠️ [CallCacheManager] Unable to open database")
            db = nil
        }
    }

    private func createTableIfNeeded() {
        guard let db = db else { return }
        let sql = """
        CREATE TABLE IF NOT EXISTS call_cache (
            cache_key TEXT PRIMARY KEY,
            payload BLOB,
            updated_at REAL
        );
        """

        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            print("⚠️ [CallCacheManager] Failed to create table: \(String(cString: sqlite3_errmsg(db)))")
        }
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)


