//
//  PhotosLibraryHelper.swift
//  Enclosure
//
//  Created for managing public Photos library access (equivalent to Android DIRECTORY_PICTURES/Enclosure)
//

import Foundation
import Photos
import UIKit

class PhotosLibraryHelper {
    static let shared = PhotosLibraryHelper()
    
    private init() {}
    
    // Check if image exists in Photos library (matching Android public directory check)
    // Note: iOS Photos library doesn't preserve filenames, so we use cache as primary check
    func imageExistsInPhotosLibrary(fileName: String) -> Bool {
        // Primary check: use cache (more reliable since iOS doesn't preserve filenames in Photos)
        if fileExistsInCache(fileName: fileName) {
            return true
        }
        
        // Secondary check: try to find by filename (may not work if filename was changed)
        let fetchOptions = PHFetchOptions()
        // Note: PHAsset doesn't have a direct filename property, so this check is limited
        // We rely primarily on the cache
        return false
    }
    
    // Save image to Photos library (public directory equivalent)
    func saveImageToPhotosLibrary(imageData: Data, fileName: String, completion: @escaping (Bool, Error?) -> Void) {
        guard let image = UIImage(data: imageData) else {
            completion(false, NSError(domain: "PhotosLibraryHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create image from data"]))
            return
        }
        
        // Request photo library access
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    completion(false, NSError(domain: "PhotosLibraryHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "Photo library access denied"]))
                }
                return
            }
            
            // Save to Photos library
            PHPhotoLibrary.shared().performChanges({
                // Create asset creation request
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo, data: imageData, options: nil)
                
                // Set filename if possible (iOS doesn't directly support custom filenames in Photos)
                // The asset will be saved with a system-generated name
            }, completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success {
                        print("📱 [PhotosLibraryHelper] ✅ Image saved to Photos library: \(fileName)")
                    } else {
                        print("❌ [PhotosLibraryHelper] Failed to save image: \(error?.localizedDescription ?? "Unknown error")")
                    }
                    completion(success, error)
                }
            })
        }
    }
    
    // Save video to Photos library (public directory equivalent)
    func saveVideoToPhotosLibrary(videoData: Data, fileName: String, completion: @escaping (Bool, Error?) -> Void) {
        // Request photo library access
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    completion(false, NSError(domain: "PhotosLibraryHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "Photo library access denied"]))
                }
                return
            }
            
            // Save video data to temporary file first
            let tempDir = FileManager.default.temporaryDirectory
            let tempFile = tempDir.appendingPathComponent(fileName)
            
            do {
                // Write video data to temp file
                try videoData.write(to: tempFile, options: .atomic)
                
                // Save to Photos library
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: tempFile)
                }, completionHandler: { success, error in
                    // Clean up temp file
                    try? FileManager.default.removeItem(at: tempFile)
                    
                    DispatchQueue.main.async {
                        if success {
                            // Save to cache to track
                            PhotosLibraryHelper.shared.saveToCache(fileName: fileName, imageData: videoData)
                            print("📱 [PhotosLibraryHelper] ✅ Video saved to Photos library: \(fileName)")
                        } else {
                            print("❌ [PhotosLibraryHelper] Failed to save video: \(error?.localizedDescription ?? "Unknown error")")
                        }
                        completion(success, error)
                    }
                })
            } catch {
                DispatchQueue.main.async {
                    completion(false, error)
                }
            }
        }
    }
    
    // Get local file path for checking (we'll use a combination of Photos check + local cache)
    // Since iOS Photos library doesn't expose file paths directly, we maintain a local cache
    func getLocalCachePath(fileName: String) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cacheDir = documentsPath.appendingPathComponent("Enclosure/Media/PhotosCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true, attributes: nil)
        return cacheDir.appendingPathComponent(fileName)
    }
    
    // Check if file exists in local cache (used as a proxy for Photos library existence)
    func fileExistsInCache(fileName: String) -> Bool {
        let cachePath = getLocalCachePath(fileName: fileName)
        return FileManager.default.fileExists(atPath: cachePath.path)
    }
    
    // Save to local cache (to track which files have been saved to Photos)
    func saveToCache(fileName: String, imageData: Data) {
        let cachePath = getLocalCachePath(fileName: fileName)
        try? imageData.write(to: cachePath, options: .atomic)
        print("📱 [PhotosLibraryHelper] Saved to cache: \(cachePath.path)")
    }
    
    // Get full cache directory path (for debugging - equivalent to Android public directory)
    func getFullCachePath() -> String {
        let cacheDir = getLocalCachePath(fileName: "")
        return cacheDir.deletingLastPathComponent().path
    }
    
    // Print full path information (for debugging)
    func printPublicDirectoryPath() {
        let cacheDir = getLocalCachePath(fileName: "")
        let fullPath = cacheDir.deletingLastPathComponent().path
        
        print("")
        print("═══════════════════════════════════════════════════════════")
        print("📱 [PUBLIC_DIRECTORY] RECEIVER IMAGES PATH (iOS)")
        print("═══════════════════════════════════════════════════════════")
        print("")
        print("📍 CACHE DIRECTORY (for tracking saved files):")
        print("   \(fullPath)")
        print("")
        print("📸 ACTUAL STORAGE LOCATION:")
        print("   Photos Library (Public) - Accessible via Photos app")
        print("   Note: iOS Photos library doesn't expose direct file paths")
        print("   Files are saved to the system Photos app")
        print("")
        print("💡 TO ACCESS IN FINDER (Cache Directory):")
        print("   1. Press Cmd + Shift + G")
        print("   2. Paste: \(fullPath)")
        print("   3. Press Enter")
        print("")
        print("💡 TO ACCESS IN PHOTOS APP:")
        print("   1. Open Photos app on your device")
        print("   2. Navigate to 'All Photos' or 'Recents'")
        print("   3. Images saved from receiver messages will appear there")
        print("")
        #if targetEnvironment(simulator)
        // Extract and print APP_ID and DEVICE_ID for easy access
        let pathComponents = fullPath.components(separatedBy: "/")
        if let appIdIndex = pathComponents.firstIndex(of: "Application"),
           appIdIndex + 1 < pathComponents.count {
            let appId = pathComponents[appIdIndex + 1]
            print("📱 APP_ID: \(appId)")
        }
        if let deviceIdIndex = pathComponents.firstIndex(of: "Devices"),
           deviceIdIndex + 1 < pathComponents.count {
            let deviceId = pathComponents[deviceIdIndex + 1]
            print("📱 DEVICE_ID: \(deviceId)")
        }
        print("")
        #endif
        print("═══════════════════════════════════════════════════════════")
        print("")
    }
    
    // List all saved images in cache (for debugging)
    func listSavedImagesInCache() {
        let cacheDir = getLocalCachePath(fileName: "")
        let fullPath = cacheDir.deletingLastPathComponent()
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: fullPath, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])
            
            print("📱 [PUBLIC_DIRECTORY] ===== Saved Images in Cache =====")
            print("📱 [PUBLIC_DIRECTORY] Cache Directory: \(fullPath.path)")
            print("📱 [PUBLIC_DIRECTORY] Total files: \(files.count)")
            print("")
            
            for (index, file) in files.enumerated() {
                let fileName = file.lastPathComponent
                let fileSize = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                let creationDate = (try? file.resourceValues(forKeys: [.creationDateKey]))?.creationDate
                
                print("📱 [PUBLIC_DIRECTORY] \(index + 1). \(fileName)")
                print("   Size: \(fileSize) bytes (\(fileSize / 1024) KB)")
                if let date = creationDate {
                    print("   Created: \(date)")
                }
            }
            print("📱 [PUBLIC_DIRECTORY] ==============================")
            print("")
        } catch {
            print("❌ [PUBLIC_DIRECTORY] Error listing images: \(error.localizedDescription)")
        }
    }
}

