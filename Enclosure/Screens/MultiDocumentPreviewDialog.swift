//
//  MultiDocumentPreviewDialog.swift
//  Enclosure
//
//  Created by Ram Lohar on 30/04/25.
//

import SwiftUI
import UniformTypeIdentifiers
import QuickLook
import FirebaseStorage

struct MultiDocumentPreviewDialog: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    let selectedDocuments: [URL]
    @Binding var caption: String
    let contact: UserActiveContactModel
    let onSend: (String) -> Void
    let onDismiss: () -> Void
    
    @State private var currentIndex: Int = 0
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isCaptionFocused: Bool
    
    // Typography (match Android messageBox sizing prefs)
    private var messageInputFont: Font {
        let pref = UserDefaults.standard.string(forKey: "Font_Size") ?? "medium"
        let size: CGFloat
        switch pref {
        case "small":
            size = 13
        case "large":
            size = 19
        default:
            size = 16
        }
        return .custom("Inter18pt-Regular", size: size)
    }
    
    var body: some View {
        ZStack {
            // Full-screen background (matching Android transparent background)
            Color.black
                .ignoresSafeArea()
            
            if selectedDocuments.isEmpty {
                // Show loading or error if no documents
                VStack {
                    Text("No documents selected")
                        .foregroundColor(.white)
                }
            } else {
                VStack(spacing: 0) {
                    // Top bar with back button and document count (matching Android header)
                    HStack {
                        // Back button
                        Button(action: {
                            // Light haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            onDismiss()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                
                                Image("leftvector")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 25, height: 18)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.leading, 16)
                        
                        Spacer()
                        
                        // Document count indicator (matching Android counter) - always show
                        Text("\(currentIndex + 1) / \(selectedDocuments.count)")
                            .font(.custom("Inter18pt-Medium", size: 16))
                            .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Spacer to balance layout (send button is in bottom caption bar)
                    Spacer()
                        .frame(width: 40)
                }
                .frame(height: 60)
                .background(Color.black.opacity(0.3))
                
                // Document preview area (matching Android document preview)
                GeometryReader { geometry in
                    TabView(selection: $currentIndex) {
                        ForEach(Array(selectedDocuments.enumerated()), id: \.element) { index, documentURL in
                            DocumentPreviewItem(documentURL: documentURL)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                }
                
                // Spacing between document and caption area (5px)
                Spacer()
                    .frame(height: 5)
                
                // Bottom caption input area (matching WhatsAppLikeImagePicker captionBarView design)
                HStack(spacing: 0) {
                    // Caption input container (matching messageBox design from WhatsAppLikeImagePicker)
                    HStack(spacing: 0) {
                        // Message input field container - layout_weight="1"
                        VStack(alignment: .leading, spacing: 0) {
                            ZStack(alignment: .leading) {
                                // Placeholder text (matching Android textColorHint="#9EA6B9")
                                if caption.isEmpty {
                                    Text("Add Caption")
                                        .font(.custom("Inter18pt-Medium", size: 17))
                                        .foregroundColor(Color(hex: "#9EA6B9"))
                                        .padding(.leading, 15)
                                        .padding(.trailing, 20)
                                        .padding(.top, 5)
                                        .padding(.bottom, 5)
                                }
                                
                                // TextField (matching Android EditText properties)
                                TextField("", text: $caption, axis: .vertical)
                                    .font(.custom("Inter18pt-Medium", size: 17)) // textSize="17sp", textFontWeight="500"
                                    .foregroundColor(.white) // textColor="@color/white"
                                    .lineLimit(4) // maxLines="4"
                                    .lineSpacing(4) // lineHeight="21dp" (21 - 17 = 4dp spacing)
                                    .frame(maxWidth: 180, alignment: .leading) // maxWidth="180dp"
                                    .padding(.leading, 15) // paddingStart="15dp"
                                    .padding(.trailing, 20) // paddingEnd="20dp"
                                    .padding(.top, 5) // paddingTop="5dp"
                                    .padding(.bottom, 5) // paddingBottom="5dp"
                                    .background(Color.clear) // background="#00000000"
                                    .focused($isCaptionFocused)
                                    .accentColor(Color("black_white_crossEmoji")) // textColorHighlight
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 50) // Match send button height (50dp)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(hex: "#1B1C1C")) // Use specified color for caption message box
                    )
                    .padding(.leading, 10)
                    .padding(.trailing, 5)
                    
                    // Send button group (matching sendGrpLyt from WhatsAppLikeImagePicker)
                    VStack(spacing: 0) {
                        Button(action: {
                            // Light haptic feedback (guarded to avoid errors on unsupported devices)
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.prepare()
                            generator.impactOccurred()
                            
                            // Dismiss keyboard first to avoid constraint warnings
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            
                            let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
                            print("MultiDocumentPreviewDialog: Send button clicked - Caption: '\(trimmedCaption)' (length: \(trimmedCaption.count))")
                            
                            // Small delay to let keyboard dismiss animation complete
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                self.handleMultiDocumentSend(caption: trimmedCaption)
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: Constant.themeColor))
                                    .frame(width: 50, height: 50)
                                
                                // Send icon (keyboard double arrow right) - same as Android
                                Image("baseline_keyboard_double_arrow_right_24")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 26, height: 26)
                                    .foregroundColor(.white)
                                    .padding(.top, 4)
                                    .padding(.bottom, 8)
                            }
                        }
                    }
                    .padding(.horizontal, 5)
                }
                .padding(.bottom, keyboardHeight > 0 ? keyboardHeight - 20 : 10)
                .background(Color.black)
                }
            }
        }
        .onAppear {
            print("MultiDocumentPreviewDialog: onAppear - documents count: \(selectedDocuments.count)")
            print("MultiDocumentPreviewDialog: documents: \(selectedDocuments.map { $0.lastPathComponent })")
            print("MultiDocumentPreviewDialog: onAppear - Initial caption: '\(caption)' (length: \(caption.count))")
            setupKeyboardObservers()
        }
        .onDisappear {
            removeKeyboardObservers()
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded { value in
                    // Handle swipe down to dismiss (optional)
                    if value.translation.height > 100 {
                        onDismiss()
                    }
                }
        )
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            keyboardHeight = 0
        }
    }
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Document Upload Functions (matching Android sendMultipleDocuments)
    
    enum MultiDocumentUploadError: Error {
        case fileNotFound
        case dataUnavailable
        case downloadURLMissing
        case uploadFailed(String)
    }
    
    private func handleMultiDocumentSend(caption: String) {
        print("MultiDocumentPreviewDialog: === MULTI-DOCUMENT SEND ===")
        print("MultiDocumentPreviewDialog: Selected documents count: \(selectedDocuments.count)")
        print("MultiDocumentPreviewDialog: Caption: '\(caption)'")
        
        guard !selectedDocuments.isEmpty else {
            print("MultiDocumentPreviewDialog: No documents selected, returning")
            return
        }
        
        // Close the preview dialog
        onDismiss()
        
        let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let receiverUid = contact.uid
        let senderId = Constant.SenderIdMy
        let userName = UserDefaults.standard.string(forKey: Constant.full_name) ?? ""
        let micPhoto = UserDefaults.standard.string(forKey: Constant.profilePic) ?? ""
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "hh:mm a"
        let currentDateTimeString = timeFormatter.string(from: Date())
        
        let currentDateFormatter = DateFormatter()
        currentDateFormatter.dateFormat = "yyyy-MM-dd"
        let currentDateString = currentDateFormatter.string(from: Date())
        
        let timestamp = Date().timeIntervalSince1970
        
        // Upload all documents to Firebase Storage, then push to API + RTDB
        let dispatchGroup = DispatchGroup()
        let lockQueue = DispatchQueue(label: "com.enclosure.multiDocumentUpload.lock")
        
        struct UploadedDocumentResult {
            let index: Int
            let downloadURL: String
            let fileName: String
            let fileSize: Int64
            let fileExtension: String
        }
        
        var uploadResults: [UploadedDocumentResult] = []
        var uploadErrors: [Error] = []
        
        for (index, documentURL) in selectedDocuments.enumerated() {
            dispatchGroup.enter()
            
            // Verify file exists
            guard FileManager.default.fileExists(atPath: documentURL.path) else {
                lockQueue.sync { uploadErrors.append(MultiDocumentUploadError.fileNotFound) }
                dispatchGroup.leave()
                continue
            }
            
            let fileName = documentURL.lastPathComponent
            let fileExtension = getFileExtension(from: fileName)
            let documentModelId = UUID().uuidString
            let remoteFileName = "\(documentModelId).\(fileExtension)"
            
            // Get file size
            let fileSize: Int64
            if let attributes = try? FileManager.default.attributesOfItem(atPath: documentURL.path),
               let size = attributes[.size] as? Int64 {
                fileSize = size
            } else {
                fileSize = 0
            }
            
            // Read file data
            guard let fileData = try? Data(contentsOf: documentURL) else {
                lockQueue.sync { uploadErrors.append(MultiDocumentUploadError.dataUnavailable) }
                dispatchGroup.leave()
                continue
            }
            
            // Upload to Firebase Storage
            uploadDocumentToFirebase(data: fileData, remoteFileName: remoteFileName, mimeType: getMimeType(for: fileExtension)) { uploadResult in
                switch uploadResult {
                case .failure(let error):
                    lockQueue.sync { uploadErrors.append(error) }
                    dispatchGroup.leave()
                case .success(let downloadURL):
                    let result = UploadedDocumentResult(
                        index: index,
                        downloadURL: downloadURL,
                        fileName: fileName,
                        fileSize: fileSize,
                        fileExtension: fileExtension
                    )
                    lockQueue.sync { uploadResults.append(result) }
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            if uploadResults.isEmpty {
                print("❌ [MULTI_DOCUMENT] Upload failed - no results")
                Constant.showToast(message: "Unable to upload documents. Please try again.")
                return
            }
            
            if !uploadErrors.isEmpty {
                print("⚠️ [MULTI_DOCUMENT] Some uploads failed: \(uploadErrors.count) errors")
            }
            
            let sortedResults = uploadResults.sorted { $0.index < $1.index }
            
            // Send each document as a separate message (matching Android behavior)
            // Only first document gets caption, others get empty caption
            for (index, result) in sortedResults.enumerated() {
                let documentModelId = UUID().uuidString
                let documentCaption = (index == 0) ? trimmedCaption : ""
                
                print("MultiDocumentPreviewDialog: Creating ChatMessage \(index + 1)/\(sortedResults.count) with caption: '\(documentCaption)'")
                
                let newMessage = ChatMessage(
                    id: documentModelId,
                    uid: senderId,
                    message: documentCaption,
                    time: currentDateTimeString,
                    document: result.downloadURL,
                    dataType: Constant.doc,
                    fileExtension: result.fileExtension,
                    name: nil,
                    phone: nil,
                    micPhoto: micPhoto,
                    miceTiming: nil,
                    userName: userName,
                    receiverId: receiverUid,
                    replytextData: nil,
                    replyKey: nil,
                    replyType: nil,
                    replyOldData: nil,
                    replyCrtPostion: nil,
                    forwaredKey: nil,
                    groupName: nil,
                    docSize: "\(result.fileSize)",
                    fileName: result.fileName,
                    thumbnail: nil,
                    fileNameThumbnail: nil,
                    caption: documentCaption,
                    notification: 1,
                    currentDate: currentDateString,
                    emojiModel: [EmojiModel(name: "", emoji: "")],
                    emojiCount: nil,
                    timestamp: timestamp,
                    imageWidth: nil,
                    imageHeight: nil,
                    aspectRatio: nil,
                    selectionCount: "1",
                    selectionBunch: nil,
                    receiverLoader: 0
                )
                
                print("MultiDocumentPreviewDialog: ChatMessage created with caption: '\(newMessage.caption ?? "nil")'")
                
                let userFTokenKey = UserDefaults.standard.string(forKey: Constant.FCM_TOKEN) ?? ""
                
                MessageUploadService.shared.uploadMessage(
                    model: newMessage,
                    filePath: nil,
                    userFTokenKey: userFTokenKey,
                    deviceType: "2"
                ) { success, errorMessage in
                    if success {
                        print("✅ [MULTI_DOCUMENT] Uploaded document \(index + 1)/\(sortedResults.count) for modelId=\(documentModelId)")
                    } else {
                        print("❌ [MULTI_DOCUMENT] Upload error: \(errorMessage ?? "Unknown error")")
                        Constant.showToast(message: "Failed to send document. Please try again.")
                    }
                }
            }
            
            // Call the original onSend callback for any additional handling
            onSend(trimmedCaption)
        }
    }
    
    // Upload document to Firebase Storage
    private func uploadDocumentToFirebase(data: Data, remoteFileName: String, mimeType: String, completion: @escaping (Result<String, Error>) -> Void) {
        let storagePath = "\(Constant.CHAT)/\(Constant.SenderIdMy)_\(contact.uid)/\(remoteFileName)"
        let ref = Storage.storage().reference().child(storagePath)
        let metadata = StorageMetadata()
        metadata.contentType = mimeType
        
        ref.putData(data, metadata: metadata) { _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            ref.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let url = url else {
                    completion(.failure(MultiDocumentUploadError.downloadURLMissing))
                    return
                }
                
                completion(.success(url.absoluteString))
            }
        }
    }
    
    // Get file extension from filename
    private func getFileExtension(from fileName: String) -> String {
        if let lastDotIndex = fileName.lastIndex(of: ".") {
            let extensionStart = fileName.index(after: lastDotIndex)
            return String(fileName[extensionStart...]).lowercased()
        }
        return ""
    }
    
    // Get MIME type from file extension
    private func getMimeType(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "pdf": return "application/pdf"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls": return "application/vnd.ms-excel"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "ppt": return "application/vnd.ms-powerpoint"
        case "pptx": return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "txt": return "text/plain"
        case "rtf": return "application/rtf"
        case "zip": return "application/zip"
        case "rar": return "application/x-rar-compressed"
        case "7z": return "application/x-7z-compressed"
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        default: return "application/octet-stream"
        }
    }
}

// MARK: - Document Preview Item (matching Android item_document_preview.xml)
struct DocumentPreviewItem: View {
    let documentURL: URL
    
    @State private var fileSize: String = ""
    @State private var fileName: String = ""
    @State private var fileIcon: String = "documentsvg"
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Document Name (matching Android documentName TextView)
                Text(fileName)
                    .font(.custom("Inter18pt-Medium", size: 22))
                    .foregroundColor(Color("gray3"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .lineLimit(3)
                
                // Size Label (matching Android "size" TextView)
                Text("size")
                    .font(.custom("Inter18pt-Medium", size: 17))
                    .foregroundColor(Color("gray3"))
                    .padding(.horizontal, 30)
                    .padding(.top, 5)
                    .padding(.vertical, 10)
                
                // Document Size (matching Android documentSize TextView)
                Text(fileSize)
                    .font(.custom("Inter18pt-Medium", size: 17))
                    .foregroundColor(Color("gray3"))
                    .padding(.horizontal, 30)
                    .padding(.top, 5)
                    .padding(.bottom, 10)
                
                // Document Icon (matching Android documentIcon ImageView)
                Image(fileIcon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(Color("gray3"))
                    .padding(.top, 5)
                
                Spacer()
            }
        }
        .onAppear {
            loadDocumentInfo()
        }
    }
    
    private func loadDocumentInfo() {
        // Get file name
        fileName = documentURL.lastPathComponent
        
        // Get file size
        if let attributes = try? FileManager.default.attributesOfItem(atPath: documentURL.path),
           let size = attributes[.size] as? Int64 {
            fileSize = formatFileSize(size)
        } else {
            fileSize = "Unknown"
        }
        
        // Determine icon based on file type
        fileIcon = getFileIcon(for: documentURL)
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func getFileIcon(for url: URL) -> String {
        let pathExtension = url.pathExtension.lowercased()
        
        // Check if it's an image
        if ["jpg", "jpeg", "png", "gif", "heic", "heif", "webp"].contains(pathExtension) {
            return "gallery"
        }
        
        // Check if it's a video
        if ["mp4", "mov", "avi", "m4v", "mkv"].contains(pathExtension) {
            return "videopng"
        }
        
        // Check if it's a PDF
        if pathExtension == "pdf" {
            return "documentsvg"
        }
        
        // Check if it's audio
        if ["mp3", "wav", "m4a", "aac"].contains(pathExtension) {
            return "mikesvg" // Use mic icon for audio
        }
        
        // Default to document icon
        return "documentsvg"
    }
}

