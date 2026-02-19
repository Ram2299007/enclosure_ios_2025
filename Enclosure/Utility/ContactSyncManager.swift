//
//  ContactSyncManager.swift
//  Enclosure
//
//  Created by ChatGPT on 20/11/25.
//

import Foundation
import Contacts

final class ContactSyncManager {
    static let shared = ContactSyncManager()
    
    enum SyncError: LocalizedError {
        case permissionDenied
        case missingIdentity
        case failedToCreateFile
        case uploadFailed(String)
        case saveFailed(String)
        case underlying(Error)
        
        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Contacts permission is required to sync your address book."
            case .missingIdentity:
                return "We could not find your account details. Please sign in again."
            case .failedToCreateFile:
                return "Unable to prepare your contacts file. Please try again."
            case .uploadFailed(let message):
                return message.isEmpty ? "Failed to upload contacts." : message
            case .saveFailed(let message):
                return message.isEmpty ? "Failed to finalize contact sync." : message
            case .underlying(let error):
                return error.localizedDescription
            }
        }
    }
    
    private let contactStore = CNContactStore()
    
    private init() {}
    
    func syncContacts(completion: @escaping (Result<Void, SyncError>) -> Void) {
        guard let uid = UserDefaults.standard.string(forKey: Constant.UID_KEY), !uid.isEmpty else {
            completion(.failure(.missingIdentity))
            return
        }
        
        let countryCode = UserDefaults.standard.string(forKey: Constant.country_Code) ?? ""
        let phoneNumber = UserDefaults.standard.string(forKey: Constant.PHONE_NUMBERKEY) ?? ""
        
        requestAccess { [weak self] granted in
            guard let self = self else { return }
            guard granted else {
                completion(.failure(.permissionDenied))
                return
            }
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let jsonData = try self.buildContactsPayload(uid: uid, phoneNumber: phoneNumber, countryCode: countryCode)
                    let fileName = "contact_\(uid).json"
                    let fileURL = try self.write(jsonData: jsonData, fileName: fileName)
                    ApiService.shared.uploadUserContactList(uid: uid,
                                                            fileURL: fileURL,
                                                            fileName: fileName,
                                                            countryCodeKey: countryCode) { success, message in
                        guard success else {
                            completion(.failure(.uploadFailed(message)))
                            return
                        }
                        
                        ApiService.shared.saveContactFile(fileName: fileName) { saveSuccess, saveMessage in
                            if saveSuccess {
                                completion(.success(()))
                            } else {
                                completion(.failure(.saveFailed(saveMessage)))
                            }
                        }
                    }
                } catch let syncError as SyncError {
                    completion(.failure(syncError))
                } catch {
                    completion(.failure(.underlying(error)))
                }
            }
        }
    }
    
    private func requestAccess(completion: @escaping (Bool) -> Void) {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized:
            completion(true)
        case .denied, .restricted:
            completion(false)
        case .notDetermined:
            contactStore.requestAccess(for: .contacts) { granted, _ in
                completion(granted)
            }
        @unknown default:
            completion(false)
        }
    }
    
    private func buildContactsPayload(uid: String, phoneNumber: String, countryCode: String) throws -> Data {
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactMiddleNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
        ]
        
        let request = CNContactFetchRequest(keysToFetch: keys)
        var contactsPayload: [[String: Any]] = []
        var seenNumbers = Set<String>()
        
        try contactStore.enumerateContacts(with: request) { contact, stop in
            if contactsPayload.count >= 10_000 {
                stop.pointee = true
                return
            }
            
            let displayName = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
            
            for phone in contact.phoneNumbers {
                guard let normalized = normalizeNumber(phone.value.stringValue, countryCode: countryCode) else {
                    continue
                }
                
                if seenNumbers.contains(normalized) {
                    continue
                }
                
                seenNumbers.insert(normalized)
                
                contactsPayload.append([
                    "uid": uid,
                    "mobile_no": phoneNumber,
                    "contact_name": displayName,
                    "contact_number": normalized
                ])
                
                if contactsPayload.count >= 10_000 {
                    stop.pointee = true
                    break
                }
            }
        }
        
        let payload: [String: Any] = ["contact": contactsPayload]
        guard JSONSerialization.isValidJSONObject(payload) else {
            throw SyncError.failedToCreateFile
        }
        
        return try JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
    }
    
    private func write(jsonData: Data, fileName: String) throws -> URL {
        guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw SyncError.failedToCreateFile
        }
        
        let fileURL = cacheDir.appendingPathComponent(fileName)
        do {
            try jsonData.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            throw SyncError.failedToCreateFile
        }
    }
    
    private func normalizeNumber(_ value: String, countryCode: String) -> String? {
        let digits = value.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        guard !digits.isEmpty else { return nil }
        
        var cleaned = digits.filter { "0123456789".contains($0) }
        while cleaned.hasPrefix("0") && cleaned.count > 1 {
            cleaned.removeFirst()
        }
        
        let countryDigits = countryCode.filter { "0123456789".contains($0) }
        if !countryDigits.isEmpty && !cleaned.hasPrefix(countryDigits) {
            cleaned = countryDigits + cleaned
        }
        
        // Return with leading + for international format (e.g. +911800407267864)
        return cleaned.isEmpty ? nil : "+" + cleaned
    }
}


