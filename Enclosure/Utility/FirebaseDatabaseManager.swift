//
//  FirebaseDatabaseManager.swift
//  Enclosure
//
//  Created for Firebase Realtime Database integration
//

import Foundation
import FirebaseDatabase

class FirebaseDatabaseManager {
    static let shared = FirebaseDatabaseManager()
    
    private var database: DatabaseReference {
        return Database.database().reference()
    }
    
    private init() {}
    
    // MARK: - Database Reference Helpers
    
    /// Get reference to a specific path
    func reference(_ path: String) -> DatabaseReference {
        return database.child(path)
    }
    
    // MARK: - Write Operations
    
    /// Write data to a specific path
    func write(path: String, data: [String: Any], completion: @escaping (Error?) -> Void) {
        database.child(path).setValue(data) { error, _ in
            completion(error)
        }
    }
    
    /// Update data at a specific path
    func update(path: String, data: [String: Any], completion: @escaping (Error?) -> Void) {
        database.child(path).updateChildValues(data) { error, _ in
            completion(error)
        }
    }
    
    /// Push data to a path (creates auto-generated key)
    func push(path: String, data: [String: Any], completion: @escaping (String?, Error?) -> Void) {
        let ref = database.child(path).childByAutoId()
        ref.setValue(data) { error, _ in
            if let error = error {
                completion(nil, error)
            } else {
                completion(ref.key, nil)
            }
        }
    }
    
    /// Delete data at a specific path
    func delete(path: String, completion: @escaping (Error?) -> Void) {
        database.child(path).removeValue { error, _ in
            completion(error)
        }
    }
    
    // MARK: - Read Operations
    
    /// Observe value changes at a path
    func observe(path: String, completion: @escaping (DataSnapshot?) -> Void) -> DatabaseHandle {
        return database.child(path).observe(.value) { snapshot in
            completion(snapshot)
        }
    }
    
    /// Observe child added events
    func observeChildAdded(path: String, completion: @escaping (DataSnapshot) -> Void) -> DatabaseHandle {
        return database.child(path).observe(.childAdded) { snapshot in
            completion(snapshot)
        }
    }
    
    /// Observe child changed events
    func observeChildChanged(path: String, completion: @escaping (DataSnapshot) -> Void) -> DatabaseHandle {
        return database.child(path).observe(.childChanged) { snapshot in
            completion(snapshot)
        }
    }
    
    /// Observe child removed events
    func observeChildRemoved(path: String, completion: @escaping (DataSnapshot) -> Void) -> DatabaseHandle {
        return database.child(path).observe(.childRemoved) { snapshot in
            completion(snapshot)
        }
    }
    
    /// Read data once (single read)
    func readOnce(path: String, completion: @escaping (DataSnapshot?) -> Void) {
        database.child(path).observeSingleEvent(of: .value) { snapshot in
            completion(snapshot)
        }
    }
    
    /// Remove observer
    func removeObserver(handle: DatabaseHandle, path: String) {
        database.child(path).removeObserver(withHandle: handle)
    }
    
    /// Remove all observers at a path
    func removeAllObservers(path: String) {
        database.child(path).removeAllObservers()
    }
    
    // MARK: - Chat-Specific Methods
    
    /// Send a chat message
    func sendMessage(
        senderId: String,
        receiverId: String,
        message: String,
        dataType: String = "Text",
        imageUrl: String? = nil,
        videoUrl: String? = nil,
        documentUrl: String? = nil,
        completion: @escaping (String?, Error?) -> Void
    ) {
        let timestamp = ServerValue.timestamp()
        let messageId = UUID().uuidString
        
        let messageData: [String: Any] = [
            "id": messageId,
            "senderId": senderId,
            "receiverId": receiverId,
            "text": message,
            "timestamp": timestamp,
            "dataType": dataType,
            "imageUrl": imageUrl ?? "",
            "videoUrl": videoUrl ?? "",
            "documentUrl": documentUrl ?? ""
        ]
        
        // Store in both sender and receiver paths for easy retrieval
        let senderPath = "messages/\(senderId)/\(receiverId)/\(messageId)"
        let receiverPath = "messages/\(receiverId)/\(senderId)/\(messageId)"
        
        // Also store in a conversation path
        let conversationPath = "conversations/\(min(senderId, receiverId))/\(max(senderId, receiverId))/\(messageId)"
        
        let updates: [String: Any] = [
            senderPath: messageData,
            receiverPath: messageData,
            conversationPath: messageData
        ]
        
        database.updateChildValues(updates) { error, _ in
            if let error = error {
                completion(nil, error)
            } else {
                completion(messageId, nil)
            }
        }
    }
    
    /// Load messages for a conversation
    func loadMessages(
        userId: String,
        contactId: String,
        limit: UInt = 50,
        completion: @escaping ([[String: Any]]?, Error?) -> Void
    ) {
        let path = "messages/\(userId)/\(contactId)"
        
        database.child(path)
            .queryOrderedByKey()
            .queryLimited(toLast: limit)
            .observeSingleEvent(of: .value) { snapshot in
                guard let value = snapshot.value as? [String: [String: Any]] else {
                    completion([], nil)
                    return
                }
                
                let messages = Array(value.values)
                completion(messages, nil)
            }
    }
    
    /// Observe new messages in real-time
    func observeMessages(
        userId: String,
        contactId: String,
        onNewMessage: @escaping ([String: Any]) -> Void
    ) -> DatabaseHandle {
        let path = "messages/\(userId)/\(contactId)"
        
        return database.child(path)
            .queryLimited(toLast: 1)
            .observe(.childAdded) { snapshot in
                if let messageData = snapshot.value as? [String: Any] {
                    onNewMessage(messageData)
                }
            }
    }
    
    // MARK: - User Status Methods
    
    /// Update user online status
    func updateUserStatus(userId: String, isOnline: Bool, lastSeen: TimeInterval? = nil) {
        let status: [String: Any] = [
            "isOnline": isOnline,
            "lastSeen": lastSeen ?? ServerValue.timestamp()
        ]
        
        database.child("users/\(userId)/status").setValue(status)
    }
    
    /// Observe user status changes
    func observeUserStatus(userId: String, completion: @escaping ([String: Any]?) -> Void) -> DatabaseHandle {
        return database.child("users/\(userId)/status").observe(.value) { snapshot in
            completion(snapshot.value as? [String: Any])
        }
    }
}

