//
//  SharedContentHandler.swift
//  Enclosure
//
//  Created by Ram Lohar on 30/04/25.
//

import SwiftUI
import UniformTypeIdentifiers
import Contacts

class SharedContentHandler: ObservableObject {
    static let shared = SharedContentHandler()
    
    @Published var pendingSharedContent: SharedContent?
    @Published var shouldShowShareScreen: Bool = false
    
    private init() {}
    
    // Handle shared content from Share Extension or URL scheme
    func handleSharedContent(_ content: SharedContent) {
        pendingSharedContent = content
        shouldShowShareScreen = true
    }
    
    // Process shared items from NSExtensionContext (for Share Extension)
    func processSharedItems(_ items: [NSExtensionItem], completion: @escaping (SharedContent?) -> Void) {
        var imageUrls: [URL] = []
        var videoUrls: [URL] = []
        var documentUrl: URL?
        var documentName: String?
        var documentSize: String?
        var textData: String?
        var contactInfo: SharedContent.ContactInfo?
        
        let group = DispatchGroup()
        
        for item in items {
            // Handle text
            if let text = item.attributedContentText?.string, !text.isEmpty {
                textData = text
            }
            
            // Handle attachments
            if let attachments = item.attachments {
                for attachment in attachments {
                    group.enter()
                    
                    if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                        attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { (data, error) in
                            defer { group.leave() }
                            
                            if let url = data as? URL {
                                imageUrls.append(url)
                            } else if let imageData = data as? Data, let image = UIImage(data: imageData) {
                                // Save to temp file
                                if let tempUrl = self.saveImageToTemp(image) {
                                    imageUrls.append(tempUrl)
                                }
                            }
                        }
                    } else if attachment.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                        attachment.loadItem(forTypeIdentifier: UTType.movie.identifier, options: nil) { (data, error) in
                            defer { group.leave() }
                            
                            if let url = data as? URL {
                                videoUrls.append(url)
                            }
                        }
                    } else if attachment.hasItemConformingToTypeIdentifier(UTType.vCard.identifier) {
                        attachment.loadItem(forTypeIdentifier: UTType.vCard.identifier, options: nil) { (data, error) in
                            defer { group.leave() }
                            
                            if let url = data as? URL {
                                contactInfo = self.parseContactFromVCard(url: url)
                            } else if let vCardData = data as? Data {
                                contactInfo = self.parseContactFromVCardData(vCardData)
                            }
                        }
                    } else if attachment.hasItemConformingToTypeIdentifier(UTType.item.identifier) {
                        attachment.loadItem(forTypeIdentifier: UTType.item.identifier, options: nil) { (data, error) in
                            defer { group.leave() }
                            
                            if let url = data as? URL {
                                documentUrl = url
                                documentName = url.lastPathComponent
                                documentSize = self.getFileSize(url: url)
                            }
                        }
                    } else {
                        group.leave()
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            // Create SharedContent with determined type
            var sharedContent: SharedContent
            
            // Determine content type and create appropriate SharedContent
            if !imageUrls.isEmpty {
                sharedContent = SharedContent(type: .image)
                sharedContent.imageUrls = imageUrls
            } else if !videoUrls.isEmpty {
                sharedContent = SharedContent(type: .video)
                sharedContent.videoUrls = videoUrls
            } else if let contact = contactInfo {
                sharedContent = SharedContent(type: .contact)
                sharedContent.contact = contact
            } else if documentUrl != nil {
                sharedContent = SharedContent(type: .document)
                sharedContent.documentUrl = documentUrl
                sharedContent.documentName = documentName
                sharedContent.documentSize = documentSize
            } else {
                // Default to text
                sharedContent = SharedContent(type: .text)
                sharedContent.textData = textData
            }
            
            // Set text data if available (for captions)
            if let text = textData {
                sharedContent.textData = text
            }
            
            completion(sharedContent)
        }
    }
    
    // MARK: - Helper Functions
    private func saveImageToTemp(_ image: UIImage) -> URL? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = UUID().uuidString + ".jpg"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("🚫 Error saving image to temp: \(error)")
            return nil
        }
    }
    
    private func parseContactFromVCard(url: URL) -> SharedContent.ContactInfo? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return parseContactFromVCardData(data)
    }
    
    private func parseContactFromVCardData(_ data: Data) -> SharedContent.ContactInfo? {
        guard let vCardString = String(data: data, encoding: .utf8) else { return nil }
        
        var name = ""
        var phone = ""
        var email = ""
        
        let lines = vCardString.components(separatedBy: .newlines)
        for line in lines {
            if line.hasPrefix("FN:") {
                name = String(line.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if line.hasPrefix("TEL") {
                let components = line.components(separatedBy: ":")
                if components.count > 1 {
                    phone = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } else if line.hasPrefix("EMAIL") {
                let components = line.components(separatedBy: ":")
                if components.count > 1 {
                    email = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        guard !name.isEmpty else { return nil }
        return SharedContent.ContactInfo(name: name, phoneNumber: phone, email: email.isEmpty ? nil : email)
    }
    
    private func getFileSize(url: URL) -> String {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return "Unknown"
        }
        
        return formatFileSize(size)
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
