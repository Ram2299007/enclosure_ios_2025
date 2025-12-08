//
//  NewGroupViewModel.swift
//  Enclosure
//
//  Created by Ram Lohar on 30/04/25.
//

import Foundation
import SwiftUI

final class NewGroupViewModel: ObservableObject {
    @Published var contacts: [UserActiveContactModel] = []
    @Published var selectedContactIds: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasCachedContacts = false
    @Published var groupName = ""
    @Published var selectedImage: UIImage?
    @Published var compressedImageFile: URL?
    @Published var fullImageFile: URL?
    
    private let cacheManager = ChatCacheManager.shared
    private let networkMonitor = NetworkMonitor.shared
    
    var selectedCount: Int {
        selectedContactIds.count
    }
    
    var invitedFriendListJSON: String {
        guard !selectedContactIds.isEmpty else { return "NODATA" }
        
        let jsonArray = selectedContactIds.map { uid in
            ["friend_id": uid]
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonArray),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "NODATA"
        }
        
        return jsonString
    }
    
    func fetchContacts(uid: String) {
        guard !uid.isEmpty else {
            errorMessage = "Missing user id"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        loadCachedContacts(reason: .prefetch, shouldStopLoading: false)
        
        guard networkMonitor.isConnected else {
            loadCachedContacts(reason: .offline)
            return
        }
        
        ApiService.get_user_active_chat_list(uid: uid) { success, message, data in
            DispatchQueue.main.async {
                self.isLoading = false
                if success {
                    let fetchedList = data ?? []
                    // Filter out current user (similar to Android)
                    let filtered = fetchedList.filter { contact in
                        contact.uid != uid
                    }
                    self.contacts = filtered
                    self.hasCachedContacts = !filtered.isEmpty
                    self.errorMessage = nil
                } else {
                    if !self.hasCachedContacts {
                        self.loadCachedContacts(reason: .error(message))
                    } else {
                        self.errorMessage = message.isEmpty ? "Something went wrong." : message
                    }
                }
            }
        }
    }
    
    private func loadCachedContacts(reason: ContactCacheReason, shouldStopLoading: Bool = true) {
        // For now, we'll use the same cache as chat list
        // You may need to implement a specific cache for group contacts
        cacheManager.fetchChats { [weak self] (cachedContacts: [UserActiveContactModel]) in
            guard let self = self else { return }
            
            // Ensure all @Published property updates happen on main thread
            DispatchQueue.main.async {
                if cachedContacts.isEmpty && reason == .prefetch {
                    if shouldStopLoading {
                        self.isLoading = false
                    }
                    return
                }
                
                // Filter out current user
                let uid = Constant.SenderIdMy
                let filtered = cachedContacts.filter { $0.uid != uid }
                self.contacts = filtered
                self.hasCachedContacts = !filtered.isEmpty
                
                if shouldStopLoading {
                    self.isLoading = false
                }
                
                switch reason {
                case .offline:
                    self.errorMessage = filtered.isEmpty ? "You are offline. No cached contacts available." : nil
                case .prefetch:
                    break
                case .error(let message):
                    if filtered.isEmpty {
                        self.errorMessage = message?.isEmpty == false ? message : "Unable to load contacts."
                    } else {
                        self.errorMessage = nil
                    }
                }
            }
        }
    }
    
    func toggleContactSelection(_ uid: String) {
        if selectedContactIds.contains(uid) {
            selectedContactIds.remove(uid)
        } else {
            selectedContactIds.insert(uid)
        }
    }
    
    func isContactSelected(_ uid: String) -> Bool {
        selectedContactIds.contains(uid)
    }
    
    func createGroup(uid: String, completion: @escaping (Bool, String) -> Void) {
        guard !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion(false, "Missing group name")
            return
        }
        
        guard invitedFriendListJSON != "NODATA" else {
            completion(false, "Please add contacts to create group")
            return
        }
        
        // Determine which image file to use (compressed if > 200KB, otherwise full)
        var imageFileToUse: URL?
        
        if let compressedFile = compressedImageFile, let fullFile = fullImageFile {
            let compressedSize = getFileSize(filePath: compressedFile.path)
            if compressedSize > 200 * 1024 {
                imageFileToUse = compressedFile
            } else {
                imageFileToUse = fullFile
            }
        } else if let compressedFile = compressedImageFile {
            imageFileToUse = compressedFile
        } else if let fullFile = fullImageFile {
            imageFileToUse = fullFile
        }
        
        ApiService.create_group_for_chatting(
            uid: uid,
            groupName: groupName.trimmingCharacters(in: .whitespacesAndNewlines),
            invitedFriendList: invitedFriendListJSON,
            groupIcon: imageFileToUse
        ) { success, message in
            DispatchQueue.main.async {
                if success {
                    // Clean up image files
                    self.cleanupImageFiles()
                }
                completion(success, message)
            }
        }
    }
    
    private func getFileSize(filePath: String) -> Int64 {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: filePath),
              let fileSize = attributes[.size] as? Int64 else {
            return 0
        }
        return fileSize
    }
    
    func cleanupImageFiles() {
        if let compressedFile = compressedImageFile {
            try? FileManager.default.removeItem(at: compressedFile)
        }
        if let fullFile = fullImageFile {
            try? FileManager.default.removeItem(at: fullFile)
        }
        compressedImageFile = nil
        fullImageFile = nil
        selectedImage = nil
    }
    
    func processSelectedImage(_ image: UIImage) {
        selectedImage = image
        
        // Create compressed version (20% quality)
        if let compressedData = image.jpegData(compressionQuality: 0.2) {
            let tempDir = FileManager.default.temporaryDirectory
            let compressedURL = tempDir.appendingPathComponent("temp_compressed_\(UUID().uuidString).jpg")
            
            do {
                try compressedData.write(to: compressedURL)
                compressedImageFile = compressedURL
            } catch {
                print("Error saving compressed image: \(error)")
            }
        }
        
        // Create full version (80% quality)
        if let fullData = image.jpegData(compressionQuality: 0.8) {
            let tempDir = FileManager.default.temporaryDirectory
            let fullURL = tempDir.appendingPathComponent("temp_full_\(UUID().uuidString).jpg")
            
            do {
                try fullData.write(to: fullURL)
                fullImageFile = fullURL
            } catch {
                print("Error saving full image: \(error)")
            }
        }
    }
}

private enum ContactCacheReason: CustomStringConvertible, Equatable {
    case prefetch
    case offline
    case error(String?)
    
    var description: String {
        switch self {
        case .prefetch:
            return "prefetch"
        case .offline:
            return "offline"
        case .error(let message):
            return "error(\(message ?? "nil"))"
        }
    }
}

