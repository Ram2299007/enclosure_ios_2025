//
//  ShareViewController.swift
//  EnclosureShareExtension
//
//  Created by Ram Lohar on 15/01/26.
//

import UIKit
import UniformTypeIdentifiers

// @objc annotation required for NSExtensionPrincipalClass to work correctly
@objc(ShareViewController)
class ShareViewController: UIViewController {
    private var processedCount = 0
    private var totalAttachments = 0
    private var sharedData: [String: Any] = [:]
    private var storedExtensionContext: NSExtensionContext? // Store context from beginRequest
    private var loadedTextData: String? // Store text loaded from attachments
    
    // CRITICAL: This is called FIRST when extension is activated
    // This is the entry point for Share Extensions using custom UIViewController
    // UIViewController already conforms to NSExtensionRequestHandling when used as extension
    override func beginRequest(with context: NSExtensionContext) {
        NSLog("🔴🔴🔴🔴🔴 [ShareExtension] beginRequest CALLED 🔴🔴🔴🔴🔴")
        NSLog("📤 [ShareExtension] Extension context: \(context)")
        NSLog("📤 [ShareExtension] Input items count: \(context.inputItems.count)")
        fputs("🔴🔴🔴 beginRequest CALLED\n", stderr)
        fflush(stderr)
        
        // CRITICAL: Store the extension context - it's only available in beginRequest
        storedExtensionContext = context
        
        // extensionContext property is automatically set by iOS, but we store it explicitly
        // Process items immediately on main thread
        DispatchQueue.main.async { [weak self] in
            // Ensure view is loaded first
            _ = self?.view
            self?.processSharedItems()
        }
    }
    
    // Force print to console immediately - these should appear FIRST
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        NSLog("🔴🔴🔴 [ShareExtension] INIT(nibName) CALLED 🔴🔴🔴")
        NSLog("📤 [ShareExtension] ShareViewController initialized")
        fputs("🔴 INIT(nibName) CALLED\n", stderr)
        fflush(stderr)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        NSLog("🔴🔴🔴 [ShareExtension] INIT(coder) CALLED 🔴🔴🔴")
        fputs("🔴 INIT(coder) CALLED\n", stderr)
        fflush(stderr)
    }
    
    // This is called when the view controller is loaded from storyboard
    override func awakeFromNib() {
        super.awakeFromNib()
        NSLog("🔴🔴🔴 [ShareExtension] awakeFromNib CALLED 🔴🔴🔴")
        fputs("🔴 awakeFromNib CALLED\n", stderr)
        fflush(stderr)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // CRITICAL: Force immediate output to verify Share Extension is running
        NSLog("🔴🔴🔴🔴🔴 SHARE EXTENSION viewDidLoad CALLED 🔴🔴🔴🔴🔴")
        NSLog("📤 [ShareExtension] ====== viewDidLoad CALLED ======")
        NSLog("📤 [ShareExtension] Extension context: \(extensionContext != nil ? "EXISTS" : "NIL")")
        
        // Also write to stderr which is more reliable
        fputs("🔴🔴🔴 viewDidLoad CALLED\n", stderr)
        fflush(stderr)
        
        // CRITICAL: Don't complete immediately - process items first
        view.backgroundColor = .black
        
        let label = UILabel()
        label.text = "Processing..."
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // Check if App Group is accessible
        let sharedDefaults = UserDefaults(suiteName: "group.com.enclosure.data")
        if sharedDefaults == nil {
            NSLog("🔴 [ShareExtension] CRITICAL: App Group UserDefaults is nil!")
            NSLog("🔴 [ShareExtension] App Group 'group.com.enclosure.data' is NOT configured!")
            fputs("🔴 App Group nil\n", stderr)
            fflush(stderr)
            label.text = "Error: App Group not configured"
            label.textColor = .red
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.completeRequest()
            }
            return
        }
        
        NSLog("✅ [ShareExtension] App Group UserDefaults accessible")
        fputs("✅ App Group accessible\n", stderr)
        fflush(stderr)
        
        // Don't process items in viewDidLoad - wait for viewDidAppear
        // This ensures the view is fully loaded and visible
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NSLog("🔴 [ShareExtension] viewWillAppear CALLED")
        fputs("🔴 viewWillAppear\n", stderr)
        fflush(stderr)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        NSLog("🔴🔴🔴 [ShareExtension] viewDidAppear CALLED 🔴🔴🔴")
        fputs("🔴🔴🔴 viewDidAppear CALLED\n", stderr)
        fflush(stderr)
        
        // DON'T process items here - already processed in beginRequest
        // Processing here causes duplicate processing
        // Items are already being processed in beginRequest -> processSharedItems()
    }
    
    func processSharedItems() {
        NSLog("🔴🔴🔴 [ShareExtension] processSharedItems CALLED 🔴🔴🔴")
        fputs("🔴🔴🔴 processSharedItems CALLED\n", stderr)
        fflush(stderr)
        
        // Reset state for new share
        loadedTextData = nil
        processedCount = 0
        totalAttachments = 0
        
        // Use stored context first, fallback to extensionContext property
        let context = storedExtensionContext ?? extensionContext
        
        guard let extensionContext = context else {
            NSLog("🚫 [ShareExtension] extensionContext is NIL!")
            NSLog("🚫 [ShareExtension] storedExtensionContext: \(storedExtensionContext != nil ? "EXISTS" : "NIL")")
            NSLog("🚫 [ShareExtension] extensionContext property: \(self.extensionContext != nil ? "EXISTS" : "NIL")")
            fputs("🚫 extensionContext NIL\n", stderr)
            fflush(stderr)
            openMainApp()
            return
        }
        
        guard let items = extensionContext.inputItems as? [NSExtensionItem] else {
            NSLog("🚫 [ShareExtension] inputItems is NIL or wrong type!")
            NSLog("📤 [ShareExtension] inputItems type: \(type(of: extensionContext.inputItems))")
            fputs("🚫 inputItems wrong type\n", stderr)
            fflush(stderr)
            openMainApp()
            return
        }
        
        NSLog("📤 [ShareExtension] Found \(items.count) extension items")
        fputs("📤 Found \(items.count) items\n", stderr)
        fflush(stderr)
        
        var imageUrls: [String] = []
        var videoUrls: [String] = []
        var documentUrl: String?
        var documentName: String?
        var textData: String?
        var contentType = "text"
        
        // Track content types to detect mixed selections (images + videos + documents)
        var hasImages = false
        var hasVideos = false
        var hasDocuments = false
        var hasContacts = false
        
        let group = DispatchGroup()
        
        // Count total attachments and extract text
        var hasAttachments = false
        var hasNonTextAttachments = false
        var hasTextAttachments = false
        
        for item in items {
            // Check attributedContentText first
            if let text = item.attributedContentText?.string, !text.isEmpty {
                textData = text
            }
            
            // Check attachments
            if let attachments = item.attachments, !attachments.isEmpty {
                hasAttachments = true
                totalAttachments += attachments.count
                
                // Check if attachments are only plain text or URLs (text sharing from external apps)
                for attachment in attachments {
                    if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) ||
                       attachment.hasItemConformingToTypeIdentifier("public.plain-text") ||
                       attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) ||
                       attachment.hasItemConformingToTypeIdentifier("public.url") {
                        hasTextAttachments = true
                    } else {
                        hasNonTextAttachments = true
                    }
                }
            }
        }
        
        // If we have text attachments, we need to load them to get the full text
        // attributedContentText might be truncated or formatted, so we load from attachment
        if hasTextAttachments {
            // Need to load text from attachments first
            NSLog("📤 [ShareExtension] Found text attachments - loading text from attachments...")
            NSLog("📤 [ShareExtension] Current textData from attributedContentText: \(textData?.prefix(50) ?? "nil")...")
            // Don't return - continue to process attachments below
        } else if (!hasAttachments && textData != nil) {
            // No attachments, just text from attributedContentText - save immediately
            NSLog("📤 [ShareExtension] Text-only share (no attachments) - saving immediately")
            NSLog("📤 [ShareExtension] textData: \(textData?.prefix(50) ?? "nil")...")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    NSLog("🚫 [ShareExtension] self is nil in async block")
                    return
                }
                NSLog("📤 [ShareExtension] Calling saveAndOpenApp for text-only share...")
                self.saveAndOpenApp(contentType: "text", imageUrls: [], videoUrls: [], documentUrl: nil, documentName: nil, textData: textData)
            }
            return
        }
        
        if !hasAttachments && textData == nil && !hasTextAttachments {
            NSLog("🚫 [ShareExtension] No attachments and no text - opening app without data")
            openMainApp()
            return
        }
        
        // Process attachments
        for item in items {
            // Handle text from attributedContentText
            if let text = item.attributedContentText?.string, !text.isEmpty {
                textData = text
            }
            
            // Handle attachments
            if let attachments = item.attachments {
                for attachment in attachments {
                    group.enter()
                    
                    // Handle URL attachments (YouTube links, web URLs, etc.)
                    if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) ||
                       attachment.hasItemConformingToTypeIdentifier("public.url") {
                        // URLs should be treated as text
                        let typeIdentifier = attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) 
                            ? UTType.url.identifier 
                            : "public.url"
                        
                        NSLog("📤 [ShareExtension] Loading URL attachment with type: \(typeIdentifier)")
                        attachment.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { [weak self] (data, error) in
                            defer { group.leave() }
                            
                            guard let self = self else {
                                NSLog("🚫 [ShareExtension] self is nil in URL loading closure")
                                return
                            }
                            
                            if let error = error {
                                NSLog("🚫 [ShareExtension] Error loading URL: \(error.localizedDescription)")
                                return
                            }
                            
                            // URL can come as URL object or String
                            if let url = data as? URL {
                                let urlString = url.absoluteString
                                self.handleLoadedText(data: urlString as NSSecureCoding, error: nil)
                                NSLog("📤 [ShareExtension] Loaded URL: \(urlString)")
                            } else if let urlString = data as? String {
                                self.handleLoadedText(data: urlString as NSSecureCoding, error: nil)
                                NSLog("📤 [ShareExtension] Loaded URL string: \(urlString)")
                            }
                            self.processedCount += 1
                        }
                    } else if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) ||
                       attachment.hasItemConformingToTypeIdentifier("public.plain-text") {
                        // Try loading with plainText first, fallback to public.plain-text
                        let typeIdentifier = attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) 
                            ? UTType.plainText.identifier 
                            : "public.plain-text"
                        
                        NSLog("📤 [ShareExtension] Loading plain text attachment with type: \(typeIdentifier)")
                        attachment.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { [weak self] (data, error) in
                            defer { group.leave() }
                            
                            guard let self = self else {
                                NSLog("🚫 [ShareExtension] self is nil in text loading closure")
                                return
                            }
                            
                            if let error = error {
                                NSLog("🚫 [ShareExtension] Error loading plain text with \(typeIdentifier): \(error.localizedDescription)")
                                // Try fallback type if first attempt failed
                                if typeIdentifier == UTType.plainText.identifier && attachment.hasItemConformingToTypeIdentifier("public.plain-text") {
                                    NSLog("📤 [ShareExtension] Trying fallback type: public.plain-text")
                                    group.enter() // Need to enter again for fallback
                                    attachment.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { [weak self] (data, error) in
                                        defer { group.leave() }
                                        guard let self = self else { return }
                                        self.handleLoadedText(data: data, error: error)
                                        self.processedCount += 1
                                    }
                                }
                                return
                            }
                            
                            self.handleLoadedText(data: data, error: nil)
                            self.processedCount += 1
                        }
                    } else if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                        attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (data, error) in
                            defer { group.leave() }
                            
                            if let url = data as? URL {
                                // Copy image to permanent location (app's documents directory)
                                // The original URL might be in a temporary location that gets cleaned up
                                if let copiedUrl = self?.copyImageToPermanentLocation(sourceUrl: url) {
                                    imageUrls.append(copiedUrl.path)
                                    hasImages = true
                                    NSLog("📤 [ShareExtension] Image copied to permanent location: \(copiedUrl.path)")
                                } else {
                                    // Fallback: try to use original URL with security-scoped access
                                    let _ = url.startAccessingSecurityScopedResource()
                                    defer { url.stopAccessingSecurityScopedResource() }
                                    if FileManager.default.fileExists(atPath: url.path) {
                                imageUrls.append(url.path)
                                        hasImages = true
                                        NSLog("📤 [ShareExtension] Using original image URL: \(url.path)")
                                    } else {
                                        NSLog("🚫 [ShareExtension] Image file does not exist at: \(url.path)")
                                    }
                                }
                                self?.processedCount += 1
                            } else if let imageData = data as? Data {
                                if let tempUrl = self?.saveToTemp(data: imageData, extension: "jpg") {
                                    imageUrls.append(tempUrl.path)
                                    hasImages = true
                                    NSLog("📤 [ShareExtension] Image saved from data to: \(tempUrl.path)")
                                }
                                self?.processedCount += 1
                            }
                        }
                    } else if attachment.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                        attachment.loadItem(forTypeIdentifier: UTType.movie.identifier, options: nil) { [weak self] (data, error) in
                            defer { group.leave() }
                            
                            if let url = data as? URL {
                                // Copy video to permanent location (app's documents directory)
                                // The original URL might be in a temporary location that gets cleaned up
                                if let copiedUrl = self?.copyVideoToPermanentLocation(sourceUrl: url) {
                                    videoUrls.append(copiedUrl.path)
                                    hasVideos = true
                                    NSLog("📤 [ShareExtension] Video copied to permanent location: \(copiedUrl.path)")
                                } else {
                                    // Fallback: try to use original URL with security-scoped access
                                    let _ = url.startAccessingSecurityScopedResource()
                                    defer { url.stopAccessingSecurityScopedResource() }
                                    if FileManager.default.fileExists(atPath: url.path) {
                                videoUrls.append(url.path)
                                        hasVideos = true
                                        NSLog("📤 [ShareExtension] Using original video URL: \(url.path)")
                                    } else {
                                        NSLog("🚫 [ShareExtension] Video file does not exist at: \(url.path)")
                                    }
                                }
                                self?.processedCount += 1
                            }
                        }
                    } else if attachment.hasItemConformingToTypeIdentifier(UTType.vCard.identifier) {
                        attachment.loadItem(forTypeIdentifier: UTType.vCard.identifier, options: nil) { [weak self] (data, error) in
                            defer { group.leave() }
                            
                            if let url = data as? URL {
                                // Copy contact to permanent location
                                if let copiedUrl = self?.copyDocumentToPermanentLocation(sourceUrl: url, extension: "vcf") {
                                    documentUrl = copiedUrl.path
                                    documentName = url.lastPathComponent
                                    contentType = "contact"
                                    hasContacts = true
                                    NSLog("📤 [ShareExtension] Contact copied to permanent location: \(copiedUrl.path)")
                                } else {
                                    // Fallback: use temp location
                                if let tempUrl = self?.copyToTemp(url: url, extension: "vcf") {
                                    documentUrl = tempUrl.path
                                    documentName = url.lastPathComponent
                                    contentType = "contact"
                                        hasContacts = true
                                    }
                                }
                            } else if let vCardData = data as? Data {
                                // Save contact data to permanent location
                                if let copiedUrl = self?.saveDocumentDataToPermanentLocation(data: vCardData, extension: "vcf", fileName: "contact.vcf") {
                                    documentUrl = copiedUrl.path
                                    documentName = "contact.vcf"
                                    contentType = "contact"
                                    hasContacts = true
                                    NSLog("📤 [ShareExtension] Contact data saved to permanent location: \(copiedUrl.path)")
                                } else {
                                    // Fallback: use temp location
                                if let tempUrl = self?.saveToTemp(data: vCardData, extension: "vcf") {
                                    documentUrl = tempUrl.path
                                    documentName = "contact.vcf"
                                    contentType = "contact"
                                        hasContacts = true
                                    }
                                }
                            }
                            self?.processedCount += 1
                        }
                    } else if attachment.hasItemConformingToTypeIdentifier(UTType.item.identifier) {
                        attachment.loadItem(forTypeIdentifier: UTType.item.identifier, options: nil) { [weak self] (data, error) in
                            defer { group.leave() }
                            
                            if let url = data as? URL {
                                // Copy document to permanent location
                                let fileExtension = url.pathExtension.isEmpty ? "bin" : url.pathExtension
                                if let copiedUrl = self?.copyDocumentToPermanentLocation(sourceUrl: url, extension: fileExtension) {
                                    documentUrl = copiedUrl.path
                                    documentName = url.lastPathComponent
                                    contentType = "document"
                                    hasDocuments = true
                                    NSLog("📤 [ShareExtension] Document copied to permanent location: \(copiedUrl.path)")
                                } else {
                                    // Fallback: use temp location
                                    if let tempUrl = self?.copyToTemp(url: url, extension: fileExtension) {
                                    documentUrl = tempUrl.path
                                    documentName = url.lastPathComponent
                                    contentType = "document"
                                        hasDocuments = true
                                    }
                                }
                            }
                            self?.processedCount += 1
                        }
                    } else {
                        group.leave()
                    }
                }
            }
        }
        
        // If no attachments to process, call notify immediately
        if totalAttachments == 0 {
            NSLog("📤 [ShareExtension] No attachments to process - calling saveAndOpenApp directly")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let finalTextData = textData
                // Even if textData is empty, save it as text type (URLs might be in attributedContentText)
                // This ensures the contact screen is shown
                self.saveAndOpenApp(contentType: "text", imageUrls: [], videoUrls: [], documentUrl: nil, documentName: nil, textData: finalTextData ?? "")
            }
        } else {
            group.notify(queue: .main) { [weak self] in
                guard let self = self else {
                    NSLog("🚫 [ShareExtension] self is nil in group.notify")
                    return
                }
                
                NSLog("🔴 [ShareExtension] group.notify CALLED - Processing complete")
                NSLog("🔴 [ShareExtension] Processed count: \(self.processedCount)/\(self.totalAttachments)")
                fputs("🔴 group.notify CALLED\n", stderr)
                fflush(stderr)
                
                // Determine final text data
                // If we loaded text from attachments, use that (it's more complete)
                // Otherwise use attributedContentText
                // Don't merge them as they're usually the same content, causing duplication
                var finalTextData: String?
                if let loaded = self.loadedTextData, !loaded.isEmpty {
                    // Use loaded text from attachment (more reliable and complete)
                        finalTextData = loaded
                    NSLog("📤 [ShareExtension] Using loaded text from attachment (\(loaded.count) chars)")
                } else if let attributedText = textData, !attributedText.isEmpty {
                    // Fallback to attributedContentText if no attachment text was loaded
                    finalTextData = attributedText
                    NSLog("📤 [ShareExtension] Using attributedContentText (\(attributedText.count) chars)")
                }
                
                // Determine content type
                // Check for mixed content types (images + videos + documents) - treat as documents
                let typeCount = (hasImages ? 1 : 0) + (hasVideos ? 1 : 0) + (hasDocuments ? 1 : 0) + (hasContacts ? 1 : 0)
                let isMixedSelection = typeCount > 1
                
                var finalContentType = contentType
                if isMixedSelection {
                    // Mixed selection (images + videos, images + documents, videos + documents, or all)
                    // Treat as documents (matching Android behavior)
                    finalContentType = "document"
                    NSLog("📤 [ShareExtension] Mixed content types detected - treating as document")
                    NSLog("📤 [ShareExtension] Has images: \(hasImages), Has videos: \(hasVideos), Has documents: \(hasDocuments), Has contacts: \(hasContacts)")
                } else if !imageUrls.isEmpty {
                    finalContentType = "image"
                } else if !videoUrls.isEmpty {
                    finalContentType = "video"
                } else if documentUrl != nil {
                    // Already set above (contact or document)
                } else if finalTextData != nil {
                    finalContentType = "text"
                }
                
                NSLog("📤 [ShareExtension] Content type determined: \(finalContentType)")
                if isMixedSelection {
                    NSLog("📤 [ShareExtension] Mixed selection detected - treating as documents")
                    NSLog("📤 [ShareExtension] Images: \(imageUrls.count), Videos: \(videoUrls.count), Documents: \(documentUrl != nil ? "1" : "0")")
                }
                
                // For mixed selections, combine all URLs into documentUrl (use first available)
                var finalDocumentUrl = documentUrl
                var finalDocumentName = documentName
                
                if isMixedSelection {
                    // Combine all files - use first image, video, or document as the primary document
                    if let firstImage = imageUrls.first {
                        finalDocumentUrl = firstImage
                        finalDocumentName = URL(fileURLWithPath: firstImage).lastPathComponent
                        NSLog("📤 [ShareExtension] Mixed selection - using first image as document: \(firstImage)")
                    } else if let firstVideo = videoUrls.first {
                        finalDocumentUrl = firstVideo
                        finalDocumentName = URL(fileURLWithPath: firstVideo).lastPathComponent
                        NSLog("📤 [ShareExtension] Mixed selection - using first video as document: \(firstVideo)")
                    } else if let docUrl = documentUrl {
                        finalDocumentUrl = docUrl
                        finalDocumentName = documentName
                        NSLog("📤 [ShareExtension] Mixed selection - using document: \(docUrl)")
                    }
                    
                    // Clear imageUrls and videoUrls for mixed selection (treated as documents)
                    // Note: The main app will handle this as a document type
                }
                
                NSLog("📤 [ShareExtension] Final text data length: \(finalTextData?.count ?? 0) chars")
                NSLog("📤 [ShareExtension] Final text preview: \(finalTextData?.prefix(50) ?? "nil")...")
                fputs("📤 Content type: \(finalContentType)\n", stderr)
                fflush(stderr)
                
                // Always save and open app, even if textData is empty
                // This ensures contact screen is shown for all content types
                // Empty text might occur with URLs or other edge cases
                    self.saveAndOpenApp(
                        contentType: finalContentType,
                    imageUrls: isMixedSelection ? [] : imageUrls, // Clear for mixed selection
                    videoUrls: isMixedSelection ? [] : videoUrls, // Clear for mixed selection
                    documentUrl: finalDocumentUrl,
                    documentName: finalDocumentName,
                    textData: finalTextData ?? ""
                    )
            }
        }
    }
    
    private func saveAndOpenApp(contentType: String, imageUrls: [String], videoUrls: [String], documentUrl: String?, documentName: String?, textData: String?) {
        // Log immediately - first thing in function
        fputs("🔴 saveAndOpenApp CALLED - FIRST LINE\n", stderr)
        fflush(stderr)
        NSLog("🔴 [ShareExtension] saveAndOpenApp CALLED - FIRST LINE")
        NSLog("🔴 [ShareExtension] Parameters - contentType: \(contentType), textData: \(textData?.prefix(50) ?? "nil")...")
        fputs("🔴 saveAndOpenApp CALLED - AFTER FIRST LOG\n", stderr)
        fflush(stderr)
        
        // Try to save to shared file container first (more reliable than UserDefaults for cross-process sync)
        var savedToFile = false
        var containerURL: URL?
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.enclosure.data") {
            containerURL = url
            NSLog("✅ [ShareExtension] App Group container accessible: \(url.path)")
            savedToFile = true
        } else {
            NSLog("⚠️ [ShareExtension] App Group container not accessible - will use UserDefaults only")
            NSLog("⚠️ [ShareExtension] This might be a signing issue - check Signing & Capabilities in Xcode")
            NSLog("⚠️ [ShareExtension] Attempting alternative method to access container...")
            // Try alternative: check if we can create the directory
            if let altURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let sharedPath = altURL.deletingLastPathComponent().appendingPathComponent("Shared/AppGroup/group.com.enclosure.data")
                NSLog("📤 [ShareExtension] Trying alternative path: \(sharedPath.path)")
                if FileManager.default.fileExists(atPath: sharedPath.path) {
                    containerURL = sharedPath
                    savedToFile = true
                    NSLog("✅ [ShareExtension] Found container via alternative path")
                }
            }
            savedToFile = false
        }
        
        // Always save to UserDefaults as primary method (works even if container fails)
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.enclosure.data") else {
            NSLog("🔴 [ShareExtension] CRITICAL: App Group UserDefaults is nil!")
            NSLog("🔴 [ShareExtension] App Group 'group.com.enclosure.data' is NOT properly configured!")
            fputs("🔴 App Group UserDefaults nil\n", stderr)
            fflush(stderr)
            completeRequest()
            return
        }
        
        NSLog("✅ [ShareExtension] App Group UserDefaults accessible - saving data...")
        
        // Save to UserDefaults (primary method)
        sharedDefaults.set(contentType, forKey: "sharedContentType")
        sharedDefaults.set(imageUrls, forKey: "sharedImageUrls")
        sharedDefaults.set(videoUrls, forKey: "sharedVideoUrls")
        if let docUrl = documentUrl {
            sharedDefaults.set(docUrl, forKey: "sharedDocumentUrl")
        }
        if let docName = documentName {
            sharedDefaults.set(docName, forKey: "sharedDocumentName")
        }
        if let text = textData {
            sharedDefaults.set(text, forKey: "sharedTextData")
        }
        
        // Force synchronize and verify
        let syncResult = sharedDefaults.synchronize()
        NSLog("📤 [ShareExtension] synchronize() result: \(syncResult)")
        
        // ALSO use CFPreferences for more reliable cross-process sync
        let appGroupID = "group.com.enclosure.data" as CFString
        CFPreferencesSetValue("sharedContentType" as CFString, contentType as CFString, appGroupID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        if let text = textData {
            CFPreferencesSetValue("sharedTextData" as CFString, text as CFString, appGroupID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        }
        let cfSyncResult = CFPreferencesSynchronize(appGroupID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        NSLog("📤 [ShareExtension] Also saved via CFPreferences - sync result: \(cfSyncResult)")
        
        // Verify data was actually saved
        let verifyContentType = sharedDefaults.string(forKey: "sharedContentType")
        let verifyTextData = sharedDefaults.string(forKey: "sharedTextData")
        NSLog("📤 [ShareExtension] Verification - contentType: \(verifyContentType ?? "nil"), textData: \(verifyTextData != nil ? "\(verifyTextData!.count) chars" : "nil")")
        
        if verifyContentType != nil {
            NSLog("✅ [ShareExtension] Saved to UserDefaults successfully - VERIFIED")
        } else {
            NSLog("🚫 [ShareExtension] CRITICAL: Data not found after saving! UserDefaults sync failed!")
        }
        
        // Also try to save to file container if accessible (optional backup method)
        if savedToFile, let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.enclosure.data") {
            NSLog("📤 [ShareExtension] Also saving to file container as backup...")
            NSLog("📤 [ShareExtension] Container path: \(containerURL.path)")
            
            // Create shared data dictionary
            var sharedData: [String: Any] = [
                "sharedContentType": contentType,
                "sharedImageUrls": imageUrls,
                "sharedVideoUrls": videoUrls
            ]
            
            if let docUrl = documentUrl {
                sharedData["sharedDocumentUrl"] = docUrl
            }
            
            if let docName = documentName {
                sharedData["sharedDocumentName"] = docName
            }
            
            if let text = textData {
                sharedData["sharedTextData"] = text
            }
            
            // Save to JSON file in shared container
            let sharedFileURL = containerURL.appendingPathComponent("sharedContent.json")
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: sharedData, options: .prettyPrinted)
                try jsonData.write(to: sharedFileURL, options: .atomic)
                NSLog("✅ [ShareExtension] Successfully saved shared content to file: \(sharedFileURL.path)")
                
                // Verify file was written
                if FileManager.default.fileExists(atPath: sharedFileURL.path) {
                    NSLog("✅ [ShareExtension] File exists and is accessible")
                } else {
                    NSLog("⚠️ [ShareExtension] File was not created (non-critical)")
                }
            } catch {
                NSLog("⚠️ [ShareExtension] Failed to save to file container (non-critical): \(error.localizedDescription)")
                // Don't return - UserDefaults is the primary method
            }
        }
        
        // Small delay to ensure file is written (file container is fast and reliable)
        NSLog("📤 [ShareExtension] Waiting 0.3s before opening main app (file container is ready)...")
        fputs("📤 Waiting 0.3s before openMainApp\n", stderr)
        fflush(stderr)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            // Verify data is still there before opening app
            if let verifyDefaults = UserDefaults(suiteName: "group.com.enclosure.data") {
                let verifyContentType = verifyDefaults.string(forKey: "sharedContentType")
                NSLog("📤 [ShareExtension] Final verification before opening app - contentType: \(verifyContentType ?? "nil")")
                if verifyContentType == nil {
                    NSLog("🚫 [ShareExtension] WARNING: Data lost before opening app!")
                }
            }
            NSLog("📤 [ShareExtension] Calling openMainApp now")
            fputs("📤 Calling openMainApp\n", stderr)
            fflush(stderr)
            self?.openMainApp()
        }
    }
    private func handleLoadedText(data: NSSecureCoding?, error: Error?) {
        if let error = error {
            NSLog("🚫 [ShareExtension] Error loading text: \(error.localizedDescription)")
            return
        }
        
        var loadedText: String?
        
        if let url = data as? URL {
            // Text file
            if let textContent = try? String(contentsOf: url, encoding: .utf8), !textContent.isEmpty {
                loadedText = textContent
                NSLog("📤 [ShareExtension] Loaded text from file: \(textContent.prefix(50))...")
            }
        } else if let string = data as? String, !string.isEmpty {
            // Direct string
            loadedText = string
            NSLog("📤 [ShareExtension] Loaded text from string: \(string.prefix(50))...")
        } else if let textData = data as? Data, let string = String(data: textData, encoding: .utf8), !string.isEmpty {
            // Data that can be decoded as string
            loadedText = string
            NSLog("📤 [ShareExtension] Loaded text from data: \(string.prefix(50))...")
        }
        
        if let loaded = loadedText, !loaded.isEmpty {
            if loadedTextData == nil || loadedTextData!.isEmpty {
                loadedTextData = loaded
            } else {
                loadedTextData = loadedTextData! + "\n" + loaded
            }
            NSLog("📤 [ShareExtension] Text loaded successfully, total length: \(loadedTextData?.count ?? 0)")
        } else {
            NSLog("🚫 [ShareExtension] Could not extract text from data")
        }
    }
    
    func saveToTemp(data: Data, extension ext: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = UUID().uuidString + ".\(ext)"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("🚫 Error saving to temp: \(error)")
            return nil
        }
    }
    
    func copyToTemp(url: URL, extension ext: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = UUID().uuidString + ".\(ext)"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            try FileManager.default.copyItem(at: url, to: fileURL)
            return fileURL
        } catch {
            print("🚫 Error copying to temp: \(error)")
            return nil
        }
    }
    
    // Copy image to permanent location in app's documents directory
    func copyImageToPermanentLocation(sourceUrl: URL) -> URL? {
        return copyFileToPermanentLocation(sourceUrl: sourceUrl, subdirectory: "SharedImages", defaultExtension: "jpg")
    }
    
    // Copy video to permanent location in app's documents directory
    func copyVideoToPermanentLocation(sourceUrl: URL) -> URL? {
        return copyFileToPermanentLocation(sourceUrl: sourceUrl, subdirectory: "SharedVideos", defaultExtension: "mp4")
    }
    
    // Copy document to permanent location in app's documents directory
    func copyDocumentToPermanentLocation(sourceUrl: URL, extension ext: String) -> URL? {
        return copyFileToPermanentLocation(sourceUrl: sourceUrl, subdirectory: "SharedDocuments", defaultExtension: ext)
    }
    
    // Save document data to permanent location
    func saveDocumentDataToPermanentLocation(data: Data, extension ext: String, fileName: String) -> URL? {
        // Use app group container for shared access between extension and main app
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.enclosure.data") else {
            NSLog("🚫 [ShareExtension] Cannot access app group container, using documents directory")
            // Fallback to documents directory
            guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return nil
            }
            let documentsDir = documentsURL.appendingPathComponent("SharedDocuments", isDirectory: true)
            try? FileManager.default.createDirectory(at: documentsDir, withIntermediateDirectories: true)
            let fileURL = documentsDir.appendingPathComponent(fileName)
            
            do {
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try FileManager.default.removeItem(at: fileURL)
                }
                try data.write(to: fileURL)
                NSLog("✅ [ShareExtension] Document data saved to documents: \(fileURL.path)")
                return fileURL
            } catch {
                NSLog("🚫 [ShareExtension] Error saving document data to documents: \(error.localizedDescription)")
                return nil
            }
        }
        
        // Use app group container
        let documentsDir = containerURL.appendingPathComponent("SharedDocuments", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: documentsDir, withIntermediateDirectories: true)
        } catch {
            NSLog("🚫 [ShareExtension] Error creating SharedDocuments directory: \(error.localizedDescription)")
        }
        
        let fileURL = documentsDir.appendingPathComponent(fileName)
        
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            try data.write(to: fileURL)
            NSLog("✅ [ShareExtension] Document data saved to app group container: \(fileURL.path)")
            return fileURL
        } catch {
            NSLog("🚫 [ShareExtension] Error saving document data: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Generic function to copy file to permanent location
    private func copyFileToPermanentLocation(sourceUrl: URL, subdirectory: String, defaultExtension: String) -> URL? {
        // Use app group container for shared access between extension and main app
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.enclosure.data") else {
            NSLog("🚫 [ShareExtension] Cannot access app group container, using documents directory")
            // Fallback to documents directory
            guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return nil
            }
            let targetDir = documentsURL.appendingPathComponent(subdirectory, isDirectory: true)
            try? FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
            let fileExtension = sourceUrl.pathExtension.isEmpty ? defaultExtension : sourceUrl.pathExtension
            let fileName = UUID().uuidString + ".\(fileExtension)"
            let destinationURL = targetDir.appendingPathComponent(fileName)
            
            do {
                // Start accessing security-scoped resource if needed
                let _ = sourceUrl.startAccessingSecurityScopedResource()
                defer { sourceUrl.stopAccessingSecurityScopedResource() }
                
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: sourceUrl, to: destinationURL)
                NSLog("✅ [ShareExtension] File copied to documents (\(subdirectory)): \(destinationURL.path)")
                return destinationURL
            } catch {
                NSLog("🚫 [ShareExtension] Error copying file to documents: \(error.localizedDescription)")
                return nil
            }
        }
        
        // Use app group container
        let targetDir = containerURL.appendingPathComponent(subdirectory, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
        } catch {
            NSLog("🚫 [ShareExtension] Error creating \(subdirectory) directory: \(error.localizedDescription)")
        }
        
        let fileExtension = sourceUrl.pathExtension.isEmpty ? defaultExtension : sourceUrl.pathExtension
        let fileName = UUID().uuidString + ".\(fileExtension)"
        let destinationURL = targetDir.appendingPathComponent(fileName)
        
        do {
            // Start accessing security-scoped resource if needed
            let _ = sourceUrl.startAccessingSecurityScopedResource()
            defer { sourceUrl.stopAccessingSecurityScopedResource() }
            
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceUrl, to: destinationURL)
            NSLog("✅ [ShareExtension] File copied to app group container (\(subdirectory)): \(destinationURL.path)")
            return destinationURL
        } catch {
            NSLog("🚫 [ShareExtension] Error copying file: \(error.localizedDescription)")
            NSLog("🚫 [ShareExtension] Source URL: \(sourceUrl.path)")
            NSLog("🚫 [ShareExtension] Source exists: \(FileManager.default.fileExists(atPath: sourceUrl.path))")
            return nil
        }
    }
    
    func openMainApp() {
        NSLog("🔴🔴🔴 [ShareExtension] openMainApp CALLED 🔴🔴🔴")
        fputs("🔴🔴🔴 openMainApp CALLED\n", stderr)
        fflush(stderr)
        
        guard let url = URL(string: "enclosure://share") else {
            NSLog("🚫 [ShareExtension] Failed to create URL")
            fputs("🚫 Failed to create URL\n", stderr)
            fflush(stderr)
            completeRequest()
            return
        }
        
        NSLog("📤 [ShareExtension] Opening main app with URL: \(url)")
        NSLog("📤 [ShareExtension] Current thread: \(Thread.current)")
        NSLog("📤 [ShareExtension] Is main thread: \(Thread.isMainThread)")
        fputs("📤 Opening URL: \(url)\n", stderr)
        fflush(stderr)
        
        // Use UIApplication.shared.open() directly - more reliable for extensions
        // Extensions can access UIApplication.shared
        if let sharedApp = UIApplication.value(forKeyPath: "sharedApplication") as? UIApplication {
            NSLog("📤 [ShareExtension] Found UIApplication.shared, opening URL...")
            NSLog("📤 [ShareExtension] URL to open: \(url.absoluteString)")
            fputs("📤 [ShareExtension] About to open URL: \(url.absoluteString)\n", stderr)
            fflush(stderr)
            
            // Try opening with completion handler first
            sharedApp.open(url, options: [:]) { [weak self] success in
                NSLog("📤📤📤 [ShareExtension] Open URL completion called - success: \(success)")
                fputs("📤📤📤 [ShareExtension] Open URL result: \(success)\n", stderr)
                fflush(stderr)
                
                if success {
                    NSLog("✅ [ShareExtension] Successfully opened main app with URL scheme")
                    fputs("✅ [ShareExtension] Successfully opened main app\n", stderr)
                    fflush(stderr)
                    // Give the app time to process the URL before completing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self?.completeRequest()
                    }
                } else {
                    NSLog("🚫 [ShareExtension] Failed to open main app - URL scheme might not be registered")
                    fputs("🚫 [ShareExtension] Failed to open main app\n", stderr)
                    fflush(stderr)
                    // Try alternative method
                    NSLog("📤 [ShareExtension] Trying alternative open method...")
                    if sharedApp.canOpenURL(url) {
                        sharedApp.open(url)
                        NSLog("📤 [ShareExtension] Called open() without completion handler")
                    }
                    // Still complete request even if opening failed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.completeRequest()
                    }
                }
            }
        } else {
            NSLog("🚫 [ShareExtension] Could not access UIApplication.shared")
            // Fallback: try responder chain
            var responder: UIResponder? = self
            while responder != nil {
                if let application = responder as? UIApplication {
                    NSLog("📤 [ShareExtension] Found UIApplication via responder chain")
                    application.open(url) { [weak self] success in
                        NSLog("📤 [ShareExtension] Open URL result: \(success)")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self?.completeRequest()
                        }
                    }
                    return
                }
                responder = responder?.next
            }
            NSLog("🚫 [ShareExtension] Could not find UIApplication - completing request anyway")
            completeRequest()
        }
    }
    
    @objc func openURL(_ url: URL) {
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, options: [:]) { [weak self] success in
                    print("📤 [ShareExtension] Open URL result: \(success)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self?.completeRequest()
                    }
                }
                return
            }
            responder = responder?.next
        }
        completeRequest()
    }
    
    func completeRequest() {
        NSLog("🔴 [ShareExtension] completeRequest CALLED")
        fputs("🔴 completeRequest CALLED\n", stderr)
        fflush(stderr)
        
        // Use stored context or extensionContext property
        let context = storedExtensionContext ?? extensionContext
        if let context = context {
            context.completeRequest(returningItems: [], completionHandler: nil)
        } else {
            NSLog("🚫 [ShareExtension] No context available to complete request")
        }
    }
}
