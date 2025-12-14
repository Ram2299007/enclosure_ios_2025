//
//  DocumentPicker.swift
//  Enclosure
//
//  Created by Ram Lohar on 30/04/25.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedDocuments: [URL]
    var allowsMultipleSelection: Bool = true
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Use UIDocumentPickerViewController for files/documents/photos/videos
        // Support all file types (matching Android Intent.ACTION_GET_CONTENT with "*/*")
        var contentTypes: [UTType] = [
            // Images
            .image,
            .jpeg,
            .png,
            .gif,
            .heic,
            .heif,
            // Videos
            .movie,
            .mpeg4Movie,
            .quickTimeMovie,
            .avi,
            // Documents
            .pdf,
            .text,
            .plainText,
            .rtf,
            .rtfd,
            // Office documents
            .spreadsheet,
            .presentation,
            // Archives
            .zip,
            .archive,
            .gzip,
            // Audio
            .audio,
            .mp3,
            .wav,
            // Generic item (catches everything else including Office docs)
            .item,
            .data
        ]
        
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = allowsMultipleSelection
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            // Handle selected documents
            // Start accessing security-scoped resources
            for url in urls {
                _ = url.startAccessingSecurityScopedResource()
            }
            parent.selectedDocuments = urls
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

