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
    @State private var showClearChatDialog: Bool = false
    @State private var navigateToGroupInfo: Bool = false
    
    // Progress indicators
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
    
    // Emoji picker state (matching ChattingScreen)
    @State private var emojis: [EmojiData] = []
    @State private var filteredEmojis: [EmojiData] = []
    @State private var isLoadingEmojis: Bool = false
    @State private var emojiSearchText: String = ""
    @State private var showEmojiLeftArrow: Bool = false
    @State private var isEmojiLayoutHorizontal: Bool = false
    @State private var isSyncingEmojiText: Bool = false
    @FocusState private var isEmojiSearchFieldFocused: Bool
    
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
    @State private var filteredMessages: [GroupChatMessage] = [] // Filtered messages for search
    @State private var isSearching: Bool = false // Track if currently searching
    @State private var isLoading: Bool = false
    @State private var initialLoadDone: Bool = false
    @State private var hasPerformedInitialScroll: Bool = false // Track if initial scroll has been performed
    @State private var lastKey: String? = nil // For pagination (matching Android lastKey)
    @State private var uniqueDates: Set<String> = [] // Track unique dates for date headers
    @State private var initiallyLoadedMessageIds: Set<String> = [] // Prevent duplicates from listener
    @State private var firebaseListenerHandle: DatabaseHandle? = nil // Firebase listener handle
    @State private var hasMoreMessages: Bool = true // Track if there are more messages to load
    @State private var selectedMessageIds: Set<String> = [] // Track selected messages for multi-select
    @State private var messageReceiverLoaders: [String: Int] = [:] // Store receiverLoader for each message (from Firebase)
    private let PAGE_SIZE: Int = 10 // Matching Android PAGE_SIZE
    
    // Image preview state (matching ChattingScreen)
    @State private var bunchPreviewImages: [SelectionBunchModel] = []
    @State private var bunchPreviewCurrentIndex: Int = 0
    @State private var navigateToMultipleImageScreen: Bool = false
    @State private var navigateToShowImageScreen: Bool = false
    @State private var selectedImageForShow: SelectionBunchModel?
    
    // Voice recording state (matching ChattingScreen)
    @State private var showVoiceRecordingBottomSheet: Bool = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordingTimer: Timer?
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingProgress: Double = 0.0
    @State private var audioFileURL: URL?
    @State private var isRecording: Bool = false
    
    // Long press dialog state (matching ChattingScreen)
    @State private var showLongPressDialog: Bool = false
    @State private var longPressedMessage: ChatMessage? = nil
    @State private var longPressPosition: CGPoint = .zero
    
    // Scroll down button state (matching ChattingScreen)
    @State private var scrollViewProxy: ScrollViewProxy? = nil // Hold proxy for manual scrolls (down arrow)
    @State private var showScrollDownButton: Bool = false // Show when user is away from bottom
    @State private var isLastItemVisible: Bool = false // Track if last message is visible (matching Android)
    @State private var downArrowCount: Int = 0
    @State private var showDownArrowCount: Bool = false
    
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
                
                // Main loader
                if showLoader {
                    HorizontalProgressBar()
                        .frame(height: 4)
                        .frame(maxWidth: .infinity)
                }
                
                // Message list (positioned above message input container, matching ChattingScreen)
                messageListView
                
                // Bottom input area (matching ChattingScreen layout)
                messageInputContainer
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
        .overlay(
            // Custom Clear Chat Dialog (matching Android clearmsg_layout.xml)
            Group {
                if showClearChatDialog {
                    ClearGroupChatDialog(
                        isPresented: $showClearChatDialog,
                        onConfirm: {
                            clearGroupChat()
                        }
                    )
                }
            }
        )
        .background(
            // Hidden NavigationLink for ForGroupVisibleScreen
            NavigationLink(
                destination: ForGroupVisibleScreen(group: group)
                    .onDisappear {
                        // Reset navigation state when ForGroupVisibleScreen is dismissed
                        navigateToGroupInfo = false
                    },
                isActive: $navigateToGroupInfo
            ) {
                EmptyView()
            }
            .hidden()
        )
        .overlay(
            // Long press dialog overlay - full screen alert with blur (matching ChattingScreen)
            Group {
                if showLongPressDialog, let message = longPressedMessage {
                    GroupMessageLongPressDialog(
                        message: message,
                        isSentByMe: message.uid == Constant.SenderIdMy,
                        position: longPressPosition,
                        group: group,
                        isPresented: $showLongPressDialog,
                        onCopy: {
                            handleCopyMessage(message: message)
                        },
                        onDelete: {
                            handleDeleteMessage(message: message)
                        },
                        onImageTap: { imageModel in
                            // Open ShowImageScreen for single image (matching ChattingScreen)
                            selectedImageForShow = imageModel
                            navigateToShowImageScreen = true
                        }
                    )
                }
            }
        )
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
        .background(
            // Hidden NavigationLink for programmatic navigation (matching Android Activity navigation)
            NavigationLink(
                destination: MultipleImageScreen(
                    images: bunchPreviewImages,
                    currentIndex: bunchPreviewCurrentIndex
                ),
                isActive: $navigateToMultipleImageScreen
            ) {
                EmptyView()
            }
            .hidden()
        )
        .background(
            // Hidden NavigationLink for ShowImageScreen (single image view)
            NavigationLink(
                destination: Group {
                    if let selectedImage = selectedImageForShow {
                        ShowImageScreen(
                            imageModel: selectedImage,
                            viewHolderTypeKey: nil // Group chat, so no sender/receiver distinction needed
                        )
                    } else {
                        EmptyView()
                    }
                },
                isActive: $navigateToShowImageScreen
            ) {
                EmptyView()
            }
            .hidden()
        )
        .sheet(isPresented: $showVoiceRecordingBottomSheet) {
            VoiceRecordingBottomSheet(
                recordingDuration: $recordingDuration,
                recordingProgress: $recordingProgress,
                isRecording: $isRecording,
                onCancel: {
                    cancelRecording()
                },
                onSend: {
                    sendAndStopRecording()
                }
            )
        }
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
                    handleBackTap()
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
                .padding(.trailing, 12)  // Add more space before profile
                
                // Search field (full width when active - matching Android binding.searchlyt.setVisibility(View.VISIBLE))
                if showSearch {
                    HStack {
                        Rectangle()
                            .fill(Color(hex: Constant.themeColor)) // Use original theme color in both light and dark mode
                            .frame(width: 1, height: 19.24)
                            .padding(.leading, 13)
                        
                        TextField("Search...", text: $searchText)
                            .font(.custom("Inter18pt-Medium", size: 16))
                            .foregroundColor(Color("TextColor"))
                            .padding(.leading, 13)
                            .textFieldStyle(PlainTextFieldStyle())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .onAppear {
                                // Focus search field (matching Android binding.searchEt.requestFocus())
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isMessageFieldFocused = false
                                }
                            }
                            .onChange(of: searchText) { newValue in
                                // Handle search text changes (matching Android TextWatcher)
                                handleSearchTextChanged(newValue)
                            }
                    }
                    .padding(.trailing, 10)
                } else {
                    // Group section (hidden when search is active, clickable to open ForGroupVisibleScreen)
                    Button(action: {
                        // Navigate to ForGroupVisibleScreen
                        navigateToGroupInfo = true
                    }) {
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
                    }
                    .buttonStyle(PlainButtonStyle())
                    
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
                                    .lineLimit(1...4)
                                    .frame(maxWidth: 180, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
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
                                    .onTapGesture {
                                        print("🔵 [MESSAGE_BOX_TAP] TextField tapped")
                                        handleMessageBoxTap()
                                    }
                                    .simultaneousGesture(
                                        TapGesture()
                                            .onEnded {
                                                print("🔵 [MESSAGE_BOX_TAP] Simultaneous tap gesture detected")
                                                handleMessageBoxTap()
                                            }
                                    )
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                print("🔵 [MESSAGE_BOX_TAP] VStack container tapped")
                                handleMessageBoxTap()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Emoji button (emoji) - marginEnd="5dp"
                            Button(action: {
                                handleEmojiButtonClick()
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
                        .frame(minHeight: 44, alignment: .center) // Allow wrap_content height
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
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.1)
                                .onEnded { _ in
                                    handleSendButtonLongPress()
                                }
                        )
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
    
    // MARK: - Emoji Layout (matching ChattingScreen)
    private var emojiLayoutView: some View {
        VStack(spacing: 0) {
            // Emoji Search Container - Top (50dp height, always visible, matching emojiSearchContainerTop)
            // android:layout_marginHorizontal="8dp"
            HStack(spacing: 0) {
                // Left arrow (shown when search is focused, matching emojiLeftArrow)
                // android:layout_width="40dp" android:layout_height="40dp"
                if showEmojiLeftArrow {
                Button(action: {
                        // Hide keyboard and change back to vertical/grid layout
                        print("🟡 [EMOJI_PICKER] Back arrow clicked - hiding keyboard and switching to grid")
                        withAnimation {
                            isEmojiSearchFieldFocused = false
                            showEmojiLeftArrow = false
                            isEmojiLayoutHorizontal = false
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
                    // No extra padding - arrow is at container edge
                }
                
                // Top search box (matching emojiSearchBox, layout_weight="1")
                // android:layout_marginStart="8dp" android:layout_marginEnd="8dp"
                // android:paddingStart="12dp" android:paddingEnd="12dp"
                ZStack(alignment: .leading) {
                    if emojiSearchText.isEmpty {
                        Text("Search emojis...")
                            .font(.custom("Inter18pt-Regular", size: 14))
                            .foregroundColor(Color("chtbtncolor"))
                            .padding(.leading, showEmojiLeftArrow ? 8 + 12 : 12) // marginStart(8dp) + paddingStart(12dp)
                            .padding(.trailing, 8 + 12) // marginEnd(8dp) + paddingEnd(12dp)
                    }
                    TextField("", text: $emojiSearchText)
                    .font(.custom("Inter18pt-Regular", size: 14))
                    .foregroundColor(Color("black_white_cross"))
                        .padding(.leading, 12) // android:paddingStart="12dp"
                        .padding(.trailing, 12) // android:paddingEnd="12dp"
                        .frame(height: 40) // android:layout_height="40dp"
                        .padding(.leading, showEmojiLeftArrow ? 8 : 0) // android:layout_marginStart="8dp" (only when arrow visible)
                        .padding(.trailing, 8) // android:layout_marginEnd="8dp"
                        .focused($isEmojiSearchFieldFocused)
                        .onChange(of: emojiSearchText) { newValue in
                            handleEmojiSearchTextChanged(newValue)
                        }
                        .onTapGesture {
                            // When tapped, immediately show arrow and change to horizontal layout
                            print("🟡 [EMOJI_PICKER] Search field tapped - showing horizontal layout and keyboard")
                            // Immediately switch to horizontal layout
                            showEmojiLeftArrow = true
                            isEmojiLayoutHorizontal = true
                            
                            // Request focus and open keyboard
                            DispatchQueue.main.async {
                                self.isEmojiSearchFieldFocused = true
                            }
                        }
                }
                .frame(maxWidth: .infinity, alignment: .leading) // layout_weight="1"
            }
            .frame(height: 50) // android:layout_height="50dp"
            .padding(.horizontal, 8) // android:layout_marginHorizontal="8dp"
            
            // Emoji RecyclerView - height="250dp"
            if isLoadingEmojis {
                ProgressView()
                    .frame(height: 250)
            } else {
                if isEmojiLayoutHorizontal {
                    // Horizontal layout (when searching) - single row, no vertical spacing
                    GeometryReader { geometry in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .center, spacing: 8) {
                                ForEach(filteredEmojis, id: \.codePoint) { emoji in
                                    Button(action: {
                                        // Insert emoji into message text
                                        messageText += emoji.character
                                    }) {
                                        Text(emoji.character)
                            .font(.system(size: 30))
                                            .frame(width: 40, height: 40)
                                    }
                    }
                }
                            .padding(.horizontal, 8)
                            .frame(height: 40) // Exact height to match emoji row
                        }
                        .frame(height: 40) // Exact height to match emoji row
                    }
                    .frame(height: 40) // Exact height to match emoji row
                } else {
                    // Vertical/Grid layout (default)
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 8) {
                            ForEach(filteredEmojis, id: \.codePoint) { emoji in
                                Button(action: {
                                    // Insert emoji into message text
                                    messageText += emoji.character
                                }) {
                                    Text(emoji.character)
                                        .font(.system(size: 30))
                                        .frame(width: 40, height: 40)
                                }
                            }
                        }
                        .padding(8)
            }
            .frame(height: 250)
                }
            }
        }
        .background(Color("edittextBg"))
        .onAppear {
            // Fetch emojis when layout appears (matching ChattingScreen)
            fetchEmojis()
        }
        .onChange(of: isEmojiSearchFieldFocused) { hasFocus in
            if hasFocus {
                // Show left arrow and change to horizontal layout when search gets focus
                print("🟡 [EMOJI_PICKER] Search field focused - showing horizontal layout")
                // Immediately switch to horizontal layout (no animation delay)
                showEmojiLeftArrow = true
                isEmojiLayoutHorizontal = true
            } else {
                // Hide left arrow and change back to vertical/grid layout when search loses focus
                print("🟡 [EMOJI_PICKER] Search field lost focus - showing grid layout")
                withAnimation {
                    showEmojiLeftArrow = false
                    isEmojiLayoutHorizontal = false
                }
            }
        }
    }
    
    // MARK: - Fetch Emojis from API (matching ChattingScreen fetchEmojis)
    private func fetchEmojis() {
        // Skip if already loading or already loaded
        guard !isLoadingEmojis else { return }
        guard emojis.isEmpty else { return }
        
        isLoadingEmojis = true
        
        // API endpoint: emojiController/fetch_emoji_data
        let urlString = "\(Constant.baseURL)emojiController/fetch_emoji_data"
        guard let url = URL(string: urlString) else {
            isLoadingEmojis = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoadingEmojis = false
                
                if let error = error {
                    print("🚫 [fetchEmojis] Error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    print("🚫 [fetchEmojis] No data received")
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let dataArray = json["data"] as? [[String: Any]] {
                        
                        var fetchedEmojis: [EmojiData] = []
                        for item in dataArray {
                            if let slug = item["slug"] as? String,
                               let character = item["character"] as? String,
                               let unicodeName = item["unicode_name"] as? String,
                               let codePoint = item["code_point"] as? String,
                               let group = item["group"] as? String,
                               let subGroup = item["sub_group"] as? String {
                                fetchedEmojis.append(EmojiData(
                                    slug: slug,
                                    character: character,
                                    unicodeName: unicodeName,
                                    codePoint: codePoint,
                                    group: group,
                                    subGroup: subGroup
                                ))
                            }
                        }
                        
                        self.emojis = fetchedEmojis
                        self.filteredEmojis = fetchedEmojis // Initialize filtered list
                        print("✅ [fetchEmojis] Loaded \(fetchedEmojis.count) emojis")
                    }
                } catch {
                    print("🚫 [fetchEmojis] JSON parsing error: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    // MARK: - Handle Emoji Search Text Changed (matching ChattingScreen handleEmojiSearchTextChanged)
    private func handleEmojiSearchTextChanged(_ newValue: String) {
        // Sync text between top and bottom search boxes (prevent infinite loop)
        if !isSyncingEmojiText {
            isSyncingEmojiText = true
            // Text is already synced via @State binding, just filter
            filterEmojis(newValue)
            isSyncingEmojiText = false
        }
    }
    
    // MARK: - Filter Emojis (matching ChattingScreen filterEmojis)
    private func filterEmojis(_ searchText: String) {
        let trimmedText = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedText.isEmpty {
            // Show all emojis when search is empty
            filteredEmojis = emojis
        } else {
            // Filter emojis by slug, character, unicodeName, group, or subGroup
            filteredEmojis = emojis.filter { emoji in
                emoji.slug.lowercased().contains(trimmedText) ||
                emoji.character.lowercased().contains(trimmedText) ||
                emoji.unicodeName.lowercased().contains(trimmedText) ||
                emoji.group.lowercased().contains(trimmedText) ||
                emoji.subGroup.lowercased().contains(trimmedText)
            }
        }
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
                .foregroundColor(Color("black_white_cross"))
                .multilineTextAlignment(.center)
                .padding(7)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color("cardBackgroundColornew"))
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
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
    
    // MARK: - Message List View (extracted to reduce complexity)
    private var messageListView: some View {
        ZStack(alignment: .top) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Load more indicator at top (matching Android)
                        if hasMoreMessages && !messages.isEmpty {
                            ProgressView()
                                .frame(height: 40)
                                .onAppear {
                                    loadMore()
                                }
                        }
                        
                        // Messages list (matching Android RecyclerView)
                        // Use filtered messages when searching, otherwise use all messages
                        ForEach(Array((isSearching ? filteredMessages : messages).enumerated()), id: \.element.id) { index, groupMessage in
                            // Convert GroupChatMessage to ChatMessage for MessageBubbleView
                            let chatMessage = convertGroupMessageToChatMessage(groupMessage)
                            
                            // Display all message types (Text, img, video, etc.) - matching ChattingScreen
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
                                onBunchLongPress: { selectionBunch in
                                    // Show preview dialog for bunch images (matching ChattingScreen)
                                    print("📸 [BunchPreview] onBunchLongPress (single tap) called with \(selectionBunch.count) images")
                                    for (index, img) in selectionBunch.enumerated() {
                                        print("📸 [BunchPreview] Setting image \(index): fileName=\(img.fileName), imgUrl=\(img.imgUrl.isEmpty ? "empty" : String(img.imgUrl.prefix(50)))")
                                    }
                                    
                                    // Set images first, then navigate to full screen (matching Android Activity navigation)
                                    bunchPreviewImages = selectionBunch
                                    bunchPreviewCurrentIndex = 0
                                    print("📸 [BunchPreview] State updated: bunchPreviewImages.count = \(bunchPreviewImages.count)")
                                    
                                    // Navigate to full screen (matching Android startActivity)
                                    navigateToMultipleImageScreen = true
                                    print("📸 [BunchPreview] After setting navigateToMultipleImageScreen: bunchPreviewImages.count = \(bunchPreviewImages.count)")
                                },
                                onImageTap: { imageModel in
                                    // Open ShowImageScreen for single image (matching ChattingScreen)
                                    selectedImageForShow = imageModel
                                    navigateToShowImageScreen = true
                                },
                                isHighlighted: false,
                                isMultiSelectMode: showMultiSelectHeader,
                                isSelected: selectedMessageIds.contains(chatMessage.id),
                                onSelectionToggle: { messageId in
                                    toggleMessageSelection(messageId: messageId)
                                },
                                isLastMessage: index == (isSearching ? filteredMessages.count : messages.count) - 1
                            )
                            .id(chatMessage.id)
                            .onAppear {
                                // Track last item visibility (matching ChattingScreen)
                                let currentMessages = isSearching ? filteredMessages : messages
                                if index == currentMessages.count - 1 {
                                    handleLastItemVisibility(id: chatMessage.id, index: index, isAppearing: true)
                                }
                            }
                            .onDisappear {
                                // Track last item visibility (matching ChattingScreen)
                                let currentMessages = isSearching ? filteredMessages : messages
                                if index == currentMessages.count - 1 {
                                    handleLastItemVisibility(id: chatMessage.id, index: index, isAppearing: false)
                                }
                            }
                        }
                    }
                }
                .contentShape(Rectangle()) // Ensure entire area is tappable
                .allowsHitTesting(true) // Ensure ScrollView can receive touches
                .onAppear {
                    scrollViewProxy = proxy
                }
                .onDisappear {
                    scrollViewProxy = nil
                }
                .onChange(of: initialLoadDone) { done in
                    guard done, !hasPerformedInitialScroll, !messages.isEmpty else { return }
                    hasPerformedInitialScroll = true
                    scrollToBottom(animated: false)
                    self.showScrollDownButton = false
                    self.isLastItemVisible = true
                    self.downArrowCount = 0
                    self.showDownArrowCount = false
                }
                .onChange(of: messages.count) { _ in
                    // Scroll to bottom when new messages are added (matching Android)
                    // Only scroll if not searching (search results are handled separately)
                    if !isSearching,
                       hasPerformedInitialScroll,
                       let lastMessageId = messages.last?.id,
                       !initiallyLoadedMessageIds.contains(lastMessageId) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo(lastMessageId, anchor: .bottom)
                            }
                            // Hide scroll down button when scrolling to bottom
                            self.showScrollDownButton = false
                            self.isLastItemVisible = true
                            self.downArrowCount = 0
                            self.showDownArrowCount = false
                        }
                    }
                }
            }
            
            // Scroll down button overlay (matching ChattingScreen)
            if showScrollDownButton {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        scrollDownButton
                    }
                }
                .allowsHitTesting(true) // Allow button to receive touches
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
            
            // Valuable card overlay (centered when messages are empty)
            if messages.isEmpty && initialLoadDone {
                VStack {
                    Spacer()
                    valuableCardView
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false) // Don't block touches to ScrollView
            }
        }
    }
    
    // MARK: - Menu Dialog (matching ChattingScreen menuOverlay design)
    private var menuDialog: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                showMenu = false
            }
                }
            
            VStack(alignment: .trailing, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    // Search button
            Button(action: {
                        withAnimation {
                            showSearch = true
                showMenu = false
                        }
                        // Focus search field (matching Android binding.searchEt.requestFocus())
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isMessageFieldFocused = false
                        }
            }) {
                        HStack {
                            Text("Search")
                                .font(.custom("Inter18pt-Medium", size: 17))
                    .foregroundColor(Color("TextColor"))
                            Spacer()
                        }
                        .padding(.leading, 15)
                        .padding(.top, 12)
                        .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
            }
                    .buttonStyle(MenuItemRippleStyle())
            
                    // For visible button (Group Info)
            Button(action: {
                        withAnimation {
                showMenu = false
                        }
                        // Navigate to Group Info screen (matching Android userInfoScreen)
                        navigateToGroupInfo = true
            }) {
                        HStack {
                            Text("For visible")
                                .font(.custom("Inter18pt-Medium", size: 17))
                    .foregroundColor(Color("TextColor"))
                            Spacer()
                        }
                        .padding(.leading, 15)
                        .padding(.top, 12)
                        .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
            }
                    .buttonStyle(MenuItemRippleStyle())
            
                    // Clear All button
            Button(action: {
                        withAnimation {
                showMenu = false
                        }
                        // Show confirmation dialog (matching Android delete_popup_row)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showClearChatDialog = true
                        }
            }) {
                        HStack {
                            Text("Clear All")
                                .font(.custom("Inter18pt-Medium", size: 17))
                    .foregroundColor(Color("TextColor"))
                            Spacer()
                        }
                        .padding(.leading, 15)
                        .padding(.top, 12)
                        .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
            }
                    .buttonStyle(MenuItemRippleStyle())
        }
            }
        .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color("BackgroundColor"))
                    .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
        )
            .frame(width: 180)
        .padding(.top, 50)
            .padding(.trailing, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
    }
    
    // MARK: - Menu 2 Dialog
    private var menu2Dialog: some View {
        VStack {
            Button(action: {
                withAnimation {
                    showSearch = true
                showMenu2 = false
                }
                // Focus search field (matching Android binding.searchEt.requestFocus())
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isMessageFieldFocused = false
                }
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
    
    // MARK: - Handle Message Box Tap (matching ChattingScreen handleMessageBoxTap)
    private func handleMessageBoxTap() {
        print("🔵 [MESSAGE_BOX_TAP] handleMessageBoxTap() called")
        print("🔵 [MESSAGE_BOX_TAP] showGalleryPicker: \(showGalleryPicker)")
        print("🔵 [MESSAGE_BOX_TAP] showEmojiLayout: \(showEmojiLayout)")
        print("🔵 [MESSAGE_BOX_TAP] isMessageFieldFocused: \(isMessageFieldFocused)")
        
        // If gallery picker is visible, hide it and show keyboard
        if showGalleryPicker {
            print("🔵 [MESSAGE_BOX_TAP] Gallery picker is visible - hiding it")
            withAnimation {
                showGalleryPicker = false
            }
            print("🔵 [MESSAGE_BOX_TAP] Gallery picker hidden, scheduling keyboard show")
            // Request focus and show keyboard after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                print("🔵 [MESSAGE_BOX_TAP] Setting focus to show keyboard")
                self.isMessageFieldFocused = true
                print("🔵 [MESSAGE_BOX_TAP] Focus set: \(self.isMessageFieldFocused)")
            }
            return
        }
        
        // If emoji picker is visible, hide it and reset emoji search state
        if showEmojiLayout {
            print("🔵 [MESSAGE_BOX_TAP] Emoji picker is visible - hiding it")
            withAnimation {
                showEmojiLayout = false
                // Reset emoji search state
                emojiSearchText = ""
                showEmojiLeftArrow = false
                isEmojiLayoutHorizontal = false
                isEmojiSearchFieldFocused = false
            }
            print("🔵 [MESSAGE_BOX_TAP] Emoji picker hidden, scheduling keyboard show")
            // Request focus and show keyboard after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                print("🔵 [MESSAGE_BOX_TAP] Setting focus to show keyboard")
                self.isMessageFieldFocused = true
                print("🔵 [MESSAGE_BOX_TAP] Focus set: \(self.isMessageFieldFocused)")
            }
            return
        }
        
        // If no picker is visible, just request focus
        print("🔵 [MESSAGE_BOX_TAP] No picker visible - just requesting focus")
        isMessageFieldFocused = true
        print("🔵 [MESSAGE_BOX_TAP] Focus set: \(isMessageFieldFocused)")
    }
    
    // MARK: - Handle Emoji Button Click (matching ChattingScreen handleEmojiButtonClick)
    private func handleEmojiButtonClick() {
        print("🟡 [EMOJI_BUTTON] Emoji button clicked")
        print("🟡 [EMOJI_BUTTON] isMessageFieldFocused: \(isMessageFieldFocused)")
        print("🟡 [EMOJI_BUTTON] showEmojiLayout: \(showEmojiLayout)")
        
        // If keyboard is open (message field is focused), hide it first
        if isMessageFieldFocused {
            print("🟡 [EMOJI_BUTTON] Keyboard is open - hiding it first")
            isMessageFieldFocused = false
            // Hide keyboard and then show emoji picker after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                print("🟡 [EMOJI_BUTTON] Showing emoji picker after keyboard hide")
                withAnimation {
                    self.showEmojiLayout = true
                    self.showGalleryPicker = false
                }
                // Fetch emojis when picker is shown
                self.fetchEmojis()
            }
        } else {
            // If keyboard is not open, just toggle emoji picker
            print("🟡 [EMOJI_BUTTON] Keyboard not open - toggling emoji picker")
            let willShowEmojiLayout = !showEmojiLayout
            withAnimation {
                showEmojiLayout.toggle()
                showGalleryPicker = false
            }
            // Fetch emojis when picker is shown
            if willShowEmojiLayout {
                fetchEmojis()
            }
        }
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
    
    // MARK: - Request Photos and Load (custom dialog first, when user opens gallery)
    private func requestPhotosAndLoad() {
        AndroidStylePermissionManager.shared.requestPermissionWithDialogFromTopVC(for: .photos) { granted in
            DispatchQueue.main.async {
                if granted { loadRecentPhotos() }
            }
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
    
    // MARK: - Camera Permission (custom dialog first, when user taps camera)
    private func requestCameraPermission(completion: @escaping (Bool) -> Void = { _ in }) {
        AndroidStylePermissionManager.shared.requestPermissionWithDialogFromTopVC(for: .camera) { granted in
            DispatchQueue.main.async { completion(granted) }
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
        // These will be updated with actual URLs after upload
        var placeholderSelectionBunch: [SelectionBunchModel] = []
        for index in 0..<selectedAssets.count {
            let fileName = "\(modelId)_\(index).jpg"
            let localFileURL = getLocalImageURL(fileName: fileName)
            placeholderSelectionBunch.append(SelectionBunchModel(imgUrl: localFileURL.path, fileName: fileName))
        }
        
        // Create message with local file path (matching ChattingScreen - shows preview immediately)
        let firstFileName = "\(modelId)_0.jpg"
        let localFileURL = getLocalImageURL(fileName: firstFileName)
        
        // Create message with group information using GroupChatMessage
        let createdBy = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        let newMessage = GroupChatMessage(
            id: modelId,
            uid: senderId,
            message: "",
            time: currentDateTimeString,
            document: localFileURL.path, // Local file path (matching ChattingScreen - shows preview immediately)
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
            fileName: firstFileName,
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
        
        // Store message in SQLite pending table before upload (matching Android insertPendingGroupMessage)
        let chatMessageForDB = ChatMessage(
            id: modelId,
            uid: senderId,
            message: "",
            time: currentDateTimeString,
            document: localFileURL.path, // Local file path
            dataType: Constant.img,
            fileExtension: "jpg",
            name: nil,
            phone: nil,
            micPhoto: micPhoto,
            miceTiming: nil,
            userName: userName,
            receiverId: groupId,
            replytextData: nil,
            replyKey: nil,
            replyType: nil,
            replyOldData: nil,
            replyCrtPostion: nil,
            forwaredKey: nil,
            groupName: group.name,
            docSize: nil,
            fileName: firstFileName,
            thumbnail: nil,
            fileNameThumbnail: nil,
            caption: trimmedCaption,
            notification: 1,
            currentDate: currentDateString,
            emojiModel: [EmojiModel(name: "", emoji: "")],
            emojiCount: nil,
            timestamp: timestamp,
            imageWidth: nil,
            imageHeight: nil,
            aspectRatio: nil,
            selectionCount: "\(selectedAssets.count)",
            selectionBunch: placeholderSelectionBunch.count >= 2 ? placeholderSelectionBunch : nil,
            receiverLoader: 0 // Show progress bar
        )
        DatabaseHelper.shared.insertPendingGroupMessage(chatMessageForDB, groupId: groupId)
        print("✅ [PendingMessages] Group image message stored in group pending table: \(modelId)")
        
        // Add to UI immediately (matching ChattingScreen: messageList.add, itemAdd, setLastItemVisible, notifyItemInserted, scrollToPosition)
        DispatchQueue.main.async {
            if !self.messages.contains(where: { $0.id == modelId }) {
                print("🔍 [ProgressBar] 📤 ADDING GROUP IMAGE MESSAGE TO UI")
                print("🔍 [ProgressBar]   - Message ID: \(modelId.prefix(8))...")
                print("🔍 [ProgressBar]   - receiverLoader: 0 (will show progress bar)")
                print("🔍 [ProgressBar]   - document: \(localFileURL.path)")
                self.messages.append(newMessage)
                self.messageReceiverLoaders[modelId] = 0 // Show progress bar
                self.isLastItemVisible = true // Show progress for pending message (matching Android setLastItemVisible(true))
                self.showScrollDownButton = false // Hide down button (matching Android downCardview.setVisibility(View.GONE))
                print("✅ [GROUP_MULTI_IMAGE] Message added to UI immediately: \(modelId)")
            }
        }
        
        // Upload images to Firebase Storage and send message (in background)
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
                    // Save image to local storage (matching Android Enclosure/Media/Images)
                    self.saveImageToLocalStorage(data: export.data, fileName: remoteFileName)
                    
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
                print("🚫 [GROUP_MULTI_IMAGE] Upload failed - no results")
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
            
            // Update message in UI with actual URLs (matching ChattingScreen)
            if let index = self.messages.firstIndex(where: { $0.id == modelId }) {
                print("🔍 [ProgressBar] 📤 UPDATING GROUP IMAGE MESSAGE IN UI")
                print("🔍 [ProgressBar]   - Message ID: \(modelId.prefix(8))...")
                print("🔍 [ProgressBar]   - Updated document: \(first.downloadURL)")
                self.messages[index] = updatedMessage
            }
            
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
                userFTokenKey: userFTokenKey
            ) { success, errorMessage in
                if success {
                    print("✅ [GROUP_MULTI_IMAGE] Uploaded \(sortedResults.count) images for modelId=\(modelId) using GROUP API")
                    // Check if message exists in Firebase and stop progress bar (matching ChattingScreen)
                    self.checkMessageInFirebaseAndStopProgress(messageId: modelId, groupId: self.group.groupId)
                } else {
                    print("🚫 [GROUP_MULTI_IMAGE] Upload error: \(errorMessage ?? "Unknown error")")
                    Constant.showToast(message: "Failed to send images. Please try again.")
                    // Keep receiverLoader as 0 to show progress bar (message still pending)
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
    
    /// Get local image file URL (matching Android exactPath2 + "/" + fileName)
    private func getLocalImageURL(fileName: String) -> URL {
        let imagesDir = getLocalImagesDirectory()
        return imagesDir.appendingPathComponent(fileName)
    }

    /// Resolve selection bunch URL to local path when available
    private func resolveSelectionBunchImageURL(remoteUrl: String, fileName: String) -> String {
        let imagesDir = getLocalImagesDirectory()
        
        if !fileName.isEmpty {
            let localURL = imagesDir.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: localURL.path) {
                return localURL.path
            }
        }
        
        guard !remoteUrl.isEmpty else {
            return remoteUrl
        }
        
        if remoteUrl.hasPrefix("file://"), let url = URL(string: remoteUrl),
           FileManager.default.fileExists(atPath: url.path) {
            return url.path
        }
        
        if remoteUrl.hasPrefix("/") && FileManager.default.fileExists(atPath: remoteUrl) {
            return remoteUrl
        }
        
        if let url = URL(string: remoteUrl), url.isFileURL,
           FileManager.default.fileExists(atPath: url.path) {
            return url.path
        }
        
        if let url = URL(string: remoteUrl), !url.lastPathComponent.isEmpty {
            let localURL = imagesDir.appendingPathComponent(url.lastPathComponent)
            if FileManager.default.fileExists(atPath: localURL.path) {
                return localURL.path
            }
        }
        
        return remoteUrl
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
                    // Hide scroll down button when sending message (matching ChattingScreen)
                    self.showScrollDownButton = false
                    self.isLastItemVisible = true
                }
                
                // Upload message using MessageUploadService (matching Android UploadHelper.uploadContent - line 1349)
                DispatchQueue.main.async {
                    // Get user FCM token
                    let userFTokenKey = UserDefaults.standard.string(forKey: Constant.FCM_TOKEN) ?? ""
                    // Use MessageUploadService.uploadGroupMessage (matching Android GroupMessageUploadService)
                    // Use GroupChatMessage for upload (matching Android group_messageModel); device_type from API only
                    MessageUploadService.shared.uploadGroupMessage(
                        model: newMessage, // GroupChatMessage
                        filePath: nil, // Text messages don't have files
                        userFTokenKey: userFTokenKey
                    ) { success, errorMessage in
                        if success {
                            print("✅ MessageUploadService: Group message uploaded successfully with ID: \(modelId)")
                            
                            // Check if message exists in Firebase and stop progress bar (matching Android)
                            self.checkMessageInFirebaseAndStopProgress(messageId: modelId, groupId: groupId)
                        } else {
                            print("🚫 MessageUploadService: Error uploading group message: \(errorMessage ?? "Unknown error")")
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
                        print("🚫 [ProgressBar] Error updating receiverLoader: \(error.localizedDescription)")
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
    
    // MARK: - Fetch Messages (matching Android fetchMessages and ChattingScreen)
    private func fetchMessages(senderRoom: String, listener: (() -> Void)? = nil) {
        // Check if already loading (matching Android isLoading check)
        if isLoading {
            print("📱 [fetchMessages] Already loading, skipping fetch.")
            listener?()
            return
        }
        
        // If we already have messages (cached data), don't show loader but ensure listener is attached
        if !messages.isEmpty {
            print("📱 [fetchMessages] Group messages already available, skipping network fetch")
            // Re-attach realtime listener if it was removed (e.g. after navigating back)
            if firebaseListenerHandle == nil {
                print("📱 [fetchMessages] ⚠️ Listener not attached, re-attaching for realtime updates")
                attachFullListener(senderRoom: senderRoom)
            }
            listener?()
            return
        }
        
        isLoading = true
        print("📱 [fetchMessages] Fetching messages for room: \(senderRoom)")
        
        if !initialLoadDone {
            // 🔹 Phase 1: Load last 10 messages immediately (matching ChattingScreen Phase 1)
            print("📱 [fetchMessages] Phase 1: Initial load (last 10 messages by key).")
        
        let database = Database.database().reference()
        let chatPath = "\(Constant.GROUPCHAT)/\(senderRoom)"
        database.child(chatPath).keepSynced(true)
        
        // Query last 10 messages ordered by key (matching Android orderByKey().limitToLast(10))
            let limitedQuery = database.child(chatPath)
            .queryOrderedByKey()
            .queryLimited(toLast: 10)
        
            limitedQuery.observeSingleEvent(of: .value) { snapshot in
                print("📱 [fetchMessages] Fetched initial data: \(snapshot.childrenCount) messages.")
                
                var tempList: [GroupChatMessage] = []
                
                guard let children = snapshot.children.allObjects as? [DataSnapshot] else {
                    print("⚠️ [fetchMessages] No children found")
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.initialLoadDone = true
                        listener?()
            }
                    return
                }
                
                for child in children {
                    let childKey = child.key
                    
                    // Skip invalid keys (matching Android)
                    if childKey.count <= 1 || childKey == ":" {
                        print("📱 [fetchMessages] Skipping invalid key: \(childKey)")
                        continue
                    }
                    
                    do {
                        // Parse message from Firebase snapshot
                        if let messageDict = child.value as? [String: Any] {
                            let model = try self.parseGroupMessageFromDict(messageDict, messageId: childKey)
                            // Add all message types (Text, Image, Video, Document, Contact, VoiceAudio)
                            tempList.append(model)
                        }
                    } catch {
                        print("🚫 [fetchMessages] Error parsing message for key: \(childKey), error: \(error.localizedDescription)")
                        continue
                    }
                }
                
                // Sort by key (matching Android - keys are chronological)
                tempList.sort { $0.id < $1.id }
                
                // Store message IDs from initial load to prevent duplicates when listener attaches
                let initialMessageIds = Set(tempList.map { $0.id })
                
                // Get oldest key from initial load (for pagination)
                let oldestKey = tempList.first?.id
                
                // 🔹 Directly update messages array immediately (matching ChattingScreen)
                DispatchQueue.main.async {
                    print("📱 [fetchMessages] Updating messages array with \(tempList.count) messages")
                    self.messages = tempList
                    
                    // Store initially loaded message IDs to prevent duplicates
                    self.initiallyLoadedMessageIds = initialMessageIds
                    
                    // Set lastKey for pagination (oldest message key)
                    if let oldestKey = oldestKey {
                        self.lastKey = oldestKey
                        print("📱 [fetchMessages] Set lastKey to: \(oldestKey)")
                    }
                    
                    // Update unique dates
                    for message in tempList {
                        if let date = message.currentDate {
                            self.uniqueDates.insert(date)
                        }
                    }
                    
                    self.isLoading = false
                    self.initialLoadDone = true
                    
                    // 🔁 Attach continuous listener after a delay (matching ChattingScreen)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.attachFullListener(senderRoom: senderRoom)
                    }
                    
                    listener?()
                }
            } withCancel: { error in
                self.isLoading = false
                        DispatchQueue.main.async {
                    self.initialLoadDone = true
                }
                print("🚫 [fetchMessages] Error fetching initial messages: \(error.localizedDescription)")
                
                // Don't show toast for network errors to avoid spam (matching Android)
                let nsError = error as NSError
                let isNetworkError = nsError.domain == NSURLErrorDomain && 
                                    (nsError.code == NSURLErrorNotConnectedToInternet || 
                                     nsError.code == NSURLErrorNetworkConnectionLost ||
                                     nsError.code == NSURLErrorTimedOut)
                
                if !isNetworkError {
                    DispatchQueue.main.async {
                        Constant.showToast(message: "Error loading messages: \(error.localizedDescription)")
                    }
                }
                listener?()
            }
        } else {
            // Already loaded once, just make sure full listener is attached (matching ChattingScreen)
            print("📱 [fetchMessages] Phase 2: Full listener already attached.")
            attachFullListener(senderRoom: senderRoom)
            listener?()
        }
    }
    
    // MARK: - Attach Full Listener for Real-time Updates (matching ChattingScreen)
    private func attachFullListener(senderRoom: String) {
        // Prevent duplicate listeners (matching ChattingScreen)
        if firebaseListenerHandle != nil {
            print("📱 [attachFullListener] Listener already attached, skipping")
            return
        }
        
        let database = Database.database().reference()
        let chatPath = "\(Constant.GROUPCHAT)/\(senderRoom)"
        database.child(chatPath).keepSynced(true)
        
        print("📱 [attachFullListener] Attaching real-time listener for room: \(senderRoom)")
        
        // Use ChildEventListener for real-time updates (matching Android addChildEventListener)
        let handle = database.child(chatPath)
            .queryOrderedByKey()
            .observe(.childAdded) { snapshot in
                // Skip messages that were already loaded in initial fetch (matching ChattingScreen)
                if self.initiallyLoadedMessageIds.contains(snapshot.key) {
                    print("📱 [attachFullListener] Skipping duplicate message from initial load: \(snapshot.key)")
                    return
                }
                self.handleChildAdded(snapshot: snapshot, senderRoom: senderRoom)
            }
        
        // Also observe child changed events (matching Android onChildChanged)
        database.child(chatPath).observe(.childChanged) { snapshot in
            self.handleChildChanged(snapshot: snapshot)
        }
        
        // Store listener handles for cleanup
        firebaseListenerHandle = handle
    }
    
    // MARK: - Handle Child Added (matching Android onChildAdded)
    private func handleChildAdded(snapshot: DataSnapshot, senderRoom: String) {
        guard let messageDict = snapshot.value as? [String: Any] else {
            print("🚫 [handleChildAdded] Invalid message data")
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
                    
                    // Update lastKey if this is the oldest message (for pagination)
                    if self.lastKey == nil || messageId < self.lastKey! {
                        self.lastKey = messageId
                    }
                    
                    // Hide scroll down button when new message arrives (matching ChattingScreen)
                    self.showScrollDownButton = false
                    self.isLastItemVisible = true
                    self.downArrowCount = 0
                    self.showDownArrowCount = false
                    
                    // Scroll to bottom (matching Android scrollToPosition)
                    // This will be handled by ScrollViewReader onChange
                    print("📱 [handleChildAdded] Added new message with ID: \(messageId)")
                }
            }
        } catch {
            print("🚫 [handleChildAdded] Error parsing message: \(error.localizedDescription)")
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
            print("🚫 [handleChildChanged] Error parsing message: \(error.localizedDescription)")
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
            // First try to parse from selectionBunch array (preferred format)
            if let bunchArray = dict["selectionBunch"] as? [[String: Any]] {
                let parsed: [SelectionBunchModel] = bunchArray.compactMap { (bunchDict: [String: Any]) -> SelectionBunchModel? in
                    guard let imgUrl = bunchDict["imgUrl"] as? String,
                          let fileName = bunchDict["fileName"] as? String else {
                        return nil
                    }
                    let resolvedUrl = resolveSelectionBunchImageURL(remoteUrl: imgUrl, fileName: fileName)
                    return SelectionBunchModel(imgUrl: resolvedUrl, fileName: fileName)
                }
                if !parsed.isEmpty {
                    return parsed
                }
            }
            
            // If selectionBunch array is not available, parse from individual img fields (img1, img2, img3, etc.)
            // This matches the Firebase structure where images are stored as separate fields
            // Firebase structure: document = main/first image, img1 = first image (may be same as document), img2 = second image, etc.
            if let count = selectionCount, let selectionCountInt = Int(count), selectionCountInt > 0 {
                var bunch: [SelectionBunchModel] = []
                
                // Parse img1, img2, img3, etc. fields
                // Note: img1 might be the same as document or a separate field
                for i in 1...selectionCountInt {
                    let imgKey = "img\(i)"
                    var imgUrl: String? = nil
                    var imgFileName: String? = nil
                    
                    // Try to get from img1, img2, img3, etc. fields first
                    if let url = dict[imgKey] as? String, !url.isEmpty {
                        imgUrl = url
                        // Extract fileName from imgUrl or construct from pattern
                        if let baseFileName = fileName {
                            // Replace _0 with _i-1 pattern (e.g., modelId_0.jpg -> modelId_1.jpg for img2)
                            // For img1 (i=1), use _0, for img2 (i=2), use _1, etc.
                            imgFileName = baseFileName.replacingOccurrences(of: "_0.", with: "_\(i-1).")
                        } else {
                            imgFileName = "image_\(i-1).jpg"
                        }
                    } else if i == 1 && !document.isEmpty {
                        // For first image (img1), fallback to document field if img1 is not available
                        imgUrl = document
                        imgFileName = fileName ?? "image_0.jpg"
                    }
                    
                    if let url = imgUrl, let name = imgFileName {
                        let resolvedUrl = resolveSelectionBunchImageURL(remoteUrl: url, fileName: name)
                        bunch.append(SelectionBunchModel(imgUrl: resolvedUrl, fileName: name))
                    }
                }
                
                // If we have multiple images (selectionCount >= 2), return the bunch
                if bunch.count >= 2 {
                    return bunch
                } else if bunch.count == 1 && selectionCountInt == 1 {
                    // Single image: return it for single image display
                    return bunch
                } else if bunch.count == 1 && selectionCountInt > 1 {
                    // Partial data: we have selectionCount > 1 but only one image (others might be uploading)
                    return bunch
                }
            }
            
            // Fallback: if we have document field and it's an image message, create single image bunch
            // This handles the case where selectionCount might be missing or "1"
            if dataType == Constant.img && !document.isEmpty, let fileName = fileName {
                // Check if selectionCount exists and is > 1, if so, we might need to wait for more images
                if let count = selectionCount, let countInt = Int(count), countInt > 1 {
                    // Multiple images expected but only document available - return single image for now
                    let resolvedUrl = resolveSelectionBunchImageURL(remoteUrl: document, fileName: fileName)
                    return [SelectionBunchModel(imgUrl: resolvedUrl, fileName: fileName)]
                } else {
                    // Single image message
                    let resolvedUrl = resolveSelectionBunchImageURL(remoteUrl: document, fileName: fileName)
                    return [SelectionBunchModel(imgUrl: resolvedUrl, fileName: fileName)]
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
                    print("🚫 [loadMore] Error parsing message: \(error.localizedDescription)")
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
        print("📱 [handleLongPress] Long press on message: \(message.id), position: \(position)")
        longPressedMessage = message
        longPressPosition = position
        showLongPressDialog = true
    }
    
    // MARK: - Handle Copy Message
    private func handleCopyMessage(message: ChatMessage) {
        print("📱 [handleCopyMessage] Copying message: \(message.id)")
        
        // Copy message text to clipboard (matching Android ClipboardManager)
        let textToCopy: String
        if message.dataType == Constant.Text {
            textToCopy = message.message
        } else if message.dataType == Constant.contact, let name = message.name, let phone = message.phone {
            textToCopy = "\(name)\n\(phone)"
        } else {
            // For other types, copy a placeholder or empty string
            textToCopy = message.message
        }
        
        UIPasteboard.general.string = textToCopy
        Constant.showToast(message: "Message copied")
        
        // Close dialog
        showLongPressDialog = false
        longPressedMessage = nil
    }
    
    // MARK: - Handle Delete Message
    private func handleDeleteMessage(message: ChatMessage) {
        print("📱 [handleDeleteMessage] Deleting message: \(message.id)")
        
        let groupId = group.groupId
        let senderId = Constant.SenderIdMy
        let senderRoom = getSenderRoom()
        let messageId = message.id
        
        // Step 1: Remove from Firebase GROUPCHAT (matching Android)
        let database = Database.database().reference()
        let messageRef = database.child(Constant.GROUPCHAT).child(senderRoom).child(messageId)
        
        messageRef.removeValue { error, _ in
            if let error = error {
                print("🚫 [handleDeleteMessage] Error removing from Firebase: \(error.localizedDescription)")
                Constant.showToast(message: "Failed to delete message")
                return
            }
            
            print("✅ [handleDeleteMessage] Removed from Firebase GROUPCHAT")
            
            // Step 2: Get group members and call delete API for each (matching Android deleteDataForAllMembers)
            self.getGroupMembersAndDelete(groupId: groupId, messageId: messageId, senderId: senderId)
            
            // Step 3: Remove from local messages array
            DispatchQueue.main.async {
                if let index = self.messages.firstIndex(where: { $0.id == messageId }) {
                    self.messages.remove(at: index)
                }
                
                // Remove from pending table if exists
                DatabaseHelper.shared.removePendingGroupMessage(modelId: messageId, groupId: groupId)
                
                // Close dialog
                self.showLongPressDialog = false
                self.longPressedMessage = nil
            }
        }
    }
    
    // MARK: - Get Group Members and Delete (matching Android deleteDataForAllMembers)
    private func getGroupMembersAndDelete(groupId: String, messageId: String, senderId: String) {
        // Call get_group_members API (matching Android Webservice.get_group_members_for_adapter)
        let urlString = "\(Constant.baseURL)groupController/get_group_members"
        guard let url = URL(string: urlString) else {
            print("🚫 [getGroupMembersAndDelete] Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "groupId": groupId
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("🚫 [getGroupMembersAndDelete] Error fetching group members: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("🚫 [getGroupMembersAndDelete] No data received")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let dataArray = json["data"] as? [[String: Any]] {
                    
                    var memberUids: [String] = []
                    for memberDict in dataArray {
                        if let uid = memberDict["uid"] as? String, !uid.isEmpty {
                            memberUids.append(uid)
                        }
                    }
                    
                    print("✅ [getGroupMembersAndDelete] Found \(memberUids.count) group members")
                    
                    // Call delete API for each member (matching Android delete_chatingindivisual)
                    for (index, memberUid) in memberUids.enumerated() {
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                            self.deleteMessageForMember(messageId: messageId, senderId: senderId, memberUid: memberUid)
                        }
                    }
                }
            } catch {
                print("🚫 [getGroupMembersAndDelete] JSON parsing error: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    // MARK: - Delete Message for Member (matching Android Webservice.delete_chatingindivisual)
    private func deleteMessageForMember(messageId: String, senderId: String, memberUid: String) {
        let urlString = "\(Constant.baseURL)chatController/delete_chatingindivisual"
        guard let url = URL(string: urlString) else {
            print("🚫 [deleteMessageForMember] Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "modelId": messageId,
            "uid": senderId,
            "receiverUid": memberUid
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("🚫 [deleteMessageForMember] Error deleting for member \(memberUid): \(error.localizedDescription)")
                return
            }
            
            print("✅ [deleteMessageForMember] Delete API called for member: \(memberUid)")
        }.resume()
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
                        // Hide scroll down button when loading pending messages (matching ChattingScreen)
                        self.showScrollDownButton = false
                        self.isLastItemVisible = true
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
    
    // MARK: - Voice Recording Functions (matching ChattingScreen)
    
    /// Handle long press on send button (matching Android onLongClickListener)
    private func handleSendButtonLongPress() {
        print("VoiceRecording: === SEND BUTTON LONG PRESS ===")
        
        // Check if multi-select is active (matching Android)
        if selectedAssetIds.count > 0 {
            print("VoiceRecording: Multi-select active, ignoring long press")
            return
        }
        
        // Hide keyboard (matching Android)
        isMessageFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        // Vibrate (matching Android Constant.Vibrator50)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Animate send button (matching Android ObjectAnimator 1.3f -> 0.8f)
        withAnimation(.easeInOut(duration: 0.2)) {
            sendButtonScale = 1.3
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.2)) {
                self.sendButtonScale = 0.8
            }
        }
        
        // Show bottom sheet dialog
        showVoiceRecordingBottomSheet = true
        
        // Start recording after a short delay to allow bottom sheet to appear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.startRecording()
        }
    }
    
    /// Start voice recording (matching Android startRecording)
    private func startRecording() {
        print("VoiceRecording: === START RECORDING ===")
        // Custom permission dialog first, then system (when user taps voice record)
        AndroidStylePermissionManager.shared.requestPermissionWithDialogFromTopVC(for: .microphone) { granted in
            guard granted else {
                DispatchQueue.main.async {
                    Constant.showToast(message: "Microphone permission is required for voice recording")
                    self.showVoiceRecordingBottomSheet = false
                    self.resetSendButtonScale()
                }
                return
            }
            
            DispatchQueue.main.async {
                do {
                    // Configure audio session
                    let audioSession = AVAudioSession.sharedInstance()
                    try audioSession.setCategory(.playAndRecord, mode: .default)
                    try audioSession.setActive(true)
                    
                    // Create audio file URL (matching Android file path structure)
                    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let audiosDir = documentsPath.appendingPathComponent("Enclosure/Media/Audios", isDirectory: true)
                    
                    // Create directory if it doesn't exist
                    try FileManager.default.createDirectory(at: audiosDir, withIntermediateDirectories: true, attributes: nil)
                    
                    // Generate filename with timestamp (matching Android format)
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                    let timestamp = dateFormatter.string(from: Date())
                    // Note: iOS saves AAC as .m4a, but Android uses .mp3 extension
                    // We'll use .m4a (correct format) and backend should handle it
                    let fileName = "\(timestamp).m4a"
                    let fileURL = audiosDir.appendingPathComponent(fileName)
                    
                    self.audioFileURL = fileURL
                    
                    // Configure audio recorder settings (matching Android: MPEG_4, AAC)
                    let settings: [String: Any] = [
                        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                        AVSampleRateKey: 44100,
                        AVNumberOfChannelsKey: 1,
                        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                    ]
                    
                    // Create recorder
                    self.audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
                    self.audioRecorder?.prepareToRecord()
                    self.audioRecorder?.record()
                    
                    self.isRecording = true
                    self.recordingDuration = 0
                    // Progress bar starts at 100% (full) and decreases to 0% as time runs out (matching Android CountDownTimer)
                    self.recordingProgress = 100.0
                    
                    // Start timer for countdown (60 seconds max, matching Android)
                    self.recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                        // Update duration
                        self.recordingDuration += 0.1
                        
                        // Update progress bar: progress decreases from 100 to 0 as time increases (matching Android CountDownTimer)
                        let elapsedSeconds = self.recordingDuration
                        let maxSeconds: Double = 60.0
                        let remainingSeconds = max(0, maxSeconds - elapsedSeconds)
                        self.recordingProgress = max(0, min(100, (remainingSeconds / maxSeconds) * 100.0))
                        
                        // Auto-stop at 60 seconds (matching Android countDownTimer)
                        if self.recordingDuration >= 60.0 {
                            timer.invalidate()
                            self.recordingDuration = 60.0 // Cap at exactly 60 seconds
                            self.recordingProgress = 0.0 // Progress bar at 0% when time is up
                            self.sendAndStopRecording()
                            self.showVoiceRecordingBottomSheet = false
                            self.resetSendButtonScale()
                        }
                    }
                    
                    print("VoiceRecording: Recording started, file: \(fileURL.path)")
                } catch {
                    print("VoiceRecording: Error starting recording: \(error.localizedDescription)")
                    Constant.showToast(message: "Failed to start recording")
                    self.showVoiceRecordingBottomSheet = false
                    self.resetSendButtonScale()
                }
            }
        }
    }
    
    /// Cancel recording (matching Android cancelRecording)
    private func cancelRecording() {
        print("VoiceRecording: === CANCEL RECORDING ===")
        
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        audioRecorder?.stop()
        audioRecorder = nil
        
        // Delete audio file (matching Android mFilePath.delete())
        if let fileURL = audioFileURL {
            try? FileManager.default.removeItem(at: fileURL)
            print("VoiceRecording: Deleted audio file: \(fileURL.path)")
        }
        
        audioFileURL = nil
        isRecording = false
        recordingDuration = 0
        recordingProgress = 0.0
        
        // Reset audio session
        try? AVAudioSession.sharedInstance().setActive(false)
        
        // Reset send button scale (matching Android ObjectAnimator 1f, 1f, 1f)
        resetSendButtonScale()
        
        showVoiceRecordingBottomSheet = false
    }
    
    /// Send and stop recording (matching Android sendAndStopRecording)
    private func sendAndStopRecording() {
        print("VoiceRecording: === SEND AND STOP RECORDING ===")
        
        guard let recorder = audioRecorder, let fileURL = audioFileURL else {
            print("VoiceRecording: Recorder or file URL is nil")
            cancelRecording()
            return
        }
        
        // Stop recording
        recorder.stop()
        audioRecorder = nil
        
        // Stop timer
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        isRecording = false
        
        // Verify audio file exists and has content
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let fileAttributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let fileSize = fileAttributes[.size] as? Int64,
              fileSize > 0 else {
            print("VoiceRecording: Audio file not found or empty")
            Constant.showToast(message: "Failed to record audio")
            cancelRecording()
            return
        }
        
        print("VoiceRecording: Audio file exists, size: \(fileSize) bytes")
        
        // Get audio duration
        let audioDuration = getAudioDuration(fileURL: fileURL)
        print("VoiceRecording: Audio duration: \(audioDuration)")
        
        // Reset send button scale (matching Android ObjectAnimator 1f, 1f, 1f)
        resetSendButtonScale()
        
        // Hide bottom sheet
        showVoiceRecordingBottomSheet = false
        
        // Upload audio file
        uploadGroupAudioToFirebase(fileURL: fileURL, duration: audioDuration, fileName: fileURL.lastPathComponent)
        
        // Reset audio session
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    /// Get audio duration (matching Android getAudioDuration)
    private func getAudioDuration(fileURL: URL) -> String {
        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            let durationSeconds = Int(audioPlayer.duration)
            let minutes = durationSeconds / 60
            let seconds = durationSeconds % 60
            return String(format: "%02d:%02d", minutes, seconds)
        } catch {
            print("VoiceRecording: Error getting audio duration: \(error.localizedDescription)")
            return "00:00"
        }
    }
    
    /// Upload audio to Firebase Storage and send message (matching Android upload logic, adapted for groups)
    private func uploadGroupAudioToFirebase(fileURL: URL, duration: String, fileName: String) {
        print("VoiceRecording: === UPLOAD GROUP AUDIO TO FIREBASE ===")
        print("VoiceRecording: File: \(fileURL.path), Duration: \(duration), FileName: \(fileName)")
        
        guard let audioData = try? Data(contentsOf: fileURL) else {
            print("VoiceRecording: Failed to read audio file data")
            Constant.showToast(message: "Failed to read audio file")
            return
        }
        
        let groupId = group.groupId
        let senderId = Constant.SenderIdMy
        let userName = UserDefaults.standard.string(forKey: Constant.full_name) ?? ""
        let micPhoto = UserDefaults.standard.string(forKey: Constant.profilePic) ?? ""
        let createdBy = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "hh:mm a"
        let currentDateTimeString = timeFormatter.string(from: Date())
        
        let currentDateFormatter = DateFormatter()
        currentDateFormatter.dateFormat = "yyyy-MM-dd"
        let currentDateString = currentDateFormatter.string(from: Date())
        
        let timestamp = Date().timeIntervalSince1970
        let modelId = UUID().uuidString
        
        // Upload to Firebase Storage using GROUPCHAT path
        let storagePath = "\(Constant.GROUPCHAT)/\(groupId)/\(modelId).m4a"
        let ref = Storage.storage().reference().child(storagePath)
        let metadata = StorageMetadata()
        metadata.contentType = "audio/m4a"
        
        ref.putData(audioData, metadata: metadata) { metadata, error in
            if let error = error {
                print("VoiceRecording: Upload error: \(error.localizedDescription)")
                Constant.showToast(message: "Failed to upload audio")
                return
            }
            
            // Get download URL
            ref.downloadURL { url, error in
                if let error = error {
                    print("VoiceRecording: Download URL error: \(error.localizedDescription)")
                    Constant.showToast(message: "Failed to get download URL")
                    return
                }
                
                guard let downloadURL = url else {
                    print("VoiceRecording: Download URL is nil")
                    Constant.showToast(message: "Failed to get download URL")
                    return
                }
                
                print("VoiceRecording: Upload successful, URL: \(downloadURL.absoluteString)")
                
                // Create GroupChatMessage (matching Android group_messageModel with voiceAudio dataType)
                let newMessage = GroupChatMessage(
                    id: modelId,
                    uid: senderId,
                    message: "",
                    time: currentDateTimeString,
                    document: downloadURL.absoluteString,
                    dataType: Constant.voiceAudio,
                    fileExtension: "m4a", // iOS AAC format (Android uses .mp3 but same AAC codec)
                    name: nil,
                    phone: nil,
                    miceTiming: duration, // Audio duration in format "MM:SS"
                    micPhoto: micPhoto,
                    createdBy: createdBy,
                    userName: userName,
                    receiverUid: groupId, // Use groupId as receiverUid for groups
                    docSize: nil,
                    fileName: fileName,
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
                
                // Convert GroupChatMessage to ChatMessage for database storage
                let chatMessageForDB = ChatMessage(
                    id: modelId,
                    uid: senderId,
                    message: "",
                    time: currentDateTimeString,
                    document: downloadURL.absoluteString,
                    dataType: Constant.voiceAudio,
                    fileExtension: "m4a",
                    name: nil,
                    phone: nil,
                    micPhoto: micPhoto,
                    miceTiming: duration,
                    userName: userName,
                    receiverId: groupId,
                    replytextData: nil,
                    replyKey: nil,
                    replyType: nil,
                    replyOldData: nil,
                    replyCrtPostion: nil,
                    forwaredKey: nil,
                    groupName: group.name,
                    docSize: nil,
                    fileName: fileName,
                    thumbnail: nil,
                    fileNameThumbnail: nil,
                    caption: nil,
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
                
                // Store message in SQLite group pending table before upload (matching Android insertPendingGroupMessage)
                DatabaseHelper.shared.insertPendingGroupMessage(chatMessageForDB, groupId: groupId)
                print("✅ [PendingMessages] Group voice audio message stored in group pending table: \(modelId)")
                
                // Add to UI immediately with progress bar (matching Android messageList.add + itemAdd)
                DispatchQueue.main.async {
                    self.messages.append(newMessage)
                    self.messageReceiverLoaders[modelId] = 0 // Show progress bar
                    // Hide scroll down button when sending voice message (matching ChattingScreen)
                    self.showScrollDownButton = false
                    self.isLastItemVisible = true
                }
                
                // Upload via MessageUploadService using GROUP API
                let userFTokenKey = UserDefaults.standard.string(forKey: Constant.FCM_TOKEN) ?? ""
                
                MessageUploadService.shared.uploadGroupMessage(
                    model: newMessage,
                    filePath: fileURL.path,
                    userFTokenKey: userFTokenKey
                ) { success, errorMessage in
                    if success {
                        print("✅ [VOICE_RECORDING] Uploaded group audio for modelId=\(modelId)")
                        // Check if message exists in Firebase and stop progress bar (matching Android)
                        self.checkMessageInFirebaseAndStopProgress(messageId: modelId, groupId: groupId)
                    } else {
                        print("🚫 [VOICE_RECORDING] Upload error: \(errorMessage ?? "Unknown error")")
                        Constant.showToast(message: "Failed to send audio. Please try again.")
                        // Keep receiverLoader as 0 to show progress bar (message still pending)
                    }
                }
            }
        }
    }
    
    /// Reset send button scale animation (matching Android ObjectAnimator 1f, 1f, 1f)
    private func resetSendButtonScale() {
        withAnimation(.easeInOut(duration: 0.2)) {
            sendButtonScale = 1.0
        }
    }
    
    // MARK: - Scroll Down Button (matching ChattingScreen)
    private var scrollDownButton: some View {
        Button(action: {
            let currentMessages = isSearching ? filteredMessages : messages
            print("📜 [SCROLL] Scroll down button tapped - messages.count: \(currentMessages.count)")
            
            // Light haptic feedback (Android-style tap vibration)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            // Scroll to the last message if available
            scrollToBottom(animated: true)
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
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundColor(Color(hex: Constant.themeColor)) // apply theme tint
                    
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
        .padding(.trailing, 15) // marginEnd="20dp" to match Android spacing request
        .padding(.bottom, 45) // marginBottom="45dp"
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    
    // MARK: - Handle Last Item Visibility (matching ChattingScreen)
    private func handleLastItemVisibility(id: String, index: Int, isAppearing: Bool) {
        // Check if this is the last message (matching Android lastVisiblePosition >= totalItems - 1)
        let currentMessages = isSearching ? filteredMessages : messages
        let isLastMessage = index == currentMessages.count - 1
        
        if isLastMessage {
            // Update isLastItemVisible flag (matching Android)
            isLastItemVisible = isAppearing
            
            // Update down button visibility (matching Android)
            // Hide when last item is visible, show when not visible
            showScrollDownButton = !isLastItemVisible
            
            // Reset down arrow count when last item becomes visible
            if isAppearing {
                downArrowCount = 0
                showDownArrowCount = false
            }
        } else if !isAppearing {
            let currentMessages = isSearching ? filteredMessages : messages
            if index < currentMessages.count - 1 {
            // If a message above the last one disappears, increment count
            // This tracks how many messages are below the visible area
            if !isLastItemVisible {
                downArrowCount += 1
                showDownArrowCount = true
                }
            }
        }
    }
    
    // MARK: - Scroll To Bottom (matching ChattingScreen)
    private func scrollToBottom(animated: Bool) {
        let currentMessages = isSearching ? filteredMessages : messages
        guard let lastId = currentMessages.last?.id, let proxy = scrollViewProxy else {
            return
        }
        
        if animated {
            withAnimation {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            CATransaction.setAnimationDuration(0)
            proxy.scrollTo(lastId, anchor: .bottom)
            CATransaction.commit()
        }
        
        // Reset down arrow count after scrolling
        downArrowCount = 0
        showDownArrowCount = false
    }
    
    // MARK: - Handle Back Tap (matching ChattingScreen)
    private func handleBackTap() {
        // If search is active, clear it first (matching Android back button behavior)
        if showSearch {
            withAnimation {
                showSearch = false
                searchText = ""
                isSearching = false
                filteredMessages.removeAll()
            }
            return
        }
        
        // If multi-select mode is active, exit it first (matching Android back button behavior)
        if showMultiSelectHeader {
            showMultiSelectHeader = false
            selectedCount = 0
            selectedMessageIds.removeAll()
            return
        }
        
        // Otherwise, dismiss the screen
        dismiss()
    }
    
    // MARK: - Handle Search Text Changed (matching Android TextWatcher for searchEt)
    private func handleSearchTextChanged(_ newValue: String) {
        let query = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !query.isEmpty {
            // Search messages (matching Android searchMessages)
            isSearching = true
            searchMessages(query: query)
        } else {
            // Reload all messages if search is cleared (matching Android fetchMessages)
            isSearching = false
            filteredMessages.removeAll()
            let senderRoom = getSenderRoom()
            fetchMessages(senderRoom: senderRoom) {
                // Don't scroll when search is cleared (matching Android)
            }
        }
    }
    
    // MARK: - Clear Group Chat (matching Android clearChat, adapted for GROUPCHAT)
    private func clearGroupChat() {
        let groupId = group.groupId
        let senderRoom = getSenderRoom()
        let database = Database.database().reference()
        
        print("🗑️ [CLEAR GROUP CHAT] Clearing chat for group: \(groupId), room: \(senderRoom)")
        
        // Clear from Firebase (matching Android database.getReference().child(Constant.GROUPCHAT).child(senderRoom).removeValue())
        database.child(Constant.GROUPCHAT).child(senderRoom).removeValue { error, _ in
            if let error = error {
                print("🗑️ [CLEAR GROUP CHAT] 🚫 Error clearing Firebase: \(error.localizedDescription)")
                Constant.showToast(message: "Failed to clear chat")
            } else {
                print("🗑️ [CLEAR GROUP CHAT] ✅ Successfully cleared Firebase data for room: \(senderRoom)")
                
                // Delete all pending group messages from SQLite table (matching Android clearAllPendingMessages)
                // Get all pending messages and delete them one by one (since deleteAllPendingGroupMessages doesn't exist yet)
                DatabaseHelper.shared.getPendingGroupMessages(groupId: groupId) { pendingMessages in
                    for message in pendingMessages {
                        _ = DatabaseHelper.shared.removePendingGroupMessage(modelId: message.id, groupId: groupId)
                    }
                    print("🗑️ [CLEAR GROUP CHAT] ✅ Deleted all pending group messages from SQLite")
                }
                
                // Clear local messages
                DispatchQueue.main.async {
                    let pendingCount = self.messages.filter { self.messageReceiverLoaders[$0.id] == 0 }.count
                    print("🗑️ [CLEAR GROUP CHAT] Removing \(self.messages.count) messages from UI (including \(pendingCount) pending messages)")
                    self.messages.removeAll()
                    self.messageReceiverLoaders.removeAll()
                    print("🗑️ [CLEAR GROUP CHAT] ✅ Cleared local messages")
                }
                
                DispatchQueue.main.async {
                    print("🗑️ [CLEAR GROUP CHAT] ✅ Group chat cleared successfully")
                    // Toast removed - no message shown after clearing (matching user requirement)
                }
            }
        }
    }
    
    // MARK: - Search Messages (matching Android searchMessages function, adapted for GROUPCHAT)
    private func searchMessages(query: String) {
        let senderRoom = getSenderRoom()
        let database = Database.database().reference()
        let chatRef = database.child(Constant.GROUPCHAT).child(senderRoom)
        
        print("🔍 [SEARCH] Searching for: '\(query)' in group room: \(senderRoom)")
        
        // Query all messages once (matching Android addListenerForSingleValueEvent)
        chatRef.observeSingleEvent(of: .value) { snapshot in
            var foundMessages: [GroupChatMessage] = []
            
            guard snapshot.exists() else {
                print("🔍 [SEARCH] No messages found in group room")
                DispatchQueue.main.async {
                    self.filteredMessages = []
                }
                return
            }
            
            // Iterate through all messages
            for child in snapshot.children {
                guard let childSnapshot = child as? DataSnapshot else { continue }
                let childKey = childSnapshot.key
                
                // Skip typing indicator node (matching Android)
                if childKey == "typing" {
                    print("🔍 [SEARCH] Skipping typing indicator node")
                    continue
                }
                
                // Skip invalid keys (matching Android)
                if childKey.count <= 1 || childKey == ":" {
                    print("🔍 [SEARCH] Skipping invalid key: \(childKey)")
                    continue
                }
                
                // Parse message from snapshot
                guard let messageDict = childSnapshot.value as? [String: Any] else { continue }
                
                // Get message text
                if let messageText = messageDict["message"] as? String,
                   !messageText.isEmpty {
                    // Check if message contains query (case-insensitive matching Android)
                    if messageText.lowercased().contains(query.lowercased()) {
                        // Convert to GroupChatMessage using existing parser
                        do {
                            let groupMessage = try self.parseGroupMessageFromDict(messageDict, messageId: childKey)
                            foundMessages.append(groupMessage)
                        } catch {
                            print("🚫 [SEARCH] Error parsing message: \(error.localizedDescription)")
                        }
                    }
                }
            }
            
            // Update filtered messages on main thread
            DispatchQueue.main.async {
                // Sort by timestamp (newest first) - use id for sorting since GroupChatMessage doesn't have timestamp
                // Messages are sorted by key (which is chronological)
                self.filteredMessages = foundMessages.sorted { $0.id > $1.id }
                print("🔍 [SEARCH] Found \(self.filteredMessages.count) messages matching '\(query)'")
            }
        } withCancel: { error in
            print("🚫 [SEARCH] Error searching messages: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.filteredMessages = []
            }
        }
    }
}

// MARK: - Group Message Long Press Dialog (matching MessageLongPressDialog exactly, adapted for group messages)
struct GroupMessageLongPressDialog: View {
    let message: ChatMessage
    let isSentByMe: Bool
    let position: CGPoint
    let group: GroupModel
    @Binding var isPresented: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onImageTap: ((SelectionBunchModel) -> Void)? // Callback for single image tap to open ShowImageScreen
    
    @Environment(\.colorScheme) private var colorScheme
    
    // Emoji reactions state
    @State private var availableEmojis: [EmojiData] = [] // Emojis from API
    @State private var currentEmojiModels: [EmojiModel] = [] // Current reactions from Firebase
    @State private var displayEmojis: [DisplayEmoji] = [] // Combined static + Firebase emojis for display
    @State private var isLoadingEmojis: Bool = false
    @State private var showEmojiPicker: Bool = false
    @State private var emojiListenerHandle: DatabaseHandle?
    
    // Animation state for WhatsApp-style scale animation
    // Opens from exact touch point with smooth scale up, no rotation
    @State private var scaleValue: CGFloat = 0.01
    @State private var opacityValue: Double = 0.0
    @State private var backdropOpacity: Double = 0.0
    @State private var isDismissing: Bool = false
    
    // Helper function for smooth dismissal
    private func dismissDialog() {
        guard !isDismissing else { return } // Prevent multiple taps
        isDismissing = true
        animateOut()
        // Dismiss after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.15)) {
                isPresented = false
            }
            isDismissing = false
        }
    }
    
    private func animateIn() {
        scaleValue = 0.01
        opacityValue = 0.0
        backdropOpacity = 0.0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            // WhatsApp-style: fast spring scale up from touch point
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82, blendDuration: 0)) {
                scaleValue = 1.0
                opacityValue = 1.0
                backdropOpacity = 1.0
            }
        }
    }
    
    private func animateOut() {
        // WhatsApp-style: quick scale down back to touch point
        withAnimation(.easeOut(duration: 0.2)) {
            scaleValue = 0.01
            opacityValue = 0.0
            backdropOpacity = 0.0
        }
    }
    
    // Static emojis list (matching Android get_emojiChatadapter)
    private let staticEmojis: [DisplayEmoji] = [
        DisplayEmoji(slug: "e0-6-thumbs-up", character: "👍", unicodeName: "E0.6 thumbs up", codePoint: "1F44D"),
        DisplayEmoji(slug: "e0-6-red-heart", character: "❤️", unicodeName: "E0.6 red heart", codePoint: "2764 FE0F"),
        DisplayEmoji(slug: "e0-6-face-with-tears-of-joy", character: "😂", unicodeName: "E0.6 face with tears of joy", codePoint: "1F602"),
        DisplayEmoji(slug: "e0-6-face-with-open-mouth", character: "😮", unicodeName: "E0.6 face with open mouth", codePoint: "1F62E"),
        DisplayEmoji(slug: "e0-6-smiling-face-with-tear", character: "🥲", unicodeName: "E0.6 smiling face with tear", codePoint: "1F972"),
        DisplayEmoji(slug: "e0-6-folded-hands", character: "🙏", unicodeName: "E0.6 folded hands", codePoint: "1F64F"),
        DisplayEmoji(slug: "e0-6-face-blowing-a-kiss", character: "😘", unicodeName: "E0.6 face blowing a kiss", codePoint: "1F618"),
        DisplayEmoji(slug: "e0-6-smiling-face-with-hearts", character: "🥰", unicodeName: "E0.6 smiling face with hearts", codePoint: "1F970"),
        DisplayEmoji(slug: "e0-6-maple-leaf", character: "🍁", unicodeName: "E0.6 maple leaf", codePoint: "1F341"),
        DisplayEmoji(slug: "e0-6-artist-palette", character: "🎨", unicodeName: "E0.6 artist palette", codePoint: "1F3A8"),
        DisplayEmoji(slug: "e0-6-long-drum", character: "🪘", unicodeName: "E0.6 long drum", codePoint: "1FA98"),
        DisplayEmoji(slug: "e0-6-pear", character: "🍐", unicodeName: "E0.6 pear", codePoint: "1F350")
    ]
    
    // Display emoji model for combining static and Firebase emojis
    struct DisplayEmoji: Identifiable, Hashable {
        let id: String
        let slug: String
        let character: String
        let unicodeName: String
        let codePoint: String
        var isFromFirebase: Bool = false // Track if emoji came from Firebase
        
        init(slug: String, character: String, unicodeName: String, codePoint: String, isFromFirebase: Bool = false) {
            // Ensure unique ID: if slug is empty, use character; if character is also empty, use unique identifier
            if slug.isEmpty {
                if character.isEmpty {
                    self.id = "empty-emoji-placeholder"
                } else {
                    self.id = character
                }
            } else {
                if character.isEmpty {
                    self.id = "\(slug)-empty-placeholder"
                } else {
                    self.id = slug
                }
            }
            self.slug = slug
            self.character = character
            self.unicodeName = unicodeName
            self.codePoint = codePoint
            self.isFromFirebase = isFromFirebase
        }
    }
    
    // Get sender room for group messages (matching GroupChattingScreen.getSenderRoom)
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
    
    // Computed properties for text message preview
    private var messageContent: String {
        message.message
    }
    
    private var textContentType: String {
        detectTextContentType(messageContent)
    }
    
    private var emojiFontSize: CGFloat {
        if textContentType == "only_emoji" {
            let emojiCount = countEmojis(messageContent)
            if emojiCount == 1 {
                return 80 // 80sp for single emoji, no background
            } else if emojiCount == 2 {
                return 45 // 45sp for 2 emojis, no background
            } else if emojiCount == 3 {
                return 35 // 35sp for 3 emojis, no background
            } else {
                return 15 // 15sp for 4+ emojis, with background
            }
        } else {
            return 15 // Default size for text messages
        }
    }
    
    private var shouldShowBackground: Bool {
        if textContentType == "only_emoji" {
            let emojiCount = countEmojis(messageContent)
            // No background for 1-3 emojis, background for 4+ emojis
            return emojiCount >= 4
        } else {
            return true
        }
    }
    
    // Check if main message should be hidden (matching MessageBubbleView shouldHideMainMessage logic)
    private var shouldHideMainMessage: Bool {
        if let replyKey = message.replyKey, replyKey == "ReplyKey",
           let replyType = message.replyType, replyType == Constant.Text {
            return true
        }
        return false
    }
    
    // Reply layout view - matching MessageBubbleView replyLayoutView
    @ViewBuilder
    private var replyLayoutPreviewView: some View {
        // Reply layout (matching Android replylyoutGlobal) - show if replyKey == "ReplyKey"
        if let replyKey = message.replyKey, replyKey == "ReplyKey" {
            HStack {
                if isSentByMe {
                    Spacer(minLength: 0)
                }
                
                // Reply container (matching Android replylyoutGlobal)
                ReplyView(message: message, isSentByMe: isSentByMe) {
                    // No reply action for group messages
                }
                
                if !isSentByMe {
                    Spacer(minLength: 0)
                }
            }
            .padding(.bottom, 4) // Add spacing between reply and main message
        }
    }
    
    var body: some View {
            ZStack {
                // Blurred background overlay - covers entire screen and is tappable everywhere
                Color.black.opacity(0.35 * backdropOpacity)
                    .background(.ultraThinMaterial)
                    .opacity(backdropOpacity)
                    .contentShape(Rectangle()) // Make entire area tappable
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(edges: .all)
                    .zIndex(0) // Background layer
                    .onTapGesture {
                        dismissDialog()
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 20)
                            .onEnded { value in
                                if value.translation.height > 30 {
                                    dismissDialog()
                                }
                            }
                    )
            
            GeometryReader { geometry in
                
                // Dialog content positioned at exact touch location
                // Match reference file: use HStack with Spacers for X positioning, offset only for Y
                HStack(spacing: 0) {
                    // For sender (end gravity): add spacer at start to push content to right
                    // For receiver (start gravity): no spacer - content aligns to left
                    if isSentByMe {
                        Spacer()
                    }
                    
                    VStack(alignment: isSentByMe ? .trailing : .leading, spacing: 0) {
                        ScrollView {
                            VStack(alignment: isSentByMe ? .trailing : .leading, spacing: 0) {
                                // Emoji reactions card (matching Android emojiCard)
                                emojiReactionsView
                            
                                // Message preview section (matching Android MainSenderBox/MainReceiverBox)
                                // Use exact same styling as MessageBubbleView for text messages
                                if message.dataType == Constant.Text {
                                    // Match MessageBubbleView structure: HStack with Spacer for end gravity
                                    HStack(spacing: 0) {
                                        if isSentByMe {
                                            Spacer() // Push to end (right side gravity)
                                        }
                                        textMessagePreviewView
                                            .padding(.trailing, isSentByMe ? 0 : 0) // No outer side spacing for preview
                                            .padding(.leading, isSentByMe ? 0 : 0)
                                            .padding(.vertical, 10) // Vertical spacing for preview bubble
                                        if !isSentByMe {
                                            Spacer(minLength: 0) // Keep on left for receiver
                                        }
                                    }
                                } else if message.dataType == Constant.img && !message.document.isEmpty {
                                    // Image message preview - matching MessageBubbleView exact styling
                                    imageMessagePreviewView
                                } else if message.dataType == Constant.video && !message.document.isEmpty {
                                    // Video message preview - matching MessageBubbleView exact styling
                                    videoMessagePreviewView
                                } else if message.dataType == Constant.doc {
                                    // Document message preview - matching MessageBubbleView exact styling
                                    documentMessagePreviewView
                                } else if message.dataType == Constant.contact {
                                    // Contact message preview - matching MessageBubbleView exact styling
                                    contactMessagePreviewView
                                } else if message.dataType == Constant.voiceAudio {
                                    // Voice audio message preview - matching MessageBubbleView exact styling
                                    voiceAudioMessagePreviewView
                                } else {
                                    // For other non-text messages, show simplified preview
                                    VStack(alignment: isSentByMe ? .trailing : .leading, spacing: 0) {
                                        if let replyKey = message.replyKey, replyKey == "ReplyKey" {
                                            ReplyView(message: message, isSentByMe: isSentByMe) {
                                                // No reply action for group messages
                                            }
                                            .padding(.horizontal, 12)
                                        } else {
                                            Text(getMessagePreviewText())
                                                .font(.custom("Inter18pt-Regular", size: 13))
                                                .foregroundColor(isSentByMe ? Color(hex: "#e7ebf4") : Color("TextColor"))
                                                .padding(.horizontal, 12)
                                                .padding(.top, 5)
                                                .padding(.bottom, 6)
                                        }
                                        
                                        // Time row with progress indicator for preview
                                        timeRowPreviewView
                                    }
                                    .frame(maxWidth: 220)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(isSentByMe ? getSenderMessageBackgroundColor(colorScheme: colorScheme) : getReceiverMessageBackgroundColor())
                                    )
                                    .padding(.trailing, isSentByMe ? 0 : 0)
                                    .padding(.leading, isSentByMe ? 0 : 0)
                                    .padding(.vertical, 10)
                                }
                            
                                // Action buttons card (matching Android cardview exactly)
                                // CardView: width=220dp, cornerRadius=20dp, elevation=5dp, marginEnd=16dp, marginTop=2dp, marginBottom=20dp
                                VStack(spacing: 0) {
                                    // Copy button (matching Android copy)
                                    // Only show for Text datatype messages
                                    if message.dataType == Constant.Text {
                                        Button(action: {
                                            // Haptic feedback (matching Android Constant.Vibrator)
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            onCopy()
                                        }) {
                                            HStack(spacing: 0) {
                                                // TextView: weight=1, marginStart=15dp, lineHeight=24dp
                                                Text("Copy")
                                                    .font(.custom("Inter18pt-Regular", size: 16))
                                                    .fontWeight(.bold)
                                                    .foregroundColor(Color("TextColor"))
                                                    .lineSpacing(0) // lineHeight="24dp"
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .padding(.leading, 15)
                                                
                                                // ImageView container: weight=4, size=23x23dp (matching Android exactly)
                                                HStack {
                                                    Spacer()
                                                    Image("copy_svg")
                                                        .renderingMode(.template)
                                                        .resizable()
                                                        .scaledToFit()
                                                        .frame(width: 23, height: 23) // Exact Android size: 23dp x 23dp
                                                        .foregroundColor(Color("gray3")) // app:tint="@color/gray3"
                                                        .padding(.trailing, 15) // Right edge margin to match Android layout
                                                }
                                                .frame(maxWidth: .infinity)
                                            }
                                            .frame(minHeight: 36) // Reduced height for tighter spacing
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.top, 6) // Reduced vertical padding
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                    
                                    // Divider: height=1dp, marginTop=6dp, invisible (reduced spacing)
                                    Rectangle()
                                        .fill(Color("gray2"))
                                        .frame(height: 1)
                                        .padding(.top, 6)
                                        .opacity(0) // invisible
                                    
                                    // Delete button (matching Android deletelyt)
                                    // paddingTop=10dp, marginStart=15dp, icon size=26.05x24dp, marginStart=3dp
                                    Button(action: {
                                        // Haptic feedback (matching Android Constant.Vibrator)
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        onDelete()
                                    }) {
                                        HStack(spacing: 0) {
                                            // TextView: weight=1, marginStart=15dp, lineHeight=24dp
                                            Text("Delete")
                                                .font(.custom("Inter18pt-Regular", size: 16))
                                                .fontWeight(.bold)
                                                .foregroundColor(Color("TextColor"))
                                                .lineLimit(1)
                                                .lineSpacing(0) // lineHeight="24dp"
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.leading, 15)
                                            
                                            // ImageView container: weight=4, size=26.05x24dp (matching Android exactly)
                                            HStack {
                                                Spacer()
                                                Image("baseline_delete_forever_24")
                                                    .renderingMode(.template)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 26.05, height: 24) // Exact Android size: 26.05dp x 24dp
                                                    .foregroundColor(Color("gray3")) // app:tint="@color/gray3"
                                                    .padding(.trailing, 15) // Right edge margin to match Android layout
                                            }
                                            .frame(maxWidth: .infinity)
                                        }
                                        .frame(minHeight: 36) // Reduced height for tighter spacing
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.top, 6) // Reduced vertical padding
                                    }
                                    .buttonStyle(DialogButtonStyle())
                                    
                                    // Divider: height=0.5dp, marginTop=6dp, invisible (reduced spacing)
                                    Rectangle()
                                        .fill(Color("gray2"))
                                        .frame(height: 0.5)
                                        .padding(.top, 6)
                                        .opacity(0) // invisible
                                }
                                .frame(width: 220) // layout_width="220dp"
                                .background(
                                    RoundedRectangle(cornerRadius: 20) // cardCornerRadius="20dp"
                                        .fill(Color("cardBackgroundColornew")) // style="@style/cardBackgroundColor"
                                        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2) // cardElevation="5dp"
                                )
                                .padding(.trailing, isSentByMe ? 0 : 0) // No outer side spacing for action card
                                .padding(.leading, isSentByMe ? 0 : 0)
                                .padding(.top, 5) // 3rd container top margin: 5px
                                .padding(.bottom, 20) // layout_marginBottom="20dp"
                            }
                        }
                        .frame(width: min(geometry.size.width - 20, 380))
                        .frame(maxHeight: geometry.size.height - 40)
                        .allowsHitTesting(true) // Allow touches on ScrollView content
                        // WhatsApp-style: pure scale from touch point, no rotation
                        .scaleEffect(scaleValue, anchor: isSentByMe ? .topTrailing : .topLeading)
                        .opacity(opacityValue)
                    }
                    
                    // For receiver (start gravity): add spacer at end
                    // For sender (end gravity): no spacer - content aligns to right
                    if !isSentByMe {
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity)
                // 10px margin on both sides for clean edge spacing
                .padding(.horizontal, 10)
            .offset(x: 0, y: adjustedOffsetY(in: geometry))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure GeometryReader fills entire ZStack
            .zIndex(1) // Dialog content on top of blur
            .background(Color.clear.contentShape(Rectangle()).allowsHitTesting(false)) // Don't block touches in empty areas
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: .all)
        .onAppear {
            animateIn()
        }
        .onChange(of: isPresented) { newValue in
            if !newValue && !isDismissing {
                // Animate dialog dismissal - reverse the unfold animation with spring for smoother feel
                // Only animate if not already dismissing (prevents double animation)
                isDismissing = true
                animateOut()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    isDismissing = false
                }
            } else if newValue {
                // Reset dismissing flag when presenting
                isDismissing = false
                animateIn()
            }
        }
    }
    
    // Calculate adjusted offset Y - position dialog at exact touch location within safe bounds
    private func adjustedOffsetY(in geometry: GeometryProxy) -> CGFloat {
        let safeBottom = geometry.safeAreaInsets.bottom
        let screenH = geometry.size.height
        let emojiCardHeight: CGFloat = 60
        let minPad: CGFloat = 10
        
        // Fallback: center vertically
        guard position.y > 0 else {
            let centeredY = screenH * 0.15
            print("🟣 [GroupMessageLongPressDialog] Invalid position, centering at Y: \(centeredY)")
            return centeredY
        }
        
        let frame = geometry.frame(in: .global)
        let localY = position.y - frame.minY
        
        // Estimate actual dialog height based on message type
        let messagePreviewHeight: CGFloat = estimateMessagePreviewHeight()
        let actionButtonsHeight: CGFloat = 160  // Reply + Copy + Delete (group has fewer options)
        let totalDialogHeight = emojiCardHeight + messagePreviewHeight + actionButtonsHeight
        
        // Place emoji card above the touch point so message preview aligns with the pressed message
        let dialogTopY = localY - emojiCardHeight
        
        // Clamp within safe area bounds (ensure bottom options stay within screen)
        let minY = minPad
        let maxY = screenH - totalDialogHeight - minPad - safeBottom
        let clampedY = min(max(dialogTopY, minY), max(maxY, minY))
        
        print("🟣 [GroupMessageLongPressDialog] Touch Y: \(position.y), Local Y: \(localY), Dialog Height: \(totalDialogHeight), Clamped Y: \(clampedY), isSentByMe: \(isSentByMe)")
        return clampedY
    }
    
    // Estimate message preview height based on message type
    private func estimateMessagePreviewHeight() -> CGFloat {
        var height: CGFloat = 100  // Base height for text messages
        
        if message.dataType == Constant.img && !message.document.isEmpty {
            height = 200  // Image preview
        } else if message.dataType == Constant.video && !message.document.isEmpty {
            height = 200  // Video preview
        } else if message.dataType == Constant.doc {
            height = 100  // Document preview
        } else if message.dataType == Constant.contact {
            height = 80   // Contact preview
        } else if message.dataType == Constant.voiceAudio {
            height = 80   // Voice audio preview
        }
        
        // Add extra height for reply layout if present
        if message.replyKey == "ReplyKey" {
            height += 40
        }
        
        return height
    }
    
    // MARK: - Message Preview Views
    
    // Text message preview view - matching MessageBubbleView exact styling
    @ViewBuilder
    private var textMessagePreviewView: some View {
        VStack(alignment: isSentByMe ? .trailing : .leading, spacing: 0) {
            // Show reply layout if present (matching MessageBubbleView structure)
            replyLayoutPreviewView
            
            // Main message content - hide if this is a reply message with text replyType
            if !shouldHideMainMessage {
                // Check if message contains a URL
                if let url = messageContent.extractURL(), url.isValidURL() {
                    // Show rich link preview
                    HStack {
                        if isSentByMe {
                            Spacer(minLength: 0)
                            SenderRichLinkView(
                                url: url,
                                backgroundColor: getSenderMessageBackgroundColor(colorScheme: colorScheme),
                                linkTitle: message.linkTitle,
                                linkDescription: message.linkDescription,
                                linkImageUrl: message.linkImageUrl,
                                favIconUrl: message.favIconUrl
                            )
                        } else {
                            ReceiverRichLinkView(
                                url: url,
                                linkTitle: message.linkTitle,
                                linkDescription: message.linkDescription,
                                linkImageUrl: message.linkImageUrl,
                                favIconUrl: message.favIconUrl
                            )
                            Spacer(minLength: 0)
                        }
                    }
                    .frame(maxWidth: 250)
                } else {
                    // Regular text message (no URL)
                    Group {
                        if textContentType == "only_emoji" {
                            if shouldShowBackground {
                                if isSentByMe {
                                    Text(messageContent)
                                        .font(.custom("Inter18pt-Regular", size: emojiFontSize))
                                        .fontWeight(.light)
                                        .foregroundColor(Color(hex: "#e7ebf4"))
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(.horizontal, 12)
                                        .padding(.top, 5)
                                        .padding(.bottom, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(getSenderMessageBackgroundColor(colorScheme: colorScheme))
                                        )
                                } else {
                                    Text(messageContent)
                                        .font(.custom("Inter18pt-Regular", size: emojiFontSize))
                                        .fontWeight(.light)
                                        .foregroundColor(Color("TextColor"))
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(.horizontal, 12)
                                        .padding(.top, 5)
                                        .padding(.bottom, 6)
                                        .background(getReceiverGlassBackground(cornerRadius: 12))
                                }
                            } else {
                                Text(messageContent)
                                    .font(.custom("Inter18pt-Regular", size: emojiFontSize))
                                    .fontWeight(.light)
                                    .foregroundColor(isSentByMe ? Color(hex: "#e7ebf4") : Color("TextColor"))
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        } else {
                            if isSentByMe {
                                Text(messageContent)
                                    .font(.custom("Inter18pt-Regular", size: 15))
                                    .fontWeight(.light)
                                    .foregroundColor(Color(hex: "#e7ebf4"))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .padding(.horizontal, 12)
                                    .padding(.top, 5)
                                    .padding(.bottom, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(getSenderMessageBackgroundColor(colorScheme: colorScheme))
                                    )
                            } else {
                                Text(messageContent)
                                    .font(.custom("Inter18pt-Regular", size: 15))
                                    .fontWeight(.light)
                                    .foregroundColor(Color("TextColor"))
                                    .lineSpacing(7)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.horizontal, 12)
                                    .padding(.top, 5)
                                    .padding(.bottom, 6)
                                    .background(getReceiverGlassBackground(cornerRadius: 20))
                            }
                        }
                    }
                    .frame(maxWidth: 250, alignment: isSentByMe ? .trailing : .leading)
                }
            }
            
            // Time row with progress indicator
            timeRowPreviewView
        }
    }
    
    // Time row preview view
    @ViewBuilder
    private var timeRowPreviewView: some View {
        HStack(spacing: 6) {
            if isSentByMe {
                progressIndicatorPreviewView(isSender: true)
                Text(message.time)
                    .font(.custom("Inter18pt-Regular", size: 10))
                    .foregroundColor(Color("gray3"))
            } else {
                Text(message.time)
                    .font(.custom("Inter18pt-Regular", size: 10))
                    .foregroundColor(Color("gray3"))
                progressIndicatorPreviewView(isSender: false)
            }
        }
        .padding(.top, 5)
        .padding(.bottom, 7)
        .frame(maxWidth: .infinity, alignment: isSentByMe ? .trailing : .leading)
    }
    
    // Progress indicator preview view
    @ViewBuilder
    private func progressIndicatorPreviewView(isSender: Bool) -> some View {
        let themeColor = Color(hex: Constant.themeColor)
        let indicatorColor = isSender ? themeColor : Color("line")
        let trackColor = isSender ? themeColor : Color("line")
        let cornerRadius: CGFloat = isSender ? 20 : 10
        
        return ZStack(alignment: .leading) {
            Capsule()
                .fill(trackColor)
                .frame(width: 20, height: 1)
            Capsule()
                .fill(indicatorColor)
                .frame(width: 20, height: 1)
        }
        .frame(width: 20, height: 1)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
    
    // Image message preview view
    @ViewBuilder
    private var imageMessagePreviewView: some View {
        VStack(alignment: isSentByMe ? .trailing : .leading, spacing: 0) {
            replyLayoutPreviewView
            
            if !shouldHideMainMessage {
                if isSentByMe {
                    HStack {
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 0) {
                            DynamicImageView(
                                imageUrl: message.document,
                                fileName: message.fileName,
                                imageWidth: message.imageWidth,
                                imageHeight: message.imageHeight,
                                aspectRatio: message.aspectRatio,
                                backgroundColor: getSenderMessageBackgroundColor(colorScheme: colorScheme),
                                onTap: {
                                    onImageTap?(SelectionBunchModel(
                                        imgUrl: message.document,
                                        fileName: message.fileName ?? ""
                                    ))
                                }
                            )
                            
                            if let caption = message.caption, !caption.isEmpty {
                                HStack {
                                    Text(caption)
                                        .font(.custom("Inter18pt-Regular", size: 15))
                                        .fontWeight(.regular)
                                        .foregroundColor(Color(hex: "#e7ebf4"))
                                        .lineSpacing(7)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .padding(.top, 5)
                                        .padding(.bottom, 6)
                                    Spacer(minLength: 0)
                                }
                                .padding(.top, 5)
                                .padding(.bottom, 5)
                            }
                        }
                        .frame(width: calculateImageSize(imageWidth: message.imageWidth, imageHeight: message.imageHeight, aspectRatio: message.aspectRatio).width)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(getSenderMessageBackgroundColor(colorScheme: colorScheme))
                        )
                    }
                    .frame(maxWidth: 250)
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 0) {
                            ReceiverDynamicImageView(
                                imageUrl: message.document,
                                fileName: message.fileName,
                                imageWidth: message.imageWidth,
                                imageHeight: message.imageHeight,
                                aspectRatio: message.aspectRatio,
                                onTap: {
                                    onImageTap?(SelectionBunchModel(
                                        imgUrl: message.document,
                                        fileName: message.fileName ?? ""
                                    ))
                                }
                            )
                            
                            if let caption = message.caption, !caption.isEmpty {
                                HStack {
                                    Text(caption)
                                        .font(.custom("Inter18pt-Regular", size: 15))
                                        .fontWeight(.regular)
                                        .foregroundColor(Color("TextColor"))
                                        .lineSpacing(7)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .padding(.top, 5)
                                        .padding(.bottom, 6)
                                    Spacer(minLength: 0)
                                }
                                .padding(.top, 5)
                                .padding(.bottom, 5)
                            }
                        }
                        .frame(width: calculateImageSize(imageWidth: message.imageWidth, imageHeight: message.imageHeight, aspectRatio: message.aspectRatio).width)
                        .background(getReceiverGlassBackground(cornerRadius: 12))
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: 250)
                }
            }
            
            // Time row with progress indicator for preview
            timeRowPreviewView
        }
        .padding(.horizontal, isSentByMe ? 16 : 12)
        .padding(.top, 2)
        .padding(.bottom, 2)
    }
    
    // Video message preview view - matching MessageBubbleView exact styling
    @ViewBuilder
    private var videoMessagePreviewView: some View {
        VStack(alignment: isSentByMe ? .trailing : .leading, spacing: 0) {
            // Show reply layout if present (matching MessageBubbleView structure)
            replyLayoutPreviewView
            
            // Main video content - hide if this is a reply message
            if !shouldHideMainMessage {
                if isSentByMe {
                    // Sender video message (matching Android sendervideoLyt design)
                    HStack {
                        Spacer(minLength: 0) // Push content to end
                        
                        // Container wrapping video and caption with same background as Constant.Text sender messages
                        VStack(alignment: .trailing, spacing: 0) {
                            SenderVideoView(
                                videoUrl: message.document,
                                thumbnailUrl: message.thumbnail,
                                fileName: message.fileName,
                                imageWidth: message.imageWidth,
                                imageHeight: message.imageHeight,
                                aspectRatio: message.aspectRatio,
                                backgroundColor: getSenderMessageBackgroundColor(colorScheme: colorScheme)
                            )
                            
                            // Caption text if present (matching Android caption display)
                            if let caption = message.caption, !caption.isEmpty {
                                HStack {
                                    Text(caption)
                                        .font(.custom("Inter18pt-Regular", size: 15))
                                        .fontWeight(.regular)
                                        .foregroundColor(Color(hex: "#e7ebf4"))
                                        .lineSpacing(7)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .padding(.top, 5)
                                        .padding(.bottom, 6)
                                    Spacer(minLength: 0)
                                }
                                .padding(.top, 5)
                                .padding(.bottom, 5)
                            }
                        }
                        .frame(width: calculateImageSize(imageWidth: message.imageWidth, imageHeight: message.imageHeight, aspectRatio: message.aspectRatio).width) // Container width matches video width exactly
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(getSenderMessageBackgroundColor(colorScheme: colorScheme))
                        )
                    }
                    .frame(maxWidth: 250)
                } else {
                    // Receiver video message (matching Android receivervideoLyt design)
                    HStack {
                        // Container wrapping video and caption with same background as Constant.Text receiver messages
                        VStack(alignment: .leading, spacing: 0) {
                            ReceiverVideoView(
                                videoUrl: message.document,
                                thumbnailUrl: message.thumbnail,
                                fileName: message.fileName,
                                imageWidth: message.imageWidth,
                                imageHeight: message.imageHeight,
                                aspectRatio: message.aspectRatio
                            )
                            
                            // Caption text if present (matching Android caption display)
                            if let caption = message.caption, !caption.isEmpty {
                                HStack {
                                    Text(caption)
                                        .font(.custom("Inter18pt-Regular", size: 15))
                                        .fontWeight(.regular)
                                        .foregroundColor(Color("TextColor"))
                                        .lineSpacing(7)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .padding(.top, 5)
                                        .padding(.bottom, 6)
                                    Spacer(minLength: 0)
                                }
                                .padding(.top, 5)
                                .padding(.bottom, 5)
                            }
                        }
                        .frame(width: calculateImageSize(imageWidth: message.imageWidth, imageHeight: message.imageHeight, aspectRatio: message.aspectRatio).width) // Container width matches video width exactly
                        .background(
                            getReceiverGlassBackground(cornerRadius: 12)
                        )
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: 250)
                }
            }
            
            // Time row with progress indicator for preview
            timeRowPreviewView
        }
        .padding(.horizontal, isSentByMe ? 16 : 12)
        .padding(.vertical, 10)
    }
    
    // Document message preview view - matching MessageBubbleView exact styling
    @ViewBuilder
    private var documentMessagePreviewView: some View {
        VStack(alignment: isSentByMe ? .trailing : .leading, spacing: 0) {
            // Show reply layout if present (matching MessageBubbleView structure)
            replyLayoutPreviewView
            
            // Main document content - hide if this is a reply message
            if !shouldHideMainMessage {
                if isSentByMe {
                    // Sender document message (matching Android docLyt design)
                    HStack {
                        Spacer(minLength: 0) // Push content to end
                        
                        // Container wrapping document and caption with same background as Constant.Text sender messages
                        VStack(alignment: .trailing, spacing: 0) {
                            SenderDocumentView(
                                documentUrl: message.document.isEmpty ? (message.fileName ?? "") : message.document,
                                fileName: message.fileName ?? message.message,
                                docSize: message.docSize,
                                fileExtension: message.fileExtension,
                                backgroundColor: getSenderMessageBackgroundColor(colorScheme: colorScheme),
                                micPhoto: message.micPhoto
                            )
                            
                            // Caption text if present (matching Android caption display)
                            if let caption = message.caption, !caption.isEmpty {
                                HStack {
                                    Text(caption)
                                        .font(.custom("Inter18pt-Regular", size: 15))
                                        .fontWeight(.regular)
                                        .foregroundColor(Color(hex: "#e7ebf4"))
                                        .lineSpacing(7)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .padding(.top, 5)
                                        .padding(.bottom, 6)
                                    Spacer(minLength: 0)
                                }
                                .padding(.top, 5)
                                .padding(.bottom, 5)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(getSenderMessageBackgroundColor(colorScheme: colorScheme))
                        )
                    }
                    .frame(maxWidth: 250)
                } else {
                    // Receiver document message (matching Android docLyt design)
                    HStack {
                        // Container wrapping document and caption with same background as Constant.Text receiver messages
                        VStack(alignment: .leading, spacing: 0) {
                            ReceiverDocumentView(
                                documentUrl: message.document.isEmpty ? (message.fileName ?? "") : message.document,
                                fileName: message.fileName ?? message.message,
                                docSize: message.docSize,
                                fileExtension: message.fileExtension,
                                micPhoto: message.micPhoto
                            )
                            
                            // Caption text if present (matching Android caption display)
                            if let caption = message.caption, !caption.isEmpty {
                                HStack {
                                    Text(caption)
                                        .font(.custom("Inter18pt-Regular", size: 15))
                                        .fontWeight(.regular)
                                        .foregroundColor(Color("TextColor"))
                                        .lineSpacing(7)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .padding(.top, 5)
                                        .padding(.bottom, 6)
                                    Spacer(minLength: 0)
                                }
                                .padding(.top, 5)
                                .padding(.bottom, 5)
                            }
                        }
                        .background(
                            getReceiverGlassBackground(cornerRadius: 20) // Changed to 20dp to match Android
                        )
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: 250)
                }
            }
            
            // Time row with progress indicator for preview
            timeRowPreviewView
        }
        .padding(.horizontal, isSentByMe ? 16 : 12)
        .padding(.vertical, 10)
    }
    
    // Contact message preview view - matching MessageBubbleView exact styling
    @ViewBuilder
    private var contactMessagePreviewView: some View {
        VStack(alignment: isSentByMe ? .trailing : .leading, spacing: 0) {
            // Show reply layout if present (matching MessageBubbleView structure)
            replyLayoutPreviewView
            
            // Main contact content - hide if this is a reply message
            if !shouldHideMainMessage {
                if isSentByMe {
                    // Sender contact message (matching Android contactContainer design)
                    HStack {
                        Spacer(minLength: 0) // Push content to end
                        
                        // Container wrapping contact and caption with same background as Constant.Text sender messages
                        VStack(alignment: .trailing, spacing: 0) {
                            SenderContactView(
                                contactName: message.name ?? "",
                                contactPhone: message.phone ?? "",
                                backgroundColor: getSenderMessageBackgroundColor(colorScheme: colorScheme),
                                contactDocumentUrl: message.document.isEmpty ? nil : message.document
                            )
                            
                            // Caption text if present (matching Android caption display)
                            if let caption = message.caption, !caption.isEmpty {
                                HStack {
                                    Text(caption)
                                        .font(.custom("Inter18pt-Regular", size: 15))
                                        .fontWeight(.regular)
                                        .foregroundColor(Color(hex: "#e7ebf4"))
                                        .lineSpacing(7)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .padding(.top, 5)
                                        .padding(.bottom, 6)
                                    Spacer(minLength: 0)
                                }
                                .padding(.top, 5)
                                .padding(.bottom, 5)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(getSenderMessageBackgroundColor(colorScheme: colorScheme))
                        )
                    }
                    .frame(maxWidth: 250)
                } else {
                    // Receiver contact message (matching Android contactContainer design)
                    HStack {
                        // Container wrapping contact and caption with same background as Constant.Text receiver messages
                        VStack(alignment: .leading, spacing: 0) {
                            ReceiverContactView(
                                contactName: message.name ?? "",
                                contactPhone: message.phone ?? "",
                                contactDocumentUrl: message.document.isEmpty ? nil : message.document
                            )
                            
                            // Caption text if present (matching Android caption display)
                            if let caption = message.caption, !caption.isEmpty {
                                HStack {
                                    Text(caption)
                                        .font(.custom("Inter18pt-Regular", size: 15))
                                        .fontWeight(.regular)
                                        .foregroundColor(Color("TextColor"))
                                        .lineSpacing(7)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .padding(.top, 5)
                                        .padding(.bottom, 6)
                                    Spacer(minLength: 0)
                                }
                                .padding(.top, 5)
                                .padding(.bottom, 5)
                            }
                        }
                        .background(
                            getReceiverGlassBackground(cornerRadius: 20) // Android: contactContainer should match message container corner radius
                        )
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: 250)
                }
            }
            
            // Time row with progress indicator for preview
            timeRowPreviewView
        }
        .padding(.horizontal, isSentByMe ? 16 : 12)
        .padding(.vertical, 10)
    }
    
    // Voice audio message preview view - matching MessageBubbleView exact styling
    @ViewBuilder
    private var voiceAudioMessagePreviewView: some View {
        VStack(alignment: isSentByMe ? .trailing : .leading, spacing: 0) {
            // Show reply layout if present (matching MessageBubbleView structure)
            replyLayoutPreviewView
            
            // Main voice audio content - hide if this is a reply message
            if !shouldHideMainMessage {
                if isSentByMe {
                    // Sender voice audio message (matching Android miceContainer design)
                    HStack {
                        Spacer(minLength: 0) // Push content to end
                        
                        // Container wrapping voice audio and caption with same background as Constant.Text sender messages
                        VStack(alignment: .trailing, spacing: 0) {
                            SenderVoiceAudioView(
                                audioUrl: message.document,
                                audioTiming: message.miceTiming ?? "00:00",
                                micPhoto: message.micPhoto,
                                backgroundColor: getSenderMessageBackgroundColor(colorScheme: colorScheme)
                            )
                            
                            // Caption text if present (matching Android caption display)
                            if let caption = message.caption, !caption.isEmpty {
                                HStack {
                                    Text(caption)
                                        .font(.custom("Inter18pt-Regular", size: 15))
                                        .fontWeight(.regular)
                                        .foregroundColor(Color(hex: "#e7ebf4"))
                                        .lineSpacing(7)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .padding(.top, 5)
                                        .padding(.bottom, 6)
                                    Spacer(minLength: 0)
                                }
                                .padding(.top, 5)
                                .padding(.bottom, 5)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(getSenderMessageBackgroundColor(colorScheme: colorScheme))
                        )
                    }
                    .frame(maxWidth: 250)
                } else {
                    // Receiver voice audio message (matching Android miceContainer design)
                    HStack {
                        // Container wrapping voice audio and caption with same background as Constant.Text receiver messages
                        VStack(alignment: .leading, spacing: 0) {
                            ReceiverVoiceAudioView(
                                audioUrl: message.document,
                                audioTiming: message.miceTiming ?? "00:00",
                                micPhoto: message.micPhoto
                            )
                            
                            // Caption text if present (matching Android caption display)
                            if let caption = message.caption, !caption.isEmpty {
                                HStack {
                                    Text(caption)
                                        .font(.custom("Inter18pt-Regular", size: 15))
                                        .fontWeight(.regular)
                                        .foregroundColor(Color("TextColor"))
                                        .lineSpacing(7)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .padding(.top, 5)
                                        .padding(.bottom, 6)
                                    Spacer(minLength: 0)
                                }
                                .padding(.top, 5)
                                .padding(.bottom, 5)
                            }
                        }
                        .background(
                            getReceiverGlassBackground(cornerRadius: 20)
                        )
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: 250)
                }
            }
            
            // Time row with progress indicator for preview
            timeRowPreviewView
        }
        .padding(.horizontal, isSentByMe ? 16 : 12)
        .padding(.vertical, 10)
    }
    
    // MARK: - Emoji Reactions View
    
    private var emojiReactionsView: some View {
        ZStack(alignment: .center) {
            HStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(displayEmojis.isEmpty ? staticEmojis : displayEmojis) { displayEmoji in
                            if !displayEmoji.character.isEmpty {
                                emojiReactionButton(displayEmoji: displayEmoji)
                            }
                        }
                    }
                }
                .padding(.trailing, 15)
                Spacer()
            }
            .padding(5)
            
            HStack {
                Spacer()
                rightGradientBars
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showEmojiPicker = true
                    fetchAvailableEmojis()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color("gray3"))
                        .frame(width: 40, height: 40)
                }
                .padding(.trailing, 5)
            }
            
            HStack {
                leftGradientBars
                Spacer()
            }
        }
        .frame(width: 305)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color("cardBackgroundColornew"))
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.trailing, isSentByMe ? 0 : 0)
        .padding(.leading, isSentByMe ? 0 : 0)
        .padding(.vertical, 10)
        .onAppear {
            displayEmojis = staticEmojis
            setupEmojiListener()
            fetchAvailableEmojis()
        }
        .onDisappear {
            removeEmojiListener()
        }
        .sheet(isPresented: $showEmojiPicker) {
            emojiPickerSheet
        }
    }
    
    @ViewBuilder
    private var leftGradientBars: some View {
        // Empty for now (matching ChattingScreen)
    }
    
    @ViewBuilder
    private var rightGradientBars: some View {
        // Empty for now (matching ChattingScreen)
    }
    
    @ViewBuilder
    private func gradientBar(alpha: Double) -> some View {
        Rectangle()
            .fill(Color("cardBackgroundColornew"))
            .opacity(alpha)
            .frame(width: 4, height: 40)
    }
    
    @ViewBuilder
    private func emojiReactionButton(displayEmoji: DisplayEmoji) -> some View {
        let currentUserId = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        let userReaction = currentEmojiModels.first { $0.name == currentUserId && $0.emoji == displayEmoji.character }
        let isUserReaction = userReaction != nil
        
        let containerSize: CGFloat = displayEmoji.unicodeName.isEmpty ? 25 : 40
        let textSize: CGFloat = 25
        
        Button(action: {
            handleEmojiTap(displayEmoji: displayEmoji)
        }) {
            Text(displayEmoji.character)
                .font(.system(size: textSize))
                .frame(width: containerSize, height: nil)
                .frame(minHeight: containerSize)
                .background(
                    Circle()
                        .fill(isUserReaction ? Color(hex: "#00A3E9").opacity(0.3) : Color.clear)
                )
        }
        .padding(.horizontal, 2)
    }
    
    // MARK: - Helper Functions
    
    private func getSenderMessageBackgroundColor(colorScheme: ColorScheme) -> Color {
        guard colorScheme == .dark else {
            return Color(hex: "#011224")
        }
        
        let themeColor = Constant.themeColor
        let colorKey = themeColor.lowercased()
        
        switch colorKey {
        case "#ff0080": return Color(hex: "#4D0026")
        case "#00a3e9": return Color(hex: "#01253B")
        case "#7adf2a": return Color(hex: "#25430D")
        case "#ec0001": return Color(hex: "#470000")
        case "#16f3ff": return Color(hex: "#05495D")
        case "#ff8a00": return Color(hex: "#663700")
        case "#7f7f7f": return Color(hex: "#2B3137")
        case "#d9b845": return Color(hex: "#413815")
        case "#346667": return Color(hex: "#1F3D3E")
        case "#9846d9": return Color(hex: "#2d1541")
        case "#a81010": return Color(hex: "#430706")
        default: return Color(hex: "#01253B")
        }
    }
    
    private func getReceiverMessageBackgroundColor() -> Color {
        return Color("cardBackgroundColornew")
    }
    
    @ViewBuilder
    private func getReceiverGlassBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        getReceiverGlassBgStart(),
                        getReceiverGlassBgCenter(),
                        getReceiverGlassBgEnd()
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(getReceiverGlassBorder(), lineWidth: 0.5)
            )
    }
    
    private func getReceiverGlassBgStart() -> Color {
        Color("cardBackgroundColornew").opacity(0.9)
    }
    
    private func getReceiverGlassBgCenter() -> Color {
        Color("cardBackgroundColornew").opacity(0.7)
    }
    
    private func getReceiverGlassBgEnd() -> Color {
        Color("cardBackgroundColornew").opacity(0.9)
    }
    
    private func getReceiverGlassBorder() -> Color {
        Color.gray.opacity(0.2)
    }
    
    private func calculateImageSize(imageWidth: String?, imageHeight: String?, aspectRatio: String?) -> CGSize {
        var imageWidthPx: CGFloat = 300
        var imageHeightPx: CGFloat = 300
        var aspectRatioValue: CGFloat = 1.0
        
        if let widthStr = imageWidth, !widthStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let width = Float(widthStr) {
                imageWidthPx = CGFloat(width)
            }
        }
        
        if let heightStr = imageHeight, !heightStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let height = Float(heightStr) {
                imageHeightPx = CGFloat(height)
            }
        }
        
        if let ratioStr = aspectRatio, !ratioStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let ratio = Float(ratioStr), ratio > 0 {
                aspectRatioValue = CGFloat(ratio)
            } else {
                if imageHeightPx > 0 {
                    aspectRatioValue = imageWidthPx / imageHeightPx
                }
            }
        } else {
            if imageHeightPx > 0 {
                aspectRatioValue = imageWidthPx / imageHeightPx
            }
        }
        
        let MAX_WIDTH_PT: CGFloat = 210
        let MAX_HEIGHT_PT: CGFloat = 250
        let scale = UIScreen.main.scale
        var maxWidthPx = MAX_WIDTH_PT * scale
        var maxHeightPx = MAX_HEIGHT_PT * scale
        
        maxWidthPx = min(maxWidthPx, 600)
        maxHeightPx = min(maxHeightPx, 600)
        
        var finalWidthPx: CGFloat = 0
        var finalHeightPx: CGFloat = 0
        
        let orientation = UIDevice.current.orientation
        let isLandscape = orientation.isLandscape || (UIScreen.main.bounds.width > UIScreen.main.bounds.height)
        
        if isLandscape {
            finalWidthPx = maxWidthPx
            finalHeightPx = maxWidthPx / aspectRatioValue
            if finalHeightPx > maxHeightPx {
                finalHeightPx = maxHeightPx
                finalWidthPx = maxHeightPx * aspectRatioValue
            }
        } else {
            finalHeightPx = maxHeightPx
            finalWidthPx = maxHeightPx * aspectRatioValue
            if finalWidthPx > maxWidthPx {
                finalWidthPx = maxWidthPx
                finalHeightPx = maxWidthPx / aspectRatioValue
            }
        }
        
        finalWidthPx = min(finalWidthPx, maxWidthPx)
        finalHeightPx = min(finalHeightPx, maxHeightPx)
        
        let finalWidthPt = finalWidthPx / scale
        let finalHeightPt = finalHeightPx / scale
        
        return CGSize(width: finalWidthPt, height: finalHeightPt)
    }
    
    private func getMessagePreviewText() -> String {
        switch message.dataType {
        case Constant.img:
            return "📷 Image"
        case Constant.video:
            return "🎥 Video"
        case Constant.voiceAudio:
            return "🎤 Audio"
        case Constant.doc:
            return "📄 Document"
        case Constant.contact:
            return "📇 Contact"
        default:
            return message.message
        }
    }
    
    private func detectTextContentType(_ text: String) -> String {
        let emojiPattern = "^[\\p{Emoji}\\s]+$"
        let emojiRegex = try? NSRegularExpression(pattern: emojiPattern, options: [])
        let range = NSRange(location: 0, length: text.utf16.count)
        
        if let regex = emojiRegex, regex.firstMatch(in: text, options: [], range: range) != nil {
            return "only_emoji"
        } else if text.rangeOfCharacter(from: CharacterSet(charactersIn: "😀😁😂😃😄😅😆😇😈😉😊😋😌😍😎😏😐😑😒😓😔😕😖😗😘😙😚😛😜😝😞😟😠😡😢😣😤😥😦😧😨😩😪😫😬😭😮😯😰😱😲😳😴😵😶😷😸😹😺😻😼😽😾😿🙀🙁🙂🙃🙄🙅🙆🙇🙈🙉🙊🙋🙌🙍🙎🙏")) != nil {
            return "text_and_emoji"
        } else {
            return "only_text"
        }
    }
    
    private func countEmojis(_ content: String) -> Int {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return 0
        }
        
        var emojiCount = 0
        var currentIndex = trimmed.startIndex
        
        while currentIndex < trimmed.endIndex {
            let char = trimmed[currentIndex]
            
            if char.isWhitespace || char.isNewline {
                currentIndex = trimmed.index(after: currentIndex)
                continue
            }
            
            if char.isEmoji {
                emojiCount += 1
                var nextIndex = trimmed.index(after: currentIndex)
                
                while nextIndex < trimmed.endIndex {
                    let nextChar = trimmed[nextIndex]
                    let scalar = nextChar.unicodeScalars.first
                    if let scalar = scalar {
                        let codePoint = scalar.value
                        if codePoint == 0xFE0F || codePoint == 0xFE00 || (codePoint >= 0xFE01 && codePoint <= 0xFE0F) || codePoint == 0x200D || codePoint == 0x20E3 {
                            nextIndex = trimmed.index(after: nextIndex)
                            continue
                        }
                    }
                    
                    if nextChar.isEmoji {
                        let nextScalar = nextChar.unicodeScalars.first
                        if let nextScalar = nextScalar {
                            let nextCodePoint = nextScalar.value
                            if (nextCodePoint >= 0x1F1E6 && nextCodePoint <= 0x1F1FF) || nextCodePoint == 0x200D {
                                nextIndex = trimmed.index(after: nextIndex)
                                continue
                            }
                        }
                    }
                    break
                }
                currentIndex = nextIndex
            } else {
                currentIndex = trimmed.index(after: currentIndex)
            }
        }
        
        return emojiCount
    }
    
    // MARK: - Emoji Functions
    
    private func setupEmojiListener() {
        let currentUserId = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        let groupId = group.groupId
        let senderRoom = getSenderRoom()
        let messageId = message.id
        
        let database = Database.database().reference()
        let emojiPath = "\(Constant.GROUPCHAT)/\(senderRoom)/\(messageId)/emojiModel"
        
        displayEmojis = staticEmojis
        
        if let emojiModels = message.emojiModel {
            currentEmojiModels = emojiModels.filter { !$0.name.isEmpty && !$0.emoji.isEmpty }
        }
        
        emojiListenerHandle = database.child(emojiPath).observe(.value) { snapshot in
            var emojiModels: [EmojiModel] = []
            var emojiHashSet = Set<String>()
            
            for emoji in self.staticEmojis {
                emojiHashSet.insert(emoji.character)
            }
            
            if let emojiArray = snapshot.value as? [[String: Any]] {
                for emojiDict in emojiArray {
                    let emoji = emojiDict["emoji"] as? String ?? ""
                    let name = emojiDict["name"] as? String ?? ""
                    
                    if !emoji.isEmpty && !name.isEmpty {
                        emojiModels.append(EmojiModel(name: name, emoji: emoji))
                        
                        if !emojiHashSet.contains(emoji) {
                            emojiHashSet.insert(emoji)
                        }
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.currentEmojiModels = emojiModels
                self.updateDisplayEmojis()
            }
        }
    }
    
    private func updateDisplayEmojis() {
        var combinedEmojis = staticEmojis
        var emojiHashSet = Set<String>()
        
        for emoji in staticEmojis {
            emojiHashSet.insert(emoji.character)
        }
        
        for emojiModel in currentEmojiModels {
            let emoji = emojiModel.emoji
            let name = emojiModel.name
            
            if !emoji.isEmpty && !name.isEmpty && !emojiHashSet.contains(emoji) {
                let firebaseEmoji = DisplayEmoji(
                    slug: "",
                    character: emoji,
                    unicodeName: name,
                    codePoint: "",
                    isFromFirebase: true
                )
                combinedEmojis.append(firebaseEmoji)
                emojiHashSet.insert(emoji)
            }
        }
        
        if let lastEmoji = combinedEmojis.last, !lastEmoji.character.isEmpty {
            let emptyEmoji = DisplayEmoji(
                slug: "e0-6-red-heart",
                character: "",
                unicodeName: "",
                codePoint: "2764 FE0F"
            )
            combinedEmojis.append(emptyEmoji)
        }
        
        displayEmojis = combinedEmojis
    }
    
    private func removeEmojiListener() {
        if let handle = emojiListenerHandle {
            let database = Database.database().reference()
            let senderRoom = getSenderRoom()
            let messageId = message.id
            let emojiPath = "\(Constant.GROUPCHAT)/\(senderRoom)/\(messageId)/emojiModel"
            database.child(emojiPath).removeObserver(withHandle: handle)
            emojiListenerHandle = nil
        }
    }
    
    private func fetchAvailableEmojis() {
        guard !isLoadingEmojis else { return }
        guard availableEmojis.isEmpty else { return }
        
        isLoadingEmojis = true
        let urlString = "\(Constant.baseURL)emojiController/fetch_emoji_data"
        guard let url = URL(string: urlString) else {
            isLoadingEmojis = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoadingEmojis = false
                
                if let error = error {
                    print("🚫 [fetchAvailableEmojis] Error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else { return }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let dataArray = json["data"] as? [[String: Any]] {
                        var fetchedEmojis: [EmojiData] = []
                        for item in dataArray {
                            if let slug = item["slug"] as? String,
                               let character = item["character"] as? String,
                               let unicodeName = item["unicode_name"] as? String,
                               let codePoint = item["code_point"] as? String,
                               let group = item["group"] as? String,
                               let subGroup = item["sub_group"] as? String {
                                fetchedEmojis.append(EmojiData(
                                    slug: slug,
                                    character: character,
                                    unicodeName: unicodeName,
                                    codePoint: codePoint,
                                    group: group,
                                    subGroup: subGroup
                                ))
                            }
                        }
                        self.availableEmojis = fetchedEmojis
                    }
                } catch {
                    print("🚫 [fetchAvailableEmojis] JSON parsing error: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    private func handleEmojiTap(displayEmoji: DisplayEmoji) {
        guard !displayEmoji.character.isEmpty else { return }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        let currentUserId = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        let userReaction = currentEmojiModels.first { $0.name == currentUserId && $0.emoji == displayEmoji.character }
        
        isPresented = false
        
        if let _ = userReaction {
            removeEmoji(emojiCharacter: displayEmoji.character)
        } else {
            addEmoji(emojiCharacter: displayEmoji.character)
        }
    }
    
    private func addEmoji(emojiCharacter: String) {
        let currentUserId = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        let groupId = group.groupId
        let senderRoom = getSenderRoom()
        let messageId = message.id
        
        let database = Database.database().reference()
        let emojiPath = "\(Constant.GROUPCHAT)/\(senderRoom)/\(messageId)/emojiModel"
        
        database.child(emojiPath).observeSingleEvent(of: .value) { snapshot in
            var emojiMap: [String: EmojiModel] = [:]
            var isUpdated = false
            
            if snapshot.exists(), let emojiArray = snapshot.value as? [[String: Any]] {
                for emojiDict in emojiArray {
                    let name = emojiDict["name"] as? String ?? ""
                    let emoji = emojiDict["emoji"] as? String ?? ""
                    if !name.isEmpty {
                        if name == currentUserId {
                            emojiMap[name] = EmojiModel(name: name, emoji: emojiCharacter)
                            isUpdated = true
                        } else {
                            emojiMap[name] = EmojiModel(name: name, emoji: emoji)
                        }
                    }
                }
            }
            
            if !isUpdated {
                emojiMap[currentUserId] = EmojiModel(name: currentUserId, emoji: emojiCharacter)
            }
            
            let emojiList = Array(emojiMap.values)
            let emojiCountStr = String(emojiList.count)
            
            database.child(emojiPath).setValue(emojiList.map { ["name": $0.name, "emoji": $0.emoji] })
            database.child("\(Constant.GROUPCHAT)/\(senderRoom)/\(messageId)/emojiCount").setValue(emojiCountStr)
        }
    }
    
    private func addEmojiFromPicker(emojiCharacter: String) {
        let currentUserId = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        guard !currentUserId.isEmpty else { return }
        
        let groupId = group.groupId
        let senderRoom = getSenderRoom()
        let messageId = message.id
        
        let database = Database.database().reference()
        let emojiPath = "\(Constant.GROUPCHAT)/\(senderRoom)/\(messageId)/emojiModel"
        
        database.child(emojiPath).observeSingleEvent(of: .value) { snapshot in
            var emojiMap: [String: EmojiModel] = [:]
            var isUpdated = false
            let newEmoji = emojiCharacter
            
            if snapshot.exists(), let emojiArray = snapshot.value as? [[String: Any]] {
                for emojiDict in emojiArray {
                    let name = emojiDict["name"] as? String ?? ""
                    let emoji = emojiDict["emoji"] as? String ?? ""
                    if !name.isEmpty {
                        if name == currentUserId {
                            emojiMap[name] = EmojiModel(name: name, emoji: newEmoji)
                            isUpdated = true
                        } else {
                            emojiMap[name] = EmojiModel(name: name, emoji: emoji)
                        }
                    }
                }
            }
            
            if !isUpdated {
                emojiMap[currentUserId] = EmojiModel(name: currentUserId, emoji: newEmoji)
            }
            
            if !emojiMap.isEmpty {
                let emojiList = Array(emojiMap.values)
                let emojiCountStr = String(emojiList.count)
                
                database.child(emojiPath).setValue(emojiList.map { ["name": $0.name, "emoji": $0.emoji] }) { error, _ in
                    if error == nil {
                        database.child("\(Constant.GROUPCHAT)/\(senderRoom)/\(messageId)/emojiCount").setValue(emojiCountStr)
                    }
                }
            }
        }
    }
    
    private func removeEmoji(emojiCharacter: String) {
        let currentUserId = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        let groupId = group.groupId
        let senderRoom = getSenderRoom()
        let messageId = message.id
        
        let database = Database.database().reference()
        let emojiPath = "\(Constant.GROUPCHAT)/\(senderRoom)/\(messageId)/emojiModel"
        
        database.child(emojiPath).observeSingleEvent(of: .value) { snapshot in
            var emojiList: [EmojiModel] = []
            let emojiKey = currentUserId + "_" + emojiCharacter
            
            if snapshot.exists(), let emojiArray = snapshot.value as? [[String: Any]] {
                for emojiDict in emojiArray {
                    let name = emojiDict["name"] as? String ?? ""
                    let emoji = emojiDict["emoji"] as? String ?? ""
                    let existingKey = name + "_" + emoji
                    if existingKey != emojiKey {
                        emojiList.append(EmojiModel(name: name, emoji: emoji))
                    }
                }
            }
            
            let emojiCountStr = emojiList.isEmpty ? "" : String(emojiList.count)
            
            if emojiList.isEmpty {
                let emptyList: [[String: String]] = [["name": "", "emoji": ""]]
                database.child(emojiPath).setValue(emptyList)
            } else {
                database.child(emojiPath).setValue(emojiList.map { ["name": $0.name, "emoji": $0.emoji] })
            }
            
            database.child("\(Constant.GROUPCHAT)/\(senderRoom)/\(messageId)/emojiCount").setValue(emojiCountStr)
        }
    }
    
    @ViewBuilder
    private var emojiPickerSheet: some View {
        NavigationView {
            ZStack {
                if isLoadingEmojis {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading emojis...")
                            .font(.custom("Inter18pt-Regular", size: 14))
                            .foregroundColor(Color("gray3"))
                            .padding(.top, 10)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 40), spacing: 8)], spacing: 8) {
                            ForEach(availableEmojis, id: \.slug) { emojiData in
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    addEmojiFromPicker(emojiCharacter: emojiData.character)
                                    showEmojiPicker = false
                                    isPresented = false
                                }) {
                                    Text(emojiData.character)
                                        .font(.system(size: 30))
                                        .frame(width: 40, height: 40)
                                }
                            }
                        }
                        .padding(8)
                    }
                }
            }
            .navigationTitle("Add Emoji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showEmojiPicker = false
                    }
                }
            }
        }
    }
}

// MARK: - Clear Group Chat Dialog (matching ChattingScreen ClearChatDialog design)
struct ClearGroupChatDialog: View {
    @Binding var isPresented: Bool
    let onConfirm: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Semi-transparent background (matching Android setCanceledOnTouchOutside)
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        isPresented = false
                    }
                }
            
            // Dialog card (matching Android CardView: 268dp width, cardBackgroundColornew, 20dp corner radius)
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    // Dismiss button (matching Android dismiss ImageView: 24dp x 24dp, crossbtn drawable)
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation {
                                isPresented = false
                            }
                        }) {
                            Image("crossbtn")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(Color("TextColor"))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.top, 0)
                    .padding(.trailing, 0)
                    
                    // Title text (matching Android TextView: "Delete All Messages ?", 17sp, font weight 500, center gravity)
                    Text("Delete All Messages ?")
                        .font(.custom("Inter18pt-Medium", size: 17))
                        .fontWeight(.medium)
                        .foregroundColor(Color("TextColor"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(18)
                        .padding(.top, 14)
                    
                    // Buttons container (matching Android LinearLayout: horizontal, center gravity, 25dp marginTop)
                    HStack(spacing: 25) {
                        // Ok button (matching Android AppCompatButton: button_hover4 background, 33dp height, 15sp, white text)
                        Button(action: {
                            withAnimation {
                                isPresented = false
                            }
                            onConfirm()
                        }) {
                            Text("Ok")
                                .font(.custom("Inter18pt-Regular", size: 15))
                                .foregroundColor(.white)
                                .frame(height: 33)
                                .padding(.horizontal, 20)
                                .background(Color(hex: Constant.themeColor))
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Cancel button (matching Android: visibility="gone" - hidden in layout)
                        // Note: Android layout has Cancel button but it's set to gone, so we don't show it
                    }
                    .padding(.top, 25)
                }
                .padding(20) // Matching Android padding="20dp"
            }
            .frame(width: 268) // Matching Android layout_width="268dp"
            .background(
                RoundedRectangle(cornerRadius: 20) // Matching Android cardCornerRadius="20dp"
                    .fill(Color("cardBackgroundColornew")) // Matching Android cardBackgroundColor="@color/cardBackgroundColornew"
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            )
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPresented)
    }
}
