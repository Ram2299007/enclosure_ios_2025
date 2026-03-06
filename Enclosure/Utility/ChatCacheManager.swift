//
//  ChatCacheManager.swift
//  Enclosure
//
//  Created by ChatGPT on 19/11/25.
//

import Foundation
import SQLite3

final class ChatCacheManager {
    static let shared = ChatCacheManager()

    private let databaseURL: URL
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.enclosure.chatCacheQueue")

    private init() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        databaseURL = documentsDirectory.appendingPathComponent("chat_cache.sqlite")
        openDatabase()
        createTableIfNeeded()
    }

    deinit {
        sqlite3_close(db)
    }

    func cacheChats(_ chats: [UserActiveContactModel]) {
        queue.async {
            guard let db = self.db else { return }
            sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)
            sqlite3_exec(db, "DELETE FROM chats;", nil, nil, nil)

            let insertSQL = """
            INSERT OR REPLACE INTO chats
            (uid, photo, full_name, mobile_no, caption, sent_time, data_type, message, f_token, notification, msg_limit, device_type, message_id, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """

            var statement: OpaquePointer?

            if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
                for chat in chats {
                    self.bind(chat: chat, to: statement)

                    if sqlite3_step(statement) != SQLITE_DONE {
                        print("⚠️ SQLite insert failed: \(String(cString: sqlite3_errmsg(db)))")
                    }

                    sqlite3_reset(statement)
                }
            } else {
                print("⚠️ SQLite prepare insert failed: \(String(cString: sqlite3_errmsg(db)))")
            }

            sqlite3_finalize(statement)
            sqlite3_exec(db, "COMMIT;", nil, nil, nil)
        }
    }

    func fetchChats(completion: @escaping ([UserActiveContactModel]) -> Void) {
        queue.async {
            guard let db = self.db else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            let query = "SELECT uid, photo, full_name, mobile_no, caption, sent_time, data_type, message, f_token, notification, msg_limit, device_type, message_id, created_at FROM chats ORDER BY created_at DESC;"
            var statement: OpaquePointer?
            var cachedChats: [UserActiveContactModel] = []

            if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
                while sqlite3_step(statement) == SQLITE_ROW {
                    let chat = self.chat(from: statement)
                    cachedChats.append(chat)
                }
            } else {
                print("⚠️ SQLite fetch failed: \(String(cString: sqlite3_errmsg(db)))")
            }

            sqlite3_finalize(statement)

            DispatchQueue.main.async {
                completion(cachedChats)
            }
        }
    }
    
    func getFCMToken(for uid: String, completion: @escaping (String?) -> Void) {
        queue.async {
            guard let db = self.db else {
                print("🔑 [ChatCacheManager] Database not available for FCM token lookup - uid: \(uid)")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            print("🔑 [ChatCacheManager] Looking up FCM token for receiver UID: \(uid)")
            let query = "SELECT f_token FROM chats WHERE uid = ? LIMIT 1;"
            var statement: OpaquePointer?
            var fcmToken: String?
            
            if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, uid, -1, SQLITE_TRANSIENT)
                
                if sqlite3_step(statement) == SQLITE_ROW {
                    if let cString = sqlite3_column_text(statement, 0) {
                        fcmToken = String(cString: cString)
                        print("🔑 [ChatCacheManager] ✅ FCM token found for UID: \(uid)")
                        print("🔑 [ChatCacheManager]   Token: \(fcmToken?.isEmpty == false ? fcmToken! : "EMPTY")")
                        print("🔑 [ChatCacheManager]   Token Preview: \(fcmToken?.isEmpty == false ? "\(fcmToken!.prefix(50))..." : "EMPTY")")
                    } else {
                        print("🔑 [ChatCacheManager] ⚠️ FCM token column is NULL for UID: \(uid)")
                    }
                } else {
                    print("🔑 [ChatCacheManager] ⚠️ No contact found in database for UID: \(uid)")
                }
            } else {
                print("🔑 [ChatCacheManager] ❌ SQLite getFCMToken failed: \(String(cString: sqlite3_errmsg(db)))")
            }
            
            sqlite3_finalize(statement)
            
            DispatchQueue.main.async {
                completion(fcmToken)
            }
        }
    }
    
    /// Upserts a single contact so device_type and f_token are available for send_notification_api when ChattingScreen is opened from chatView.
    func upsertContact(_ contact: UserActiveContactModel) {
        queue.async {
            guard let db = self.db else { return }
            let insertSQL = """
            INSERT OR REPLACE INTO chats
            (uid, photo, full_name, mobile_no, caption, sent_time, data_type, message, f_token, notification, msg_limit, device_type, message_id, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
                self.bind(chat: contact, to: statement)
                if sqlite3_step(statement) == SQLITE_DONE {
                    print("🔑 [ChatCacheManager] Upserted contact for uid: \(contact.uid), device_type: \(contact.deviceType)")
                }
                sqlite3_finalize(statement)
            }
        }
    }
    
    /// Returns receiver's device_type from cache (e.g. "1" = Android, "2" = iOS). Backend uses this to build FCM payload (iOS needs notification block).
    func getDeviceType(for uid: String, completion: @escaping (String?) -> Void) {
        queue.async {
            guard let db = self.db else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let query = "SELECT device_type FROM chats WHERE uid = ? LIMIT 1;"
            var statement: OpaquePointer?
            var deviceType: String?
            if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, uid, -1, SQLITE_TRANSIENT)
                if sqlite3_step(statement) == SQLITE_ROW, let cString = sqlite3_column_text(statement, 0) {
                    deviceType = String(cString: cString)
                }
                sqlite3_finalize(statement)
            }
            DispatchQueue.main.async { completion(deviceType) }
        }
    }
}

private extension ChatCacheManager {
    func openDatabase() {
        if sqlite3_open(databaseURL.path, &db) != SQLITE_OK {
            print("⚠️ Unable to open SQLite database")
            db = nil
        }
    }

    func createTableIfNeeded() {
        guard let db = db else { return }
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS chats (
            uid TEXT PRIMARY KEY,
            photo TEXT,
            full_name TEXT,
            mobile_no TEXT,
            caption TEXT,
            sent_time TEXT,
            data_type TEXT,
            message TEXT,
            f_token TEXT,
            notification INTEGER,
            msg_limit INTEGER,
            device_type TEXT,
            message_id TEXT,
            created_at TEXT
        );
        """

        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            print("⚠️ Failed to create chats table: \(String(cString: sqlite3_errmsg(db)))")
        }
    }

    func bind(chat: UserActiveContactModel, to statement: OpaquePointer?) {
        guard let statement = statement else { return }

        let values: [Any] = [
            chat.uid,
            chat.photo,
            chat.fullName,
            chat.mobileNo,
            chat.caption,
            chat.sentTime,
            chat.dataType,
            chat.message,
            chat.fToken,
            chat.notification,
            chat.msgLimit,
            chat.deviceType,
            chat.messageId,
            chat.createdAt
        ]

        for (index, value) in values.enumerated() {
            let position = Int32(index + 1)
            if let text = value as? String {
                sqlite3_bind_text(statement, position, text, -1, SQLITE_TRANSIENT)
            } else if let number = value as? Int {
                sqlite3_bind_int(statement, position, Int32(number))
            } else {
                sqlite3_bind_null(statement, position)
            }
        }
    }

    func chat(from statement: OpaquePointer?) -> UserActiveContactModel {
        func text(at index: Int32) -> String {
            guard let cString = sqlite3_column_text(statement, index) else { return "" }
            return String(cString: cString)
        }

        let uid = text(at: 0)
        let photo = text(at: 1)
        let fullName = text(at: 2)
        let mobileNo = text(at: 3)
        let caption = text(at: 4)
        let sentTime = text(at: 5)
        let dataType = text(at: 6)
        let message = text(at: 7)
        let fToken = text(at: 8)
        let notification = Int(sqlite3_column_int(statement, 9))
        let msgLimit = Int(sqlite3_column_int(statement, 10))
        let deviceType = text(at: 11)
        let messageId = text(at: 12)
        let createdAt = text(at: 13)

        return UserActiveContactModel(
            photo: photo,
            fullName: fullName,
            mobileNo: mobileNo,
            caption: caption,
            uid: uid,
            sentTime: sentTime,
            dataType: dataType,
            message: message,
            fToken: fToken,
            notification: notification,
            msgLimit: msgLimit,
            deviceType: deviceType,
            messageId: messageId,
            createdAt: createdAt
        )
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)


