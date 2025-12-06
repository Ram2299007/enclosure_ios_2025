//
//  ChattingScreen.swift
//  Enclosure
//
//  Created by Ram Lohar on 30/04/25.
//

import SwiftUI

struct ChattingScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    let contact: UserActiveContactModel
    
    @State private var messageText: String = ""
    @State private var showEmojiPicker: Bool = false
    @State private var showGalleryPicker: Bool = false
    @State private var showMenu: Bool = false
    @State private var showSearch: Bool = false
    @State private var searchText: String = ""
    @State private var showMultiSelectHeader: Bool = false
    @State private var selectedCount: Int = 0
    @State private var showReplyLayout: Bool = false
    @State private var replyMessage: String = ""
    @State private var replySenderName: String = ""
    @State private var replyDataType: String = ""
    @State private var showBlockContainer: Bool = false
    @State private var characterCount: Int = 0
    @State private var showCharacterCount: Bool = false
    @State private var isPressed: Bool = false
    
    // Message list state
    @State private var messages: [ChatMessage] = []
    
    // Valuable card state
    @State private var limitStatus: String = "0"
    @State private var totalMsgLimit: String = "0"
    @State private var showLimitStatus: Bool = false
    @State private var showTotalMsgLimit: Bool = false
    
    var body: some View {
        ZStack {
            // Background color matching Android modetheme2
            Color("BackgroundColor")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Message list
                messageListView
                
                // Multi-select counter (hidden by default)
                if showMultiSelectHeader && selectedCount > 0 {
                    multiSelectCounterView
                }
                
                // Scroll down button (hidden by default)
                scrollDownButton
                
                // Bottom input area
                bottomInputView
            }
            
            // Menu overlay
            if showMenu {
                menuOverlay
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadMessages()
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 0) {
            // Main header card
            if !showMultiSelectHeader {
                headerCardView
            } else {
                multiSelectHeaderView
            }
        }
    }
    
    private var headerCardView: some View {
        VStack(spacing: 0) {
            // Header card matching Android header1Cardview
            HStack(spacing: 0) {
                // Back button
                Button(action: handleBackTap) {
                    ZStack {
                        if isPressed {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 40, height: 40)
                                .scaleEffect(isPressed ? 1.2 : 1.0)
                                .animation(.easeOut(duration: 0.3), value: isPressed)
                        }
                        
                        Image("leftvector")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 18)
                            .foregroundColor(Color("TextColor"))
                    }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { _ in
                            withAnimation {
                                isPressed = false
                            }
                        }
                )
                .buttonStyle(.plain)
                .padding(.leading, 10)
                .padding(.trailing, 8)
                
                // Profile section
                Button(action: {
                    // TODO: Navigate to profile
                }) {
                    HStack(spacing: 0) {
                        // Profile image with border
                        ZStack {
                            Circle()
                                .stroke(Color("blue"), lineWidth: 2)
                                .frame(width: 44, height: 44)
                            
                            CachedAsyncImage(url: URL(string: contact.photo)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                            } placeholder: {
                                Image("inviteimg")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.leading, 5)
                        .padding(.trailing, 16)
                        
                        // Name
                        Text(contact.fullName)
                            .font(.custom("Inter18pt-Medium", size: 16))
                            .foregroundColor(Color("TextColor"))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Right side menu
                HStack(spacing: 0) {
                    // Search button (hidden by default)
                    if showSearch {
                        TextField("Search...", text: $searchText)
                            .font(.custom("Inter18pt-Medium", size: 16))
                            .foregroundColor(Color("TextColor"))
                            .textFieldStyle(PlainTextFieldStyle())
                            .frame(width: 150)
                    }
                    
                    // Menu button (three dots)
                    Button(action: {
                        withAnimation {
                            showMenu.toggle()
                        }
                    }) {
                        VStack(spacing: 3) {
                            Circle()
                                .fill(Color("menuPointColor"))
                                .frame(width: 4, height: 4)
                            Circle()
                                .fill(Color("blue"))
                                .frame(width: 4, height: 4)
                            Circle()
                                .fill(Color("gray3"))
                                .frame(width: 4, height: 4)
                        }
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color("circlebtnhover").opacity(0.1))
                        )
                    }
                    .padding(.trailing, 10)
                }
            }
            .frame(height: 50)
            .background(Color("BackgroundColor"))
        }
    }
    
    private var multiSelectHeaderView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Close button
                Button(action: {
                    withAnimation {
                        showMultiSelectHeader = false
                        selectedCount = 0
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color("circlebtnhover").opacity(0.1))
                            .frame(width: 40, height: 40)
                        
                        Image("crossimg")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 18)
                            .foregroundColor(Color("TextColor"))
                    }
                }
                .padding(.leading, 20)
                .padding(.trailing, 5)
                
                // Selected count text
                Text("Selected \(selectedCount)")
                    .font(.custom("Inter18pt-Medium", size: 16))
                    .foregroundColor(Color("TextColor"))
                    .padding(.leading, 21)
                
                Spacer()
                
                // Forward button
                Button(action: {
                    // TODO: Handle forward
                }) {
                    Text("forward")
                        .font(.custom("Inter18pt-Regular", size: 10))
                        .foregroundColor(Color("TextColor"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color("dxForward"))
                        )
                }
                .padding(.trailing, 10)
            }
            .frame(height: 50)
            .background(Color("edittextBg"))
        }
    }
    
    // MARK: - Message List View
    private var messageListView: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if messages.isEmpty {
                            // Valuable card view (matching Android valuable CardView)
                            VStack {
                                Spacer(minLength: 0)
                                
                                VStack(spacing: 0) {
                                    Text("Your Message Will Become More Valuable Here")
                                        .font(.custom("Inter18pt-Regular", size: 12))
                                        .foregroundColor(Color("black_white_cross"))
                                        .multilineTextAlignment(.center)
                                        .padding(7)
                                    
                                    // limit_status TextView (hidden by default)
                                    if showLimitStatus {
                                        Text(limitStatus)
                                            .font(.custom("Inter18pt-Regular", size: 12))
                                            .foregroundColor(Color(red: 0x53/255.0, green: 0x52/255.0, blue: 0x52/255.0))
                                            .padding(7)
                                    }
                                    
                                    // total_msg_limit TextView (hidden by default)
                                    if showTotalMsgLimit {
                                        Text(totalMsgLimit)
                                            .font(.custom("Inter18pt-Regular", size: 12))
                                            .foregroundColor(Color(red: 0x53/255.0, green: 0x52/255.0, blue: 0x52/255.0))
                                            .padding(7)
                                    }
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color("cardBackgroundColornew"))
                                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                                )
                                .padding(.horizontal, 16)
                                
                                Spacer(minLength: 0)
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                        } else {
                            ForEach(messages) { message in
                                MessageBubbleView(message: message)
                                    .id(message.id)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onAppear {
                    if let lastMessage = messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Multi-select Counter
    private var multiSelectCounterView: some View {
        Text("\(selectedCount)")
            .font(.custom("Inter18pt-Bold", size: 12))
            .foregroundColor(.white)
            .frame(width: 24, height: 24)
            .background(
                Circle()
                    .fill(Color("blue"))
            )
            .padding(.trailing, 15)
            .padding(.bottom, 5)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
    
    // MARK: - Scroll Down Button
    private var scrollDownButton: some View {
        Button(action: {
            // TODO: Scroll to bottom
        }) {
            ZStack {
                Circle()
                    .fill(Color("BackgroundColor"))
                    .frame(width: 35, height: 35)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                Image("down_arrow")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(Color("blue"))
            }
        }
        .padding(.trailing, 10)
        .padding(.bottom, 45)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    
    // MARK: - Bottom Input View
    private var bottomInputView: some View {
        VStack(spacing: 0) {
            // Block container (hidden by default)
            if showBlockContainer {
                blockContainerView
            }
            
            // Message input container (messageboxContainer)
            messageInputContainer
        }
        .background(Color("edittextBg"))
    }
    
    private var blockContainerView: some View {
        HStack(spacing: 50) {
            // Clear All button
            Button(action: {
                // TODO: Clear all messages
            }) {
                HStack {
                    Image("deleteicon")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.red)
                    
                    Text("Clear All")
                        .font(.custom("Inter18pt-Bold", size: 14))
                        .foregroundColor(.red)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color("BackgroundColor"))
                )
            }
            
            // Unblock button
            Button(action: {
                // TODO: Unblock user
            }) {
                HStack {
                    Image("unblock")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundColor(Color("green_call"))
                    
                    Text("Unblock")
                        .font(.custom("Inter18pt-Bold", size: 14))
                        .foregroundColor(Color("green_call"))
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color("BackgroundColor"))
                )
            }
        }
        .padding(20)
        .background(Color("chattingMessageBox"))
    }
    
    private var messageInputContainer: some View {
        // Outer vertical container (messageboxContainer) - orientation="vertical"
        VStack(spacing: 0) {
            // Inner horizontal container - padding="2dp"
            HStack(alignment: .bottom, spacing: 0) {
                // Vertical container with layout_weight="1" containing reply and edit layouts
                VStack(spacing: 0) {
                    // Reply layout (replylyout) - marginStart="2dp" marginTop="2dp" marginEnd="2dp"
                    if showReplyLayout {
                        replyLayoutView
                            .padding(.horizontal, 2)
                            .padding(.top, 2)
                    }
                    
                    // Main input layout (editLyt) - marginStart="2dp" marginEnd="2dp"
                    HStack(alignment: .center, spacing: 0) {
                        // Attach button (gallary) - marginStart="5dp"
                        Button(action: {
                            withAnimation {
                                showGalleryPicker.toggle()
                                showEmojiPicker = false
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color("chattingMessageBox"))
                                    .frame(width: 40, height: 40)
                                
                                Image("attachsvg")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                    .foregroundColor(Color("chtbtncolor"))
                            }
                        }
                        .padding(.leading, 5)
                        
                        // Message input field container - layout_weight="1"
                        VStack(alignment: .leading, spacing: 0) {
                            TextField("Message on Ec", text: $messageText, axis: .vertical)
                                .font(.custom("Inter18pt-Medium", size: 17))
                                .foregroundColor(Color("black_white_cross"))
                                .lineLimit(4)
                                .frame(maxWidth: 180, alignment: .leading)
                                .padding(.leading, 0)
                                .padding(.trailing, 20)
                                .padding(.top, 5)
                                .padding(.bottom, 5)
                                .background(Color.clear)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Emoji button (emoji) - marginEnd="5dp"
                        Button(action: {
                            withAnimation {
                                showEmojiPicker.toggle()
                                showGalleryPicker = false
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color("chattingMessageBox"))
                                    .frame(width: 40, height: 40)
                                
                                EmojiIconView()
                                    .frame(width: 20, height: 20)
                            }
                        }
                        .padding(.trailing, 5)
                    }
                    .frame(height: 50) // Match send button height (50dp)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color("message_box_bg"))
                    )
                    .padding(.horizontal, 5)
                }
                .frame(maxWidth: .infinity) // layout_weight="1"
                
                // Send button (sendGrpLyt) - layout_gravity="center_vertical|bottom"
                VStack(spacing: 0) {
                    Button(action: {
                        sendMessage()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color("blue"))
                                .frame(width: 50, height: 50)
                            
                            Image("mikesvg")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 22, height: 22)
                                .foregroundColor(.white)
                                .padding(.top, 4)
                                .padding(.bottom, 8)
                        }
                    }
                }
                .padding(.horizontal, 5)
            }
            .padding(2) // Inner horizontal container padding="2dp"
            
            // Emoji picker layout (emojiLyt) - below horizontal container
            if showEmojiPicker {
                emojiPickerView
            }
            
            // Gallery picker layout (galleryRecentLyt) - below horizontal container
            if showGalleryPicker {
                galleryPickerView
            }
        }
    }
    
    private var replyLayoutView: some View {
        HStack(spacing: 0) {
            // Reply indicator bar - width="3dp" height="50dp"
            Rectangle()
                .fill(Color("blue"))
                .frame(width: 3, height: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(replySenderName)
                    .font(.custom("Inter18pt-Bold", size: 14))
                    .foregroundColor(Color("blue"))
                
                Text(replyMessage)
                    .font(.custom("Inter18pt-Regular", size: 14))
                    .foregroundColor(Color(red: 0x78/255.0, green: 0x78/255.0, blue: 0x7A/255.0))
                    .lineLimit(1)
            }
            .padding(.leading, 10)
            
            Spacer()
            
            // Cancel reply button
            Button(action: {
                withAnimation {
                    showReplyLayout = false
                    replyMessage = ""
                    replySenderName = ""
                }
            }) {
                Image("crosssvg")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundColor(Color("blue"))
            }
            .padding(.trailing, 12)
        }
        .frame(height: 55) // Matching Android height="55dp"
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color("message_box_bg_3"))
        )
    }
    
    // MARK: - Emoji Picker View
    private var emojiPickerView: some View {
        VStack(spacing: 0) {
            // Emoji Search Box - Top
            HStack(spacing: 0) {
                Button(action: {
                    withAnimation {
                        showEmojiPicker = false
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color("circlebtnhover").opacity(0.1))
                            .frame(width: 40, height: 40)
                        
                        Image("leftvector")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 18)
                            .foregroundColor(Color("TextColor"))
                    }
                }
                .padding(.leading, 8)
                
                TextField("Search emojis...", text: .constant(""))
                    .font(.custom("Inter18pt-Regular", size: 14))
                    .foregroundColor(Color("black_white_cross"))
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .padding(.horizontal, 8)
            }
            .frame(height: 50)
            .padding(.horizontal, 8)
            
            // Emoji RecyclerView - height="250dp"
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 8) {
                    // TODO: Add emoji items here
                    ForEach(0..<20) { _ in
                        Text("😀")
                            .font(.system(size: 30))
                            .frame(width: 40, height: 40)
                    }
                }
                .padding(8)
            }
            .frame(height: 250)
        }
    }
    
    // MARK: - Gallery Picker View
    private var galleryPickerView: some View {
        VStack(spacing: 0) {
            // Gallery card view - height="300dp"
            VStack(spacing: 0) {
                // Gallery RecyclerView
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 2) {
                        // TODO: Add gallery images here
                        ForEach(0..<12) { _ in
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 80, height: 80)
                                .cornerRadius(4)
                        }
                    }
                    .padding(5)
                }
                .frame(height: 250)
                
                // Bottom view with action buttons
                HStack(spacing: 0) {
                    // Camera button
                    Button(action: {
                        // TODO: Open camera
                    }) {
                        VStack(spacing: 5) {
                            Image("camera")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(Color("chtbtncolor"))
                            
                            Text("Camera")
                                .font(.custom("Inter18pt-Medium", size: 11))
                                .foregroundColor(Color("chtbtncolor"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(7)
                    }
                    
                    // Photo button
                    Button(action: {
                        // TODO: Open photo gallery
                    }) {
                        VStack(spacing: 5) {
                            Image("gallery")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(Color("chtbtncolor"))
                            
                            Text("Photo")
                                .font(.custom("Inter18pt-Medium", size: 11))
                                .foregroundColor(Color("chtbtncolor"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(7)
                    }
                    
                    // Video button
                    Button(action: {
                        // TODO: Open video picker
                    }) {
                        VStack(spacing: 5) {
                            Image("videopng")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(Color("chtbtncolor"))
                            
                            Text("Video")
                                .font(.custom("Inter18pt-Medium", size: 11))
                                .foregroundColor(Color("chtbtncolor"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(7)
                    }
                    
                    // File button
                    Button(action: {
                        // TODO: Open document picker
                    }) {
                        VStack(spacing: 5) {
                            Image("documentsvg")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(Color("chtbtncolor"))
                            
                            Text("File")
                                .font(.custom("Inter18pt-Medium", size: 11))
                                .foregroundColor(Color("chtbtncolor"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(7)
                    }
                    
                    // Contact button
                    Button(action: {
                        // TODO: Open contact picker
                    }) {
                        VStack(spacing: 5) {
                            Image("contact")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(Color("chtbtncolor"))
                            
                            Text("Contact")
                                .font(.custom("Inter18pt-Medium", size: 11))
                                .foregroundColor(Color("chtbtncolor"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(7)
                    }
                }
                .padding(.horizontal, 7)
            }
            .frame(height: 300)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color("chattingMessageBox"))
            )
            .padding(2)
        }
    }
    
    // MARK: - Menu Overlay
    private var menuOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showMenu = false
                    }
                }
            
            VStack(alignment: .trailing, spacing: 0) {
                VStack(alignment: .leading, spacing: 18) {
                    Button(action: {
                        withAnimation {
                            showSearch = true
                            showMenu = false
                        }
                    }) {
                        Text("Search")
                            .font(.custom("Inter18pt-Medium", size: 17))
                            .foregroundColor(Color("TextColor"))
                    }
                    
                    Button(action: {
                        // TODO: Navigate to profile
                        showMenu = false
                    }) {
                        Text("For visible")
                            .font(.custom("Inter18pt-Medium", size: 17))
                            .foregroundColor(Color("TextColor"))
                    }
                    
                    Button(action: {
                        // TODO: Clear chat
                        showMenu = false
                    }) {
                        Text("Clear Chat")
                            .font(.custom("Inter18pt-Medium", size: 17))
                            .foregroundColor(Color("TextColor"))
                    }
                }
                .padding(17)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color("BackgroundColor"))
            )
            .frame(width: 180)
            .padding(.top, 50)
            .padding(.trailing, 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
    }
    
    // MARK: - Helper Functions
    private func handleBackTap() {
        withAnimation {
            isPressed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            dismiss()
            isPressed = false
        }
    }
    
    private func loadMessages() {
        // TODO: Load messages from Firebase or API
        // For now, using empty array
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // TODO: Send message to Firebase or API
        let newMessage = ChatMessage(
            id: UUID().uuidString,
            text: messageText,
            senderId: Constant.SenderIdMy,
            receiverId: contact.uid,
            timestamp: Date(),
            dataType: "Text"
        )
        
        messages.append(newMessage)
        messageText = ""
        showReplyLayout = false
        
        // TODO: Upload message to server
    }
}

// MARK: - Chat Message Model
struct ChatMessage: Identifiable {
    let id: String
    let text: String
    let senderId: String
    let receiverId: String
    let timestamp: Date
    let dataType: String
    var imageUrl: String? = nil
    var videoUrl: String? = nil
    var documentUrl: String? = nil
    var contactInfo: ContactInfo? = nil
}

struct ContactInfo {
    let name: String
    let phoneNumber: String
    let email: String?
}

// MARK: - Message Bubble View
struct MessageBubbleView: View {
    let message: ChatMessage
    let isSentByMe: Bool
    
    init(message: ChatMessage) {
        self.message = message
        self.isSentByMe = message.senderId == Constant.SenderIdMy
    }
    
    var body: some View {
        HStack {
            if isSentByMe {
                Spacer()
            }
            
            VStack(alignment: isSentByMe ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.custom("Inter18pt-Regular", size: 16))
                    .foregroundColor(isSentByMe ? .white : Color("TextColor"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSentByMe ? Color("blue") : Color("message_box_bg"))
                    )
                
                Text(formatTime(message.timestamp))
                    .font(.custom("Inter18pt-Regular", size: 10))
                    .foregroundColor(Color("gray3"))
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            
            if !isSentByMe {
                Spacer()
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Emoji Icon View (matching Android vector drawable)
struct EmojiIconView: View {
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            // Android viewport is 26x24, we'll use 26 as base for scaling
            let scale = size / 26.0
            
            ZStack {
                // Main circle (face) - radius 12.522 from Android vector
                // The circle is centered in the viewport
                Circle()
                    .fill(Color("chtbtncolor").opacity(0.81))
                    .frame(width: 12.522 * 2 * scale, height: 12.522 * 2 * scale)
                
                // Left eye - center at (8.757, 12.757) with radius 2.757
                Circle()
                    .fill(Color("chattingMessageBox"))
                    .frame(width: 2.757 * 2 * scale, height: 2.757 * 2 * scale)
                    .offset(
                        x: (8.757 - 13.0) * scale, // Offset from viewport center (13, 12)
                        y: (12.757 - 12.0) * scale
                    )
                
                // Right eye - center at (16.634, 12.757) with radius 2.757
                Circle()
                    .fill(Color("chattingMessageBox"))
                    .frame(width: 2.757 * 2 * scale, height: 2.757 * 2 * scale)
                    .offset(
                        x: (16.634 - 13.0) * scale,
                        y: (12.757 - 12.0) * scale
                    )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

#Preview {
    ChattingScreen(
        contact: UserActiveContactModel(
            photo: "",
            fullName: "John Doe",
            mobileNo: "1234567890",
            caption: "",
            uid: "123",
            sentTime: "10:00 AM",
            dataType: "Text",
            message: "",
            fToken: "",
            notification: 0,
            msgLimit: 100,
            deviceType: "iOS",
            messageId: "1",
            createdAt: ""
        )
    )
}

