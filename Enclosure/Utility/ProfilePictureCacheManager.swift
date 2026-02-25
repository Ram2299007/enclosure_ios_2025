//
//  ProfilePictureCacheManager.swift
//  Enclosure
//
//  Manages local caching of profile pictures for Communication Notifications
//  Downloads and caches profile images so they're available for INPerson
//

import Foundation
import UIKit
import CryptoKit

/// Manages profile picture caching for Communication Notifications
/// Downloads profile images in background and caches them locally for use in INPerson
final class ProfilePictureCacheManager {
    static let shared = ProfilePictureCacheManager()
    
    private let cacheDirectory: URL
    private let fileManager = FileManager.default
    
    private init() {
        // Use App Group shared container so both main app and Notification Service Extension
        // can access the same cached profile pictures (fixes profile pics not showing in notifications)
        let sharedContainer = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.com.enclosure.data")
        let baseDir = sharedContainer ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = baseDir.appendingPathComponent("ProfilePictures", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    /// Gets cached profile image path for a sender
    /// If not cached, downloads in background and returns nil (notification will show without image initially)
    /// - Parameters:
    ///   - photoUrl: Remote URL of the profile picture
    ///   - senderUid: Unique identifier for the sender (used as cache key)
    ///   - completion: Callback with local file path if available, nil if downloading
    func getCachedProfileImage(
        photoUrl: String,
        senderUid: String,
        completion: @escaping (String?) -> Void
    ) {
        guard !photoUrl.isEmpty, let url = URL(string: photoUrl) else {
            print("⚠️ [PROFILE_CACHE] Invalid photo URL: \(photoUrl)")
            completion(nil)
            return
        }
        
        // Check LocalImageCache first (used by CachedAsyncImage)
        if let cachedImage = LocalImageCache.shared.image(for: url) {
            // Save to notification cache directory for direct file access
            let localPath = cachePath(for: senderUid, url: url)
            if let imageData = cachedImage.jpegData(compressionQuality: 0.9) {
                try? imageData.write(to: localPath)
                print("✅ [PROFILE_CACHE] Found in LocalImageCache, saved to notification cache")
                completion(localPath.path)
                return
            }
        }
        
        // Check notification cache directory
        let localPath = cachePath(for: senderUid, url: url)
        if fileManager.fileExists(atPath: localPath.path) {
            print("✅ [PROFILE_CACHE] Found cached profile image: \(localPath.path)")
            completion(localPath.path)
            return
        }
        
        // Not cached - download in background (don't block notification)
        print("📥 [PROFILE_CACHE] Downloading profile image: \(photoUrl)")
        downloadAndCacheProfileImage(url: url, senderUid: senderUid, localPath: localPath)
        
        // Return nil immediately so notification shows without delay
        // Image will be cached for next notification
        completion(nil)
    }
    
    /// Downloads profile image and caches it locally
    private func downloadAndCacheProfileImage(url: URL, senderUid: String, localPath: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("🚫 [PROFILE_CACHE] Download failed: \(error.localizedDescription)")
                return
            }
            
            guard let data = data, let image = UIImage(data: data) else {
                print("🚫 [PROFILE_CACHE] Invalid image data")
                return
            }
            
            // Save to notification cache
            do {
                // Create directory if needed
                try self.fileManager.createDirectory(
                    at: localPath.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                
                // Save image
                if let jpegData = image.jpegData(compressionQuality: 0.9) {
                    try jpegData.write(to: localPath, options: .atomic)
                    print("✅ [PROFILE_CACHE] Cached profile image: \(localPath.path)")
                    
                    // Also save to LocalImageCache for consistency
                    LocalImageCache.shared.save(image: image, for: url)
                }
            } catch {
                print("🚫 [PROFILE_CACHE] Failed to save image: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    /// Gets cache file path for a sender's profile picture
    private func cachePath(for senderUid: String, url: URL) -> URL {
        // Use senderUid as primary identifier, URL hash as fallback
        let fileName: String
        if !senderUid.isEmpty && senderUid != "unknown" {
            fileName = "\(senderUid).jpg"
        } else {
            // Fallback to URL hash
            let data = Data(url.absoluteString.utf8)
            let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            fileName = "\(hash).jpg"
        }
        
        return cacheDirectory.appendingPathComponent(fileName)
    }
    
    /// Pre-caches profile picture for a sender (call when user opens chat)
    /// This ensures image is ready for notifications
    func preCacheProfileImage(photoUrl: String, senderUid: String) {
        guard !photoUrl.isEmpty, let url = URL(string: photoUrl) else { return }
        
        let localPath = cachePath(for: senderUid, url: url)
        
        // Skip if already cached
        if fileManager.fileExists(atPath: localPath.path) {
            return
        }
        
        // Download and cache
        downloadAndCacheProfileImage(url: url, senderUid: senderUid, localPath: localPath)
    }
    
    /// Clears all cached profile pictures (useful for debugging or storage management)
    func clearCache() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        print("✅ [PROFILE_CACHE] Cache cleared")
    }
}
