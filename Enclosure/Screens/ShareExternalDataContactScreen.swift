//
//  ShareExternalDataContactScreen.swift
//  Enclosure
//
//  Created by Ram Lohar on 30/04/25.
//

import SwiftUI
import AVFoundation
import AVKit

struct ShareExternalDataContactScreen: View {
    let sharedContent: SharedContent
    let caption: String
    var onNavigateToChat: ((UserActiveContactModel) -> Void)? = nil // Callback to navigate to chat screen
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @StateObject private var viewModel = ChatViewModel()
    @State private var selectedContactIds: Set<String> = []
    @State private var isLoading: Bool = true
    @State private var searchText: String = ""
    @State private var isSharing: Bool = false
    @State private var isPressed: Bool = false
    @FocusState private var isSearchFocused: Bool
    
    // Preview dialog states (matching ChattingScreen)
    @State private var showImagePreview: Bool = false
    @State private var showVideoPreview: Bool = false
    @State private var showDocumentPreview: Bool = false
    @State private var previewCaption: String = ""
    @State private var contactsToShareWith: [UserActiveContactModel] = []
    
    // Filter out blocked users (matching Android setAdapter logic)
    private var availableContacts: [UserActiveContactModel] {
        viewModel.chatList.filter { !$0.block }
    }
    
    private var filteredContacts: [UserActiveContactModel] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return availableContacts
        }
        
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return availableContacts.filter { contact in
            contact.fullName.lowercased().contains(trimmed) ||
            contact.mobileNo.contains(trimmed)
        }
    }
    
    // Selected contacts for display (matching Android forwardnameAdapter)
    private var selectedContacts: [UserActiveContactModel] {
        filteredContacts.filter { selectedContactIds.contains($0.uid) }
    }
    
    // Helper function to hide keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    var body: some View {
        ZStack {
            // Background matching Android BackgroundColor style
            Color("background_color")
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    hideKeyboard()
                }
            
            VStack(spacing: 0) {
                // Header section (matching Android searchlyt)
                VStack(spacing: 0) {
                    // Top bar with cancel button and "Contacts" text (matching Android)
                    HStack(spacing: 0) {
                        // Cancel button (matching Android backarrow LinearLayout)
                        Button(action: {
                            handleCancel()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color("circlebtnhover").opacity(0.1))
                                    .frame(width: 26, height: 26)
                                
                                Image("leftvector")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 25, height: 18)
                                    .foregroundColor(Color("TextColor"))
                                    .padding(2)
                            }
                        }
                        .padding(.leading, 20) // layout_marginStart="20dp"
                        
                        // "Contacts" text (matching Android theme TextView)
                        Text("Contacts")
                            .font(.custom("Inter18pt-Medium", size: 16))
                            .fontWeight(.medium)
                            .foregroundColor(Color("TextColor"))
                            .padding(.leading, 21) // layout_marginStart="21dp"
                        
                        Spacer()
        }
                    .padding(.top, 20) // layout_marginTop="20dp"
                    .padding(.trailing, 17) // layout_marginEnd="17dp"
                    
                    // Network loader (matching Android networkLoader)
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(LinearProgressViewStyle(tint: Color("TextColor")))
                            .frame(height: 4)
                            .padding(.top, 10) // layout_marginTop="10dp"
                    }
                    
                    // Search bar (matching Android searchLytNew LinearLayout)
                    // layout_marginTop="20dp" padding="8dp" layout_weight="1" layout_marginEnd="10dp"
                    HStack {
                        // Blue indicator line (matching Android viewnewnn)
                        Rectangle()
                            .fill(Color("blue"))
                            .frame(width: 1, height: 19.24) // layout_height="19.24dp"
                            .padding(.leading, 13)
                    
                        // Search field (matching Android searchview AutoCompleteTextView)
                        TextField("Search Name", text: $searchText)
                            .font(.custom("Inter18pt-Regular", size: 15)) // textSize="15sp"
                            .foregroundColor(Color("TextColor"))
                            .focused($isSearchFocused)
                            .lineSpacing(0) // lineHeight="22.5dp"
                            .padding(.leading, 13)
            }
                    .padding(.top, 20) // layout_marginTop="20dp"
                    .padding(.leading, 8) // padding="8dp" (left only)
                    .padding(.trailing, 20) // Same right spacing as checkbox (20dp)
        }
                .padding(.horizontal, 0)
    
                // Contact List (matching Android recyclerview in FrameLayout)
                // FrameLayout: layout_below="@+id/searchlyt" layout_above="@id/dx" layout_marginTop="15dp"
        ScrollView {
            LazyVStack(spacing: 0) {
                        if isLoading && filteredContacts.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 50)
                } else if filteredContacts.isEmpty {
                    Text("No contacts found")
                        .font(.custom("Inter18pt-Regular", size: 16))
                        .foregroundColor(Color("gray3"))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 50)
                } else {
                    ForEach(filteredContacts) { contact in
                        ShareContactRowView(
                            contact: contact,
                            isSelected: selectedContactIds.contains(contact.uid),
                                    canSelect: true, // Always allow selection for share
                            onTap: {
                                toggleSelection(for: contact)
                            }
                        )
                    }
                }
            }
                }
                .padding(.top, 15) // layout_marginTop="15dp" on FrameLayout
                
                Spacer()
                
                // Bottom bar (matching Android dx LinearLayout)
                // layout_height="60dp" background="@drawable/rect" backgroundTint="@color/dxForward"
                if !selectedContactIds.isEmpty {
        HStack(spacing: 0) {
                        // Selected contacts names (matching Android namerecyclerview with forwardnameAdapter)
                        // Infinite width, keep left to the icon
                        // layout_marginStart="15dp" layout_marginEnd="5dp"
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(selectedContacts.enumerated()), id: \.element.uid) { index, contact in
                                    // Each name displayed as separate item (matching forwardname_row.xml)
                                    Text(displaySelectedContactName(contact: contact, index: index, total: selectedContacts.count))
                                        .font(.custom("Inter18pt-Medium", size: 13)) // textSize="13sp" fontFamily="@font/inter_medium"
                                        .foregroundColor(Color("gray3")) // textColor="@color/gray3"
                                .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false) // wrap_content width
                                }
                            }
                            .padding(.leading, 15) // layout_marginStart="15dp"
                            .padding(.trailing, 5) // layout_marginEnd="5dp"
                        }
                        .frame(height: 40) // layout_height="40dp"
                        .frame(maxWidth: .infinity) // Infinite width - takes all available space
                        
                        // Share icon (positioned after names, before button)
                        Image("forward_svg")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundColor(Color("TextColor"))
                            .padding(.trailing, 2) // Keep it close to the forbg button
                        
                        // Share button container (matching Android richBox LinearLayout)
                        // android:layout_width="match_parent" android:layout_height="match_parent"
                        // android:layout_marginTop="11dp" android:layout_marginBottom="7dp"
                        // android:background="@drawable/forbg"
            Button(action: {
                handleShare()
            }) {
                if isSharing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color("whitetogray")))
                                    .frame(maxWidth: .infinity)
                                    .frame(maxHeight: .infinity)
                } else {
                                // TextView inside richBox (matching Android forward TextView)
                                // android:layout_width="match_parent" android:layout_height="wrap_content"
                                // android:layout_gravity="center" android:gravity="center"
                                // android:layout_marginStart="15dp"
                    Text("Share")
                                    .font(.custom("Inter18pt-Regular", size: 16)) // android:fontFamily="@font/inter" android:textSize="16sp"
                                    .fontWeight(.bold) // android:textStyle="bold"
                                    .foregroundColor(Color("whitetogray")) // android:textColor="@color/whitetogray"
                                    .padding(.leading, 15) // android:layout_marginStart="15dp"
                                    .frame(maxWidth: .infinity) // android:layout_width="match_parent"
                                    .frame(maxHeight: .infinity) // android:layout_height="wrap_content" with layout_gravity="center"
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 80) // Fixed width 80px
            .background(
                            // Background using original forbg asset from drawable (trapezoidal shape with angled left edge)
                            Image("forbg")
                                .resizable()
                                .scaledToFill()
            )
                        .padding(.top, 11) // android:layout_marginTop="11dp"
                        .padding(.bottom, 7) // android:layout_marginBottom="7dp"
            .disabled(isSharing)
        }
                    .frame(height: 60) // layout_height="60dp"
                    .background(
                        // Background matching Android @drawable/rect with @color/dxForward tint
                        // android:background="@drawable/rect" android:backgroundTint="@color/dxForward"
                        Color("dxForward")
                    )
                }
            }
        }
        .navigationBarHidden(true)
        .background(NavigationGestureEnabler())
        .fullScreenCover(isPresented: $showImagePreview) {
            ShareImagePreviewDialog(
                imageUrls: sharedContent.imageUrls,
                caption: $previewCaption,
                onSend: { finalCaption in
                    sendImagesToContacts(selectedContacts: contactsToShareWith, caption: finalCaption)
                },
                onDismiss: {
                    showImagePreview = false
                    isSharing = false
                }
            )
            .onAppear {
                NSLog("🖼️ [SHARE_IMAGE_PREVIEW] Dialog appeared")
                NSLog("🖼️ [SHARE_IMAGE_PREVIEW] Image URLs count: \(sharedContent.imageUrls.count)")
                for (index, url) in sharedContent.imageUrls.enumerated() {
                    NSLog("🖼️ [SHARE_IMAGE_PREVIEW] Image \(index): \(url.path)")
                    NSLog("🖼️ [SHARE_IMAGE_PREVIEW] Image \(index) exists: \(FileManager.default.fileExists(atPath: url.path))")
                }
            }
        }
        .fullScreenCover(isPresented: $showVideoPreview) {
            ShareVideoPreviewDialog(
                videoUrls: sharedContent.videoUrls,
                caption: $previewCaption,
                onSend: { finalCaption in
                    sendVideosToContacts(selectedContacts: contactsToShareWith, caption: finalCaption)
                },
                onDismiss: {
                    showVideoPreview = false
                    isSharing = false
                }
            )
        }
        .fullScreenCover(isPresented: $showDocumentPreview) {
            ShareDocumentPreviewDialog(
                documentUrl: sharedContent.documentUrl,
                documentName: sharedContent.documentName,
                caption: $previewCaption,
                onSend: { finalCaption in
                    sendDocumentsToContacts(selectedContacts: contactsToShareWith, caption: finalCaption)
                },
                onDismiss: {
                    showDocumentPreview = false
                    isSharing = false
                }
            )
        }
        .onAppear {
            loadContacts()
        }
        .onChange(of: viewModel.isLoading) { loading in
            if !loading {
                isLoading = false
            }
        }
        .onChange(of: viewModel.chatList.count) { count in
            if count > 0 {
                isLoading = false
            }
        }
    }
    
    // Display selected contact name (matching Android forwardnameAdapter logic)
    // Android format: "Name1 , Name2 , Name3" (with spaces around comma, last name without comma)
    private func displaySelectedContactName(contact: UserActiveContactModel, index: Int, total: Int) -> String {
        if total == 1 {
            return contact.fullName
        } else if total > 1 {
            if index == total - 1 {
                // Last item: just the name
                return contact.fullName
            } else {
                // Not last: name + " , " (matching Android: model.getName()+" "+","+" ")
                return contact.fullName + " , "
            }
        }
        return contact.fullName
    }
    
    // MARK: - Helper Functions
    private func loadContacts() {
        isLoading = true
        viewModel.fetchChatList(uid: Constant.SenderIdMy)
        
        // Check loading state after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if !viewModel.isLoading {
                isLoading = false
            }
        }
        
        // Also observe when chatList is populated
        if !viewModel.chatList.isEmpty {
            isLoading = false
        }
    }
    
    private func handleCancel() {
        if isSearchFocused {
            isSearchFocused = false
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        } else {
            withAnimation {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                dismiss()
                isPressed = false
            }
        }
    }
    
    private func toggleSelection(for contact: UserActiveContactModel) {
        if selectedContactIds.contains(contact.uid) {
            selectedContactIds.remove(contact.uid)
        } else {
            selectedContactIds.insert(contact.uid)
        }
    }
    
    private func handleShare() {
        guard !selectedContactIds.isEmpty else { return }
        
        let selectedContacts = availableContacts.filter { selectedContactIds.contains($0.uid) }
        
        guard !isSharing else { return }
        
        isSharing = true
        
        // Handle sharing based on content type (matching Android forward button logic)
        switch sharedContent.type {
        case .text:
            // Text sharing - send directly without preview (matching Android sendText)
            sendTextToContacts(selectedContacts: selectedContacts)
        case .image:
            // Image sharing - show preview first (matching Android setupMultiImagePreview)
            NSLog("🖼️ [SHARE_HANDLE] Image share triggered")
            NSLog("🖼️ [SHARE_HANDLE] Image URLs count: \(sharedContent.imageUrls.count)")
            for (index, url) in sharedContent.imageUrls.enumerated() {
                NSLog("🖼️ [SHARE_HANDLE] Image URL \(index): \(url)")
                NSLog("🖼️ [SHARE_HANDLE] Image URL \(index) path: \(url.path)")
                NSLog("🖼️ [SHARE_HANDLE] Image URL \(index) exists: \(FileManager.default.fileExists(atPath: url.path))")
            }
            contactsToShareWith = selectedContacts
            previewCaption = caption
            NSLog("🖼️ [SHARE_HANDLE] Setting showImagePreview = true")
            showImagePreview = true
        case .video:
            // Video sharing - show preview first (matching Android setupMultiVideoPreview)
            contactsToShareWith = selectedContacts
            previewCaption = caption
            showVideoPreview = true
        case .document:
            // Document sharing - show preview first
            contactsToShareWith = selectedContacts
            previewCaption = caption
            showDocumentPreview = true
        case .contact:
            // Contact sharing - send contacts to contacts
            if let contactInfo = sharedContent.contact {
                sendContactToContacts(contactInfo: contactInfo, selectedContacts: selectedContacts)
            }
        }
    }
    
    // MARK: - Sharing Functions (matching Android sendText, sendMultiImages, etc.)
    
    private func sendTextToContacts(selectedContacts: [UserActiveContactModel]) {
        guard let textData = sharedContent.textData, !textData.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Constant.showToast(message: "No text to share")
            isSharing = false
            return
        }
        
        let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let senderId = Constant.SenderIdMy
        let userName = UserDefaults.standard.string(forKey: Constant.full_name) ?? ""
        let micPhoto = UserDefaults.standard.string(forKey: Constant.profilePic) ?? ""
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "hh:mm a"
        let currentTimeString = timeFormatter.string(from: Date())
        
        let timestamp = Date().timeIntervalSince1970
        let userFTokenKey = UserDefaults.standard.string(forKey: Constant.FCM_TOKEN) ?? ""
        
        // Send to each selected contact
        for (index, contact) in selectedContacts.enumerated() {
            let modelId = UUID().uuidString
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let currentDateString = dateFormatter.string(from: Date())
            
            let chatMessage = ChatMessage(
                id: modelId,
                uid: senderId,
                message: textData,
                time: currentTimeString,
                document: "",
                dataType: Constant.Text,
                fileExtension: nil,
                name: nil,
                phone: nil,
                micPhoto: micPhoto,
                miceTiming: nil,
                userName: userName,
                receiverId: contact.uid,
                replytextData: nil,
                replyKey: nil,
                replyType: nil,
                replyOldData: nil,
                replyCrtPostion: nil,
                forwaredKey: nil,
                groupName: nil,
                docSize: nil,
                fileName: nil,
                thumbnail: nil,
                fileNameThumbnail: nil,
                caption: trimmedCaption.isEmpty ? nil : trimmedCaption,
                notification: 1,
                currentDate: currentDateString,
                emojiModel: nil,
                emojiCount: nil,
                timestamp: timestamp,
                imageWidth: nil,
                imageHeight: nil,
                aspectRatio: nil,
                selectionCount: nil,
                selectionBunch: nil,
                receiverLoader: 0,
                linkTitle: nil,
                linkDescription: nil,
                linkImageUrl: nil,
                favIconUrl: nil
            )
            
            // Store in SQLite
            DatabaseHelper.shared.insertPendingMessage(chatMessage)
            
            // Upload message
            MessageUploadService.shared.uploadMessage(
                model: chatMessage,
                filePath: nil,
                userFTokenKey: userFTokenKey
            ) { success, errorMessage in
                if success {
                    print("✅ [SHARE_TEXT] Sent text to \(contact.fullName) (\(index + 1)/\(selectedContacts.count))")
                } else {
                    print("🚫 [SHARE_TEXT] Failed to send to \(contact.fullName): \(errorMessage ?? "Unknown error")")
                }
                
                // Check if all messages sent
                if index == selectedContacts.count - 1 {
                    DispatchQueue.main.async {
                        self.isSharing = false
                        
                        // If sending to single contact, navigate to ChattingScreen (matching Android behavior)
                        if selectedContacts.count == 1, let firstContact = selectedContacts.first {
                            // Navigate to chat screen for single contact
                        self.dismiss()
                            // Small delay to ensure dismiss completes before navigation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onNavigateToChat?(firstContact)
                            }
                        } else {
                            // Multiple contacts - just dismiss (no toast, matching Android)
                            self.dismiss()
                        }
                    }
                }
            }
        }
    }
    
    private func sendImagesToContacts(selectedContacts: [UserActiveContactModel], caption: String = "") {
        guard !sharedContent.imageUrls.isEmpty else {
            Constant.showToast(message: "No images to share")
        isSharing = false
            return
        }
        
        let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let senderId = Constant.SenderIdMy
        let userName = UserDefaults.standard.string(forKey: Constant.full_name) ?? ""
        let micPhoto = UserDefaults.standard.string(forKey: Constant.profilePic) ?? ""
        let userFTokenKey = UserDefaults.standard.string(forKey: Constant.FCM_TOKEN) ?? ""
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "hh:mm a"
        let currentTimeString = timeFormatter.string(from: Date())
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let currentDateString = dateFormatter.string(from: Date())
        
        let timestamp = Date().timeIntervalSince1970
        
        var totalMessages = 0
        var completedMessages = 0
        var failedMessages = 0
        
        // Send each image to each contact
        // Only first image gets caption (matching Android/MultiDocumentPreviewDialog behavior)
        for (contactIndex, contact) in selectedContacts.enumerated() {
            for (imageIndex, imageUrl) in sharedContent.imageUrls.enumerated() {
                totalMessages += 1
                let modelId = UUID().uuidString
                let fileName = "\(modelId).jpg"
                
                // Only first image gets caption (matching MultiDocumentPreviewDialog: index == 0)
                let imageCaption = (imageIndex == 0) ? trimmedCaption : ""
                
                // Create message (matching Android sendMultiImages logic)
                let chatMessage = ChatMessage(
                    id: modelId,
                    uid: senderId,
                    message: "",
                    time: currentTimeString,
                    document: imageUrl.path, // Local file path
                    dataType: Constant.img,
                    fileExtension: "jpg",
                    name: nil,
                    phone: nil,
                    micPhoto: micPhoto,
                    miceTiming: nil,
                    userName: userName,
                    receiverId: contact.uid,
                    replytextData: nil,
                    replyKey: nil,
                    replyType: nil,
                    replyOldData: nil,
                    replyCrtPostion: nil,
                    forwaredKey: nil,
                    groupName: nil,
                    docSize: nil,
                    fileName: fileName,
                    thumbnail: nil,
                    fileNameThumbnail: nil,
                    caption: imageCaption.isEmpty ? nil : imageCaption,
                    notification: 1,
                    currentDate: currentDateString,
                    emojiModel: nil,
                    emojiCount: nil,
                    timestamp: timestamp,
                    imageWidth: nil,
                    imageHeight: nil,
                    aspectRatio: nil,
                    selectionCount: sharedContent.imageUrls.count > 1 ? "\(sharedContent.imageUrls.count)" : nil,
                    selectionBunch: nil,
                    receiverLoader: 0,
                    linkTitle: nil,
                    linkDescription: nil,
                    linkImageUrl: nil,
                    favIconUrl: nil
                )
                
                // Save image to local storage BEFORE upload (matching ChattingScreen)
                // This prevents download icon from showing for sender
                // The file is already local, so we can save it immediately
                if let imageData = try? Data(contentsOf: imageUrl) {
                    self.saveImageToLocalStorage(data: imageData, fileName: fileName)
                }
                
                // Store in SQLite
                DatabaseHelper.shared.insertPendingMessage(chatMessage)
                
                // Upload message
                MessageUploadService.shared.uploadMessage(
                    model: chatMessage,
                    filePath: imageUrl.path,
                    userFTokenKey: userFTokenKey
                ) { success, errorMessage in
                    if success {
                        completedMessages += 1
                        print("✅ [SHARE_IMAGE] Sent image \(imageIndex + 1)/\(sharedContent.imageUrls.count) to \(contact.fullName)")
                    } else {
                        failedMessages += 1
                        print("🚫 [SHARE_IMAGE] Failed to send image \(imageIndex + 1) to \(contact.fullName): \(errorMessage ?? "Unknown error")")
                    }
                    
                    // Check if all messages sent
                    if completedMessages + failedMessages == totalMessages {
                        DispatchQueue.main.async {
                            self.isSharing = false
                            
                            // If sending to single contact, navigate to ChattingScreen
                            if selectedContacts.count == 1, let firstContact = selectedContacts.first {
                                self.dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onNavigateToChat?(firstContact)
                                }
                            } else {
                                self.dismiss()
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func sendVideosToContacts(selectedContacts: [UserActiveContactModel], caption: String = "") {
        guard !sharedContent.videoUrls.isEmpty else {
            Constant.showToast(message: "No videos to share")
        isSharing = false
            return
        }
        
        let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let senderId = Constant.SenderIdMy
        let userName = UserDefaults.standard.string(forKey: Constant.full_name) ?? ""
        let micPhoto = UserDefaults.standard.string(forKey: Constant.profilePic) ?? ""
        let userFTokenKey = UserDefaults.standard.string(forKey: Constant.FCM_TOKEN) ?? ""
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "hh:mm a"
        let currentTimeString = timeFormatter.string(from: Date())
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let currentDateString = dateFormatter.string(from: Date())
        
        let timestamp = Date().timeIntervalSince1970
        
        var totalMessages = 0
        var completedMessages = 0
        var failedMessages = 0
        
        // Send each video to each contact
        // Only first video gets caption (matching Android/MultiDocumentPreviewDialog behavior)
        for (contactIndex, contact) in selectedContacts.enumerated() {
            for (videoIndex, videoUrl) in sharedContent.videoUrls.enumerated() {
                totalMessages += 1
                let modelId = UUID().uuidString
                let fileName = "\(modelId).mp4"
                
                // Only first video gets caption (matching MultiDocumentPreviewDialog: index == 0)
                let videoCaption = (videoIndex == 0) ? trimmedCaption : ""
                
                // Create message (matching Android sendMultiVideos logic)
                let chatMessage = ChatMessage(
                    id: modelId,
                    uid: senderId,
                    message: "",
                    time: currentTimeString,
                    document: videoUrl.path, // Local file path
                    dataType: Constant.video,
                    fileExtension: "mp4",
                    name: nil,
                    phone: nil,
                    micPhoto: micPhoto,
                    miceTiming: nil,
                    userName: userName,
                    receiverId: contact.uid,
                    replytextData: nil,
                    replyKey: nil,
                    replyType: nil,
                    replyOldData: nil,
                    replyCrtPostion: nil,
                    forwaredKey: nil,
                    groupName: nil,
                    docSize: nil,
                    fileName: fileName,
                    thumbnail: nil,
                    fileNameThumbnail: nil,
                    caption: videoCaption.isEmpty ? nil : videoCaption,
                    notification: 1,
                    currentDate: currentDateString,
                    emojiModel: nil,
                    emojiCount: nil,
                    timestamp: timestamp,
                    imageWidth: nil,
                    imageHeight: nil,
                    aspectRatio: nil,
                    selectionCount: nil,
                    selectionBunch: nil,
                    receiverLoader: 0,
                    linkTitle: nil,
                    linkDescription: nil,
                    linkImageUrl: nil,
                    favIconUrl: nil
                )
                
                // Save video to local storage BEFORE upload (matching ChattingScreen)
                // This prevents download icon from showing for sender
                // The file is already local, so we can save it immediately
                if let videoData = try? Data(contentsOf: videoUrl) {
                    self.saveVideoToLocalStorage(data: videoData, fileName: fileName)
                }
                
                // Store in SQLite
                DatabaseHelper.shared.insertPendingMessage(chatMessage)
                
                // Upload message
                MessageUploadService.shared.uploadMessage(
                    model: chatMessage,
                    filePath: videoUrl.path,
                    userFTokenKey: userFTokenKey
                ) { success, errorMessage in
                    if success {
                        completedMessages += 1
                        print("✅ [SHARE_VIDEO] Sent video \(videoIndex + 1)/\(sharedContent.videoUrls.count) to \(contact.fullName)")
                    } else {
                        failedMessages += 1
                        print("🚫 [SHARE_VIDEO] Failed to send video \(videoIndex + 1) to \(contact.fullName): \(errorMessage ?? "Unknown error")")
                    }
                    
                    // Check if all messages sent
                    if completedMessages + failedMessages == totalMessages {
                        DispatchQueue.main.async {
                            self.isSharing = false
                            
                            // If sending to single contact, navigate to ChattingScreen
                            if selectedContacts.count == 1, let firstContact = selectedContacts.first {
                                self.dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onNavigateToChat?(firstContact)
                                }
                            } else {
                                self.dismiss()
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func sendDocumentsToContacts(selectedContacts: [UserActiveContactModel], caption: String = "") {
        guard let documentUrl = sharedContent.documentUrl else {
            Constant.showToast(message: "No document to share")
        isSharing = false
            return
        }
        
        let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let senderId = Constant.SenderIdMy
        let userName = UserDefaults.standard.string(forKey: Constant.full_name) ?? ""
        let micPhoto = UserDefaults.standard.string(forKey: Constant.profilePic) ?? ""
        let userFTokenKey = UserDefaults.standard.string(forKey: Constant.FCM_TOKEN) ?? ""
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "hh:mm a"
        let currentTimeString = timeFormatter.string(from: Date())
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let currentDateString = dateFormatter.string(from: Date())
        
        let timestamp = Date().timeIntervalSince1970
        
        var totalMessages = 0
        var completedMessages = 0
        var failedMessages = 0
        
        // Send document to each contact
        for (contactIndex, contact) in selectedContacts.enumerated() {
            totalMessages += 1
            let modelId = UUID().uuidString
            let fileName = sharedContent.documentName ?? documentUrl.lastPathComponent
            let fileExtension = (fileName as NSString).pathExtension.lowercased()
            
            // Get file size
            var docSize: String? = nil
            if let attributes = try? FileManager.default.attributesOfItem(atPath: documentUrl.path),
               let size = attributes[.size] as? Int64 {
                docSize = "\(size)"
            }
            
            // Create message (matching Android sendDocument logic)
            let chatMessage = ChatMessage(
                id: modelId,
                uid: senderId,
                message: "",
                time: currentTimeString,
                document: documentUrl.path, // Local file path
                dataType: Constant.doc,
                fileExtension: fileExtension.isEmpty ? nil : fileExtension,
                name: nil,
                phone: nil,
                micPhoto: micPhoto,
                miceTiming: nil,
                userName: userName,
                receiverId: contact.uid,
                replytextData: nil,
                replyKey: nil,
                replyType: nil,
                replyOldData: nil,
                replyCrtPostion: nil,
                forwaredKey: nil,
                groupName: nil,
                docSize: docSize,
                fileName: fileName,
                thumbnail: nil,
                fileNameThumbnail: nil,
                caption: trimmedCaption.isEmpty ? nil : trimmedCaption,
                notification: 1,
                currentDate: currentDateString,
                emojiModel: nil,
                emojiCount: nil,
                timestamp: timestamp,
                imageWidth: nil,
                imageHeight: nil,
                aspectRatio: nil,
                selectionCount: nil,
                selectionBunch: nil,
                receiverLoader: 0,
                linkTitle: nil,
                linkDescription: nil,
                linkImageUrl: nil,
                favIconUrl: nil
            )
            
            // Save document to local storage BEFORE upload (matching ChattingScreen)
            // This prevents download icon from showing for sender
            // The file is already local, so we can save it immediately
            self.saveDocumentToLocalStorage(documentURL: documentUrl, fileName: fileName)
            
            // Store in SQLite
            DatabaseHelper.shared.insertPendingMessage(chatMessage)
            
            // Upload message
            MessageUploadService.shared.uploadMessage(
                model: chatMessage,
                filePath: documentUrl.path,
                userFTokenKey: userFTokenKey
            ) { success, errorMessage in
                if success {
                    completedMessages += 1
                    print("✅ [SHARE_DOCUMENT] Sent document to \(contact.fullName)")
                } else {
                    failedMessages += 1
                    print("🚫 [SHARE_DOCUMENT] Failed to send document to \(contact.fullName): \(errorMessage ?? "Unknown error")")
                }
                
                // Check if all messages sent
                if completedMessages + failedMessages == totalMessages {
                    DispatchQueue.main.async {
                        self.isSharing = false
                        
                        // If sending to single contact, navigate to ChattingScreen
                        if selectedContacts.count == 1, let firstContact = selectedContacts.first {
                            self.dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onNavigateToChat?(firstContact)
                            }
                        } else {
                            self.dismiss()
                        }
                    }
                }
            }
        }
    }
    
    private func sendContactToContacts(contactInfo: SharedContent.ContactInfo, selectedContacts: [UserActiveContactModel]) {
        let senderId = Constant.SenderIdMy
        let userName = UserDefaults.standard.string(forKey: Constant.full_name) ?? ""
        let micPhoto = UserDefaults.standard.string(forKey: Constant.profilePic) ?? ""
        let userFTokenKey = UserDefaults.standard.string(forKey: Constant.FCM_TOKEN) ?? ""
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "hh:mm a"
        let currentTimeString = timeFormatter.string(from: Date())
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let currentDateString = dateFormatter.string(from: Date())
        
        let timestamp = Date().timeIntervalSince1970
        
        var totalMessages = 0
        var completedMessages = 0
        var failedMessages = 0
        
        // Send contact to each selected contact
        for (contactIndex, contact) in selectedContacts.enumerated() {
            totalMessages += 1
            let modelId = UUID().uuidString
            
            // Create message (matching Android sendContact logic)
            let chatMessage = ChatMessage(
                id: modelId,
                uid: senderId,
                message: "",
                time: currentTimeString,
                document: "",
                dataType: Constant.contact,
                fileExtension: nil,
                name: contactInfo.name,
                phone: contactInfo.phoneNumber,
                micPhoto: micPhoto,
                miceTiming: nil,
                userName: userName,
                receiverId: contact.uid,
                replytextData: nil,
                replyKey: nil,
                replyType: nil,
                replyOldData: nil,
                replyCrtPostion: nil,
                forwaredKey: nil,
                groupName: nil,
                docSize: nil,
                fileName: nil,
                thumbnail: nil,
                fileNameThumbnail: nil,
                caption: nil,
                notification: 1,
                currentDate: currentDateString,
                emojiModel: nil,
                emojiCount: nil,
                timestamp: timestamp,
                imageWidth: nil,
                imageHeight: nil,
                aspectRatio: nil,
                selectionCount: "1",
                selectionBunch: nil,
                receiverLoader: 0,
                linkTitle: nil,
                linkDescription: nil,
                linkImageUrl: nil,
                favIconUrl: nil
            )
            
            // Store in SQLite
            DatabaseHelper.shared.insertPendingMessage(chatMessage)
            
            // Upload message
            MessageUploadService.shared.uploadMessage(
                model: chatMessage,
                filePath: nil,
                userFTokenKey: userFTokenKey
            ) { success, errorMessage in
                if success {
                    completedMessages += 1
                    print("✅ [SHARE_CONTACT] Sent contact '\(contactInfo.name)' to \(contact.fullName)")
                } else {
                    failedMessages += 1
                    print("🚫 [SHARE_CONTACT] Failed to send contact to \(contact.fullName): \(errorMessage ?? "Unknown error")")
                }
                
                // Check if all messages sent
                if completedMessages + failedMessages == totalMessages {
                    DispatchQueue.main.async {
                        self.isSharing = false
                        
                        // If sending to single contact, navigate to ChattingScreen
                        if selectedContacts.count == 1, let firstContact = selectedContacts.first {
                            self.dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onNavigateToChat?(firstContact)
                            }
                        } else {
                            self.dismiss()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Local Storage Functions (matching ChattingScreen)
    
    /// Get local images directory path (matching Android Enclosure/Media/Images)
    private func getLocalImagesDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagesDir = documentsPath.appendingPathComponent("Enclosure/Media/Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true, attributes: nil)
        return imagesDir
    }
    
    /// Save image to local storage (matching Android file saving logic)
    private func saveImageToLocalStorage(data: Data, fileName: String) {
        let imagesDir = getLocalImagesDirectory()
        let fileURL = imagesDir.appendingPathComponent(fileName)
        
        // Check if file already exists (matching Android doesFileExist check)
        guard !FileManager.default.fileExists(atPath: fileURL.path) else {
            print("📱 [LOCAL_STORAGE] Image already exists locally: \(fileName)")
            return
        }
        
        do {
            try data.write(to: fileURL, options: .atomic)
            print("📱 [LOCAL_STORAGE] ✅ Saved image to local storage")
            print("📱 [LOCAL_STORAGE] File: \(fileName)")
            print("📱 [LOCAL_STORAGE] File Path: \(fileURL.path)")
            print("📱 [LOCAL_STORAGE] Size: \(data.count) bytes (\(String(format: "%.2f", Double(data.count) / 1024.0)) KB)")
        } catch {
            print("🚫 [LOCAL_STORAGE] Error saving image to local storage: \(error.localizedDescription)")
        }
    }
    
    /// Get local videos directory path (matching Android Enclosure/Media/Videos)
    private func getLocalVideosDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videosDir = documentsPath.appendingPathComponent("Enclosure/Media/Videos", isDirectory: true)
        try? FileManager.default.createDirectory(at: videosDir, withIntermediateDirectories: true, attributes: nil)
        return videosDir
    }
    
    /// Save video to local storage (matching Android file saving logic)
    private func saveVideoToLocalStorage(data: Data, fileName: String) {
        let videosDir = getLocalVideosDirectory()
        let fileURL = videosDir.appendingPathComponent(fileName)
        
        // Check if file already exists (matching Android doesFileExist check)
        guard !FileManager.default.fileExists(atPath: fileURL.path) else {
            print("📱 [LOCAL_STORAGE] Video already exists locally: \(fileName)")
            return
        }
        
        do {
            try data.write(to: fileURL, options: .atomic)
            print("📱 [LOCAL_STORAGE] ✅ Saved video to local storage")
            print("📱 [LOCAL_STORAGE] File: \(fileName)")
            print("📱 [LOCAL_STORAGE] File Path: \(fileURL.path)")
            print("📱 [LOCAL_STORAGE] Size: \(data.count) bytes (\(String(format: "%.2f", Double(data.count) / 1024.0 / 1024.0)) MB)")
        } catch {
            print("🚫 [LOCAL_STORAGE] Error saving video to local storage: \(error.localizedDescription)")
        }
    }
    
    /// Get local documents directory path (matching Android Enclosure/Media/Documents)
    private func getLocalDocumentsDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let docsDir = documentsPath.appendingPathComponent("Enclosure/Media/Documents", isDirectory: true)
        try? FileManager.default.createDirectory(at: docsDir, withIntermediateDirectories: true, attributes: nil)
        return docsDir
    }
    
    /// Save document to local storage (matching Android file saving logic)
    private func saveDocumentToLocalStorage(documentURL: URL, fileName: String) {
        let docsDir = getLocalDocumentsDirectory()
        let destinationURL = docsDir.appendingPathComponent(fileName)
        
        // Check if file already exists
        guard !FileManager.default.fileExists(atPath: destinationURL.path) else {
            print("📱 [LOCAL_STORAGE] Document already exists locally: \(fileName)")
            return
        }
        
        // Copy file to local storage
        do {
            try FileManager.default.copyItem(at: documentURL, to: destinationURL)
            print("📱 [LOCAL_STORAGE] ✅ Saved document to local storage")
            print("📱 [LOCAL_STORAGE] File: \(fileName)")
            print("📱 [LOCAL_STORAGE] File Path: \(destinationURL.path)")
        } catch {
            print("❌ [LOCAL_STORAGE] Failed to save document: \(error.localizedDescription)")
        }
    }
}

// MARK: - Share Contact Row View (matching Android forward_layout_row.xml)
struct ShareContactRowView: View {
    @Environment(\.colorScheme) var colorScheme
    
    let contact: UserActiveContactModel
    let isSelected: Bool
    let canSelect: Bool
    let onTap: () -> Void
    
    // Truncate name to 20 characters (matching Android)
    private var displayName: String {
        if contact.fullName.count > 20 {
            return String(contact.fullName.prefix(20)) + "..."
        }
        return contact.fullName
    }
    
    var body: some View {
        Button(action: {
            if canSelect {
                withAnimation(.easeInOut(duration: 0.2)) {
            onTap()
                }
            }
        }) {
            HStack(alignment: .center, spacing: 0) {
                // Profile image (matching Android contact1img: 50dp x 50dp)
                AsyncImage(url: URL(string: contact.photo)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image("inviteimg")
                        .resizable()
                        .scaledToFill()
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                .padding(.leading, 16) // layout_marginHorizontal="16dp"
                .padding(.trailing, 20) // marginEnd="20dp"
                
                // Name (matching Android contact1text)
                // fontFamily="@font/inter_bold" textSize="16sp" textFontWeight="600"
                Text(displayName)
                        .font(.custom("Inter18pt-Bold", size: 16))
                        .fontWeight(.semibold)
                        .foregroundColor(Color("TextColor"))
                        .lineLimit(1)
                    .lineSpacing(0) // lineHeight="18dp"
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                // Checkbox (matching Android checkbox_bg visual size - smaller than drawable)
                // layout_gravity="end" - vertically centered in LinearLayout
                // Aligned to same right edge as search icon (16dp from right)
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color("TextColor") : Color.clear)
                        .frame(width: 18, height: 18) // Reduced size
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color("TextColor"), lineWidth: 2)
                        )
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .foregroundColor(colorScheme == .dark ? Color.black : Color(red: 0xF6/255, green: 0xF7/255, blue: 0xFF/255))
                            .font(.system(size: 9, weight: .bold)) // Smaller checkmark to match smaller box
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                // No trailing padding - parent HStack already has .padding(.horizontal, 16) which aligns with search icon
            }
            .padding(.top, 10) // paddingTop="10dp"
            .padding(.bottom, 10) // paddingBottom="10dp"
            .padding(.leading, 16) // layout_marginStart="16dp"
            .padding(.trailing, 20) // 20dp right margin to align with search icon
            .background(Color("background_color"))
            .opacity(canSelect ? 1.0 : 0.5)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Share Image Preview Dialog (matching MultiImagePreviewDialog design)
struct ShareImagePreviewDialog: View {
    let imageUrls: [URL]
    @Binding var caption: String
    let onSend: (String) -> Void
    let onDismiss: () -> Void
    
    @State private var currentIndex: Int = 0
    @State private var previewImages: [UIImage?] = []
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isCaptionFocused: Bool
    
    init(imageUrls: [URL], caption: Binding<String>, onSend: @escaping (String) -> Void, onDismiss: @escaping () -> Void) {
        self.imageUrls = imageUrls
        self._caption = caption
        self.onSend = onSend
        self.onDismiss = onDismiss
        NSLog("🖼️ [IMAGE_PREVIEW_INIT] ShareImagePreviewDialog initialized")
        NSLog("🖼️ [IMAGE_PREVIEW_INIT] Image URLs count: \(imageUrls.count)")
        for (index, url) in imageUrls.enumerated() {
            NSLog("🖼️ [IMAGE_PREVIEW_INIT] URL \(index): \(url)")
            NSLog("🖼️ [IMAGE_PREVIEW_INIT] URL \(index) path: \(url.path)")
            NSLog("🖼️ [IMAGE_PREVIEW_INIT] URL \(index) isFileURL: \(url.isFileURL)")
            NSLog("🖼️ [IMAGE_PREVIEW_INIT] URL \(index) fileExists: \(FileManager.default.fileExists(atPath: url.path))")
        }
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar with back button and image count
                HStack {
                    Button(action: {
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
                    
                    Text("\(currentIndex + 1) / \(imageUrls.count)")
                        .font(.custom("Inter18pt-Medium", size: 16))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Spacer()
                        .frame(width: 40)
                }
                .frame(height: 60)
                .background(Color.black.opacity(0.3))
                
                // Image preview area - load directly from local file paths (immediate display)
                GeometryReader { geometry in
                    TabView(selection: $currentIndex) {
                        ForEach(Array(imageUrls.enumerated()), id: \.offset) { index, url in
                            ImagePreviewItemView(
                                url: url,
                                index: index,
                                previewImages: previewImages,
                                onAppear: {
                                    NSLog("🖼️ [PREVIEW_RENDER] Image view \(index) appeared")
                                }
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                }
                
                Spacer()
                    .frame(height: 5)
                
                // Bottom caption input area
                HStack(spacing: 0) {
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            ZStack(alignment: .leading) {
                                if caption.isEmpty {
                                    Text("Add Caption")
                                        .font(.custom("Inter18pt-Medium", size: 17))
                                        .foregroundColor(Color(hex: "#9EA6B9"))
                                        .padding(.leading, 15)
                                        .padding(.trailing, 20)
                                        .padding(.top, 5)
                                        .padding(.bottom, 5)
                                }
                                
                                TextField("", text: $caption, axis: .vertical)
                                    .font(.custom("Inter18pt-Medium", size: 17))
                                    .foregroundColor(.white)
                                    .lineLimit(4)
                                    .lineSpacing(4)
                                    .frame(maxWidth: 180, alignment: .leading)
                                    .padding(.leading, 15)
                                    .padding(.trailing, 20)
                                    .padding(.top, 5)
                                    .padding(.bottom, 5)
                                    .background(Color.clear)
                                    .focused($isCaptionFocused)
                                    .accentColor(Color("black_white_crossEmoji"))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(hex: "#1B1C1C"))
                    )
                    .padding(.leading, 10)
                    .padding(.trailing, 5)
                    
                    VStack(spacing: 0) {
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
                            onSend(trimmedCaption)
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: Constant.themeColor))
                                    .frame(width: 50, height: 50)
                                
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
        .onAppear {
            NSLog("🖼️ [IMAGE_PREVIEW] ShareImagePreviewDialog onAppear")
            NSLog("🖼️ [IMAGE_PREVIEW] Total image URLs: \(imageUrls.count)")
            for (index, url) in imageUrls.enumerated() {
                NSLog("🖼️ [IMAGE_PREVIEW] URL \(index): \(url)")
                NSLog("🖼️ [IMAGE_PREVIEW] URL \(index) path: \(url.path)")
                NSLog("🖼️ [IMAGE_PREVIEW] URL \(index) isFileURL: \(url.isFileURL)")
                NSLog("🖼️ [IMAGE_PREVIEW] URL \(index) fileExists: \(FileManager.default.fileExists(atPath: url.path))")
            }
            // Preload images in background for fallback (but display immediately from local paths)
            preloadImagesForFallback()
            setupKeyboardObservers()
        }
        .onDisappear {
            removeKeyboardObservers()
        }
    }
    
    // Preload images in background for fallback (only if direct load fails)
    private func preloadImagesForFallback() {
        NSLog("🖼️ [PRELOAD] preloadImagesForFallback called")
        NSLog("🖼️ [PRELOAD] Image URLs count: \(imageUrls.count)")
        previewImages = Array(repeating: nil, count: imageUrls.count)
        
        for (index, url) in imageUrls.enumerated() {
            NSLog("🖼️ [PRELOAD] Processing image \(index)")
            // Check if direct load would succeed
            let filePath = url.path
            let fileExists = FileManager.default.fileExists(atPath: filePath)
            let canLoadDirectly = fileExists && UIImage(contentsOfFile: filePath) != nil
            
            // Only preload if direct load failed
            if !canLoadDirectly {
                NSLog("🖼️ [PRELOAD] Direct load failed for image \(index), trying async load")
                DispatchQueue.global(qos: .userInitiated).async {
                    NSLog("🖼️ [PRELOAD] Async loading image \(index) from: \(url)")
                    if let imageData = try? Data(contentsOf: url) {
                        NSLog("🖼️ [PRELOAD] Image \(index) data loaded: \(imageData.count) bytes")
                        if let image = UIImage(data: imageData) {
                            NSLog("🖼️ [PRELOAD] ✅ Image \(index) created from data")
                            DispatchQueue.main.async {
                                if index < self.previewImages.count {
                                    self.previewImages[index] = image
                                    NSLog("🖼️ [PRELOAD] Image \(index) stored in previewImages")
                                }
                            }
                        } else {
                            NSLog("🖼️ [PRELOAD] ❌ Failed to create UIImage from data for image \(index)")
                        }
                    } else {
                        NSLog("🖼️ [PRELOAD] ❌ Failed to load data from URL for image \(index)")
                    }
                }
            } else {
                NSLog("🖼️ [PRELOAD] Direct load succeeded for image \(index), skipping async load")
            }
        }
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
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
}

// MARK: - Image Preview Item View (helper to avoid NSLog in view builder)
private struct ImagePreviewItemView: View {
    let url: URL
    let index: Int
    let previewImages: [UIImage?]
    let onAppear: () -> Void
    
    var body: some View {
        ZStack {
            Color.black
            
            // Load image directly from local file path (immediate, no loader)
            if let image = loadImageFromLocalPath(url: url) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        NSLog("🖼️ [PREVIEW_RENDER] Image \(index) rendered from local path")
                        onAppear()
                    }
            } else {
                // Fallback: try async load if direct load fails
                if index < previewImages.count, let image = previewImages[index] {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear {
                            NSLog("🖼️ [PREVIEW_RENDER] Image \(index) rendered from fallback")
                            onAppear()
                        }
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .onAppear {
                            NSLog("🖼️ [PREVIEW_RENDER] Image \(index) showing loader")
                            NSLog("🖼️ [PREVIEW_RENDER] Image \(index) local load failed, trying fallback")
                            onAppear()
                        }
                }
            }
        }
    }
    
    // Load image directly from local file path (immediate, synchronous)
    private func loadImageFromLocalPath(url: URL) -> UIImage? {
        NSLog("🖼️ [LOAD_IMAGE] loadImageFromLocalPath called")
        NSLog("🖼️ [LOAD_IMAGE] URL: \(url)")
        NSLog("🖼️ [LOAD_IMAGE] URL.path: \(url.path)")
        NSLog("🖼️ [LOAD_IMAGE] URL.isFileURL: \(url.isFileURL)")
        
        // Use file path directly for immediate loading
        let filePath = url.path
        let fileExists = FileManager.default.fileExists(atPath: filePath)
        NSLog("🖼️ [LOAD_IMAGE] File exists: \(fileExists)")
        
        if fileExists {
            // Load directly from file system (immediate, no async)
            if let image = UIImage(contentsOfFile: filePath) {
                NSLog("🖼️ [LOAD_IMAGE] ✅ Image loaded successfully")
                NSLog("🖼️ [LOAD_IMAGE] Image size: \(image.size)")
                return image
            } else {
                NSLog("🖼️ [LOAD_IMAGE] ❌ Failed to create UIImage from file path")
                // Try alternative: load as data first
                if let imageData = try? Data(contentsOf: url) {
                    NSLog("🖼️ [LOAD_IMAGE] Data loaded, size: \(imageData.count) bytes")
                    if let image = UIImage(data: imageData) {
                        NSLog("🖼️ [LOAD_IMAGE] ✅ Image created from data")
                        return image
                    } else {
                        NSLog("🖼️ [LOAD_IMAGE] ❌ Failed to create UIImage from data")
                    }
                } else {
                    NSLog("🖼️ [LOAD_IMAGE] ❌ Failed to load data from URL")
                }
            }
        } else {
            NSLog("🖼️ [LOAD_IMAGE] ❌ File does not exist at path: \(filePath)")
            // Try loading from URL directly (might be a file:// URL that needs different handling)
            if let imageData = try? Data(contentsOf: url) {
                NSLog("🖼️ [LOAD_IMAGE] Data loaded from URL directly, size: \(imageData.count) bytes")
                if let image = UIImage(data: imageData) {
                    NSLog("🖼️ [LOAD_IMAGE] ✅ Image created from URL data")
                    return image
                }
            }
        }
        return nil
    }
}

// MARK: - Share Video Preview Dialog (matching MultiVideoPreviewDialog design)
struct ShareVideoPreviewDialog: View {
    let videoUrls: [URL]
    @Binding var caption: String
    let onSend: (String) -> Void
    let onDismiss: () -> Void
    
    @State private var currentIndex: Int = 0
    @State private var players: [AVPlayer?] = []
    @State private var thumbnails: [UIImage?] = []
    @State private var keyboardHeight: CGFloat = 0
    @State private var isPlaying: [Bool] = []
    @FocusState private var isCaptionFocused: Bool
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button(action: {
                        pauseAllVideos()
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
                    
                    Text("\(currentIndex + 1) / \(videoUrls.count)")
                        .font(.custom("Inter18pt-Medium", size: 16))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Spacer()
                        .frame(width: 40)
                }
                .frame(height: 60)
                .background(Color.black.opacity(0.3))
                
                // Video preview area - load directly from local file paths (immediate display)
                GeometryReader { geometry in
                    TabView(selection: $currentIndex) {
                        ForEach(Array(videoUrls.enumerated()), id: \.offset) { index, url in
                            ZStack {
                                Color.black
                                
                                // Load video directly from local file path (immediate)
                                if index < players.count, let player = players[index] {
                                    VideoPlayer(player: player)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .onTapGesture {
                                            togglePlayPause(at: index)
                                        }
                                } else if let thumbnail = loadVideoThumbnailFromLocalPath(url: url) {
                                    // Show thumbnail immediately while video loads
                                    Image(uiImage: thumbnail)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                } else if index < thumbnails.count, let thumbnail = thumbnails[index] {
                                    // Fallback: use preloaded thumbnail
                                    Image(uiImage: thumbnail)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                } else {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                            }
                            .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .onChange(of: currentIndex) { newIndex in
                        pauseAllVideos()
                        if newIndex < players.count, let player = players[newIndex] {
                            player.play()
                            isPlaying[newIndex] = true
                        }
                    }
                }
                
                Spacer()
                    .frame(height: 5)
                
                // Bottom caption input (same as image preview)
                HStack(spacing: 0) {
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            ZStack(alignment: .leading) {
                                if caption.isEmpty {
                                    Text("Add Caption")
                                        .font(.custom("Inter18pt-Medium", size: 17))
                                        .foregroundColor(Color(hex: "#9EA6B9"))
                                        .padding(.leading, 15)
                                        .padding(.trailing, 20)
                                        .padding(.top, 5)
                                        .padding(.bottom, 5)
                                }
                                
                                TextField("", text: $caption, axis: .vertical)
                                    .font(.custom("Inter18pt-Medium", size: 17))
                                    .foregroundColor(.white)
                                    .lineLimit(4)
                                    .lineSpacing(4)
                                    .frame(maxWidth: 180, alignment: .leading)
                                    .padding(.leading, 15)
                                    .padding(.trailing, 20)
                                    .padding(.top, 5)
                                    .padding(.bottom, 5)
                                    .background(Color.clear)
                                    .focused($isCaptionFocused)
                                    .accentColor(Color("black_white_crossEmoji"))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(hex: "#1B1C1C"))
                    )
                    .padding(.leading, 10)
                    .padding(.trailing, 5)
                    
                    VStack(spacing: 0) {
                        Button(action: {
                            pauseAllVideos()
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
                            onSend(trimmedCaption)
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: Constant.themeColor))
                                    .frame(width: 50, height: 50)
                                
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
        .onAppear {
            // Load videos immediately from local file paths
            loadAllVideosImmediately()
            setupKeyboardObservers()
        }
        .onDisappear {
            pauseAllVideos()
            removeKeyboardObservers()
        }
    }
    
    // Load video thumbnail directly from local file path (immediate)
    private func loadVideoThumbnailFromLocalPath(url: URL) -> UIImage? {
        let filePath = url.path
        if FileManager.default.fileExists(atPath: filePath) {
            let asset = AVAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.requestedTimeToleranceAfter = .zero
            imageGenerator.requestedTimeToleranceBefore = .zero
            
            if let cgImage = try? imageGenerator.copyCGImage(at: CMTime.zero, actualTime: nil) {
                return UIImage(cgImage: cgImage)
            }
        }
        return nil
    }
    
    // Load videos immediately from local file paths (no loader)
    private func loadAllVideosImmediately() {
        players = Array(repeating: nil, count: videoUrls.count)
        thumbnails = Array(repeating: nil, count: videoUrls.count)
        isPlaying = Array(repeating: false, count: videoUrls.count)
        
        // Create players immediately (they use local file URLs, so instant)
        for (index, url) in videoUrls.enumerated() {
            let player = AVPlayer(url: url)
            players[index] = player
            
            // Generate thumbnail immediately from local file
            if let thumbnail = loadVideoThumbnailFromLocalPath(url: url) {
                thumbnails[index] = thumbnail
            } else {
                // Fallback: generate thumbnail in background
                DispatchQueue.global(qos: .userInitiated).async {
                    let asset = AVAsset(url: url)
                    let imageGenerator = AVAssetImageGenerator(asset: asset)
                    imageGenerator.appliesPreferredTrackTransform = true
                    
                    if let cgImage = try? imageGenerator.copyCGImage(at: CMTime.zero, actualTime: nil) {
                        let thumbnail = UIImage(cgImage: cgImage)
                        DispatchQueue.main.async {
                            if index < self.thumbnails.count {
                                self.thumbnails[index] = thumbnail
                            }
                        }
                    }
                }
            }
        }
        
        // Auto-play first video
        if let firstPlayer = players.first, let player = firstPlayer {
            player.play()
            if !isPlaying.isEmpty {
                isPlaying[0] = true
            }
        }
    }
    
    private func togglePlayPause(at index: Int) {
        guard index < players.count, let player = players[index] else { return }
        if isPlaying[index] {
            player.pause()
            isPlaying[index] = false
        } else {
            player.play()
            isPlaying[index] = true
        }
    }
    
    private func pauseAllVideos() {
        for (index, player) in players.enumerated() {
            player?.pause()
            if index < isPlaying.count {
                isPlaying[index] = false
            }
        }
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
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
}

// MARK: - Share Document Preview Dialog (matching MultiDocumentPreviewDialog design)
struct ShareDocumentPreviewDialog: View {
    let documentUrl: URL?
    let documentName: String?
    @Binding var caption: String
    let onSend: (String) -> Void
    let onDismiss: () -> Void
    
    @State private var keyboardHeight: CGFloat = 0
    @State private var fileSize: String = ""
    @State private var fileName: String = ""
    @State private var fileIcon: String = "documentsvg"
    @FocusState private var isCaptionFocused: Bool
    
    var body: some View {
        ZStack {
            // Full-screen background (matching Android transparent background)
            Color.black
                .ignoresSafeArea()
            
            if documentUrl == nil {
                // Show error if no document
                VStack {
                    Text("No document selected")
                        .foregroundColor(.white)
                }
            } else {
                VStack(spacing: 0) {
                    // Top bar with back button (matching Android header)
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
                        
                        // Spacer to balance layout (send button is in bottom caption bar)
                        Spacer()
                            .frame(width: 40)
                    }
                    .frame(height: 60)
                    .background(Color.black.opacity(0.3))
                    
                    // Document preview area (matching Android document preview)
                    GeometryReader { geometry in
                        ZStack {
                            Color.black
                            
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
                                
                                // Small delay to let keyboard dismiss animation complete
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    onSend(trimmedCaption)
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
            loadDocumentInfo()
            setupKeyboardObservers()
        }
        .onDisappear {
            removeKeyboardObservers()
        }
    }
    
    private func loadDocumentInfo() {
        guard let url = documentUrl else { return }
        
        // Get file name
        fileName = documentName ?? url.lastPathComponent
        
        // Get file size
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attributes[.size] as? Int64 {
            fileSize = formatFileSize(size)
        } else {
            fileSize = "Unknown"
        }
        
        // Determine icon based on file type
        fileIcon = getFileIcon(for: url)
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
        if ["mp4", "mov", "avi", "mkv", "m4v", "3gp"].contains(pathExtension) {
            return "video"
        }
        
        // Check if it's a PDF
        if pathExtension == "pdf" {
            return "pdf"
        }
        
        // Check if it's a document
        if ["doc", "docx", "txt", "rtf", "pages"].contains(pathExtension) {
            return "documentsvg"
        }
        
        // Check if it's a spreadsheet
        if ["xls", "xlsx", "numbers", "csv"].contains(pathExtension) {
            return "spreadsheet"
        }
        
        // Check if it's a presentation
        if ["ppt", "pptx", "key"].contains(pathExtension) {
            return "presentation"
        }
        
        // Check if it's an archive
        if ["zip", "rar", "7z", "tar", "gz"].contains(pathExtension) {
            return "archive"
        }
        
        // Default document icon
        return "documentsvg"
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
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
}
