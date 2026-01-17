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
    
    var body: some View {
        ZStack {
            // Background matching Android BackgroundColor style
            Color("background_color")
                .ignoresSafeArea()
            
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
                    HStack(alignment: .center, spacing: 0) {
                        // Blue indicator line (matching Android viewnewnn)
                        Rectangle()
                            .fill(Color("blue"))
                            .frame(width: 1, height: 19.24) // layout_height="19.24dp"
                            .padding(.leading, 23) // layout_marginStart="23dp"
                        
                        // Search field (matching Android searchview AutoCompleteTextView)
                        HStack(alignment: .center, spacing: 0) {
                            TextField("Search Name", text: $searchText)
                                .font(.custom("Inter18pt-Regular", size: 15)) // textSize="15sp"
                                .foregroundColor(Color("TextColor"))
                                .focused($isSearchFocused)
                                .lineSpacing(0) // lineHeight="22.5dp"
                                .padding(.leading, 13) // layout_marginStart="13dp"
                            
                            Spacer()
                            
                            // Search icon (matching Android searchIcon)
                            // layout_weight="3.9" layout_gravity="end|center_vertical"
                            Image("search")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20) // layout_width="20dp" layout_height="20dp"
                                .foregroundColor(Color("TextColor"))
                        }
                        .frame(maxWidth: .infinity) // layout_weight="1"
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
