//
//  ShareExternalDataContactScreen.swift
//  Enclosure
//
//  Created by Ram Lohar on 30/04/25.
//

import SwiftUI

struct ShareExternalDataContactScreen: View {
    let sharedContent: SharedContent
    let caption: String
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @StateObject private var viewModel = ChatViewModel()
    @State private var selectedContactIds: Set<String> = []
    @State private var isLoading: Bool = true
    @State private var searchText: String = ""
    @State private var showNetworkLoader: Bool = false
    @State private var isSharing: Bool = false
    @FocusState private var isSearchFocused: Bool
    
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
        availableContacts.filter { selectedContactIds.contains($0.uid) }
    }
    
    var body: some View {
        ZStack {
            Color("BackgroundColor")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Search section (matching Android searchlyt LinearLayout)
                searchSection
                
                // Network loader (matching Android networkLoader LinearProgressIndicator)
                if showNetworkLoader {
                    ProgressView()
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 4)
                        .padding(.top, 5)
                }
                
                // Contacts list (matching Android recyclerview RecyclerView)
                contactsList
                
                // Bottom selected contacts and share button (matching Android dx LinearLayout)
                if !selectedContactIds.isEmpty {
                    bottomShareSection
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadContacts()
        }
        .onChange(of: viewModel.chatList) { _ in
            // Hide loader when contacts are loaded
            if !viewModel.chatList.isEmpty {
                isLoading = false
                showNetworkLoader = false
            }
        }
    }
    
    // MARK: - Search Section (matching Android searchlyt LinearLayout)
    private var searchSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Search container (matching Android searchLytNew LinearLayout - weight 1, marginEnd 10dp)
                HStack(spacing: 0) {
                    // Blue vertical bar (matching Android viewnewnn View: 1dp width, 19.24dp height, 23dp marginStart)
                    Rectangle()
                        .fill(Color("blue"))
                        .frame(width: 1, height: 19.24)
                        .padding(.leading, 23)
                    
                    // Search field (matching Android searchview AutoCompleteTextView: 13dp marginStart)
                    TextField("Search Name", text: $searchText)
                        .font(.custom("Inter18pt-Regular", size: 15))
                        .fontWeight(.medium)
                        .foregroundColor(Color("TextColor"))
                        .accentColor(Color("TextColor"))
                        .focused($isSearchFocused)
                        .padding(.leading, 13)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 10) // marginEnd="10dp"
                
                // Search icon container (matching Android LinearLayout - weight 3.9)
                HStack {
                    // Search icon (matching Android searchIcon ImageView: 20dp x 20dp, centered)
                    Image("search")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                }
                .frame(width: UIScreen.main.bounds.width * 0.28) // Approximate weight 3.9
            }
            .padding(.vertical, 8) // padding="8dp"
            .padding(.horizontal, 8) // padding="8dp"
        }
    }
    
    // MARK: - Contacts List
    private var contactsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if isLoading {
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
                            onTap: {
                                toggleSelection(for: contact)
                            }
                        )
                    }
                }
            }
            .padding(.top, 15)
        }
    }
    
    // MARK: - Bottom Share Section (matching Android dx LinearLayout)
    private var bottomShareSection: some View {
        HStack(spacing: 0) {
            // Selected contacts horizontal list (matching Android namerecyclerview RecyclerView)
            // Shows names as text separated by commas (matching forwardnameAdapter)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(selectedContacts.enumerated()), id: \.element.uid) { index, contact in
                        if selectedContacts.count == 1 {
                            // Single contact: just show name
                            Text(contact.fullName)
                                .font(.custom("Inter18pt-Medium", size: 13))
                                .foregroundColor(Color("gray3"))
                                .lineLimit(1)
                        } else {
                            // Multiple contacts: show name with comma separator
                            if index == selectedContacts.count - 1 {
                                // Last item: just name
                                Text(contact.fullName)
                                    .font(.custom("Inter18pt-Medium", size: 13))
                                    .foregroundColor(Color("gray3"))
                                    .lineLimit(1)
                            } else {
                                // Not last: name + comma + space
                                Text("\(contact.fullName) , ")
                                    .font(.custom("Inter18pt-Medium", size: 13))
                                    .foregroundColor(Color("gray3"))
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 5)
            }
            .frame(height: 40)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Share button (matching Android forward LinearLayout - weight 2.5)
            Button(action: {
                handleShare()
            }) {
                if isSharing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color("whitetogray")))
                } else {
                    Text("Share")
                        .font(.custom("Inter18pt-Regular", size: 16))
                        .fontWeight(.bold)
                        .foregroundColor(Color("whitetogray"))
                }
            }
            .frame(width: UIScreen.main.bounds.width * 0.4) // Approximate weight 2.5
            .padding(.horizontal, 15)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color("dxForward"))
            )
            .padding(.trailing, 10)
            .disabled(isSharing)
        }
        .frame(height: 60)
        .background(Color("dxForward"))
    }
    
    // MARK: - Helper Functions
    private func loadContacts() {
        isLoading = true
        showNetworkLoader = true
        
        viewModel.fetchChatList(uid: Constant.SenderIdMy)
        
        // Hide loader after a delay if contacts don't load
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if isLoading {
                isLoading = false
                showNetworkLoader = false
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
            // Image sharing - send images to contacts
            if sharedContent.imageUrls.count > 1 {
                // Multi-image - show preview first (matching Android setupMultiImagePreview)
                // For now, send directly
                sendImagesToContacts(selectedContacts: selectedContacts)
            } else {
                // Single image - send directly
                sendImagesToContacts(selectedContacts: selectedContacts)
            }
        case .video:
            // Video sharing - send videos to contacts
            if sharedContent.videoUrls.count > 1 {
                // Multi-video - show preview first (matching Android setupMultiVideoPreview)
                // For now, send directly
                sendVideosToContacts(selectedContacts: selectedContacts)
            } else {
                // Single video - send directly
                sendVideosToContacts(selectedContacts: selectedContacts)
            }
        case .document:
            // Document sharing - send documents to contacts
            sendDocumentsToContacts(selectedContacts: selectedContacts)
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
                userFTokenKey: userFTokenKey,
                deviceType: "2"
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
                        Constant.showToast(message: "Shared with \(selectedContacts.count) contact(s)")
                        self.dismiss()
                    }
                }
            }
        }
    }
    
    private func sendImagesToContacts(selectedContacts: [UserActiveContactModel]) {
        // TODO: Implement image sharing logic
        // This should upload images to Firebase Storage and send messages
        print("📤 [SHARE_IMAGE] Sharing \(sharedContent.imageUrls.count) image(s) to \(selectedContacts.count) contact(s)")
        Constant.showToast(message: "Image sharing not yet implemented")
        isSharing = false
    }
    
    private func sendVideosToContacts(selectedContacts: [UserActiveContactModel]) {
        // TODO: Implement video sharing logic
        print("📤 [SHARE_VIDEO] Sharing \(sharedContent.videoUrls.count) video(s) to \(selectedContacts.count) contact(s)")
        Constant.showToast(message: "Video sharing not yet implemented")
        isSharing = false
    }
    
    private func sendDocumentsToContacts(selectedContacts: [UserActiveContactModel]) {
        // TODO: Implement document sharing logic
        print("📤 [SHARE_DOCUMENT] Sharing document to \(selectedContacts.count) contact(s)")
        Constant.showToast(message: "Document sharing not yet implemented")
        isSharing = false
    }
    
    private func sendContactToContacts(contactInfo: SharedContent.ContactInfo, selectedContacts: [UserActiveContactModel]) {
        // TODO: Implement contact sharing logic
        print("📤 [SHARE_CONTACT] Sharing contact '\(contactInfo.name)' to \(selectedContacts.count) contact(s)")
        Constant.showToast(message: "Contact sharing not yet implemented")
        isSharing = false
    }
}

// MARK: - Share Contact Row View (matching Android share_contact_layout.xml)
struct ShareContactRowView: View {
    let contact: UserActiveContactModel
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            onTap()
        }) {
            HStack(spacing: 0) {
                // Profile image container (matching Android CardView with contact1img)
                // 50dp x 50dp, 1dp marginStart, 20dp marginEnd
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
                .padding(.leading, 1) // marginStart="1dp"
                .padding(.trailing, 20) // marginEnd="20dp"
                
                // Name and caption container (matching Android LinearLayout)
                VStack(alignment: .leading, spacing: 0) {
                    // Name (matching Android contact1text: 16sp, bold, inter_bold, weight 600)
                    Text(contact.fullName)
                        .font(.custom("Inter18pt-Bold", size: 16))
                        .fontWeight(.semibold)
                        .foregroundColor(Color("TextColor"))
                        .lineLimit(1)
                        .lineSpacing(0)
                    
                    // Caption (matching Android captiontext: 13sp, gray3, hidden by default)
                    // Note: Caption is hidden in Android, so we don't show it
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                // Checkbox container (matching Android LinearLayout with checkbox)
                // Checkbox (matching Android checkbox_bg drawable)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? Color("blue") : Color("gray3"))
                    .font(.system(size: 24))
                    .padding(.trailing, 16)
            }
            .padding(.top, 10) // paddingTop="10dp"
            .padding(.bottom, 10) // paddingBottom="10dp"
            .padding(.horizontal, 16) // layout_marginHorizontal="16dp"
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
