//
//  MultiContactPreviewDialog.swift
//  Enclosure
//
//  Created by Ram Lohar on 30/04/25.
//

import SwiftUI
import FirebaseDatabase

struct MultiContactPreviewDialog: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    let selectedContacts: [ContactPickerInfo]
    @Binding var caption: String
    let contact: UserActiveContactModel
    let onSend: (String) -> Void
    let onDismiss: () -> Void
    let onMessageAdded: ((ChatMessage) -> Void)? // Callback to add message immediately to list
    
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
            
            if selectedContacts.isEmpty {
                // Show loading or error if no contacts
                VStack {
                    Text("No contacts selected")
                        .foregroundColor(.white)
                }
            } else {
                VStack(spacing: 0) {
                    // Top bar with back button and contact count (matching Android header)
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
                        
                        // Contact count indicator (matching Android counter) - always show
                        Text("\(currentIndex + 1) / \(selectedContacts.count)")
                            .font(.custom("Inter18pt-Medium", size: 16))
                            .foregroundColor(.white)
                    
                        Spacer()
                        
                        // Spacer to balance layout (send button is in bottom caption bar)
                        Spacer()
                            .frame(width: 40)
                    }
                    .frame(height: 60)
                    .background(Color.black.opacity(0.3))
                    
                    // Contact preview area (matching Android contact preview)
                    GeometryReader { geometry in
                        TabView(selection: $currentIndex) {
                            ForEach(Array(selectedContacts.enumerated()), id: \.element.id) { index, contact in
                                ContactPreviewItem(contact: contact)
                                    .tag(index)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    }
                    
                    // Spacing between contact and caption area (5px)
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
                                print("MultiContactPreviewDialog: Send button clicked - Caption: '\(trimmedCaption)' (length: \(trimmedCaption.count))")
                                
                                // Small delay to let keyboard dismiss animation complete
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    self.handleMultiContactSend(caption: trimmedCaption)
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
            print("MultiContactPreviewDialog: onAppear - contacts count: \(selectedContacts.count)")
            print("MultiContactPreviewDialog: contacts: \(selectedContacts.map { $0.name })")
            print("MultiContactPreviewDialog: onAppear - Initial caption: '\(caption)' (length: \(caption.count))")
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
    
    /// Check if message exists in Firebase and stop progress bar (matching Android behavior)
    private func checkMessageInFirebaseAndStopProgress(messageId: String, receiverUid: String) {
        let senderId = Constant.SenderIdMy
        let receiverRoom = receiverUid + senderId
        let database = Database.database().reference()
        let messageRef = database.child(Constant.CHAT).child(receiverRoom).child(messageId)
        
        print("🔍 [ProgressBar] Checking if contact message exists in Firebase: \(messageId)")
        
        // Check if message exists in Firebase (matching Android addListenerForSingleValueEvent)
        messageRef.observeSingleEvent(of: .value) { snapshot in
            if snapshot.exists() {
                print("✅ [ProgressBar] Contact message confirmed in Firebase, stopping animation and updating receiverLoader")
                
                // Remove from pending table (matching Android removePendingMessage)
                let removed = DatabaseHelper.shared.removePendingMessage(modelId: messageId, receiverUid: receiverUid)
                if removed {
                    print("✅ [PendingMessages] Removed pending contact message from SQLite: \(messageId)")
                }
                
                // Update receiverLoader to 1 to stop progress bar (matching Android setIndeterminate(false))
                let receiverLoaderRef = database.child(Constant.CHAT).child(receiverRoom).child(messageId).child("receiverLoader")
                receiverLoaderRef.setValue(1) { error, _ in
                    if let error = error {
                        print("❌ [ProgressBar] Error updating receiverLoader: \(error.localizedDescription)")
                    } else {
                        print("✅ [ProgressBar] receiverLoader updated to 1 for contact message: \(messageId)")
                    }
                }
            } else {
                print("⚠️ [ProgressBar] Contact message not found in Firebase yet, keeping animation")
                // Keep receiverLoader as 0, animation continues
            }
        }
    }
    
    // MARK: - Contact Send Functions (matching Android sendMultipleContacts)
    
    private func handleMultiContactSend(caption: String) {
        print("MultiContactPreviewDialog: === MULTI-CONTACT SEND ===")
        print("MultiContactPreviewDialog: Selected contacts count: \(selectedContacts.count)")
        print("MultiContactPreviewDialog: Caption: '\(caption)'")
        
        guard !selectedContacts.isEmpty else {
            print("MultiContactPreviewDialog: No contacts selected, returning")
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
        
        // Send each contact as a separate message (matching Android behavior)
        // Only first contact gets caption, others get empty caption
        for (index, contactInfo) in selectedContacts.enumerated() {
            let contactModelId = UUID().uuidString
            let contactCaption = (index == 0) ? trimmedCaption : ""
            
            print("MultiContactPreviewDialog: Creating ChatMessage \(index + 1)/\(selectedContacts.count) with caption: '\(contactCaption)'")
            print("MultiContactPreviewDialog: Contact: name='\(contactInfo.name)', phone='\(contactInfo.phone ?? "nil")', email='\(contactInfo.email ?? "nil")'")
            
            let newMessage = ChatMessage(
                id: contactModelId,
                uid: senderId,
                message: contactCaption,
                time: currentDateTimeString,
                document: "",
                dataType: Constant.contact,
                fileExtension: nil,
                name: contactInfo.name,
                phone: contactInfo.phone,
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
                docSize: nil,
                fileName: nil,
                thumbnail: nil,
                fileNameThumbnail: nil,
                caption: contactCaption,
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
            
            print("MultiContactPreviewDialog: ChatMessage created with caption: '\(newMessage.caption ?? "nil")'")
            print("MultiContactPreviewDialog: ChatMessage name: '\(newMessage.name ?? "nil")', phone: '\(newMessage.phone ?? "nil")'")
            
            // Store message in SQLite pending table before upload (matching Android insertPendingMessage)
            DatabaseHelper.shared.insertPendingMessage(newMessage)
            print("✅ [PendingMessages] Contact message stored in pending table: \(contactModelId)")
            
            // Add message to UI immediately with progress bar (matching Android messageList.add + itemAdd)
            onMessageAdded?(newMessage)
            
            let userFTokenKey = UserDefaults.standard.string(forKey: Constant.FCM_TOKEN) ?? ""
            
            MessageUploadService.shared.uploadMessage(
                model: newMessage,
                filePath: nil,
                userFTokenKey: userFTokenKey,
                deviceType: "2"
            ) { success, errorMessage in
                if success {
                    print("✅ [MULTI_CONTACT] Uploaded contact \(index + 1)/\(selectedContacts.count) for modelId=\(contactModelId)")
                    // Check if message exists in Firebase and stop progress bar (matching Android)
                    self.checkMessageInFirebaseAndStopProgress(messageId: contactModelId, receiverUid: receiverUid)
                } else {
                    print("❌ [MULTI_CONTACT] Upload error: \(errorMessage ?? "Unknown error")")
                    Constant.showToast(message: "Failed to send contact. Please try again.")
                    // Keep receiverLoader as 0 to show progress bar (message still pending)
                }
            }
        }
        
        // Call the original onSend callback for any additional handling
        onSend(trimmedCaption)
    }
}

// MARK: - Contact Preview Item (matching Android item_contact_preview.xml)
struct ContactPreviewItem: View {
    let contact: ContactPickerInfo
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Contact Avatar (matching Android contactAvatar - 100dp x 100dp)
                ZStack {
                    // Avatar background circle (matching Android contact_avatar_background drawable)
                    Circle()
                        .fill(Color("modetheme2")) // Use theme color for avatar background
                        .frame(width: 100, height: 100)
                    
                    // Contact Initial (matching Android contactInitial TextView)
                    Text(contact.initial)
                        .font(.custom("Inter18pt-Bold", size: 36)) // textSize="36sp", textStyle="bold"
                        .foregroundColor(.black) // textColor="@color/black"
                }
                .padding(.top, 40) // layout_marginTop="40dp"
                
                // Contact Name (matching Android contactName TextView)
                Text(contact.displayName)
                    .font(.custom("Inter18pt-Medium", size: 24)) // textSize="24sp"
                    .foregroundColor(.white) // textColor="@color/white"
                    .multilineTextAlignment(.center)
                    .lineLimit(2) // maxLines="2"
                    .padding(.horizontal, 40) // layout_marginHorizontal="40dp"
                    .padding(.top, 30) // layout_marginTop="30dp"
                
                // Contact Phone (matching Android contactPhone TextView)
                if let phone = contact.phone, !phone.isEmpty {
                    Text(phone)
                        .font(.custom("Inter18pt-Medium", size: 18)) // textSize="18sp"
                        .foregroundColor(Color("gray3")) // textColor="@color/gray3"
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40) // layout_marginHorizontal="40dp"
                        .padding(.top, 12) // layout_marginTop="12dp"
                }
                
                // Contact Email (matching Android contactEmail TextView)
                if let email = contact.email, !email.isEmpty {
                    Text(email)
                        .font(.custom("Inter18pt-Medium", size: 16)) // textSize="16sp"
                        .foregroundColor(Color("gray3")) // textColor="@color/gray3"
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40) // layout_marginHorizontal="40dp"
                        .padding(.top, 8) // layout_marginTop="8dp"
                }
                
                Spacer()
            }
        }
    }
}

