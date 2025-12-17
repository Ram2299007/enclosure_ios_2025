//
//  LocalStorageHelper.swift
//  Enclosure
//
//  Created for debugging local storage
//

import Foundation
import UIKit

/// Helper class to check and manage local storage for images
class LocalStorageHelper {
    
    /// Get local images directory path
    static func getLocalImagesDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagesDir = documentsPath.appendingPathComponent("Enclosure/Media/Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true, attributes: nil)
        return imagesDir
    }
    
    /// List all saved images in local storage
    static func listSavedImages() {
        let imagesDir = getLocalImagesDirectory()
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: imagesDir, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey])
            
            print("\n📱 [LOCAL_STORAGE] ===== Saved Images List =====")
            print("📱 [LOCAL_STORAGE] Directory: \(imagesDir.path)")
            print("📱 [LOCAL_STORAGE] Total files: \(files.count)\n")
            
            if files.isEmpty {
                print("📱 [LOCAL_STORAGE] No images found in local storage")
            } else {
                for (index, file) in files.enumerated() {
                    let fileName = file.lastPathComponent
                    let fileSize = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                    let creationDate = (try? file.resourceValues(forKeys: [.creationDateKey]))?.creationDate
                    let modificationDate = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                    
                    print("📱 [LOCAL_STORAGE] \(index + 1). \(fileName)")
                    print("   📏 Size: \(fileSize) bytes (\(String(format: "%.2f", Double(fileSize) / 1024.0)) KB)")
                    if let date = creationDate {
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        formatter.timeStyle = .short
                        print("   📅 Created: \(formatter.string(from: date))")
                    }
                    if let date = modificationDate {
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        formatter.timeStyle = .short
                        print("   🔄 Modified: \(formatter.string(from: date))")
                    }
                    print("")
                }
            }
            print("📱 [LOCAL_STORAGE] ==============================\n")
        } catch {
            print("❌ [LOCAL_STORAGE] Error listing images: \(error.localizedDescription)")
        }
    }
    
    /// Get total size of all saved images
    static func getTotalStorageSize() -> Int64 {
        let imagesDir = getLocalImagesDirectory()
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: imagesDir, includingPropertiesForKeys: [.fileSizeKey])
            var totalSize: Int64 = 0
            
            for file in files {
                if let fileSize = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                    totalSize += Int64(fileSize)
                }
            }
            
            return totalSize
        } catch {
            return 0
        }
    }
    
    /// Check if a specific image exists locally
    static func imageExists(fileName: String) -> Bool {
        let imagesDir = getLocalImagesDirectory()
        let fileURL = imagesDir.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    /// Get file path for a specific image
    static func getImagePath(fileName: String) -> String? {
        let imagesDir = getLocalImagesDirectory()
        let fileURL = imagesDir.appendingPathComponent(fileName)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL.path
        }
        
        return nil
    }
    
    /// Get full path to images directory
    static func getFullPath() -> String {
        let imagesDir = getLocalImagesDirectory()
        return imagesDir.path
    }
    
    /// Print directory path for manual checking
    static func printDirectoryPath() {
        let imagesDir = getLocalImagesDirectory()
        let fullPath = imagesDir.path
        
        print("\n")
        print("═══════════════════════════════════════════════════════════")
        print("📱 [LOCAL_STORAGE] FULL PATH TO IMAGES DIRECTORY")
        print("═══════════════════════════════════════════════════════════")
        print("")
        print("📍 \(fullPath)")
        print("")
        print("═══════════════════════════════════════════════════════════")
        
        #if targetEnvironment(simulator)
        // Extract APP_ID and DEVICE_ID from the path
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
        print("💡 TO ACCESS IN FINDER:")
        print("   1. Press Cmd + Shift + G")
        print("   2. Paste the path above")
        print("   3. Press Enter")
        print("")
        #else
        print("📱 Running on physical device")
        print("💡 Use Xcode → Window → Devices → Select Device → Open Container")
        print("")
        #endif
        print("═══════════════════════════════════════════════════════════")
        print("")
    }
    
    /// Get APP_ID (for simulator)
    static func getAppId() -> String? {
        #if targetEnvironment(simulator)
        let imagesDir = getLocalImagesDirectory()
        let pathComponents = imagesDir.path.components(separatedBy: "/")
        if let appIdIndex = pathComponents.firstIndex(of: "Application"),
           appIdIndex + 1 < pathComponents.count {
            return pathComponents[appIdIndex + 1]
        }
        #endif
        return nil
    }
    
    /// Get DEVICE_ID (for simulator)
    static func getDeviceId() -> String? {
        #if targetEnvironment(simulator)
        let imagesDir = getLocalImagesDirectory()
        let pathComponents = imagesDir.path.components(separatedBy: "/")
        if let deviceIdIndex = pathComponents.firstIndex(of: "Devices"),
           deviceIdIndex + 1 < pathComponents.count {
            return pathComponents[deviceIdIndex + 1]
        }
        #endif
        return nil
    }
    
    /// Delete all saved images (use with caution!)
    static func deleteAllImages() {
        let imagesDir = getLocalImagesDirectory()
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: imagesDir, includingPropertiesForKeys: nil)
            
            for file in files {
                try FileManager.default.removeItem(at: file)
            }
            
            print("✅ [LOCAL_STORAGE] Deleted \(files.count) images")
        } catch {
            print("❌ [LOCAL_STORAGE] Error deleting images: \(error.localizedDescription)")
        }
    }
}

