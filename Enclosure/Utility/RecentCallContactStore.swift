//
//  RecentCallContactStore.swift
//  Enclosure
//
//  Persists contact info for recent calls so that tapping a call
//  in the iPhone's native Phone app Recents can initiate an
//  Enclosure voice call directly.
//

import Foundation

struct RecentCallContact: Codable {
    let friendId: String
    let fullName: String
    let photo: String
    let fToken: String
    let voipToken: String
    let deviceType: String
    let mobileNo: String
    let updatedAt: Date
}

final class RecentCallContactStore {
    static let shared = RecentCallContactStore()
    
    private let storageKey = "enclosure_recent_call_contacts"
    private let maxEntries = 50
    
    private init() {}
    
    // MARK: - Save Contact
    
    /// Save or update a contact's info for callback from native Phone app Recents.
    /// Merges with existing data: non-empty fields in the new contact overwrite,
    /// but empty fields fall back to existing data (prevents partial saves from
    /// clearing good data).
    func saveContact(_ contact: RecentCallContact) {
        var contacts = loadAll()
        
        if let existing = contacts[contact.friendId] {
            // Merge: prefer new non-empty values, keep existing if new is empty
            let merged = RecentCallContact(
                friendId: contact.friendId,
                fullName: contact.fullName.isEmpty ? existing.fullName : contact.fullName,
                photo: contact.photo.isEmpty ? existing.photo : contact.photo,
                fToken: contact.fToken.isEmpty ? existing.fToken : contact.fToken,
                voipToken: contact.voipToken.isEmpty ? existing.voipToken : contact.voipToken,
                deviceType: contact.deviceType.isEmpty ? existing.deviceType : contact.deviceType,
                mobileNo: contact.mobileNo.isEmpty ? existing.mobileNo : contact.mobileNo,
                updatedAt: Date()
            )
            contacts[contact.friendId] = merged
        } else {
            contacts[contact.friendId] = contact
        }
        
        // Trim oldest entries if over limit
        if contacts.count > maxEntries {
            let sorted = contacts.sorted { $0.value.updatedAt < $1.value.updatedAt }
            let toRemove = contacts.count - maxEntries
            for (key, _) in sorted.prefix(toRemove) {
                contacts.removeValue(forKey: key)
            }
        }
        
        saveAll(contacts)
        NSLog("📇 [RecentCallContactStore] Saved contact: \(contact.fullName) (id=\(contact.friendId))")
    }
    
    /// Convenience: save from a CallLogUserInfo entry (call log list).
    func saveFromCallLogEntry(_ entry: CallLogUserInfo) {
        let contact = RecentCallContact(
            friendId: entry.friendId,
            fullName: entry.fullName,
            photo: entry.photo,
            fToken: entry.fToken,
            voipToken: entry.voipToken,
            deviceType: entry.deviceType,
            mobileNo: entry.mobileNo,
            updatedAt: Date()
        )
        saveContact(contact)
    }
    
    /// Convenience: save from outgoing call payload + extra tokens.
    func saveFromOutgoingCall(
        friendId: String,
        fullName: String,
        photo: String,
        fToken: String,
        voipToken: String,
        deviceType: String,
        mobileNo: String
    ) {
        let contact = RecentCallContact(
            friendId: friendId,
            fullName: fullName,
            photo: photo,
            fToken: fToken,
            voipToken: voipToken,
            deviceType: deviceType,
            mobileNo: mobileNo,
            updatedAt: Date()
        )
        saveContact(contact)
    }
    
    // MARK: - Retrieve Contact
    
    func getContact(for friendId: String) -> RecentCallContact? {
        let contacts = loadAll()
        return contacts[friendId]
    }
    
    // MARK: - Persistence
    
    private func loadAll() -> [String: RecentCallContact] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [:] }
        do {
            return try JSONDecoder().decode([String: RecentCallContact].self, from: data)
        } catch {
            NSLog("⚠️ [RecentCallContactStore] Failed to decode: \(error.localizedDescription)")
            return [:]
        }
    }
    
    private func saveAll(_ contacts: [String: RecentCallContact]) {
        do {
            let data = try JSONEncoder().encode(contacts)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            NSLog("⚠️ [RecentCallContactStore] Failed to encode: \(error.localizedDescription)")
        }
    }
}
