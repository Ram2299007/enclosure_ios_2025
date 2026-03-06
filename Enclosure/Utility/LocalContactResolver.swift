//
//  LocalContactResolver.swift
//  Enclosure
//
//  Resolves local contact names from iOS Contacts by phone number.
//  Used to show the name the user saved in their phone (like WhatsApp),
//  not the sender's server-side display name.
//

import Foundation
import Contacts

final class LocalContactResolver {
    static let shared = LocalContactResolver()
    private let store = CNContactStore()
    private init() {}
    
    /// Look up a contact name from iOS Contacts by phone number.
    /// Returns the locally stored contact name (like WhatsApp shows), or nil if not found.
    func resolveLocalName(for phoneNumber: String) -> String? {
        let trimmed = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else { return nil }
        
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactNicknameKey as CNKeyDescriptor
        ]
        
        do {
            let predicate = CNContact.predicateForContacts(matching: CNPhoneNumber(stringValue: trimmed))
            let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
            guard let contact = contacts.first else { return nil }
            
            if !contact.nickname.isEmpty {
                return contact.nickname
            }
            return CNContactFormatter.string(from: contact, style: .fullName)
        } catch {
            NSLog("⚠️ [LocalContactResolver] Error: \(error.localizedDescription)")
            return nil
        }
    }
}
