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
    @State private var downArrowCount: Int = 0
    @State private var showDownArrowCount: Bool = false
    @State private var maxMessageLength: Int = 1000
    
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
                NavigationLink(destination: UserInfoScreen(
                    recUserId: contact.uid,
                    recUserName: contact.fullName
                )) {
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
                // Background matching modern_play_button_bg
                Circle()
                    .fill(Color("BackgroundColor"))
                    .frame(width: 35, height: 35)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                VStack(spacing: 0) {
                    // Down arrow image - 24dp x 24dp, original colors (no tint)
                    Image("down_arrow")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                    
                    // Count text - hidden by default (visibility="gone")
                    if showDownArrowCount {
                        Text("\(downArrowCount)")
                            .font(.custom("Inter18pt-Bold", size: 12))
                            .foregroundColor(Color("blue"))
                    }
                }
                .padding(5) // 5dp padding
            }
        }
        .padding(.trailing, 10) // marginEnd="10dp"
        .padding(.bottom, 45) // marginBottom="45dp"
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
                                .onChange(of: messageText) { newValue in
                                    updateMessageText(newValue)
                                }
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
                        handleSendButtonClick()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color("blue"))
                                .frame(width: 50, height: 50)
                            
                            // Show mic icon when text is empty, send icon when text is present
                            if messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedCount == 0 {
                            Image("mikesvg")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 22, height: 22)
                                .foregroundColor(.white)
                                .padding(.top, 4)
                                .padding(.bottom, 8)
                            } else {
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
    
    private func updateMessageText(_ newValue: String) {
        let trimmedText = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedText.isEmpty {
            // Clear typing status when messageBox is empty
            clearTypingStatus()
        } else {
            // Update typing status when user is typing
            updateTypingStatus(true)
        }
    }
    
    private func clearTypingStatus() {
        // TODO: Clear typing status in Firebase
    }
    
    private func updateTypingStatus(_ isTyping: Bool) {
        // TODO: Update typing status in Firebase
    }
    
    // MARK: - Send Button Handler (matching Android sendGrp.setOnClickListener)
    private func handleSendButtonClick() {
        print("DIALOGUE_DEBUG: === SEND BUTTON CLICKED ===")
        
        // Check if multi-select mode is active
        if selectedCount > 0 {
            print("DIALOGUE_DEBUG: Send button clicked for multi-images!")
            // TODO: Show full-screen dialog for multi-image preview
            // setupMultiImagePreviewWithData()
            return
        }
        
        // Normal message send
        let message = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        
        // Capture values needed in the closure
        let receiverUid = contact.uid
        let replyMsg = replyMessage
        let replyType = replyDataType
        let limitStatusValue = limitStatus
        let totalMsgLimitValue = totalMsgLimit
        
        // Run in background thread (matching Android new Thread)
        // Note: No need for [weak self] since ChattingScreen is a struct (value type)
        DispatchQueue.global(qos: .userInitiated).async {
            
            do {
                // Generate unique message ID
                let modelId = UUID().uuidString
                
                // Get current time in "hh:mm a" format (matching Android)
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "hh:mm a"
                let currentDateTimeString = dateFormatter.string(from: Date())
                
                // Get current date (matching Android Constant.getCurrentDate())
                let currentDateFormatter = DateFormatter()
                currentDateFormatter.dateFormat = "yyyy-MM-dd"
                let currentDateString = currentDateFormatter.string(from: Date())
                
                // Get timestamp
                let timestamp = Date().timeIntervalSince1970
                
                // Get user name from UserDefaults (matching Android Constant.getSF.getString(Constant.full_name, ""))
                let userName = UserDefaults.standard.string(forKey: "full_name") ?? ""
                let micPhoto = UserDefaults.standard.string(forKey: "profilePic") ?? ""
                
                // Create emoji model array (matching Android - default empty emoji)
                let emojiModels: [EmojiModel] = [EmojiModel(name: "", emoji: "")]
                
                // Create message model with all parameters (matching Android messageModel structure)
        let newMessage = ChatMessage(
                    id: modelId,
                    uid: Constant.SenderIdMy,
                    message: message,
                    time: currentDateTimeString,
                    document: "",
                    dataType: "Text",
                    fileExtension: nil,
                    name: nil,
                    phone: nil,
                    micPhoto: micPhoto,
                    miceTiming: nil,
                    userName: userName,
                    receiverId: receiverUid,
                    replytextData: replyMsg.isEmpty ? nil : replyMsg,
                    replyKey: replyMsg.isEmpty ? nil : modelId,
                    replyType: replyType.isEmpty ? nil : replyType,
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
                    emojiModel: emojiModels,
                    emojiCount: nil,
                    timestamp: timestamp,
                    imageWidth: nil,
                    imageHeight: nil,
                    aspectRatio: nil,
                    selectionCount: nil,
                    selectionBunch: nil,
                    receiverLoader: 0
                )
        
                // TODO: Store message in SQLite pending table before upload
                // try DatabaseHelper.shared.insertPendingMessage(model)
                
                // Check message limit status
                if limitStatusValue == "0" {
                    // Upload message using MessageUploadService (matching Android)
                    DispatchQueue.main.async {
                        // Get user FCM token
                        let userFTokenKey = UserDefaults.standard.string(forKey: Constant.FCM_TOKEN) ?? ""
                        let deviceType = "2" // iOS device type
                        
                        // Use MessageUploadService (matching Android MessageUploadService)
                        MessageUploadService.shared.uploadMessage(
                            model: newMessage,
                            filePath: nil, // Text messages don't have files
                            userFTokenKey: userFTokenKey,
                            deviceType: deviceType
                        ) { success, errorMessage in
                            if success {
                                print("✅ MessageUploadService: Message uploaded successfully with ID: \(modelId)")
                            } else {
                                print("❌ MessageUploadService: Error uploading message: \(errorMessage ?? "Unknown error")")
                            }
                        }
                    }
                } else {
                    // Show message limit toast
                    DispatchQueue.main.async {
                        Constant.showToast(
                            message: "Msg limit set for privacy in a day - \(totalMsgLimitValue)"
                        )
                    }
                }
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    // Add message to list
                    self.messages.append(newMessage)
                    
                    // Clear typing status when message is sent
                    self.clearTypingStatus()
                    
                    // Clear message box and reply layout
                    self.messageText = ""
                    self.showReplyLayout = false
                    self.replyMessage = ""
                    self.replySenderName = ""
                    self.replyDataType = ""
                    self.hideEmojiAndGalleryPickers()
                    
                    // Hide down arrow cardview when new message is added (user is at bottom)
                    // TODO: Hide down arrow if visible
                }
                
            } catch {
                print("SendGroupClickListener: Error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    // Re-enable message box if there was an error
                    // In SwiftUI, TextField is always enabled, but we can handle errors here
                }
            }
        }
    }
    
    // Legacy method - keeping for backward compatibility if needed
    private func uploadMessageToFirebase(
        message: String,
        modelId: String,
        currentDateTimeString: String
    ) {
        // This method is no longer used - upload is now done directly in handleSendButtonClick
        // Keeping for backward compatibility
    }
    
    private func hideEmojiAndGalleryPickers() {
        // Hide emoji picker if visible
        if showEmojiPicker {
            withAnimation {
                showEmojiPicker = false
            }
        }
        
        // Hide gallery picker if visible
        if showGalleryPicker {
            withAnimation {
                showGalleryPicker = false
            }
        }
        
        // Request focus on message box (show keyboard)
        // In SwiftUI, we can use @FocusState to manage focus
        // TODO: Add @FocusState for message box focus management
    }
    
    private func sendMessage() {
        // Legacy method - keeping for backward compatibility
        handleSendButtonClick()
    }
}

// MARK: - Chat Message Model (matching Android messageModel.java)
struct ChatMessage: Identifiable, Codable {
    // CodingKeys to map Swift property names to JSON keys (matching Android)
    enum CodingKeys: String, CodingKey {
        case id, uid, message, time, document, dataType
        case fileExtension = "extension" // Map fileExtension to "extension" in JSON
        case name, phone, micPhoto, miceTiming, userName, receiverId
        case replytextData, replyKey, replyType, replyOldData, replyCrtPostion
        case forwaredKey, groupName, docSize, fileName, thumbnail, fileNameThumbnail, caption
        case notification, currentDate, emojiModel, emojiCount, timestamp
        case imageWidth, imageHeight, aspectRatio, selectionCount, selectionBunch, receiverLoader
    }
    
    // Core message fields
    let id: String // modelId
    var uid: String // senderId
    var message: String // message text
    var time: String // formatted time "hh:mm a"
    var document: String // document URL (image/video/document)
    var dataType: String // Text, img, video, doc, contact, voiceAudio
    var fileExtension: String? // file extension
    var name: String? // contact name (for contact type)
    var phone: String? // contact phone (for contact type)
    var micPhoto: String? // sender profile photo
    var miceTiming: String? // audio timing (for voice messages)
    var userName: String? // sender user name
    var receiverId: String // receiverUid
    
    // Reply fields
    var replytextData: String?
    var replyKey: String?
    var replyType: String?
    var replyOldData: String?
    var replyCrtPostion: String?
    
    // Forward and group fields
    var forwaredKey: String?
    var groupName: String?
    
    // File/document fields
    var docSize: String?
    var fileName: String?
    var thumbnail: String?
    var fileNameThumbnail: String?
    var caption: String?
    
    // Notification and date
    var notification: Int
    var currentDate: String?
    
    // Emoji fields
    var emojiModel: [EmojiModel]?
    var emojiCount: String?
    
    // Timestamp
    var timestamp: TimeInterval // long timestamp
    
    // Image dimensions
    var imageWidth: String?
    var imageHeight: String?
    var aspectRatio: String?
    
    // Selection bunch (for multi-image messages)
    var selectionCount: String?
    var selectionBunch: [SelectionBunchModel]?
    
    // Receiver loader (for loading state)
    var receiverLoader: Int
    
    // Initializer with all parameters (matching Android constructor)
    init(
        id: String,
        uid: String,
        message: String,
        time: String,
        document: String = "",
        dataType: String = "Text",
        fileExtension: String? = nil,
        name: String? = nil,
        phone: String? = nil,
        micPhoto: String? = nil,
        miceTiming: String? = nil,
        userName: String? = nil,
        receiverId: String,
        replytextData: String? = nil,
        replyKey: String? = nil,
        replyType: String? = nil,
        replyOldData: String? = nil,
        replyCrtPostion: String? = nil,
        forwaredKey: String? = nil,
        groupName: String? = nil,
        docSize: String? = nil,
        fileName: String? = nil,
        thumbnail: String? = nil,
        fileNameThumbnail: String? = nil,
        caption: String? = nil,
        notification: Int = 1,
        currentDate: String? = nil,
        emojiModel: [EmojiModel]? = nil,
        emojiCount: String? = nil,
        timestamp: TimeInterval = Date().timeIntervalSince1970,
        imageWidth: String? = nil,
        imageHeight: String? = nil,
        aspectRatio: String? = nil,
        selectionCount: String? = nil,
        selectionBunch: [SelectionBunchModel]? = nil,
        receiverLoader: Int = 0
    ) {
        self.id = id
        self.uid = uid
        self.message = message
        self.time = time
        self.document = document
        self.dataType = dataType
        self.fileExtension = fileExtension
        self.name = name
        self.phone = phone
        self.micPhoto = micPhoto
        self.miceTiming = miceTiming
        self.userName = userName
        self.receiverId = receiverId
        self.replytextData = replytextData
        self.replyKey = replyKey
        self.replyType = replyType
        self.replyOldData = replyOldData
        self.replyCrtPostion = replyCrtPostion
        self.forwaredKey = forwaredKey
        self.groupName = groupName
        self.docSize = docSize
        self.fileName = fileName
        self.thumbnail = thumbnail
        self.fileNameThumbnail = fileNameThumbnail
        self.caption = caption
        self.notification = notification
        self.currentDate = currentDate
        self.emojiModel = emojiModel
        self.emojiCount = emojiCount
        self.timestamp = timestamp
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.aspectRatio = aspectRatio
        self.selectionCount = selectionCount
        self.selectionBunch = selectionBunch
        self.receiverLoader = receiverLoader
    }
    
    // Convenience initializer for simple text messages
    init(
        id: String,
        text: String,
        senderId: String,
        receiverId: String,
        timestamp: Date,
        dataType: String = "Text"
    ) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "hh:mm a"
        let timeString = dateFormatter.string(from: timestamp)
        
        self.init(
            id: id,
            uid: senderId,
            message: text,
            time: timeString,
            document: "",
            dataType: dataType,
            receiverId: receiverId,
            timestamp: timestamp.timeIntervalSince1970
        )
    }
}

// MARK: - Emoji Model (matching Android emojiModel.java)
struct EmojiModel: Codable, Equatable, Hashable {
    var name: String
    var emoji: String
    
    init(name: String = "", emoji: String = "") {
        self.name = name
        self.emoji = emoji
    }
}

// MARK: - Selection Bunch Model (matching Android selectionBunchModel.java)
struct SelectionBunchModel: Codable, Equatable, Hashable {
    var imgUrl: String
    var fileName: String
    
    init(imgUrl: String = "", fileName: String = "") {
        self.imgUrl = imgUrl
        self.fileName = fileName
    }
}

// MARK: - Contact Info (for contact type messages)
struct ContactInfo: Codable {
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
        self.isSentByMe = message.uid == Constant.SenderIdMy
    }
    
    var body: some View {
        HStack {
            if isSentByMe {
                Spacer()
            }
            
            VStack(alignment: isSentByMe ? .trailing : .leading, spacing: 4) {
                Text(message.message)
                    .font(.custom("Inter18pt-Regular", size: 16))
                    .foregroundColor(isSentByMe ? .white : Color("TextColor"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSentByMe ? Color("blue") : Color("message_box_bg"))
                    )
                
                Text(message.time)
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

