//
//  GroupChattingScreen.swift
//  Enclosure
//
//  Created by Ram Lohar on 30/04/25.
//

import SwiftUI
import UIKit
import Photos
import PhotosUI
import AVFoundation
import FirebaseStorage
import FirebaseDatabase

struct GroupChattingScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    let group: GroupModel
    
    // Header state
    @State private var showSearch: Bool = false
    @State private var searchText: String = ""
    @State private var showMenu: Bool = false
    @State private var showMenu2: Bool = false
    @State private var showMultiSelectHeader: Bool = false
    @State private var selectedCount: Int = 0
    
    // Progress indicators
    @State private var showNetworkLoader: Bool = false
    @State private var showLoader: Bool = false
    
    // Message input state
    @State private var messageText: String = ""
    @FocusState private var isMessageFieldFocused: Bool
    @State private var characterCount: Int = 0
    @State private var showCharacterCount: Bool = false
    @State private var maxMessageLength: Int = 1000
    @State private var selectedAssetIds: Set<String> = [] // Track selected assets for badge
    @State private var sendButtonScale: CGFloat = 1.0
    
    // Reply layout state
    @State private var showReplyLayout: Bool = false
    @State private var replyMessage: String = ""
    @State private var replySenderName: String = ""
    @State private var replyDataType: String = ""
    @State private var replyImageUrl: String? = nil
    @State private var replyContactName: String? = nil
    @State private var replyFileExtension: String? = nil
    @State private var replyMessageId: String? = nil
    @State private var isReplyFromSender: Bool = false // Track if reply is from sender (for theme color)
    
    // Emoji layout state
    @State private var showEmojiLayout: Bool = false
    
    // Gallery picker state
    @State private var showGalleryPicker: Bool = false
    @State private var showCameraView: Bool = false
    @State private var wasGalleryPickerOpenBeforeCamera: Bool = false
    @State private var showWhatsAppImagePicker: Bool = false
    @State private var wasGalleryPickerOpenBeforeImagePicker: Bool = false
    @State private var showWhatsAppVideoPicker: Bool = false
    @State private var wasGalleryPickerOpenBeforeVideoPicker: Bool = false
    @State private var showWhatsAppContactPicker: Bool = false
    @State private var wasGalleryPickerOpenBeforeContactPicker: Bool = false
    @State private var showDocumentPicker: Bool = false
    @State private var showUnifiedGalleryPicker: Bool = false
    @State private var wasGalleryPickerOpenBeforeDocumentPicker: Bool = false
    @State private var selectedDocuments: [URL] = []
    @State private var showFilePickerActionSheet: Bool = false
    
    // Multi-image preview dialog state
    @State private var showMultiImagePreview: Bool = false
    @State private var multiImagePreviewCaption: String = ""
    @State private var multiImagePreviewAssets: [PHAsset] = [] // Store selected assets from WhatsAppLikeImagePicker
    
    // Multi-video preview dialog state
    @State private var showMultiVideoPreview: Bool = false
    @State private var multiVideoPreviewCaption: String = ""
    @State private var multiVideoPreviewAssets: [PHAsset] = [] // Store selected assets from WhatsAppLikeVideoPicker
    
    // Multi-contact preview dialog state
    @State private var showMultiContactPreview: Bool = false
    @State private var multiContactPreviewCaption: String = ""
    @State private var multiContactPreviewContacts: [ContactPickerInfo] = [] // Store selected contacts from WhatsAppLikeContactPicker
    
    // Multi-document preview dialog state
    @State private var showMultiDocumentPreview: Bool = false
    @State private var multiDocumentPreviewCaption: String = ""
    @State private var multiDocumentPreviewURLs: [URL] = [] // Store selected document URLs
    
    // Local gallery (mirrors Android dataRecview)
    @State private var photoAssets: [PHAsset] = []
    private let imageManager = PHCachingImageManager()
    
    // Date card state
    @State private var showDateCard: Bool = false
    @State private var dateText: String = "Today"
    
    // Valuable card state
    @State private var showValuableCard: Bool = false
    
    // Messages state (matching Android groupMessageList)
    @State private var messages: [GroupChatMessage] = []
    @State private var isLoading: Bool = false
    @State private var initialLoadDone: Bool = false
    @State private var lastKey: String? = nil // For pagination (matching Android lastKey)
    @State private var uniqueDates: Set<String> = [] // Track unique dates for date headers
    @State private var initiallyLoadedMessageIds: Set<String> = [] // Prevent duplicates from listener
    @State private var firebaseListenerHandle: DatabaseHandle? = nil // Firebase listener handle
    @State private var hasMoreMessages: Bool = true // Track if there are more messages to load
    @State private var selectedMessageIds: Set<String> = [] // Track selected messages for multi-select
    @State private var messageReceiverLoaders: [String: Int] = [:] // Store receiverLoader for each message (from Firebase)
    private let PAGE_SIZE: Int = 10 // Matching Android PAGE_SIZE
    
    var body: some View {
        ZStack {
            Color("BackgroundColor")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Main header (header1Cardview)
                if !showMultiSelectHeader {
                    header1
                } else {
                    header2
                }
                
                // Network loader
                if showNetworkLoader {
                    HorizontalProgressBar()
                        .frame(height: 2)
                }
                
                // Main loader
                if showLoader {
                    HorizontalProgressBar()
                        .frame(height: 4)
                        .frame(maxWidth: .infinity)
                }
                
                // Message list (positioned between header and input container)
                ZStack(alignment: .top) {
                    ScrollViewReader { proxy in
                    ScrollView {
                        GeometryReader { geometry in
                        LazyVStack(spacing: 0) {
                                // Load more indicator at top (matching Android)
                                if hasMoreMessages && !messages.isEmpty {
                                    ProgressView()
                                        .frame(height: 40)
                                        .onAppear {
                                            loadMore()
                                        }
                                }
                                
                                // Show valuable card when messages list is empty (matching ChattingScreen)
                                if messages.isEmpty && initialLoadDone {
                                    // Valuable card view (matching Android valuable CardView) - centered on screen
                                    VStack {
                                        Spacer()
                                        
                                        VStack(spacing: 0) {
                                            Text("Your Message Will Become More Valuable Here")
                                                .font(.custom("Inter18pt-Regular", size: 12))
                                                .foregroundColor(Color("TextColor"))
                                                .multilineTextAlignment(.center)
                                                .padding(7)
                                        }
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color("cardBackgroundColornew"))
                                        )
                                        .padding(.horizontal, 16)
                                        
                                        Spacer()
                                    }
                                    .frame(width: geometry.size.width)
                                    .frame(minHeight: geometry.size.height)
                                }
                                
                                // Messages list (matching Android RecyclerView)
                                ForEach(Array(messages.enumerated()), id: \.element.id) { index, groupMessage in
                                    // Convert GroupChatMessage to ChatMessage for MessageBubbleView
                                    let chatMessage = convertGroupMessageToChatMessage(groupMessage)
                                    
                                    // Only display Constant.Text datatype for now (as requested)
                                    if chatMessage.dataType == Constant.Text {
                                        MessageBubbleView(
                                            message: chatMessage,
                                            onHalfSwipe: { swipedMessage in
                                                // Handle multi-select mode first (matching Android)
                                                if showMultiSelectHeader {
                                                    toggleMessageSelection(messageId: swipedMessage.id)
                                                    return
                                                }
                                                handleHalfSwipeReply(swipedMessage)
                                            },
                                            onReplyTap: { message in
                                                // Handle multi-select mode first (matching Android)
                                                if showMultiSelectHeader {
                                                    toggleMessageSelection(messageId: message.id)
                                                    return
                                                }
                                                handleReplyTap(message: message)
                                            },
                                            onLongPress: { message, position in
                                                // Handle multi-select mode first (matching Android)
                                                if showMultiSelectHeader {
                                                    toggleMessageSelection(messageId: message.id)
                                                    return
                                                }
                                                handleLongPress(message: message, position: position)
                                            },
                                            isHighlighted: false,
                                            isMultiSelectMode: showMultiSelectHeader,
                                            isSelected: selectedMessageIds.contains(chatMessage.id),
                                            onSelectionToggle: { messageId in
                                                toggleMessageSelection(messageId: messageId)
                                            }
                                        )
                                        .id(chatMessage.id)
                                    }
                            }
                            }
                        }
                    }
                    .contentShape(Rectangle()) // Ensure entire area is tappable
                    .allowsHitTesting(true) // Ensure ScrollView can receive touches
                    .onChange(of: messages.count) { _ in
                        // Scroll to bottom when new messages are added (matching Android)
                        if !messages.isEmpty, let lastMessageId = messages.last?.id {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation {
                                    proxy.scrollTo(lastMessageId, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                    
                    // Multi-select small counter text overlay
                    if showMultiSelectHeader && selectedCount > 0 {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("\(selectedCount)")
                                    .font(.custom("Inter18pt-Bold", size: 12))
                                    .foregroundColor(.white)
                                    .frame(width: 24, height: 24)
                                    .background(
                                        Circle()
                                            .fill(Color("buttonColorTheme"))
                                    )
                                    .padding(.trailing, 15)
                                    .padding(.bottom, 60)
                            }
                        }
                        .allowsHitTesting(true) // Allow counter to receive touches
                    }
                    
                    // Date card overlay
                    if showDateCard {
                        dateCardView
                            .zIndex(1000) // Ensure it's on top
                            .padding(.top, 8)
                            .allowsHitTesting(false) // Don't block touches to ScrollView
                    }
                }
                
                // Bottom input area
                messageInputContainer
            }
            
            // Valuable card (centered, initially hidden)
            if showValuableCard {
                valuableCardView
            }
            
            // Menu dialogs
            if showMenu {
                menuDialog
            }
            
            if showMenu2 {
                menu2Dialog
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showCameraView) {
            GroupCameraGalleryView(group: group)
        }
        .fullScreenCover(isPresented: $showWhatsAppImagePicker, onDismiss: {
            // Restore gallery picker when image picker is dismissed (matching CameraGalleryView behavior)
            if wasGalleryPickerOpenBeforeImagePicker {
                withAnimation {
                    showGalleryPicker = true
                }
                wasGalleryPickerOpenBeforeImagePicker = false
            }
        }) {
            WhatsAppLikeImagePicker(maxSelection: 30) { selectedAssets, caption in
                handleImagePickerResult(selectedAssets: selectedAssets, caption: caption)
            }
        }
        .fullScreenCover(isPresented: $showWhatsAppVideoPicker, onDismiss: {
            // Restore gallery picker when video picker is dismissed (matching CameraGalleryView behavior)
            if wasGalleryPickerOpenBeforeVideoPicker {
                withAnimation {
                    showGalleryPicker = true
                }
                wasGalleryPickerOpenBeforeVideoPicker = false
            }
        }) {
            GroupWhatsAppLikeVideoPicker(maxSelection: 5, group: group) { selectedAssets, caption in
                handleVideoPickerResult(selectedAssets: selectedAssets, caption: caption)
            }
        }
        .fullScreenCover(isPresented: $showMultiImagePreview, onDismiss: {
            // Reset caption when dialog is dismissed
            multiImagePreviewCaption = ""
        }) {
            MultiImagePreviewDialog(
                selectedAssetIds: $selectedAssetIds,
                photoAssets: multiImagePreviewAssets.isEmpty ? photoAssets : multiImagePreviewAssets,
                imageManager: imageManager,
                caption: $multiImagePreviewCaption,
                onSend: { caption in
                    handleMultiImageSend(caption: caption)
                },
                onDismiss: {
                    showMultiImagePreview = false
                }
            )
        }
        .fullScreenCover(isPresented: $showWhatsAppContactPicker, onDismiss: {
            // Restore gallery picker when contact picker is dismissed (matching CameraGalleryView behavior)
            if wasGalleryPickerOpenBeforeContactPicker {
                withAnimation {
                    showGalleryPicker = true
                }
                wasGalleryPickerOpenBeforeContactPicker = false
            }
        }) {
            WhatsAppLikeContactPicker(maxSelection: 50) { (contacts: [ContactPickerInfo], caption: String) in
                handleContactPickerResult(contacts: contacts, caption: caption)
            }
        }
        .fullScreenCover(isPresented: $showMultiVideoPreview, onDismiss: {
            // Reset caption when dialog is dismissed
            multiVideoPreviewCaption = ""
        }) {
            GroupMultiVideoPreviewDialog(
                selectedAssetIds: $selectedAssetIds,
                videoAssets: multiVideoPreviewAssets.isEmpty ? [] : multiVideoPreviewAssets,
                imageManager: imageManager,
                caption: $multiVideoPreviewCaption,
                group: group,
                onSend: { caption in
                    handleMultiVideoSend(caption: caption)
                },
                onDismiss: {
                    showMultiVideoPreview = false
                }
            )
        }
        .fullScreenCover(isPresented: $showMultiContactPreview, onDismiss: {
            // Reset caption when dialog is dismissed
            multiContactPreviewCaption = ""
        }) {
            GroupMultiContactPreviewDialog(
                selectedContacts: multiContactPreviewContacts,
                caption: $multiContactPreviewCaption,
                group: group,
                onSend: { caption in
                    handleMultiContactSend(caption: caption)
                },
                onDismiss: {
                    showMultiContactPreview = false
                }
            )
        }
        .sheet(isPresented: $showDocumentPicker, onDismiss: {
            // Handle documents when picker is dismissed
            // Use a small delay to ensure sheet is fully dismissed before showing preview
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if !selectedDocuments.isEmpty {
                    let documentsToShow = selectedDocuments // Copy before clearing
                    handleDocumentPickerResult(selectedDocuments: documentsToShow)
                    // Clear after handling to avoid re-processing
                    selectedDocuments.removeAll()
                }
            }
            // Restore gallery picker when document picker is dismissed (matching CameraGalleryView behavior)
            if wasGalleryPickerOpenBeforeDocumentPicker {
                withAnimation {
                    showGalleryPicker = true
                }
                wasGalleryPickerOpenBeforeDocumentPicker = false
            }
        }) {
            DocumentPicker(selectedDocuments: $selectedDocuments, allowsMultipleSelection: true)
        }
        .sheet(isPresented: $showUnifiedGalleryPicker, onDismiss: {
            print("GalleryPicker: Sheet dismissed, selectedDocuments count: \(selectedDocuments.count)")
            print("GalleryPicker: selectedDocuments: \(selectedDocuments.map { $0.lastPathComponent })")
            // Note: Documents are handled via onDocumentsSelected callback, so we don't need to process here
            // This onDismiss is just for cleanup
            // Clear selectedDocuments after a delay to avoid conflicts
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if !selectedDocuments.isEmpty {
                    print("GalleryPicker: Clearing selectedDocuments in onDismiss")
                    selectedDocuments.removeAll()
                }
            }
            // Restore gallery picker when unified gallery picker is dismissed (matching CameraGalleryView behavior)
            if wasGalleryPickerOpenBeforeDocumentPicker {
                withAnimation {
                    showGalleryPicker = true
                }
                wasGalleryPickerOpenBeforeDocumentPicker = false
            }
        }) {
            GalleryPicker(
                selectedDocuments: $selectedDocuments,
                onDocumentsSelected: { documents in
                    handleDocumentPickerResult(selectedDocuments: documents)
                }
            )
        }
        .fullScreenCover(isPresented: $showMultiDocumentPreview, onDismiss: {
            // Reset caption when dialog is dismissed
            multiDocumentPreviewCaption = ""
        }) {
            GroupMultiDocumentPreviewDialog(
                selectedDocuments: multiDocumentPreviewURLs,
                caption: $multiDocumentPreviewCaption,
                group: group,
                onSend: { caption in
                    handleMultiDocumentSend(caption: caption)
                },
                onDismiss: {
                    showMultiDocumentPreview = false
                }
            )
        }
        .overlay(
            CustomActionSheet(
                isPresented: $showFilePickerActionSheet,
                title: "",
                options: [
                    ActionSheetOption("Select from Gallery") {
                        // Open gallery picker (photos and videos)
                        print("DocumentUpload: Action sheet - Select from Gallery chosen")
                        showUnifiedGalleryPicker = true
                        showFilePickerActionSheet = false
                    },
                    ActionSheetOption("Select from File") {
                        // Open document picker
                        print("DocumentUpload: Action sheet - Select from File chosen")
                        showDocumentPicker = true
                        showFilePickerActionSheet = false
                    }
                ]
            )
        )
        .onChange(of: showCameraView) { isPresented in
            // When camera view is dismissed, restore gallery picker if it was open before
            if !isPresented && wasGalleryPickerOpenBeforeCamera {
                withAnimation {
                    showGalleryPicker = true
                }
                wasGalleryPickerOpenBeforeCamera = false
            }
        }
        .onAppear {
            // Load pending messages from SQLite first (matching Android loadPendingMessages on onResume)
            loadPendingGroupMessages()
            
            // Fetch messages on appear (matching Android onCreate)
            let senderRoom = getSenderRoom()
            fetchMessages(senderRoom: senderRoom) {
                print("✅ Group messages fetched successfully")
            }
        }
        .onDisappear {
            // Remove Firebase listeners when leaving screen
            removeFirebaseListeners()
        }
    }
    
    // MARK: - Header 1 (Main Header)
    private var header1: some View {
        VStack(spacing: 0) {
            // Header card matching Android header1Cardview
            HStack(spacing: 0) {
                // Back button
                Button(action: {
                    dismiss()
                }) {
                    ZStack {
                        Image("leftvector")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 18)
                            .foregroundColor(Color("TextColor"))
                    }
                }
                .buttonStyle(.plain)
                .padding(.leading, 10)
                .padding(.trailing, 8)
                
                // Search field (full width when active - matching Android binding.searchlyt.setVisibility(View.VISIBLE))
                if showSearch {
                    TextField("Search...", text: $searchText)
                        .font(.custom("Inter18pt-Medium", size: 16))
                        .foregroundColor(Color("TextColor"))
                        .textFieldStyle(PlainTextFieldStyle())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 10)
                } else {
                    // Group section (hidden when search is active)
                    HStack(spacing: 0) {
                        // Group icon with border
                        ZStack {
                            Circle()
                                .stroke(Color("blue"), lineWidth: 2)
                                .frame(width: 44, height: 44)
                            
                            CachedAsyncImage(url: URL(string: group.iconURL)) { image in
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
                        Text(group.name)
                            .font(.custom("Inter18pt-Medium", size: 16))
                            .foregroundColor(Color("TextColor"))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Multi-select header elements (initially hidden)
                    if showMultiSelectHeader {
                        HStack(spacing: 8) {
                            Text("\(selectedCount) selected")
                                .font(.custom("Inter18pt-Bold", size: 14))
                                .foregroundColor(Color("blue"))
                            
                            Image("forward_wrapped")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .padding(4)
                                .background(
                                    Circle()
                                        .fill(Color.clear)
                                )
                        }
                    }
                    
                    // Menu button (three dots) - hidden when search is active
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
                                .fill(Color(hex: Constant.themeColor))
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
    
    // MARK: - Header 2 (Multi-select Header)
    private var header2: some View {
        VStack(spacing: 0) {
            // Header card matching Android header2Cardview
            HStack(spacing: 0) {
                // Cross button
                Button(action: {
                    showMultiSelectHeader = false
                    selectedCount = 0
                }) {
                    ZStack {
                        Image("crossimg")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 18)
                            .foregroundColor(Color("TextColor"))
                    }
                }
                .buttonStyle(.plain)
                .padding(.leading, 20)
                .padding(.trailing, 5)
                
                // Selected counter text
                Text("Selected \(selectedCount)")
                    .font(.custom("Inter18pt-Medium", size: 16))
                    .foregroundColor(Color("TextColor"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 21)
                
                Spacer()
                
                // Forward all button
                HStack(spacing: 5) {
                    Image("forward_wrapped")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundColor(Color("TextColor"))
                    
                    Text("forward")
                        .font(.custom("Inter18pt-Regular", size: 10))
                        .foregroundColor(Color("TextColor"))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color("dxForward"))
                )
                .padding(.trailing, 20)
            }
            .frame(height: 50)
            .background(Color("edittextBg"))
        }
    }
    
    // MARK: - Message Input Container
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
                            .padding(.top, 2) // Only add top margin, horizontal is already in replyLayoutView
                    }
                    
                    // Main input layout (editLyt) - marginStart="2dp" marginEnd="2dp"
                    VStack(spacing: 0) {
                        HStack(alignment: .center, spacing: 0) {
                            // Attach button (gallary) - marginStart="5dp"
                            Button(action: {
                                handleGalleryButtonClick()
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
                                    .font(messageInputFont)
                                    .foregroundColor(Color("black_white_cross"))
                                    .lineLimit(4)
                                    .frame(maxWidth: 180, alignment: .leading)
                                    .padding(.leading, 0)
                                    .padding(.trailing, 20)
                                    .padding(.top, 5)
                                    .padding(.bottom, 5)
                                    .background(Color.clear)
                                    .focused($isMessageFieldFocused)
                                    .onChange(of: messageText) { newValue in
                                        characterCount = newValue.count
                                        showCharacterCount = characterCount > 0
                                    }
                            }
                            .contentShape(Rectangle())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Emoji button (emoji) - marginEnd="5dp"
                            Button(action: {
                                showEmojiLayout.toggle()
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
                        .padding(.horizontal, 7) // Inner padding matching reply layout inner margin="7dp"
                    }
                    .padding(.horizontal, 2) // Outer margin matching reply layout marginStart/End="2dp" for width alignment
                    .background(
                        // When reply layout is visible: bottom corners only (to connect with reply layout)
                        // When reply layout is hidden: all corners rounded (matching message_box_bg.xml)
                        Group {
                            if showReplyLayout {
                                // Bottom corners only (matching Android when replylyout is visible)
                                RoundedCorner(radius: 20, corners: [.bottomLeft, .bottomRight])
                                    .fill(Color("message_box_bg"))
                            } else {
                                // All corners rounded (matching message_box_bg.xml with 20dp radius)
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color("message_box_bg"))
                            }
                        }
                    )
                    .zIndex(1) // Ensure TextField area has higher z-index than gallery picker
                }
                .frame(maxWidth: .infinity) // layout_weight="1"
                .contentShape(Rectangle()) // Ensure clear hit testing boundary
                
                // Send button (sendGrpLyt) - layout_gravity="center_vertical|bottom"
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 0) {
                        Button(action: {
                            handleSendButtonClick()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: Constant.themeColor)) // theme color like Android
                                    .frame(width: 50, height: 50)
                                
                                // Show mic icon when text is empty and no images selected, send icon when text is present or images selected
                                if messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedAssetIds.isEmpty {
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
                            .scaleEffect(sendButtonScale)
                        }
                    }
                    
                    // Small counter badge (Android multiSelectSmallCounterText) - positioned relative to send button
                    if selectedAssetIds.count > 0 {
                        Text("\(selectedAssetIds.count)")
                            .font(.custom("Inter18pt-Bold", size: 12))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(Color(hex: Constant.themeColor)) // match Android counter tint
                            )
                            .offset(x: -13, y: -30) // lift badge above send button with extra right margin
                    }
                }
                .padding(.horizontal, 5)
            }
            .padding(2) // Inner horizontal container padding="2dp"
            .contentShape(Rectangle()) // Clear boundary for message input area to prevent gesture interference
            .background(Color("edittextBg")) // Ensure solid background to prevent visual overlap
            // Note: Removed .clipped() to allow badge to be visible above send button
            
            // Emoji picker layout (emojiLyt) - below horizontal container
            if showEmojiLayout {
                emojiLayoutView
            }
            
            // Gallery picker layout (galleryRecentLyt) - below horizontal container
            if showGalleryPicker {
                galleryPickerView
                    .onAppear {
                        requestPhotosAndLoad()
                    }
                    .zIndex(0) // Lower z-index than TextField area
            }
        }
        // Note: Removed .clipped() from outer VStack to allow badge to be visible above send button
    }
    
    // MARK: - Reply Layout
    private var replyLayoutView: some View {
        // Get color based on sender/receiver (matching Android HalfSwipeCallback logic)
        let replyColor: Color = isReplyFromSender ? Color(hex: Constant.themeColor) : Color("black_white_cross")
        
        return ZStack(alignment: .topLeading) {
            // Layer 1: Blue background layer (matching Android LinearLayout id="view")
            // marginHorizontal="6dp" marginVertical="7dp" backgroundTint="@color/blue"
            // This layer is larger (6dp margins) and creates the blue border effect
            RoundedCorner(radius: 20, corners: [.topLeft, .topRight])
                .fill(replyColor.opacity(0.2)) // Blue tint for sender, black_white_cross tint for receiver
                .frame(height: 55) // height="55dp"
                .padding(.horizontal, 6) // marginHorizontal="6dp" - creates larger blue layer
                .padding(.vertical, 7) // marginVertical="7dp"
            
            // Layer 2: White foreground layer (matching Android second LinearLayout)
            // margin="7dp" backgroundTint="@color/circlebtnhover"
            // This layer is smaller (7dp margins) and sits on top of the blue layer
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    // Left side content - layout_weight="1"
                    HStack(spacing: 0) {
                        // Text content - marginStart="10dp"
                        VStack(alignment: .leading, spacing: 4) {
                            Text(replySenderName)
                                .font(.custom("Inter18pt-Bold", size: 14)) // textFontWeight="1000" textSize="14sp"
                                .foregroundColor(replyColor) // Theme color for sender, black_white_cross for receiver
                            
                            // Reply message with icon for certain data types (matching Android compoundDrawables)
                            HStack(spacing: 5) {
                                // Icon for specific data types (matching Android drawable icons)
                                if replyDataType == Constant.img {
                                    Image(systemName: "photo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 16, height: 16)
                                        .foregroundColor(Color(red: 0x78/255.0, green: 0x78/255.0, blue: 0x7A/255.0))
                                } else if replyDataType == Constant.video {
                                    Image(systemName: "video.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 16, height: 16)
                                        .foregroundColor(Color(red: 0x78/255.0, green: 0x78/255.0, blue: 0x7A/255.0))
                                } else if replyDataType == Constant.voiceAudio {
                                    Image(systemName: "mic.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 16, height: 16)
                                        .foregroundColor(Color(red: 0x78/255.0, green: 0x78/255.0, blue: 0x7A/255.0))
                                } else if replyDataType == Constant.contact {
                                    Image(systemName: "person.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 16, height: 16)
                                        .foregroundColor(Color(red: 0x78/255.0, green: 0x78/255.0, blue: 0x7A/255.0))
                                }
                                
                                Text(replyMessage)
                                    .font(.custom("Inter18pt-Regular", size: 14)) // textSize="14sp"
                                    .foregroundColor(Color(red: 0x78/255.0, green: 0x78/255.0, blue: 0x7A/255.0)) // textColor="#78787A"
                                    .lineLimit(1) // maxLines="1" singleLine="true"
                            }
                        }
                        .padding(.leading, 10) // marginStart="10dp"
                    }
                    .frame(maxWidth: .infinity, alignment: .leading) // layout_weight="1"
                    
                    // Right side - cancel button
                    Button(action: {
                        showReplyLayout = false
                    }) {
                        Image("crosssvg")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 25)
                            .foregroundColor(replyColor)
                    }
                    .padding(.trailing, 15)
                }
                .frame(height: 55)
            }
            .background(
                RoundedCorner(radius: 20, corners: [.topLeft, .topRight])
                    .fill(Color("message_box_bg_3"))
            )
            .padding(.horizontal, 7) // margin="7dp" - creates smaller white layer on top
            .padding(.vertical, 7) // margin="7dp"
        }
        .padding(.horizontal, 2) // marginStart="2dp" marginEnd="2dp"
        .padding(.top, 2) // marginTop="2dp"
        .background(
            // Outer background (matching Android replylyout background)
            RoundedCorner(radius: 20, corners: [.topLeft, .topRight])
                .fill(Color("message_box_bg_3"))
        )
    }
    
    // MARK: - Emoji Layout
    private var emojiLayoutView: some View {
        VStack(spacing: 0) {
            // Emoji search container (top)
            HStack(spacing: 8) {
                Button(action: {
                    showEmojiLayout = false
                }) {
                    Image("leftvector")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 25, height: 18)
                        .foregroundColor(Color("icontintGlobal"))
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color.clear)
                        )
                }
                
                TextField("Search emojis...", text: .constant(""))
                    .font(.custom("Inter18pt-Regular", size: 14))
                    .foregroundColor(Color("black_white_cross"))
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(height: 40)
                    .padding(.horizontal, 12)
            }
            .padding(.horizontal, 8)
            .frame(height: 50)
            
            // Emoji recycler view (placeholder)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 10) {
                    ForEach(0..<50) { _ in
                        Text("😀")
                            .font(.system(size: 30))
                    }
                }
                .padding()
            }
            .frame(height: 250)
        }
        .background(Color("edittextBg"))
    }
    
    // MARK: - Gallery Picker View
    private var galleryPickerView: some View {
        VStack(spacing: 0) {
            // Gallery card view - height="300dp"
            VStack(spacing: 0) {
                // Gallery RecyclerView - wrapped in container to prevent gesture interference
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 2) {
                        ForEach(photoAssets, id: \.localIdentifier) { asset in
                            GalleryAssetThumbnail(
                                asset: asset,
                                imageManager: imageManager,
                                isSelected: selectedAssetIds.contains(asset.localIdentifier)
                            )
                            .padding(.top, 10) // top margin for each item
                            .overlay(alignment: .topTrailing) {
                                if selectedAssetIds.contains(asset.localIdentifier) {
                                    Image("multitick")
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                        .padding(10)
                                }
                            }
                            .onTapGesture {
                                toggleSelection(for: asset)
                            }
                        }
                    }
                    // Match Android dataRecview container insets with equal spacing on all sides
                    .padding(.top, 10)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
                }
                .frame(height: 250, alignment: .top) // Strict frame alignment
                .clipped()
                .contentShape(Rectangle())
                .compositingGroup() // Create a compositing group to prevent visual overflow
                
                // Bottom view with action buttons
                HStack(spacing: 0) {
                    // Camera button
                    Button(action: {
                        handleCameraButtonClick()
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
                        .padding(5) // outer inset like Android parent padding
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color("circlebtnhover")) // gallary_bgcontent.xml
                        )
                        .padding(5) // inner container spacing to mirror Android padding="5dp"
                    }
                    
                    // Photo button
                    Button(action: {
                        handlePhotoButtonClick()
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
                        .padding(5)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color("circlebtnhover"))
                        )
                        .padding(5)
                    }
                    
                    // Video button
                    Button(action: {
                        handleVideoButtonClick()
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
                        .padding(5)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color("circlebtnhover"))
                        )
                        .padding(5)
                    }
                    
                    // File button
                    Button(action: {
                        handleFileButtonClick()
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
                        .padding(5)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color("circlebtnhover"))
                        )
                        .padding(5)
                    }
                    
                    // Contact button
                    Button(action: {
                        handleContactButtonClick()
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
                        .padding(5)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color("circlebtnhover"))
                        )
                        .padding(5)
                    }
                }
                .padding(.horizontal, 7)
                .padding(.bottom, 10)
            }
            .frame(height: 300)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color("chattingMessageBox"))
            )
            .padding(2)
            .clipped() // Ensure the entire container is clipped
        }
        .contentShape(Rectangle())
        .allowsHitTesting(true)
        .clipped() // Additional clipping at the outer level to prevent overflow
    }
    
    // MARK: - Valuable Card
    private var valuableCardView: some View {
        VStack(spacing: 0) {
            Text("Your Message Will Become More Valuable Here")
                .font(.custom("Inter18pt-Regular", size: 12))
                .foregroundColor(Color("TextColor"))
                .multilineTextAlignment(.center)
                .padding(7)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color("cardBackgroundColornew"))
        )
        .padding(.top, 10)
    }
    
    // MARK: - Date Card
    private var dateCardView: some View {
        VStack(spacing: 0) {
            Text(dateText)
                .font(.custom("Inter18pt-Regular", size: 10))
                .foregroundColor(Color("TextColor"))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color("cardBackgroundColornew"))
        )
        .padding(.top, 56)
    }
    
    // MARK: - Menu Dialog
    private var menuDialog: some View {
        VStack(alignment: .leading, spacing: 5) {
            Button(action: {
                // Group Info action
                showMenu = false
            }) {
                Text("Group Info")
                    .font(.custom("Inter18pt-Medium", size: 16))
                    .foregroundColor(Color("TextColor"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, 32)
            .padding(.top, 10)
            
            Button(action: {
                // Add Member action
                showMenu = false
            }) {
                Text("Add Member")
                    .font(.custom("Inter18pt-Medium", size: 16))
                    .foregroundColor(Color("TextColor"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, 32)
            .padding(.top, 5)
            
            Button(action: {
                // Remove Member action
                showMenu = false
            }) {
                Text("Remove Member")
                    .font(.custom("Inter18pt-Medium", size: 16))
                    .foregroundColor(Color("TextColor"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, 32)
            .padding(.top, 5)
            
            Button(action: {
                // Delete Group action
                showMenu = false
            }) {
                Text("Delete Group")
                    .font(.custom("Inter18pt-Medium", size: 16))
                    .foregroundColor(Color("TextColor"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, 32)
            .padding(.top, 5)
        }
        .frame(width: 267, height: 138)
        .background(
            Image("menurect")
                .resizable()
        )
        .padding(.leading, 126)
        .padding(.top, 50)
        .padding(.trailing, 30)
        .onTapGesture {
            showMenu = false
        }
    }
    
    // MARK: - Menu 2 Dialog
    private var menu2Dialog: some View {
        VStack {
            Button(action: {
                showSearch.toggle()
                showMenu2 = false
            }) {
                Text("Search")
                    .font(.custom("Inter18pt-Medium", size: 17))
                    .foregroundColor(Color("TextColor"))
            }
        }
        .frame(width: 140, height: 45)
        .background(
            Image("menurect")
                .resizable()
        )
        .padding(.trailing, 5)
        .padding(.top, 60)
        .onTapGesture {
            showMenu2 = false
        }
    }
    
    // MARK: - Typography
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
    
    // MARK: - Handle Gallery Button Click (matching Android gallery button behavior)
    private func handleGalleryButtonClick() {
        print("🟢 [GALLERY_BUTTON] Gallery button clicked")
        print("🟢 [GALLERY_BUTTON] isMessageFieldFocused: \(isMessageFieldFocused)")
        print("🟢 [GALLERY_BUTTON] showGalleryPicker: \(showGalleryPicker)")
        
        // If keyboard is open (message field is focused), hide it first
        if isMessageFieldFocused {
            print("🟢 [GALLERY_BUTTON] Keyboard is open - hiding it first")
            isMessageFieldFocused = false
            // Hide keyboard and then show gallery picker after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                print("🟢 [GALLERY_BUTTON] Showing gallery picker after keyboard hide")
                withAnimation {
                    self.showGalleryPicker = true
                    self.showEmojiLayout = false
                }
            }
        } else {
            // If keyboard is not open, just toggle gallery picker
            print("🟢 [GALLERY_BUTTON] Keyboard not open - toggling gallery picker")
            withAnimation {
                showGalleryPicker.toggle()
                showEmojiLayout = false
            }
        }
    }
    
    // MARK: - Request Photos and Load
    private func requestPhotosAndLoad() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            loadRecentPhotos()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    loadRecentPhotos()
                }
            }
        default:
            // Permissions denied; keep grid empty
            break
        }
    }
    
    private func loadRecentPhotos(limit: Int = 120) {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = limit
        options.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared, .typeiTunesSynced]
        let fetched = PHAsset.fetchAssets(with: .image, options: options)
        
        var assets: [PHAsset] = []
        fetched.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        DispatchQueue.main.async {
            self.photoAssets = assets
        }
    }
    
    private func toggleSelection(for asset: PHAsset) {
        let id = asset.localIdentifier
        if selectedAssetIds.contains(id) {
            selectedAssetIds.remove(id)
        } else {
            // Match Android multi-select limit (30)
            guard selectedAssetIds.count < 30 else { return }
            selectedAssetIds.insert(id)
        }
        // Update selectedCount to match selectedAssetIds.count (matching Android binding.multiSelectSmallCounterText)
        selectedCount = selectedAssetIds.count
    }
    
    // MARK: - Camera Button Handler
    private func handleCameraButtonClick() {
        // Light haptic feedback (Android-style tap vibration)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Hide keyboard and focus message box
        isMessageFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        // Save gallery picker state before opening camera
        wasGalleryPickerOpenBeforeCamera = showGalleryPicker
        
        // Hide emoji picker if open
        if showEmojiLayout {
            withAnimation {
                showEmojiLayout = false
            }
        }
        
        // Hide gallery picker if open (will restore when camera closes)
        if showGalleryPicker {
            withAnimation {
                showGalleryPicker = false
            }
        }
        
        // Clear selected assets (hides multi-select counter)
        selectedAssetIds.removeAll()
        
        // Send button will automatically show mic icon when messageText is empty
        // and selectedAssetIds is empty (already handled in UI)
        
        // Request camera permission and show camera view
        requestCameraPermission { granted in
            if granted {
                DispatchQueue.main.async {
                    showCameraView = true
                }
            }
        }
    }
    
    // MARK: - Camera Permission
    private func requestCameraPermission(completion: @escaping (Bool) -> Void = { _ in }) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                if granted {
                    print("Camera permission granted")
                    completion(true)
                } else {
                    print("Camera permission denied")
                    completion(false)
                    // TODO: Show permission denied alert
                }
            }
        }
    }
    
    // MARK: - Photo Button Handler
    private func handlePhotoButtonClick() {
        print("ImageUpload: === GALLERY BUTTON CLICKED (Main) ===")
        
        // Light haptic feedback (Android-style tap vibration)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Hide keyboard and focus message box (matching Android hideKeyboardAndFocusMessageBox)
        isMessageFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        // Hide multi-select counter (matching Android binding.multiSelectSmallCounterText.setVisibility(View.GONE))
        selectedAssetIds.removeAll()
        selectedCount = 0
        
        // Save gallery picker state before opening image picker (don't hide it - will restore on back)
        wasGalleryPickerOpenBeforeImagePicker = showGalleryPicker
        
        // Hide emoji picker if open
        if showEmojiLayout {
            withAnimation {
                showEmojiLayout = false
            }
        }
        
        // Hide gallery picker if open (will restore when image picker closes)
        if showGalleryPicker {
            withAnimation {
                showGalleryPicker = false
            }
        }
        
        // Launch WhatsApp-like image picker (matching Android WhatsAppLikeImagePicker)
        print("ImageUpload: === LAUNCHING WhatsAppLikeImagePicker ===")
        print("ImageUpload: PICK_IMAGE_REQUEST_CODE: PhotoPicker")
        print("ImageUpload: Current selectedAssetIds size: \(selectedAssetIds.count)")
        
        DispatchQueue.main.async {
            showWhatsAppImagePicker = true
        }
    }
    
    // MARK: - Handle Image Picker Result
    private func handleImagePickerResult(selectedAssets: [PHAsset], caption: String) {
        print("ImageUpload: === IMAGE PICKER RESULT RECEIVED ===")
        print("ImageUpload: Selected assets count: \(selectedAssets.count)")
        print("ImageUpload: Caption: '\(caption)'")
        
        guard !selectedAssets.isEmpty else { return }
        
        // Store selected assets for preview dialog
        multiImagePreviewAssets = selectedAssets
        
        // Update selected assets
        selectedAssetIds = Set(selectedAssets.map { $0.localIdentifier })
        selectedCount = selectedAssets.count
        
        // Set caption from WhatsAppLikeImagePicker
        multiImagePreviewCaption = caption
        
        // Show full-screen dialog for multi-image preview (matching Android setupMultiImagePreviewWithData)
        showMultiImagePreview = true
    }
    
    // MARK: - Handle Multi-Image Send (matching Android upload logic)
    private func handleMultiImageSend(caption: String) {
        print("DIALOGUE_DEBUG: === MULTI-IMAGE SEND ===")
        print("DIALOGUE_DEBUG: Selected images count: \(selectedAssetIds.count)")
        print("DIALOGUE_DEBUG: Caption: '\(caption)'")
        
        // Get selected assets from multiImagePreviewAssets or photoAssets
        let selectedAssets = multiImagePreviewAssets.isEmpty 
            ? photoAssets.filter { selectedAssetIds.contains($0.localIdentifier) }
            : multiImagePreviewAssets.filter { selectedAssetIds.contains($0.localIdentifier) }
        
        guard !selectedAssets.isEmpty else {
            print("DIALOGUE_DEBUG: No assets selected, returning")
            return
        }
        
        // Close the preview dialog
        showMultiImagePreview = false
        
        // Hide gallery picker
        withAnimation {
            showGalleryPicker = false
        }
        
        // Clear selected assets after sending
        selectedAssetIds.removeAll()
        selectedCount = 0
        
        let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let groupId = group.groupId
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
        let modelId = UUID().uuidString
        
        // Capture reply context if present
        let replyMsg = replyMessage
        let replyType = replyDataType
        
        // Create placeholder selectionBunch items so bunch view can render immediately
        var placeholderSelectionBunch: [SelectionBunchModel] = []
        for index in 0..<selectedAssets.count {
            let fileName = "\(modelId)_\(index).jpg"
            placeholderSelectionBunch.append(SelectionBunchModel(imgUrl: "", fileName: fileName))
        }
        
        // Create message with group information using GroupChatMessage
        let createdBy = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        let newMessage = GroupChatMessage(
            id: modelId,
            uid: senderId,
            message: "",
            time: currentDateTimeString,
            document: "", // Will be updated after upload
            dataType: Constant.img,
            fileExtension: "jpg",
            name: nil,
            phone: nil,
            miceTiming: nil,
            micPhoto: micPhoto,
            createdBy: createdBy,
            userName: userName,
            receiverUid: groupId, // Use groupId as receiverUid for groups
            docSize: nil,
            fileName: "\(modelId)_0.jpg",
            thumbnail: nil,
            fileNameThumbnail: nil,
            caption: trimmedCaption,
            currentDate: currentDateString,
            imageWidth: nil, // Will be updated after export
            imageHeight: nil, // Will be updated after export
            aspectRatio: nil, // Will be updated after export
            active: 0, // 0 = sending, 1 = sent
            selectionCount: "\(selectedAssets.count)",
            selectionBunch: placeholderSelectionBunch.count >= 2 ? placeholderSelectionBunch : nil // Show bunch view if 2+ images
        )
        
        // Upload images to Firebase Storage and send message
        uploadGroupImagesAndSend(selectedAssets: selectedAssets, message: newMessage, modelId: modelId)
    }
    
    // MARK: - Upload Group Images and Send
    private func uploadGroupImagesAndSend(selectedAssets: [PHAsset], message: GroupChatMessage, modelId: String) {
        let dispatchGroup = DispatchGroup()
        let lockQueue = DispatchQueue(label: "com.enclosure.groupMultiImageUpload.lock")
        
        struct UploadedImageResult {
            let index: Int
            let downloadURL: String
            let fileName: String
            let width: Int
            let height: Int
        }
        
        var uploadResults: [UploadedImageResult] = []
        var uploadErrors: [Error] = []
        
        // Upload all images
        for (index, asset) in selectedAssets.enumerated() {
            dispatchGroup.enter()
            let remoteFileName = "\(modelId)_\(index).jpg"
            
            exportImageAsset(asset, fileName: remoteFileName) { exportResult in
                switch exportResult {
                case .failure(let error):
                    lockQueue.sync { uploadErrors.append(error) }
                    dispatchGroup.leave()
                case .success(let export):
                    // Upload to Firebase Storage using GROUPCHAT path
                    self.uploadGroupImageFileToFirebase(data: export.data, remoteFileName: remoteFileName) { uploadResult in
                        switch uploadResult {
                        case .failure(let error):
                            lockQueue.sync { uploadErrors.append(error) }
                        case .success(let downloadURL):
                            let result = UploadedImageResult(
                                index: index,
                                downloadURL: downloadURL,
                                fileName: remoteFileName,
                                width: export.width,
                                height: export.height
                            )
                            lockQueue.sync { uploadResults.append(result) }
                        }
                        dispatchGroup.leave()
                    }
                }
            }
        }
        
        // After all uploads complete, update message and send to API
        dispatchGroup.notify(queue: .main) {
            if uploadResults.isEmpty {
                print("❌ [GROUP_MULTI_IMAGE] Upload failed - no results")
                Constant.showToast(message: "Unable to upload images. Please try again.")
                return
            }
            
            if !uploadErrors.isEmpty {
                print("⚠️ [GROUP_MULTI_IMAGE] Some uploads failed: \(uploadErrors.count) errors")
            }
            
            let sortedResults = uploadResults.sorted { $0.index < $1.index }
            let selectionBunchModels = sortedResults.map { SelectionBunchModel(imgUrl: $0.downloadURL, fileName: $0.fileName) }
            
            guard let first = sortedResults.first else {
                Constant.showToast(message: "Unable to prepare images. Please try again.")
                return
            }
            
            let aspectRatioValue: String
            if first.height > 0 {
                aspectRatioValue = String(format: "%.2f", Double(first.width) / Double(first.height))
            } else {
                aspectRatioValue = ""
            }
            
            // Update message with actual URLs
            var updatedMessage = message
            updatedMessage.document = first.downloadURL
            updatedMessage.imageWidth = "\(first.width)"
            updatedMessage.imageHeight = "\(first.height)"
            updatedMessage.aspectRatio = aspectRatioValue
            updatedMessage.selectionBunch = selectionBunchModels.count >= 2 ? selectionBunchModels : nil
            
            // Convert GroupChatMessage to ChatMessage for database storage
            let chatMessageForDB = ChatMessage(
                id: updatedMessage.id,
                uid: updatedMessage.uid,
                message: updatedMessage.message,
                time: updatedMessage.time,
                document: updatedMessage.document,
                dataType: updatedMessage.dataType,
                fileExtension: updatedMessage.fileExtension,
                name: updatedMessage.name,
                phone: updatedMessage.phone,
                micPhoto: updatedMessage.micPhoto,
                miceTiming: updatedMessage.miceTiming,
                userName: updatedMessage.userName,
                receiverId: updatedMessage.receiverUid, // Use receiverUid as receiverId
                replytextData: nil,
                replyKey: nil,
                replyType: nil,
                replyOldData: nil,
                replyCrtPostion: nil,
                forwaredKey: nil,
                groupName: group.name, // Set group name
                docSize: updatedMessage.docSize,
                fileName: updatedMessage.fileName,
                thumbnail: updatedMessage.thumbnail,
                fileNameThumbnail: updatedMessage.fileNameThumbnail,
                caption: updatedMessage.caption,
                notification: 1,
                currentDate: updatedMessage.currentDate,
                emojiModel: [EmojiModel(name: "", emoji: "")],
                emojiCount: nil,
                timestamp: Date().timeIntervalSince1970,
                imageWidth: updatedMessage.imageWidth,
                imageHeight: updatedMessage.imageHeight,
                aspectRatio: updatedMessage.aspectRatio,
                selectionCount: updatedMessage.selectionCount,
                selectionBunch: updatedMessage.selectionBunch,
                receiverLoader: 0
            )
            
            // Store message in SQLite pending table before upload (matching Android insertPendingGroupMessage)
            DatabaseHelper.shared.insertPendingMessage(chatMessageForDB)
            print("✅ [PendingMessages] Group image message stored in pending table: \(modelId)")
            
            // Upload message via GROUP API (not individual chat API)
            let userFTokenKey = UserDefaults.standard.string(forKey: Constant.FCM_TOKEN) ?? ""
            
            MessageUploadService.shared.uploadGroupMessage(
                model: updatedMessage,
                filePath: nil,
                userFTokenKey: userFTokenKey,
                deviceType: "2"
            ) { success, errorMessage in
                if success {
                    print("✅ [GROUP_MULTI_IMAGE] Uploaded \(sortedResults.count) images for modelId=\(modelId) using GROUP API")
                } else {
                    print("❌ [GROUP_MULTI_IMAGE] Upload error: \(errorMessage ?? "Unknown error")")
                    Constant.showToast(message: "Failed to send images. Please try again.")
                }
            }
        }
    }
    
    // MARK: - Export Image Asset
    private func exportImageAsset(_ asset: PHAsset, fileName: String, completion: @escaping (Result<(data: Data, width: Int, height: Int), Error>) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.version = .current
        
        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
            guard let data = data else {
                completion(.failure(NSError(domain: "ImageExport", code: -1, userInfo: [NSLocalizedDescriptionKey: "No image data"])))
                return
            }
            
            let image = UIImage(data: data)
            let jpegData = image?.jpegData(compressionQuality: 0.85) ?? data
            let width = image?.cgImage?.width ?? Int(asset.pixelWidth)
            let height = image?.cgImage?.height ?? Int(asset.pixelHeight)
            completion(.success((jpegData, width, height)))
        }
    }
    
    // MARK: - Upload Group Image to Firebase Storage
    private func uploadGroupImageFileToFirebase(data: Data, remoteFileName: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Use GROUPCHAT constant and group.groupId for storage path
        let storagePath = "\(Constant.GROUPCHAT)/\(group.groupId)/\(remoteFileName)"
        let ref = Storage.storage().reference().child(storagePath)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        DispatchQueue.main.async {
            bgTask = UIApplication.shared.beginBackgroundTask(withName: "UploadGroupImage") {
                UIApplication.shared.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
        }
        let endTask: () -> Void = {
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
        }
        
        ref.putData(data, metadata: metadata) { _, error in
            if let error = error {
                endTask()
                completion(.failure(error))
                return
            }
            
            ref.downloadURL { url, error in
                endTask()
                
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let url = url else {
                    completion(.failure(NSError(domain: "FirebaseStorage", code: -1, userInfo: [NSLocalizedDescriptionKey: "Download URL missing"])))
                    return
                }
                
                completion(.success(url.absoluteString))
            }
        }
    }
    
    // MARK: - Video Button Handler
    private func handleVideoButtonClick() {
        print("VideoUpload: === VIDEO BUTTON CLICKED (Main) ===")
        
        // Light haptic feedback (Android-style tap vibration)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Hide keyboard and focus message box (matching Android hideKeyboardAndFocusMessageBox)
        isMessageFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        // Hide multi-select counter (matching Android binding.multiSelectSmallCounterText.setVisibility(View.GONE))
        selectedAssetIds.removeAll()
        selectedCount = 0
        
        // Save gallery picker state before opening video picker (don't hide it - will restore on back)
        wasGalleryPickerOpenBeforeVideoPicker = showGalleryPicker
        
        // Hide emoji picker if open
        if showEmojiLayout {
            withAnimation {
                showEmojiLayout = false
            }
        }
        
        // Hide gallery picker if open (will restore when video picker closes)
        if showGalleryPicker {
            withAnimation {
                showGalleryPicker = false
            }
        }
        
        // Launch WhatsApp-like video picker (matching Android WhatsAppLikeVideoPicker)
        print("VideoUpload: === LAUNCHING GroupWhatsAppLikeVideoPicker ===")
        print("VideoUpload: PICK_VIDEO_REQUEST_CODE: VideoPicker")
        print("VideoUpload: Current selectedAssetIds size: \(selectedAssetIds.count)")
        
        DispatchQueue.main.async {
            showWhatsAppVideoPicker = true
        }
    }
    
    // MARK: - Handle Video Picker Result
    private func handleVideoPickerResult(selectedAssets: [PHAsset], caption: String) {
        print("VideoUpload: === VIDEO PICKER RESULT RECEIVED ===")
        print("VideoUpload: Selected assets count: \(selectedAssets.count)")
        print("VideoUpload: Caption: '\(caption)'")
        
        // Videos are uploaded directly from GroupMultiVideoPreviewDialog (matching Android flow)
        // This callback is called after videos are sent, so we just need to clear selections
        selectedAssetIds.removeAll()
        selectedCount = 0
        
        // Store selected assets for preview dialog (if needed for future use)
        multiVideoPreviewAssets = selectedAssets
        multiVideoPreviewCaption = caption
    }
    
    // MARK: - Handle Multi-Video Send (matching Android upload logic)
    private func handleMultiVideoSend(caption: String) {
        print("DIALOGUE_DEBUG: === MULTI-VIDEO SEND ===")
        print("DIALOGUE_DEBUG: Selected videos count: \(selectedAssetIds.count)")
        print("DIALOGUE_DEBUG: Caption: '\(caption)'")
        
        // Videos are uploaded directly from GroupMultiVideoPreviewDialog
        // This function is called after videos are sent, so we just need to clear selections
        selectedAssetIds.removeAll()
        selectedCount = 0
        
        // Hide gallery picker
        withAnimation {
            showGalleryPicker = false
        }
    }
    
    // MARK: - File Button Handler
    private func handleFileButtonClick() {
        // Light haptic feedback (Android-style tap vibration)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Hide keyboard and focus message box (matching Android hideKeyboardAndFocusMessageBox)
        isMessageFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        // Hide multi-select counter (matching Android binding.multiSelectSmallCounterText.setVisibility(View.GONE))
        selectedAssetIds.removeAll()
        selectedCount = 0
        
        // Save gallery picker state before opening file picker (don't hide it - will restore on back)
        wasGalleryPickerOpenBeforeDocumentPicker = showGalleryPicker
        
        // Hide emoji picker if open
        if showEmojiLayout {
            withAnimation {
                showEmojiLayout = false
            }
        }
        
        // Clear selected documents
        selectedDocuments.removeAll()
        
        // Show action sheet to choose between Gallery and File (matching Telegram behavior)
        print("DocumentUpload: === SHOWING FILE PICKER ACTION SHEET ===")
        
        DispatchQueue.main.async {
            showFilePickerActionSheet = true
        }
    }
    
    // MARK: - Handle Document Picker Result
    private func handleDocumentPickerResult(selectedDocuments: [URL]) {
        print("DocumentUpload: === DOCUMENT PICKER RESULT RECEIVED ===")
        print("DocumentUpload: Selected documents count: \(selectedDocuments.count)")
        
        guard !selectedDocuments.isEmpty else {
            print("DocumentUpload: No documents selected, returning")
            return
        }
        
        // Prevent double processing if already showing preview
        guard !showMultiDocumentPreview else {
            print("DocumentUpload: Preview already showing, skipping duplicate call")
            return
        }
        
        print("DocumentUpload: Storing documents for preview: \(selectedDocuments.map { $0.lastPathComponent })")
        
        // CRITICAL: Set URLs and show dialog in separate updates to ensure state is processed
        // First, set the URLs synchronously
        multiDocumentPreviewURLs = selectedDocuments
        multiDocumentPreviewCaption = ""
        
        print("DocumentUpload: Stored URLs count: \(multiDocumentPreviewURLs.count)")
        print("DocumentUpload: URLs: \(multiDocumentPreviewURLs.map { $0.lastPathComponent })")
        
        // Use a longer delay to ensure SwiftUI has fully processed the state update
        // SwiftUI batches state updates, so we need to wait for the first update to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            print("DocumentUpload: Showing preview dialog, URLs count: \(self.multiDocumentPreviewURLs.count)")
            print("DocumentUpload: URLs before showing: \(self.multiDocumentPreviewURLs.map { $0.lastPathComponent })")
            
            // Verify URLs are still set before showing
            guard !self.multiDocumentPreviewURLs.isEmpty else {
                print("DocumentUpload: ERROR - URLs are empty when trying to show dialog!")
                return
            }
            
            // Show full-screen dialog for multi-document preview (matching Android)
            // At this point, multiDocumentPreviewURLs should be set and SwiftUI should have processed it
            self.showMultiDocumentPreview = true
            print("DocumentUpload: showMultiDocumentPreview set to: \(self.showMultiDocumentPreview)")
        }
    }
    
    // MARK: - Handle Multi-Document Send (matching Android upload logic)
    private func handleMultiDocumentSend(caption: String) {
        print("DocumentUpload: === MULTI-DOCUMENT SEND ===")
        print("DocumentUpload: Selected documents count: \(multiDocumentPreviewURLs.count)")
        print("DocumentUpload: Caption: '\(caption)'")
        
        // Documents are uploaded directly from GroupMultiDocumentPreviewDialog (matching Android flow)
        // This callback is called after documents are sent, so we just need to clear selections
        multiDocumentPreviewURLs.removeAll()
        multiDocumentPreviewCaption = ""
        
        // Hide gallery picker
        withAnimation {
            showGalleryPicker = false
        }
    }
    
    // MARK: - Contact Button Handler
    private func handleContactButtonClick() {
        print("ContactUpload: === CONTACT BUTTON CLICKED (Main) ===")
        
        // Light haptic feedback (Android-style tap vibration)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Hide keyboard and focus message box (matching Android hideKeyboardAndFocusMessageBox)
        isMessageFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        // Hide multi-select counter (matching Android binding.multiSelectSmallCounterText.setVisibility(View.GONE))
        selectedAssetIds.removeAll()
        selectedCount = 0
        
        // Save gallery picker state before opening contact picker (don't hide it - will restore on back)
        wasGalleryPickerOpenBeforeContactPicker = showGalleryPicker
        
        // Hide emoji picker if open
        if showEmojiLayout {
            withAnimation {
                showEmojiLayout = false
            }
        }
        
        // Hide gallery picker if open (will restore when contact picker closes)
        if showGalleryPicker {
            withAnimation {
                showGalleryPicker = false
            }
        }
        
        // Launch WhatsApp-like contact picker (matching Android WhatsAppLikeContactPicker)
        print("ContactUpload: === LAUNCHING WhatsAppLikeContactPicker ===")
        print("ContactUpload: PICK_CONTACT_REQUEST_CODE: ContactPicker")
        
        DispatchQueue.main.async {
            showWhatsAppContactPicker = true
        }
    }
    
    // MARK: - Handle Contact Picker Result
    private func handleContactPickerResult(contacts: [ContactPickerInfo], caption: String) {
        print("ContactUpload: === CONTACT PICKER CALLBACK RECEIVED ===")
        print("ContactUpload: Selected contacts count: \(contacts.count)")
        print("ContactUpload: Contacts: \(contacts.map { $0.name })")
        
        // Guard: Don't proceed if no contacts selected
        guard !contacts.isEmpty else {
            print("ContactUpload: No contacts selected, skipping preview")
            return
        }
        
        // Store contacts and caption for preview dialog on main thread
        DispatchQueue.main.async {
            print("ContactUpload: Setting contacts on main thread, count: \(contacts.count)")
            self.multiContactPreviewContacts = contacts
            self.multiContactPreviewCaption = caption
            
            // Verify state was set correctly
            print("ContactUpload: State after setting - contacts count: \(self.multiContactPreviewContacts.count)")
            
            // Show preview dialog after a delay to ensure picker is dismissed and state is committed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("ContactUpload: After delay - contacts count: \(self.multiContactPreviewContacts.count)")
                print("ContactUpload: Contacts: \(self.multiContactPreviewContacts.map { $0.name })")
                
                // Double-check contacts are available before showing
                guard !self.multiContactPreviewContacts.isEmpty else {
                    print("ContactUpload: ERROR - Contacts array is empty after delay, not showing preview")
                    return
                }
                
                print("ContactUpload: Showing preview dialog with \(self.multiContactPreviewContacts.count) contacts")
                self.showMultiContactPreview = true
            }
        }
    }
    
    // MARK: - Handle Multi-Contact Send (matching Android upload logic)
    private func handleMultiContactSend(caption: String) {
        print("ContactUpload: === MULTI-CONTACT SEND ===")
        print("ContactUpload: Selected contacts count: \(multiContactPreviewContacts.count)")
        print("ContactUpload: Caption: '\(caption)'")
        
        // Contacts are uploaded directly from GroupMultiContactPreviewDialog (matching Android flow)
        // This callback is called after contacts are sent, so we just need to clear selections
        multiContactPreviewContacts.removeAll()
        multiContactPreviewCaption = ""
        
        // Hide gallery picker
        withAnimation {
            showGalleryPicker = false
        }
    }
    
    // MARK: - Send Button Handler (matching Android sendGrp.setOnClickListener - line 1174)
    private func handleSendButtonClick() {
        print("DIALOGUE_DEBUG: === SEND BUTTON CLICKED ===")
        print("DIALOGUE_DEBUG: Send button clicked for group chat!")
        
        // Check if multi-select mode is active (matching Android binding.multiSelectSmallCounterText.getText().toString())
        if selectedAssetIds.count > 0 {
            print("DIALOGUE_DEBUG: Send button clicked for multi-images!")
            print("DIALOGUE_DEBUG: Selected images count: \(selectedAssetIds.count)")
            
            // Light haptic feedback (Android-style tap vibration)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            // Show full-screen dialog for multi-image preview (matching Android setupMultiImagePreviewWithData)
            showMultiImagePreview = true
            return
        }
        
        // Normal text message send (matching Android line 1247-1368)
        let message = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        
        // Capture values needed in the closure
        let groupId = group.groupId
        let groupName = group.name
        let isReplyVisible = showReplyLayout
        let replyMsg = replyMessage
        let replyType = replyDataType
        let replyMsgId = replyMessageId
        
        // Run in background thread (matching Android new Thread)
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Generate modelId (matching Android database.getReference().push().getKey())
                let modelId = Database.database().reference().childByAutoId().key ?? UUID().uuidString
                
                // Get current time (matching Android SimpleDateFormat)
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "hh:mm a"
                let currentDateTimeString = dateFormatter.string(from: Date())
                
                // Get current date (matching Android Constant.getCurrentDate())
                let currentDateFormatter = DateFormatter()
                currentDateFormatter.dateFormat = "dd MMM yyyy"
                var currentDateString = currentDateFormatter.string(from: Date())
                
                // Ensure clean date without colon prefix (matching Android line 1260-1265)
                if currentDateString.starts(with: ":") {
                    currentDateString = String(currentDateString.dropFirst()).trimmingCharacters(in: .whitespaces)
                    print("⚠️ Removed leading colon from date: \(currentDateString)")
                }
                print("Using clean currentDate: \(currentDateString)")
                
                // Get user info (matching Android Constant.getSF.getString)
                let senderId = Constant.SenderIdMy
                let userName = UserDefaults.standard.string(forKey: Constant.full_name) ?? ""
                let micPhoto = UserDefaults.standard.string(forKey: Constant.profilePic) ?? ""
                let createdBy = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
                
                // Create emoji model array (matching Android - default empty emoji)
                let emojiModels: [EmojiModel] = [EmojiModel(name: "", emoji: "")]
                
                // Reply logic (matching Android)
                let replytextData: String?
                let replyKey: String?
                let replyTypeValue: String?
                let replyOldData: String?
                let replyCrtPostion: String?
                
                if isReplyVisible {
                    replytextData = message
                    replyKey = "ReplyKey"
                    replyTypeValue = "Text"
                    replyOldData = replyMsg
                    replyCrtPostion = replyMsgId
                } else {
                    replytextData = nil
                    replyKey = nil
                    replyTypeValue = nil
                    replyOldData = nil
                    replyCrtPostion = nil
                }
                
                // Create group message model (matching Android group_messageModel - line 1269)
                let newMessage = GroupChatMessage(
                    id: modelId,
                    uid: senderId,
                    message: message,
                    time: currentDateTimeString,
                    document: "",
                    dataType: Constant.Text,
                    fileExtension: nil,
                    name: nil,
                    phone: nil,
                    miceTiming: nil,
                    micPhoto: micPhoto,
                    createdBy: createdBy,
                    userName: userName,
                    receiverUid: groupId, // groupId as receiverUid for groups
                    docSize: nil,
                    fileName: nil,
                    thumbnail: nil,
                    fileNameThumbnail: nil,
                    caption: nil,
                    currentDate: currentDateString,
                    imageWidth: nil,
                    imageHeight: nil,
                    aspectRatio: nil,
                    active: 0, // 0 = sending, 1 = sent
                    selectionCount: "1",
                    selectionBunch: nil
                )
                
                // Store message in SQLite pending table before upload (matching Android insertPendingGroupMessage - line 1334)
                // Note: DatabaseHelper uses ChatMessage, so we'll need to convert or update DatabaseHelper
                // For now, we'll create a ChatMessage for database storage
                let chatMessageForDB = ChatMessage(
                    id: modelId,
                    uid: senderId,
                    message: message,
                    time: currentDateTimeString,
                    document: "",
                    dataType: Constant.Text,
                    fileExtension: nil,
                    name: nil,
                    phone: nil,
                    micPhoto: micPhoto,
                    miceTiming: nil,
                    userName: userName,
                    receiverId: groupId,
                    replytextData: replytextData,
                    replyKey: replyKey,
                    replyType: replyTypeValue,
                    replyOldData: replyOldData,
                    replyCrtPostion: replyCrtPostion,
                    forwaredKey: nil,
                    groupName: groupName,
                    docSize: nil,
                    fileName: nil,
                    thumbnail: nil,
                    fileNameThumbnail: nil,
                    caption: nil,
                    notification: 1,
                    currentDate: currentDateString,
                    emojiModel: emojiModels,
                    emojiCount: nil,
                    timestamp: Date().timeIntervalSince1970,
                    imageWidth: nil,
                    imageHeight: nil,
                    aspectRatio: nil,
                    selectionCount: "1",
                    selectionBunch: nil,
                    receiverLoader: 0
                )
                // Store message in SQLite group pending table before upload (matching Android insertPendingGroupMessage)
                DatabaseHelper.shared.insertPendingGroupMessage(chatMessageForDB, groupId: groupId)
                print("✅ [PendingMessages] Group text message stored in group pending table: \(modelId)")
                
                // Add message to UI immediately with receiverLoader: 0 (pending/uploading)
                // This shows the animated progress bar (matching Android messageList.add + itemAdd)
                DispatchQueue.main.async {
                    // Convert ChatMessage to GroupChatMessage for UI
                    let groupMessage = GroupChatMessage(
                        id: modelId,
                        uid: senderId,
                        message: message,
                        time: currentDateTimeString,
                        document: "",
                        dataType: Constant.Text,
                        fileExtension: nil,
                        name: nil,
                        phone: nil,
                        miceTiming: nil,
                        micPhoto: micPhoto,
                        createdBy: createdBy,
                        userName: userName,
                        receiverUid: groupId,
                        docSize: nil,
                        fileName: nil,
                        thumbnail: nil,
                        fileNameThumbnail: nil,
                        caption: nil,
                        currentDate: currentDateString,
                        imageWidth: nil,
                        imageHeight: nil,
                        aspectRatio: nil,
                        active: 0, // 0 = sending, 1 = sent
                        selectionCount: "1",
                        selectionBunch: nil
                    )
                    self.messages.append(groupMessage)
                    self.messageReceiverLoaders[modelId] = 0 // Show progress bar
                }
                
                // Upload message using MessageUploadService (matching Android UploadHelper.uploadContent - line 1349)
                DispatchQueue.main.async {
                    // Get user FCM token
                    let userFTokenKey = UserDefaults.standard.string(forKey: Constant.FCM_TOKEN) ?? ""
                    let deviceType = "2" // iOS device type
                    
                    // Use MessageUploadService.uploadGroupMessage (matching Android GroupMessageUploadService)
                    // Use GroupChatMessage for upload (matching Android group_messageModel)
                    MessageUploadService.shared.uploadGroupMessage(
                        model: newMessage, // GroupChatMessage
                        filePath: nil, // Text messages don't have files
                        userFTokenKey: userFTokenKey,
                        deviceType: deviceType
                    ) { success, errorMessage in
                        if success {
                            print("✅ MessageUploadService: Group message uploaded successfully with ID: \(modelId)")
                            
                            // Check if message exists in Firebase and stop progress bar (matching Android)
                            self.checkMessageInFirebaseAndStopProgress(messageId: modelId, groupId: groupId)
                        } else {
                            print("❌ MessageUploadService: Error uploading group message: \(errorMessage ?? "Unknown error")")
                            // Keep receiverLoader as 0 to show progress bar (message still pending)
                        }
                    }
                }
                
                // Update UI on main thread - Add message immediately with progress bar (matching Android)
                DispatchQueue.main.async {
                    // Clear message box and reply layout
                    self.messageText = ""
                    self.showReplyLayout = false
                    self.replyMessage = ""
                    self.replySenderName = ""
                    self.replyDataType = ""
                    self.isReplyFromSender = false
                    self.replyImageUrl = nil
                    self.replyContactName = nil
                    self.replyFileExtension = nil
                    self.replyMessageId = nil
                    self.hideEmojiAndGalleryPickers()
                }
                
            } catch {
                print("SendGroupClickListener: Error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    // Handle error if needed
                }
            }
        }
    }
    
    // MARK: - Check Message in Firebase and Stop Progress (matching Android)
    private func checkMessageInFirebaseAndStopProgress(messageId: String, groupId: String) {
        let senderId = Constant.SenderIdMy
        let chatKey = getSenderRoom() // Use getSenderRoom for consistency
        
        let database = Database.database().reference()
        let messageRef = database.child(Constant.GROUPCHAT).child(chatKey).child(messageId)
        
        print("🔍 [ProgressBar] Checking if message exists in Firebase: \(messageId)")
        
        messageRef.observeSingleEvent(of: .value, with: { snapshot in
            if snapshot.exists() {
                print("✅ [ProgressBar] Message confirmed in Firebase, stopping animation and updating receiverLoader")
                
                // Remove from pending table
                let removed = DatabaseHelper.shared.removePendingGroupMessage(modelId: messageId, groupId: groupId)
                if removed {
                    print("✅ [PendingMessages] Removed pending group message from SQLite: \(messageId)")
                }
                
                // Update receiverLoader to 1 immediately to stop progress bar
                let receiverLoaderRef = database.child(Constant.GROUPCHAT).child(chatKey).child(messageId).child("receiverLoader")
                receiverLoaderRef.setValue(1) { error, _ in
                    if let error = error {
                        print("❌ [ProgressBar] Error updating receiverLoader: \(error.localizedDescription)")
            } else {
                        print("✅ [ProgressBar] receiverLoader updated to 1 for message: \(messageId)")
                        // Update local state immediately
                        DispatchQueue.main.async {
                            self.messageReceiverLoaders[messageId] = 1
                            if let index = self.messages.firstIndex(where: { $0.id == messageId }) {
                                var updatedMessage = self.messages[index]
                                updatedMessage.active = 1 // Update the message model directly
                                self.messages[index] = updatedMessage
                            }
                        }
                    }
                }
            } else {
                print("⚠️ [ProgressBar] Message not found in Firebase yet, keeping animation")
            }
        })
    }
    
    // MARK: - Hide Emoji and Gallery Pickers (matching Android)
    private func hideEmojiAndGalleryPickers() {
        if showEmojiLayout {
            withAnimation {
                showEmojiLayout = false
            }
        }
        if showGalleryPicker {
            withAnimation {
                showGalleryPicker = false
            }
        }
    }
    
    // MARK: - Helper function to get sender room (matching Android)
    private func getSenderRoom() -> String {
        let senderId = Constant.SenderIdMy
        let groupId = group.groupId
        // Create chat key by combining senderId and groupId, replacing special characters
        let chatKey = (senderId + groupId).replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: "#", with: "_")
            .replacingOccurrences(of: "$", with: "_")
            .replacingOccurrences(of: "[", with: "_")
            .replacingOccurrences(of: "]", with: "_")
        return chatKey
    }
    
    // MARK: - Convert GroupChatMessage to ChatMessage (for MessageBubbleView)
    private func convertGroupMessageToChatMessage(_ groupMessage: GroupChatMessage) -> ChatMessage {
        return ChatMessage(
            id: groupMessage.id,
            uid: groupMessage.uid,
            message: groupMessage.message,
            time: groupMessage.time,
            document: groupMessage.document,
            dataType: groupMessage.dataType,
            fileExtension: groupMessage.fileExtension,
            name: groupMessage.name,
            phone: groupMessage.phone,
            micPhoto: groupMessage.micPhoto,
            miceTiming: groupMessage.miceTiming,
            userName: groupMessage.userName,
            receiverId: groupMessage.receiverUid,
            replytextData: nil, // Group messages don't have reply fields in GroupChatMessage
            replyKey: nil,
            replyType: nil,
            replyOldData: nil,
            replyCrtPostion: nil,
            forwaredKey: nil,
            groupName: group.name,
            docSize: groupMessage.docSize,
            fileName: groupMessage.fileName,
            thumbnail: groupMessage.thumbnail,
            fileNameThumbnail: groupMessage.fileNameThumbnail,
            caption: groupMessage.caption,
            notification: 1,
            currentDate: groupMessage.currentDate,
            emojiModel: [EmojiModel(name: "", emoji: "")],
            emojiCount: nil,
            timestamp: Date().timeIntervalSince1970, // Will be updated from Firebase if available
            imageWidth: groupMessage.imageWidth,
            imageHeight: groupMessage.imageHeight,
            aspectRatio: groupMessage.aspectRatio,
            selectionCount: groupMessage.selectionCount,
            selectionBunch: groupMessage.selectionBunch,
            receiverLoader: {
                // Use receiverLoader from Firebase if available, otherwise derive from active
                // receiverLoader: 0 = sending (show progress), 1 = sent (hide progress)
                if let receiverLoader = messageReceiverLoaders[groupMessage.id] {
                    return receiverLoader
                }
                // Fallback: use active field (active: 0 = sending, 1 = sent)
                return groupMessage.active == 1 ? 1 : 0
            }()
        )
    }
    
    // MARK: - Fetch Messages (matching Android fetchMessages)
    private func fetchMessages(senderRoom: String, listener: (() -> Void)? = nil) {
        // Check if already loading (matching Android isLoading check)
        if isLoading {
            print("📱 [fetchMessages] Already loading, skipping fetch.")
            listener?()
            return
        }
        
        // If we already have messages (cached data), don't show loader (matching Android)
        if !messages.isEmpty {
            print("📱 [fetchMessages] Group messages already available, skipping network fetch")
            listener?()
            return
        }
        
        isLoading = true
        print("📱 [fetchMessages] Fetching messages for room: \(senderRoom)")
        
        let database = Database.database().reference()
        let chatPath = "\(Constant.GROUPCHAT)/\(senderRoom)"
        
        // Query last 10 messages ordered by key (matching Android orderByKey().limitToLast(10))
        let query = database.child(chatPath)
            .queryOrderedByKey()
            .queryLimited(toLast: 10)
        
        // Use ChildEventListener for real-time updates (matching Android addChildEventListener)
        let handle = database.child(chatPath)
            .queryOrderedByKey()
            .observe(.childAdded) { snapshot in
                self.handleChildAdded(snapshot: snapshot, senderRoom: senderRoom)
            }
        
        // Also observe child changed events (matching Android onChildChanged)
        database.child(chatPath).observe(.childChanged) { snapshot in
            self.handleChildChanged(snapshot: snapshot)
        }
        
        // Store listener handles for cleanup
        firebaseListenerHandle = handle
        
        // Also observe once for initial load (matching Android)
        query.observeSingleEvent(of: .value) { snapshot in
            if snapshot.childrenCount == 0 {
                // No messages found
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.initialLoadDone = true
                    listener?()
                }
            } else {
                // Set lastKey to the oldest (first) key for pagination (matching Android)
                if let children = snapshot.children.allObjects as? [DataSnapshot], !children.isEmpty {
                    // Find the smallest (oldest) key
                    let keys = children.map { $0.key }
                    if let oldestKey = keys.min() {
                        DispatchQueue.main.async {
                            self.lastKey = oldestKey
                            print("📱 [fetchMessages] Set lastKey to: \(oldestKey)")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Handle Child Added (matching Android onChildAdded)
    private func handleChildAdded(snapshot: DataSnapshot, senderRoom: String) {
        guard let messageDict = snapshot.value as? [String: Any] else {
            print("❌ [handleChildAdded] Invalid message data")
                return
            }
            
        do {
            // Parse GroupChatMessage from Firebase snapshot
            let messageId = snapshot.key
            var groupMessage = try parseGroupMessageFromDict(messageDict, messageId: messageId)
            
            // Remove message from group pending table if it exists in Firebase (matching Android removePendingGroupMessage)
            DatabaseHelper.shared.removePendingGroupMessage(modelId: messageId, groupId: group.groupId)
            
            // Check if message already exists
            if let existingIndex = messages.firstIndex(where: { $0.id == messageId }) {
                // Update existing message (matching Android)
                DispatchQueue.main.async {
                    self.messages[existingIndex] = groupMessage
                    print("📱 [handleChildAdded] Updated existing message with ID: \(messageId)")
                }
            } else {
                // Add new message (matching Android)
                // Format date with unique date logic (matching Android uniqueDates.add)
                let uniqDate = groupMessage.currentDate ?? ""
                let formattedDate = uniqueDates.insert(uniqDate).inserted ? uniqDate : ":\(uniqDate)"
                groupMessage.currentDate = formattedDate
                
                DispatchQueue.main.async {
                    self.messages.append(groupMessage)
                    self.isLoading = false
                    self.initialLoadDone = true
                    
                    // Update lastKey if this is the oldest message (for pagination)
                    if self.lastKey == nil || messageId < self.lastKey! {
                        self.lastKey = messageId
                    }
                    
                    // Scroll to bottom (matching Android scrollToPosition)
                    // This will be handled by ScrollViewReader onChange
                    print("📱 [handleChildAdded] Added new message with ID: \(messageId)")
                }
            }
        } catch {
            print("❌ [handleChildAdded] Error parsing message: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Handle Child Changed (matching Android onChildChanged)
    private func handleChildChanged(snapshot: DataSnapshot) {
        guard let messageDict = snapshot.value as? [String: Any] else {
            return
        }
        
        let messageId = snapshot.key
        
        // Update receiverLoader if it changed (matching Android adapter update)
        if let receiverLoader = messageDict["receiverLoader"] as? Int {
            DispatchQueue.main.async {
                self.messageReceiverLoaders[messageId] = receiverLoader
                print("📱 [handleChildChanged] Updated receiverLoader to \(receiverLoader) for message: \(messageId)")
            }
        }
        
        do {
            let updatedMessage = try parseGroupMessageFromDict(messageDict, messageId: messageId)
            
            // Find and update message (matching Android)
            if let index = messages.firstIndex(where: { $0.id == messageId }) {
                DispatchQueue.main.async {
                    self.messages[index] = updatedMessage
                    print("📱 [handleChildChanged] Updated message with ID: \(messageId)")
                }
            }
                } catch {
            print("❌ [handleChildChanged] Error parsing message: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Parse Group Message from Dictionary
    private func parseGroupMessageFromDict(_ dict: [String: Any], messageId: String) throws -> GroupChatMessage {
        // Parse GroupChatMessage from Firebase dictionary (matching Android snapshot.getValue)
        let uid = dict["uid"] as? String ?? ""
        let message = dict["message"] as? String ?? ""
        let time = dict["time"] as? String ?? ""
        let document = dict["document"] as? String ?? ""
        let dataType = dict["dataType"] as? String ?? Constant.Text
        let fileExtension = dict["extension"] as? String
        let name = dict["name"] as? String
        let phone = dict["phone"] as? String
        let miceTiming = dict["miceTiming"] as? String
        let micPhoto = dict["micPhoto"] as? String
        let createdBy = dict["createdBy"] as? String
        let userName = dict["userName"] as? String
        let receiverUid = dict["receiverUid"] as? String ?? ""
        let docSize = dict["docSize"] as? String
        let fileName = dict["fileName"] as? String
        let thumbnail = dict["thumbnail"] as? String
        let fileNameThumbnail = dict["fileNameThumbnail"] as? String
        let caption = dict["caption"] as? String
        let currentDate = dict["currentDate"] as? String
        let imageWidth = dict["imageWidth"] as? String
        let imageHeight = dict["imageHeight"] as? String
        let aspectRatio = dict["aspectRatio"] as? String
        let active = dict["active"] as? Int ?? 0
        let receiverLoader = dict["receiverLoader"] as? Int ?? 1 // Parse receiverLoader from Firebase (default to 1 = sent if not present)
        let selectionCount = dict["selectionCount"] as? String
        let selectionBunch: [SelectionBunchModel]? = {
            if let bunchArray = dict["selectionBunch"] as? [[String: Any]] {
                return bunchArray.compactMap { bunchDict in
                    guard let imgUrl = bunchDict["imgUrl"] as? String,
                          let fileName = bunchDict["fileName"] as? String else {
                        return nil
                    }
                    return SelectionBunchModel(imgUrl: imgUrl, fileName: fileName)
                }
            }
            return nil
        }()
        
        // Store receiverLoader separately (matching Android model.getReceiverLoader())
        DispatchQueue.main.async {
            self.messageReceiverLoaders[messageId] = receiverLoader
        }
        
        return GroupChatMessage(
            id: messageId,
            uid: uid,
            message: message,
            time: time,
            document: document,
            dataType: dataType,
            fileExtension: fileExtension,
            name: name,
            phone: phone,
            miceTiming: miceTiming,
            micPhoto: micPhoto,
            createdBy: createdBy,
            userName: userName,
            receiverUid: receiverUid,
            docSize: docSize,
            fileName: fileName,
            thumbnail: thumbnail,
            fileNameThumbnail: fileNameThumbnail,
            caption: caption,
            currentDate: currentDate,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            aspectRatio: aspectRatio,
            active: active,
            selectionCount: selectionCount,
            selectionBunch: selectionBunch
        )
    }
    
    // MARK: - Load More (matching Android loadMore)
    private func loadMore() {
        if isLoading {
            print("📱 [loadMore] Already loading, skipping loadMore")
            return
        }
        
        // If we already have messages, don't show loader for loadMore (matching Android)
        if !messages.isEmpty && lastKey == nil {
            print("📱 [loadMore] Group messages already available, skipping loadMore")
            return
        }
        
        isLoading = true
        
        let senderRoom = getSenderRoom()
        let database = Database.database().reference()
        let chatPath = "\(Constant.GROUPCHAT)/\(senderRoom)"
        
        // Query older messages (matching Android orderByKey().limitToLast(PAGE_SIZE))
        // For key-based pagination, we need to get a larger set and filter
        var query: DatabaseQuery = database.child(chatPath)
            .queryOrderedByKey()
            .queryLimited(toLast: UInt(PAGE_SIZE * 3)) // Get more to account for filtering
        
        if let lastKey = lastKey {
            // Use queryEnding to get messages before lastKey (matching Android endBefore)
            // For orderByKey, we must use queryEnding(atValue:) without childKey parameter
            query = query.queryEnding(atValue: lastKey)
        }
        
        query.observeSingleEvent(of: .value) { snapshot in
            var fetchedNewMessages: [GroupChatMessage] = []
            var newLastKey: String? = nil
            
            guard let children = snapshot.children.allObjects as? [DataSnapshot] else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.hasMoreMessages = false
                }
            return
        }
        
            for child in children {
                let snapshotKey = child.key
                guard let messageDict = child.value as? [String: Any] else { continue }
                
                // Filter: only add messages before lastKey (matching Android endBefore)
                if let lastKey = self.lastKey, snapshotKey >= lastKey {
                    continue
                }
                
                do {
                    let model = try self.parseGroupMessageFromDict(messageDict, messageId: snapshotKey)
                    
                    // Avoid duplicate messages (matching Android)
                    let exists = self.messages.contains { $0.id == model.id }
                    if !exists {
                        // Format date with colon prefix for loaded older messages (matching Android)
                        let uniqDate = model.currentDate ?? ""
                        var formattedModel = model
                        formattedModel.currentDate = ":\(uniqDate)"
                        fetchedNewMessages.append(formattedModel)
                    }
                    
                    // Track the smallest (oldest) key for next pagination (matching Android)
                    if newLastKey == nil || snapshotKey < newLastKey! {
                        newLastKey = snapshotKey
                    }
        } catch {
                    print("❌ [loadMore] Error parsing message: \(error.localizedDescription)")
                }
            }
            
            // Update messages list (matching Android combinedList)
            if !fetchedNewMessages.isEmpty {
                DispatchQueue.main.async {
                    // Add newly fetched (older) messages at the top, then existing messages
                    self.messages = fetchedNewMessages + self.messages
                    self.lastKey = newLastKey
                    self.isLoading = false
                    print("📱 [loadMore] Loaded \(fetchedNewMessages.count) older messages")
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.hasMoreMessages = false
                    print("📱 [loadMore] No more messages to load")
                }
            }
        }
    }
    
    // MARK: - Remove Firebase Listeners
    private func removeFirebaseListeners() {
        if let handle = firebaseListenerHandle {
            let database = Database.database().reference()
            let senderRoom = getSenderRoom()
            let chatPath = "\(Constant.GROUPCHAT)/\(senderRoom)"
            database.child(chatPath).removeObserver(withHandle: handle)
            firebaseListenerHandle = nil
        }
    }
    
    // MARK: - Handle Half Swipe Reply
    private func handleHalfSwipeReply(_ message: ChatMessage) {
        // Set reply layout state (matching Android)
        showReplyLayout = true
        replyMessage = message.message
        replySenderName = message.userName ?? ""
        replyDataType = message.dataType
        replyImageUrl = message.document.isEmpty ? nil : message.document
        replyContactName = message.name
        replyFileExtension = message.fileExtension
        replyMessageId = message.id
        isReplyFromSender = message.uid == Constant.SenderIdMy
    }
    
    // MARK: - Handle Reply Tap
    private func handleReplyTap(message: ChatMessage) {
        // Scroll to replied message (matching Android)
        // Implementation will be added later
        print("📱 [handleReplyTap] Reply tapped for message: \(message.id)")
    }
    
    // MARK: - Handle Long Press
    private func handleLongPress(message: ChatMessage, position: CGPoint) {
        // Show context menu (matching Android)
        // Implementation will be added later
        print("📱 [handleLongPress] Long press on message: \(message.id)")
    }
    
    // MARK: - Toggle Message Selection
    private func toggleMessageSelection(messageId: String) {
        if selectedMessageIds.contains(messageId) {
            selectedMessageIds.remove(messageId)
        } else {
            selectedMessageIds.insert(messageId)
        }
        selectedCount = selectedMessageIds.count
        
        // Show/hide multi-select header (matching Android)
        if selectedCount > 0 {
            showMultiSelectHeader = true
        } else {
            showMultiSelectHeader = false
        }
    }
    
    // MARK: - Load Pending Group Messages (matching Android loadPendingMessages on onResume)
    private func loadPendingGroupMessages() {
        let groupId = group.groupId
        print("📱 [loadPendingGroupMessages] Loading pending group messages for group: \(groupId)")
        
        DatabaseHelper.shared.getPendingGroupMessages(groupId: groupId) { pendingMessages in
            guard !pendingMessages.isEmpty else {
                print("📱 [loadPendingGroupMessages] No pending group messages found in SQLite")
                    return
                }
                
            print("📱 [loadPendingGroupMessages] Found \(pendingMessages.count) pending group messages in SQLite")
            
            DispatchQueue.main.async {
                var addedCount = 0
                var skippedCount = 0
                
                for pendingMessage in pendingMessages {
                    // Check if message already exists in current list (matching Android duplicate check)
                    let exists = self.messages.contains { $0.id == pendingMessage.id }
                    
                    if !exists {
                        // Convert ChatMessage to GroupChatMessage for UI
                        let groupMessage = GroupChatMessage(
                            id: pendingMessage.id,
                            uid: pendingMessage.uid,
                            message: pendingMessage.message,
                            time: pendingMessage.time,
                            document: pendingMessage.document,
                            dataType: pendingMessage.dataType,
                            fileExtension: pendingMessage.fileExtension,
                            name: pendingMessage.name,
                            phone: pendingMessage.phone,
                            miceTiming: pendingMessage.miceTiming,
                            micPhoto: pendingMessage.micPhoto,
                            createdBy: nil,
                            userName: pendingMessage.userName,
                            receiverUid: pendingMessage.receiverId,
                            docSize: pendingMessage.docSize,
                            fileName: pendingMessage.fileName,
                            thumbnail: pendingMessage.thumbnail,
                            fileNameThumbnail: pendingMessage.fileNameThumbnail,
                            caption: pendingMessage.caption,
                            currentDate: pendingMessage.currentDate,
                            imageWidth: pendingMessage.imageWidth,
                            imageHeight: pendingMessage.imageHeight,
                            aspectRatio: pendingMessage.aspectRatio,
                            active: 0, // Pending messages are still sending
                            selectionCount: pendingMessage.selectionCount,
                            selectionBunch: pendingMessage.selectionBunch
                        )
                        
                        self.messages.append(groupMessage)
                        self.messageReceiverLoaders[pendingMessage.id] = 0 // Show progress bar
                        addedCount += 1
                        print("📱 [loadPendingGroupMessages] Adding pending message to UI: \(pendingMessage.id), dataType: \(pendingMessage.dataType), receiverLoader: \(pendingMessage.receiverLoader)")
                    } else {
                        print("📱 [loadPendingGroupMessages] Pending message already in list (skipping): \(pendingMessage.id)")
                        skippedCount += 1
                    }
                }
                
                if addedCount > 0 {
                    // Sort messages by timestamp (matching Android)
                    self.messages.sort { msg1, msg2 in
                        // Use timestamp if available, otherwise use currentDate
                        return true // Keep insertion order for now
                    }
                    
                    print("📱 [loadPendingGroupMessages] ✅ Added \(addedCount) pending group messages to UI (skipped \(skippedCount) duplicates)")
                } else {
                    print("📱 [loadPendingGroupMessages] ⚠️ No new pending group messages added (all \(skippedCount) were duplicates)")
                }
            }
        }
    }
}

