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
            var urls: [URL] = []
            let group = DispatchGroup()
            
            for result in results {
                group.enter()
                
                // Get the asset identifier
                if let assetIdentifier = result.assetIdentifier {
                    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
                    if let asset = fetchResult.firstObject {
                        // Export the asset to a temporary file URL
                        if asset.mediaType == .image {
                            // Export image
                            let options = PHImageRequestOptions()
                            options.isSynchronous = false
                            options.deliveryMode = .highQualityFormat
                            
                            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { imageData, _, _, _ in
                                if let data = imageData {
                                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
                                    do {
                                        try data.write(to: tempURL)
                                        urls.append(tempURL)
                                    } catch {
                                        print("Error writing image: \(error)")
                                    }
                                }
                                group.leave()
                            }
                        } else if asset.mediaType == .video {
                            // Export video
                            let options = PHVideoRequestOptions()
                            options.isNetworkAccessAllowed = true
                            
                            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                                if let urlAsset = avAsset as? AVURLAsset {
                                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
                                    do {
                                        try FileManager.default.copyItem(at: urlAsset.url, to: tempURL)
                                        urls.append(tempURL)
                                    } catch {
                                        print("Error copying video: \(error)")
                                    }
                                }
                                group.leave()
                            }
                        } else {
                            group.leave()
                        }
                    } else {
                        group.leave()
                    }
                } else {
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                // Start accessing security-scoped resources
                for url in urls {
                    _ = url.startAccessingSecurityScopedResource()
                }
                self.parent.selectedDocuments = urls
                self.parent.presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

