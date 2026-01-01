//
//  DatabaseHelper.swift
//  Enclosure
//
//  Created for pending messages functionality
//

import Foundation
import SQLite3

final class DatabaseHelper {
    static let shared = DatabaseHelper()
    
    private let databaseURL: URL
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.enclosure.databaseHelperQueue")
    
    private let TABLE_NAME_PENDING = "pending_messages"
    
    // SQLITE_TRANSIENT constant (matching ChatCacheManager and CallCacheManager)
    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    
    private init() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        databaseURL = documentsDirectory.appendingPathComponent("enclosureDatabase.db")
        openDatabase()
        createPendingTableIfNeeded()
    }
    
    deinit {
        sqlite3_close(db)
    }
    
    // MARK: - Database Operations
    
    private func openDatabase() {
        if sqlite3_open(databaseURL.path, &db) != SQLITE_OK {
            print("⚠️ [DatabaseHelper] Unable to open SQLite database")
            db = nil
        } else {
            print("✅ [DatabaseHelper] Database opened successfully")
        }
    }
    
    private func createPendingTableIfNeeded() {
        guard let db = db else { return }
        
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS \(TABLE_NAME_PENDING) (
            uid TEXT,
            message TEXT,
            time TEXT,
            document TEXT,
            dataType TEXT,
            extension TEXT,
            name TEXT,
            phone TEXT,
            micPhoto TEXT,
            miceTiming TEXT,
            userName TEXT,
            replytextData TEXT,
            replyKey TEXT,
            replyType TEXT,
            replyOldData TEXT,
            replyCrtPostion TEXT,
            modelId TEXT,
            receiverUid TEXT,
            forwaredKey TEXT,
            groupName TEXT,
            docSize TEXT,
            fileName TEXT,
            thumbnail TEXT,
            fileNameThumbnail TEXT,
            caption TEXT,
            notification INTEGER,
            currentDate TEXT,
            emojiCount TEXT,
            timestamp REAL,
            imageWidth TEXT,
            imageHeight TEXT,
            aspectRatio TEXT,
            selectionCount TEXT,
            emojiModel TEXT,
            selectionBunch TEXT,
            uploadStatus INTEGER DEFAULT 0,
            PRIMARY KEY (modelId, receiverUid)
        );
        """
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            print("⚠️ [DatabaseHelper] Failed to create pending_messages table: \(String(cString: sqlite3_errmsg(db)))")
        } else {
            print("✅ [DatabaseHelper] pending_messages table created/verified")
        }
    }
    
    // MARK: - Pending Messages Operations
    
    /// Insert pending message (matching Android insertPendingMessage)
    func insertPendingMessage(_ message: ChatMessage) {
        queue.async {
            guard let db = self.db else { return }
            
            let insertSQL = """
            INSERT OR REPLACE INTO \(self.TABLE_NAME_PENDING)
            (uid, message, time, document, dataType, extension, name, phone, micPhoto, miceTiming,
             userName, replytextData, replyKey, replyType, replyOldData, replyCrtPostion,
             modelId, receiverUid, forwaredKey, groupName, docSize, fileName, thumbnail,
             fileNameThumbnail, caption, notification, currentDate, emojiCount, timestamp,
             imageWidth, imageHeight, aspectRatio, selectionCount, emojiModel, selectionBunch, uploadStatus)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0);
            """
            
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
                self.bindMessage(message: message, to: statement)
                
                if sqlite3_step(statement) == SQLITE_DONE {
                    print("✅ [DatabaseHelper] Pending message inserted: \(message.id)")
                } else {
                    print("⚠️ [DatabaseHelper] Failed to insert pending message: \(String(cString: sqlite3_errmsg(db)))")
                }
                
                sqlite3_finalize(statement)
            } else {
                print("⚠️ [DatabaseHelper] Failed to prepare insert statement: \(String(cString: sqlite3_errmsg(db)))")
            }
        }
    }
    
    /// Remove pending message (matching Android removePendingMessage)
    func removePendingMessage(modelId: String, receiverUid: String) -> Bool {
        var result = false
        let semaphore = DispatchSemaphore(value: 0)
        
        queue.async {
            guard let db = self.db else {
                semaphore.signal()
                return
            }
            
            let deleteSQL = "DELETE FROM \(self.TABLE_NAME_PENDING) WHERE modelId = ? AND receiverUid = ?;"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, modelId, -1, self.SQLITE_TRANSIENT)
                sqlite3_bind_text(statement, 2, receiverUid, -1, self.SQLITE_TRANSIENT)
                
                if sqlite3_step(statement) == SQLITE_DONE {
                    result = true
                    print("✅ [DatabaseHelper] Pending message removed: \(modelId)")
                } else {
                    print("⚠️ [DatabaseHelper] Failed to remove pending message: \(String(cString: sqlite3_errmsg(db)))")
                }
                
                sqlite3_finalize(statement)
            }
            
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
    
    /// Get pending messages for a receiver (matching Android getPendingMessages)
    func getPendingMessages(receiverUid: String, completion: @escaping ([ChatMessage]) -> Void) {
        queue.async {
            guard let db = self.db else {
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }
            
            var messages: [ChatMessage] = []
            let query = "SELECT * FROM \(self.TABLE_NAME_PENDING) WHERE receiverUid = ? AND uploadStatus IN (0, 1) ORDER BY timestamp ASC;"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, receiverUid, -1, self.SQLITE_TRANSIENT)
                
                while sqlite3_step(statement) == SQLITE_ROW {
                    if let message = self.messageFromStatement(statement) {
                        messages.append(message)
                    }
                }
                
                sqlite3_finalize(statement)
            }
            
            DispatchQueue.main.async {
                completion(messages)
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func bindMessage(message: ChatMessage, to statement: OpaquePointer?) {
        guard let statement = statement else { return }
        
        var index: Int32 = 1
        
        // Bind all fields
        sqlite3_bind_text(statement, index, message.uid, -1, SQLITE_TRANSIENT); index += 1
        sqlite3_bind_text(statement, index, message.message, -1, SQLITE_TRANSIENT); index += 1
        sqlite3_bind_text(statement, index, message.time, -1, SQLITE_TRANSIENT); index += 1
        sqlite3_bind_text(statement, index, message.document, -1, SQLITE_TRANSIENT); index += 1
        sqlite3_bind_text(statement, index, message.dataType, -1, SQLITE_TRANSIENT); index += 1
        sqlite3_bind_text(statement, index, message.fileExtension ?? "", -1, SQLITE_TRANSIENT); index += 1
        sqlite3_bind_text(statement, index, message.name ?? "", -1, SQLITE_TRANSIENT); index += 1
        sqlite3_bind_text(statement, index, message.phone ?? "", -1, SQLITE_TRANSIENT); index += 1
        sqlite3_bind_text(statement, index, message.micPhoto ?? "", -1, SQLITE_TRANSIENT); index += 1
        sqlite3_bind_text(statement, index, message.miceTiming ?? "", -1, SQLITE_TRANSIENT); index += 1
        sqlite3_bind_text(statement, index, message.userName ?? "", -1, SQLITE_TRANSIENT); index += 1
        sqlite3_bind_text(statement, index, message.replytextData ?? "", -1, SQLITE_TRANSIENT); index += 1
        sqlite3_bind_text(statement, index, message.replyKey ?? "", -1, SQLITE_TRANSIENT); index += 1
        sqlite3_bind_text(statement, index, message.replyType ?? "", -1, SQLITE_TRANSIENT); index += 1
        sqlite3_bind_text(statement, index, message.replyOldData ?? "", -1, SQLITE_TRANSIENT); index += 1
        sqlite3_bind_text(statement, index, message.replyCrtPostion ?? "", -1, SQLITE_TRANSIENT); index += 1
        sqlite3_bind_text(statement, index, message.id, -1, SQLITE_TRANSIENT); index += 1
        sqlite3_bind_text(statement, index, message.receiverId, -1, SQLITE_TRANSIENT); index += 1
        sqlite3_bind_text(statement, index, message.forwaredKey ?? "", -1, SQLITE_TRANSIENT); index += 1
        sqlite3_bind_text(statement, index, message.groupName ?? "", -1, SQLITE_TRANSIENT); index += 1
        sqlite3_bind_text(statement, index, message.docSize ?? "", -1, SQLITE_TRANSIENT); index += 1
        sqlite3_bind_text(statement, index, message.fileName ?? "", -1, SQLITE_TRANSIENT); index += 1
        sqlite3_bind_text(statement, index, message.thumbnail ?? "", -1, SQLITE_TRANSIENT); index += 1
        sqlite3_bind_text(statement, index, message.fileNameThumbnail ?? "", -1, SQLITE_TRANSIENT); index += 1
        sqlite3_bind_text(statement, index, message.caption ?? "", -1, SQLITE_TRANSIENT); index += 1
        sqlite3_bind_int(statement, index, Int32(message.notification)); index += 1
        sqlite3_bind_text(statement, index, message.currentDate ?? "", -1, SQLITE_TRANSIENT); index += 1
        sqlite3_bind_text(statement, index, message.emojiCount ?? "", -1, SQLITE_TRANSIENT); index += 1
        sqlite3_bind_double(statement, index, message.timestamp); index += 1
        sqlite3_bind_text(statement, index, message.imageWidth ?? "", -1, SQLITE_TRANSIENT); index += 1
        sqlite3_bind_text(statement, index, message.imageHeight ?? "", -1, SQLITE_TRANSIENT); index += 1
        sqlite3_bind_text(statement, index, message.aspectRatio ?? "", -1, SQLITE_TRANSIENT); index += 1
        sqlite3_bind_text(statement, index, message.selectionCount ?? "", -1, SQLITE_TRANSIENT); index += 1
        
        // Serialize emojiModel and selectionBunch to JSON
        let emojiJson = self.serializeEmojiModel(message.emojiModel)
        sqlite3_bind_text(statement, index, emojiJson, -1, SQLITE_TRANSIENT); index += 1
        
        let selectionBunchJson = self.serializeSelectionBunch(message.selectionBunch)
        sqlite3_bind_text(statement, index, selectionBunchJson, -1, SQLITE_TRANSIENT)
    }
    
    private func messageFromStatement(_ statement: OpaquePointer?) -> ChatMessage? {
        guard let statement = statement else { return nil }
        
        // Helper to safely get text from column (handles NULL values)
        func getText(column: Int32) -> String {
            if let text = sqlite3_column_text(statement, column) {
                return String(cString: text)
            }
            return ""
        }
        
        // Read all columns (matching Android cursor reading)
        let uid = getText(column: 0)
        let message = getText(column: 1)
        let time = getText(column: 2)
        let document = getText(column: 3)
        let dataType = getText(column: 4)
        let extension_ = getText(column: 5)
        let name = getText(column: 6)
        let phone = getText(column: 7)
        let micPhoto = getText(column: 8)
        let miceTiming = getText(column: 9)
        let userName = getText(column: 10)
        let replytextData = getText(column: 11)
        let replyKey = getText(column: 12)
        let replyType = getText(column: 13)
        let replyOldData = getText(column: 14)
        let replyCrtPostion = getText(column: 15)
        let modelId = getText(column: 16)
        let receiverUid = getText(column: 17)
        let forwaredKey = getText(column: 18)
        let groupName = getText(column: 19)
        let docSize = getText(column: 20)
        let fileName = getText(column: 21)
        let thumbnail = getText(column: 22)
        let fileNameThumbnail = getText(column: 23)
        let caption = getText(column: 24)
        let notification = Int(sqlite3_column_int(statement, 25))
        let currentDate = getText(column: 26)
        let emojiCount = getText(column: 27)
        let timestamp = sqlite3_column_double(statement, 28)
        let imageWidth = getText(column: 29)
        let imageHeight = getText(column: 30)
        let aspectRatio = getText(column: 31)
        let selectionCount = getText(column: 32)
        let emojiModelJson = getText(column: 33)
        let selectionBunchJson = getText(column: 34)
        
        // Deserialize emojiModel and selectionBunch
        let emojiModel = deserializeEmojiModel(emojiModelJson)
        let selectionBunch = deserializeSelectionBunch(selectionBunchJson)
        
        return ChatMessage(
            id: modelId,
            uid: uid,
            message: message,
            time: time,
            document: document,
            dataType: dataType,
            fileExtension: extension_.isEmpty ? nil : extension_,
            name: name.isEmpty ? nil : name,
            phone: phone.isEmpty ? nil : phone,
            micPhoto: micPhoto.isEmpty ? nil : micPhoto,
            miceTiming: miceTiming.isEmpty ? nil : miceTiming,
            userName: userName.isEmpty ? nil : userName,
            receiverId: receiverUid,
            replytextData: replytextData.isEmpty ? nil : replytextData,
            replyKey: replyKey.isEmpty ? nil : replyKey,
            replyType: replyType.isEmpty ? nil : replyType,
            replyOldData: replyOldData.isEmpty ? nil : replyOldData,
            replyCrtPostion: replyCrtPostion.isEmpty ? nil : replyCrtPostion,
            forwaredKey: forwaredKey.isEmpty ? nil : forwaredKey,
            groupName: groupName.isEmpty ? nil : groupName,
            docSize: docSize.isEmpty ? nil : docSize,
            fileName: fileName.isEmpty ? nil : fileName,
            thumbnail: thumbnail.isEmpty ? nil : thumbnail,
            fileNameThumbnail: fileNameThumbnail.isEmpty ? nil : fileNameThumbnail,
            caption: caption.isEmpty ? nil : caption,
            notification: notification,
            currentDate: currentDate.isEmpty ? nil : currentDate,
            emojiModel: emojiModel,
            emojiCount: emojiCount.isEmpty ? nil : emojiCount,
            timestamp: timestamp,
            imageWidth: imageWidth.isEmpty ? nil : imageWidth,
            imageHeight: imageHeight.isEmpty ? nil : imageHeight,
            aspectRatio: aspectRatio.isEmpty ? nil : aspectRatio,
            selectionCount: selectionCount.isEmpty ? nil : selectionCount,
            selectionBunch: selectionBunch,
            receiverLoader: 0 // Pending messages always have receiverLoader = 0
        )
    }
    
    private func serializeEmojiModel(_ emojiModel: [EmojiModel]?) -> String {
        guard let emojiModel = emojiModel else { return "[]" }
        do {
            let data = try JSONEncoder().encode(emojiModel)
            return String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            return "[]"
        }
    }
    
    private func deserializeEmojiModel(_ json: String) -> [EmojiModel] {
        guard let data = json.data(using: .utf8) else { return [] }
        do {
            return try JSONDecoder().decode([EmojiModel].self, from: data)
        } catch {
            return []
        }
    }
    
    private func serializeSelectionBunch(_ selectionBunch: [SelectionBunchModel]?) -> String {
        guard let selectionBunch = selectionBunch else { return "[]" }
        do {
            let data = try JSONEncoder().encode(selectionBunch)
            return String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            return "[]"
        }
    }
    
    private func deserializeSelectionBunch(_ json: String) -> [SelectionBunchModel]? {
        guard let data = json.data(using: .utf8) else { return nil }
        do {
            return try JSONDecoder().decode([SelectionBunchModel].self, from: data)
        } catch {
            return nil
        }
    }
}

