//
//  GalleryPicker.swift
//  Enclosure
//
//  Created by Ram Lohar on 30/04/25.
//

import SwiftUI
import UIKit
import PhotosUI
import Photos
import AVFoundation
import UniformTypeIdentifiers

struct GalleryPicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedDocuments: [URL]
    var allowsMultipleSelection: Bool = true
    var onDocumentsSelected: (([URL]) -> Void)? = nil
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        // Use PHPickerViewController to show photos and videos from gallery
        var configuration = PHPickerConfiguration()
        configuration.filter = .any(of: [.images, .videos]) // Show both photos and videos
        configuration.selectionLimit = allowsMultipleSelection ? 0 : 1 // 0 = unlimited
        configuration.preferredAssetRepresentationMode = .current
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: GalleryPicker
        
        init(_ parent: GalleryPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            print("GalleryPicker: didFinishPicking called with \(results.count) results")
            
            // If no results, dismiss immediately
            guard !results.isEmpty else {
                print("GalleryPicker: No results selected, dismissing")
                self.parent.presentationMode.wrappedValue.dismiss()
                return
            }
            
            var urls: [URL] = []
            let group = DispatchGroup()
            
            for (index, result) in results.enumerated() {
                group.enter()
                print("GalleryPicker: Processing result \(index + 1)/\(results.count)")
                
                let itemProvider = result.itemProvider
                
                // Check if it's an image
                if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    print("GalleryPicker: Result \(index + 1) is an image")
                    itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
                        defer { group.leave() }
                        if let error = error {
                            print("GalleryPicker: Error loading image \(index + 1): \(error)")
                            return
                        }
                        guard let sourceURL = url else {
                            print("GalleryPicker: No URL for image \(index + 1)")
                            return
                        }
                        
                        // Copy to temporary directory
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
                        do {
                            // If sourceURL is already a file URL, copy it
                            if sourceURL.startAccessingSecurityScopedResource() {
                                defer { sourceURL.stopAccessingSecurityScopedResource() }
                                try FileManager.default.copyItem(at: sourceURL, to: tempURL)
                            } else {
                                try FileManager.default.copyItem(at: sourceURL, to: tempURL)
                            }
                            urls.append(tempURL)
                            print("GalleryPicker: Exported image \(index + 1) to \(tempURL.lastPathComponent)")
                        } catch {
                            print("GalleryPicker: Error copying image \(index + 1): \(error)")
                        }
                    }
                }
                // Check if it's a video
                else if itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    print("GalleryPicker: Result \(index + 1) is a video")
                    itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                        defer { group.leave() }
                        if let error = error {
                            print("GalleryPicker: Error loading video \(index + 1): \(error)")
                            return
                        }
                        guard let sourceURL = url else {
                            print("GalleryPicker: No URL for video \(index + 1)")
                            return
                        }
                        
                        // Copy to temporary directory
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
                        do {
                            // If sourceURL is already a file URL, copy it
                            if sourceURL.startAccessingSecurityScopedResource() {
                                defer { sourceURL.stopAccessingSecurityScopedResource() }
                                try FileManager.default.copyItem(at: sourceURL, to: tempURL)
                            } else {
                                try FileManager.default.copyItem(at: sourceURL, to: tempURL)
                            }
                            urls.append(tempURL)
                            print("GalleryPicker: Exported video \(index + 1) to \(tempURL.lastPathComponent)")
                        } catch {
                            print("GalleryPicker: Error copying video \(index + 1): \(error)")
                        }
                    }
                }
                // Try using assetIdentifier as fallback
                else if let assetIdentifier = result.assetIdentifier {
                    print("GalleryPicker: Result \(index + 1) has assetIdentifier, using fallback method")
                    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
                    if let asset = fetchResult.firstObject {
                        print("GalleryPicker: Found asset \(index + 1), mediaType: \(asset.mediaType.rawValue)")
                        // Export the asset to a temporary file URL
                        if asset.mediaType == .image {
                            // Export image
                            let options = PHImageRequestOptions()
                            options.isSynchronous = false
                            options.deliveryMode = .highQualityFormat
                            
                            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { imageData, _, _, _ in
                                defer { group.leave() }
                                if let data = imageData {
                                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
                                    do {
                                        try data.write(to: tempURL)
                                        urls.append(tempURL)
                                        print("GalleryPicker: Exported image \(index + 1) to \(tempURL.lastPathComponent)")
                                    } catch {
                                        print("GalleryPicker: Error writing image \(index + 1): \(error)")
                                    }
                                } else {
                                    print("GalleryPicker: No image data for asset \(index + 1)")
                                }
                            }
                        } else if asset.mediaType == .video {
                            // Export video
                            let options = PHVideoRequestOptions()
                            options.isNetworkAccessAllowed = true
                            
                            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                                defer { group.leave() }
                                if let urlAsset = avAsset as? AVURLAsset {
                                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
                                    do {
                                        try FileManager.default.copyItem(at: urlAsset.url, to: tempURL)
                                        urls.append(tempURL)
                                        print("GalleryPicker: Exported video \(index + 1) to \(tempURL.lastPathComponent)")
                                    } catch {
                                        print("GalleryPicker: Error copying video \(index + 1): \(error)")
                                    }
                                } else {
                                    print("GalleryPicker: No video asset for asset \(index + 1)")
                                }
                            }
                        } else {
                            print("GalleryPicker: Unknown media type for asset \(index + 1)")
                            group.leave()
                        }
                    } else {
                        print("GalleryPicker: No asset found for identifier \(index + 1)")
                        group.leave()
                    }
                } else {
                    print("GalleryPicker: No supported type for result \(index + 1)")
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                print("GalleryPicker: All async operations completed")
                print("GalleryPicker: Exported \(urls.count) files out of \(results.count) results")
                print("GalleryPicker: Files: \(urls.map { $0.lastPathComponent })")
                
                // Start accessing security-scoped resources
                for url in urls {
                    _ = url.startAccessingSecurityScopedResource()
                }
                
                // Set documents BEFORE dismissing
                self.parent.selectedDocuments = urls
                print("GalleryPicker: Set selectedDocuments to \(urls.count) files")
                
                // Also call completion callback if provided
                if let callback = self.parent.onDocumentsSelected {
                    callback(urls)
                }
                
                // Dismiss after a short delay to ensure binding is updated
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    print("GalleryPicker: Dismissing picker")
                    self.parent.presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

