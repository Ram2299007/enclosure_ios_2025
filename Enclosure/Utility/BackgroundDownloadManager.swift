//
//  BackgroundDownloadManager.swift
//  Enclosure
//
//  Created for background image downloads with notifications
//

import Foundation
import UIKit
import UserNotifications
import FirebaseStorage
import Photos

class BackgroundDownloadManager: NSObject {
    static let shared = BackgroundDownloadManager()
    
    private var activeDownloads: [String: Any] = [:] // Can hold both StorageDownloadTask and URLSessionDownloadTask
    private var downloadProgress: [String: Double] = [:]
    private var downloadNotifications: [String: String] = [:] // fileName -> notificationId
    private var progressObservations: [String: NSKeyValueObservation] = [:] // Retain KVO observations for HTTP downloads
    
    private override init() {
        super.init()
        requestNotificationPermission()
    }
    
    // Request notification permission
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                print("📱 [BackgroundDownload] Notification permission granted")
            } else {
                print("📱 [BackgroundDownload] Notification permission denied")
            }
        }
    }
    
    // Check if file is a video based on extension
    private func isVideoFile(fileName: String) -> Bool {
        let videoExtensions = ["mp4", "mov", "avi", "m4v", "mkv", "3gp", "webm"]
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        return videoExtensions.contains(fileExtension)
    }
    
    // Download image with background support and notifications
    func downloadImage(
        imageUrl: String,
        fileName: String,
        destinationFile: URL,
        onProgress: ((Double) -> Void)? = nil,
        onSuccess: (() -> Void)? = nil,
        onFailure: ((Error) -> Void)? = nil
    ) {
        // Check if already downloading
        if activeDownloads[fileName] != nil {
            print("📱 [BackgroundDownload] Already downloading: \(fileName)")
            return
        }
        
        // Check if file already exists
        if FileManager.default.fileExists(atPath: destinationFile.path) {
            print("📱 [BackgroundDownload] File already exists: \(fileName)")
            onSuccess?()
            return
        }
        
        // Show initial notification
        showDownloadNotification(fileName: fileName, progress: 0, isComplete: false)
        
        // Download using Firebase Storage or HTTP
        if imageUrl.hasPrefix("gs://") {
            // Firebase Storage download
            downloadFromFirebaseStorage(
                imageUrl: imageUrl,
                fileName: fileName,
                destinationFile: destinationFile,
                onProgress: onProgress,
                onSuccess: onSuccess,
                onFailure: onFailure
            )
        } else {
            // HTTP/HTTPS download
            downloadViaHTTP(
                imageUrl: imageUrl,
                fileName: fileName,
                destinationFile: destinationFile,
                onProgress: onProgress,
                onSuccess: onSuccess,
                onFailure: onFailure
            )
        }
    }
    
    // Download from Firebase Storage
    private func downloadFromFirebaseStorage(
        imageUrl: String,
        fileName: String,
        destinationFile: URL,
        onProgress: ((Double) -> Void)?,
        onSuccess: (() -> Void)?,
        onFailure: ((Error) -> Void)?
    ) {
        let storageRef = Storage.storage().reference(forURL: imageUrl)
        let downloadTask = storageRef.write(toFile: destinationFile)
        
        // Store task (write(toFile:) returns StorageDownloadTask which is a subclass of StorageTask)
        activeDownloads[fileName] = downloadTask
        
        // Track progress
        _ = downloadTask.observe(.progress) { snapshot in
            guard let progress = snapshot.progress else { return }
            let totalBytes = Double(progress.totalUnitCount)
            let downloadedBytes = Double(progress.completedUnitCount)
            
            if totalBytes > 0 {
                let progressPercent = (downloadedBytes / totalBytes) * 100.0
                self.downloadProgress[fileName] = progressPercent
                
                // Update notification
                self.showDownloadNotification(fileName: fileName, progress: progressPercent, isComplete: false)
                
                // Call progress callback
                DispatchQueue.main.async {
                    onProgress?(progressPercent)
                }
            }
        }
        
        // Handle success
        downloadTask.observe(.success) { _ in
            self.activeDownloads.removeValue(forKey: fileName)
            self.downloadProgress.removeValue(forKey: fileName)
            
            // Remove notification when download completes
            if let notificationId = self.downloadNotifications[fileName] {
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationId])
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId])
                self.downloadNotifications.removeValue(forKey: fileName)
                print("📱 [BackgroundDownload] Removed notification for completed download: \(fileName)")
            }
            
            DispatchQueue.main.async {
                onSuccess?()
            }
        }
        
        // Handle failure
        downloadTask.observe(.failure) { snapshot in
            self.activeDownloads.removeValue(forKey: fileName)
            self.downloadProgress.removeValue(forKey: fileName)
            
            let error = snapshot.error ?? NSError(domain: "DownloadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
            
            // Show error notification
            self.showErrorNotification(fileName: fileName, error: error)
            
            // Remove notification ID after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.downloadNotifications.removeValue(forKey: fileName)
            }
            
            DispatchQueue.main.async {
                onFailure?(error)
            }
        }
    }
    
    // Download via HTTP/HTTPS
    private func downloadViaHTTP(
        imageUrl: String,
        fileName: String,
        destinationFile: URL,
        onProgress: ((Double) -> Void)?,
        onSuccess: (() -> Void)?,
        onFailure: ((Error) -> Void)?
    ) {
        guard let url = URL(string: imageUrl) else {
            let error = NSError(domain: "DownloadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            DispatchQueue.main.async {
                onFailure?(error)
            }
            return
        }
        
        // Create download task
        let task = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            if let error = error {
                self.activeDownloads.removeValue(forKey: fileName)
                self.downloadProgress.removeValue(forKey: fileName)
                self.progressObservations.removeValue(forKey: fileName)
                
                // Remove progress notification
                if let notificationId = self.downloadNotifications[fileName] {
                    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationId])
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId])
                }
                
                // Show error notification
                self.showErrorNotification(fileName: fileName, error: error)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.downloadNotifications.removeValue(forKey: fileName)
                }
                
                DispatchQueue.main.async {
                    onFailure?(error)
                }
                return
            }
            
            guard let tempURL = tempURL else {
                let error = NSError(domain: "DownloadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                self.activeDownloads.removeValue(forKey: fileName)
                self.downloadProgress.removeValue(forKey: fileName)
                self.progressObservations.removeValue(forKey: fileName)
                
                // Remove progress notification
                if let notificationId = self.downloadNotifications[fileName] {
                    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationId])
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId])
                }
                
                // Show error notification
                self.showErrorNotification(fileName: fileName, error: error)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.downloadNotifications.removeValue(forKey: fileName)
                }
                
                DispatchQueue.main.async {
                    onFailure?(error)
                }
                return
            }
            
            // Move file to destination
            do {
                // Remove existing file if any
                if FileManager.default.fileExists(atPath: destinationFile.path) {
                    try FileManager.default.removeItem(at: destinationFile)
                }
                
                // Create directory if needed
                try FileManager.default.createDirectory(at: destinationFile.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                
                // Move file
                try FileManager.default.moveItem(at: tempURL, to: destinationFile)
                
                self.activeDownloads.removeValue(forKey: fileName)
                self.downloadProgress.removeValue(forKey: fileName)
                self.progressObservations.removeValue(forKey: fileName)
                
                // Remove notification when download completes
                if let notificationId = self.downloadNotifications[fileName] {
                    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationId])
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId])
                    self.downloadNotifications.removeValue(forKey: fileName)
                    print("📱 [BackgroundDownload] Removed notification for completed download: \(fileName)")
                }
                
                DispatchQueue.main.async {
                    onSuccess?()
                }
            } catch {
                self.activeDownloads.removeValue(forKey: fileName)
                self.downloadProgress.removeValue(forKey: fileName)
                self.progressObservations.removeValue(forKey: fileName)
                
                self.showErrorNotification(fileName: fileName, error: error)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.downloadNotifications.removeValue(forKey: fileName)
                }
                
                DispatchQueue.main.async {
                    onFailure?(error)
                }
            }
        }
        
        // Store task
        activeDownloads[fileName] = task
        
        // Track progress - store observation to keep it alive
        let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
            let progressPercent = progress.fractionCompleted * 100.0
            self.downloadProgress[fileName] = progressPercent
            
            // Update notification
            self.showDownloadNotification(fileName: fileName, progress: progressPercent, isComplete: false)
            
            // Call progress callback
            DispatchQueue.main.async {
                onProgress?(progressPercent)
            }
        }
        
        // Retain observation so KVO keeps firing
        progressObservations[fileName] = observation
        
        // Start download
        task.resume()
    }
    
    // Show download notification (silent/background notification - only visible in notification center)
    private func showDownloadNotification(fileName: String, progress: Double, isComplete: Bool) {
        let content = UNMutableNotificationContent()
        
        if isComplete {
            content.title = "Download Complete"
            content.body = "\(fileName) downloaded successfully"
            content.sound = nil // No sound for silent notification
        } else {
            content.title = "Downloading Image"
            content.body = "\(fileName) - \(Int(progress))%"
            content.sound = nil // No sound during progress updates
        }
        
        // Set interruption level to passive (silent notification - only shows in notification center)
        // This makes it like Android's lower priority notification
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .passive
        }
        
        // Set category identifier for silent notification
        content.categoryIdentifier = "DOWNLOAD_PROGRESS"
        
        // Use notification ID for updating
        let notificationId = downloadNotifications[fileName] ?? UUID().uuidString
        downloadNotifications[fileName] = notificationId
        
        // Create request
        let request = UNNotificationRequest(
            identifier: notificationId,
            content: content,
            trigger: nil // Immediate
        )
        
        // Add or update notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🚫 [BackgroundDownload] Failed to show notification: \(error.localizedDescription)")
            }
        }
    }
    
    // Show error notification (silent/background notification - only visible in notification center)
    private func showErrorNotification(fileName: String, error: Error) {
        let content = UNMutableNotificationContent()
        content.title = "Download Failed"
        content.body = "Failed to download \(fileName)"
        content.sound = nil // No sound for silent notification
        
        // Set interruption level to passive (silent notification - only shows in notification center)
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .passive
        }
        
        // Set category identifier for silent notification
        content.categoryIdentifier = "DOWNLOAD_ERROR"
        
        let notificationId = UUID().uuidString
        let request = UNNotificationRequest(
            identifier: notificationId,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🚫 [BackgroundDownload] Failed to show error notification: \(error.localizedDescription)")
            }
        }
    }
    
    // Cancel download
    func cancelDownload(fileName: String) {
        if let task = activeDownloads[fileName] {
            if let urlTask = task as? URLSessionDownloadTask {
                urlTask.cancel()
            } else {
                // For Firebase Storage tasks, write(toFile:) returns StorageDownloadTask
                // StorageTask base class doesn't expose cancel() method directly
                // The download may continue in background but we'll stop tracking it
                print("📱 [BackgroundDownload] Removing Firebase Storage download from tracking: \(fileName)")
            }
            activeDownloads.removeValue(forKey: fileName)
            downloadProgress.removeValue(forKey: fileName)
            downloadNotifications.removeValue(forKey: fileName)
            progressObservations.removeValue(forKey: fileName)
        }
    }
    
    // Cancel download with a specific key (for Photos library downloads)
    func cancelDownloadWithKey(key: String) {
        if let task = activeDownloads[key] {
            if let urlTask = task as? URLSessionDownloadTask {
                urlTask.cancel()
            } else {
                print("📱 [BackgroundDownload] Removing download from tracking: \(key)")
            }
            activeDownloads.removeValue(forKey: key)
            downloadProgress.removeValue(forKey: key)
            downloadNotifications.removeValue(forKey: key)
            progressObservations.removeValue(forKey: key)
        }
    }
    
    // Get download progress
    func getProgress(fileName: String) -> Double? {
        return downloadProgress[fileName]
    }
    
    // Check if downloading
    func isDownloading(fileName: String) -> Bool {
        return activeDownloads[fileName] != nil
    }
    
    // Check if downloading with a specific key (for Photos library downloads)
    func isDownloadingWithKey(key: String) -> Bool {
        return activeDownloads[key] != nil
    }
    
    // Get progress with a specific key
    func getProgressWithKey(key: String) -> Double? {
        return downloadProgress[key]
    }
    
    // Download image to Photos library (for receiver side - public directory equivalent)
    func downloadImageToPhotosLibrary(
        imageUrl: String,
        fileName: String,
        onProgress: ((Double) -> Void)? = nil,
        onSuccess: (() -> Void)? = nil,
        onFailure: ((Error) -> Void)? = nil
    ) {
        // Check if already downloading
        let downloadKey = "photos_\(fileName)"
        if activeDownloads[downloadKey] != nil {
            print("📱 [BackgroundDownload] Already downloading to Photos: \(fileName)")
            return
        }
        
        // Check if file already exists in Photos library
        if PhotosLibraryHelper.shared.imageExistsInPhotosLibrary(fileName: fileName) ||
           PhotosLibraryHelper.shared.fileExistsInCache(fileName: fileName) {
            print("📱 [BackgroundDownload] File already exists in Photos: \(fileName)")
            onSuccess?()
            return
        }
        
        // Show initial notification
        showDownloadNotification(fileName: fileName, progress: 0, isComplete: false)
        
        // Download to temporary location first, then save to Photos
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(fileName)
        
        // Download using Firebase Storage or HTTP
        if imageUrl.hasPrefix("gs://") {
            // Firebase Storage download
            downloadFromFirebaseStorageToPhotos(
                imageUrl: imageUrl,
                fileName: fileName,
                tempFile: tempFile,
                downloadKey: downloadKey,
                onProgress: onProgress,
                onSuccess: onSuccess,
                onFailure: onFailure
            )
        } else {
            // HTTP/HTTPS download
            downloadViaHTTPToPhotos(
                imageUrl: imageUrl,
                fileName: fileName,
                tempFile: tempFile,
                downloadKey: downloadKey,
                onProgress: onProgress,
                onSuccess: onSuccess,
                onFailure: onFailure
            )
        }
    }
    
    // Download from Firebase Storage to Photos library
    private func downloadFromFirebaseStorageToPhotos(
        imageUrl: String,
        fileName: String,
        tempFile: URL,
        downloadKey: String,
        onProgress: ((Double) -> Void)?,
        onSuccess: (() -> Void)?,
        onFailure: ((Error) -> Void)?
    ) {
        let storageRef = Storage.storage().reference(forURL: imageUrl)
        let downloadTask = storageRef.write(toFile: tempFile)
        
        // Store task
        activeDownloads[downloadKey] = downloadTask
        
        // Track progress
        _ = downloadTask.observe(.progress) { snapshot in
            guard let progress = snapshot.progress else { return }
            let totalBytes = Double(progress.totalUnitCount)
            let downloadedBytes = Double(progress.completedUnitCount)
            
            if totalBytes > 0 {
                let progressPercent = (downloadedBytes / totalBytes) * 100.0
                self.downloadProgress[downloadKey] = progressPercent
                
                // Update notification
                self.showDownloadNotification(fileName: fileName, progress: progressPercent, isComplete: false)
                
                // Call progress callback
                DispatchQueue.main.async {
                    onProgress?(progressPercent)
                }
            }
        }
        
        // Handle success
        downloadTask.observe(.success) { _ in
            // Read downloaded file and save to Photos library
            if let fileData = try? Data(contentsOf: tempFile) {
                // Check if it's a video file
                let isVideo = self.isVideoFile(fileName: fileName)
                
                if isVideo {
                    // Save video to Photos library
                    PhotosLibraryHelper.shared.saveVideoToPhotosLibrary(videoData: fileData, fileName: fileName) { success, error in
                        self.activeDownloads.removeValue(forKey: downloadKey)
                        self.downloadProgress.removeValue(forKey: downloadKey)
                        
                        // Remove notification when download completes
                        if let notificationId = self.downloadNotifications[fileName] {
                            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationId])
                            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId])
                            self.downloadNotifications.removeValue(forKey: fileName)
                            print("📱 [BackgroundDownload] Removed notification for completed Photos download: \(fileName)")
                        }
                        
                        // Clean up temp file
                        try? FileManager.default.removeItem(at: tempFile)
                        
                        DispatchQueue.main.async {
                            if success {
                                onSuccess?()
                            } else {
                                onFailure?(error ?? NSError(domain: "DownloadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to save video to Photos library"]))
                            }
                        }
                    }
                } else {
                    // Save image to Photos library
                    PhotosLibraryHelper.shared.saveImageToPhotosLibrary(imageData: fileData, fileName: fileName) { success, error in
                        if success {
                            // Save to cache to track
                            PhotosLibraryHelper.shared.saveToCache(fileName: fileName, imageData: fileData)
                        }
                        
                        self.activeDownloads.removeValue(forKey: downloadKey)
                        self.downloadProgress.removeValue(forKey: downloadKey)
                        
                        // Remove notification when download completes
                        if let notificationId = self.downloadNotifications[fileName] {
                            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationId])
                            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId])
                            self.downloadNotifications.removeValue(forKey: fileName)
                            print("📱 [BackgroundDownload] Removed notification for completed Photos download: \(fileName)")
                        }
                        
                        // Clean up temp file
                        try? FileManager.default.removeItem(at: tempFile)
                        
                        DispatchQueue.main.async {
                            if success {
                                onSuccess?()
                            } else {
                                onFailure?(error ?? NSError(domain: "DownloadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to save to Photos library"]))
                            }
                        }
                    }
                }
            } else {
                self.activeDownloads.removeValue(forKey: downloadKey)
                self.downloadProgress.removeValue(forKey: downloadKey)
                
                let error = NSError(domain: "DownloadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to read downloaded file"])
                self.showErrorNotification(fileName: fileName, error: error)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.downloadNotifications.removeValue(forKey: fileName)
                }
                
                DispatchQueue.main.async {
                    onFailure?(error)
                }
            }
        }
        
        // Handle failure
        downloadTask.observe(.failure) { snapshot in
            self.activeDownloads.removeValue(forKey: downloadKey)
            self.downloadProgress.removeValue(forKey: downloadKey)
            
            let error = snapshot.error ?? NSError(domain: "DownloadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
            
            // Show error notification
            self.showErrorNotification(fileName: fileName, error: error)
            
            // Clean up temp file
            try? FileManager.default.removeItem(at: tempFile)
            
            // Remove notification ID after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.downloadNotifications.removeValue(forKey: fileName)
            }
            
            DispatchQueue.main.async {
                onFailure?(error)
            }
        }
    }
    
    // Download via HTTP/HTTPS to Photos library
    private func downloadViaHTTPToPhotos(
        imageUrl: String,
        fileName: String,
        tempFile: URL,
        downloadKey: String,
        onProgress: ((Double) -> Void)?,
        onSuccess: (() -> Void)?,
        onFailure: ((Error) -> Void)?
    ) {
        guard let url = URL(string: imageUrl) else {
            let error = NSError(domain: "DownloadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            DispatchQueue.main.async {
                onFailure?(error)
            }
            return
        }
        
        // Create download task
        let task = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            if let error = error {
                self.activeDownloads.removeValue(forKey: downloadKey)
                self.downloadProgress.removeValue(forKey: downloadKey)
                self.progressObservations.removeValue(forKey: downloadKey)
                
                // Remove progress notification
                if let notificationId = self.downloadNotifications[fileName] {
                    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationId])
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId])
                }
                
                // Show error notification
                self.showErrorNotification(fileName: fileName, error: error)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.downloadNotifications.removeValue(forKey: fileName)
                }
                
                DispatchQueue.main.async {
                    onFailure?(error)
                }
                return
            }
            
            guard let downloadedTempURL = tempURL else {
                let error = NSError(domain: "DownloadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                self.activeDownloads.removeValue(forKey: downloadKey)
                self.downloadProgress.removeValue(forKey: downloadKey)
                self.progressObservations.removeValue(forKey: downloadKey)
                
                // Remove progress notification
                if let notificationId = self.downloadNotifications[fileName] {
                    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationId])
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId])
                }
                
                // Show error notification
                self.showErrorNotification(fileName: fileName, error: error)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.downloadNotifications.removeValue(forKey: fileName)
                }
                
                DispatchQueue.main.async {
                    onFailure?(error)
                }
                return
            }
            
            // Move to temp file location
            do {
                // Remove existing temp file if any
                if FileManager.default.fileExists(atPath: tempFile.path) {
                    try FileManager.default.removeItem(at: tempFile)
                }
                
                // Create directory if needed
                try FileManager.default.createDirectory(at: tempFile.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                
                // Move file
                try FileManager.default.moveItem(at: downloadedTempURL, to: tempFile)
                
                // Read file and save to Photos library
                if let fileData = try? Data(contentsOf: tempFile) {
                    // Check if it's a video file
                    let isVideo = self.isVideoFile(fileName: fileName)
                    
                    if isVideo {
                        // Save video to Photos library
                        PhotosLibraryHelper.shared.saveVideoToPhotosLibrary(videoData: fileData, fileName: fileName) { success, error in
                            self.activeDownloads.removeValue(forKey: downloadKey)
                            self.downloadProgress.removeValue(forKey: downloadKey)
                            self.progressObservations.removeValue(forKey: downloadKey)
                            
                            // Remove notification when download completes
                            if let notificationId = self.downloadNotifications[fileName] {
                                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationId])
                                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId])
                                self.downloadNotifications.removeValue(forKey: fileName)
                                print("📱 [BackgroundDownload] Removed notification for completed Photos download: \(fileName)")
                            }
                            
                            // Clean up temp file
                            try? FileManager.default.removeItem(at: tempFile)
                            
                            DispatchQueue.main.async {
                                if success {
                                    onSuccess?()
                                } else {
                                    onFailure?(error ?? NSError(domain: "DownloadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to save video to Photos library"]))
                                }
                            }
                        }
                    } else {
                        // Save image to Photos library
                        PhotosLibraryHelper.shared.saveImageToPhotosLibrary(imageData: fileData, fileName: fileName) { success, error in
                            if success {
                                // Save to cache to track
                                PhotosLibraryHelper.shared.saveToCache(fileName: fileName, imageData: fileData)
                            }
                            
                            self.activeDownloads.removeValue(forKey: downloadKey)
                            self.downloadProgress.removeValue(forKey: downloadKey)
                            self.progressObservations.removeValue(forKey: downloadKey)
                            
                            // Remove notification when download completes
                            if let notificationId = self.downloadNotifications[fileName] {
                                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationId])
                                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId])
                                self.downloadNotifications.removeValue(forKey: fileName)
                                print("📱 [BackgroundDownload] Removed notification for completed Photos download: \(fileName)")
                            }
                            
                            // Clean up temp file
                            try? FileManager.default.removeItem(at: tempFile)
                            
                            DispatchQueue.main.async {
                                if success {
                                    onSuccess?()
                                } else {
                                    onFailure?(error ?? NSError(domain: "DownloadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to save to Photos library"]))
                                }
                            }
                        }
                    }
                } else {
                    self.activeDownloads.removeValue(forKey: downloadKey)
                    self.downloadProgress.removeValue(forKey: downloadKey)
                    self.progressObservations.removeValue(forKey: downloadKey)
                    
                    let error = NSError(domain: "DownloadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to read downloaded file"])
                    self.showErrorNotification(fileName: fileName, error: error)
                    
                    // Clean up temp file
                    try? FileManager.default.removeItem(at: tempFile)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.downloadNotifications.removeValue(forKey: fileName)
                    }
                    
                    DispatchQueue.main.async {
                        onFailure?(error)
                    }
                }
            } catch {
                self.activeDownloads.removeValue(forKey: downloadKey)
                self.downloadProgress.removeValue(forKey: downloadKey)
                self.progressObservations.removeValue(forKey: downloadKey)
                
                self.showErrorNotification(fileName: fileName, error: error)
                
                // Clean up temp file
                try? FileManager.default.removeItem(at: tempFile)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.downloadNotifications.removeValue(forKey: fileName)
                }
                
                DispatchQueue.main.async {
                    onFailure?(error)
                }
            }
        }
        
        // Store task
        activeDownloads[downloadKey] = task
        
        // Track progress - store observation to keep it alive
        let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
            let progressPercent = progress.fractionCompleted * 100.0
            self.downloadProgress[downloadKey] = progressPercent
            
            // Update notification
            self.showDownloadNotification(fileName: fileName, progress: progressPercent, isComplete: false)
            
            // Call progress callback
            DispatchQueue.main.async {
                onProgress?(progressPercent)
            }
        }
        
        // Retain observation so KVO keeps firing
        progressObservations[downloadKey] = observation
        
        // Start download
        task.resume()
    }
}

