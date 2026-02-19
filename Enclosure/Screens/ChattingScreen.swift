//
//  ChattingScreen.swift
//  Enclosure
//
//  Created by Ram Lohar on 30/04/25.
//

import SwiftUI
import Photos
import PhotosUI
import FirebaseDatabase
import FirebaseStorage
import QuartzCore
import UIKit
import AVFoundation
import AVKit
import QuickLook
import Contacts
import ContactsUI

struct ChattingScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    let contact: UserActiveContactModel
    
    @State private var messageText: String = ""
    @FocusState private var isMessageFieldFocused: Bool
    @State private var showEmojiPicker: Bool = false
    @State private var showGalleryPicker: Bool = false
    @State private var showCameraView: Bool = false
    @State private var wasGalleryPickerOpenBeforeCamera: Bool = false
    @State private var wasGalleryPickerOpenBeforeImagePicker: Bool = false
    @State private var wasGalleryPickerOpenBeforeVideoPicker: Bool = false
    @State private var wasGalleryPickerOpenBeforeDocumentPicker: Bool = false
    @State private var showMenu: Bool = false
    @State private var showWhatsAppImagePicker: Bool = false
    @State private var showWhatsAppVideoPicker: Bool = false
    @State private var showDocumentPicker: Bool = false
    @State private var showUnifiedGalleryPicker: Bool = false
    @State private var showWhatsAppContactPicker: Bool = false
    @State private var selectedDocuments: [URL] = []
    @State private var showFilePickerActionSheet: Bool = false
    @State private var wasGalleryPickerOpenBeforeContactPicker: Bool = false
    @State private var showSearch: Bool = false
    @FocusState private var isSearchFieldFocused: Bool
    @State private var showForwardContactPicker: Bool = false // Show forward contact picker
    @State private var selectedMessagesForForward: [ChatMessage] = [] // Store selected messages for forwarding
    @State private var searchText: String = ""
    @State private var showMultiSelectHeader: Bool = false
    @State private var selectedCount: Int = 0
    
    // Multi-selection state (matching Android chatAdapter)
    @State private var isMultiSelectMode: Bool = false
    @State private var selectedMessageIds: Set<String> = [] // Track selected message IDs
    @State private var showReplyLayout: Bool = false
    @State private var replyMessage: String = ""
    @State private var replySenderName: String = ""
    @State private var replyDataType: String = ""
    @State private var isReplyFromSender: Bool = false // Track if reply is from sender (for theme color)
    @State private var replyImageUrl: String? = nil // Image/thumbnail URL for reply preview
    @State private var replyContactName: String? = nil // Contact name for contact type
    @State private var replyFileExtension: String? = nil // File extension for documents/music
    @State private var replyMessageId: String? = nil // Original message ID for reply (replyCrtPostion)
    @State private var isBlockedByUser: Bool = false // Track if current user is blocked by the other user
    @State private var characterCount: Int = 0
    @State private var showCharacterCount: Bool = false
    @State private var isPressed: Bool = false
    @State private var downArrowCount: Int = 0
    @State private var showDownArrowCount: Bool = false
    @State private var maxMessageLength: Int = 1000
    
    // Message list state
    @State private var messages: [ChatMessage] = []
    @State private var filteredMessages: [ChatMessage] = [] // Filtered messages for search
    @State private var isSearching: Bool = false // Track if currently searching
    
    // Firebase listener state (matching Android)
    @State private var isLoading: Bool = false
    @State private var isLoadingMore: Bool = false // Track pagination loading state
    @State private var initialLoadDone: Bool = false
    @State private var fullListenerAttached: Bool = false
    @State private var hasScrolledToBottom: Bool = false // Track if we've scrolled to bottom initially
    @State private var initiallyLoadedMessageIds: Set<String> = [] // Track message IDs loaded in initial fetch
    @State private var oldestInitialTimestamp: TimeInterval = 0 // Track oldest timestamp from initial load
    @State private var lastTimestamp: TimeInterval? = nil // Track oldest timestamp for pagination (matching Android)
    @State private var lastLoadMoreTime: Date? = nil // Track last loadMore call time for throttling
    @State private var hasMoreMessages: Bool = true // Track if there are more messages to load
    @State private var lastScrollOffsetUpdateTime: Date? = nil //ƒvideos Track last scroll offset update time for throttling
    @State private var lastScrollOffset: CGFloat = 0 // Track last scroll offset to detect scrolling
    @State private var isInitialScrollInProgress: Bool = false // Prevent loadMore during initial scroll
    @State private var initialScrollCompletedTime: Date? = nil // Track when initial scroll completed
    @State private var scrollDebounceWorkItem: DispatchWorkItem? = nil // Debounce scroll for rapid message additions
    @State private var listenerMessagesDebounceWorkItem: DispatchWorkItem? = nil // Debounce scroll after listener finishes
    @State private var hasPerformedInitialScroll: Bool = false // Track if initial scroll has been performed
    @State private var pendingInitialScrollId: String? = nil // Message ID to scroll to once ready
    @State private var allowAnimatedScroll: Bool = false // Enable animated scrolls after initial scroll completes
    @State private var firebaseListenerHandle: DatabaseHandle?
    @State private var firebaseChildListenerHandle: DatabaseHandle?
    @State private var scrollViewProxy: ScrollViewProxy? = nil // Hold proxy for manual scrolls (down arrow)
    @State private var showScrollDownButton: Bool = false // Show when user is away from bottom
    @State private var isLastItemVisible: Bool = false // Track if last message is visible (matching Android)
    @State private var isTouchGestureActive: Bool = false // Track touch to debounce touch gesture
    @State private var highlightedMessageId: String? = nil // Track highlighted message ID for reply navigation
    @State private var showLongPressDialog: Bool = false // Track long press dialog visibility
    @State private var longPressedMessage: ChatMessage? = nil // Track which message was long pressed
    @State private var longPressPosition: CGPoint = .zero // Track long press position
    
    // Emoji reactions bottom sheet state
    @State private var showEmojiReactionsSheet: Bool = false
    @State private var emojiReactionsMessage: ChatMessage? = nil
    @State private var emojiReactionsList: [EmojiModel] = []
    @State private var isLoadingEmojiReactions: Bool = false
    @State private var emojiReactionsListenerHandle: DatabaseHandle?
    
    // Typing indicator state (matching Android)
    @State private var isTyping: Bool = false
    @State private var typingRunnable: DispatchWorkItem? = nil
    @State private var typingListenerHandle: DatabaseHandle? = nil
    @State private var typingRef: DatabaseReference? = nil
    @State private var typingListenerHandle2: DatabaseHandle? = nil // Alternative room listener
    @State private var typingRef2: DatabaseReference? = nil // Alternative room reference
    
    // MARK: - Errors
    private enum MultiImageUploadError: Error {
        case dataUnavailable
        case downloadURLMissing
    }
    
    // Emoji picker state
    @State private var emojis: [EmojiData] = []
    @State private var filteredEmojis: [EmojiData] = []
    @State private var isLoadingEmojis: Bool = false
    @State private var emojiSearchText: String = ""
    @State private var showEmojiLeftArrow: Bool = false
    @State private var isEmojiLayoutHorizontal: Bool = false
    @State private var isSyncingEmojiText: Bool = false
    @FocusState private var isEmojiSearchFieldFocused: Bool
    
    // Local gallery (mirrors Android dataRecview)
    @State private var photoAssets: [PHAsset] = []
    @State private var selectedAssetIds: Set<String> = []
    private let imageManager = PHCachingImageManager()
    
    // Multi-image preview dialog state
    @State private var showMultiImagePreview: Bool = false
    @State private var multiImagePreviewCaption: String = ""
    @State private var multiImagePreviewAssets: [PHAsset] = [] // Store selected assets from WhatsAppLikeImagePicker
    
    // Multi-document preview dialog state
    @State private var showMultiDocumentPreview: Bool = false
    @State private var multiDocumentPreviewCaption: String = ""
    @State private var multiDocumentPreviewURLs: [URL] = [] // Store selected document URLs
    
    // Bunch image preview state (for navigation to full screen)
    @State private var navigateToMultipleImageScreen: Bool = false
    @State private var bunchPreviewImages: [SelectionBunchModel] = []
    @State private var bunchPreviewCurrentIndex: Int = 0
    
    // Single image preview state (for navigation to ShowImageScreen)
    @State private var navigateToShowImageScreen: Bool = false
    @State private var selectedImageForShow: SelectionBunchModel?
    
    // Multi-contact preview dialog state
    @State private var showMultiContactPreview: Bool = false
    @State private var multiContactPreviewCaption: String = ""
    @State private var multiContactPreviewContacts: [ContactPickerInfo] = [] // Store selected contacts
    
    // Voice recording state
    @State private var showVoiceRecordingBottomSheet: Bool = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordingTimer: Timer?
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingProgress: Double = 0.0
    @State private var audioFileURL: URL?
    @State private var isRecording: Bool = false
    @State private var sendButtonScale: CGFloat = 1.0
    
    // Pagination constants (matching Android)
    private let PAGE_SIZE: UInt = 10
    private let LOAD_MORE_THROTTLE: TimeInterval = 0.5 // Throttle loadMore calls (500ms)

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
        // Android uses a regular weight for the messageBox text
        return .custom("Inter18pt-Regular", size: size)
    }
    
    // Valuable card state
    @State private var limitStatus: String = "0"
    @State private var totalMsgLimit: String = "0"
    @State private var showLimitStatus: Bool = false
    
    // Menu dialog states
    @State private var showClearChatDialog: Bool = false
    @State private var showBlockUserDialog: Bool = false
    @State private var navigateToUserInfo: Bool = false
    @State private var showTotalMsgLimit: Bool = false
    
    // Unique dates tracking (matching Android uniqueDates Set)
    @State private var uniqueDates: Set<String> = []
    
    // Date display state (matching Android datelyt)
    @State private var showDateView: Bool = false
    @State private var dateText: String = ""
    @State private var firstVisibleMessageIndex: Int = 0
    @State private var hideDateWorkItem: DispatchWorkItem? = nil
    @State private var isScrolling: Bool = false
    @State private var dateScrollDebounceWorkItem: DispatchWorkItem? = nil // Debounce for date view scroll detection
    @State private var lastScrollEventTime: Date? = nil // Track last scroll event time
    
    // Block functionality state (matching Android blockUser, blockContainer)
    @State private var isUserBlocked: Bool = false // Track if user is blocked (matching Android blockUser TextView)
    @State private var showBlockCard: Bool = false // Track if block card should be shown (matching Android blockContainer visibility)
    @State private var blockedUserName: String = "" // Name of blocked user (matching Android originalNumber)
    @State private var blockedUserSubtitle: String = "" // Subtitle for blocked user (matching Android originalName)
    @State private var isContactSaved: Bool = false // Track if contact is saved in phone contacts
    
    var body: some View {
        ZStack {
            // Background color matching Android modetheme2
            Color("BackgroundColor")
                .ignoresSafeArea()
                .onAppear {
                    // Mark chat screen active for this receiver (matching Android chattingScreen.isChatScreenActive / isChatScreenActiveUid) to suppress FCM chat notifications
                    FirebaseManager.shared.chatScreenActiveUid = contact.uid
                    // Store selected user's device_type so notification sends original value
                    ChatCacheManager.shared.upsertContact(contact)
                    print("[NOTIF_RECEIVER_DEVICE] on_appear receiver_uid=\(contact.uid) full_name=\(contact.fullName) device_type=\(contact.deviceType)")
                    print("🚫 [BLOCK] ChattingScreen appeared - showBlockCard: \(showBlockCard), isUserBlocked: \(isUserBlocked)")
                    print("🚫 [BLOCK] Contact: \(contact.fullName), UID: \(contact.uid)")
                    print("🚫 [BLOCK] Contact block status from API - block: \(contact.block), iamblocked: \(contact.iamblocked)")
                    
                    // Set initial block status from contact data (matching Android Intent extra "block")
                    // This ensures we have the correct state even if API check fails
                    if contact.block {
                        isUserBlocked = true
                        showBlockCard = true
                        blockedUserName = contact.fullName
                        blockedUserSubtitle = "~ \(contact.fullName)"
                        print("🚫 [BLOCK] ✅ Initial state set from contact data - isUserBlocked: \(isUserBlocked), showBlockCard: \(showBlockCard)")
                    }
                    
                    if contact.iamblocked {
                        isBlockedByUser = true
                        print("🚫 [BLOCK] ✅ Initial state set from contact data - isBlockedByUser: \(isBlockedByUser)")
                    }
                    
                    // Check block status when screen appears (matching Android handleIntent block check)
                    // This will verify/update the state, but initial state is already set from contact data
                    checkBlockStatus()
                    // Check if contact is saved in phone contacts
                    checkIfContactSaved()
                    
                    // Load pending messages from SQLite (matching Android loadPendingMessages on onResume)
                    loadPendingMessages()
                }
                .onDisappear {
                    // Clear chat screen active (matching Android) so chat notifications show again
                    FirebaseManager.shared.chatScreenActiveUid = nil
                }
            
            VStack(spacing: 0) {
                // Header - show multi-select header when in multi-select mode, otherwise show normal header
                if isMultiSelectMode {
                    multiSelectHeaderView
                } else {
                headerView
                }
                
                // Message list
                ZStack(alignment: .top) {
                    messageListView
                        .contentShape(Rectangle()) // Ensure entire area is tappable
                        .allowsHitTesting(true) // Ensure ScrollView can receive touches
                    
                    // Block card view (matching Android cardview below datelyt)
                    // Show when user is NOT blocked AND contact is NOT saved (upper container with Add and Block)
                    // When user is already blocked, show bottom container instead (with Unblock option)
                    if showBlockCard && !isUserBlocked && !isContactSaved {
                        blockCardView
                            .zIndex(999) // Below date view but above messages
                            .padding(.top, showDateView ? 60 : 8) // Position below date view if visible
                            .padding(.horizontal, 12) // layout_marginHorizontal="12dp"
                            .allowsHitTesting(true) // Allow button interactions
                            .onAppear {
                                print("🚫 [BLOCK] ✅ Block card view rendered in ZStack - showBlockCard: \(showBlockCard), isUserBlocked: \(isUserBlocked), isContactSaved: \(isContactSaved)")
                                print("🚫 [BLOCK] Block card position - top padding: \(showDateView ? 60 : 8), horizontal: 12")
                            }
                    }
                    
                    
                    // Date view overlay (matching Android datelyt)
                    if showDateView {
                        dateView
                            .zIndex(1000) // Ensure it's on top
                            .padding(.top, 8) // Add some top padding
                            .allowsHitTesting(false) // Don't block touches to ScrollView
                    }
                    
                    // Scroll down button overlay
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
                }
                
                // Bottom input area - hide when in multi-select mode (matching Android binding.bottom.setVisibility(View.GONE))
                if !isMultiSelectMode {
                bottomInputView
                }
            }
            
            // Menu overlay
            if showMenu {
                menuOverlay
            }
            
            // Long press dialog overlay - full screen
            if showLongPressDialog, let message = longPressedMessage {
                MessageLongPressDialog(
                    message: message,
                    isSentByMe: message.uid == Constant.SenderIdMy,
                    position: longPressPosition,
                    contact: contact,
                    isPresented: $showLongPressDialog,
                    onReply: {
                        showLongPressDialog = false
                        longPressedMessage = nil
                        handleHalfSwipeReply(message)
                    },
                    onForward: {
                        showLongPressDialog = false
                        longPressedMessage = nil
                        selectedMessageIds = [message.id]
                        selectedCount = 1
                        openContactSelectionForForward()
                    },
                    onCopy: {
                        showLongPressDialog = false
                        longPressedMessage = nil
                        UIPasteboard.general.string = message.message
                        Constant.showToast(message: "Copied")
                    },
                    onDelete: {
                        showLongPressDialog = false
                        longPressedMessage = nil
                        deleteMessage(message: message)
                    },
                    onMultiSelect: {
                        showLongPressDialog = false
                        longPressedMessage = nil
                        enterMultiSelectMode()
                        toggleMessageSelection(messageId: message.id)
                    },
                    onImageTap: { imageModel in
                        // Open ShowImageScreen for single image
                        selectedImageForShow = imageModel
                        navigateToShowImageScreen = true
                    }
                )
            }
        }
        .sheet(isPresented: $showEmojiReactionsSheet) {
            emojiReactionsBottomSheet
        }
        .navigationBarHidden(true)
        .background(
            // Hidden NavigationLink for UserInfoScreen from menu
            NavigationLink(
                destination: UserInfoScreen(
                    recUserId: contact.uid,
                    recUserName: contact.fullName
                )
                .onDisappear {
                    // Reset navigation state when UserInfoScreen is dismissed
                    navigateToUserInfo = false
                },
                isActive: $navigateToUserInfo
            ) {
                EmptyView()
            }
            .hidden()
        )
        .overlay(
            // Custom Block User Dialog (matching Android delete_ac_dialogue.xml)
            Group {
                if showBlockUserDialog {
                    BlockUserDialog(
                        isPresented: $showBlockUserDialog,
                        onConfirm: {
                            // Block user (matching Android Webservice.insertBlockUser)
                            let receiverUid = contact.uid
                            let uid = Constant.SenderIdMy
                            
                            ApiService.blockUser(uid: uid, blockedUid: receiverUid) { [self] success, message in
                                DispatchQueue.main.async {
                                    // Handle "already blocked" as success (matching Android behavior)
                                    if success || message.lowercased().contains("already blocked") {
                                        isUserBlocked = true
                                        showBlockCard = true
                                        blockedUserName = contact.fullName
                                        blockedUserSubtitle = "~ \(contact.fullName)"
                                        print("🚫 [MENU BLOCK] ✅ User blocked successfully (or already blocked)")
                                        print("🚫 [MENU BLOCK] Updated state - isUserBlocked: \(isUserBlocked), showBlockCard: \(showBlockCard)")
                                        // Re-check contact saved status when block status changes
                                        // This will determine which container to show (upper or bottom)
                                        checkIfContactSaved()
                                        // Don't call checkBlockStatus() here as it may return false and overwrite our correct state
                                        // The state is already set correctly above
                                        // No toast shown (matching Android behavior)
                                    } else {
                                        print("🚫 [MENU BLOCK] 🚫 Failed to block user: \(message)")
                                        Constant.showToast(message: "Failed to block user")
                                    }
                                }
                            }
                        }
                    )
                }
            }
        )
        .overlay(
            // Custom Clear Chat Dialog (matching Android delete_popup_row.xml)
            Group {
                if showClearChatDialog {
                    ClearChatDialog(
                        isPresented: $showClearChatDialog,
                        onConfirm: {
                            clearChat()
                        }
                    )
                }
            }
        )
        .fullScreenCover(isPresented: $showCameraView) {
            CameraGalleryView(contact: contact)
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
            WhatsAppLikeVideoPicker(maxSelection: 5, contact: contact) { selectedAssets, caption in
                handleVideoPickerResult(selectedAssets: selectedAssets, caption: caption)
            }
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
                allowsMultipleSelection: true,
                onDocumentsSelected: { urls in
                    print("GalleryPicker: onDocumentsSelected callback called with \(urls.count) files")
                    // Store documents immediately when callback is called
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        print("GalleryPicker: Processing documents from callback, count: \(urls.count)")
                        handleDocumentPickerResult(selectedDocuments: urls)
                    }
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
                    // Use a longer delay and verify contacts are still available
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
        }
        .fullScreenCover(isPresented: $showMultiImagePreview, onDismiss: {
            // Reset caption and assets when dialog is dismissed
            multiImagePreviewCaption = ""
            multiImagePreviewAssets = []
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
        .fullScreenCover(isPresented: $showMultiDocumentPreview, onDismiss: {
            // Reset caption and URLs when dialog is dismissed
            multiDocumentPreviewCaption = ""
            multiDocumentPreviewURLs = []
        }) {
            // IMPORTANT: Create a local copy to ensure we capture the current value
            // SwiftUI evaluates this closure when showMultiDocumentPreview becomes true
            let documentsToShow = multiDocumentPreviewURLs
            MultiDocumentPreviewDialog(
                selectedDocuments: documentsToShow,
                caption: $multiDocumentPreviewCaption,
                contact: contact,
                onSend: { caption in
                    handleMultiDocumentSend(caption: caption)
                },
                onDismiss: {
                    showMultiDocumentPreview = false
                },
                onMessageAdded: { message in
                    // Add message to list immediately with progress bar (matching Android messageList.add)
                    DispatchQueue.main.async {
                        if !self.messages.contains(where: { $0.id == message.id }) {
                            print("🔍 [ProgressBar] 📤 ADDING DOCUMENT MESSAGE TO UI")
                            print("🔍 [ProgressBar]   - Message ID: \(message.id.prefix(8))...")
                            print("🔍 [ProgressBar]   - receiverLoader: \(message.receiverLoader)")
                            if message.receiverLoader == 0 {
                                print("🔍 [ProgressBar]   ⚠️ PROGRESS BAR WILL BE SHOWN (receiverLoader == 0)")
                            }
                            self.messages.append(message)
                            self.isLastItemVisible = true
                            self.showScrollDownButton = false
                            print("✅ [MULTI_DOCUMENT] Message added to UI immediately: \(message.id)")
                        }
                    }
                }
            )
            .onAppear {
                print("MultiDocumentPreviewDialog: fullScreenCover onAppear")
                print("MultiDocumentPreviewDialog: Captured documents count: \(documentsToShow.count)")
                print("MultiDocumentPreviewDialog: Captured documents: \(documentsToShow.map { $0.lastPathComponent })")
                print("MultiDocumentPreviewDialog: Current state documents count: \(multiDocumentPreviewURLs.count)")
            }
        }
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
                            viewHolderTypeKey: Constant.SenderIdMy == contact.uid ? "sender" : "receiver"
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
        .fullScreenCover(isPresented: $showMultiContactPreview, onDismiss: {
            // Reset caption and contacts when dialog is dismissed
            multiContactPreviewCaption = ""
            multiContactPreviewContacts = []
        }) {
            // IMPORTANT: Use current state value - SwiftUI will evaluate this when showMultiContactPreview becomes true
            MultiContactPreviewDialog(
                selectedContacts: multiContactPreviewContacts,
                caption: $multiContactPreviewCaption,
                contact: contact,
                onSend: { caption in
                    handleMultiContactSend(caption: caption)
                },
                onDismiss: {
                    showMultiContactPreview = false
                },
                onMessageAdded: { message in
                    // Add message to list immediately with progress bar (matching Android messageList.add)
                    DispatchQueue.main.async {
                        if !self.messages.contains(where: { $0.id == message.id }) {
                            print("🔍 [ProgressBar] 📤 ADDING CONTACT MESSAGE TO UI")
                            print("🔍 [ProgressBar]   - Message ID: \(message.id.prefix(8))...")
                            print("🔍 [ProgressBar]   - receiverLoader: \(message.receiverLoader)")
                            if message.receiverLoader == 0 {
                                print("🔍 [ProgressBar]   ⚠️ PROGRESS BAR WILL BE SHOWN (receiverLoader == 0)")
                            }
                            self.messages.append(message)
                            self.isLastItemVisible = true
                            self.showScrollDownButton = false
                            print("✅ [MULTI_CONTACT] Message added to UI immediately: \(message.id)")
                        }
                    }
                }
            )
            .onAppear {
                print("MultiContactPreviewDialog: fullScreenCover onAppear")
                print("MultiContactPreviewDialog: Current state contacts count: \(multiContactPreviewContacts.count)")
                print("MultiContactPreviewDialog: Contacts: \(multiContactPreviewContacts.map { $0.name })")
            }
        }
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
            .interactiveDismissDisabled(true) // Prevent swipe to dismiss (matching Android setCanceledOnTouchOutside(false))
        }
        .fullScreenCover(isPresented: $showForwardContactPicker) {
            // Forward contact picker (matching Android showForwardDialog)
            // Shows active chat users instead of device contacts
            ForwardContactPicker(maxSelection: 50) { (contacts: [UserActiveContactModel]) in
                // Handle forward to selected contacts (matching Android forwardText.setOnClickListener)
                forwardMessagesToContacts(contacts: contacts)
            }
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
            // Get receiverRoom (matching Android: receiverUid + uid)
            let receiverUid = contact.uid
            let uid = Constant.SenderIdMy
            let receiverRoom = receiverUid + uid
            
            // Fetch limit status (matching Android Webservice.get_individual_chatting)
            fetchIndividualChattingLimit(senderId: uid, receiverUid: receiverUid)
            
            // Fetch messages (matching Android fetchMessages)
            fetchMessages(receiverRoom: receiverRoom) {
                print("✅ Messages fetched successfully")
            }
        }
        .onDisappear {
            // Remove Firebase listeners when leaving screen
            removeFirebaseListeners()
            
            // Refresh limit status on exit (Android onBackPressed/onDestroy)
            let receiverUid = contact.uid
            let uid = Constant.SenderIdMy
            fetchIndividualChattingLimit(senderId: uid, receiverUid: receiverUid)
            
            // Clean up work items
            hideDateWorkItem?.cancel()
            dateScrollDebounceWorkItem?.cancel()
        }
    }
    
    // MARK: - Helper function to get receiver room
    private func getReceiverRoom() -> String {
        let receiverUid = contact.uid
        let uid = Constant.SenderIdMy
        return receiverUid + uid
    }
    
    // MARK: - Helper function to get sender room
    private func getSenderRoom() -> String {
        let receiverUid = contact.uid
        let uid = Constant.SenderIdMy
        return uid + receiverUid
    }
    
    // MARK: - Fetch individual chatting limit (matching Android Webservice.get_individual_chatting)
    private func fetchIndividualChattingLimit(senderId: String, receiverUid: String) {
        ApiService.get_individual_chatting(uid: senderId, friendId: receiverUid) { success, message, limitStatusValue, totalMsgLimitValue in
            DispatchQueue.main.async {
                self.limitStatus = limitStatusValue
                self.totalMsgLimit = totalMsgLimitValue
                self.showLimitStatus = !limitStatusValue.isEmpty && limitStatusValue != "0"
                self.showTotalMsgLimit = !totalMsgLimitValue.isEmpty && totalMsgLimitValue != "0"
                
                if success {
                    print("✅ [ChattingScreen] get_individual_chatting success - limitStatus: \(limitStatusValue), totalMsgLimit: \(totalMsgLimitValue)")
                } else {
                    print("🚫 [ChattingScreen] get_individual_chatting failed - message: \(message)")
                }
            }
        }
    }
    
    // MARK: - Scroll to target message and highlight it (matching Android scrollToTargetModelId)
    private func scrollToTargetMessage(targetModelId: String) {
        print("📜 [SCROLL] scrollToTargetMessage called - targetModelId: \(targetModelId.prefix(8)), messages.count: \(messages.count)")
        
        guard let proxy = scrollViewProxy else {
            print("📜 [SCROLL] ⚠️ ScrollViewProxy not available")
            return
        }
        
        // Check if message exists in current messages list
        if let foundIndex = messages.firstIndex(where: { $0.id == targetModelId }) {
            let message = messages[foundIndex]
            print("📜 [SCROLL] ✅ Message found at index \(foundIndex)/\(messages.count - 1), scrolling to: \(targetModelId.prefix(8))")
            
            // Scroll to message
            DispatchQueue.main.async {
                print("📜 [SCROLL] Executing scrollTo with animation - anchor: .center")
                withAnimation {
                    proxy.scrollTo(message.id, anchor: .center)
                }
                print("📜 [SCROLL] ScrollTo completed")
                
                // Highlight the message after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    print("📜 [SCROLL] Highlighting message: \(targetModelId.prefix(8))")
                    self.highlightedMessageId = targetModelId
                    
                    // Remove highlight after 1 second
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        print("📜 [SCROLL] Removing highlight from message: \(targetModelId.prefix(8))")
                        self.highlightedMessageId = nil
                    }
                }
            }
        } else {
            print("⚠️ [scrollToTargetMessage] Message not found in current list, checking Firebase")
            // Message not in current list, need to load more pages
            loadPagesUntilMessageFound(targetModelId: targetModelId)
        }
    }
    
    // MARK: - Load pages until message is found (matching Android loadPagesUntilModelFound)
    private func loadPagesUntilMessageFound(targetModelId: String) {
        // Check if message exists in current messages
        let modelFound = messages.contains { $0.id == targetModelId }
        
        if modelFound {
            scrollToTargetMessage(targetModelId: targetModelId)
            return
        }
        
        // Load more messages
        let receiverRoom = getReceiverRoom()
        loadMore(receiverRoom: receiverRoom)
        
        // Retry after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            loadPagesUntilMessageFound(targetModelId: targetModelId)
        }
    }
    
    // MARK: - Handle reply tap (matching Android onClick for replyKey)
    private func handleReplyTap(message: ChatMessage) {
        guard let replyKey = message.replyKey, replyKey == "ReplyKey" else {
            return
        }
        
        guard let targetModelId = message.replyCrtPostion, !targetModelId.isEmpty else {
            print("⚠️ [handleReplyTap] Reply modelId is null or empty")
            return
        }
        
        print("📱 [handleReplyTap] Reply tapped, target modelId: \(targetModelId)")
        
        // Check both receiverRoom and senderRoom in Firebase (matching Android)
        let receiverRoom = getReceiverRoom()
        let senderRoom = getSenderRoom()
        
        // Check receiverRoom
        checkMessageInFirebase(room: receiverRoom, targetModelId: targetModelId) { found in
            if found {
                print("✅ [handleReplyTap] Message found in receiverRoom, scrolling...")
                self.scrollToTargetMessage(targetModelId: targetModelId)
            } else {
                // Check senderRoom
                self.checkMessageInFirebase(room: senderRoom, targetModelId: targetModelId) { found in
                    if found {
                        print("✅ [handleReplyTap] Message found in senderRoom, scrolling...")
                        self.scrollToTargetMessage(targetModelId: targetModelId)
                    } else {
                        print("⚠️ [handleReplyTap] Message not found in either room")
                    }
                }
            }
        }
    }
    
    // MARK: - Check if message exists in Firebase room
    private func checkMessageInFirebase(room: String, targetModelId: String, completion: @escaping (Bool) -> Void) {
        let database = Database.database().reference()
        let chatPath = "\(Constant.CHAT)/\(room)"
        
        database.child(chatPath).child(targetModelId).observeSingleEvent(of: .value) { snapshot in
            let exists = snapshot.exists()
            print("📱 [checkMessageInFirebase] Room: \(room), ModelId: \(targetModelId), Exists: \(exists)")
            completion(exists)
        } withCancel: { error in
            print("🚫 [checkMessageInFirebase] Error checking room \(room): \(error.localizedDescription)")
            completion(false)
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 0) {
            // Main header card (always show normal header)
                headerCardView
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
                            .focused($isSearchFieldFocused)
                            .onAppear {
                                // Focus search field (matching Android binding.searchEt.requestFocus())
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isMessageFieldFocused = false
                                    isSearchFieldFocused = true
                                }
                            }
                            .onChange(of: searchText) { newValue in
                                // Handle search text changes (matching Android TextWatcher)
                                handleSearchTextChanged(newValue)
                            }
                    }
                    .padding(.trailing, 10)
                } else {
                    // Profile section (hidden when search is active - matching Android binding.name.setVisibility(View.GONE))
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
                    
                    // Menu button (three dots) - hidden when search is active (matching Android binding.menu2.setVisibility(View.GONE))
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
    
    // MARK: - Message List View
    private var messageListView: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 4, pinnedViews: []) { // Reduced spacing for better performance
                        // Loading indicator at top when loading more (matching Android)
                        if isLoadingMore {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding()
                                Spacer()
                            }
                        }
                        
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
                            // Use filtered messages when searching, otherwise use all messages
                            ForEach(Array((isSearching ? filteredMessages : messages).enumerated()), id: \.element.id) { index, message in
                                MessageBubbleView(
                                    message: message,
                                    onHalfSwipe: { swipedMessage in
                                        // Handle multi-select mode first (matching Android)
                                        if isMultiSelectMode {
                                            toggleMessageSelection(messageId: swipedMessage.id)
                                            return
                                        }
                                        handleHalfSwipeReply(swipedMessage)
                                    },
                                    onReplyTap: { message in
                                        // Handle multi-select mode first (matching Android)
                                        if isMultiSelectMode {
                                            toggleMessageSelection(messageId: message.id)
                                            return
                                        }
                                        handleReplyTap(message: message)
                                    },
                                    onLongPress: { message, position in
                                        // Handle multi-select mode first (matching Android)
                                        if isMultiSelectMode {
                                            toggleMessageSelection(messageId: message.id)
                                            return
                                        }
                                        
                                        print("🔵 Long press callback triggered for message: \(message.id), position: \(position)")
                                        longPressedMessage = message
                                        longPressPosition = position
                                        showLongPressDialog = true
                                        print("🔵 Dialog state - showLongPressDialog: \(showLongPressDialog), message: \(longPressedMessage?.id ?? "nil")")
                                    },
                                    onEmojiCardTap: { message in
                                        // Handle multi-select mode first (matching Android)
                                        if isMultiSelectMode {
                                            toggleMessageSelection(messageId: message.id)
                                            return
                                        }
                                        // Handle emoji card tap - open emoji reactions bottom sheet
                                        emojiReactionsMessage = message
                                        showEmojiReactionsSheet = true
                                        loadEmojiReactions(for: message)
                                    },
                                    onBunchLongPress: { selectionBunch in
                                        // Show preview dialog for bunch images (called on single tap)
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
                                        // Open ShowImageScreen for single image
                                        selectedImageForShow = imageModel
                                        navigateToShowImageScreen = true
                                    },
                                    isHighlighted: highlightedMessageId == message.id,
                                    isMultiSelectMode: isMultiSelectMode,
                                    isSelected: isMessageSelected(messageId: message.id),
                                    onSelectionToggle: { messageId in
                                        toggleMessageSelection(messageId: messageId)
                                    },
                                    onReceiverPendingComplete: { pendingMessage in
                                        // Mirror Android: update receiverLoader for last receiver message
                                        checkMessageInFirebaseAndStopProgress(
                                            messageId: pendingMessage.id,
                                            receiverUid: contact.uid
                                        )
                                    },
                                    isLastMessage: index == (isSearching ? filteredMessages.count : messages.count) - 1
                                )
                                    .id(message.id)
                                    .onAppear {
                                        // Optimize: Only handle visibility for last item to reduce overhead
                                        let currentMessages = isSearching ? filteredMessages : messages
                                        if index == currentMessages.count - 1 {
                                        handleLastItemVisibility(id: message.id, index: index, isAppearing: true)
                                        }
                                        
                                        // When last message appears, scroll to it once (for initial load only)
                                        // This ensures we only scroll once when the view is actually rendered (like WhatsApp)
                                        if index == messages.count - 1 && hasPerformedInitialScroll && !hasScrolledToBottom {
                                            print("🟢 [SCROLL] Last message appeared - performing single scroll to: \(message.id)")
                                            
                                            // Scroll immediately when last message appears (like WhatsApp)
                                            print("🟢 [SCROLL] Executing scroll to: \(message.id)")
                                            
                                            // Scroll without animation (like WhatsApp)
                                            CATransaction.begin()
                                            CATransaction.setDisableActions(true)
                                            CATransaction.setAnimationDuration(0)
                                            proxy.scrollTo(message.id, anchor: .bottom)
                                            CATransaction.commit()
                                            
                                            // Set flags immediately
                                            self.hasScrolledToBottom = true
                                            self.hasPerformedInitialScroll = true
                                            
                                            // Enable loadMore after a delay
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                self.isInitialScrollInProgress = false
                                                self.initialScrollCompletedTime = Date()
                                            }
                                        }
                                    }
                                    .onDisappear {
                                        // Optimize: Only handle visibility for last item to reduce overhead
                                        if index == messages.count - 1 {
                                        handleLastItemVisibility(id: message.id, index: index, isAppearing: false)
                                    }
                            }
                        }
                    }
                    }
                    .padding(.vertical, 4) // Reduced padding for better performance
                }
                .frame(width: geometry.size.width, height: geometry.size.height) // Fixed frame for ScrollView
                // Removed coordinateSpace - no longer needed after removing preference handler
                // Performance optimization: Reduce layout calculations during scroll
                .scrollDismissesKeyboard(.interactively)
                // Removed preference change handler to improve scroll performance - it was causing stuttering
                .onAppear {
                    scrollViewProxy = proxy
                }
                .onDisappear {
                    scrollViewProxy = nil
                }
                .onAppear {
                    // Don't scroll here - let onChange handle it when messages are loaded
                }
                // Initial scroll is driven by onAppear of the last message; no scroll here
                .onChange(of: initialLoadDone) { done in
                    guard done, !hasPerformedInitialScroll else { return }
                    // Scroll immediately to last message without visible animation
                    hasPerformedInitialScroll = true
                    hasScrolledToBottom = true
                    isInitialScrollInProgress = true
                    scrollToBottom(animated: false)
                    isInitialScrollInProgress = false
                    initialScrollCompletedTime = Date()
                    allowAnimatedScroll = true
                }
                .onChange(of: pendingInitialScrollId) { targetId in
                    guard let id = targetId, !hasScrolledToBottom else {
                        return
                    }
                    isInitialScrollInProgress = true
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)
                    CATransaction.setAnimationDuration(0)
                    proxy.scrollTo(id, anchor: .bottom)
                    CATransaction.commit()
                    hasScrolledToBottom = true
                    pendingInitialScrollId = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isInitialScrollInProgress = false
                        initialScrollCompletedTime = Date()
                        allowAnimatedScroll = true
                    }
                }
                .onChange(of: messages.count) { newCount in
                    // Optimize: Debounce scroll updates to improve performance
                    guard newCount > 0, let lastMessage = messages.last else {
                        return
                    }
                    
                    // For new incoming messages after initial scroll
                    // Use async to avoid blocking main thread during scroll
                    DispatchQueue.main.async {
                        if self.hasScrolledToBottom && !self.isInitialScrollInProgress && self.hasPerformedInitialScroll {
                            if self.allowAnimatedScroll {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        } else {
                            CATransaction.begin()
                            CATransaction.setDisableActions(true)
                            CATransaction.setAnimationDuration(0)
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            CATransaction.commit()
                        }
                    }
                }
                }
                .frame(width: geometry.size.width, height: geometry.size.height) // Frame on ScrollViewReader container
            }
        }
    }
    
    // MARK: - Block Card View (matching Android cardview with originalDelete and originalAdd)
    private var blockCardView: some View {
        // Use contact name if blockedUserName is empty
        let displayName = blockedUserName.isEmpty ? contact.fullName : blockedUserName
        let displaySubtitle = blockedUserSubtitle.isEmpty ? "~ \(contact.fullName)" : blockedUserSubtitle
        
        return VStack(spacing: 0) {
            VStack(spacing: 0) {
                // Name TextView (matching Android originalNumber)
                Text(displayName)
                    .font(.custom("Inter18pt-Medium", size: 15)) // android:textSize="15sp" android:fontFamily="@font/inter_medium"
                    .foregroundColor(Color("TextColor")) // style="@style/TextColor"
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8) // android:layout_marginTop="8dp"
                    .onAppear {
                        print("🚫 [BLOCK] ✅ Block card view content appeared")
                        print("🚫 [BLOCK] Display Name: '\(displayName)', Subtitle: '\(displaySubtitle)'")
                        print("🚫 [BLOCK] Block status - isUserBlocked: \(isUserBlocked), showBlockCard: \(showBlockCard)")
                    }
                
                // Subtitle TextView (matching Android originalName)
                Text(displaySubtitle)
                    .font(.custom("Inter18pt-Regular", size: 10)) // android:textSize="10sp" android:fontFamily="@font/inter"
                    .foregroundColor(Color("TextColor")) // style="@style/TextColor"
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                
                // Buttons container (matching Android LinearLayout with originalDelete and originalAdd)
                HStack(spacing: 25) { // android:layout_marginStart="25dp" for second button
                    // Block button (matching Android originalDelete)
                    Button(action: {
                        handleBlockUser()
                    }) {
                        HStack(spacing: 5) { // android:drawablePadding="2dp" + marginStart="5dp"
                            Image("unblock") // android:src="@drawable/unblock"
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20) // android:layout_width="20dp" android:layout_height="20dp"
                                .foregroundColor(.red) // app:tint="@color/red"
                            
                            Text("Block") // android:text="Block"
                                .font(.custom("Inter18pt-Regular", size: 14)) // android:textSize="14sp" android:fontFamily="@font/inter"
                                .foregroundColor(.red) // android:textColor="@color/red"
                        }
                        .padding(.horizontal, 12) // android:layout_marginHorizontal="12dp"
                        .padding(.vertical, 8) // android:padding="8dp"
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8) // Matching gallary_bgcontent drawable
                            .fill(Color("BackgroundColor"))
                    )
                    
                    // Add button (matching Android originalAdd)
                    Button(action: {
                        handleAddUser()
                    }) {
                        HStack(spacing: 5) { // android:drawablePadding="2dp" + marginStart="5dp"
                            Image("addperson") // android:src="@drawable/addperson"
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20) // android:layout_width="20dp" android:layout_height="20dp"
                                .foregroundColor(Color("green_call")) // app:tint="@color/green_call"
                            
                            Text("Add") // android:text="Add"
                                .font(.custom("Inter18pt-Regular", size: 14)) // android:textSize="14sp" android:fontFamily="@font/inter"
                                .foregroundColor(Color("green_call")) // android:textColor="@color/green_call"
                        }
                        .padding(.horizontal, 12) // android:layout_marginHorizontal="12dp"
                        .padding(.vertical, 8) // android:padding="8dp"
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8) // Matching gallary_bgcontent drawable
                            .fill(Color("BackgroundColor"))
                    )
                }
                .padding(.top, 20) // android:layout_marginTop="20dp"
                .frame(maxWidth: .infinity)
            }
            .padding(15) // android:padding="15dp"
        }
        .background(
            RoundedRectangle(cornerRadius: 20) // app:cardCornerRadius="20dp"
                .fill(Color("chattingMessageBox")) // app:cardBackgroundColor="@color/chattingMessageBox"
        )
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2) // app:cardElevation="0dp" but subtle shadow for depth
    }
    
    // MARK: - Date View (matching Android datelyt)
    private var dateView: some View {
        HStack(spacing: 0) {
            // Left divider line (matching Android View with layout_weight="1")
            Rectangle()
                .fill(Color(red: 0xDE/255.0, green: 0xDD/255.0, blue: 0xDD/255.0))
                .frame(height: 1)
                .opacity(0) // invisible (matching Android visibility="invisible")
                .frame(maxWidth: .infinity)
                .padding(.trailing, 10)
            
            // Date card (matching Android CardView with elevation)
            VStack(spacing: 0) {
                Text(dateText)
                    .font(.custom("Inter18pt-Regular", size: 10))
                    .foregroundColor(Color("TextColor"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color("cardBackgroundColornew"))
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4) // Elevation shadow (matching Android CardView elevation)
            )
            .padding(5)
            
            // Right divider line (matching Android View with layout_weight="1")
            Rectangle()
                .fill(Color(red: 0xDE/255.0, green: 0xDD/255.0, blue: 0xDD/255.0))
                .frame(height: 1)
                .opacity(0) // invisible (matching Android visibility="invisible")
                .frame(maxWidth: .infinity)
                .padding(.leading, 10)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Scroll Down Button
    private var scrollDownButton: some View {
        Button(action: {
            print("📜 [SCROLL] Scroll down button tapped - allowAnimatedScroll: \(allowAnimatedScroll), messages.count: \(messages.count)")
            
            // Light haptic feedback (Android-style tap vibration)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            // Scroll to the last message if available
            scrollToBottom(animated: allowAnimatedScroll)
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
    
    // MARK: - Bottom Input View
    private var bottomInputView: some View {
        VStack(spacing: 0) {
            // Block container (shown when current user has blocked the other user - matching Android block_container)
            // Android: binding.blockContainer.setVisibility(View.VISIBLE) when block = true
            // Note: When isBlockedByUser is true, Android just disables UI, doesn't show block container
            // Show when user is blocked (bottom container with Clear All and Unblock)
            // This should always show when user is blocked, regardless of contact saved status
            if isUserBlocked && showBlockCard {
                blockContainerView
                    .onAppear {
                        print("🚫 [BLOCK CONTAINER] ✅ Bottom container (blockContainerView) appeared - isUserBlocked: \(isUserBlocked), showBlockCard: \(showBlockCard)")
                    }
            } else {
                // Debug: Log why container is not showing
                let _ = print("🚫 [BLOCK CONTAINER] 🚫 Bottom container NOT showing - isUserBlocked: \(isUserBlocked), showBlockCard: \(showBlockCard)")
            }
            
            // Message input container (messageboxContainer) - hide when current user blocked other user
            // Android: binding.messageboxContainer.setVisibility(View.GONE) when block = true
            // When isBlockedByUser is true, Android disables the input but doesn't hide it completely
            if !isUserBlocked {
                messageInputContainer
                    .disabled(isBlockedByUser) // Disable input when blocked by user (matching Android)
            }
        }
        .background(Color("edittextBg"))
    }
    
    private var blockContainerView: some View {
        // Main container (matching Android block_container LinearLayout)
        VStack(spacing: 0) {
            // Inner horizontal container (matching Android LinearLayout with horizontal orientation)
            HStack(spacing: 0) {
                // Clear All button container (matching Android LinearLayout with gallary_bgcontent)
                HStack(spacing: 0) {
                    Button(action: {
                        // Show clear chat dialog (matching Android blockClearAll onClick)
                        print("🚫 [BLOCK] Clear All button tapped")
                        showClearChatDialog = true
                    }) {
                        // Button content (matching Android LinearLayoutCompat with custome_ripple_circle2)
                        HStack(spacing: 5) { // android:layout_marginStart="5dp" for text
                            Image("deleteicon")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20) // android:layout_width="20dp" android:layout_height="20dp"
                                .foregroundColor(.red) // app:tint="@color/red"
                            
                            Text("Clear All")
                                .font(.custom("Inter18pt-Regular", size: 14)) // android:fontFamily="@font/inter" android:textSize="14sp"
                                .fontWeight(.bold) // android:textStyle="bold"
                                .foregroundColor(.red) // android:textColor="@color/red"
                        }
                        .padding(.horizontal, 12) // android:layout_marginHorizontal="12dp"
                        .padding(.vertical, 8) // android:padding="8dp"
                    }
                    .buttonStyle(PlainButtonStyle()) // Remove default button styling
                }
                .background(
                    RoundedRectangle(cornerRadius: 8) // Matching gallary_bgcontent drawable
                        .fill(Color("BackgroundColor"))
                )
                
                // Spacer between buttons (matching Android layout_marginStart="50dp")
                Spacer()
                    .frame(width: 50)
                
                // Unblock button container (matching Android LinearLayout with gallary_bgcontent)
                HStack(spacing: 0) {
                    Button(action: {
                        // Unblock user functionality (matching Android blockUnblock onClick)
                        // This button is shown when current user has blocked the other user (isUserBlocked = true)
                        print("🚫 [BLOCK] Unblock button tapped - isUserBlocked: \(isUserBlocked), isBlockedByUser: \(isBlockedByUser)")
                        let receiverUid = contact.uid
                        let uid = Constant.SenderIdMy
                        
                        // Only unblock if current user has blocked the other user (matching Android blockUnblock onClick)
                        if isUserBlocked {
                            // Unblock the other user (matching Android Webservice.unblockUser)
                            print("🚫 [BLOCK] Unblocking user - UID: \(uid), Blocked UID: \(receiverUid)")
                            ApiService.unblockUser(uid: uid, blockedUid: receiverUid) { [self] success, message in
                                DispatchQueue.main.async {
                                    if success {
                                        isUserBlocked = false
                                        showBlockCard = false
                                        print("🚫 [BLOCK] ✅ User unblocked successfully")
                                        // No toast shown (matching Android behavior)
                                    } else {
                                        print("🚫 [BLOCK] 🚫 Failed to unblock user: \(message)")
                                        Constant.showToast(message: "Failed to unblock user")
                                    }
                                }
                            }
                        } else {
                            print("🚫 [BLOCK] ⚠️ Cannot unblock - current user has not blocked the other user")
                        }
                    }) {
                        // Button content (matching Android LinearLayoutCompat with custome_ripple_circle2)
                        HStack(spacing: 5) { // android:layout_marginStart="5dp" for text
                            Image("unblock") // android:src="@drawable/unblock"
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20) // android:layout_width="20dp" android:layout_height="20dp"
                                .foregroundColor(Color("green_call")) // app:tint="@color/green_call"
                            
                            Text("Unblock")
                                .font(.custom("Inter18pt-Regular", size: 14)) // android:fontFamily="@font/inter" android:textSize="14sp"
                                .fontWeight(.bold) // android:textStyle="bold"
                                .foregroundColor(Color("green_call")) // android:textColor="@color/green_call"
                        }
                        .padding(.horizontal, 12) // android:layout_marginHorizontal="12dp"
                        .padding(.vertical, 8) // android:padding="8dp"
                    }
                    .buttonStyle(PlainButtonStyle()) // Remove default button styling
                }
                .background(
                    RoundedRectangle(cornerRadius: 8) // Matching gallary_bgcontent drawable
                        .fill(Color("BackgroundColor"))
                )
            }
            .frame(maxWidth: .infinity) // match_parent width
        }
        .frame(maxWidth: .infinity) // match_parent width
        .padding(20) // android:padding="20dp"
        .background(Color("chattingMessageBox")) // android:background="@color/chattingMessageBox"
    }
    
    private var messageInputContainer: some View {
        // Outer vertical container (messageboxContainer) - orientation="vertical"
        VStack(spacing: 0) {
            // Inner horizontal container - padding="2dp"
            HStack(alignment: .bottom, spacing: 0) {
                AnyView(messageInputStack)
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
            if showEmojiPicker {
                emojiPickerView
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

    private var messageInputStack: some View {
        VStack(spacing: 0) {
            // Reply layout (replylyout) - marginStart="2dp" marginTop="2dp" marginEnd="2dp"
            // Note: replyLayoutView already has .padding(.horizontal, 2) inside, so no need to add it here
            if showReplyLayout {
                replyLayoutView
                    .padding(.top, 2) // Only add top margin, horizontal is already in replyLayoutView
            }
            
            messageInputRow
        }
    }
    
    private var messageInputRow: some View {
        // Main input layout (editLyt) - marginStart="2dp" marginEnd="2dp"
        // Structure matches reply layout: outer margin, then background, then inner padding
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
                            updateMessageText(newValue)
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
            // Use native uneven corners to avoid UIBezierPath issues
            UnevenRoundedRectangle(
                cornerRadii: .init(
                    topLeading: showReplyLayout ? 0 : 20,
                    bottomLeading: 20,
                    bottomTrailing: 20,
                    topTrailing: showReplyLayout ? 0 : 20
                )
            )
            .fill(Color("message_box_bg"))
        )
        .zIndex(1) // Ensure TextField area has higher z-index than gallery picker
    }
    
    private var replyLayoutView: some View {
        // Get color based on sender/receiver (matching Android HalfSwipeCallback logic)
        let replyColor: Color = isReplyFromSender ? Color(hex: Constant.themeColor) : Color("black_white_cross")
        
        return ZStack(alignment: .topLeading) {
            // Layer 1: Blue background layer (matching Android LinearLayout id="view")
            // marginHorizontal="6dp" marginVertical="7dp" backgroundTint="@color/blue"
            // This layer is larger (6dp margins) and creates the blue border effect
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 20, bottomLeading: 0, bottomTrailing: 0, topTrailing: 20)
            )
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
                        // Text content - marginStart="10dp" (vertical bar is hidden in Android with visibility="gone")
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
                                } else if let ext = replyFileExtension, ["mp3", "wav", "flac", "aac", "ogg", "oga", "m4a", "wma", "alac", "aiff"].contains(ext.lowercased()) {
                                    Image(systemName: "music.note")
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
                    
                    // Right side - thumbnails/icons and cancel button (matching Android layout)
                    HStack(spacing: 12) {
                        // Image thumbnail for img/video (matching Android imgcardview - 35dp)
                        if (replyDataType == Constant.img || replyDataType == Constant.video), let imageUrl = replyImageUrl, !imageUrl.isEmpty {
                            AsyncImage(url: URL(string: imageUrl)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                case .failure(_), .empty:
                                    Color.gray.opacity(0.3)
                                @unknown default:
                                    Color.gray.opacity(0.3)
                                }
                            }
                            .frame(width: 35, height: 35) // 35dp x 35dp
                            .clipShape(RoundedRectangle(cornerRadius: 20)) // cardCornerRadius="20dp"
                        }
                        
                        // Audio icon (matching Android imgcardviewVoiceAudio - 22dp)
                        if replyDataType == Constant.voiceAudio {
                            Image(systemName: "mic.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 22, height: 22) // 22dp x 22dp
                                .foregroundColor(Color("TextColor"))
                        }
                        
                        // Music icon (matching Android imgcardviewVoiceMusic - 20dp)
                        if let ext = replyFileExtension, ["mp3", "wav", "flac", "aac", "ogg", "oga", "m4a", "wma", "alac", "aiff"].contains(ext.lowercased()) {
                            Image(systemName: "music.note")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20) // 20dp x 20dp
                                .foregroundColor(Color("TextColor"))
                        }
                        
                        // Contact circle (matching Android contactContainer - 35dp)
                        if replyDataType == Constant.contact, let contactName = replyContactName, !contactName.isEmpty {
                            let firstLetter = String(contactName.prefix(1)).uppercased()
                            ZStack {
                                Circle()
                                    .fill(Color("contact_gradient_circle"))
                                    .frame(width: 35, height: 35) // 35dp x 35dp
                                
                                Text(firstLetter)
                                    .font(.custom("Inter18pt-Regular", size: 11))
                                    .foregroundColor(isReplyFromSender ? Color.black : Color.white)
                            }
                        }
                        
                        // PDF icon (matching Android pageLyt - 26dp)
                        if replyDataType == Constant.doc, let ext = replyFileExtension, ext.lowercased() == "pdf" {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color("pagesvg"))
                                    .frame(width: 26, height: 26) // 26dp x 26dp
                                
                                Text("PDF")
                                    .font(.custom("Inter18pt-Bold", size: 7.5))
                                    .foregroundColor(Color("modetheme2"))
                                    .textCase(.uppercase)
                            }
                        }
                        
                        // Cancel button matching Android ImageView cancel
                        // Uses theme color for sender, black_white_cross for receiver
            Button(action: {
                withAnimation {
                    showReplyLayout = false
                    replyMessage = ""
                    replySenderName = ""
                    isReplyFromSender = false
                    replyImageUrl = nil
                    replyContactName = nil
                    replyFileExtension = nil
                    replyMessageId = nil
                }
            }) {
                Image("crosssvg")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                                .frame(width: 22, height: 22) // width="22dp" height="22dp"
                                .foregroundColor(replyColor) // Theme color for sender, black_white_cross for receiver
            }
                        .padding(.trailing, 12) // marginEnd="12dp" (approximate from layout)
                        .padding(.vertical, 5) // margin="5dp" for button
        }
                }
                .padding(7) // layout_margin="7dp"
                .frame(height: 55) // height="55dp"
            }
        .background(
            // White layer background (matching backgroundTint="@color/circlebtnhover")
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 20, bottomLeading: 0, bottomTrailing: 0, topTrailing: 20)
            )
            .fill(Color("message_box_bg_3"))
        )
            .padding(.horizontal, 7) // margin="7dp" - creates smaller white layer on top
            .padding(.vertical, 7) // margin="7dp"
        }
        .padding(.horizontal, 2) // marginStart="2dp" marginEnd="2dp"
        .padding(.top, 2) // marginTop="2dp"
        .background(
            // Outer background (matching Android replylyout background)
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 20, bottomLeading: 0, bottomTrailing: 0, topTrailing: 20)
            )
            .fill(Color("message_box_bg_3"))
        )
    }
    
    // MARK: - Emoji Picker View (matching Android activity_personalmsg_limit_msg.xml)
    private var emojiPickerView: some View {
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
                .padding(.bottom,10)
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
                            isSearchFieldFocused = true
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
                    
                    // For visible button (View Profile)
                    Button(action: {
                        withAnimation {
                            showMenu = false
                        }
                        // Navigate to UserInfoScreen (matching Android userInfoScreen)
                        // Use immediate navigation without delay for better UX
                        navigateToUserInfo = true
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
                    
                    // Block button (hidden if chatting with yourself - matching Android logic)
                    if Constant.SenderIdMy != contact.uid {
                        Button(action: {
                            withAnimation {
                                showMenu = false
                            }
                            // Handle block/unblock (matching Android blockUser onClick)
                            handleBlockUserClick()
                        }) {
                            HStack {
                                Text(isUserBlocked ? "Unblock" : "Block")
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
    
    // MARK: - Helper Functions
    private func handleBackTap() {
        withAnimation {
            isPressed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // If search is active, hide search and show name (matching Android onBackPressed - searchEt is focused)
            if showSearch {
                withAnimation {
                    showSearch = false
                    searchText = ""
                    isSearching = false
                    filteredMessages.removeAll()
                }
                isSearchFieldFocused = false
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                isPressed = false
                return
            }
            
            // If multi-select mode is active, exit it first (matching Android back button behavior)
            if isMultiSelectMode {
                exitMultiSelectMode()
                isPressed = false
                return
            }
            
            // If gallery picker is open, hide it first (two-step back behavior)
            if showGalleryPicker {
                withAnimation {
                    showGalleryPicker = false
                }
                isPressed = false
                return
            }
            
            // If emoji picker is open, hide it first (two-step back behavior)
            if showEmojiPicker {
                withAnimation {
                    showEmojiPicker = false
                }
                isPressed = false
                return
            }
            
            // If gallery picker is closed, navigate back
            let receiverUid = contact.uid
            let uid = Constant.SenderIdMy
            fetchIndividualChattingLimit(senderId: uid, receiverUid: receiverUid)
            dismiss()
            isPressed = false
        }
    }
    
    // MARK: - Fetch Emojis from API (matching Android fetch_emoji_data)
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
            let receiverRoom = getReceiverRoom()
            fetchMessages(receiverRoom: receiverRoom) {
                // Don't scroll when search is cleared (matching Android)
            }
        }
    }
    
    // MARK: - Search Messages (matching Android searchMessages function)
    private func searchMessages(query: String) {
        let receiverRoom = getReceiverRoom()
        let database = Database.database().reference()
        let chatRef = database.child(Constant.CHAT).child(receiverRoom)
        
        print("🔍 [SEARCH] Searching for: '\(query)' in room: \(receiverRoom)")
        
        // Query all messages once (matching Android addListenerForSingleValueEvent)
        chatRef.observeSingleEvent(of: .value) { snapshot in
            var foundMessages: [ChatMessage] = []
            
            guard snapshot.exists() else {
                print("🔍 [SEARCH] No messages found in room")
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
                        // Convert to ChatMessage using existing parser
                        if let chatMessage = self.parseMessageFromDict(messageDict, messageId: childKey) {
                            foundMessages.append(chatMessage)
                        }
                    }
                }
            }
            
            // Update filtered messages on main thread
            DispatchQueue.main.async {
                // Sort by timestamp (newest first)
                self.filteredMessages = foundMessages.sorted { $0.timestamp > $1.timestamp }
                print("🔍 [SEARCH] Found \(self.filteredMessages.count) messages matching '\(query)'")
            }
        } withCancel: { error in
            print("🚫 [SEARCH] Error searching messages: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.filteredMessages = []
            }
        }
    }
    
    // MARK: - Handle Emoji Search Text Changed (matching Android TextWatcher)
    private func handleEmojiSearchTextChanged(_ newValue: String) {
        // Sync text between top and bottom search boxes (prevent infinite loop)
        if !isSyncingEmojiText {
            isSyncingEmojiText = true
            // Text is already synced via @State binding, just filter
            filterEmojis(newValue)
            isSyncingEmojiText = false
        }
    }
    
    // MARK: - Filter Emojis (matching Android filterEmojis)
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
    
    // MARK: - Handle Message Box Tap (matching Android messageBox.setOnTouchListener)
    private func handleMessageBoxTap() {
        print("🔵 [MESSAGE_BOX_TAP] handleMessageBoxTap() called")
        print("🔵 [MESSAGE_BOX_TAP] showGalleryPicker: \(showGalleryPicker)")
        print("🔵 [MESSAGE_BOX_TAP] showEmojiPicker: \(showEmojiPicker)")
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
        if showEmojiPicker {
            print("🔵 [MESSAGE_BOX_TAP] Emoji picker is visible - hiding it")
            withAnimation {
                showEmojiPicker = false
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
                    self.showEmojiPicker = false
                }
            }
        } else {
            // If keyboard is not open, just toggle gallery picker
            print("🟢 [GALLERY_BUTTON] Keyboard not open - toggling gallery picker")
            withAnimation {
                showGalleryPicker.toggle()
                showEmojiPicker = false
            }
        }
    }
    
    // MARK: - Handle Emoji Button Click (matching Android emoji button behavior)
    private func handleEmojiButtonClick() {
        print("🟡 [EMOJI_BUTTON] Emoji button clicked")
        print("🟡 [EMOJI_BUTTON] isMessageFieldFocused: \(isMessageFieldFocused)")
        print("🟡 [EMOJI_BUTTON] showEmojiPicker: \(showEmojiPicker)")
        
        // If keyboard is open (message field is focused), hide it first
        if isMessageFieldFocused {
            print("🟡 [EMOJI_BUTTON] Keyboard is open - hiding it first")
            isMessageFieldFocused = false
            // Hide keyboard and then show emoji picker after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                print("🟡 [EMOJI_BUTTON] Showing emoji picker after keyboard hide")
                withAnimation {
                    self.showEmojiPicker = true
                    self.showGalleryPicker = false
                }
                // Fetch emojis when picker is shown
                self.fetchEmojis()
            }
        } else {
            // If keyboard is not open, just toggle emoji picker
            print("🟡 [EMOJI_BUTTON] Keyboard not open - toggling emoji picker")
            let willShowEmojiPicker = !showEmojiPicker
            withAnimation {
                showEmojiPicker.toggle()
                showGalleryPicker = false
            }
            // Fetch emojis when picker is shown
            if willShowEmojiPicker {
                fetchEmojis()
            }
        }
    }
    
    // MARK: - Firebase Message Fetching (matching Android fetchMessages)
    
    /// Fetch messages from Firebase (matching Android fetchMessages with OnMessagesFetchedListener)
    private func fetchMessages(receiverRoom: String, listener: (() -> Void)? = nil) {
        fetchMessages(receiverRoom: receiverRoom, shouldScrollToLast: false, listener: listener)
    }
    
    /// Fetch messages from Firebase with scroll option (matching Android fetchMessages overload)
    private func fetchMessages(receiverRoom: String, shouldScrollToLast: Bool, listener: (() -> Void)?) {
        // Check if already loading (matching Android isLoading check)
        if isLoading {
            print("📱 [fetchMessages] Already loading, skipping fetch.")
            listener?()
            return
        }
        
        // If we already have messages (cached data), don't show loader (matching Android)
        if !messages.isEmpty {
            print("📱 [fetchMessages] Messages already available, skipping network fetch")
            listener?()
            return
        }
        
        isLoading = true
        print("📱 [fetchMessages] Fetching messages for room: \(receiverRoom)")
        
        if !initialLoadDone {
            // 🔹 Phase 1: Load last 10 messages ordered by timestamp (matching Android)
            print("📱 [fetchMessages] Phase 1: Initial load (last 10 messages by timestamp).")
            
            let database = Database.database().reference()
            let chatPath = "\(Constant.CHAT)/\(receiverRoom)"
            database.child(chatPath).keepSynced(true)
            
            let limitedQuery = database.child(chatPath)
                .queryOrdered(byChild: "timestamp")
                .queryLimited(toLast: 10)
            
            limitedQuery.observeSingleEvent(of: .value) { snapshot in
                print("📱 [fetchMessages] Fetched initial data: \(snapshot.childrenCount) messages.")
                
                var tempList: [ChatMessage] = []
                
                guard let children = snapshot.children.allObjects as? [DataSnapshot] else {
                    print("⚠️ [fetchMessages] No children found")
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.initialLoadDone = true
                        self.updateEmptyState(isEmpty: tempList.isEmpty)
                        listener?()
                    }
                    return
                }
                
                for child in children {
                    let childKey = child.key
                    
                    // Skip typing indicator node - it's not a message (matching Android)
                    if childKey == "typing" {
                        print("📱 [fetchMessages] Skipping typing indicator node")
                        continue
                    }
                    
                    // Skip invalid keys (matching Android)
                    if childKey.count <= 1 || childKey == ":" {
                        print("📱 [fetchMessages] Skipping invalid key: \(childKey)")
                        continue
                    }
                    
                    do {
                        // Parse message from Firebase snapshot (matching Android child.getValue(messageModel.class))
                        if let messageDict = child.value as? [String: Any] {
                            if let model = self.parseMessageFromDict(messageDict, messageId: childKey) {
                                // Add Text, Image, Video, Document, and Contact datatype messages
                                if model.dataType == Constant.Text || model.dataType == Constant.img || model.dataType == Constant.video || model.dataType == Constant.doc || model.dataType == Constant.contact || model.dataType == Constant.voiceAudio {
                                    tempList.append(model)
                                }
                            }
                        }
                    } catch {
                        print("🚫 [fetchMessages] Error parsing message for key: \(childKey), error: \(error.localizedDescription)")
                        continue
                    }
                }
                
                // Sort by timestamp (matching Android Collections.sort)
                tempList.sort { $0.timestamp < $1.timestamp }
                
                // Store message IDs from initial load to prevent duplicates when listener attaches
                let initialMessageIds = Set(tempList.map { $0.id })
                
                // Get oldest timestamp from initial load (to skip older messages from listener)
                let oldestTimestamp = tempList.first?.timestamp ?? 0
                
                // 🔹 Directly update messages array (matching Android chatAdapter.setMessages)
                DispatchQueue.main.async {
                    print("📱 [fetchMessages] Updating messages array with \(tempList.count) messages")
                    self.messages = tempList
                    
                    // Store initially loaded message IDs to prevent duplicates
                    self.initiallyLoadedMessageIds = initialMessageIds
                    self.oldestInitialTimestamp = oldestTimestamp
                    // Set lastTimestamp for pagination (oldest message timestamp)
                    self.lastTimestamp = oldestTimestamp
                    print("📱 [fetchMessages] Stored \(initialMessageIds.count) initial message IDs to prevent duplicates")
                    print("📱 [fetchMessages] Oldest initial timestamp: \(oldestTimestamp)")
                    
                    // Update unique dates
                    for message in tempList {
                        if let date = message.currentDate {
                            self.uniqueDates.insert(date)
                        }
                    }
                    
                    // Auto scroll to bottom ONLY on first time onCreate (matching Android)
                    if shouldScrollToLast && !tempList.isEmpty {
                        // Scroll will be handled by ScrollViewReader in messageListView
                    }
                    
                    self.updateEmptyState(isEmpty: tempList.isEmpty)
                    print("📱 [fetchMessages] \(tempList.isEmpty ? "Message list is empty after fetch, showing valuable view" : "Messages found, hiding valuable view")")
                    
                    self.isLoading = false
                    self.initialLoadDone = true
                    
                    // 🔁 Attach continuous listener after a delay (matching Android Handler.postDelayed)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.attachFullListener(receiverRoom: receiverRoom)
                    }
                    
                    listener?()
                }
            } withCancel: { error in
                self.isLoading = false
                DispatchQueue.main.async {
                    self.updateEmptyState(isEmpty: self.messages.isEmpty)
                }
                print("🚫 [fetchMessages] Error fetching initial messages: \(error.localizedDescription)")
                
                // Don't show toast for network errors to avoid spam (matching Android)
                // Check if it's a network error by checking error domain
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
            // Already loaded once, just make sure full listener is attached (matching Android)
            print("📱 [fetchMessages] Phase 2: Full listener already attached.")
            // 🚀 ALWAYS ATTACH LISTENER FOR REAL-TIME MESSAGES
            attachFullListener(receiverRoom: receiverRoom)
            listener?()
        }
    }
    
    /// Attach full listener for real-time message updates (matching Android attachFullListener)
    private func attachFullListener(receiverRoom: String) {
        if fullListenerAttached {
            print("📱 [attachFullListener] Full listener already attached, skipping.")
            return // Prevent duplicate listeners
        }
        
        print("📱 [attachFullListener] 🚀 Attaching full listener to room: \(receiverRoom)")
        fullListenerAttached = true
        
        let database = Database.database().reference()
        let chatPath = "\(Constant.CHAT)/\(receiverRoom)"
        database.child(chatPath).keepSynced(true)
        
        let fullQuery = database.child(chatPath)
            .queryOrdered(byChild: "timestamp")
        
        // Listen for child added events (matching Android addChildEventListener.onChildAdded)
        firebaseChildListenerHandle = fullQuery.observe(.childAdded) { snapshot in
            print("📱 [onChildAdded] 🚀 REAL-TIME: Child added with key: \(snapshot.key)")
            self.handleChildAdded(snapshot: snapshot, receiverRoom: receiverRoom)
        }
        
        // Listen for child changed events (matching Android onChildChanged)
        fullQuery.observe(.childChanged) { snapshot in
            let changedKey = snapshot.key
            
            // Skip typing indicator node (matching Android)
            if changedKey == "typing" {
                print("📱 [onChildChanged] Skipping typing indicator node")
                return
            }
            
            if let messageDict = snapshot.value as? [String: Any],
               let updatedModel = self.parseMessageFromDict(messageDict, messageId: changedKey) {
                
                // Handle Text, Image, Video, Document, and Contact datatype messages
                if updatedModel.dataType == Constant.Text || updatedModel.dataType == Constant.img || updatedModel.dataType == Constant.video || updatedModel.dataType == Constant.doc || updatedModel.dataType == Constant.contact || updatedModel.dataType == Constant.voiceAudio {
                    // Find and update existing message (matching Android)
                    if let index = self.messages.firstIndex(where: { $0.id == changedKey }) {
                        let oldModel = self.messages[index]
                        
                        // Check if message actually changed (matching Android)
                        let isChanged = oldModel.message != updatedModel.message ||
                                      oldModel.emojiCount != updatedModel.emojiCount ||
                                      oldModel.emojiModel != updatedModel.emojiModel ||
                                      oldModel.timestamp != updatedModel.timestamp ||
                                      oldModel.document != updatedModel.document ||
                                      oldModel.receiverLoader != updatedModel.receiverLoader // Check receiverLoader changes
                        
                        if isChanged {
                            DispatchQueue.main.async {
                                self.messages[index] = updatedModel
                                
                                // Log receiverLoader changes (progress bar visibility)
                                if oldModel.receiverLoader != updatedModel.receiverLoader {
                                    print("📱 [onChildChanged] receiverLoader changed from \(oldModel.receiverLoader) to \(updatedModel.receiverLoader) for message: \(changedKey)")
                                    if updatedModel.receiverLoader == 1 {
                                        print("✅ [ProgressBar] ✅ Progress bar HIDDEN - message confirmed in Firebase (receiverLoader: 0 → 1)")
                                    } else if updatedModel.receiverLoader == 0 {
                                        print("🔍 [ProgressBar] ⚠️ Progress bar SHOWN - message is pending (receiverLoader: \(oldModel.receiverLoader) → 0)")
                                    }
                                }
                                
                                print("📱 [onChildChanged] Message updated for key: \(changedKey)")
                            }
                        } else {
                            print("📱 [onChildChanged] No meaningful change → update skipped: \(changedKey)")
                        }
                    }
                }
            }
        }
        
        // Listen for child removed events (matching Android onChildRemoved)
        fullQuery.observe(.childRemoved) { snapshot in
            print("📱 [onChildRemoved] Child removed with key: \(snapshot.key)")
            self.handleChildRemoved(snapshot: snapshot)
        }
        
        // Add typing indicator listener (matching Android setupTypingListener)
        setupTypingIndicatorListener(receiverRoom: receiverRoom)
    }
    
    /// Setup typing indicator listener (matching Android setupTypingListener)
    private func setupTypingIndicatorListener(receiverRoom: String) {
        let database = Database.database().reference()
        let receiverUid = contact.uid
        let senderId = Constant.SenderIdMy
        
        // Check both possible room combinations (matching Android behavior)
        // Room 1: receiverUid + senderId (where sender saves typing indicator)
        // Room 2: senderId + receiverUid (alternative room)
        let room1 = receiverUid + senderId
        let room2 = senderId + receiverUid
        
        print("🔍 [TypingIndicator] Setting up listener for rooms:")
        print("   Room 1: \(room1)")
        print("   Room 2: \(room2)")
        print("   Current receiverRoom: \(receiverRoom)")
        
        // Listen to the room where the sender saves typing (receiverUid + senderId)
        // This is the room where messages from sender to receiver are stored
        let typingPath = "\(Constant.CHAT)/\(room1)/typing"
        
        typingRef = database.child(typingPath)
        
        // Listen for typing indicator changes
        typingListenerHandle = typingRef?.observe(.value) { snapshot in
            print("🔔 [TypingIndicator] Listener triggered - exists: \(snapshot.exists())")
            if snapshot.exists(), let typingDict = snapshot.value as? [String: Any] {
                print("📥 [TypingIndicator] Received typing data: \(typingDict.keys)")
                // Parse typing indicator message
                if let typingMessage = self.parseMessageFromDict(typingDict, messageId: "typing") {
                    print("✅ [TypingIndicator] Parsed typing message - uid: \(typingMessage.uid), my uid: \(Constant.SenderIdMy)")
                    // Only show typing indicator if it's from the other user (not ourselves)
                    if typingMessage.uid != Constant.SenderIdMy {
                        print("✅ [TypingIndicator] Adding typing indicator to message list")
                        DispatchQueue.main.async {
                            self.addTypingIndicatorToMessageList(typingMessage: typingMessage)
                        }
                    } else {
                        print("⚠️ [TypingIndicator] Ignoring typing indicator from self")
                    }
                } else {
                    print("🚫 [TypingIndicator] Failed to parse typing message from dict")
                }
            } else {
                // Typing indicator removed - remove from message list
                print("🗑️ [TypingIndicator] Typing indicator removed from Firebase")
                DispatchQueue.main.async {
                    self.removeTypingIndicatorFromMessageList()
                }
            }
        }
        
        print("✅ [TypingIndicator] Listener setup complete for path: \(typingPath)")
        
        // Also listen to alternative room path (in case messages are stored there)
        let typingPath2 = "\(Constant.CHAT)/\(room2)/typing"
        typingRef2 = database.child(typingPath2)
        
        typingListenerHandle2 = typingRef2?.observe(.value) { snapshot in
            print("🔔 [TypingIndicator] Alternative listener triggered - exists: \(snapshot.exists())")
            if snapshot.exists(), let typingDict = snapshot.value as? [String: Any] {
                print("📥 [TypingIndicator] Received typing data from alternative room: \(typingDict.keys)")
                if let typingMessage = self.parseMessageFromDict(typingDict, messageId: "typing") {
                    if typingMessage.uid != Constant.SenderIdMy {
                        print("✅ [TypingIndicator] Adding typing indicator from alternative room")
                        DispatchQueue.main.async {
                            self.addTypingIndicatorToMessageList(typingMessage: typingMessage)
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.removeTypingIndicatorFromMessageList()
                }
            }
        }
        
        print("✅ [TypingIndicator] Alternative listener setup complete for path: \(typingPath2)")
    }
    
    /// Add typing indicator to message list (matching Android addTypingIndicatorToMessageList)
    private func addTypingIndicatorToMessageList(typingMessage: ChatMessage) {
        print("📝 [TypingIndicator] addTypingIndicatorToMessageList CALLED")
        print("   typingMessage uid: \(typingMessage.uid)")
        print("   typingMessage dataType: \(typingMessage.dataType)")
        
        // Check if typing indicator already exists
        if let existingIndex = messages.firstIndex(where: { $0.dataType == Constant.TYPEINDICATOR && $0.uid == typingMessage.uid }) {
            print("⚠️ [TypingIndicator] Typing indicator already exists at position: \(existingIndex)")
            // Update existing typing indicator
            messages[existingIndex] = typingMessage
            return
        }
        
        // Add typing indicator to the end of the message list
        messages.append(typingMessage)
        print("✅ [TypingIndicator] Typing indicator added to message list")
    }
    
    /// Remove typing indicator from message list (matching Android removeTypingIndicatorFromMessageList)
    private func removeTypingIndicatorFromMessageList() {
        // Remove all typing indicator messages
        messages.removeAll { $0.dataType == Constant.TYPEINDICATOR }
        print("✅ [TypingIndicator] Typing indicator removed from message list")
    }
    
    /// Handle child added event (matching Android handleChildAdded)
    private func handleChildAdded(snapshot: DataSnapshot, receiverRoom: String) {
        guard snapshot.exists() else {
            print("⚠️ [handleChildAdded] DataSnapshot does not exist")
            return
        }
        
        let key = snapshot.key
        
        // Skip typing indicator node (matching Android)
        if key == "typing" {
            print("📱 [handleChildAdded] Skipping typing indicator node")
            return
        }
        
        // Parse message from snapshot (matching Android dataSnapshot.getValue(messageModel.class))
        guard let messageDict = snapshot.value as? [String: Any],
              var model = parseMessageFromDict(messageDict, messageId: key) else {
            print("⚠️ [handleChildAdded] Failed to parse ChatMessage for key: \(key)")
            return
        }
        
        // Handle typing indicator messages separately
        if model.dataType == Constant.TYPEINDICATOR {
            // Only show typing indicator if it's from the other user (not ourselves)
            if model.uid != Constant.SenderIdMy {
                DispatchQueue.main.async {
                    self.addTypingIndicatorToMessageList(typingMessage: model)
                }
            }
            return
        }
        
        // Handle Text, Image, Video, Document, Contact, and VoiceAudio datatype messages
        guard model.dataType == Constant.Text || model.dataType == Constant.img || model.dataType == Constant.video || model.dataType == Constant.doc || model.dataType == Constant.contact || model.dataType == Constant.voiceAudio else {
            print("📱 [handleChildAdded] Skipping unsupported message type: \(model.dataType)")
            return
        }
        
        // Remove from pending table when message is confirmed in Firebase (matching Android removePendingMessage)
        // This happens when the message appears in Firebase, meaning it was successfully sent
        let receiverUid = contact.uid
        let removed = DatabaseHelper.shared.removePendingMessage(modelId: model.id, receiverUid: receiverUid)
        if removed {
            print("✅ [PendingMessages] Removed pending message from SQLite (confirmed in Firebase): \(model.id)")
        }
        
        // 🔍 FIX: If message is from current user and already in Firebase but has receiverLoader: 0,
        // update it to 1 to stop progress bar (message is already confirmed in Firebase)
        let isSentByMe = model.uid == Constant.SenderIdMy
        if isSentByMe && model.receiverLoader == 0 {
            print("🔍 [ProgressBar] ⚠️ FIXING: Message is in Firebase but has receiverLoader: 0")
            print("🔍 [ProgressBar]   - Message ID: \(model.id.prefix(8))...")
            print("🔍 [ProgressBar]   - Message is already in Firebase (confirmed)")
            print("🔍 [ProgressBar]   - Updating receiverLoader from 0 → 1 to stop progress bar")
            
            // Update receiverLoader to 1 in Firebase to stop progress bar
            let senderId = Constant.SenderIdMy
            let receiverRoom = receiverUid + senderId
            let database = Database.database().reference()
            let receiverLoaderRef = database.child(Constant.CHAT).child(receiverRoom).child(model.id).child("receiverLoader")
            receiverLoaderRef.setValue(1) { error, _ in
                if let error = error {
                    print("🚫 [ProgressBar] Error updating receiverLoader in handleChildAdded: \(error.localizedDescription)")
                } else {
                    print("✅ [ProgressBar] ✅ Fixed receiverLoader: 0 → 1 for message: \(model.id.prefix(8))... (progress bar will stop)")
                }
            }
            
            // Update local model immediately to stop progress bar in UI
            model.receiverLoader = 1
            print("🔍 [ProgressBar] ✅ Updated local model receiverLoader to 1 (progress bar will stop immediately)")
        }
        
        // Check if message already exists in current list (matching Android duplicate check)
        // Android: checks if message exists in messageList, if not, adds it
        // We check here to prevent processing, but still allow updates in the main block below
        let messageExists = messages.contains(where: { $0.id == model.id })
        
        if messageExists {
            // Message already exists - this might be a duplicate from listener firing for existing messages
            // But we still process it in case it's an update (matching Android behavior)
            print("📱 [handleChildAdded] Message already exists in list: \(model.id), will process as potential update")
        }
        
        // Ensure modelId is set (matching Android)
        if model.id.isEmpty && !key.isEmpty {
            // Note: ChatMessage.id is immutable, so we recreate if needed
            // In practice, the id should already be set from parseMessageFromDict
        }
        
        print("📱 [handleChildAdded] Message ID: \(model.id)")
        print("📱 [handleChildAdded] Message type: \(model.dataType)")
        print("📱 [handleChildAdded] Message content: \(model.message)")
        
        // Check for duplicates and remove if exists (matching Android)
        DispatchQueue.main.async {
            var updatedMessageList = self.messages
            
            // Remove existing message with same ID if it exists (matching Android)
            if let existingIndex = updatedMessageList.firstIndex(where: { $0.id == model.id }) {
                updatedMessageList.remove(at: existingIndex)
                print("📱 [handleChildAdded] Duplicate found, removed message with ID: \(model.id)")
            }
            
            // Handle unique dates (matching Android uniqueDates logic)
            let uniqDate = model.currentDate ?? ""
            let isNewDate = self.uniqueDates.insert(uniqDate).inserted
            let finalDate = isNewDate ? uniqDate : ":\(uniqDate)"
            
            // Create mutable copy of model with updated date
            var updatedModel = model
            updatedModel.currentDate = finalDate
            
            // Add new message
            updatedMessageList.append(updatedModel)
            
            // Sort messages by timestamp (matching Android Collections.sort)
            updatedMessageList.sort { $0.timestamp < $1.timestamp }
            
            print("📱 [handleChildAdded] Updated messageList size: \(updatedMessageList.count)")
            print("🔵 [SCROLL_DEBUG] handleChildAdded - messages updated, new count: \(updatedMessageList.count), hasScrolledToBottom: \(self.hasScrolledToBottom), hasPerformedInitialScroll: \(self.hasPerformedInitialScroll)")
            
            // Update messages array (matching Android messageList.clear() and addAll())
            // Force UI update by assigning new array (matching Android chatAdapter.updateMessageListEfficiently)
            self.messages = updatedMessageList
            
            // Trigger UI refresh explicitly (matching Android notifyItemInserted/notifyDataSetChanged)
            // SwiftUI should auto-update, but we ensure it happens immediately
            print("📱 [handleChildAdded] ✅ UI UPDATE - Messages array updated, count: \(updatedMessageList.count)")
            
            // If initial load is done but initial scroll hasn't been performed yet, wait for listener to finish
            // This ensures we scroll only once to the actual last message (like WhatsApp)
            if self.initialLoadDone && !self.hasPerformedInitialScroll {
                // Cancel previous debounce
                self.listenerMessagesDebounceWorkItem?.cancel()
                
                // Wait for listener to finish adding messages, then mark for initial scroll
                let workItem = DispatchWorkItem {
                    guard !self.hasPerformedInitialScroll else { return }
                    guard let lastId = self.messages.last?.id else { return }
                    print("🟢 [SCROLL_DEBUG] Listener finished - will perform single initial scroll to: \(lastId), total: \(self.messages.count)")
                    self.hasPerformedInitialScroll = true
                    self.pendingInitialScrollId = lastId
                }
                self.listenerMessagesDebounceWorkItem = workItem
                // Wait 1 second after last message addition to ensure listener is done
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
            }
            
            // Check if message is from receiver (matching Android isReceiverMessage check)
            let currentUid = Constant.SenderIdMy
            let isReceiverMessage = model.uid != currentUid
            
            // Auto scroll for receiver messages (matching Android real-time scroll)
            if isReceiverMessage {
                // Scroll only for truly new messages, not initial listener backfill
                if !self.initiallyLoadedMessageIds.contains(model.id) {
                    // Scroll will be handled by ScrollViewReader in messageListView
                    // Set pending scroll ID for real-time messages (matching Android scrollToPosition)
                    self.pendingInitialScrollId = model.id
                    print("📱 [handleChildAdded] 🚀 FAST REAL-TIME SCROLL - New receiver message, ID: \(model.id)")
                } else {
                    print("📱 [handleChildAdded] Skipping scroll for initial message: \(model.id)")
                }
            }
            
            // Update empty state
            self.updateEmptyState(isEmpty: updatedMessageList.isEmpty)
        }
    }
    
    /// Handle child removed event (matching Android handleChildRemoved)
    private func handleChildRemoved(snapshot: DataSnapshot) {
        let key = snapshot.key
        
        DispatchQueue.main.async {
            // Remove message from list if it exists (matching Android)
            if let index = self.messages.firstIndex(where: { $0.id == key }) {
                self.messages.remove(at: index)
                print("📱 [handleChildRemoved] Removed message with key: \(key)")
                self.updateEmptyState(isEmpty: self.messages.isEmpty)
            }
        }
    }
    
    /// Parse message from Firebase dictionary (matching Android messageModel parsing)
    private func parseMessageFromDict(_ dict: [String: Any], messageId: String) -> ChatMessage? {
        do {
            // Extract all fields matching Android messageModel structure
            let uid = dict["uid"] as? String ?? ""
            let message = dict["message"] as? String ?? ""
            let time = dict["time"] as? String ?? ""
            let document = dict["document"] as? String ?? ""
            let dataType = dict["dataType"] as? String ?? Constant.Text
            let fileExtension = dict["extension"] as? String
            let name = dict["name"] as? String
            let phone = dict["phone"] as? String
            let micPhoto = dict["micPhoto"] as? String
            let miceTiming = dict["miceTiming"] as? String
            let userName = dict["userName"] as? String
            // Handle both receiverId and receiverUid (Android uses receiverUid in Firebase)
            let receiverId = (dict["receiverId"] as? String) ?? (dict["receiverUid"] as? String) ?? ""
            let replytextData = dict["replytextData"] as? String
            let replyKey = dict["replyKey"] as? String
            let replyType = dict["replyType"] as? String
            let replyOldData = dict["replyOldData"] as? String
            let replyCrtPostion = dict["replyCrtPostion"] as? String
            let forwaredKey = dict["forwaredKey"] as? String
            let groupName = dict["groupName"] as? String
            let docSize = dict["docSize"] as? String
            let fileName = dict["fileName"] as? String
            let thumbnail = dict["thumbnail"] as? String
            let fileNameThumbnail = dict["fileNameThumbnail"] as? String
            let caption = dict["caption"] as? String
            let notification = dict["notification"] as? Int ?? 1
            let currentDate = dict["currentDate"] as? String
            let emojiCount = dict["emojiCount"] as? String
            let timestamp = (dict["timestamp"] as? TimeInterval) ?? Date().timeIntervalSince1970
            let imageWidth = dict["imageWidth"] as? String
            let imageHeight = dict["imageHeight"] as? String
            let aspectRatio = dict["aspectRatio"] as? String
            let selectionCount = dict["selectionCount"] as? String
            let receiverLoader = dict["receiverLoader"] as? Int ?? 0
            // 🔍 PROGRESS BAR LOG: Log receiverLoader value from Firebase
            if receiverLoader == 0 {
                print("🔍 [ProgressBar] ⚠️ Parsed receiverLoader: \(receiverLoader) from Firebase for message: \(messageId.prefix(8))... (WILL SHOW PROGRESS BAR)")
            } else {
                print("🔍 [ProgressBar] ✅ Parsed receiverLoader: \(receiverLoader) from Firebase for message: \(messageId.prefix(8))... (WILL HIDE PROGRESS BAR)")
            }
            
            // Parse emojiModel array (matching Android ArrayList<emojiModel>)
            var emojiModels: [EmojiModel] = []
            if let emojiArray = dict["emojiModel"] as? [[String: Any]] {
                for emojiDict in emojiArray {
                    let emojiName = emojiDict["name"] as? String ?? ""
                    let emoji = emojiDict["emoji"] as? String ?? ""
                    emojiModels.append(EmojiModel(name: emojiName, emoji: emoji))
                }
            } else {
                // Default empty emoji (matching Android)
                emojiModels = [EmojiModel(name: "", emoji: "")]
            }
            
            // Parse selectionBunch array (matching Android parseSelectionBunchFromSnapshot)
            var selectionBunch: [SelectionBunchModel]? = nil
            if let bunchArray = dict["selectionBunch"] as? [[String: Any]] {
                selectionBunch = []
                for bunchDict in bunchArray {
                    let imgUrl = bunchDict["imgUrl"] as? String ?? ""
                    let fileName = bunchDict["fileName"] as? String ?? ""
                    selectionBunch?.append(SelectionBunchModel(imgUrl: imgUrl, fileName: fileName))
                }
            }
            
            // Create ChatMessage (matching Android messageModel constructor)
            return ChatMessage(
                id: messageId,
                uid: uid,
                message: message,
                time: time,
                document: document,
                dataType: dataType,
                fileExtension: fileExtension,
                name: name,
                phone: phone,
                micPhoto: micPhoto,
                miceTiming: miceTiming,
                userName: userName,
                receiverId: receiverId,
                replytextData: replytextData,
                replyKey: replyKey,
                replyType: replyType,
                replyOldData: replyOldData,
                replyCrtPostion: replyCrtPostion,
                forwaredKey: forwaredKey,
                groupName: groupName,
                docSize: docSize,
                fileName: fileName,
                thumbnail: thumbnail,
                fileNameThumbnail: fileNameThumbnail,
                caption: caption,
                notification: notification,
                currentDate: currentDate,
                emojiModel: emojiModels,
                emojiCount: emojiCount,
                timestamp: timestamp,
                imageWidth: imageWidth,
                imageHeight: imageHeight,
                aspectRatio: aspectRatio,
                selectionCount: selectionCount,
                selectionBunch: selectionBunch,
                receiverLoader: receiverLoader
            )
        } catch {
            print("🚫 [parseMessageFromDict] Error parsing message: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Remove Firebase listeners (matching Android cleanup)
    private func removeFirebaseListeners() {
        let database = Database.database().reference()
        let receiverUid = contact.uid
        let uid = Constant.SenderIdMy
        let receiverRoom = receiverUid + uid
        let chatPath = "\(Constant.CHAT)/\(receiverRoom)"
        
        if let handle = firebaseChildListenerHandle {
            database.child(chatPath).removeObserver(withHandle: handle)
            firebaseChildListenerHandle = nil
            print("📱 [removeFirebaseListeners] Removed child listener")
        }
        
        // Remove typing indicator listener (matching Android cleanupTypingListener)
        if let handle = typingListenerHandle, let ref = typingRef {
            ref.removeObserver(withHandle: handle)
            typingListenerHandle = nil
            typingRef = nil
            print("📱 [removeFirebaseListeners] Removed typing indicator listener")
        }
        
        // Remove alternative typing indicator listener
        if let handle = typingListenerHandle2, let ref = typingRef2 {
            ref.removeObserver(withHandle: handle)
            typingListenerHandle2 = nil
            typingRef2 = nil
            print("📱 [removeFirebaseListeners] Removed alternative typing indicator listener")
        }
        
        // Clear typing status before cleanup
        clearTypingStatus()
        
        // Remove typing indicator from message list
        removeTypingIndicatorFromMessageList()
        
        fullListenerAttached = false
    }
    
    /// Update empty state (matching Android updateEmptyState)
    private func updateEmptyState(isEmpty: Bool) {
        // Empty state is handled by the valuable card view in messageListView
        // This method can be extended if needed
    }
    
    // MARK: - Load More Messages (Pagination) - matching Android loadMore
    /// Load more older messages when user scrolls to top (matching Android loadMore)
    private func loadMore(receiverRoom: String) {
        print("📱 [loadMore] loadMore called - isLoadingMore: \(isLoadingMore), initialLoadDone: \(initialLoadDone)")
        
        // Prevent loadMore during initial setup (matching Android)
        if isLoading || isLoadingMore || !initialLoadDone {
            print("📱 [loadMore] Skipped - isLoading: \(isLoading), isLoadingMore: \(isLoadingMore), initialLoadDone: \(initialLoadDone)")
            return
        }
        
        isLoadingMore = true
        
        let database = Database.database().reference()
        let chatPath = "\(Constant.CHAT)/\(receiverRoom)"
        
        var query: DatabaseQuery
        
        guard let lastTs = lastTimestamp else {
            // No lastTimestamp means we shouldn't be calling loadMore
            print("📱 [loadMore] No lastTimestamp, skipping")
            isLoadingMore = false
            hasMoreMessages = false
            return
        }
        
        // ✅ Load older messages than the currently oldest (matching Android endBefore)
        // Firebase iOS: Use queryEnding(atValue:) with exclusive end to get messages before timestamp
        // We'll query a larger set and filter to get exactly PAGE_SIZE older messages
        query = database.child(chatPath)
            .queryOrdered(byChild: "timestamp")
            .queryEnding(atValue: lastTs - 0.001, childKey: nil) // Messages before lastTimestamp
            .queryLimited(toLast: PAGE_SIZE * 3) // Get more to account for filtering and ensure we have enough
        
        query.observeSingleEvent(of: .value) { snapshot in
            
            print("📱 [loadMore] Fetched \(snapshot.childrenCount) older messages")
            
            var fetchedNewMessages: [ChatMessage] = []
            var newLastTimestamp: TimeInterval? = nil
            
            guard let children = snapshot.children.allObjects as? [DataSnapshot] else {
                DispatchQueue.main.async {
                    self.isLoadingMore = false
                }
                return
            }
            
            for child in children {
                let childKey = child.key
                
                // Skip typing indicator node (matching Android)
                if childKey == "typing" {
                    continue
                }
                
                // Skip invalid keys (matching Android)
                if childKey.count <= 1 || childKey == ":" {
                    continue
                }
                
                // Parse message from snapshot
                if let messageDict = child.value as? [String: Any],
                   let model = self.parseMessageFromDict(messageDict, messageId: childKey) {
                    
                    // Add Text, Image, Video, Document, and Contact datatype messages
                    if model.dataType == Constant.Text || model.dataType == Constant.img || model.dataType == Constant.video || model.dataType == Constant.doc || model.dataType == Constant.contact {
                        // ✅ Filter: only add messages older than lastTimestamp (matching Android endBefore)
                        if model.timestamp < lastTs {
                            // ✅ Avoid duplicate messages (matching Android)
                            let exists = self.messages.contains { $0.id == model.id }
                            
                            if !exists {
                                fetchedNewMessages.append(model)
                                
                                // ✅ Track the oldest timestamp (matching Android)
                                let ts = model.timestamp
                                if newLastTimestamp == nil || ts < newLastTimestamp! {
                                    newLastTimestamp = ts
                                }
                            }
                        }
                    }
                }
            }
            
            // ✅ Merge results (matching Android)
            if !fetchedNewMessages.isEmpty {
                // Update lastTimestamp for next pagination
                if let newLastTs = newLastTimestamp {
                    DispatchQueue.main.async {
                        self.lastTimestamp = newLastTs
                        self.hasMoreMessages = true // There might be more messages
                    }
                }
                
                // Merge: prepend new messages (matching Android combinedList)
                var combinedList: [ChatMessage] = []
                combinedList.append(contentsOf: fetchedNewMessages)
                combinedList.append(contentsOf: self.messages)
                
                // ✅ Ensure chronological order (matching Android Collections.sort)
                combinedList.sort { $0.timestamp < $1.timestamp }
                
                // ✅ Update messages array (matching Android messageList)
                DispatchQueue.main.async {
                    // Store the first message ID before update to maintain scroll position
                    let firstMessageId = self.messages.first?.id
                    
                    self.messages = combinedList
                    
                    // Update unique dates
                    for message in fetchedNewMessages {
                        if let date = message.currentDate {
                            self.uniqueDates.insert(date)
                        }
                    }
                    
                    print("📱 [loadMore] Loaded \(fetchedNewMessages.count) older messages, total: \(combinedList.count)")
                    
                    // Scroll to maintain position after a delay to allow layout update
                    if let firstId = firstMessageId {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            // Scroll will be handled by ScrollViewReader if needed
                            // For now, just update the list - scroll position should be maintained automatically
                        }
                    }
                }
            } else {
                print("📱 [loadMore] No more older messages to load")
                // Mark that there are no more messages if we got 0 results
                DispatchQueue.main.async {
                    self.hasMoreMessages = false
                }
            }
            
            DispatchQueue.main.async {
                self.isLoadingMore = false
            }
        } withCancel: { error in
            print("🚫 [loadMore] Error loading more messages: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.isLoadingMore = false
            }
        }
    }
    
    /// Scroll to the bottom message, optionally animated (mirrors Android smooth scroll)
    private func scrollToBottom(animated: Bool) {
        guard let lastId = messages.last?.id, let proxy = scrollViewProxy else {
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
    }
    
    // MARK: - Block User Functionality
    private func checkBlockStatus() {
        // Check if user is blocked (matching Android handleIntent block check)
        // In Android, this comes from Intent extra "block"
        let uid = Constant.SenderIdMy
        let receiverUid = contact.uid
        
        print("🚫 [BLOCK] Checking block status - UID: \(uid), Receiver: \(receiverUid)")
        
        // Check from API if user is blocked (current user blocked the other user)
        ApiService.checkIfBlocked(uid: uid, receiverId: receiverUid) { [self] isBlocked, message in
            DispatchQueue.main.async {
                print("🚫 [BLOCK] Block status check result - isBlocked: \(isBlocked), message: \(message)")
                // Only update state if API confirms block status, or if contact data says blocked
                // This prevents API false negatives from overwriting correct state
                if isBlocked {
                    showBlockCard = true
                    isUserBlocked = true
                    blockedUserName = contact.fullName
                    blockedUserSubtitle = "~ \(contact.fullName)"
                    print("🚫 [BLOCK] ✅ Block card will be shown (API confirmed)")
                    // Re-check contact saved status when block status changes
                    checkIfContactSaved()
                } else if contact.block {
                    // API returned false, but contact data says blocked - keep the blocked state
                    // This handles cases where API check fails but user is actually blocked
                    print("🚫 [BLOCK] ⚠️ API returned false, but contact data says blocked - keeping blocked state")
                    print("🚫 [BLOCK] ✅ Block card will remain shown (from contact data)")
                    // Re-check contact saved status when block status changes
                    checkIfContactSaved()
                } else {
                    // API says not blocked and contact data also says not blocked - hide block card
                    showBlockCard = false
                    isUserBlocked = false
                    print("🚫 [BLOCK] 🚫 Block card will be hidden (not blocked)")
                }
            }
        }
        
        // Check if current user is blocked by the other user (reverse check)
        checkIfBlockedByUser()
    }
    
    // Check if contact is saved in phone contacts (matching Android phone2Contact check)
    private func checkIfContactSaved() {
        let store = CNContactStore()
        let phoneNumber = contact.mobileNo
        
        // Normalize phone number (remove spaces, dashes, etc.)
        let normalizedPhone = phoneNumber.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        
        store.requestAccess(for: .contacts) { granted, error in
            if granted {
                // Run contact enumeration on background thread to avoid main thread warning
                DispatchQueue.global(qos: .userInitiated).async {
                    let keys = [CNContactPhoneNumbersKey, CNContactGivenNameKey, CNContactFamilyNameKey] as [CNKeyDescriptor]
                    let request = CNContactFetchRequest(keysToFetch: keys)
                    
                    do {
                        var found = false
                        try store.enumerateContacts(with: request) { contact, stop in
                            for phone in contact.phoneNumbers {
                                let contactPhone = phone.value.stringValue
                                let normalizedContactPhone = contactPhone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
                                
                                // Check if phone numbers match (normalized)
                                if normalizedContactPhone == normalizedPhone || 
                                   normalizedContactPhone.hasSuffix(normalizedPhone) ||
                                   normalizedPhone.hasSuffix(normalizedContactPhone) {
                                    found = true
                                    stop.pointee = true
                                    break
                                }
                            }
                        }
                        
                        DispatchQueue.main.async {
                            self.isContactSaved = found
                            print("📇 [CONTACT] Contact saved check - phone: \(phoneNumber), isSaved: \(found)")
                        }
                    } catch {
                        print("🚫 [CONTACT] Error checking contact: \(error.localizedDescription)")
                        DispatchQueue.main.async {
                            self.isContactSaved = false
                        }
                    }
                }
            } else {
                print("🚫 [CONTACT] Contact access denied")
                DispatchQueue.main.async {
                    self.isContactSaved = false
                }
            }
        }
    }
    
    private func checkIfBlockedByUser() {
        // Check if current user is blocked by the other user (reverse check)
        let uid = Constant.SenderIdMy
        let receiverUid = contact.uid
        
        print("🚫 [BLOCK] Checking if current user is blocked by other user - UID: \(uid), Blocker: \(receiverUid)")
        
        // Reverse the check: check if receiverUid blocked uid
        ApiService.checkIfBlocked(uid: receiverUid, receiverId: uid) { [self] isBlocked, message in
            DispatchQueue.main.async {
                print("🚫 [BLOCK] Blocked by user check result - isBlocked: \(isBlocked), message: \(message)")
                if isBlocked {
                    isBlockedByUser = true
                    print("🚫 [BLOCK] ✅ Current user is blocked by other user - showing block container")
                } else {
                    isBlockedByUser = false
                    print("🚫 [BLOCK] 🚫 Current user is not blocked by other user - hiding block container")
                }
            }
        }
    }
    
    private func handleUnblockWhenBlockedByUser() {
        // Handle unblock when current user is blocked by the other user
        // This means the other user needs to unblock the current user, or we check status again
        let uid = Constant.SenderIdMy
        let receiverUid = contact.uid
        
        print("🚫 [BLOCK] handleUnblockWhenBlockedByUser() called")
        print("🚫 [BLOCK] UID: \(uid), Blocker UID: \(receiverUid)")
        
        // Re-check if still blocked by user (the other user may have unblocked)
        checkIfBlockedByUser()
        
        // Note: The actual unblocking needs to be done by the other user
        // This button might be used to refresh the status or request unblock
    }
    
    private func handleBlockUser() {
        // Block user functionality (matching Android originalDelete onClick)
        let receiverUid = contact.uid
        let uid = Constant.SenderIdMy
        
        print("🚫 [BLOCK] handleBlockUser() called")
        print("🚫 [BLOCK] UID: \(uid), Blocked UID: \(receiverUid)")
        print("🚫 [BLOCK] Contact name: \(contact.fullName)")
        
        ApiService.blockUser(uid: uid, blockedUid: receiverUid) { [self] success, message in
            DispatchQueue.main.async {
                print("🚫 [BLOCK] Block API response - success: \(success), message: \(message)")
                // Handle "already blocked" as success (matching Android behavior)
                if success || message.lowercased().contains("already blocked") {
                    isUserBlocked = true
                    showBlockCard = true
                    blockedUserName = contact.fullName
                    blockedUserSubtitle = "~ \(contact.fullName)"
                    print("🚫 [BLOCK] ✅ User blocked successfully (or already blocked)")
                    print("🚫 [BLOCK] Updated state - isUserBlocked: \(isUserBlocked), showBlockCard: \(showBlockCard)")
                    print("🚫 [BLOCK] Block container should now be visible (bottom container with Unblock)")
                    // Re-check contact saved status when block status changes
                    checkIfContactSaved()
                    // Don't call checkBlockStatus() here as it may return false and overwrite our correct state
                    // The state is already set correctly above
                    // Hide message input container (matching Android messageboxContainer.setVisibility(View.GONE))
                } else {
                    // Show error if needed
                    print("🚫 [BLOCK] 🚫 Failed to block user: \(message)")
                }
            }
        }
    }
    
    private func handleAddUser() {
        // Add user functionality - block if not blocked, unblock if blocked
        let receiverUid = contact.uid
        let uid = Constant.SenderIdMy
        
        print("🚫 [BLOCK] handleAddUser() called")
        print("🚫 [BLOCK] UID: \(uid), Target UID: \(receiverUid)")
        print("🚫 [BLOCK] Contact name: \(contact.fullName)")
        print("🚫 [BLOCK] Current isUserBlocked state: \(isUserBlocked)")
        
        // Use local state to determine action, then handle API responses appropriately
        if isUserBlocked {
            // Local state says user is blocked, so try to unblock
            print("🚫 [BLOCK] Local state indicates user is blocked, unblocking...")
            ApiService.unblockUser(uid: uid, blockedUid: receiverUid) { [self] success, message in
                DispatchQueue.main.async {
                    print("🚫 [BLOCK] Unblock API response - success: \(success), message: \(message)")
                    if success {
                        isUserBlocked = false
                        showBlockCard = false
                        print("🚫 [BLOCK] ✅ User unblocked successfully")
                        print("🚫 [BLOCK] Updated state - isUserBlocked: \(isUserBlocked), showBlockCard: \(showBlockCard)")
                        print("🚫 [BLOCK] Block card should now be hidden")
                        // Show message input container (matching Android messageboxContainer.setVisibility(View.VISIBLE))
                    } else {
                        // If unblock fails with "not blocked", try blocking instead
                        if message.lowercased().contains("not blocked") {
                            print("🚫 [BLOCK] User is not actually blocked, blocking instead...")
                            ApiService.blockUser(uid: uid, blockedUid: receiverUid) { [self] success, message in
                                DispatchQueue.main.async {
                                    print("🚫 [BLOCK] Block API response - success: \(success), message: \(message)")
                                    if success {
                                        isUserBlocked = true
                                        showBlockCard = true
                                        blockedUserName = contact.fullName
                                        blockedUserSubtitle = "~ \(contact.fullName)"
                                        print("🚫 [BLOCK] ✅ User blocked successfully")
                                    } else {
                                        print("🚫 [BLOCK] 🚫 Failed to block user: \(message)")
                                    }
                                }
                            }
                        } else {
                            print("🚫 [BLOCK] 🚫 Failed to unblock user: \(message)")
                        }
                    }
                }
            }
        } else {
            // Local state says user is not blocked, so try to block
            print("🚫 [BLOCK] Local state indicates user is not blocked, blocking...")
            ApiService.blockUser(uid: uid, blockedUid: receiverUid) { [self] success, message in
                DispatchQueue.main.async {
                    print("🚫 [BLOCK] Block API response - success: \(success), message: \(message)")
                    if success {
                        isUserBlocked = true
                        showBlockCard = true
                        blockedUserName = contact.fullName
                        blockedUserSubtitle = "~ \(contact.fullName)"
                        print("🚫 [BLOCK] ✅ User blocked successfully")
                        print("🚫 [BLOCK] Updated state - isUserBlocked: \(isUserBlocked), showBlockCard: \(showBlockCard)")
                        print("🚫 [BLOCK] Block card should now be visible")
                        // Hide message input container (matching Android messageboxContainer.setVisibility(View.GONE))
                    } else {
                        // If block fails with "already blocked", try unblocking instead
                        if message.lowercased().contains("already blocked") {
                            print("🚫 [BLOCK] User is already blocked, unblocking instead...")
                            ApiService.unblockUser(uid: uid, blockedUid: receiverUid) { [self] success, message in
                                DispatchQueue.main.async {
                                    print("🚫 [BLOCK] Unblock API response - success: \(success), message: \(message)")
                                    if success {
                                        isUserBlocked = false
                                        showBlockCard = false
                                        print("🚫 [BLOCK] ✅ User unblocked successfully")
                                    } else {
                                        print("🚫 [BLOCK] 🚫 Failed to unblock user: \(message)")
                                    }
                                }
                            }
                        } else {
                            print("🚫 [BLOCK] 🚫 Failed to block user: \(message)")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Menu Button Handlers
    
    /// Handle block user click from menu (matching Android blockUser onClick)
    private func handleBlockUserClick() {
        let receiverUid = contact.uid
        let uid = Constant.SenderIdMy
        
        print("🚫 [MENU BLOCK] handleBlockUserClick() called")
        print("🚫 [MENU BLOCK] UID: \(uid), Target UID: \(receiverUid)")
        print("🚫 [MENU BLOCK] Current isUserBlocked state: \(isUserBlocked)")
        
        if isUserBlocked {
            // User is blocked, unblock directly (matching Android unblockUser onClick)
            print("🚫 [MENU BLOCK] User is blocked, unblocking...")
            ApiService.unblockUser(uid: uid, blockedUid: receiverUid) { [self] success, message in
                DispatchQueue.main.async {
                    if success {
                        isUserBlocked = false
                        showBlockCard = false
                        print("🚫 [MENU BLOCK] ✅ User unblocked successfully")
                        // No toast shown (matching Android behavior)
                    } else {
                        print("🚫 [MENU BLOCK] 🚫 Failed to unblock user: \(message)")
                        Constant.showToast(message: "Failed to unblock user")
                    }
                }
            }
        } else {
            // User is not blocked, show confirmation dialog (matching Android delete_ac_dialogue)
            print("🚫 [MENU BLOCK] User is not blocked, showing confirmation dialog...")
            showBlockUserDialog = true
        }
    }
    
    /// Clear chat functionality (matching Android clearChat onClick)
    private func clearChat() {
        let receiverUid = contact.uid
        let uid = Constant.SenderIdMy
        let receiverRoom = getReceiverRoom()
        let senderRoom = getSenderRoom()
        let database = Database.database().reference()
        
        print("🗑️ [CLEAR CHAT] Clearing chat for room: \(receiverRoom)")
        
        // Clear from Firebase (matching Android database.getReference().child(Constant.CHAT).child(receiverRoom).removeValue())
        database.child(Constant.CHAT).child(receiverRoom).removeValue { error, _ in
            if let error = error {
                print("🗑️ [CLEAR CHAT] 🚫 Error clearing Firebase: \(error.localizedDescription)")
                Constant.showToast(message: "Failed to clear chat")
            } else {
                print("🗑️ [CLEAR CHAT] ✅ Successfully cleared Firebase data for room: \(receiverRoom)")
                
                // Delete all pending messages from SQLite table FIRST (matching Android clearAllPendingMessages)
                // This will also log the table contents for debugging
                let deleted = DatabaseHelper.shared.deleteAllPendingMessages(receiverUid: receiverUid)
                if deleted {
                    print("🗑️ [CLEAR CHAT] ✅ Deleted all pending messages from SQLite")
                } else {
                    print("🗑️ [CLEAR CHAT] ⚠️ Failed to delete pending messages from SQLite")
                }
                
                // Clear local messages - filter out any pending messages (receiverLoader == 0)
                DispatchQueue.main.async {
                    // Remove all messages, including pending ones
                    let pendingCount = self.messages.filter { $0.receiverLoader == 0 }.count
                    print("🗑️ [CLEAR CHAT] Removing \(self.messages.count) messages from UI (including \(pendingCount) pending messages)")
                    self.messages.removeAll()
                    self.updateEmptyState(isEmpty: true)
                    print("🗑️ [CLEAR CHAT] ✅ Cleared local messages")
                }
                
                // Call API to delete sender messages (matching Android Webservice.delete_sender_all_msg)
                // Note: API endpoint may need to be implemented in ApiService
                // For now, clearing Firebase is sufficient
                DispatchQueue.main.async {
                    print("🗑️ [CLEAR CHAT] ✅ Chat cleared successfully")
                    // Toast removed - no message shown after clearing (matching user requirement)
                }
            }
        }
    }
    
    
    /// Track last item visibility to toggle down arrow (matching Android isLastItemVisible logic)
    private func handleLastItemVisibility(id: String, index: Int, isAppearing: Bool) {
        // Check if this is the last message (matching Android lastVisiblePosition >= totalItems - 1)
        let isLastMessage = index == messages.count - 1
        
        if isLastMessage {
            // Update isLastItemVisible flag (matching Android)
            isLastItemVisible = isAppearing
            
            // Update down button visibility (matching Android)
            // Hide when last item is visible, show when not visible
            showScrollDownButton = !isLastItemVisible
        }
    }
    
    private func updateMessageText(_ newValue: String) {
        let trimmedText = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("🔤 [TypingIndicator] updateMessageText CALLED")
        print("   newValue length: \(newValue.count)")
        print("   trimmedText length: \(trimmedText.count)")
        print("   trimmedText isEmpty: \(trimmedText.isEmpty)")
        print("   current isTyping state: \(isTyping)")
        print("   typingRunnable is nil: \(typingRunnable == nil)")
        
        if trimmedText.isEmpty {
            // Clear typing status when messageBox is empty
            print("🔤 [TypingIndicator] Text is empty, calling clearTypingStatus()")
            clearTypingStatus()
        } else {
            // Update typing status when user is typing
            print("🔤 [TypingIndicator] Text is not empty, calling updateTypingStatus(true)")
            updateTypingStatus(true)
        }
    }
    
    /// Clear typing status in Firebase (matching Android clearTypingStatus)
    private func clearTypingStatus() {
        print("🧹 [TypingIndicator] clearTypingStatus CALLED")
        print("   current isTyping state: \(isTyping)")
        print("   typingRunnable is nil: \(typingRunnable == nil)")
        
        do {
            let receiverUid = contact.uid
            let senderId = Constant.SenderIdMy
            
            print("🧹 [TypingIndicator] clearTypingStatus - receiverUid: '\(receiverUid)', senderId: '\(senderId)'")
            
            guard !receiverUid.isEmpty && !senderId.isEmpty else {
                print("⚠️ [TypingIndicator] clearTypingStatus: Missing receiverUid or senderId")
                return
            }
            
            // Cancel pending runnable
            if typingRunnable != nil {
                print("🧹 [TypingIndicator] Cancelling existing typingRunnable")
                typingRunnable?.cancel()
                typingRunnable = nil
                print("🧹 [TypingIndicator] typingRunnable cancelled and set to nil")
            } else {
                print("🧹 [TypingIndicator] No typingRunnable to cancel (already nil)")
            }
            
            // Remove typing indicator from Firebase only if currently typing
            if isTyping {
                print("🧹 [TypingIndicator] isTyping is true, removing from Firebase")
                let receiverRoom = receiverUid + senderId
                let database = Database.database().reference()
                let typingRef = database.child(Constant.CHAT).child(receiverRoom).child("typing")
                
                print("🧹 [TypingIndicator] Removing typing indicator from Firebase path: \(typingRef)")
                
                // Remove typing indicator messageModel from Firebase
                typingRef.removeValue { error, _ in
                    if let error = error {
                        print("🚫 [TypingIndicator] Error removing typing indicator: \(error.localizedDescription)")
                    } else {
                        DispatchQueue.main.async {
                            self.isTyping = false
                            print("✅ [TypingIndicator] Typing indicator removed from Firebase at path: \(typingRef)")
                            print("✅ [TypingIndicator] isTyping set to FALSE")
                        }
                    }
                }
            } else {
                print("🧹 [TypingIndicator] isTyping is false, skipping Firebase removal")
            }
        } catch {
            print("🚫 [TypingIndicator] Error clearing typing status: \(error.localizedDescription)")
        }
    }
    
    /// Update typing status in Firebase (matching Android updateTypingStatus)
    private func updateTypingStatus(_ typing: Bool) {
        print("📝 [TypingIndicator] updateTypingStatus CALLED")
        print("   typing parameter: \(typing)")
        print("   current isTyping state: \(isTyping)")
        print("   typingRunnable is nil: \(typingRunnable == nil)")
        
        do {
            let receiverUid = contact.uid
            let senderId = Constant.SenderIdMy
            
            print("📝 [TypingIndicator] updateTypingStatus - receiverUid: '\(receiverUid)', senderId: '\(senderId)'")
            
            guard !receiverUid.isEmpty && !senderId.isEmpty else {
                print("⚠️ [TypingIndicator] updateTypingStatus: Missing receiverUid or senderId")
                return
            }
            
            // Path: chats/{receiverRoom}/typing (store as messageModel structure)
            // receiverRoom = receiverUid + senderId
            let receiverRoom = receiverUid + senderId
            let database = Database.database().reference()
            let typingRef = database.child(Constant.CHAT).child(receiverRoom).child("typing")
            
            if typing {
                print("📝 [TypingIndicator] Typing is TRUE - processing typing indicator update")
                
                // Cancel previous runnable if user is still typing (reset timer on every keystroke)
                if typingRunnable != nil {
                    print("📝 [TypingIndicator] Cancelling previous typingRunnable (user still typing)")
                    typingRunnable?.cancel()
                    typingRunnable = nil
                    print("📝 [TypingIndicator] Previous typingRunnable cancelled")
                } else {
                    print("📝 [TypingIndicator] No previous typingRunnable to cancel")
                }
                
                // Always update typing indicator on every keystroke (matching Android real-time behavior)
                // Update timestamp to show continuous typing activity
                print("💾 [TypingIndicator] SENDER: Updating typing indicator to Firebase (every keystroke)")
                print("   senderId: \(senderId)")
                print("   receiverUid: \(receiverUid)")
                print("   receiverRoom: \(receiverRoom)")
                print("   Path: \(typingRef)")
                print("   current isTyping before update: \(isTyping)")
                
                // Create typing indicator messageModel
                let emojiModels: [EmojiModel] = [EmojiModel(name: "", emoji: "")]
                
                // Get current date (matching Android Constant.getCurrentDate())
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                var typingDate = dateFormatter.string(from: Date())
                
                // Ensure clean date without colon prefix (matching Android)
                if typingDate.hasPrefix(":") {
                    typingDate = String(typingDate.dropFirst()).trimmingCharacters(in: .whitespaces)
                    print("⚠️ [TypingIndicator] Removed leading colon from typing indicator date: \(typingDate)")
                }
                
                // Get user name from UserDefaults
                let userName = UserDefaults.standard.string(forKey: Constant.full_name) ?? ""
                
                // Always use current timestamp to show continuous typing
                let currentTimestamp = Date().timeIntervalSince1970
                
                let typingMessage = ChatMessage(
                    id: "typing_indicator_\(senderId)",
                    uid: senderId,
                    message: "",
                    time: "",
                    document: "",
                    dataType: Constant.TYPEINDICATOR,
                    fileExtension: nil,
                    name: nil,
                    phone: nil,
                    micPhoto: nil,
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
                    caption: nil,
                    notification: 1,
                    currentDate: typingDate,
                    emojiModel: emojiModels,
                    emojiCount: nil,
                    timestamp: currentTimestamp, // Always update timestamp on every keystroke
                    imageWidth: nil,
                    imageHeight: nil,
                    aspectRatio: nil,
                    selectionCount: "1",
                    selectionBunch: nil,
                    receiverLoader: 0
                )
                
                // Convert to dictionary for Firebase (matching Android modelToDictionary)
                var typingDict: [String: Any] = [:]
                typingDict["uid"] = typingMessage.uid
                typingDict["message"] = typingMessage.message
                typingDict["time"] = typingMessage.time
                typingDict["document"] = typingMessage.document
                typingDict["dataType"] = typingMessage.dataType
                typingDict["extension"] = typingMessage.fileExtension ?? ""
                typingDict["name"] = typingMessage.name ?? ""
                typingDict["phone"] = typingMessage.phone ?? ""
                typingDict["micPhoto"] = typingMessage.micPhoto ?? ""
                typingDict["miceTiming"] = typingMessage.miceTiming ?? ""
                typingDict["userName"] = typingMessage.userName ?? ""
                typingDict["replytextData"] = typingMessage.replytextData ?? ""
                typingDict["replyKey"] = typingMessage.replyKey ?? ""
                typingDict["replyType"] = typingMessage.replyType ?? ""
                typingDict["replyOldData"] = typingMessage.replyOldData ?? ""
                typingDict["replyCrtPostion"] = typingMessage.replyCrtPostion ?? ""
                typingDict["modelId"] = typingMessage.id
                typingDict["receiverUid"] = typingMessage.receiverId
                typingDict["forwaredKey"] = typingMessage.forwaredKey ?? ""
                typingDict["groupName"] = typingMessage.groupName ?? ""
                typingDict["docSize"] = typingMessage.docSize ?? ""
                typingDict["fileName"] = typingMessage.fileName ?? ""
                typingDict["thumbnail"] = typingMessage.thumbnail ?? ""
                typingDict["fileNameThumbnail"] = typingMessage.fileNameThumbnail ?? ""
                typingDict["caption"] = typingMessage.caption ?? ""
                typingDict["notification"] = typingMessage.notification
                typingDict["currentDate"] = typingMessage.currentDate ?? ""
                typingDict["emojiCount"] = typingMessage.emojiCount ?? ""
                typingDict["imageWidth"] = typingMessage.imageWidth ?? ""
                typingDict["imageHeight"] = typingMessage.imageHeight ?? ""
                typingDict["aspectRatio"] = typingMessage.aspectRatio ?? ""
                typingDict["selectionCount"] = typingMessage.selectionCount ?? ""
                typingDict["receiverLoader"] = typingMessage.receiverLoader
                typingDict["timestamp"] = currentTimestamp // Always update timestamp on every keystroke
                
                // Convert emojiModel array
                if let emojiModels = typingMessage.emojiModel {
                    var emojiArray: [[String: Any]] = []
                    for emoji in emojiModels {
                        emojiArray.append(["name": emoji.name, "emoji": emoji.emoji])
                    }
                    typingDict["emojiModel"] = emojiArray
                }
                
                // Always save typing indicator to Firebase on every keystroke (update timestamp)
                print("💾 [TypingIndicator] Calling Firebase setValue with timestamp: \(currentTimestamp)")
                typingRef.setValue(typingDict) { error, _ in
                    if let error = error {
                        print("🚫 [TypingIndicator] ERROR saving typing indicator: \(error.localizedDescription)")
                    } else {
                        DispatchQueue.main.async {
                            let wasTyping = self.isTyping
                            self.isTyping = true
                            print("✅ [TypingIndicator] SUCCESS - Typing indicator updated in Firebase (timestamp: \(currentTimestamp))!")
                            print("   Path: \(typingRef)")
                            print("   isTyping changed from \(wasTyping) to TRUE")
                        }
                    }
                }
                
                // Set a runnable to clear typing status after 3 seconds of no typing activity
                // This timer is reset on every keystroke, so it only fires when user stops typing
                // Note: ChattingScreen is a struct (value type), so we capture values instead of using [weak self]
                let receiverUidForTimer = receiverUid
                let senderIdForTimer = Constant.SenderIdMy
                print("⏰ [TypingIndicator] Creating 3-second timer to clear typing indicator if user stops typing")
                let workItem = DispatchWorkItem {
                    print("⏰ [TypingIndicator] TIMER FIRED - 3 seconds passed with no typing activity")
                    let delayedReceiverUid = receiverUidForTimer
                    let delayedSenderId = senderIdForTimer
                    
                    guard !delayedReceiverUid.isEmpty && !delayedSenderId.isEmpty else {
                        print("⏰ [TypingIndicator] Timer fired but receiverUid or senderId is empty - skipping")
                        return
                    }
                    
                    let delayedReceiverRoom = delayedReceiverUid + delayedSenderId
                    let delayedDatabase = Database.database().reference()
                    let delayedTypingRef = delayedDatabase.child(Constant.CHAT).child(delayedReceiverRoom).child("typing")
                    
                    print("⏰ [TypingIndicator] Removing typing indicator from Firebase after 3s inactivity")
                    print("   Path: \(delayedTypingRef)")
                    
                    // Remove typing indicator from Firebase after 3 seconds of inactivity
                    delayedTypingRef.removeValue { error, _ in
                        if let error = error {
                            print("🚫 [TypingIndicator] Error removing typing indicator after 3s: \(error.localizedDescription)")
                        } else {
                            DispatchQueue.main.async {
                                let wasTyping = self.isTyping
                                self.isTyping = false
                                self.typingRunnable = nil // Clean up the runnable reference
                                print("✅ [TypingIndicator] Typing indicator removed from Firebase after 3s inactivity")
                                print("   isTyping changed from \(wasTyping) to FALSE")
                                print("   typingRunnable set to nil")
                                print("✅ [TypingIndicator] State reset complete - ready for next typing session")
                                // Note: State updates will be handled by the typing listener or when updateTypingStatus is called again
                            }
                        }
                    }
                }
                
                typingRunnable = workItem
                print("⏰ [TypingIndicator] Timer scheduled for 3 seconds from now")
                // Reset timer on every keystroke - only fires if user stops typing for 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: workItem)
            } else {
                // Immediately clear typing status
                print("📝 [TypingIndicator] Typing is FALSE - calling clearTypingStatus()")
                clearTypingStatus()
            }
        } catch {
            print("🚫 [TypingIndicator] Error updating typing status: \(error.localizedDescription)")
        }
    }
    
    /// Load pending messages from SQLite and add to UI (matching Android loadPendingMessages on onResume)
    private func loadPendingMessages() {
        let receiverUid = contact.uid
        print("📱 [loadPendingMessages] Loading pending messages for receiver: \(receiverUid)")
        
        // Log all pending messages in SQLite table for debugging
        DatabaseHelper.shared.logAllPendingMessages(receiverUid: receiverUid)
        
        DatabaseHelper.shared.getPendingMessages(receiverUid: receiverUid) { pendingMessages in
            guard !pendingMessages.isEmpty else {
                print("📱 [loadPendingMessages] No pending messages found in SQLite")
                return
            }
            
            print("📱 [loadPendingMessages] Found \(pendingMessages.count) pending messages in SQLite")
            for (index, msg) in pendingMessages.enumerated() {
                print("📱 [loadPendingMessages]   [\(index + 1)] modelId: \(msg.id), dataType: \(msg.dataType), receiverLoader: \(msg.receiverLoader)")
            }
            
            DispatchQueue.main.async {
                var addedCount = 0
                var skippedCount = 0
                // Add pending messages to the list if they don't already exist
                for pendingMessage in pendingMessages {
                    // Check if message already exists in the list
                    if !self.messages.contains(where: { $0.id == pendingMessage.id }) {
                        print("📱 [loadPendingMessages] Adding pending message to UI: \(pendingMessage.id), dataType: \(pendingMessage.dataType), receiverLoader: \(pendingMessage.receiverLoader)")
                        if pendingMessage.receiverLoader == 0 {
                            print("🔍 [ProgressBar] ⚠️ LOADED PENDING MESSAGE - PROGRESS BAR WILL BE SHOWN")
                            print("🔍 [ProgressBar]   - Message ID: \(pendingMessage.id.prefix(8))...")
                            print("🔍 [ProgressBar]   - dataType: \(pendingMessage.dataType)")
                            print("🔍 [ProgressBar]   - receiverLoader: \(pendingMessage.receiverLoader)")
                        }
                        self.messages.append(pendingMessage)
                        addedCount += 1
                    } else {
                        print("📱 [loadPendingMessages] Pending message already in list (skipping): \(pendingMessage.id)")
                        skippedCount += 1
                    }
                }
                
                if addedCount > 0 {
                    // Sort messages by timestamp to maintain order
                    self.messages.sort { $0.timestamp < $1.timestamp }
                    
                    // Set last item visible to show progress bar
                    self.isLastItemVisible = true
                    self.showScrollDownButton = false
                    
                    print("📱 [loadPendingMessages] ✅ Added \(addedCount) pending messages to UI (skipped \(skippedCount) duplicates)")
                } else {
                    print("📱 [loadPendingMessages] ⚠️ No new pending messages added (all \(skippedCount) were duplicates)")
                }
            }
        }
    }
    
    /// Check if message exists in Firebase and stop progress bar (matching Android behavior)
    /// This is called after successful upload to verify message is in Firebase
    private func checkMessageInFirebaseAndStopProgress(messageId: String, receiverUid: String) {
        let senderId = Constant.SenderIdMy
        let receiverRoom = receiverUid + senderId
        let database = Database.database().reference()
        let messageRef = database.child(Constant.CHAT).child(receiverRoom).child(messageId)
        
        print("🔍 [ProgressBar] Checking if message exists in Firebase: \(messageId)")
        print("🔍 [ProgressBar]   - Path: \(messageRef)")
        print("🔍 [ProgressBar]   - receiverUid: \(receiverUid)")
        
        // Check if message exists in Firebase (matching Android addListenerForSingleValueEvent)
        messageRef.observeSingleEvent(of: .value) { snapshot in
            if snapshot.exists() {
                print("✅ [ProgressBar] Message confirmed in Firebase, stopping animation and updating receiverLoader")
                print("🔍 [ProgressBar] ✅ Message found in Firebase - will stop progress bar")
                
                // Check current receiverLoader value in Firebase
                if let messageData = snapshot.value as? [String: Any],
                   let currentReceiverLoader = messageData["receiverLoader"] as? Int {
                    print("🔍 [ProgressBar]   - Current receiverLoader in Firebase: \(currentReceiverLoader)")
                } else {
                    print("🔍 [ProgressBar]   - receiverLoader not found in Firebase (will be set to 1)")
                }
                
                // Remove from pending table (matching Android removePendingMessage)
                let removed = DatabaseHelper.shared.removePendingMessage(modelId: messageId, receiverUid: receiverUid)
                if removed {
                    print("✅ [PendingMessages] Removed pending message from SQLite: \(messageId)")
                }
                
                // Wait 900ms then stop animation and update receiverLoader (matching Android Handler.postDelayed)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    // Update receiverLoader to 1 to stop progress bar animation (matching Android setIndeterminate(false))
                    self.updateReceiverLoaderForMessage(messageId: messageId, receiverUid: receiverUid, receiverLoader: 1)
                }
            } else {
                print("⚠️ [ProgressBar] Message not found in Firebase yet, keeping animation")
                print("🔍 [ProgressBar] ⚠️ PROGRESS BAR WILL CONTINUE RUNNING (message not in Firebase)")
                print("🔍 [ProgressBar]   - Message ID: \(messageId.prefix(8))...")
                print("🔍 [ProgressBar]   - receiverLoader will remain: 0")
                // Keep receiverLoader as 0, animation continues
            }
        }
    }
    
    /// Update receiverLoader for a message in Firebase (matching Android setValue receiverLoader)
    private func updateReceiverLoaderForMessage(messageId: String, receiverUid: String, receiverLoader: Int) {
        let senderId = Constant.SenderIdMy
        
        guard !receiverUid.isEmpty && !senderId.isEmpty else {
            print("⚠️ [updateReceiverLoader] Missing receiverUid or senderId")
            return
        }
        
        let receiverRoom = receiverUid + senderId
        let database = Database.database().reference()
        let messageRef = database.child(Constant.CHAT).child(receiverRoom).child(messageId).child("receiverLoader")
        
        print("🔄 [updateReceiverLoader] Updating receiverLoader to \(receiverLoader) for message: \(messageId)")
        print("   Path: \(messageRef)")
        
        messageRef.setValue(receiverLoader) { error, _ in
            if let error = error {
                print("🚫 [updateReceiverLoader] Error updating receiverLoader: \(error.localizedDescription)")
            } else {
                print("✅ [updateReceiverLoader] receiverLoader updated to \(receiverLoader) for message: \(messageId)")
                
                // Update local message to reflect the change
                DispatchQueue.main.async {
                    if let index = self.messages.firstIndex(where: { $0.id == messageId }) {
                        var updatedMessage = self.messages[index]
                        let oldReceiverLoader = updatedMessage.receiverLoader
                        updatedMessage.receiverLoader = receiverLoader
                        self.messages[index] = updatedMessage
                        print("✅ [updateReceiverLoader] Local message updated - progress bar \(receiverLoader == 1 ? "hidden" : "shown")")
                        print("🔍 [ProgressBar] 🔄 UPDATED receiverLoader: \(oldReceiverLoader) → \(receiverLoader) for message: \(messageId.prefix(8))...")
                        if receiverLoader == 1 {
                            print("🔍 [ProgressBar] ✅ PROGRESS BAR STOPPED (receiverLoader set to 1)")
                        } else {
                            print("🔍 [ProgressBar] ⚠️ PROGRESS BAR RUNNING (receiverLoader set to \(receiverLoader))")
                        }
                    } else {
                        print("🔍 [ProgressBar] ⚠️ Message not found in local messages array: \(messageId.prefix(8))...")
                    }
                }
            }
        }
    }
    
    /// Trigger reply UI (Android half-swipe) for a given message
    private func handleHalfSwipeReply(_ message: ChatMessage) {
        let isSentByMe = message.uid == Constant.SenderIdMy
        let senderName = isSentByMe ? "You" : (message.userName?.isEmpty == false ? message.userName! : contact.fullName)
        let previewText = replyPreviewText(for: message)
        
        // Capture image/thumbnail URL and other data for reply preview
        var imageUrl: String? = nil
        var contactName: String? = nil
        var fileExtension: String? = nil
        
        switch message.dataType {
        case Constant.img, Constant.video:
            // Use thumbnail if available, otherwise use document URL
            imageUrl = message.thumbnail?.isEmpty == false ? message.thumbnail : (message.document.isEmpty ? nil : message.document)
        case Constant.contact:
            contactName = message.name
        case Constant.doc, Constant.voiceAudio:
            fileExtension = message.fileExtension
        default:
            break
        }
        
        withAnimation {
            replySenderName = senderName
            replyMessage = previewText
            replyDataType = message.dataType
            isReplyFromSender = isSentByMe // Track if reply is from sender for theme color
            replyImageUrl = imageUrl
            replyContactName = contactName
            replyFileExtension = fileExtension
            replyMessageId = message.id // Store original message ID for reply
            showReplyLayout = true
            isMessageFieldFocused = true
        }
    }
    
    /// Build the reply preview label based on message type (mirrors Android reply cards)
    private func replyPreviewText(for message: ChatMessage) -> String {
        switch message.dataType {
        case Constant.img:
            return "Photo"
        case Constant.video:
            return "Video"
        case Constant.voiceAudio:
            return "Audio"
        case Constant.contact:
            if let name = message.name, !name.isEmpty { return name }
            return "Contact"
        case Constant.doc:
            if let fileName = message.fileName, !fileName.isEmpty { return fileName }
            if let ext = message.fileExtension, !ext.isEmpty { return ext }
            return "Document"
        default:
            return message.message.isEmpty ? "Message" : message.message
        }
    }
    
    // MARK: - Multi-Selection Functions (matching Android chatAdapter)
    
    /// Enter multi-select mode (matching Android enterMultiSelectMode)
    private func enterMultiSelectMode() {
        isMultiSelectMode = true
        selectedMessageIds.removeAll()
        selectedCount = 0
        showMultiSelectHeader = true
    }
    
    /// Exit multi-select mode (matching Android exitMultiSelectMode)
    private func exitMultiSelectMode() {
        isMultiSelectMode = false
        selectedMessageIds.removeAll()
        selectedCount = 0
        showMultiSelectHeader = false
    }
    
    /// Toggle message selection (matching Android toggleSelection)
    private func toggleMessageSelection(messageId: String) {
        if selectedMessageIds.contains(messageId) {
            selectedMessageIds.remove(messageId)
        } else {
            selectedMessageIds.insert(messageId)
        }
        selectedCount = selectedMessageIds.count
        
        // Exit multi-select mode if no messages are selected (optional - Android doesn't do this automatically)
        if selectedMessageIds.isEmpty {
            // Keep mode active even with 0 selections (matching Android behavior)
        }
    }
    
    // MARK: - Multi-Select Header View (matching Android header2Cardview)
    private var multiSelectHeaderView: some View {
        // CardView: match_parent width, 50dp height, 1dp marginBottom, edittextBg background
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 0) { // Vertically center all elements
                // Cross button (matching Android cross LinearLayout)
                // layout_width="40dp" layout_height="40dp" layout_marginEnd="5dp"
                Button(action: {
                    // Exit multi-select mode (matching Android binding.cross.setOnClickListener)
                    exitMultiSelectMode()
                }) {
                    ZStack {
                        // Background matching Android custome_ripple_circle
                        Circle()
                            .fill(Color("edittextBg"))
                            .frame(width: 40, height: 40)
                        
                        // Inner LinearLayout: 26x26dp
                        ZStack {
                            // ImageView: crossimg, 25x18dp, padding="2dp"
                            Image("crossimg")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 25, height: 18)
                                .foregroundColor(Color("TextColor"))
                                .padding(2)
                        }
                        .frame(width: 26, height: 26)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.leading, 20) // layout_marginStart="20dp"
                .padding(.trailing, 5) // layout_marginEnd="5dp"
                
                // Selected counter text container (matching Android LinearLayout with weight=1)
                HStack(spacing: 0) {
                    // Selected counter text (matching Android selectedCounterTxt)
                    // layout_marginStart="21dp" layout_weight="1"
                    Text("\(selectedCount) selected")
                        .font(.custom("Inter18pt-Medium", size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(Color("TextColor"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 21)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50) // Match header height for vertical centering
                
                // Forward button container (matching Android LinearLayout with weight=1, gravity=end)
                HStack(alignment: .center) { // Vertically center forward button
                    Spacer()
                    
                    // Forward button (matching Android forwardAll exactly)
                    // background="@drawable/forward_drawable" with theme color border (5dp stroke, 20dp corner radius)
                    // drawableEnd="@drawable/forward_wrapped_3" drawablePadding="5dp" paddingHorizontal="10dp"
                    Button(action: {
                        // Handle forward action (matching Android binding.forwardAll.setOnClickListener)
                        // Matching Android: chatAdapter.onForwardSelected()
                        openContactSelectionForForward()
                    }) {
                        HStack(alignment: .center, spacing: 2) { // Small spacing between text and icon
                            // Text vertically centered
                            Text("forward")
                                .font(.custom("Inter18pt-Regular", size: 10))
                                .foregroundColor(Color("TextColor"))
                                .multilineTextAlignment(.center)
                            
                            Spacer(minLength: 0) // Minimal space to push icon to end side
                            
                            // Icon matching Android forward_wrapped_3: 24dp x 24dp, positioned on end side
                            Image("forward_svg")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20) // Reduced icon size
                                .foregroundColor(Color("TextColor")) // android:drawableTint="@color/TextColor"
                        }
                        .frame(width: 78) // Keep width 78px
                        .padding(.horizontal, 6) // Reduced horizontal padding
                        .padding(.vertical, 4) // Reduced vertical padding
                        .background(
                            // Background matching Android forward_drawable.xml exactly
                            // Layer 1: Outer Border (stroke 5dp, corner radius 20dp)
                            // Layer 2: Inner Background (solid chattingMessageBox, left inset 3dp, corner radius 20dp)
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    // Layer 1: Outer Border (matching Android border item)
                                    // stroke android:width="5dp" corners android:radius="20dp"
                                    // Note: Java code applies theme color to border dynamically (borderDrawable.setStroke(5, Color.parseColor(themeColor2)))
                                    RoundedRectangle(cornerRadius: 20) // android:radius="20dp"
                                        .stroke(Color(hex: Constant.themeColor), lineWidth: 5)
                                        .frame(height: geometry.size.height-5) // Match content height for proper centering
                                    
                                    // Layer 2: Inner Background (matching Android background item)
                                    // android:left="3dp" solid android:color="@color/chattingMessageBox" corners android:radius="20dp"
                                    RoundedRectangle(cornerRadius: 20) // android:radius="20dp"
                                        .fill(Color("chattingMessageBox")) // solid android:color="@color/chattingMessageBox"
                                        .frame(width: geometry.size.width + 3, height: geometry.size.height) // Match content height
                                        .offset(x: 2) // Position 3dp from left edge
                                }
                            }
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .frame(maxWidth: .infinity)
                .padding(.trailing, 10) // layout_marginEnd="10dp"
            }
            .frame(height: 50) // layout_height="50dp"
        }
        .background(Color("edittextBg")) // app:cardBackgroundColor="@color/edittextBg"
        .padding(.bottom, 1) // layout_marginBottom="1dp"
    }
    
    /// Check if message is selected (matching Android isSelected)
    private func isMessageSelected(messageId: String) -> Bool {
        return selectedMessageIds.contains(messageId)
    }
    
    /// Get selected messages (matching Android getSelectedMessages)
    private func getSelectedMessages() -> [ChatMessage] {
        return messages.filter { selectedMessageIds.contains($0.id) }
    }
    
    // MARK: - Forward Functions (matching Android forward functionality)
    
    /// Open contact selection for forwarding (matching Android openContactSelectionForForward)
    private func openContactSelectionForForward() {
        let selectedMessages = getSelectedMessages()
        if !selectedMessages.isEmpty {
            // Store selected messages for forwarding
            selectedMessagesForForward = selectedMessages
            // Show forward contact picker
            showForwardContactPicker = true
        }
    }
    
    /// Forward messages to selected contacts (matching Android forwardText.setOnClickListener)
    private func forwardMessagesToContacts(contacts: [UserActiveContactModel]) {
        guard !selectedMessagesForForward.isEmpty, !contacts.isEmpty else {
            print("Forward: No messages or contacts to forward")
            Constant.showToast(message: "No messages or contacts to forward")
            return
        }
        
        print("Forward: Forwarding \(selectedMessagesForForward.count) messages to \(contacts.count) contacts")
        
        // Get current time in "hh:mm a" format (matching Android)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "hh:mm a"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let currentDateTimeString = dateFormatter.string(from: Date())
        
        // Get current date (matching Android Constant.getCurrentDate())
        let currentDateFormatter = DateFormatter()
        currentDateFormatter.dateFormat = "yyyy-MM-dd"
        let currentDateString = currentDateFormatter.string(from: Date())
        
        // Get user FCM token (matching Android)
        let userFTokenKey = UserDefaults.standard.string(forKey: Constant.FCM_TOKEN) ?? ""
        let myUID = Constant.SenderIdMy
        let deviceType = Constant.deviceType
        
        // Get user name and photo
        let userName = UserDefaults.standard.string(forKey: Constant.full_name) ?? ""
        let micPhoto = UserDefaults.standard.string(forKey: Constant.profilePic) ?? ""
        
        // Create emoji model array (matching Android - default empty emoji)
        let emojiModels: [EmojiModel] = [EmojiModel(name: "", emoji: "")]
        
        // Track total messages to forward
        let totalMessages = selectedMessagesForForward.count * contacts.count
        var completedMessages = 0
        var failedMessages = 0
        
        // Loop through each contact (matching Android forwardText.setOnClickListener)
        for (contactIndex, contact) in contacts.enumerated() {
            let contactId = contact.uid
            let contactName = contact.fullName
            let contactToken = contact.fToken ?? ""
            
            guard !contactId.isEmpty else {
                print("Forward: Skipping contact with empty ID")
                continue
            }
            
            // Loop through all selected messages for this contact
            for (messageIndex, originalMessage) in selectedMessagesForForward.enumerated() {
                // Generate new message ID (matching Android database.getReference().push().getKey())
                let newMessageId = UUID().uuidString
                
                // Create new forwarded message (matching Android messageModel constructor)
                let forwardedMessage = ChatMessage(
                    id: newMessageId,
                    uid: myUID,
                    message: originalMessage.message,
                    time: currentDateTimeString,
                    document: originalMessage.document,
                    dataType: originalMessage.dataType,
                    fileExtension: originalMessage.fileExtension,
                    name: originalMessage.name,
                    phone: originalMessage.phone,
                    micPhoto: micPhoto,
                    miceTiming: originalMessage.miceTiming,
                    userName: userName,
                    receiverId: contactId, // Set receiver to the contact
                    replytextData: originalMessage.replytextData,
                    replyKey: originalMessage.replyKey,
                    replyType: originalMessage.replyType,
                    replyOldData: originalMessage.replyOldData,
                    replyCrtPostion: originalMessage.replyCrtPostion,
                    forwaredKey: "forwordKey", // Set forward key (matching Android Constant.forwordKey)
                    groupName: originalMessage.groupName,
                    docSize: originalMessage.docSize,
                    fileName: originalMessage.fileName,
                    thumbnail: originalMessage.thumbnail,
                    fileNameThumbnail: originalMessage.fileNameThumbnail,
                    caption: originalMessage.caption,
                    notification: originalMessage.notification,
                    currentDate: currentDateString,
                    emojiModel: emojiModels,
                    emojiCount: nil,
                    timestamp: Date().timeIntervalSince1970,
                    imageWidth: originalMessage.imageWidth,
                    imageHeight: originalMessage.imageHeight,
                    aspectRatio: originalMessage.aspectRatio,
                    selectionCount: originalMessage.selectionCount,
                    selectionBunch: originalMessage.selectionBunch,
                    receiverLoader: 0,
                    linkTitle: originalMessage.linkTitle,
                    linkDescription: originalMessage.linkDescription,
                    linkImageUrl: originalMessage.linkImageUrl,
                    favIconUrl: originalMessage.favIconUrl
                )
                
                // Store message in SQLite pending table before upload (matching Android insertPendingMessage)
                DatabaseHelper.shared.insertPendingMessage(forwardedMessage)
                print("✅ [PendingMessages] Forwarded message stored in pending table: \(newMessageId)")
                
                // Upload message using MessageUploadService (matching Android UploadChatHelperForward)
                MessageUploadService.shared.uploadMessage(
                    model: forwardedMessage,
                    filePath: nil, // Forwarded messages use existing URLs
                    userFTokenKey: contactToken.isEmpty ? userFTokenKey : contactToken
                ) { success, errorMessage in
                    DispatchQueue.main.async {
                        if success {
                            completedMessages += 1
                            print("✅ Forward: Successfully forwarded message \(messageIndex + 1) to \(contactName)")
                            // Check if message exists in Firebase and stop progress bar (matching Android)
                            self.checkMessageInFirebaseAndStopProgress(messageId: newMessageId, receiverUid: contactId)
                        } else {
                            failedMessages += 1
                            print("🚫 Forward: Failed to forward message \(messageIndex + 1) to \(contactName): \(errorMessage ?? "Unknown error")")
                            // Keep receiverLoader as 0 to show progress bar (message still pending)
                        }
                        
                        // Check if all messages are processed
                        if completedMessages + failedMessages >= totalMessages {
                            // Completion reached; no toast needed
                            
                            // Exit multi-select mode after forwarding (matching Android chatAdapter.exitMultiSelectMode())
                            exitMultiSelectMode()
                            
                            // Clear selected messages
                            selectedMessagesForForward.removeAll()
                        }
                    }
                }
                
                // Add small delay to prevent overwhelming the server (matching Android Thread.sleep(100))
                if messageIndex < selectedMessagesForForward.count - 1 || contactIndex < contacts.count - 1 {
                    Thread.sleep(forTimeInterval: 0.1)
                }
            }
        }
    }
    
    // MARK: - Delete Message Handler (matching Android deleteLyt.setOnClickListener)
    private func deleteMessage(message: ChatMessage) {
        print("🔴 [deleteMessage] Deleting message: \(message.id)")
        
        // Get current timestamp and message timestamp
        // Android uses milliseconds, iOS timestamp is TimeInterval (seconds), so convert to milliseconds
        let currentTimestamp = Int64(Date().timeIntervalSince1970 * 1000) // Current time in milliseconds
        let messageTimestamp = Int64(message.timestamp * 1000) // Convert TimeInterval (seconds) to milliseconds
        let diffMillis = currentTimestamp - messageTimestamp
        let totalHours = diffMillis / (1000 * 60 * 60)
        
        print("🔴 [deleteMessage] Current timestamp: \(currentTimestamp), Message timestamp: \(messageTimestamp)")
        print("🔴 [deleteMessage] Total hours: \(totalHours)")
        
        // Get receiver and sender rooms
        let receiverRoom = getReceiverRoom()
        let senderRoom = getSenderRoom()
        let database = Database.database().reference()
        
        // Delete from Firebase (matching Android delete functionality)
        if totalHours <= 24 {
            // Message is less than 24 hours old - delete from both rooms
            print("🔴 [deleteMessage] Message is less than 24 hours old, deleting from both rooms")
            
            // Delete from receiver room first
            database.child(Constant.CHAT).child(receiverRoom).child(message.id).removeValue { error, _ in
                if let error = error {
                    print("🔴 [deleteMessage] Error deleting from receiver room: \(error.localizedDescription)")
                } else {
                    print("🔴 [deleteMessage] Successfully deleted from receiver room")
                    
                    // Delete from sender room
                    database.child(Constant.CHAT).child(senderRoom).child(message.id).removeValue { error, _ in
                        if let error = error {
                            print("🔴 [deleteMessage] Error deleting from sender room: \(error.localizedDescription)")
                        } else {
                            print("🔴 [deleteMessage] Successfully deleted from sender room")
                            
                            // Remove from local messages list (matching Android removeItem)
                            DispatchQueue.main.async {
                                if let index = self.messages.firstIndex(where: { $0.id == message.id }) {
                                    self.messages.remove(at: index)
                                    print("🔴 [deleteMessage] Removed message from local list at index: \(index)")
                                    self.updateEmptyState(isEmpty: self.messages.isEmpty)
                                }
                            }
                            
                            // Call API to delete from server (matching Android Webservice.delete_chatingindivisual)
                            ApiService.delete_chatingindivisual(
                                modelId: message.id,
                                senderId: message.uid,
                                receiverId: self.contact.uid
                            ) { success, message in
                                DispatchQueue.main.async {
                                    if success {
                                        print("🔴 [deleteMessage] API delete SUCCESS: \(message)")
                                    } else {
                                        print("🔴 [deleteMessage] API delete FAILED: \(message)")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } else {
            // Message is older than 24 hours - only delete from receiver room
            print("🔴 [deleteMessage] Message is older than 24 hours, deleting from receiver room only")
            
            database.child(Constant.CHAT).child(receiverRoom).child(message.id).removeValue { error, _ in
                if let error = error {
                    print("🔴 [deleteMessage] Error deleting from receiver room: \(error.localizedDescription)")
                } else {
                    print("🔴 [deleteMessage] Successfully deleted from receiver room")
                    
                    // Remove from local messages list (matching Android removeItem)
                    DispatchQueue.main.async {
                        if let index = self.messages.firstIndex(where: { $0.id == message.id }) {
                            self.messages.remove(at: index)
                            print("🔴 [deleteMessage] Removed message from local list at index: \(index)")
                            self.updateEmptyState(isEmpty: self.messages.isEmpty)
                        }
                    }
                    
                    // Call API to delete from server (matching Android Webservice.delete_chatingindivisual)
                    ApiService.delete_chatingindivisual(
                        modelId: message.id,
                        senderId: message.uid,
                        receiverId: self.contact.uid
                    ) { success, message in
                        DispatchQueue.main.async {
                            if success {
                                print("🔴 [deleteMessage] API delete SUCCESS: \(message)")
                            } else {
                                print("🔴 [deleteMessage] API delete FAILED: \(message)")
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Send Button Handler (matching Android sendGrp.setOnClickListener)
    private func handleSendButtonClick() {
        print("DIALOGUE_DEBUG: === SEND BUTTON CLICKED ===")
        
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
        
        // Normal message send
        let message = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        
        // Capture values needed in the closure
        let receiverUid = contact.uid
        let isReplyVisible = showReplyLayout
        let replyMsg = replyMessage
        let replyType = replyDataType
        let replyMsgId = replyMessageId
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
                
                // Reply logic (matching Android createMessageModel - line 14458)
                // If reply layout is visible, include reply data
                let replytextData: String?
                let replyKey: String?
                let replyTypeValue: String?
                let replyOldData: String?
                let replyCrtPostion: String?
                
                if isReplyVisible {
                    // Reply message - include reply data (matching Android reply logic)
                    replytextData = message // Current message text (matching Android binding.messageBox.getText().toString().trim())
                    replyKey = "ReplyKey" // Constant.ReplyKey (matching Android)
                    replyTypeValue = "Text" // Constant.Text (matching Android)
                    replyOldData = replyMsg // Preview text like "Photo", "Video" (matching Android binding.msgreply.getText().toString())
                    replyCrtPostion = replyMsgId // Original message ID (matching Android binding.listcrntpostion.getText().toString())
                } else {
                    // Non-reply message
                    replytextData = nil
                    replyKey = nil
                    replyTypeValue = nil
                    replyOldData = nil
                    replyCrtPostion = nil
                }
                
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
                    replytextData: replytextData,
                    replyKey: replyKey,
                    replyType: replyTypeValue,
                    replyOldData: replyOldData,
                    replyCrtPostion: replyCrtPostion,
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
        
                // Store message in SQLite pending table before upload (matching Android insertPendingMessage)
                DatabaseHelper.shared.insertPendingMessage(newMessage)
                print("✅ [PendingMessages] Message stored in pending table: \(modelId)")
                
                // Check message limit status
                if limitStatusValue == "0" {
                    // Upload message using MessageUploadService (matching Android)
                    DispatchQueue.main.async {
                        // Get user FCM token
                        let userFTokenKey = UserDefaults.standard.string(forKey: Constant.FCM_TOKEN) ?? ""
                        let deviceType = Constant.deviceType
                        
                        // Use MessageUploadService (matching Android MessageUploadService)
                        MessageUploadService.shared.uploadMessage(
                            model: newMessage,
                            filePath: nil, // Text messages don't have files
                            userFTokenKey: userFTokenKey
                        ) { success, errorMessage in
                            if success {
                                print("✅ MessageUploadService: Message uploaded successfully with ID: \(modelId)")
                                
                                // Check if message exists in Firebase before updating receiverLoader (matching Android)
                                // Android: Checks if modelId exists in database, then sets receiverLoader to 1
                                let receiverUid = self.contact.uid
                                let senderId = Constant.SenderIdMy
                                let receiverRoom = receiverUid + senderId
                                let database = Database.database().reference()
                                let messageRef = database.child(Constant.CHAT).child(receiverRoom).child(modelId)
                                
                                // Check if message exists in Firebase and stop progress bar (matching Android)
                                self.checkMessageInFirebaseAndStopProgress(messageId: modelId, receiverUid: receiverUid)
                            } else {
                                print("🚫 MessageUploadService: Error uploading message: \(errorMessage ?? "Unknown error")")
                                // Keep receiverLoader as 0 to show progress bar (message still pending)
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
                
                // Update UI on main thread - Add message immediately with progress bar (matching Android)
                DispatchQueue.main.async {
                    // Add message to list immediately with receiverLoader: 0 (pending/uploading)
                    // This shows the animated progress bar (matching Android messageList.add + itemAdd)
                    print("🔍 [ProgressBar] 📤 ADDING MESSAGE TO UI with receiverLoader: \(newMessage.receiverLoader)")
                    print("🔍 [ProgressBar]   - Message ID: \(newMessage.id.prefix(8))...")
                    print("🔍 [ProgressBar]   - dataType: \(newMessage.dataType)")
                    print("🔍 [ProgressBar]   - isSentByMe: \(newMessage.uid == Constant.SenderIdMy)")
                    if newMessage.receiverLoader == 0 {
                        print("🔍 [ProgressBar]   ⚠️ PROGRESS BAR WILL BE SHOWN (receiverLoader == 0)")
                    } else {
                        print("🔍 [ProgressBar]   ✅ PROGRESS BAR WILL BE HIDDEN (receiverLoader == \(newMessage.receiverLoader))")
                    }
                    self.messages.append(newMessage)
                    
                    // Set last item visible to show progress (matching Android setLastItemVisible(true))
                    self.isLastItemVisible = true
                    self.showScrollDownButton = false
                    
                    // Clear typing status when message is sent
                    self.clearTypingStatus()
                    
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
                    
                    // Scroll to last message (matching Android scrollToPosition)
                    // This will be handled by ScrollViewReader in messageListView
                    self.pendingInitialScrollId = newMessage.id
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
    
    // MARK: - Photo Button Handler (matching Android galleryLyt.setOnClickListener)
    private func handlePhotoButtonClick() {
        print("ImageUpload: === GALLERY BUTTON CLICKED (Main) ===")
        
        // Light haptic feedback (Android-style tap vibration)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Hide keyboard and focus message box (matching Android hideKeyboardAndFocusMessageBox)
        isMessageFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        // Show emoji button (matching Android binding.emoji.setVisibility(View.VISIBLE))
        // In SwiftUI, emoji button visibility is controlled by showEmojiPicker state
        // We don't need to explicitly show it here as it's part of the UI
        
        // Set message box hint to "Message on Ec" (matching Android)
        // In SwiftUI, placeholder is set in TextField, but we can update it if needed
        
        // Set send button to mic icon (matching Android binding.send.setImageResource(R.drawable.mike))
        // This is handled automatically by UI when messageText is empty and selectedAssetIds is empty
        
        // Hide multi-select counter (matching Android binding.multiSelectSmallCounterText.setVisibility(View.GONE))
        selectedAssetIds.removeAll()
        selectedCount = 0
        
        // Save gallery picker state before opening image picker (don't hide it - will restore on back)
        wasGalleryPickerOpenBeforeImagePicker = showGalleryPicker
        
        // Hide emoji picker if open
        if showEmojiPicker {
            withAnimation {
                showEmojiPicker = false
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
    
    // MARK: - Video Button Handler (matching Android videoLyt.setOnClickListener)
    private func handleVideoButtonClick() {
        print("VideoUpload: === VIDEO BUTTON CLICKED (Main) ===")
        
        // Light haptic feedback (Android-style tap vibration)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Hide keyboard and focus message box (matching Android hideKeyboardAndFocusMessageBox)
        isMessageFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        // Show emoji button (matching Android binding.emoji.setVisibility(View.VISIBLE))
        // In SwiftUI, emoji button visibility is controlled by showEmojiPicker state
        
        // Set message box hint to "Message on Ec" (matching Android)
        // In SwiftUI, placeholder is set in TextField, but we can update it if needed
        
        // Set send button to mic icon (matching Android binding.send.setImageResource(R.drawable.mike))
        // This is handled automatically by UI when messageText is empty and selectedAssetIds is empty
        
        // Hide multi-select counter (matching Android binding.multiSelectSmallCounterText.setVisibility(View.GONE))
        selectedAssetIds.removeAll()
        selectedCount = 0
        
        // Save gallery picker state before opening video picker (don't hide it - will restore on back)
        wasGalleryPickerOpenBeforeVideoPicker = showGalleryPicker
        
        // Hide emoji picker if open
        if showEmojiPicker {
            withAnimation {
                showEmojiPicker = false
            }
        }
        
        // Launch WhatsApp-like video picker (matching Android WhatsAppLikeVideoPicker)
        // Note: Android uses GlobalPermissionPopup.handleVideoClickWithLimitedAccess first
        // For iOS, we'll request permission directly in the picker
        print("VideoUpload: === LAUNCHING WhatsAppLikeVideoPicker ===")
        print("VideoUpload: PICK_VIDEO_REQUEST_CODE: VideoPicker")
        print("VideoUpload: Current selectedAssetIds size: \(selectedAssetIds.count)")
        
        DispatchQueue.main.async {
            showWhatsAppVideoPicker = true
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
    
    // MARK: - Handle Video Picker Result
    private func handleVideoPickerResult(selectedAssets: [PHAsset], caption: String) {
        print("VideoUpload: === VIDEO PICKER RESULT RECEIVED ===")
        print("VideoUpload: Selected assets count: \(selectedAssets.count)")
        print("VideoUpload: Caption: '\(caption)'")
        
        // Videos are uploaded directly from MultiVideoPreviewDialog (matching Android flow)
        // This callback is called after videos are sent, so we just need to clear selections
        selectedAssetIds.removeAll()
        selectedCount = 0
        
        // Scroll to bottom to show new video messages (matching Android behavior)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if !self.messages.isEmpty {
                self.isLastItemVisible = true
                self.showScrollDownButton = false
            }
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
        
        // Show emoji button (matching Android binding.emoji.setVisibility(View.VISIBLE))
        // In SwiftUI, emoji button visibility is controlled by showEmojiPicker state
        
        // Set message box hint to "Message on Ec" (matching Android)
        // In SwiftUI, placeholder is set in TextField, but we can update it if needed
        
        // Set send button to mic icon (matching Android binding.send.setImageResource(R.drawable.mike))
        // This is handled automatically by UI when messageText is empty and selectedAssetIds is empty
        
        // Hide multi-select counter (matching Android binding.multiSelectSmallCounterText.setVisibility(View.GONE))
        selectedAssetIds.removeAll()
        selectedCount = 0
        
        // Save gallery picker state before opening file picker (don't hide it - will restore on back)
        wasGalleryPickerOpenBeforeDocumentPicker = showGalleryPicker
        
        // Hide emoji picker if open
        if showEmojiPicker {
            withAnimation {
                showEmojiPicker = false
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
        
        // Documents are uploaded directly from MultiDocumentPreviewDialog (matching Android flow)
        // This callback is called after documents are sent, so we just need to clear selections
        multiDocumentPreviewURLs.removeAll()
        multiDocumentPreviewCaption = ""
        
        // Scroll to bottom to show new document messages (matching Android behavior)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if !self.messages.isEmpty {
                self.isLastItemVisible = true
                self.showScrollDownButton = false
            }
        }
    }
    
    // MARK: - Contact Button Handler (matching Android contact button click)
    private func handleContactButtonClick() {
        print("ContactUpload: === CONTACT BUTTON CLICKED (Main) ===")
        
        // Light haptic feedback (Android-style tap vibration)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Hide keyboard and focus message box (matching Android hideKeyboardAndFocusMessageBox)
        isMessageFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        // Show emoji button (matching Android binding.emoji.setVisibility(View.VISIBLE))
        // In SwiftUI, emoji button visibility is controlled by showEmojiPicker state
        
        // Set message box hint to "Message on Ec" (matching Android)
        // In SwiftUI, placeholder is set in TextField, but we can update it if needed
        
        // Set send button to mic icon (matching Android binding.send.setImageResource(R.drawable.mike))
        // This is handled automatically by UI when messageText is empty and selectedAssetIds is empty
        
        // Hide multi-select counter (matching Android binding.multiSelectSmallCounterText.setVisibility(View.GONE))
        selectedAssetIds.removeAll()
        selectedCount = 0
        
        // Save gallery picker state before opening contact picker (don't hide it - will restore on back)
        wasGalleryPickerOpenBeforeContactPicker = showGalleryPicker
        
        // Hide emoji picker if open
        if showEmojiPicker {
            withAnimation {
                showEmojiPicker = false
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
    // MARK: - Handle Multi-Contact Send (matching Android upload logic)
    private func handleMultiContactSend(caption: String) {
        print("ContactUpload: === MULTI-CONTACT SEND ===")
        print("ContactUpload: Selected contacts count: \(multiContactPreviewContacts.count)")
        print("ContactUpload: Caption: '\(caption)'")
        
        // Contacts are uploaded directly from MultiContactPreviewDialog (matching Android flow)
        // This callback is called after contacts are sent, so we just need to clear selections
        multiContactPreviewContacts.removeAll()
        multiContactPreviewCaption = ""
        
        // Scroll to bottom to show new contact messages (matching Android behavior)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if !self.messages.isEmpty {
                self.isLastItemVisible = true
                self.showScrollDownButton = false
            }
        }
    }
    
    // MARK: - Handle Contact Picker Result (deprecated - now using preview dialog)
    private func handleContactPickerResult(selectedContacts: [ContactPickerInfo], caption: String) {
        print("ContactUpload: === CONTACT PICKER RESULT RECEIVED ===")
        print("ContactUpload: Selected contacts count: \(selectedContacts.count)")
        print("ContactUpload: Caption: '\(caption)'")
        
        // Convert ContactPickerInfo to ContactInfo (matching existing structure)
        let contactInfos: [ContactInfo] = selectedContacts.map { pickerInfo in
            ContactInfo(
                name: pickerInfo.name,
                phoneNumber: pickerInfo.phone ?? "",
                email: pickerInfo.email
            )
        }
        
        // TODO: Process selected contacts and upload them
        // This should match Android's onActivityResult handling for PICK_CONTACT_REQUEST_CODE
        // For now, we just update the UI state
        
        if !contactInfos.isEmpty {
            selectedCount = contactInfos.count
            
            // TODO: Process and upload selected contacts to Firebase
            // This should match Android's WhatsAppLikeContactPicker.uploadContactsToFirebase
            // For now, we'll just update the UI to show the selected count
        }
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
        if showEmojiPicker {
            withAnimation {
                showEmojiPicker = false
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
            DispatchQueue.main.async {
                if granted { completion(true) } else { completion(false) }
            }
        }
    }
    
    private func sendMessage() {
        // Legacy method - keeping for backward compatibility
        handleSendButtonClick()
    }
    
    // MARK: - Date Display Functions (matching Android date functionality)
    
    /// Format date text (matching Android date formatting logic)
    private func formatDateText(_ date: String) -> String {
        // Handle dates with ":" prefix (duplicate dates) - matching Android
        var cleanDate = date
        if date.contains(":") {
            cleanDate = date.replacingOccurrences(of: ":", with: "")
        }
        
        // Parse the date string (format: "yyyy-MM-dd")
        let inputDateFormatter = DateFormatter()
        inputDateFormatter.dateFormat = "yyyy-MM-dd"
        inputDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        guard let parsedDate = inputDateFormatter.date(from: cleanDate) else {
            // If parsing fails, return the original date
            return cleanDate
        }
        
        // Get current date and yesterday date for comparison
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let dateToCompare = calendar.startOfDay(for: parsedDate)
        
        // Compare dates (matching Android)
        if dateToCompare == today {
            return "Today"
        } else if dateToCompare == yesterday {
            return "Yesterday"
        } else {
            // Format date as "07 December 2025" (matching user's requested format)
            let outputDateFormatter = DateFormatter()
            outputDateFormatter.dateFormat = "dd MMMM yyyy"
            outputDateFormatter.locale = Locale(identifier: "en_US_POSIX")
            return outputDateFormatter.string(from: parsedDate)
        }
    }
    
    /// Hide date view immediately (matching Android collapse(binding.date) in hideDateRunnable)
    private func hideDateView() {
        // Cancel any pending timers
        hideDateWorkItem?.cancel()
        dateScrollDebounceWorkItem?.cancel()
        
        // Hide immediately (matching Android collapse function)
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                self.showDateView = false
            }
            print("📅 [DATE_HIDE] hideDateView executed | showDateView(after)=\(self.showDateView)")
        }
    }
    
    /// Show date view with animation (parity with Android expand)
    private func expandDateView() {
        // Cancel any existing hide timers
        hideDateWorkItem?.cancel()
        dateScrollDebounceWorkItem?.cancel()
        
        // Set date text from latest message (fallback to today)
        if let lastDate = messages.last?.currentDate {
            dateText = formatDateText(lastDate)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            dateText = formatDateText(formatter.string(from: Date()))
        }
        
        print("📅 [DATE_EXPAND] expandDateView called | messages.count=\(messages.count) | dateText='\(dateText)' | showDateView(before)=\(showDateView)")
        
        // Show immediately (Android expand)
        withAnimation(.easeIn(duration: 0.2)) {
            showDateView = true
        }
        
        // Auto-collapse after 1s even without scrolling (requested behavior)
        let workItem = DispatchWorkItem { [self] in
            // Force collapse regardless of scroll state
            isScrolling = false
            withAnimation(.easeOut(duration: 0.2)) {
                showDateView = false
            }
            print("📅 [DATE_COLLAPSE_TIMER] Auto-collapsed after tap | showDateView(after)=\(showDateView)")
        }
        hideDateWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }
    
    /// Hide date view with animation (parity with Android collapse)
    private func collapseDateView() {
        hideDateView()
    }
    
    // MARK: - Helper Functions (matching Android utility functions)
    
    /// Collapse/hide view (matching Android collapse function)
    /// In SwiftUI, we use @State variables to control visibility
    private func collapse(_ showFlag: inout Bool) {
        withAnimation {
            showFlag = false
        }
    }
    
    /// Check if file exists (matching Android doesFileExist)
    private func doesFileExist(filePath: String) -> Bool {
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: filePath)
    }
    
    // MARK: - Gallery helpers (custom dialog first, when user opens gallery)
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
    
    // MARK: - Handle Multi-Image Send (matching Android upload logic)
    private func handleMultiImageSend(caption: String) {
        print("DIALOGUE_DEBUG: === MULTI-IMAGE SEND ===")
        print("DIALOGUE_DEBUG: Selected images count: \(selectedAssetIds.count)")
        print("DIALOGUE_DEBUG: Caption: '\(caption)'")
        
        // Respect message limit (same guard as text flow)
        guard limitStatus == "0" else {
            Constant.showToast(message: "Msg limit set for privacy in a day - \(totalMsgLimit)")
            return
        }
        
        // Get selected assets from photoAssets
        let selectedAssets = photoAssets.filter { selectedAssetIds.contains($0.localIdentifier) }
        
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
        let modelId = UUID().uuidString
        
        // Capture reply context if present
        let replyMsg = replyMessage
        let replyType = replyDataType
        
        // Create message immediately (matching Android - simple approach)
        // Android: creates model with imageFile.toString() (local file path) and adds to messageList immediately
        let firstFileName = "\(modelId)_0.jpg"
        let localFileURL = getLocalImageURL(fileName: firstFileName)
        
        // Create placeholder selectionBunch items so bunch view can render immediately
        // These will be updated with actual URLs after upload
        var placeholderSelectionBunch: [SelectionBunchModel] = []
        for index in 0..<selectedAssets.count {
            let fileName = "\(modelId)_\(index).jpg"
            placeholderSelectionBunch.append(SelectionBunchModel(imgUrl: "", fileName: fileName))
        }
        
        // Create message with local file path (matching Android imageFile.toString())
        let newMessage = ChatMessage(
            id: modelId,
            uid: senderId,
            message: "",
            time: currentDateTimeString,
            document: localFileURL.path, // Local file path (matching Android imageFile.toString())
            dataType: Constant.img,
            fileExtension: "jpg",
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
            fileName: firstFileName,
            thumbnail: nil,
            fileNameThumbnail: nil,
            caption: trimmedCaption,
            notification: 1,
            currentDate: currentDateString,
            emojiModel: [EmojiModel(name: "", emoji: "")],
            emojiCount: nil,
            timestamp: timestamp,
            imageWidth: nil, // Will be updated after export
            imageHeight: nil, // Will be updated after export
            aspectRatio: nil, // Will be updated after export
            selectionCount: "\(selectedAssets.count)",
            selectionBunch: placeholderSelectionBunch.count >= 2 ? placeholderSelectionBunch : nil, // Show bunch view if 2+ images
            receiverLoader: 0 // Show progress bar (matching Android setLastItemVisible(true))
        )
        
        // Store message in SQLite pending table before upload (matching Android insertPendingMessage)
        DatabaseHelper.shared.insertPendingMessage(newMessage)
        print("✅ [PendingMessages] Image message stored in pending table: \(modelId)")
        
        // Add to UI immediately (matching Android: messageList.add, itemAdd, setLastItemVisible, notifyItemInserted, scrollToPosition)
        DispatchQueue.main.async {
            if !self.messages.contains(where: { $0.id == modelId }) {
                print("🔍 [ProgressBar] 📤 ADDING IMAGE MESSAGE TO UI")
                print("🔍 [ProgressBar]   - Message ID: \(modelId.prefix(8))...")
                print("🔍 [ProgressBar]   - receiverLoader: \(newMessage.receiverLoader)")
                if newMessage.receiverLoader == 0 {
                    print("🔍 [ProgressBar]   ⚠️ PROGRESS BAR WILL BE SHOWN (receiverLoader == 0)")
                }
                self.messages.append(newMessage)
                self.isLastItemVisible = true // Show progress for pending message (matching Android setLastItemVisible(true))
                self.showScrollDownButton = false // Hide down button (matching Android downCardview.setVisibility(View.GONE))
                print("✅ [MULTI_IMAGE] Message added to UI immediately: \(modelId)")
            }
        }
        
        // Upload in background (matching Android UploadChatHelper.uploadContent)
        // Export and upload all images
        let dispatchGroup = DispatchGroup()
        let lockQueue = DispatchQueue(label: "com.enclosure.multiImageUpload.lock")
        
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
            
            self.exportImageAsset(asset, fileName: remoteFileName) { exportResult in
                switch exportResult {
                case .failure(let error):
                    lockQueue.sync { uploadErrors.append(error) }
                    dispatchGroup.leave()
                case .success(let export):
                    // Save image to local storage (matching Android Enclosure/Media/Images)
                    self.saveImageToLocalStorage(data: export.data, fileName: remoteFileName)
                    
                    // Upload to Firebase Storage
                    self.uploadImageFileToFirebase(data: export.data, remoteFileName: remoteFileName) { uploadResult in
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
                print("🚫 [MULTI_IMAGE] Upload failed - no results")
                Constant.showToast(message: "Unable to upload images. Please try again.")
                return
            }
            
            if !uploadErrors.isEmpty {
                print("⚠️ [MULTI_IMAGE] Some uploads failed: \(uploadErrors.count) errors")
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
            
            // Update message with Firebase URLs (matching Android - update after upload)
            DispatchQueue.main.async {
                if let messageIndex = self.messages.firstIndex(where: { $0.id == modelId }) {
                    var updatedMessage = self.messages[messageIndex]
                    // Update with Firebase download URL
                    updatedMessage.document = first.downloadURL
                    updatedMessage.fileName = first.fileName
                    updatedMessage.imageWidth = "\(first.width)"
                    updatedMessage.imageHeight = "\(first.height)"
                    updatedMessage.aspectRatio = aspectRatioValue
                    updatedMessage.selectionBunch = selectionBunchModels
                    
                    // Update the message in the list
                    self.messages[messageIndex] = updatedMessage
                    
                    // Update pending message in SQLite with actual URLs
                    DatabaseHelper.shared.insertPendingMessage(updatedMessage)
                    print("✅ [MULTI_IMAGE] Message updated with Firebase URLs: \(modelId)")
                    
                    // Upload to API and Firebase RTDB (matching Android UploadChatHelper)
            let userFTokenKey = UserDefaults.standard.string(forKey: Constant.FCM_TOKEN) ?? ""
            
            MessageUploadService.shared.uploadMessage(
                        model: updatedMessage,
                filePath: nil,
                userFTokenKey: userFTokenKey
            ) { success, errorMessage in
                if success {
                    print("✅ [MULTI_IMAGE] Uploaded \(sortedResults.count) images for modelId=\(modelId)")
                            // Check if message exists in Firebase and stop progress bar (matching Android)
                            self.checkMessageInFirebaseAndStopProgress(messageId: modelId, receiverUid: receiverUid)
                } else {
                    print("🚫 [MULTI_IMAGE] Upload error: \(errorMessage ?? "Unknown error")")
                    Constant.showToast(message: "Failed to send images. Please try again.")
                            // Keep receiverLoader as 0 to show progress bar (message still pending)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Local Storage Helpers (matching Android getExternalFilesDir)
    
    /// Get local images directory path (matching Android Enclosure/Media/Images)
    private func getLocalImagesDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagesDir = documentsPath.appendingPathComponent("Enclosure/Media/Images", isDirectory: true)
        
        // Create directory if it doesn't exist (matching Android mkdirs)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true, attributes: nil)
        
        return imagesDir
    }
    
    /// Check if local image file exists (matching Android doesFileExist)
    private func doesLocalImageExist(fileName: String) -> Bool {
        let imagesDir = getLocalImagesDirectory()
        let fileURL = imagesDir.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    /// Get local image file URL (matching Android exactPath2 + "/" + fileName)
    private func getLocalImageURL(fileName: String) -> URL {
        let imagesDir = getLocalImagesDirectory()
        return imagesDir.appendingPathComponent(fileName)
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
            print("")
            print("═══════════════════════════════════════════════════════════")
            print("📱 [LOCAL_STORAGE] FULL DIRECTORY PATH:")
            print("═══════════════════════════════════════════════════════════")
            print("📍 \(imagesDir.path)")
            print("═══════════════════════════════════════════════════════════")
            
            #if targetEnvironment(simulator)
            // Extract and print APP_ID and DEVICE_ID for easy access
            let pathComponents = imagesDir.path.components(separatedBy: "/")
            if let appIdIndex = pathComponents.firstIndex(of: "Application"),
               appIdIndex + 1 < pathComponents.count {
                let appId = pathComponents[appIdIndex + 1]
                print("📱 APP_ID: \(appId)")
            }
            if let deviceIdIndex = pathComponents.firstIndex(of: "Devices"),
               deviceIdIndex + 1 < pathComponents.count {
                let deviceId = pathComponents[deviceIdIndex + 1]
                print("📱 DEVICE_ID: \(deviceId)")
            }
            print("")
            print("💡 TO ACCESS IN FINDER:")
            print("   1. Press Cmd + Shift + G")
            print("   2. Paste: \(imagesDir.path)")
            print("   3. Press Enter")
            print("═══════════════════════════════════════════════════════════")
            #endif
            print("")
        } catch {
            print("🚫 [LOCAL_STORAGE] Error saving image to local storage: \(error.localizedDescription)")
        }
    }
    
    /// Debug function: List all saved images in local storage
    private func listSavedImages() {
        let imagesDir = getLocalImagesDirectory()
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: imagesDir, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])
            
            print("📱 [LOCAL_STORAGE] ===== Saved Images List =====")
            print("📱 [LOCAL_STORAGE] Directory: \(imagesDir.path)")
            print("📱 [LOCAL_STORAGE] Total files: \(files.count)")
            
            for (index, file) in files.enumerated() {
                let fileName = file.lastPathComponent
                let fileSize = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                let creationDate = (try? file.resourceValues(forKeys: [.creationDateKey]))?.creationDate
                
                print("📱 [LOCAL_STORAGE] \(index + 1). \(fileName)")
                print("   Size: \(fileSize) bytes (\(fileSize / 1024) KB)")
                if let date = creationDate {
                    print("   Created: \(date)")
                }
            }
            print("📱 [LOCAL_STORAGE] ==============================")
        } catch {
            print("🚫 [LOCAL_STORAGE] Error listing images: \(error.localizedDescription)")
        }
    }
    
    /// Debug function: Get local images directory path (for manual checking)
    private func getLocalImagesDirectoryPath() -> String {
        let imagesDir = getLocalImagesDirectory()
        return imagesDir.path
    }
    
    // Export PHAsset to a temporary JPEG file
    private func exportImageAsset(_ asset: PHAsset, fileName: String, completion: @escaping (Result<(data: Data, width: Int, height: Int), Error>) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.version = .current
        
        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
            guard let data = data else {
                completion(.failure(MultiImageUploadError.dataUnavailable))
                return
            }
            
            // Convert to JPEG to match Android flow and reduce size
            let image = UIImage(data: data)
            let jpegData = image?.jpegData(compressionQuality: 0.85) ?? data
            let width = image?.cgImage?.width ?? Int(asset.pixelWidth)
            let height = image?.cgImage?.height ?? Int(asset.pixelHeight)
            completion(.success((jpegData, width, height)))
        }
    }
    
    // Upload image data to Firebase Storage and return its download URL
    private func uploadImageFileToFirebase(data: Data, remoteFileName: String, completion: @escaping (Result<String, Error>) -> Void) {
        let storagePath = "\(Constant.CHAT)/\(Constant.SenderIdMy)_\(contact.uid)/\(remoteFileName)"
        let ref = Storage.storage().reference().child(storagePath)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        // Begin background task to avoid watchdog termination during uploads
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        DispatchQueue.main.async {
            bgTask = UIApplication.shared.beginBackgroundTask(withName: "UploadImage") {
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
                    completion(.failure(MultiImageUploadError.downloadURLMissing))
                    return
                }
                
                completion(.success(url.absoluteString))
            }
        }
    }
    
    // Scroll-based date visibility removed per latest requirements
    
    // MARK: - Voice Recording Functions
    
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
        
        // Check message limit (matching Android)
        guard limitStatus == "0" else {
            Constant.showToast(message: "Msg limit set for privacy in a day - \(totalMsgLimit)")
            return
        }
        
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
                    // Note: No [weak self] needed since ChattingScreen is a struct (value type)
                    self.recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                        // Update duration
                        self.recordingDuration += 0.1
                        
                        // Update progress bar: progress decreases from 100 to 0 as time increases (matching Android CountDownTimer)
                        // Android: progress = (int) (millisUntilFinished / (60000 / 100))
                        // millisUntilFinished starts at 60000 and decreases to 0
                        // So: progress = millisUntilFinished / 600, which gives 100 to 0
                        // In our case: progress = ((60.0 - elapsedSeconds) / 60.0) * 100.0
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
        uploadAudioToFirebase(fileURL: fileURL, duration: audioDuration, fileName: fileURL.lastPathComponent)
        
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
    
    /// Upload audio to Firebase Storage and send message (matching Android upload logic)
    private func uploadAudioToFirebase(fileURL: URL, duration: String, fileName: String) {
        print("VoiceRecording: === UPLOAD AUDIO TO FIREBASE ===")
        print("VoiceRecording: File: \(fileURL.path), Duration: \(duration), FileName: \(fileName)")
        
        guard let audioData = try? Data(contentsOf: fileURL) else {
            print("VoiceRecording: Failed to read audio file data")
            Constant.showToast(message: "Failed to read audio file")
            return
        }
        
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
        let modelId = UUID().uuidString
        
        // Upload to Firebase Storage
        // Use .m4a extension (iOS AAC format) - backend should handle both .mp3 and .m4a
        let storagePath = "\(Constant.CHAT)/\(senderId)_\(receiverUid)/\(modelId).m4a"
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
                
                // Create ChatMessage (matching Android messageModel with voiceAudio dataType)
                let newMessage = ChatMessage(
                    id: modelId,
                    uid: senderId,
                    message: "",
                    time: currentDateTimeString,
                    document: downloadURL.absoluteString,
                    dataType: Constant.voiceAudio,
                    fileExtension: "m4a", // iOS AAC format (Android uses .mp3 but same AAC codec)
                    name: nil,
                    phone: nil,
                    micPhoto: micPhoto,
                    miceTiming: duration, // Audio duration in format "MM:SS"
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
                    selectionCount: nil,
                    selectionBunch: nil,
                    receiverLoader: 0
                )
                
                // Store message in SQLite pending table before upload (matching Android insertPendingMessage)
                DatabaseHelper.shared.insertPendingMessage(newMessage)
                print("✅ [PendingMessages] Voice audio message stored in pending table: \(modelId)")
                
                // Add to UI immediately with progress bar (matching Android messageList.add + itemAdd)
                DispatchQueue.main.async {
                    print("🔍 [ProgressBar] 📤 ADDING VOICE MESSAGE TO UI")
                    print("🔍 [ProgressBar]   - Message ID: \(modelId.prefix(8))...")
                    print("🔍 [ProgressBar]   - receiverLoader: \(newMessage.receiverLoader)")
                    if newMessage.receiverLoader == 0 {
                        print("🔍 [ProgressBar]   ⚠️ PROGRESS BAR WILL BE SHOWN (receiverLoader == 0)")
                    }
                    self.messages.append(newMessage)
                    self.isLastItemVisible = true
                    self.showScrollDownButton = false
                }
                
                // Upload via MessageUploadService
                let userFTokenKey = UserDefaults.standard.string(forKey: Constant.FCM_TOKEN) ?? ""
                
                MessageUploadService.shared.uploadMessage(
                    model: newMessage,
                    filePath: fileURL.path,
                    userFTokenKey: userFTokenKey
                ) { success, errorMessage in
                    if success {
                        print("✅ [VOICE_RECORDING] Uploaded audio for modelId=\(modelId)")
                        // Check if message exists in Firebase and stop progress bar (matching Android)
                        self.checkMessageInFirebaseAndStopProgress(messageId: modelId, receiverUid: receiverUid)
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
}

// MARK: - UIKit swipe recognizer wrapper (left-to-right)
struct SwipeGestureView: UIViewRepresentable {
    var onSwipeRight: () -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        
        let recognizer = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSwipe(_:)))
        recognizer.direction = .right
        recognizer.cancelsTouchesInView = false // do not block scrolling
        view.addGestureRecognizer(recognizer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onSwipeRight: onSwipeRight)
    }
    
    class Coordinator: NSObject {
        let onSwipeRight: () -> Void
        
        init(onSwipeRight: @escaping () -> Void) {
            self.onSwipeRight = onSwipeRight
        }
        
        @objc func handleSwipe(_ recognizer: UISwipeGestureRecognizer) {
            guard recognizer.direction == .right else { return }
            onSwipeRight()
        }
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
        case linkTitle, linkDescription, linkImageUrl, favIconUrl // Rich link preview fields
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
    
    // Rich link preview fields
    var linkTitle: String?
    var linkDescription: String?
    var linkImageUrl: String?
    var favIconUrl: String?
    
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
        receiverLoader: Int = 0,
        linkTitle: String? = nil,
        linkDescription: String? = nil,
        linkImageUrl: String? = nil,
        favIconUrl: String? = nil
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
        self.linkTitle = linkTitle
        self.linkDescription = linkDescription
        self.linkImageUrl = linkImageUrl
        self.favIconUrl = favIconUrl
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

// MARK: - Group Chat Message Model (matching Android group_messageModel.java)
struct GroupChatMessage: Identifiable, Codable, Equatable {
    // CodingKeys to map Swift property names to JSON keys (matching Android)
    enum CodingKeys: String, CodingKey {
        case id, uid, message, time, document, dataType
        case fileExtension = "extension" // Map fileExtension to "extension" in JSON
        case name, phone, micPhoto, miceTiming, createdBy, userName
        case receiverUid, docSize, fileName, thumbnail, fileNameThumbnail, caption
        case currentDate, imageWidth, imageHeight, aspectRatio, active, selectionCount, selectionBunch
    }
    
    // Core message fields (matching Android group_messageModel)
    var id: String // modelId
    var uid: String // senderId
    var message: String // message text
    var time: String // formatted time "hh:mm a"
    var document: String // document URL (image/video/document)
    var dataType: String // Text, img, video, doc, contact, voiceAudio
    var fileExtension: String? // extension
    var name: String? // contact name (for contact type)
    var phone: String? // contact phone (for contact type)
    var miceTiming: String? // audio timing (for voice messages)
    var micPhoto: String? // sender profile photo
    var createdBy: String? // created by user ID
    var userName: String? // sender user name
    var receiverUid: String // receiverUid (groupId for groups)
    
    // File/document fields
    var docSize: String?
    var fileName: String?
    var thumbnail: String?
    var fileNameThumbnail: String?
    var caption: String?
    
    // Date field
    var currentDate: String?
    
    // Image dimensions
    var imageWidth: String?
    var imageHeight: String?
    var aspectRatio: String?
    
    // Active state (0 = sending, 1 = sent) - matching Android active field
    var active: Int // 0 = sending, 1 = sent
    
    // Selection bunch (for multi-image messages)
    var selectionCount: String?
    var selectionBunch: [SelectionBunchModel]?
    
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
        miceTiming: String? = nil,
        micPhoto: String? = nil,
        createdBy: String? = nil,
        userName: String? = nil,
        receiverUid: String,
        docSize: String? = nil,
        fileName: String? = nil,
        thumbnail: String? = nil,
        fileNameThumbnail: String? = nil,
        caption: String? = nil,
        currentDate: String? = nil,
        imageWidth: String? = nil,
        imageHeight: String? = nil,
        aspectRatio: String? = nil,
        active: Int = 0, // Default to sending state (0)
        selectionCount: String? = nil,
        selectionBunch: [SelectionBunchModel]? = nil
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
        self.miceTiming = miceTiming
        self.micPhoto = micPhoto
        self.createdBy = createdBy
        self.userName = userName
        self.receiverUid = receiverUid
        self.docSize = docSize
        self.fileName = fileName
        self.thumbnail = thumbnail
        self.fileNameThumbnail = fileNameThumbnail
        self.caption = caption
        self.currentDate = currentDate
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.aspectRatio = aspectRatio
        self.active = active
        self.selectionCount = selectionCount
        self.selectionBunch = selectionBunch
    }
    
    // Convert to dictionary for Firebase (matching Android toMap() method)
    func toDictionary() -> [String: Any] {
        var map: [String: Any] = [:]
        
        map["uid"] = uid
        map["message"] = message
        map["time"] = time
        map["document"] = document
        map["dataType"] = dataType
        map["extension"] = fileExtension ?? ""
        map["name"] = name ?? ""
        map["phone"] = phone ?? ""
        map["micPhoto"] = micPhoto ?? ""
        map["miceTiming"] = miceTiming ?? ""
        map["createdBy"] = createdBy ?? ""
        map["userName"] = userName ?? ""
        map["modelId"] = id
        map["receiverUid"] = receiverUid
        map["docSize"] = docSize ?? ""
        map["fileName"] = fileName ?? ""
        map["thumbnail"] = thumbnail ?? ""
        map["fileNameThumbnail"] = fileNameThumbnail ?? ""
        map["caption"] = caption ?? ""
        map["currentDate"] = currentDate ?? ""
        map["imageWidth"] = imageWidth ?? ""
        map["imageHeight"] = imageHeight ?? ""
        map["aspectRatio"] = aspectRatio ?? ""
        map["active"] = active
        map["selectionCount"] = selectionCount ?? ""
        
        // Serialize selectionBunch as a list of maps for reliable Firebase storage
        if let selectionBunch = selectionBunch, !selectionBunch.isEmpty {
            var bunchList: [[String: Any]] = []
            for item in selectionBunch {
                bunchList.append([
                    "imgUrl": item.imgUrl,
                    "fileName": item.fileName
                ])
            }
            map["selectionBunch"] = bunchList
            print("SelectionBunch: toDictionary(): writing selectionBunch size=\(bunchList.count)")
        } else {
            map["selectionBunch"] = NSNull()
            print("SelectionBunch: toDictionary(): selectionBunch is null/empty")
        }
        
        print("SelectionCount: GroupChatMessage.toDictionary(): selectionCount=\(selectionCount ?? "nil")")
        print("ImageDimensions: GroupChatMessage.toDictionary(): imageWidth=\(imageWidth ?? "nil"), imageHeight=\(imageHeight ?? "nil"), aspectRatio=\(aspectRatio ?? "nil")")
        
        return map
    }
    
    // Equatable conformance (matching Android equals() method)
    static func == (lhs: GroupChatMessage, rhs: GroupChatMessage) -> Bool {
        return lhs.id == rhs.id &&
            lhs.uid == rhs.uid &&
            lhs.message == rhs.message &&
            lhs.time == rhs.time &&
            lhs.document == rhs.document &&
            lhs.dataType == rhs.dataType &&
            lhs.fileExtension == rhs.fileExtension &&
            lhs.name == rhs.name &&
            lhs.phone == rhs.phone &&
            lhs.miceTiming == rhs.miceTiming &&
            lhs.micPhoto == rhs.micPhoto &&
            lhs.createdBy == rhs.createdBy &&
            lhs.userName == rhs.userName &&
            lhs.receiverUid == rhs.receiverUid &&
            lhs.docSize == rhs.docSize &&
            lhs.fileName == rhs.fileName &&
            lhs.thumbnail == rhs.thumbnail &&
            lhs.fileNameThumbnail == rhs.fileNameThumbnail &&
            lhs.caption == rhs.caption &&
            lhs.currentDate == rhs.currentDate &&
            lhs.imageWidth == rhs.imageWidth &&
            lhs.imageHeight == rhs.imageHeight &&
            lhs.aspectRatio == rhs.aspectRatio &&
            lhs.active == rhs.active &&
            lhs.selectionCount == rhs.selectionCount &&
            lhs.selectionBunch == rhs.selectionBunch
    }
    
    // Hashable conformance (matching Android hashCode() method)
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(uid)
        hasher.combine(message)
        hasher.combine(time)
        hasher.combine(document)
        hasher.combine(dataType)
        hasher.combine(fileExtension)
        hasher.combine(name)
        hasher.combine(phone)
        hasher.combine(miceTiming)
        hasher.combine(micPhoto)
        hasher.combine(createdBy)
        hasher.combine(userName)
        hasher.combine(receiverUid)
        hasher.combine(docSize)
        hasher.combine(fileName)
        hasher.combine(thumbnail)
        hasher.combine(fileNameThumbnail)
        hasher.combine(caption)
        hasher.combine(currentDate)
        hasher.combine(imageWidth)
        hasher.combine(imageHeight)
        hasher.combine(aspectRatio)
        hasher.combine(active)
        hasher.combine(selectionCount)
        hasher.combine(selectionBunch)
    }
    
    // Parse selectionBunch from Firebase snapshot (matching Android parseSelectionBunchFromSnapshot)
    static func parseSelectionBunchFromSnapshot(_ snapshot: [String: Any], model: inout GroupChatMessage) {
        if let selectionBunchData = snapshot["selectionBunch"] as? [[String: Any]] {
            var selectionBunch: [SelectionBunchModel] = []
            for bunchData in selectionBunchData {
                if let imgUrl = bunchData["imgUrl"] as? String,
                   let fileName = bunchData["fileName"] as? String {
                    selectionBunch.append(SelectionBunchModel(imgUrl: imgUrl, fileName: fileName))
                }
            }
            model.selectionBunch = selectionBunch
            print("SelectionBunch: Parsed selectionBunch from Firebase: \(selectionBunch.count) items for messageId=\(model.id)")
        } else {
            print("SelectionBunch: No selectionBunch data found in Firebase for messageId=\(model.id)")
            if model.selectionBunch == nil || model.selectionBunch?.isEmpty == true {
                model.selectionBunch = []
            } else {
                print("SelectionBunch: Preserving existing selectionBunch with \(model.selectionBunch?.count ?? 0) items for pending upload")
            }
        }
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

// MARK: - Emoji Data Model (matching Android Emoji class)
struct EmojiData: Codable, Identifiable {
    let id: String // Use codePoint as unique identifier
    let slug: String
    let character: String
    let unicodeName: String
    let codePoint: String
    let group: String
    let subGroup: String
    
    enum CodingKeys: String, CodingKey {
        case slug, character
        case unicodeName = "unicode_name"
        case codePoint = "code_point"
        case group
        case subGroup = "sub_group"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        slug = try container.decode(String.self, forKey: .slug)
        character = try container.decode(String.self, forKey: .character)
        unicodeName = try container.decode(String.self, forKey: .unicodeName)
        codePoint = try container.decode(String.self, forKey: .codePoint)
        group = try container.decode(String.self, forKey: .group)
        subGroup = try container.decode(String.self, forKey: .subGroup)
        id = codePoint // Set id from codePoint
    }
    
    init(slug: String, character: String, unicodeName: String, codePoint: String, group: String, subGroup: String) {
        self.id = codePoint
        self.slug = slug
        self.character = character
        self.unicodeName = unicodeName
        self.codePoint = codePoint
        self.group = group
        self.subGroup = subGroup
    }
}

// MARK: - Scroll Offset Preference Key (for detecting scroll to top)
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        // Improved reduce function to prevent "Bound preference tried to update multiple times per frame" warning
        // Use a simple approach: always take the latest value without conditional logic
        // This prevents the warning by ensuring we don't have complex branching in reduce
        value = nextValue()
    }
}

// MARK: - First Visible Item Preference Key (for detecting first visible message for date display)
struct MessageFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct FirstVisibleItemPreferenceKey: PreferenceKey {
    static var defaultValue: Int? = nil
    static func reduce(value: inout Int?, nextValue: () -> Int?) {
        // Take the minimum index (first visible item)
        let next = nextValue()
        if let nextIndex = next {
            if let currentIndex = value {
                value = min(currentIndex, nextIndex)
            } else {
                value = nextIndex
            }
        }
    }
}

// MARK: - Dynamic Image View (matching Android loadImageIntoView)
struct DynamicImageView: View {
    let imageUrl: String
    let fileName: String?
    let imageWidth: String?
    let imageHeight: String?
    let aspectRatio: String?
    let backgroundColor: Color
    let onTap: (() -> Void)? // Callback for single tap to open ShowImageScreen
    
    @State private var isDownloading: Bool = false
    @State private var downloadProgress: Double = 0.0
    @State private var showDownloadButton: Bool = false
    @State private var showDownloadProgress: Bool = false
    @State private var progressTimer: Timer? = nil
    
    // Get local images directory path (matching Android Enclosure/Media/Images)
    private func getLocalImagesDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagesDir = documentsPath.appendingPathComponent("Enclosure/Media/Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true, attributes: nil)
        return imagesDir
    }
    
    // Check if local image file exists and get URL (matching Android doesFileExist)
    private var imageSourceURL: URL? {
        // Check if local file exists first (matching Android: doesFileExist(exactPath2 + "/" + fileName))
        if let fileName = fileName, !fileName.isEmpty {
            let localURL = getLocalImagesDirectory().appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: localURL.path) {
                print("📱 [DynamicImageView] Using local image: \(localURL.path)")
                return localURL
            }
        }
        
        // Fallback to online URL (matching Android: model.getDocument())
        if let url = URL(string: imageUrl) {
            print("📱 [DynamicImageView] Using online image: \(imageUrl)")
            return url
        }
        
        return nil
    }
    
    // Check if local file exists (matching Android doesFileExist)
    private var hasLocalFile: Bool {
        guard let fileName = fileName, !fileName.isEmpty else { return false }
        let localURL = getLocalImagesDirectory().appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: localURL.path)
    }
    
    // Download image using BackgroundDownloadManager (matching Android startSenderImageDownloadWithProgress)
    private func downloadImage() {
        guard let fileName = fileName, !fileName.isEmpty else {
            print("🚫 [DOWNLOAD] No fileName available")
            return
        }
        
        let imagesDir = getLocalImagesDirectory()
        let destinationFile = imagesDir.appendingPathComponent(fileName)
        
        // Check if file already exists (matching Android)
        if FileManager.default.fileExists(atPath: destinationFile.path) {
            print("📱 [DOWNLOAD] Image already exists locally")
            // No toast - just return silently
            return
        }
        
        // Check if already downloading
        if BackgroundDownloadManager.shared.isDownloading(fileName: fileName) {
            print("📱 [DOWNLOAD] Already downloading: \(fileName)")
            return
        }
        
        // Light haptic feedback (matching Android Vibrator)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Update UI: hide download button, show progress (matching Android)
        isDownloading = true
        showDownloadButton = false
        showDownloadProgress = true
        downloadProgress = 0.0
        
        // Use BackgroundDownloadManager for background downloads with notifications
        BackgroundDownloadManager.shared.downloadImage(
            imageUrl: imageUrl,
            fileName: fileName,
            destinationFile: destinationFile,
            onProgress: { progress in
                // Update UI progress
                DispatchQueue.main.async {
                    self.downloadProgress = progress
                    print("📱 [DOWNLOAD] Progress: \(Int(progress))%")
                }
            },
            onSuccess: {
                // Update UI on success
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.showDownloadProgress = false
                    self.showDownloadButton = false
                    self.downloadProgress = 0.0
                    print("✅ [DOWNLOAD] Image downloaded successfully: \(destinationFile.path)")
                    // No toast - notification will show instead
                }
            },
            onFailure: { error in
                // Update UI on failure
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.showDownloadProgress = false
                    self.showDownloadButton = true
                    self.downloadProgress = 0.0
                    print("🚫 [DOWNLOAD] Download failed: \(error.localizedDescription)")
                    // No toast - notification will show instead
                }
            }
        )
    }
    
    // Calculate dynamic image size based on imageWidth, imageHeight, and aspectRatio (matching Android loadImageIntoView)
    private var imageSize: CGSize {
        // Parse dimensions with error handling (matching Android)
        var imageWidthPx: CGFloat = 300
        var imageHeightPx: CGFloat = 300
        var aspectRatioValue: CGFloat = 1.0
        
        // Parse width
        if let widthStr = imageWidth, !widthStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let width = Float(widthStr) {
                imageWidthPx = CGFloat(width)
            }
        }
        
        // Parse height
        if let heightStr = imageHeight, !heightStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let height = Float(heightStr) {
                imageHeightPx = CGFloat(height)
            }
        }
        
        // Parse aspect ratio
        if let ratioStr = aspectRatio, !ratioStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let ratio = Float(ratioStr), ratio > 0 {
                aspectRatioValue = CGFloat(ratio)
            } else {
                // Fallback to calculated aspect ratio
                if imageHeightPx > 0 {
                    aspectRatioValue = imageWidthPx / imageHeightPx
                }
            }
        } else {
            // Fallback to calculated aspect ratio
            if imageHeightPx > 0 {
                aspectRatioValue = imageWidthPx / imageHeightPx
            }
        }
        
        // Define maximum dimensions in points (matching Android MAX_WIDTH_DP = 210f, MAX_HEIGHT_DP = 250f)
        let MAX_WIDTH_PT: CGFloat = 210
        let MAX_HEIGHT_PT: CGFloat = 250
        
        // Convert to pixels (iOS uses points, but we'll use the same logic)
        // On iOS, 1 point = 1 pixel on non-retina, 2 pixels on retina, 3 pixels on retina HD
        let scale = UIScreen.main.scale
        var maxWidthPx = MAX_WIDTH_PT * scale
        var maxHeightPx = MAX_HEIGHT_PT * scale
        
        // Further limit pixel dimensions for better compression (matching Android: cap at 600px)
        maxWidthPx = min(maxWidthPx, 600)
        maxHeightPx = min(maxHeightPx, 600)
        
        // Calculate dimensions based on orientation and aspect ratio (matching Android)
        var finalWidthPx: CGFloat = 0
        var finalHeightPx: CGFloat = 0
        
        // Check orientation
        let orientation = UIDevice.current.orientation
        let isLandscape = orientation.isLandscape || (UIScreen.main.bounds.width > UIScreen.main.bounds.height)
        
        if isLandscape {
            // Landscape: Prioritize width for wide images
            finalWidthPx = maxWidthPx
            finalHeightPx = maxWidthPx / aspectRatioValue
            // Ensure height doesn't exceed maxHeightPx
            if finalHeightPx > maxHeightPx {
                finalHeightPx = maxHeightPx
                finalWidthPx = maxHeightPx * aspectRatioValue
            }
        } else {
            // Portrait: Prioritize height for wide images
            finalHeightPx = maxHeightPx
            finalWidthPx = maxHeightPx * aspectRatioValue
            // Ensure width doesn't exceed maxWidthPx
            if finalWidthPx > maxWidthPx {
                finalWidthPx = maxWidthPx
                finalHeightPx = maxWidthPx / aspectRatioValue
            }
        }
        
        // Ensure final dimensions are within bounds
        finalWidthPx = min(finalWidthPx, maxWidthPx)
        finalHeightPx = min(finalHeightPx, maxHeightPx)
        
        // Convert back to points for SwiftUI (divide by scale)
        let finalWidthPt = finalWidthPx / scale
        let finalHeightPt = finalHeightPx / scale
        
        return CGSize(width: finalWidthPt, height: finalHeightPt)
    }
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            // CardView wrapper (matching Android CardView with cornerRadius="12dp" and background color)
            // Background color matching sender message background (matching Android cardBackgroundColor)
            ZStack {
                RoundedRectangle(cornerRadius: 12) // cardCornerRadius="12dp"
                    .fill(backgroundColor) // Use same background as text messages
                    .frame(width: imageSize.width, height: imageSize.height) // Dynamic size based on image dimensions
                
                // Image view (matching Android senderImg: dynamic size, centerCrop, background="#000000")
                // Check local file first, then use online URL (matching Android doesFileExist logic)
                Group {
                    if let sourceURL = imageSourceURL {
                        // Use CachedAsyncImage for both local and remote URLs
                        CachedAsyncImage(
                            url: sourceURL,
                            content: { image in
                                // Display image with centerCrop (aspectFill) and black background
                                ZStack {
                                    Color.black // background="#000000"
                                    image
                                        .resizable()
                                        .scaledToFill() // centerCrop equivalent (scaleType="centerCrop")
                                }
                            },
                            placeholder: {
                                // Loading placeholder with black background (matching Android background="#000000")
                                ZStack {
                                    Color.black // background="#000000"
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                            }
                        )
                    } else {
                        // Fallback: show placeholder if no URL available
                        ZStack {
                            Color.black
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                    }
                }
                .frame(width: imageSize.width, height: imageSize.height) // Dynamic size based on image dimensions
                .clipShape(RoundedRectangle(cornerRadius: 12)) // Clip to card corner radius
                
                // Download button overlay (matching Android downlaod FloatingActionButton)
                // Show when local file doesn't exist (matching Android visibility logic)
                // Centered on image (matching Android layout_centerInParent="true")
                // Using iOS glassmorphism effect (iOS 26 glass style)
                if !hasLocalFile && !isDownloading {
                    // Download button with iOS glass effect (matching Android downloaddown icon)
                    Button(action: {
                        downloadImage()
                    }) {
                        ZStack {
                            // iOS glassmorphism background (iOS 26 glass style)
                            Circle()
                                .fill(.ultraThinMaterial) // Glass effect
                                .frame(width: 35, height: 35)
                                .overlay(
                                    // Subtle border for glass effect
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                            
                            // Download icon (using Android downloaddown.png icon)
                            Image("downloaddown")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .foregroundColor(Color(hex: "#e7ebf4"))
                        }
                    }
                    .onAppear {
                        showDownloadButton = true
                    }
                }
                
                // Download progress overlay (matching Android downloadPercentageImageSender)
                // Centered on image (matching Android layout_centerInParent="true")
                // Using iOS glassmorphism effect (iOS 26 glass style)
                if showDownloadProgress && isDownloading {
                    ZStack {
                        // iOS glassmorphism background (iOS 26 glass style)
                        Circle()
                            .fill(.ultraThinMaterial) // Glass effect
                            .frame(width: 60, height: 60)
                            .overlay(
                                // Subtle border for glass effect
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                        
                        // Progress percentage text (matching Android downloadPercentageImageSender)
                        Text("\(Int(downloadProgress))%")
                            .font(.custom("Inter18pt-Bold", size: 15))
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                }
            }
            .frame(width: imageSize.width, height: imageSize.height) // Dynamic size based on image dimensions
            .onTapGesture {
                // Single tap to open ShowImageScreen (matching Android openIndividualImage)
                onTap?()
            }
        }
        .onAppear {
            // Check if download is in progress from BackgroundDownloadManager
            if let fileName = fileName, !fileName.isEmpty {
                syncDownloadState(fileName: fileName)
                // Start timer to periodically check download progress
                startProgressTimer(fileName: fileName)
            }
        }
        .onDisappear {
            // Stop timer when view disappears
            progressTimer?.invalidate()
            progressTimer = nil
        }
    }
    
    // Sync download state from BackgroundDownloadManager
    private func syncDownloadState(fileName: String) {
        if BackgroundDownloadManager.shared.isDownloading(fileName: fileName) {
            isDownloading = true
            showDownloadButton = false
            showDownloadProgress = true
            if let progress = BackgroundDownloadManager.shared.getProgress(fileName: fileName) {
                downloadProgress = progress
            }
        } else if hasLocalFile {
            // File exists locally
            isDownloading = false
            showDownloadButton = false
            showDownloadProgress = false
        } else {
            // File doesn't exist and not downloading
            isDownloading = false
            showDownloadButton = true
            showDownloadProgress = false
        }
    }
    
    // Start timer to periodically check download progress
    private func startProgressTimer(fileName: String) {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            if BackgroundDownloadManager.shared.isDownloading(fileName: fileName) {
                if let progress = BackgroundDownloadManager.shared.getProgress(fileName: fileName) {
                    downloadProgress = progress
                    isDownloading = true
                    showDownloadProgress = true
                    showDownloadButton = false
                }
            } else {
                // Download completed or not in progress
                if hasLocalFile {
                    isDownloading = false
                    showDownloadProgress = false
                    showDownloadButton = false
                } else {
                    isDownloading = false
                    showDownloadProgress = false
                    showDownloadButton = true
                }
                progressTimer?.invalidate()
                progressTimer = nil
            }
        }
    }
}

// MARK: - Receiver Dynamic Image View (matching Android receiverImg design)
struct ReceiverDynamicImageView: View {
    let imageUrl: String
    let fileName: String?
    let imageWidth: String?
    let imageHeight: String?
    let aspectRatio: String?
    let onTap: (() -> Void)? // Callback for single tap to open ShowImageScreen
    
    @State private var isDownloading: Bool = false
    @State private var downloadProgress: Double = 0.0
    @State private var showDownloadButton: Bool = false
    @State private var showDownloadProgress: Bool = false
    @State private var progressTimer: Timer? = nil
    
    // Check if image exists in Photos library (public directory equivalent)
    private var hasPublicFile: Bool {
        guard let fileName = fileName, !fileName.isEmpty else { return false }
        return PhotosLibraryHelper.shared.imageExistsInPhotosLibrary(fileName: fileName) ||
               PhotosLibraryHelper.shared.fileExistsInCache(fileName: fileName)
    }
    
    // Calculate dynamic image size (same logic as sender)
    private var imageSize: CGSize {
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
    
    // Download image to Photos library (public directory)
    private func downloadImage() {
        guard let fileName = fileName, !fileName.isEmpty else {
            print("🚫 [DOWNLOAD] No fileName available")
            return
        }
        
        // Check if file already exists in Photos library
        if hasPublicFile {
            print("📱 [DOWNLOAD] Image already exists in Photos library")
            return
        }
        
        // Check if already downloading (use downloadKey for Photos library downloads)
        let downloadKey = "photos_\(fileName)"
        if BackgroundDownloadManager.shared.isDownloadingWithKey(key: downloadKey) {
            print("📱 [DOWNLOAD] Already downloading: \(fileName)")
            return
        }
        
        // Light haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Update UI
        isDownloading = true
        showDownloadButton = false
        showDownloadProgress = true
        downloadProgress = 0.0
        
        // Use BackgroundDownloadManager to download to Photos library
        BackgroundDownloadManager.shared.downloadImageToPhotosLibrary(
            imageUrl: imageUrl,
            fileName: fileName,
            onProgress: { progress in
                DispatchQueue.main.async {
                    self.downloadProgress = progress
                    print("📱 [DOWNLOAD] Progress: \(Int(progress))%")
                }
            },
            onSuccess: {
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.showDownloadProgress = false
                    self.showDownloadButton = false
                    self.downloadProgress = 0.0
                    print("✅ [DOWNLOAD] Image downloaded to Photos library: \(fileName)")
                }
            },
            onFailure: { error in
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.showDownloadProgress = false
                    self.showDownloadButton = true
                    self.downloadProgress = 0.0
                    print("🚫 [DOWNLOAD] Download failed: \(error.localizedDescription)")
                }
            }
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // CardView wrapper (matching Android CardView with white background and cornerRadius="12dp")
            ZStack {
                RoundedRectangle(cornerRadius: 12) // cardCornerRadius="12dp"
                    .fill(Color.white) // app:cardBackgroundColor="@color/white"
                    .frame(width: imageSize.width, height: imageSize.height)
                
                // Image view (matching Android recImg: dynamic size, centerCrop, background="#000000")
                Group {
                    if let url = URL(string: imageUrl) {
                        CachedAsyncImage(
                            url: url,
                            content: { image in
                                // Display image with centerCrop (aspectFill) and black background
                                ZStack {
                                    Color.black // background="#000000"
                                    image
                                        .resizable()
                                        .scaledToFill() // centerCrop equivalent
                                }
                            },
                            placeholder: {
                                // Loading placeholder with black background
                                ZStack {
                                    Color.black // background="#000000"
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                            }
                        )
                    } else {
                        // Fallback: show placeholder if no URL available
                        ZStack {
                            Color.black
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                    }
                }
                .frame(width: imageSize.width, height: imageSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Download button overlay (matching Android downlaod FloatingActionButton)
                // Show when public file doesn't exist
                if !hasPublicFile && !isDownloading {
                    Button(action: {
                        downloadImage()
                    }) {
                        ZStack {
                            // iOS glassmorphism background (iOS 26 glass style)
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 35, height: 35)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                            
                            // Download icon (using Android downloaddown.png icon)
                            Image("downloaddown")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .foregroundColor(Color.white)
                        }
                    }
                    .onAppear {
                        showDownloadButton = true
                    }
                }
                
                // Download progress overlay (matching Android downloadPercentageImage)
                if showDownloadProgress && isDownloading {
                    ZStack {
                        // iOS glassmorphism background
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                        
                        // Progress percentage text
                        Text("\(Int(downloadProgress))%")
                            .font(.custom("Inter18pt-Bold", size: 15))
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                }
            }
            .frame(width: imageSize.width, height: imageSize.height)
            .onTapGesture {
                // Single tap to open ShowImageScreen (matching Android openIndividualImage)
                onTap?()
            }
        }
        .onAppear {
            // Check if download is in progress from BackgroundDownloadManager
            if let fileName = fileName, !fileName.isEmpty {
                syncDownloadState(fileName: fileName)
                startProgressTimer(fileName: fileName)
            }
        }
        .onDisappear {
            progressTimer?.invalidate()
            progressTimer = nil
        }
    }
    
    // Sync download state from BackgroundDownloadManager
    private func syncDownloadState(fileName: String) {
        let downloadKey = "photos_\(fileName)"
        if BackgroundDownloadManager.shared.isDownloadingWithKey(key: downloadKey) {
            isDownloading = true
            showDownloadButton = false
            showDownloadProgress = true
            if let progress = BackgroundDownloadManager.shared.getProgressWithKey(key: downloadKey) {
                downloadProgress = progress
            }
        } else if hasPublicFile {
            isDownloading = false
            showDownloadButton = false
            showDownloadProgress = false
        } else {
            isDownloading = false
            showDownloadButton = true
            showDownloadProgress = false
        }
    }
    
    // Start timer to periodically check download progress
    private func startProgressTimer(fileName: String) {
        progressTimer?.invalidate()
        let downloadKey = "photos_\(fileName)"
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            if BackgroundDownloadManager.shared.isDownloadingWithKey(key: downloadKey) {
                if let progress = BackgroundDownloadManager.shared.getProgressWithKey(key: downloadKey) {
                    downloadProgress = progress
                    isDownloading = true
                    showDownloadProgress = true
                    showDownloadButton = false
                }
            } else {
                if hasPublicFile {
                    isDownloading = false
                    showDownloadProgress = false
                    showDownloadButton = false
                } else {
                    isDownloading = false
                    showDownloadProgress = false
                    showDownloadButton = true
                }
                progressTimer?.invalidate()
                progressTimer = nil
            }
        }
    }
}

// MARK: - Sender Video View (matching Android sendervideoLyt)
struct SenderVideoView: View {
    let videoUrl: String
    let thumbnailUrl: String?
    let fileName: String?
    let imageWidth: String?
    let imageHeight: String?
    let aspectRatio: String?
    let backgroundColor: Color
    
    @State private var isDownloading: Bool = false
    @State private var downloadProgress: Double = 0.0
    @State private var showDownloadButton: Bool = false
    @State private var showDownloadProgress: Bool = false
    @State private var showProgressBar: Bool = false
    @State private var showPauseButton: Bool = false
    @State private var progressTimer: Timer? = nil
    @State private var showVideoPlayer: Bool = false
    @State private var videoPlayer: AVPlayer? = nil
    
    // Calculate dynamic video size based on imageWidth, imageHeight, and aspectRatio (matching image sizing)
    private var videoSize: CGSize {
        // Parse dimensions with error handling (matching Android)
        var imageWidthPx: CGFloat = 300
        var imageHeightPx: CGFloat = 300
        var aspectRatioValue: CGFloat = 1.0
        
        // Parse width
        if let widthStr = imageWidth, !widthStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let width = Float(widthStr) {
                imageWidthPx = CGFloat(width)
            }
        }
        
        // Parse height
        if let heightStr = imageHeight, !heightStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let height = Float(heightStr) {
                imageHeightPx = CGFloat(height)
            }
        }
        
        // Parse aspect ratio
        if let ratioStr = aspectRatio, !ratioStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let ratio = Float(ratioStr), ratio > 0 {
                aspectRatioValue = CGFloat(ratio)
            } else {
                // Fallback to calculated aspect ratio
                if imageHeightPx > 0 {
                    aspectRatioValue = imageWidthPx / imageHeightPx
                }
            }
        } else {
            // Fallback to calculated aspect ratio
            if imageHeightPx > 0 {
                aspectRatioValue = imageWidthPx / imageHeightPx
            }
        }
        
        // Define maximum dimensions in points (matching Android MAX_WIDTH_DP = 210f, MAX_HEIGHT_DP = 250f)
        let MAX_WIDTH_PT: CGFloat = 210
        let MAX_HEIGHT_PT: CGFloat = 250
        
        // Convert to pixels (iOS uses points, but we'll use the same logic)
        let scale = UIScreen.main.scale
        var maxWidthPx = MAX_WIDTH_PT * scale
        var maxHeightPx = MAX_HEIGHT_PT * scale
        
        // Further limit pixel dimensions for better compression (matching Android: cap at 600px)
        maxWidthPx = min(maxWidthPx, 600)
        maxHeightPx = min(maxHeightPx, 600)
        
        // Calculate dimensions based on orientation and aspect ratio (matching Android)
        var finalWidthPx: CGFloat = 0
        var finalHeightPx: CGFloat = 0
        
        // Check orientation
        let orientation = UIDevice.current.orientation
        let isLandscape = orientation.isLandscape || (UIScreen.main.bounds.width > UIScreen.main.bounds.height)
        
        if isLandscape {
            // Landscape: Prioritize width for wide images
            finalWidthPx = maxWidthPx
            finalHeightPx = maxWidthPx / aspectRatioValue
            // Ensure height doesn't exceed maxHeightPx
            if finalHeightPx > maxHeightPx {
                finalHeightPx = maxHeightPx
                finalWidthPx = maxHeightPx * aspectRatioValue
            }
        } else {
            // Portrait: Prioritize height for wide images
            finalHeightPx = maxHeightPx
            finalWidthPx = maxHeightPx * aspectRatioValue
            // Ensure width doesn't exceed maxWidthPx
            if finalWidthPx > maxWidthPx {
                finalWidthPx = maxWidthPx
                finalHeightPx = maxWidthPx / aspectRatioValue
            }
        }
        
        // Ensure final dimensions are within bounds
        finalWidthPx = min(finalWidthPx, maxWidthPx)
        finalHeightPx = min(finalHeightPx, maxHeightPx)
        
        // Convert back to points for SwiftUI (divide by scale)
        let finalWidthPt = finalWidthPx / scale
        let finalHeightPt = finalHeightPx / scale
        
        return CGSize(width: finalWidthPt, height: finalHeightPt)
    }
    
    private var videoWidth: CGFloat {
        videoSize.width
    }
    
    private var videoHeight: CGFloat {
        videoSize.height
    }
    
    // Check if local file exists
    private var hasLocalFile: Bool {
        guard let fileName = fileName, !fileName.isEmpty else { return false }
        let localURL = getLocalVideosDirectory().appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: localURL.path)
    }
    
    // Get local videos directory
    private func getLocalVideosDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videosDir = documentsPath.appendingPathComponent("Enclosure/Media/Videos")
        if !FileManager.default.fileExists(atPath: videosDir.path) {
            try? FileManager.default.createDirectory(at: videosDir, withIntermediateDirectories: true)
        }
        return videosDir
    }
    
    // Get video URL for playback (prefer local file, fallback to online URL)
    private func getVideoURL() -> URL? {
        // Check local file first
        if hasLocalFile, let fileName = fileName, !fileName.isEmpty {
            let localURL = getLocalVideosDirectory().appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: localURL.path) {
                print("📱 [VIDEO] Using local file: \(localURL.path)")
                return localURL
            }
        }
        
        // Fallback to online URL
        if !videoUrl.isEmpty, let url = URL(string: videoUrl) {
            print("📱 [VIDEO] Using online URL: \(videoUrl)")
            return url
        }
        
        print("🚫 [VIDEO] No valid video URL found. hasLocalFile: \(hasLocalFile), videoUrl: \(videoUrl)")
        return nil
    }
    
    // Play video
    private func playVideo() {
        print("▶️ [VIDEO] Play button tapped")
        
        guard let videoURL = getVideoURL() else {
            print("🚫 [VIDEO] No video URL available")
            return
        }
        
        print("▶️ [VIDEO] Creating player with URL: \(videoURL)")
        print("▶️ [VIDEO] File exists: \(FileManager.default.fileExists(atPath: videoURL.path))")
        
        // Create player item and player (matching MultiVideoPreviewDialog pattern)
        let playerItem = AVPlayerItem(url: videoURL)
        let player = AVPlayer(playerItem: playerItem)
        videoPlayer = player
        
        print("▶️ [VIDEO] Player created: \(player)")
        print("▶️ [VIDEO] Current showVideoPlayer state: \(showVideoPlayer)")
        
        // Show video player on main thread (matching MultiVideoPreviewDialog)
        DispatchQueue.main.async {
            print("▶️ [VIDEO] Setting showVideoPlayer to true on main thread")
            self.showVideoPlayer = true
            print("▶️ [VIDEO] showVideoPlayer is now: \(self.showVideoPlayer)")
            print("▶️ [VIDEO] videoPlayer is: \(self.videoPlayer != nil ? "set" : "nil")")
        }
    }
    
    // Download video to local storage
    private func downloadVideo() {
        guard let fileName = fileName, !fileName.isEmpty else {
            print("🚫 [DOWNLOAD] No fileName available")
            return
        }
        
        let videosDir = getLocalVideosDirectory()
        let destinationFile = videosDir.appendingPathComponent(fileName)
        
        // Check if file already exists
        if FileManager.default.fileExists(atPath: destinationFile.path) {
            print("📱 [DOWNLOAD] Video already exists locally")
            return
        }
        
        // Check if already downloading
        if BackgroundDownloadManager.shared.isDownloading(fileName: fileName) {
            print("📱 [DOWNLOAD] Already downloading: \(fileName)")
            return
        }
        
        // Light haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Update UI
        isDownloading = true
        showDownloadButton = false
        showDownloadProgress = true
        showProgressBar = false // Remove horizontal progress bar
        downloadProgress = 0.0
        
        // Use BackgroundDownloadManager for video downloads
        BackgroundDownloadManager.shared.downloadImage(
            imageUrl: videoUrl,
            fileName: fileName,
            destinationFile: destinationFile,
            onProgress: { progress in
                DispatchQueue.main.async {
                    self.downloadProgress = progress
                    if progress > 0 {
                        self.showDownloadProgress = true
                        self.showProgressBar = false
                    }
                }
            },
            onSuccess: {
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.showDownloadProgress = false
                    self.showProgressBar = false
                    self.showDownloadButton = false
                    self.downloadProgress = 0.0
                    print("✅ [DOWNLOAD] Video downloaded successfully")
                }
            },
            onFailure: { error in
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.showDownloadProgress = false
                    self.showProgressBar = false
                    self.showDownloadButton = true
                    self.downloadProgress = 0.0
                    print("🚫 [DOWNLOAD] Download failed: \(error.localizedDescription)")
                }
            }
        )
    }
    
    var body: some View {
        ZStack {
            // CardView wrapper (matching Android CardView with background #e7ebf4 and cornerRadius="12dp")
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
                .frame(width: videoWidth, height: videoHeight)
            
            // Video frame (matching Android videoFrame FrameLayout)
            ZStack {
                // Video thumbnail (matching Android senderVideo ImageView)
                if let thumbnailUrl = thumbnailUrl, let url = URL(string: thumbnailUrl) {
                    CachedAsyncImage(
                        url: url,
                        content: { image in
                            ZStack {
                                Color.black
                                image
                                    .resizable()
                                    .scaledToFill()
                            }
                        },
                        placeholder: {
                            ZStack {
                                Color.black
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                        }
                    )
                } else {
                    Color.black
                }
                
                // Blur overlay (matching Android blurVideo View - visibility="gone" by default)
                // Not shown by default
            }
            .frame(width: videoWidth, height: videoHeight)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Play icon (matching MultiVideoPreviewDialog play icon design)
            Button(action: {
                playVideo()
            }) {
                ZStack {
                    // Black circle background (matching MultiVideoPreviewDialog)
                    Circle()
                        .fill(Color.black.opacity(0.7))
                        .frame(width: 44, height: 44)
                    
                    // Play arrow icon (matching MultiVideoPreviewDialog Image(systemName: "play.fill"))
                    Image(systemName: "play.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.white)
                        .offset(x: 1) // Slight offset to center the play icon better
                }
            }
            .sheet(isPresented: $showVideoPlayer, onDismiss: {
                // Clean up player when sheet is dismissed (swipe down)
                print("▶️ [VIDEO] Sheet dismissed, cleaning up player")
                if let player = videoPlayer {
                    player.pause()
                    player.replaceCurrentItem(with: nil)
                    print("▶️ [VIDEO] Player paused and cleared")
                }
                videoPlayer = nil
                print("▶️ [VIDEO] Player reference cleared")
            }) {
                Group {
                    if let player = videoPlayer {
                        VideoPlayerViewController(player: player)
                            .onAppear {
                                print("▶️ [VIDEO] VideoPlayerViewController appeared")
                            }
                    } else {
                        Text("Loading...")
                            .onAppear {
                                print("🚫 [VIDEO] Player is nil in sheet")
                            }
                    }
                }
            }
            .onChange(of: showVideoPlayer) { newValue in
                print("▶️ [VIDEO] showVideoPlayer changed to: \(newValue)")
                if !newValue {
                    // Also clean up when showVideoPlayer becomes false
                    if let player = videoPlayer {
                        player.pause()
                        player.replaceCurrentItem(with: nil)
                        print("▶️ [VIDEO] Player cleaned up on state change")
                    }
                    videoPlayer = nil
                }
            }
            
            // Download button (matching image bunch download button design)
            // Only show if file doesn't exist locally and not downloading
            if showDownloadButton && !isDownloading && !hasLocalFile {
                Button(action: {
                    downloadVideo()
                }) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 35, height: 35)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                        
                        Image("downloaddown")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundColor(Color(hex: "#e7ebf4"))
                    }
                }
            }
            
            // Progress bar removed - only show download percentage circle
            
            // Download percentage (matching Android downloadPercentageVideoSender TextView)
            if showDownloadProgress && isDownloading {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                    
                    Text("\(Int(downloadProgress))%")
                        .font(.custom("Inter18pt-Bold", size: 15))
                        .foregroundColor(.white)
                }
            }
            
            // Pause button (matching Android pauseButtonVideoSender ImageButton)
            if showPauseButton && isDownloading {
                Button(action: {
                    // Pause download logic
                    if let fileName = fileName {
                        BackgroundDownloadManager.shared.cancelDownload(fileName: fileName)
                        isDownloading = false
                        showDownloadProgress = false
                        showProgressBar = false
                        showPauseButton = false
                        showDownloadButton = true
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        
                        Image(systemName: "pause.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                            .foregroundColor(.white)
                    }
                }
                .offset(y: 40) // layout_marginTop="40dp"
            }
        }
        .frame(width: videoWidth, height: videoHeight)
        .onAppear {
            if let fileName = fileName, !fileName.isEmpty {
                syncDownloadState(fileName: fileName)
                startProgressTimer(fileName: fileName)
            }
        }
        .onDisappear {
            progressTimer?.invalidate()
            progressTimer = nil
        }
    }
    
    private func syncDownloadState(fileName: String) {
        if BackgroundDownloadManager.shared.isDownloading(fileName: fileName) {
            isDownloading = true
            showDownloadButton = false
            showDownloadProgress = true
            showProgressBar = false
            if let progress = BackgroundDownloadManager.shared.getProgress(fileName: fileName) {
                downloadProgress = progress
            }
        } else if hasLocalFile {
            isDownloading = false
            showDownloadButton = false
            showDownloadProgress = false
            showProgressBar = false
        } else {
            isDownloading = false
            showDownloadButton = true
            showDownloadProgress = false
            showProgressBar = false
        }
    }
    
    private func startProgressTimer(fileName: String) {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            if BackgroundDownloadManager.shared.isDownloading(fileName: fileName) {
                if let progress = BackgroundDownloadManager.shared.getProgress(fileName: fileName) {
                    downloadProgress = progress
                    isDownloading = true
                    showDownloadProgress = true
                    showProgressBar = false
                    showDownloadButton = false
                }
            } else {
                if hasLocalFile {
                    isDownloading = false
                    showDownloadProgress = false
                    showProgressBar = false
                    showDownloadButton = false
                } else {
                    isDownloading = false
                    showDownloadProgress = false
                    showProgressBar = false
                    showDownloadButton = true
                }
                progressTimer?.invalidate()
                progressTimer = nil
            }
        }
    }
}

// MARK: - Receiver Video View (matching Android receivervideoLyt)
struct ReceiverVideoView: View {
    let videoUrl: String
    let thumbnailUrl: String?
    let fileName: String?
    let imageWidth: String?
    let imageHeight: String?
    let aspectRatio: String?
    
    @State private var isDownloading: Bool = false
    @State private var downloadProgress: Double = 0.0
    @State private var showDownloadButton: Bool = false
    @State private var showDownloadProgress: Bool = false
    @State private var showProgressBar: Bool = false
    @State private var showPauseButton: Bool = false
    @State private var progressTimer: Timer? = nil
    @State private var showVideoPlayer: Bool = false
    @State private var videoPlayer: AVPlayer? = nil
    
    // Calculate dynamic video size based on imageWidth, imageHeight, and aspectRatio (matching image sizing)
    private var videoSize: CGSize {
        // Parse dimensions with error handling (matching Android)
        var imageWidthPx: CGFloat = 300
        var imageHeightPx: CGFloat = 300
        var aspectRatioValue: CGFloat = 1.0
        
        // Parse width
        if let widthStr = imageWidth, !widthStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let width = Float(widthStr) {
                imageWidthPx = CGFloat(width)
            }
        }
        
        // Parse height
        if let heightStr = imageHeight, !heightStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let height = Float(heightStr) {
                imageHeightPx = CGFloat(height)
            }
        }
        
        // Parse aspect ratio
        if let ratioStr = aspectRatio, !ratioStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let ratio = Float(ratioStr), ratio > 0 {
                aspectRatioValue = CGFloat(ratio)
            } else {
                // Fallback to calculated aspect ratio
                if imageHeightPx > 0 {
                    aspectRatioValue = imageWidthPx / imageHeightPx
                }
            }
        } else {
            // Fallback to calculated aspect ratio
            if imageHeightPx > 0 {
                aspectRatioValue = imageWidthPx / imageHeightPx
            }
        }
        
        // Define maximum dimensions in points (matching Android MAX_WIDTH_DP = 210f, MAX_HEIGHT_DP = 250f)
        let MAX_WIDTH_PT: CGFloat = 210
        let MAX_HEIGHT_PT: CGFloat = 250
        
        // Convert to pixels (iOS uses points, but we'll use the same logic)
        let scale = UIScreen.main.scale
        var maxWidthPx = MAX_WIDTH_PT * scale
        var maxHeightPx = MAX_HEIGHT_PT * scale
        
        // Further limit pixel dimensions for better compression (matching Android: cap at 600px)
        maxWidthPx = min(maxWidthPx, 600)
        maxHeightPx = min(maxHeightPx, 600)
        
        // Calculate dimensions based on orientation and aspect ratio (matching Android)
        var finalWidthPx: CGFloat = 0
        var finalHeightPx: CGFloat = 0
        
        // Check orientation
        let orientation = UIDevice.current.orientation
        let isLandscape = orientation.isLandscape || (UIScreen.main.bounds.width > UIScreen.main.bounds.height)
        
        if isLandscape {
            // Landscape: Prioritize width for wide images
            finalWidthPx = maxWidthPx
            finalHeightPx = maxWidthPx / aspectRatioValue
            // Ensure height doesn't exceed maxHeightPx
            if finalHeightPx > maxHeightPx {
                finalHeightPx = maxHeightPx
                finalWidthPx = maxHeightPx * aspectRatioValue
            }
        } else {
            // Portrait: Prioritize height for wide images
            finalHeightPx = maxHeightPx
            finalWidthPx = maxHeightPx * aspectRatioValue
            // Ensure width doesn't exceed maxWidthPx
            if finalWidthPx > maxWidthPx {
                finalWidthPx = maxWidthPx
                finalHeightPx = maxWidthPx / aspectRatioValue
            }
        }
        
        // Ensure final dimensions are within bounds
        finalWidthPx = min(finalWidthPx, maxWidthPx)
        finalHeightPx = min(finalHeightPx, maxHeightPx)
        
        // Convert back to points for SwiftUI (divide by scale)
        let finalWidthPt = finalWidthPx / scale
        let finalHeightPt = finalHeightPx / scale
        
        return CGSize(width: finalWidthPt, height: finalHeightPt)
    }
    
    private var videoWidth: CGFloat {
        videoSize.width
    }
    
    private var videoHeight: CGFloat {
        videoSize.height
    }
    
    // Check if video exists in Photos library (public directory)
    private var hasPublicFile: Bool {
        guard let fileName = fileName, !fileName.isEmpty else { return false }
        return PhotosLibraryHelper.shared.imageExistsInPhotosLibrary(fileName: fileName) ||
               PhotosLibraryHelper.shared.fileExistsInCache(fileName: fileName)
    }
    
    // Get video URL for playback (prefer Photos library cache, fallback to online URL)
    private func getVideoURL() -> URL? {
        // Check Photos library cache first
        if hasPublicFile, let fileName = fileName, !fileName.isEmpty {
            let cachePath = PhotosLibraryHelper.shared.getLocalCachePath(fileName: fileName)
            if FileManager.default.fileExists(atPath: cachePath.path) {
                return cachePath
            }
        }
        
        // Fallback to online URL
        if !videoUrl.isEmpty, let url = URL(string: videoUrl) {
            return url
        }
        
        return nil
    }
    
    // Play video
    private func playVideo() {
        guard let videoURL = getVideoURL() else {
            print("🚫 [VIDEO] No video URL available")
            return
        }
        
        print("▶️ [VIDEO] Playing video from URL: \(videoURL)")
        
        // Create player with URL (same as MultiVideoPreviewDialog)
        let player = AVPlayer(url: videoURL)
        videoPlayer = player
        
        // Show video player immediately (VideoPlayerViewController will auto-play)
        showVideoPlayer = true
    }
    
    // Download video to Photos library
    private func downloadVideo() {
        guard let fileName = fileName, !fileName.isEmpty else {
            print("🚫 [DOWNLOAD] No fileName available")
            return
        }
        
        // Check if file already exists in Photos library
        if hasPublicFile {
            print("📱 [DOWNLOAD] Video already exists in Photos library")
            return
        }
        
        // Check if already downloading
        let downloadKey = "photos_\(fileName)"
        if BackgroundDownloadManager.shared.isDownloadingWithKey(key: downloadKey) {
            print("📱 [DOWNLOAD] Already downloading: \(fileName)")
            return
        }
        
        // Light haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Update UI
        isDownloading = true
        showDownloadButton = false
        showDownloadProgress = true
        showProgressBar = false // Remove horizontal progress bar
        downloadProgress = 0.0
        
        // Use BackgroundDownloadManager to download to Photos library
        BackgroundDownloadManager.shared.downloadImageToPhotosLibrary(
            imageUrl: videoUrl,
            fileName: fileName,
            onProgress: { progress in
                DispatchQueue.main.async {
                    self.downloadProgress = progress
                    if progress > 0 {
                        self.showDownloadProgress = true
                        self.showProgressBar = false
                    }
                }
            },
            onSuccess: {
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.showDownloadProgress = false
                    self.showProgressBar = false
                    self.showDownloadButton = false
                    self.downloadProgress = 0.0
                    print("✅ [DOWNLOAD] Video downloaded to Photos library")
                }
            },
            onFailure: { error in
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.showDownloadProgress = false
                    self.showProgressBar = false
                    self.showDownloadButton = true
                    self.downloadProgress = 0.0
                    print("🚫 [DOWNLOAD] Download failed: \(error.localizedDescription)")
                }
            }
        )
    }
    
    var body: some View {
        ZStack {
            // CardView wrapper (matching Android CardView with white background and cornerRadius="12dp")
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .frame(width: videoWidth, height: videoHeight)
            
            // Video frame (matching Android videoFrame FrameLayout)
            ZStack {
                // Video thumbnail (matching Android recVideo ImageView)
                if let thumbnailUrl = thumbnailUrl, let url = URL(string: thumbnailUrl) {
                    CachedAsyncImage(
                        url: url,
                        content: { image in
                            ZStack {
                                Color.black
                                image
                                    .resizable()
                                    .scaledToFill()
                            }
                        },
                        placeholder: {
                            ZStack {
                                Color.black
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                        }
                    )
                } else {
                    Color.black
                }
                
                // Blur overlay (matching Android blurVideo View - visibility="gone" by default)
                // Not shown by default
            }
            .frame(width: videoWidth, height: videoHeight)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Play icon (matching MultiVideoPreviewDialog play icon design)
            Button(action: {
                playVideo()
            }) {
                ZStack {
                    // Black circle background (matching MultiVideoPreviewDialog)
                    Circle()
                        .fill(Color.black.opacity(0.7))
                        .frame(width: 44, height: 44)
                    
                    // Play arrow icon (matching MultiVideoPreviewDialog Image(systemName: "play.fill"))
                    Image(systemName: "play.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.white)
                        .offset(x: 1) // Slight offset to center the play icon better
                }
            }
            .sheet(isPresented: $showVideoPlayer, onDismiss: {
                // Clean up player when sheet is dismissed (swipe down)
                print("▶️ [VIDEO] Sheet dismissed, cleaning up player")
                if let player = videoPlayer {
                    player.pause()
                    player.replaceCurrentItem(with: nil)
                    print("▶️ [VIDEO] Player paused and cleared")
                }
                videoPlayer = nil
                print("▶️ [VIDEO] Player reference cleared")
            }) {
                Group {
                    if let player = videoPlayer {
                        VideoPlayerViewController(player: player)
                            .onAppear {
                                print("▶️ [VIDEO] VideoPlayerViewController appeared")
                            }
                    } else {
                        Text("Loading...")
                            .onAppear {
                                print("🚫 [VIDEO] Player is nil in sheet")
                            }
                    }
                }
            }
            .onChange(of: showVideoPlayer) { newValue in
                print("▶️ [VIDEO] showVideoPlayer changed to: \(newValue)")
                if !newValue {
                    // Also clean up when showVideoPlayer becomes false
                    if let player = videoPlayer {
                        player.pause()
                        player.replaceCurrentItem(with: nil)
                        print("▶️ [VIDEO] Player cleaned up on state change")
                    }
                    videoPlayer = nil
                }
            }
            
            // Download button (matching image bunch download button design)
            // Only show if file doesn't exist in Photos library and not downloading
            if showDownloadButton && !isDownloading && !hasPublicFile {
                Button(action: {
                    downloadVideo()
                }) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 35, height: 35)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                        
                        Image("downloaddown")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.white)
                    }
                }
            }
            
            // Download percentage (matching Android downloadPercentageVideo TextView)
            if showDownloadProgress && isDownloading {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                    
                    Text("\(Int(downloadProgress))%")
                        .font(.custom("Inter18pt-Bold", size: 15))
                        .foregroundColor(.white)
                }
            }
            
            // Pause button (matching Android pauseButtonVideo ImageButton)
            if showPauseButton && isDownloading {
                Button(action: {
                    // Pause download logic
                    if let fileName = fileName {
                        let downloadKey = "photos_\(fileName)"
                        BackgroundDownloadManager.shared.cancelDownloadWithKey(key: downloadKey)
                        isDownloading = false
                        showDownloadProgress = false
                        showProgressBar = false
                        showPauseButton = false
                        showDownloadButton = true
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        
                        Image(systemName: "pause.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                            .foregroundColor(.white)
                    }
                }
                .offset(y: 40) // layout_marginTop="40dp"
            }
            
            // Progress bar removed - only show download percentage circle
        }
        .frame(width: videoWidth, height: videoHeight)
        .onAppear {
            if let fileName = fileName, !fileName.isEmpty {
                syncDownloadState(fileName: fileName)
                startProgressTimer(fileName: fileName)
            }
        }
        .onDisappear {
            progressTimer?.invalidate()
            progressTimer = nil
        }
    }
    
    private func syncDownloadState(fileName: String) {
        let downloadKey = "photos_\(fileName)"
        if BackgroundDownloadManager.shared.isDownloadingWithKey(key: downloadKey) {
            isDownloading = true
            showDownloadButton = false
            showDownloadProgress = true
            showProgressBar = false
            if let progress = BackgroundDownloadManager.shared.getProgressWithKey(key: downloadKey) {
                downloadProgress = progress
            }
        } else if hasPublicFile {
            isDownloading = false
            showDownloadButton = false
            showDownloadProgress = false
            showProgressBar = false
        } else {
            isDownloading = false
            showDownloadButton = true
            showDownloadProgress = false
            showProgressBar = false
        }
    }
    
    private func startProgressTimer(fileName: String) {
        progressTimer?.invalidate()
        let downloadKey = "photos_\(fileName)"
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            if BackgroundDownloadManager.shared.isDownloadingWithKey(key: downloadKey) {
                if let progress = BackgroundDownloadManager.shared.getProgressWithKey(key: downloadKey) {
                    downloadProgress = progress
                    isDownloading = true
                    showDownloadProgress = true
                    showProgressBar = false
                    showDownloadButton = false
                }
            } else {
                if hasPublicFile {
                    isDownloading = false
                    showDownloadProgress = false
                    showProgressBar = false
                    showDownloadButton = false
                } else {
                    isDownloading = false
                    showDownloadProgress = false
                    showProgressBar = false
                    showDownloadButton = true
                }
                progressTimer?.invalidate()
                progressTimer = nil
            }
        }
    }
}

// MARK: - Sender Document View (matching Android docLyt design)
struct SenderDocumentView: View {
    let documentUrl: String
    let fileName: String
    let docSize: String?
    let fileExtension: String?
    let backgroundColor: Color
    let micPhoto: String?
    
    @State private var isDownloading: Bool = false
    @State private var showMusicPlayerBottomSheet: Bool = false
    @State private var downloadProgress: Double = 0.0
    @State private var showDownloadButton: Bool = false
    @State private var showDownloadProgress: Bool = false
    @State private var showProgressBar: Bool = false
    @State private var showPdfPreview: Bool = false
    @State private var pdfPreviewImage: UIImage? = nil
    @State private var fileCheckTimer: Timer? = nil
    @State private var showDocumentPreview: Bool = false
    @State private var documentPreviewURL: URL? = nil
    // Audio player state
    @State private var audioPlayer: AVPlayer? = nil
    @State private var isAudioPlaying: Bool = false
    @State private var audioCurrentTime: TimeInterval = 0.0
    @State private var audioDuration: TimeInterval = 0.0
    @State private var audioTimeObserver: Any? = nil
    
    // Get local documents directory path (matching Android Enclosure/Media/Documents)
    private func getLocalDocumentsDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let docsDir = documentsPath.appendingPathComponent("Enclosure/Media/Documents", isDirectory: true)
        try? FileManager.default.createDirectory(at: docsDir, withIntermediateDirectories: true, attributes: nil)
        return docsDir
    }
    
    // Get local audios directory path (matching Android Enclosure/Media/Audios)
    private func getLocalAudiosDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audiosDir = documentsPath.appendingPathComponent("Enclosure/Media/Audios", isDirectory: true)
        try? FileManager.default.createDirectory(at: audiosDir, withIntermediateDirectories: true, attributes: nil)
        return audiosDir
    }
    
    // Check if local file exists
    // Check by fileName first, then by file size if fileName doesn't match
    // For audio files, also check Audios directory (matching Android behavior)
    private var hasLocalFile: Bool {
        guard !fileName.isEmpty else { return false }
        
        // For audio files, check Audios directory first (matching Android)
        if isAudio {
            let audiosDir = getLocalAudiosDirectory()
            let audioURL = audiosDir.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: audioURL.path) {
                return true
            }
        }
        
        // Check Documents directory
        let docsDir = getLocalDocumentsDirectory()
        let localURL = docsDir.appendingPathComponent(fileName)
        
        // First check if file exists with exact fileName
        if FileManager.default.fileExists(atPath: localURL.path) {
            return true
        }
        
        // If not found by fileName, check all files in directory and match by file size
        // This handles cases where the saved filename might differ from message fileName
        if let docSize = docSize, let expectedSize = Int64(docSize), expectedSize > 0 {
            // Check Documents directory
            if let files = try? FileManager.default.contentsOfDirectory(at: docsDir, includingPropertiesForKeys: [.fileSizeKey]) {
                for file in files {
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
                       let fileSize = attributes[.size] as? Int64,
                       fileSize == expectedSize {
                        print("📱 [LOCAL_STORAGE] Found file by size match: \(file.lastPathComponent) (expected: \(fileName))")
                        return true
                    }
                }
            }
            
            // For audio files, also check Audios directory by size
            if isAudio {
                let audiosDir = getLocalAudiosDirectory()
                if let files = try? FileManager.default.contentsOfDirectory(at: audiosDir, includingPropertiesForKeys: [.fileSizeKey]) {
                    for file in files {
                        if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
                           let fileSize = attributes[.size] as? Int64,
                           fileSize == expectedSize {
                            print("📱 [LOCAL_STORAGE] Found audio file by size match: \(file.lastPathComponent) (expected: \(fileName))")
                            return true
                        }
                    }
                }
            }
        }
        
        return false
    }
    
    // Get file extension from fileName or fileExtension field
    private var extensionText: String {
        if let ext = fileExtension, !ext.isEmpty {
            return ext.uppercased()
        }
        let ext = (fileName as NSString).pathExtension
        if !ext.isEmpty {
            return ext.uppercased()
        }
        return "DOC"
    }
    
    // Format file size to match Android format (e.g., "12.4 kb")
    private var formattedDocSize: String? {
        guard let size = docSize, !size.isEmpty else { return nil }
        
        // If already formatted (contains "kb" or "mb"), return as is
        if size.lowercased().contains("kb") || size.lowercased().contains("mb") {
            return size
        }
        
        // Parse as bytes and format
        if let bytes = Int64(size) {
            if bytes < 1024 {
                return "\(bytes) b"
            } else if bytes < 1024 * 1024 {
                let kb = Double(bytes) / 1024.0
                return String(format: "%.1f kb", kb)
            } else {
                let mb = Double(bytes) / (1024.0 * 1024.0)
                return String(format: "%.1f mb", mb)
            }
        }
        
        return size
    }
    
    // Check if file is PDF
    private var isPdf: Bool {
        extensionText.uppercased() == "PDF"
    }
    
    // Check if file is audio/music (matching Android musicExtensions list)
    private var isAudio: Bool {
        let ext = extensionText.lowercased()
        return ["mp3", "wav", "flac", "aac", "ogg", "oga", "m4a", "wma", "alac", "aiff"].contains(ext)
    }
    
    // Download document
    private func downloadDocument() {
        guard !fileName.isEmpty else {
            print("🚫 [DOWNLOAD] No fileName available")
            return
        }
        
        guard !documentUrl.isEmpty else {
            print("🚫 [DOWNLOAD] No document URL available")
            return
        }
        
        // For audio files, use Audios directory (matching Android)
        let destinationDir = isAudio ? getLocalAudiosDirectory() : getLocalDocumentsDirectory()
        let destinationFile = destinationDir.appendingPathComponent(fileName)
        
        // Check if file already exists
        if FileManager.default.fileExists(atPath: destinationFile.path) {
            print("📱 [DOWNLOAD] Document already exists locally")
            return
        }
        
        // Check if already downloading
        if BackgroundDownloadManager.shared.isDownloading(fileName: fileName) {
            print("📱 [DOWNLOAD] Already downloading: \(fileName)")
            return
        }
        
        // Light haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Update UI
        isDownloading = true
        showDownloadButton = false
        showDownloadProgress = true
        showProgressBar = false
        downloadProgress = 0.0
        
        // Use BackgroundDownloadManager for document downloads
        BackgroundDownloadManager.shared.downloadImage(
            imageUrl: documentUrl,
            fileName: fileName,
            destinationFile: destinationFile,
            onProgress: { progress in
                DispatchQueue.main.async {
                    self.downloadProgress = progress
                    if progress > 0 {
                        self.showDownloadProgress = true
                        self.showProgressBar = false
                    }
                }
            },
            onSuccess: {
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.showDownloadProgress = false
                    self.showProgressBar = false
                    self.showDownloadButton = false
                    self.downloadProgress = 0.0
                    print("✅ [DOWNLOAD] Document downloaded successfully")
                }
            },
            onFailure: { error in
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.showDownloadProgress = false
                    self.showProgressBar = false
                    self.showDownloadButton = true
                    self.downloadProgress = 0.0
                    print("🚫 [DOWNLOAD] Download failed: \(error.localizedDescription)")
                }
            }
        )
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) { // spacing: 0 - no spacing between PDF preview and row (matching Android docLyt orientation="vertical")
            // Audio player container (shown for audio files only) - matching Android miceContainer
            if isAudio {
                audioPlayerView
            }
            
            // PDF preview (shown for PDF only) - matching Android pdfcard CardView, full width to parent container
            if isPdf && showPdfPreview, let pdfImage = pdfPreviewImage {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(hex: "#e7ebf4"))
                    .frame(maxWidth: .infinity) // Full width to parent container
                    .frame(height: 100) // Fixed height
                    .overlay(
                        Image(uiImage: pdfImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity) // Full width to parent container
                            .frame(height: 100) // Fixed height
                            .clipShape(RoundedRectangle(cornerRadius: 20)) // Apply 20dp corner radius to image
                    )
                    .padding(.horizontal, 1) // layout_marginHorizontal="1dp"
                    .padding(.vertical, 1) // layout_marginVertical="1dp"
            }
            
            // Row: icon | info (weight) | download/progress controls (right) - matching Android LinearLayout
            HStack(alignment: .center, spacing: 0) { // spacing: 0 - no spacing between icon, info, and controls
                // File type icon - matching Android docFileIcon LinearLayout: layout_width="26dp", layout_height="26dp", layout_gravity="center_vertical", alpha="0.8"
                ZStack(alignment: .center) {
                    // Background matching pagesvg drawable with backgroundTint="#e7ebf4"
                    Image("pagesvg")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                        .foregroundColor(Color(hex: "#e7ebf4"))
                        .opacity(0.8) // alpha="0.8"
                    
                    // Extension text - matching Android extension TextView: layout_marginTop="2dp", layout_gravity="center|center_vertical"
                    Text(extensionText.prefix(4)) // maxLength="4"
                        .font(.custom("Inter18pt-Bold", size: 7.5)) // textSize="7.5sp", fontFamily="@font/inter_bold"
                        .foregroundColor(.black) // textColor="@color/black"
                        .textCase(.uppercase) // textAllCaps="true"
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: true) // Minimize vertical space
                        .padding(.top, 1) // layout_marginTop="2dp" - reduced to minimize vertical space
                }
                .frame(width: 26, height: 26) // layout_width="26dp", layout_height="26dp"
                // No margin on icon - directly adjacent to document info
                
                // Document info - matching Android LinearLayout: layout_width="0dp", layout_weight="1", layout_height="wrap_content", layout_marginHorizontal="3dp", alpha="0.8"
                VStack(alignment: .leading, spacing: 0) { // spacing: 0 - no spacing between docName and size row (matching Android)
                    // Document name - matching Android docName TextView: layout_width="match_parent", layout_height="wrap_content", maxWidth="170dp", lineHeight="22dp"
                    Text(fileName)
                        .font(.custom("Inter18pt-Regular", size: 15)) // textSize="15sp", fontFamily="@font/inter"
                        .foregroundColor(.black) // textColor="@color/black"
                        .lineLimit(1) // singleLine="true"
                        .truncationMode(.tail) // Add ellipsis at end when truncated (matching Android)
                         // maxWidth="170dp" (wrap_content up to 170dp)
                        .fixedSize(horizontal: false, vertical: true) // layout_height="wrap_content" - minimize vertical space
                        .padding(.vertical, 0) // Remove any implicit vertical padding
                    
                    // Size and extension row - matching Android LinearLayout: layout_width="match_parent", layout_height="wrap_content", orientation="horizontal"
                    // No spacing between docName and this row (spacing: 0 in VStack matches Android - elements are touching)
                    HStack(spacing: 0) { // spacing: 0 - no spacing between size, bullet, and extension (matching Android)
                        // Document size - matching Android docSize TextView: layout_width="wrap_content", layout_height="wrap_content"
                        if let size = formattedDocSize {
                            Text(size)
                                .font(.custom("Inter18pt-Regular", size: 12)) // textSize="12sp", fontFamily="@font/inter"
                                .foregroundColor(Color(hex: "#212121")) // textColor="@color/grey_900"
                                .lineLimit(1) // singleLine="true"
                        }
                        
                        // Bullet separator - matching Android TextView: layout_width="wrap_content", layout_marginHorizontal="5dp"
                        Text("•")
                            .font(.custom("Inter18pt-Regular", size: 12)) // fontFamily="@font/inter"
                            .foregroundColor(Color(hex: "#212121")) // textColor="@color/grey_900"
                            .lineLimit(1) // singleLine="true"
                            .padding(.horizontal, 5) // layout_marginHorizontal="5dp"
                        
                        // Extension - matching Android docSizeExtension TextView: layout_width="wrap_content", layout_height="wrap_content"
                        Text(extensionText)
                            .font(.custom("Inter18pt-Regular", size: 12)) // textSize="12sp", fontFamily="@font/inter"
                            .foregroundColor(Color(hex: "#212121")) // textColor="@color/grey_900"
                            .textCase(.uppercase) // textAllCaps="true"
                            .lineLimit(1) // singleLine="true"
                        
                        Spacer(minLength: 0) // Push content to left, no extra space on right
                    }
                }
                .padding(.leading, 7) // paddingStart="7dp" (inside background)
                .padding(.top, 2) // paddingTop="3dp" - reduced to minimize vertical space
                .padding(.trailing, 7) // paddingEnd="7dp" (inside background)
                .padding(.bottom, 2) // paddingBottom="3dp" - reduced to minimize vertical space
                .fixedSize(horizontal: false, vertical: true) // layout_height="wrap_content" - minimize vertical space
                .background(
                    // Background matching doc_sender_bg drawable: radius="20dp"
                    RoundedRectangle(cornerRadius: 20) // android:radius="20dp"
                        .fill(Color(hex: "#e7ebf4")) // Solid color (opacity applied to container)
                )
                .opacity(0.8) // alpha="0.8" on entire container (matching Android alpha on LinearLayout)
                .padding(.horizontal, 3) // layout_marginHorizontal="3dp" (outside background, between icon and info)
                .frame(maxWidth: .infinity, alignment: .leading) // layout_weight="1" (expands to fill space horizontally)
                
                // Right-side download/progress controls - matching Android docDownloadControls RelativeLayout
                // Only show container when there's content to display (matching Android visibility="gone" when empty)
                // Show if: download button visible OR progress bar visible OR download percentage visible OR pause button visible
                if (!hasLocalFile && !isDownloading && showDownloadButton) || 
                   (showProgressBar && isDownloading) || 
                   (showDownloadProgress && isDownloading) || 
                   isDownloading {
                    ZStack {
                        // Download button - matching SelectionBunchLayout glassmorphism style
                        if !hasLocalFile && !isDownloading && showDownloadButton {
                            Button(action: {
                                downloadDocument()
                            }) {
                                ZStack {
                                    // iOS glassmorphism background (matching SelectionBunchLayout)
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 35, height: 35)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                                    
                                    Image("downloaddown")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                        .foregroundColor(Color(hex: "#e7ebf4")) // Matching sender SelectionBunchLayout
                                }
                            }
                        }
                        
                        // Progress bar - matching Android progressBarDoc ProgressBar
                        if showProgressBar && isDownloading {
                            ProgressView()
                                .progressViewStyle(LinearProgressViewStyle(tint: Color("TextColor")))
                                .frame(width: 40, height: 4)
                        }
                        
                        // Download percentage - matching SelectionBunchLayout glassmorphism style
                        if showDownloadProgress && isDownloading {
                            ZStack {
                                // iOS glassmorphism background (matching SelectionBunchLayout)
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                                
                                Text("\(Int(downloadProgress))%")
                                    .font(.custom("Inter18pt-Bold", size: 15))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .frame(width: 60, height: 60)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 7)
          
        }
        .frame(minHeight: 40)
        .onTapGesture {
            openDocument()
        }
        .fullScreenCover(isPresented: $showDocumentPreview) {
            Group {
                if let url = documentPreviewURL {
                    ShowDocumentScreen(
                        documentURL: url,
                        fileName: fileName,
                        docSize: docSize,
                        fileExtension: fileExtension,
                        viewHolderType: "sender",
                        downloadUrl: documentUrl.isEmpty ? nil : documentUrl
                    )
                    .onAppear {
                        print("📄 [SenderDocumentView] ShowDocumentScreen appeared - url: \(url.path)")
                    }
                } else {
                    Color.black.ignoresSafeArea()
                        .onAppear {
                            print("🚫 [SenderDocumentView] fullScreenCover triggered but documentPreviewURL is nil!")
                        }
                }
            }
        }
        .onChange(of: showDocumentPreview) { newValue in
            print("📄 [SenderDocumentView] showDocumentPreview changed to: \(newValue), documentPreviewURL: \(documentPreviewURL?.path ?? "nil")")
        }
        .sheet(isPresented: $showMusicPlayerBottomSheet) {
            MusicPlayerBottomSheet(
                audioUrl: documentUrl.isEmpty ? fileName : documentUrl,
                profileImageUrl: micPhoto ?? "",
                songTitle: fileName.isEmpty ? "Audio Message" : fileName
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            print("📄 [SenderDocumentView] onAppear - fileName: \(fileName), documentUrl: \(documentUrl.isEmpty ? "empty" : "has URL"), docSize: \(docSize ?? "nil"), fileExtension: \(fileExtension ?? "nil")")
            
            // Check if local file exists and we have a URL to download
            checkLocalFileAndUpdateUI()
            
            // Start periodic check for local file (in case file is being saved asynchronously)
            startFileCheckTimer()
            
            // Load PDF preview if PDF
            if isPdf {
                loadPdfPreview()
            }
        }
        .onDisappear {
            // Stop timer when view disappears
            fileCheckTimer?.invalidate()
            fileCheckTimer = nil
        }
    }
    
    // Check local file and update UI state
    private func checkLocalFileAndUpdateUI() {
        if hasLocalFile {
            // File exists locally, hide download button
            showDownloadButton = false
            showDownloadProgress = false
            isDownloading = false
            print("📱 [SenderDocumentView] File exists locally, hiding download button")
        } else if !documentUrl.isEmpty {
            // File doesn't exist locally, show download button
            showDownloadButton = true
            print("📱 [SenderDocumentView] File not found locally, showing download button")
        }
    }
    
    // Start timer to periodically check if file exists locally
    // This handles cases where file is saved asynchronously after upload
    private func startFileCheckTimer() {
        fileCheckTimer?.invalidate()
        
        // Check immediately
        checkLocalFileAndUpdateUI()
        
        // Then check periodically for up to 5 seconds (10 checks at 0.5s intervals)
        var checkCount = 0
        fileCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            checkCount += 1
            
            // Re-check if file exists
            if self.hasLocalFile {
                self.checkLocalFileAndUpdateUI()
                timer.invalidate()
                self.fileCheckTimer = nil
                print("📱 [SenderDocumentView] File found after \(Double(checkCount) * 0.5) seconds")
            } else if checkCount >= 10 {
                // Stop checking after 5 seconds
                timer.invalidate()
                self.fileCheckTimer = nil
            }
        }
    }
    
    // Load PDF preview thumbnail
    private func loadPdfPreview() {
        // Check if PDF file exists locally
        guard hasLocalFile else {
            showPdfPreview = false
            return
        }
        
        let localURL = getLocalDocumentsDirectory().appendingPathComponent(fileName)
        
        // Generate thumbnail from PDF first page
        DispatchQueue.global(qos: .userInitiated).async {
            guard let pdfDocument = CGPDFDocument(localURL as CFURL),
                  let firstPage = pdfDocument.page(at: 1) else {
                DispatchQueue.main.async {
                    self.showPdfPreview = false
                }
                return
            }
            
            // Get page rect
            let pageRect = firstPage.getBoxRect(.mediaBox)
            let scale: CGFloat = 180.0 / max(pageRect.width, pageRect.height)
            let scaledSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)
            
            // Create thumbnail
            UIGraphicsBeginImageContextWithOptions(scaledSize, false, 0.0)
            guard let context = UIGraphicsGetCurrentContext() else {
                UIGraphicsEndImageContext()
                DispatchQueue.main.async {
                    self.showPdfPreview = false
                }
                return
            }
            
            context.interpolationQuality = .high
            context.scaleBy(x: scale, y: scale)
            context.drawPDFPage(firstPage)
            
            let thumbnailImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            DispatchQueue.main.async {
                if let image = thumbnailImage {
                    self.pdfPreviewImage = image
                    self.showPdfPreview = true
                } else {
                    self.showPdfPreview = false
                }
            }
        }
    }
    
    // Audio player view (matching Android miceContainer) - for music files in doc dataType
    // Matching Android sample_sender.xml miceContainer exactly
    @ViewBuilder
    private var audioPlayerView: some View {
        VStack(spacing: 0) {
            // Main container - matching Android miceContainer LinearLayout
            // Android: layout_width="match_parent", layout_height="wrap_content", layout_gravity="center"
            // Android: layout_marginHorizontal="7dp", layout_marginVertical="7dp", gravity="center", orientation="vertical"
            VStack(spacing: 0) {
                // Inner container - matching Android inner LinearLayout
                // Android: layout_width="wrap_content", layout_height="wrap_content", layout_gravity="center"
                // Android: layout_marginHorizontal="3dp", backgroundTint="#021D3A", gravity="center", orientation="horizontal"
                HStack(alignment: .center, spacing: 0) {
                    // Download controls - matching Android audioDownloadControls RelativeLayout
                    // Android: layout_width="wrap_content", layout_height="wrap_content", layout_gravity="center_vertical", gravity="center"
                    if !hasLocalFile {
                        audioDownloadControlsView
                    }
                    
                    // Play button - matching Android micePlay AppCompatImageButton
                    // Android: layout_width="wrap_content", layout_height="wrap_content", layout_marginEnd="5dp"
                    // Android: scaleX="1.4", scaleY="1.4", src="@drawable/play_arrow_sender"
                    Button(action: {
                        openMusicPlayer()
                    }) {
                        Image("play_arrow_sender")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .scaleEffect(1.4) // Android: scaleX="1.4", scaleY="1.4"
                    }
                    .padding(.trailing, 5) // Android: layout_marginEnd="5dp"
                    
                    // Progress layout - matching Android progresslyt LinearLayout
                    // Android: layout_width="match_parent", layout_height="wrap_content", layout_marginHorizontal="5dp"
                    // Android: minWidth="150dp", orientation="vertical"
                    VStack(spacing: 0) {
                        // Progress bar - matching Android miceProgressbar LinearProgressIndicator
                        // Android: layout_width="match_parent", layout_height="wrap_content", layout_marginTop="19dp"
                        // Android: indicatorColor="@color/teal_700", trackCornerRadius="20dp", trackThickness="5dp"
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 20) // Android: trackCornerRadius="20dp"
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 5) // Android: trackThickness="5dp"
                                
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(hex: "#018786")) // Android: indicatorColor="@color/teal_700"
                                    .frame(width: geometry.size.width * CGFloat(audioDuration > 0 ? audioCurrentTime / audioDuration : 0), height: 5)
                            }
                        }
                        .frame(height: 5)
                        .padding(.top, 19) // Android: layout_marginTop="19dp"
                        
                        // Timing text - matching Android miceTiming TextView
                        // Android: layout_width="wrap_content", layout_height="wrap_content", layout_marginTop="5dp"
                        // Android: textColor="#e7ebf4", textSize="10sp", fontFamily="@font/inter", lineHeight="22dp"
                        Text(formatTime(audioDuration > 0 ? audioDuration : 0))
                            .font(.custom("Inter18pt-Regular", size: 10)) // Android: fontFamily="@font/inter", textSize="10sp"
                            .foregroundColor(Color(hex: "#e7ebf4")) // Android: textColor="#e7ebf4"
                            .padding(.top, 5) // Android: layout_marginTop="5dp"
                    }
                    .frame(minWidth: 150) // Android: minWidth="150dp"
                    .padding(.horizontal, 5) // Android: layout_marginHorizontal="5dp"
                    .frame(maxHeight: .infinity, alignment: .center) // Vertically center with play button
                }
                .padding(.horizontal, 3) // Android: layout_marginHorizontal="3dp"
                .background(Color.clear) // Remove inner fill to avoid darker rectangle
            }
            .padding(.horizontal, 7) // Android: layout_marginHorizontal="7dp"
            .padding(.vertical, 7) // Android: layout_marginVertical="7dp"
        }
        .onAppear {
            if isAudio && hasLocalFile {
                setupAudioPlayer()
            }
        }
        .onDisappear {
            stopAudioPlayer()
        }
    }
    
    // Audio download controls view (matching Android audioDownloadControls)
    @ViewBuilder
    private var audioDownloadControlsView: some View {
        ZStack {
            // Download button - matching SelectionBunchLayout glassmorphism style
            if !isDownloading && showDownloadButton {
                Button(action: {
                    downloadDocument()
                }) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 35, height: 35)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                        
                        Image("downloaddown")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.white)
                    }
                }
            }
            
            // Progress bar - matching Android progressBarAudio
            if showProgressBar && isDownloading {
                ProgressView()
                    .progressViewStyle(LinearProgressViewStyle(tint: Color("TextColor")))
                    .frame(width: 40, height: 4)
            }
            
            // Download percentage - matching Android downloadPercentageAudioSender
            if showDownloadProgress && isDownloading {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                    
                    Text("\(Int(downloadProgress))%")
                        .font(.custom("Inter18pt-Bold", size: 15))
                        .foregroundColor(.white)
                }
            }
        }
        .frame(width: 60, height: 60)
    }
    
    // Format time for audio player
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%.2d:%.2d", minutes, seconds)
    }
    
    // Setup audio player
    private func setupAudioPlayer() {
        guard let localURL = findLocalFileURL() else { return }
        
        audioPlayer = AVPlayer(url: localURL)
        
        // Get duration
        if let duration = audioPlayer?.currentItem?.asset.duration {
            audioDuration = CMTimeGetSeconds(duration)
        }
        
        // Observe time updates
        audioTimeObserver = audioPlayer?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { time in
            self.audioCurrentTime = CMTimeGetSeconds(time)
        }
    }
    
    // Toggle audio playback
    private func toggleAudioPlayback() {
        guard let player = audioPlayer else {
            if hasLocalFile {
                setupAudioPlayer()
                audioPlayer?.play()
                isAudioPlaying = true
            }
            return
        }
        
        if isAudioPlaying {
            player.pause()
            isAudioPlaying = false
        } else {
            player.play()
            isAudioPlaying = true
        }
    }
    
    // Stop audio player
    private func stopAudioPlayer() {
        audioPlayer?.pause()
        audioPlayer = nil
        isAudioPlaying = false
        audioCurrentTime = 0.0
        audioDuration = 0.0
        if let observer = audioTimeObserver {
            audioPlayer?.removeTimeObserver(observer)
            audioTimeObserver = nil
        }
    }
    
    // Open music player bottom sheet (matching Android micePlay click handler)
    private func openMusicPlayer() {
        print("🎵 [SenderDocumentView] Opening music player - fileName: \(fileName)")
        
        // Get audio details
        var audioUrl = documentUrl.isEmpty ? fileName : documentUrl
        let profileImageUrl = micPhoto ?? ""
        let songTitle = fileName.isEmpty ? "Audio Message" : fileName
        var localFilePath: String? = nil
        
        // Check for local file first (matching Android logic)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audiosDir = documentsPath.appendingPathComponent("Enclosure/Media/Audios", isDirectory: true)
        
        print("🎵 [SenderDocumentView] Checking audios directory: \(audiosDir.path)")
        
        if FileManager.default.fileExists(atPath: audiosDir.path) {
            let localFile = audiosDir.appendingPathComponent(fileName)
            print("🎵 [SenderDocumentView] Looking for file: \(fileName)")
            print("🎵 [SenderDocumentView] Full path: \(localFile.path)")
            
            if FileManager.default.fileExists(atPath: localFile.path) {
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: localFile.path)[.size] as? Int64) ?? 0
                if fileSize > 0 {
                    localFilePath = localFile.path
                    audioUrl = "file://" + localFilePath!
                    print("✅ [SenderDocumentView] Local file found and valid: \(localFilePath!)")
                    print("🎵 [SenderDocumentView] Audio URL with file://: \(audioUrl)")
                } else {
                    print("🚫 [SenderDocumentView] Local file exists but is empty")
                }
            } else {
                print("🚫 [SenderDocumentView] Local file not found: \(localFile.path)")
            }
        } else {
            print("🚫 [SenderDocumentView] Audios directory not found: \(audiosDir.path)")
        }
        
        print("🎵 [SenderDocumentView] Final audioUrl: \(audioUrl)")
        print("🎵 [SenderDocumentView] Final localFilePath: \(localFilePath ?? "nil")")
        
        // Show the bottom sheet
        showMusicPlayerBottomSheet = true
    }
    
    // Open document in preview
    private func openDocument() {
        print("📄 [SenderDocumentView] Opening document - fileName: \(fileName)")
        
        // Check if file exists locally first - check multiple directories
        var localURL: URL? = nil
        
        // Check Documents directory
        let docsURL = getLocalDocumentsDirectory().appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: docsURL.path) {
            localURL = docsURL
            print("📄 [SenderDocumentView] Found file in Documents: \(docsURL.path)")
        }
        
        // Check Images directory if it's an image
        if localURL == nil && isPdf == false {
            let imagesURL = getLocalImagesDirectory().appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: imagesURL.path) {
                localURL = imagesURL
                print("📄 [SenderDocumentView] Found file in Images: \(imagesURL.path)")
            }
        }
        
        // Check Videos directory if it's a video
        if localURL == nil {
            let videosURL = getLocalVideosDirectory().appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: videosURL.path) {
                localURL = videosURL
                print("📄 [SenderDocumentView] Found file in Videos: \(videosURL.path)")
            }
        }
        
        if let localFileURL = localURL {
            print("📄 [SenderDocumentView] Setting documentPreviewURL: \(localFileURL.path)")
            documentPreviewURL = localFileURL
            print("📄 [SenderDocumentView] documentPreviewURL set, now setting showDocumentPreview = true")
            showDocumentPreview = true
            print("📄 [SenderDocumentView] showDocumentPreview is now: \(showDocumentPreview)")
            return
        }
        
        // If not local and we have a download URL, download first then open
        if !documentUrl.isEmpty, let url = URL(string: documentUrl) {
            // Check if already downloading
            if isDownloading {
                print("📄 [SenderDocumentView] Already downloading, please wait")
                return
            }
            
            // Start download and open when complete
            downloadDocumentAndOpen()
        } else {
            print("🚫 [SenderDocumentView] No document URL available")
        }
    }
    
    // Get local images directory
    private func getLocalImagesDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagesDir = documentsPath.appendingPathComponent("Enclosure/Media/Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true, attributes: nil)
        return imagesDir
    }
    
    // Get local videos directory
    private func getLocalVideosDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videosDir = documentsPath.appendingPathComponent("Enclosure/Media/Videos", isDirectory: true)
        try? FileManager.default.createDirectory(at: videosDir, withIntermediateDirectories: true, attributes: nil)
        return videosDir
    }
    
    // Find local file URL by checking multiple directories
    private func findLocalFileURL() -> URL? {
        // For audio files, check Audios directory first (matching Android behavior)
        if isAudio {
            let audiosURL = getLocalAudiosDirectory().appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: audiosURL.path) {
                return audiosURL
            }
        }
        
        // Check Documents directory (for documents sent as documents)
        let docsURL = getLocalDocumentsDirectory().appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: docsURL.path) {
            return docsURL
        }
        
        // Check Images directory (for images sent as documents)
        if isImage {
            let imagesURL = getLocalImagesDirectory().appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: imagesURL.path) {
                return imagesURL
            }
        }
        
        // Check Videos directory (for videos sent as documents)
        if isVideo {
            let videosURL = getLocalVideosDirectory().appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: videosURL.path) {
                return videosURL
            }
        }
        
        return nil
    }
    
    // Check if file is image
    private var isImage: Bool {
        let ext = (fileName as NSString).pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "webp", "gif", "tiff", "psd", "heif", "svg"].contains(ext)
    }
    
    // Check if file is video
    private var isVideo: Bool {
        let ext = (fileName as NSString).pathExtension.lowercased()
        return ["mp4", "mov", "wmv", "flv", "mkv", "avi", "avchd", "webm", "hevc"].contains(ext)
    }
    
    // Download document and open when complete
    private func downloadDocumentAndOpen() {
        guard !fileName.isEmpty else {
            print("🚫 [DOWNLOAD] No fileName available")
            return
        }
        
        // For audio files, use Audios directory (matching Android)
        let destinationDir = isAudio ? getLocalAudiosDirectory() : getLocalDocumentsDirectory()
        let destinationFile = destinationDir.appendingPathComponent(fileName)
        
        // Check if file already exists
        if FileManager.default.fileExists(atPath: destinationFile.path) {
            documentPreviewURL = destinationFile
            showDocumentPreview = true
            return
        }
        
        // Check if already downloading
        if BackgroundDownloadManager.shared.isDownloading(fileName: fileName) {
            print("📱 [DOWNLOAD] Already downloading: \(fileName)")
            return
        }
        
        // Light haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Update UI: hide download button, show progress
        isDownloading = true
        showDownloadButton = false
        showDownloadProgress = true
        downloadProgress = 0.0
        
        // Use BackgroundDownloadManager for background downloads
        BackgroundDownloadManager.shared.downloadImage(
            imageUrl: documentUrl,
            fileName: fileName,
            destinationFile: destinationFile,
            onProgress: { progress in
                DispatchQueue.main.async {
                    self.downloadProgress = progress
                }
            },
            onSuccess: {
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.showDownloadProgress = false
                    self.showDownloadButton = false
                    self.downloadProgress = 0.0
                    
                    // Open document after download
                    if FileManager.default.fileExists(atPath: destinationFile.path) {
                        self.documentPreviewURL = destinationFile
                        self.showDocumentPreview = true
                    }
                }
            },
            onFailure: { error in
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.showDownloadProgress = false
                    self.showDownloadButton = true
                    self.downloadProgress = 0.0
                    print("🚫 [DOWNLOAD] Download failed: \(error.localizedDescription)")
                }
            }
        )
    }
}

// MARK: - Receiver Document View (matching Android docLyt design)
struct ReceiverDocumentView: View {
    @Environment(\.colorScheme) var colorScheme
    let documentUrl: String
    let fileName: String
    let docSize: String?
    let fileExtension: String?
    let micPhoto: String?
    
    @State private var isDownloading: Bool = false
    @State private var showMusicPlayerBottomSheet: Bool = false
    @State private var downloadProgress: Double = 0.0
    @State private var showDownloadButton: Bool = false
    @State private var showDownloadProgress: Bool = false
    @State private var showProgressBar: Bool = false
    @State private var showPdfPreview: Bool = false
    @State private var pdfPreviewImage: UIImage? = nil
    @State private var showDocumentPreview: Bool = false
    @State private var documentPreviewURL: URL? = nil
    // Audio player state
    @State private var audioPlayer: AVPlayer? = nil
    @State private var isAudioPlaying: Bool = false
    @State private var audioCurrentTime: TimeInterval = 0.0
    @State private var audioDuration: TimeInterval = 0.0
    @State private var audioTimeObserver: Any? = nil
    @State private var showShareSheet: Bool = false
    @State private var downloadedFileURL: URL? = nil
    
    // Get local documents directory path
    private func getLocalDocumentsDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let docsDir = documentsPath.appendingPathComponent("Enclosure/Media/Documents", isDirectory: true)
        try? FileManager.default.createDirectory(at: docsDir, withIntermediateDirectories: true, attributes: nil)
        return docsDir
    }
    
    // Get local audios directory path (matching Android Enclosure/Media/Audios)
    private func getLocalAudiosDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audiosDir = documentsPath.appendingPathComponent("Enclosure/Media/Audios", isDirectory: true)
        try? FileManager.default.createDirectory(at: audiosDir, withIntermediateDirectories: true, attributes: nil)
        return audiosDir
    }
    
    // Check if local file exists
    // For audio files, also check Audios directory (matching Android behavior)
    private var hasLocalFile: Bool {
        guard !fileName.isEmpty else { return false }
        
        // For audio files, check Audios directory first (matching Android)
        if isAudio {
            let audiosDir = getLocalAudiosDirectory()
            let audioURL = audiosDir.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: audioURL.path) {
                return true
            }
        }
        
        // Check Documents directory
        let localURL = getLocalDocumentsDirectory().appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: localURL.path)
    }
    
    // Get file extension
    private var extensionText: String {
        if let ext = fileExtension, !ext.isEmpty {
            return ext.uppercased()
        }
        let ext = (fileName as NSString).pathExtension
        if !ext.isEmpty {
            return ext.uppercased()
        }
        return "DOC"
    }
    
    // Format file size to match Android format (e.g., "12.4 kb")
    private var formattedDocSize: String? {
        guard let size = docSize, !size.isEmpty else { return nil }
        
        // If already formatted (contains "kb" or "mb"), return as is
        if size.lowercased().contains("kb") || size.lowercased().contains("mb") {
            return size
        }
        
        // Parse as bytes and format
        if let bytes = Int64(size) {
            if bytes < 1024 {
                return "\(bytes) b"
            } else if bytes < 1024 * 1024 {
                let kb = Double(bytes) / 1024.0
                return String(format: "%.1f kb", kb)
            } else {
                let mb = Double(bytes) / (1024.0 * 1024.0)
                return String(format: "%.1f mb", mb)
            }
        }
        
        return size
    }
    
    // Check if file is PDF
    private var isPdf: Bool {
        extensionText.uppercased() == "PDF"
    }
    
    // Check if file is audio/music (matching Android musicExtensions list)
    private var isAudio: Bool {
        let ext = extensionText.lowercased()
        return ["mp3", "wav", "flac", "aac", "ogg", "oga", "m4a", "wma", "alac", "aiff"].contains(ext)
    }
    
    // Download document
    private func downloadDocument() {
        guard !fileName.isEmpty else {
            print("🚫 [DOWNLOAD] No fileName available")
            return
        }
        
        guard !documentUrl.isEmpty else {
            print("🚫 [DOWNLOAD] No document URL available")
            return
        }
        
        // For audio files, use Audios directory (matching Android)
        let destinationDir = isAudio ? getLocalAudiosDirectory() : getLocalDocumentsDirectory()
        let destinationFile = destinationDir.appendingPathComponent(fileName)
        
        // Check if file already exists
        if FileManager.default.fileExists(atPath: destinationFile.path) {
            print("📱 [DOWNLOAD] Document already exists locally")
            return
        }
        
        // Check if already downloading
        if BackgroundDownloadManager.shared.isDownloading(fileName: fileName) {
            print("📱 [DOWNLOAD] Already downloading: \(fileName)")
            return
        }
        
        // Light haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Update UI
        isDownloading = true
        showDownloadButton = false
        showDownloadProgress = true
        showProgressBar = false
        downloadProgress = 0.0
        
        // Use BackgroundDownloadManager for document downloads
        BackgroundDownloadManager.shared.downloadImage(
            imageUrl: documentUrl,
            fileName: fileName,
            destinationFile: destinationFile,
            onProgress: { progress in
                DispatchQueue.main.async {
                    self.downloadProgress = progress
                    if progress > 0 {
                        self.showDownloadProgress = true
                        self.showProgressBar = false
                    }
                }
            },
            onSuccess: {
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.showDownloadProgress = false
                    self.showProgressBar = false
                    self.showDownloadButton = false
                    self.downloadProgress = 0.0
                    print("✅ [DOWNLOAD] Document downloaded successfully")
                }
            },
            onFailure: { error in
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.showDownloadProgress = false
                    self.showProgressBar = false
                    self.showDownloadButton = true
                    self.downloadProgress = 0.0
                    print("🚫 [DOWNLOAD] Download failed: \(error.localizedDescription)")
                }
            }
        )
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            // Audio player container (shown for audio files only) - matching Android miceContainer
            if isAudio {
                audioPlayerView
            }
            
            // PDF preview (shown for PDF) - matching Android pdfcard CardView, full width to parent container
            if isPdf && showPdfPreview, let pdfImage = pdfPreviewImage {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .frame(maxWidth: .infinity) // Full width to parent container
                    .frame(height: 100) // Fixed height
                    .overlay(
                        Image(uiImage: pdfImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity) // Full width to parent container
                            .frame(height: 100) // Fixed height
                            .clipShape(RoundedRectangle(cornerRadius: 20)) // Apply 20dp corner radius to image
                    )
                    .padding(.horizontal, 1)
                    .padding(.vertical, 1)
            }
            
            // Row: download controls (left) | doc info (center, weight) | file icon (right) - matching Android LinearLayout
            // Only show document info section if NOT audio (audio files show only audio player)
            if !isAudio {
                HStack(alignment: .center, spacing: 0) {
                // Left-side download/progress controls - matching Android docDownloadControlsReceiver RelativeLayout
                // Only show container when there's content to display (matching Android visibility="gone" when empty)
                // Show if: download button visible OR progress bar visible OR download percentage visible OR pause button visible
                if (!hasLocalFile && !isDownloading && showDownloadButton) || 
                   (showProgressBar && isDownloading) || 
                   (showDownloadProgress && isDownloading) || 
                   isDownloading {
                    ZStack {
                        // Download button - matching SelectionBunchLayout glassmorphism style
                        if !hasLocalFile && !isDownloading && showDownloadButton {
                            Button(action: {
                                downloadDocument()
                            }) {
                                ZStack {
                                    // iOS glassmorphism background (matching SelectionBunchLayout)
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 35, height: 35)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                                    
                                    Image("downloaddown")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                        .foregroundColor(.white) // Matching receiver SelectionBunchLayout
                                }
                            }
                        }
                        
                        // Progress bar - matching Android progressBarDocReceiver ProgressBar
                        if showProgressBar && isDownloading {
                            ProgressView()
                                .progressViewStyle(LinearProgressViewStyle(tint: Color("TextColor")))
                                .frame(width: 40, height: 4)
                        }
                        
                        // Download percentage - matching SelectionBunchLayout glassmorphism style
                        if showDownloadProgress && isDownloading {
                            ZStack {
                                // iOS glassmorphism background (matching SelectionBunchLayout)
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                                
                                Text("\(Int(downloadProgress))%")
                                    .font(.custom("Inter18pt-Bold", size: 15))
                                    .foregroundColor(.white)
                            }
                        }
                        
                    }
                    .frame(width: 60, height: 60)
                }
                
                // Center: doc info - matching Android LinearLayout with weight=1, layout_width="0dp", layout_weight="1", layout_height="wrap_content", layout_marginHorizontal="3dp", layout_gravity="start|center_vertical", alpha="0.8"
                VStack(alignment: .leading, spacing: 0) { // spacing: 0 - no spacing between docName and size row (matching Android)
                    // Document name - matching Android docName TextView: layout_width="match_parent", layout_height="wrap_content", maxWidth="170dp"
                    Text(fileName)
                        .font(.custom("Inter18pt-Regular", size: 14)) // textSize="14sp", fontFamily="@font/inter"
                        .foregroundColor(.white) // textColor="@color/white"
                        .lineLimit(1) // singleLine="true"
                        .truncationMode(.tail) // Add ellipsis at end when truncated (matching Android)
                        .frame(maxWidth: 170, alignment: .leading) // maxWidth="170dp" (wrap_content up to 170dp)
                        .fixedSize(horizontal: false, vertical: true) // layout_height="wrap_content" - minimize vertical space
                        .padding(.vertical, 0) // Remove any implicit vertical padding
                    
                    // Size and extension row - matching Android LinearLayout: layout_width="match_parent", layout_height="wrap_content", orientation="horizontal"
                    // No spacing between docName and this row (spacing: 0 in VStack matches Android - elements are touching)
                    HStack(spacing: 0) { // spacing: 0 - no spacing between size, bullet, and extension (matching Android)
                        // Document size - matching Android docSize TextView: layout_width="wrap_content", layout_height="wrap_content"
                        if let size = formattedDocSize {
                            Text(size)
                                .font(.custom("Inter18pt-Regular", size: 12)) // textSize="12sp", fontFamily="@font/inter"
                                .foregroundColor(Color(hex: "#9EA6B9")) // textColor="@color/gray" = #9EA6B9
                                .lineLimit(1) // singleLine="true"
                        }
                        
                        // Bullet separator - matching Android TextView: layout_width="wrap_content", layout_marginHorizontal="5dp"
                        Text("•")
                            .font(.custom("Inter18pt-Regular", size: 12)) // fontFamily="@font/inter"
                            .foregroundColor(Color(hex: "#9EA6B9")) // textColor="@color/gray" = #9EA6B9
                            .lineLimit(1) // singleLine="true"
                            .padding(.horizontal, 5) // layout_marginHorizontal="5dp"
                        
                        // Extension - matching Android docSizeExtension TextView: layout_width="wrap_content", layout_height="wrap_content"
                        Text(extensionText)
                            .font(.custom("Inter18pt-Regular", size: 12)) // textSize="12sp", fontFamily="@font/inter"
                            .foregroundColor(Color(hex: "#9EA6B9")) // textColor="@color/gray" = #9EA6B9
                            .textCase(.uppercase) // textAllCaps="true"
                            .lineLimit(1) // singleLine="true"
                        
                        Spacer(minLength: 0) // Push content to left, no extra space on right
                    }
                }
                .padding(.horizontal, 9) // paddingStart="9dp", paddingEnd="9dp" (inside background)
                .padding(.top, 5) // paddingTop="5dp" (inside background)
                .padding(.bottom, 5) // paddingBottom="5dp" (inside background)
                .fixedSize(horizontal: false, vertical: true) // layout_height="wrap_content" - minimize vertical space
                .background(
                    // Background matching doc__rec_bg drawable: radius="20dp", solid color="@color/black" = #000000
                    RoundedRectangle(cornerRadius: 20) // android:radius="20dp" (same as sender side)
                        .fill(Color.black) // Solid color="@color/black" = #000000
                )
                .opacity(0.8) // alpha="0.8" on entire container (matching Android alpha on LinearLayout)
                .padding(.horizontal, 3) // layout_marginHorizontal="3dp" (outside background, between controls and info)
                .frame(maxWidth: .infinity, alignment: .leading) // layout_weight="1" (expands to fill space horizontally)
                
                // Right: file icon - matching Android docFileIcon LinearLayout: layout_width="26dp", layout_height="26dp", layout_gravity="center_vertical", alpha="0.8", paddingTop="10dp"
                VStack(spacing: 0) { // Container matching Android LinearLayout with paddingTop="10dp"
                    ZStack(alignment: .center) {
                        // Background matching pagesvg drawable with backgroundTint="@color/TextColor"
                        Image("pagesvg")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 26, height: 26)
                            .foregroundColor(Color("TextColor"))
                            .opacity(0.8) // alpha="0.8"
                        
                        // Extension text - matching Android extension TextView: layout_marginBottom="7dp", layout_gravity="center"
                        // textColor="@color/modetheme2": light mode = @color/whitenew (#F6F7FF), dark mode = @color/black (#000000)
                        Text(extensionText.prefix(4)) // maxLength="4"
                            .font(.custom("Inter18pt-Bold", size: 7.5)) // textSize="7.5sp", fontFamily="@font/inter_bold"
                            .foregroundColor(colorScheme == .light ? Color(hex: "#F6F7FF") : Color.black) // Light: whitenew, Dark: black
                            .textCase(.uppercase) // textAllCaps="true"
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: true) // Minimize vertical space
                            .offset(y: 3.5) // layout_marginBottom="7dp" - offset to position text
                    }
                    .frame(width: 26, height: 26) // layout_width="26dp", layout_height="26dp"
                }
                .padding(.top, 0) // paddingTop="10dp" on LinearLayout (matching Android)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 7)
            .frame(minWidth: 200)
            }
        }
        .frame(minHeight: 40)
        .onTapGesture {
            openDocument()
        }
        .fullScreenCover(isPresented: $showDocumentPreview) {
            Group {
                if let url = documentPreviewURL {
                    ShowDocumentScreen(
                        documentURL: url,
                        fileName: fileName,
                        docSize: docSize,
                        fileExtension: fileExtension,
                        viewHolderType: "receiver",
                        downloadUrl: documentUrl.isEmpty ? nil : documentUrl
                    )
                    .onAppear {
                        print("📄 [ReceiverDocumentView] ShowDocumentScreen appeared - url: \(url.path)")
                    }
                } else {
                    Color.black.ignoresSafeArea()
                        .onAppear {
                            print("🚫 [ReceiverDocumentView] fullScreenCover triggered but documentPreviewURL is nil!")
                        }
                }
            }
        }
        .onChange(of: showDocumentPreview) { newValue in
            print("📄 [ReceiverDocumentView] showDocumentPreview changed to: \(newValue), documentPreviewURL: \(documentPreviewURL?.path ?? "nil")")
        }
        .sheet(isPresented: $showMusicPlayerBottomSheet) {
            MusicPlayerBottomSheet(
                audioUrl: documentUrl.isEmpty ? fileName : documentUrl,
                profileImageUrl: micPhoto ?? "",
                songTitle: fileName.isEmpty ? "Audio Message" : fileName
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showShareSheet) {
            if let fileURL = downloadedFileURL {
                ShareSheet(activityItems: [fileURL])
            }
        }
        .onAppear {
            print("📄 [ReceiverDocumentView] onAppear - fileName: \(fileName), documentUrl: \(documentUrl.isEmpty ? "empty" : "has URL"), docSize: \(docSize ?? "nil"), fileExtension: \(fileExtension ?? "nil")")
            
            // Check if local file exists and we have a URL to download
            if !hasLocalFile && !documentUrl.isEmpty {
                showDownloadButton = true
            }
            
            // Load PDF preview if PDF
            if isPdf {
                loadPdfPreview()
            }
        }
    }
    
    // Audio player view (matching Android miceContainer)
    @ViewBuilder
    // Audio player view (matching Android miceContainer) - for music files in doc dataType
    // Using same design as ReceiverVoiceAudioView but keeping timing text and receiver theme
    private var audioPlayerView: some View {
        VStack(spacing: 0) {
            // Main container - matching Android miceContainer LinearLayout
            // Android: layout_width="wrap_content", layout_marginHorizontal="7dp", layout_marginVertical="7dp", orientation="vertical", gravity="center"
            VStack(spacing: 0) {
                // Inner container - matching Android inner LinearLayout
                // Android: layout_width="wrap_content", orientation="horizontal", layout_gravity="center", gravity="center"
                HStack(alignment: .center, spacing: 0) {
                    // Download controls (only show if file not downloaded) - matching Android audioDownloadControlsReceiver
                    // Android: layout_marginEnd="7dp"
                    if !hasLocalFile {
                        audioDownloadControlsView
                            .padding(.trailing, 7) // Android: layout_marginEnd="7dp"
                    }
                    
                    // Play button - matching Android micePlay AppCompatImageButton
                    // Android: scaleX="1.4", scaleY="1.4", src="@drawable/play_arrow_receiver", tint="@color/TextColor"
                    Button(action: {
                        openMusicPlayer()
                    }) {
                        Image("play_arrow_receiver")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundColor(Color("TextColor")) // Android: tint="@color/TextColor"
                            .scaleEffect(1.4) // Android: scaleX="1.4", scaleY="1.4"
                    }
                    
                    // Horizontal container for progress bar and timing - vertically centered
                    HStack(alignment: .center, spacing: 5) {
                        // Progress bar - matching Android miceProgressbar LinearProgressIndicator
                        // Android: indicatorColor="@color/teal_700", trackCornerRadius="20dp", trackThickness="5dp"
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 20) // Android: trackCornerRadius="20dp"
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 5) // Android: trackThickness="5dp"
                                
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(hex: "#018786")) // Android: indicatorColor="@color/teal_700"
                                    .frame(width: geometry.size.width * CGFloat(audioDuration > 0 ? audioCurrentTime / audioDuration : 0), height: 5)
                            }
                        }
                        .frame(height: 5)
                        .frame(minWidth: 150) // Android: minWidth="150dp"
                        
                        // Timing text - matching Android miceTiming TextView
                        // Android: style="@style/TextColor", textSize="10sp", fontFamily="@font/inter", layout_gravity="start"
                        // Keep timing text showing duration, left aligned
                        Text(formatTime(audioDuration > 0 ? audioDuration : 0))
                            .font(.custom("Inter18pt-Regular", size: 10)) // Android: fontFamily="@font/inter", textSize="10sp"
                            .foregroundColor(Color("TextColor")) // Android: style="@style/TextColor"
                            .frame(alignment: .leading) // Android: layout_gravity="start"
                    }
                    .padding(.horizontal, 5) // Android: layout_marginHorizontal="5dp"
                }
            }
            .padding(.horizontal, 7) // Android: layout_marginHorizontal="7dp"
            .padding(.vertical, 7) // Android: layout_marginVertical="7dp"
        }
        .onAppear {
            if isAudio && hasLocalFile {
                setupAudioPlayer()
            }
        }
        .onDisappear {
            stopAudioPlayer()
        }
    }
    
    // Audio download controls view (matching Android audioDownloadControlsReceiver)
    @ViewBuilder
    private var audioDownloadControlsView: some View {
        ZStack {
            // Download button - matching SelectionBunchLayout glassmorphism style
            if !isDownloading && showDownloadButton {
                Button(action: {
                    downloadDocument()
                }) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 35, height: 35)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                        
                        Image("downloaddown")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.white)
                    }
                }
            }
            
            // Progress bar - matching Android progressBarAudioReceiver
            if showProgressBar && isDownloading {
                ProgressView()
                    .progressViewStyle(LinearProgressViewStyle(tint: Color("TextColor")))
                    .frame(width: 40, height: 4)
            }
            
            // Download percentage - matching Android downloadPercentageAudioReceiver
            if showDownloadProgress && isDownloading {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                    
                    Text("\(Int(downloadProgress))%")
                        .font(.custom("Inter18pt-Bold", size: 15))
                        .foregroundColor(.white)
                }
            }
        }
        .frame(width: 60, height: 60)
        .padding(.trailing, 7) // layout_marginEnd="7dp"
    }
    
    // Get local images directory
    private func getLocalImagesDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagesDir = documentsPath.appendingPathComponent("Enclosure/Media/Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true, attributes: nil)
        return imagesDir
    }
    
    // Get local videos directory
    private func getLocalVideosDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videosDir = documentsPath.appendingPathComponent("Enclosure/Media/Videos", isDirectory: true)
        try? FileManager.default.createDirectory(at: videosDir, withIntermediateDirectories: true, attributes: nil)
        return videosDir
    }
    
    // Find local file URL by checking multiple directories
    private func findLocalFileURL() -> URL? {
        // For audio files, check Audios directory first (matching Android behavior)
        if isAudio {
            let audiosURL = getLocalAudiosDirectory().appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: audiosURL.path) {
                return audiosURL
            }
        }
        
        // Check Documents directory (for documents sent as documents)
        let docsURL = getLocalDocumentsDirectory().appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: docsURL.path) {
            return docsURL
        }
        
        // Check Images directory (for images sent as documents)
        if isImage {
            let imagesURL = getLocalImagesDirectory().appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: imagesURL.path) {
                return imagesURL
            }
        }
        
        // Check Videos directory (for videos sent as documents)
        if isVideo {
            let videosURL = getLocalVideosDirectory().appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: videosURL.path) {
                return videosURL
            }
        }
        
        return nil
    }
    
    // Check if file is image
    private var isImage: Bool {
        let ext = (fileName as NSString).pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "webp", "gif", "tiff", "psd", "heif", "svg"].contains(ext)
    }
    
    // Check if file is video
    private var isVideo: Bool {
        let ext = (fileName as NSString).pathExtension.lowercased()
        return ["mp4", "mov", "wmv", "flv", "mkv", "avi", "avchd", "webm", "hevc"].contains(ext)
    }
    
    // Format time for audio player
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%.2d:%.2d", minutes, seconds)
    }
    
    // Setup audio player
    private func setupAudioPlayer() {
        guard let localURL = findLocalFileURL() else { return }
        
        audioPlayer = AVPlayer(url: localURL)
        
        // Get duration
        if let duration = audioPlayer?.currentItem?.asset.duration {
            audioDuration = CMTimeGetSeconds(duration)
        }
        
        // Observe time updates
        audioTimeObserver = audioPlayer?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { time in
            self.audioCurrentTime = CMTimeGetSeconds(time)
        }
    }
    
    // Toggle audio playback
    private func toggleAudioPlayback() {
        guard let player = audioPlayer else {
            if hasLocalFile {
                setupAudioPlayer()
                audioPlayer?.play()
                isAudioPlaying = true
            }
            return
        }
        
        if isAudioPlaying {
            player.pause()
            isAudioPlaying = false
        } else {
            player.play()
            isAudioPlaying = true
        }
    }
    
    // Stop audio player
    private func stopAudioPlayer() {
        audioPlayer?.pause()
        audioPlayer = nil
        isAudioPlaying = false
        audioCurrentTime = 0.0
        audioDuration = 0.0
        if let observer = audioTimeObserver {
            audioPlayer?.removeTimeObserver(observer)
            audioTimeObserver = nil
        }
    }
    
    // Open music player bottom sheet (matching Android micePlay click handler)
    private func openMusicPlayer() {
        print("🎵 [ReceiverDocumentView] Opening music player - fileName: \(fileName)")
        
        // Get audio details
        var audioUrl = documentUrl.isEmpty ? fileName : documentUrl
        let profileImageUrl = micPhoto ?? ""
        let songTitle = fileName.isEmpty ? "Audio Message" : fileName
        var localFilePath: String? = nil
        
        // Check for local file first (matching Android logic)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audiosDir = documentsPath.appendingPathComponent("Enclosure/Media/Audios", isDirectory: true)
        
        print("🎵 [ReceiverDocumentView] Checking audios directory: \(audiosDir.path)")
        
        if FileManager.default.fileExists(atPath: audiosDir.path) {
            let localFile = audiosDir.appendingPathComponent(fileName)
            print("🎵 [ReceiverDocumentView] Looking for file: \(fileName)")
            print("🎵 [ReceiverDocumentView] Full path: \(localFile.path)")
            
            if FileManager.default.fileExists(atPath: localFile.path) {
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: localFile.path)[.size] as? Int64) ?? 0
                if fileSize > 0 {
                    localFilePath = localFile.path
                    audioUrl = "file://" + localFilePath!
                    print("✅ [ReceiverDocumentView] Local file found and valid: \(localFilePath!)")
                    print("🎵 [ReceiverDocumentView] Audio URL with file://: \(audioUrl)")
                } else {
                    print("🚫 [ReceiverDocumentView] Local file exists but is empty")
                }
            } else {
                print("🚫 [ReceiverDocumentView] Local file not found: \(localFile.path)")
            }
        } else {
            print("🚫 [ReceiverDocumentView] Audios directory not found: \(audiosDir.path)")
        }
        
        print("🎵 [ReceiverDocumentView] Final audioUrl: \(audioUrl)")
        print("🎵 [ReceiverDocumentView] Final localFilePath: \(localFilePath ?? "nil")")
        
        // Show the bottom sheet
        showMusicPlayerBottomSheet = true
    }
    
    // Open document in preview
    private func openDocument() {
        print("📄 [ReceiverDocumentView] Opening document - fileName: \(fileName)")
        
        // Check if file exists locally first - check multiple directories
        var localURL: URL? = nil
        
        // For audio files, check Audios directory first (matching Android behavior)
        if isAudio {
            let audiosURL = getLocalAudiosDirectory().appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: audiosURL.path) {
                localURL = audiosURL
                print("📄 [ReceiverDocumentView] Found file in Audios: \(audiosURL.path)")
            }
        }
        
        // Check Documents directory
        if localURL == nil {
            let docsURL = getLocalDocumentsDirectory().appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: docsURL.path) {
                localURL = docsURL
                print("📄 [ReceiverDocumentView] Found file in Documents: \(docsURL.path)")
            }
        }
        
        // Check Images directory if it's an image
        if localURL == nil && isImage {
            let imagesURL = getLocalImagesDirectory().appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: imagesURL.path) {
                localURL = imagesURL
                print("📄 [ReceiverDocumentView] Found file in Images: \(imagesURL.path)")
            }
        }
        
        // Check Videos directory if it's a video
        if localURL == nil && isVideo {
            let videosURL = getLocalVideosDirectory().appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: videosURL.path) {
                localURL = videosURL
                print("📄 [ReceiverDocumentView] Found file in Videos: \(videosURL.path)")
            }
        }
        
        if let localFileURL = localURL {
            print("📄 [ReceiverDocumentView] Setting documentPreviewURL: \(localFileURL.path)")
            documentPreviewURL = localFileURL
            print("📄 [ReceiverDocumentView] documentPreviewURL set, now setting showDocumentPreview = true")
            showDocumentPreview = true
            print("📄 [ReceiverDocumentView] showDocumentPreview is now: \(showDocumentPreview)")
            return
        }
        
        // If not local and we have a download URL, download first then open
        if !documentUrl.isEmpty, let url = URL(string: documentUrl) {
            // Check if already downloading
            if isDownloading {
                print("📄 [ReceiverDocumentView] Already downloading, please wait")
                return
            }
            
            // Start download and open when complete
            downloadDocumentAndOpen()
        } else {
            print("🚫 [ReceiverDocumentView] No document URL available")
        }
    }
    
    // Download document and open when complete
    private func downloadDocumentAndOpen() {
        guard !fileName.isEmpty else {
            print("🚫 [DOWNLOAD] No fileName available")
            return
        }
        
        let docsDir = getLocalDocumentsDirectory()
        let destinationFile = docsDir.appendingPathComponent(fileName)
        
        // Check if file already exists
        if FileManager.default.fileExists(atPath: destinationFile.path) {
            documentPreviewURL = destinationFile
            showDocumentPreview = true
            return
        }
        
        // Check if already downloading
        if BackgroundDownloadManager.shared.isDownloading(fileName: fileName) {
            print("📱 [DOWNLOAD] Already downloading: \(fileName)")
            return
        }
        
        // Light haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Update UI: hide download button, show progress
        isDownloading = true
        showDownloadButton = false
        showDownloadProgress = true
        downloadProgress = 0.0
        
        // Use BackgroundDownloadManager for background downloads
        BackgroundDownloadManager.shared.downloadImage(
            imageUrl: documentUrl,
            fileName: fileName,
            destinationFile: destinationFile,
            onProgress: { progress in
                DispatchQueue.main.async {
                    self.downloadProgress = progress
                }
            },
            onSuccess: {
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.showDownloadProgress = false
                    self.showDownloadButton = false
                    self.downloadProgress = 0.0
                    
                    // Open document after download
                    if FileManager.default.fileExists(atPath: destinationFile.path) {
                        self.documentPreviewURL = destinationFile
                        self.showDocumentPreview = true
                    }
                }
            },
            onFailure: { error in
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.showDownloadProgress = false
                    self.showDownloadButton = true
                    self.downloadProgress = 0.0
                    print("🚫 [DOWNLOAD] Download failed: \(error.localizedDescription)")
                }
            }
        )
    }
    
    // Load PDF preview thumbnail
    private func loadPdfPreview() {
        // Check if PDF file exists locally
        guard hasLocalFile else {
            showPdfPreview = false
            return
        }
        
        let localURL = getLocalDocumentsDirectory().appendingPathComponent(fileName)
        
        // Generate thumbnail from PDF first page
        DispatchQueue.global(qos: .userInitiated).async {
            guard let pdfDocument = CGPDFDocument(localURL as CFURL),
                  let firstPage = pdfDocument.page(at: 1) else {
                DispatchQueue.main.async {
                    self.showPdfPreview = false
                }
                return
            }
            
            // Get page rect
            let pageRect = firstPage.getBoxRect(.mediaBox)
            let scale: CGFloat = 180.0 / max(pageRect.width, pageRect.height)
            let scaledSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)
            
            // Create thumbnail
            UIGraphicsBeginImageContextWithOptions(scaledSize, false, 0.0)
            guard let context = UIGraphicsGetCurrentContext() else {
                UIGraphicsEndImageContext()
                DispatchQueue.main.async {
                    self.showPdfPreview = false
                }
                return
            }
            
            context.interpolationQuality = .high
            context.scaleBy(x: scale, y: scale)
            context.drawPDFPage(firstPage)
            
            let thumbnailImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            DispatchQueue.main.async {
                if let image = thumbnailImage {
                    self.pdfPreviewImage = image
                    self.showPdfPreview = true
                } else {
                    self.showPdfPreview = false
                }
            }
        }
    }
}

// MARK: - Document Preview View (matching Android show_document_screen)
struct DocumentPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    let documentURL: URL
    let fileName: String
    let docSize: String?
    let fileExtension: String?
    let viewHolderType: String? // "sender" or "receiver" or nil
    let downloadUrl: String? // URL to download from if file doesn't exist locally
    
    @State private var isDownloaded: Bool = false
    @State private var isDownloading: Bool = false
    @State private var showImagePreview: Bool = false
    @State private var showVideoPlayer: Bool = false
    @State private var imageToDisplay: UIImage? = nil
    @State private var videoPlayer: AVPlayer? = nil
    @State private var showSaveMenu: Bool = false
    
    // Get local documents directory path
    private func getLocalDocumentsDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let docsDir = documentsPath.appendingPathComponent("Enclosure/Media/Documents", isDirectory: true)
        try? FileManager.default.createDirectory(at: docsDir, withIntermediateDirectories: true, attributes: nil)
        return docsDir
    }
    
    // Get local images directory path
    private func getLocalImagesDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagesDir = documentsPath.appendingPathComponent("Enclosure/Media/Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true, attributes: nil)
        return imagesDir
    }
    
    // Get local videos directory path
    private func getLocalVideosDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videosDir = documentsPath.appendingPathComponent("Enclosure/Media/Videos", isDirectory: true)
        try? FileManager.default.createDirectory(at: videosDir, withIntermediateDirectories: true, attributes: nil)
        return videosDir
    }
    
    // Get local audios directory path (matching Android Enclosure/Media/Audios)
    private func getLocalAudiosDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audiosDir = documentsPath.appendingPathComponent("Enclosure/Media/Audios", isDirectory: true)
        try? FileManager.default.createDirectory(at: audiosDir, withIntermediateDirectories: true, attributes: nil)
        return audiosDir
    }
    
    // Check if file is audio
    private var isAudio: Bool {
        let ext = (fileName as NSString).pathExtension.lowercased()
        return ["mp3", "wav", "m4a", "aac", "flac", "ogg", "wma", "opus", "amr", "3gp"].contains(ext)
    }
    
    // Check if file exists locally
    private var hasLocalFile: Bool {
        // First check if documentURL is a local file
        if documentURL.isFileURL && FileManager.default.fileExists(atPath: documentURL.path) {
            return true
        }
        // Check in appropriate directory based on file type
        if let localURL = findLocalFileURL() {
            return FileManager.default.fileExists(atPath: localURL.path)
        }
        return false
    }
    
    // Get the actual local file URL - check multiple directories based on file type
    private var localFileURL: URL? {
        // First check if documentURL is a local file
        if documentURL.isFileURL && FileManager.default.fileExists(atPath: documentURL.path) {
            print("📄 [DocumentPreviewView] Found file at documentURL: \(documentURL.path)")
            return documentURL
        }
        // Check in appropriate directory based on file type
        if let localURL = findLocalFileURL(), FileManager.default.fileExists(atPath: localURL.path) {
            print("📄 [DocumentPreviewView] Found file at: \(localURL.path)")
            return localURL
        }
        print("🚫 [DocumentPreviewView] File not found locally: \(fileName)")
        return nil
    }
    
    // Find local file URL by checking multiple directories
    private func findLocalFileURL() -> URL? {
        // For audio files, check Audios directory first (matching Android behavior)
        if isAudio {
            let audiosURL = getLocalAudiosDirectory().appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: audiosURL.path) {
                return audiosURL
            }
        }
        
        // Check Documents directory (for documents sent as documents)
        let docsURL = getLocalDocumentsDirectory().appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: docsURL.path) {
            return docsURL
        }
        
        // Check Images directory (for images sent as documents)
        if isImage {
            let imagesURL = getLocalImagesDirectory().appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: imagesURL.path) {
                return imagesURL
            }
        }
        
        // Check Videos directory (for videos sent as documents)
        if isVideo {
            let videosURL = getLocalVideosDirectory().appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: videosURL.path) {
                return videosURL
            }
        }
        
        return nil
    }
    
    // Check if file is image
    private var isImage: Bool {
        let ext = (fileName as NSString).pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "webp", "gif", "tiff", "psd", "heif", "svg"].contains(ext)
    }
    
    // Check if file is video
    private var isVideo: Bool {
        let ext = (fileName as NSString).pathExtension.lowercased()
        return ["mp4", "mov", "wmv", "flv", "mkv", "avi", "avchd", "webm", "hevc"].contains(ext)
    }
    
    var body: some View {
        ZStack {
            // Full-screen black background (matching Android @color/black)
            Color.black
                .ignoresSafeArea()
            
            // Preview controls (shown when file is downloaded)
            if isDownloaded {
                if showImagePreview, let image = imageToDisplay {
                    // Image preview (matching Android PhotoView)
                    GeometryReader { geometry in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    }
                } else if showVideoPlayer, let player = videoPlayer {
                    // Video player (matching Android ExoPlayer)
                    VideoPlayer(player: player)
                        .onAppear {
                            player.play()
                        }
                } else {
                    // Document - show download button with done icon
                    downloadControlsView(isDownloaded: true)
                }
            } else {
                // Download controls (shown when file is not downloaded)
                downloadControlsView(isDownloaded: false)
            }
            
            // Top bar with back button and menu
            VStack {
                HStack {
                    // Back arrow button (matching Android backarrow34)
                    Button(action: {
                        // Light haptic feedback
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        dismiss()
                    }) {
                        ZStack {
                            // Background matching Android black_background_hover
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.black.opacity(0.6))
                                .frame(width: 35, height: 36)
                            
                            Image("leftvector")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 25, height: 18)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.leading, 20)
                    .padding(.top, 50)
                    
                    Spacer()
                    
                    // Menu button (3 dots) - only show for sender/receiver view holders
                    if viewHolderType == "sender" || viewHolderType == "receiver" {
                        Button(action: {
                            // Light haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            showSaveMenu = true
                        }) {
                            ZStack {
                                // Background matching Android custome_ripple_circle
                                Circle()
                                    .fill(Color.black.opacity(0.6))
                                    .frame(width: 40, height: 40)
                                
                                // Three dots (matching Android menuPoint design)
                                VStack(spacing: 3) {
                                    Circle()
                                        .fill(Color(hex: "#9EA6B9"))
                                        .frame(width: 4, height: 4)
                                    
                                    Circle()
                                        .fill(Color(hex: "#00A3E9")) // Theme color
                                        .frame(width: 4, height: 4)
                                    
                                    Circle()
                                        .fill(Color(hex: "#9EA6B9"))
                                        .frame(width: 4, height: 4)
                                }
                            }
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 50)
                        .confirmationDialog("Save", isPresented: $showSaveMenu) {
                            Button("Save") {
                                saveFileToGallery()
                            }
                        }
                    }
                }
                
                Spacer()
            }
        }
        .onAppear {
            checkFileAndDisplay()
        }
        .onDisappear {
            videoPlayer?.pause()
            videoPlayer = nil
        }
    }
    
    // Download controls view (matching Android downloadCtrl LinearLayout)
    @ViewBuilder
    private func downloadControlsView(isDownloaded: Bool) -> some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Document name (matching Android docName TextView)
            Text(fileName)
                .font(.custom("Inter18pt-Medium", size: 18))
                .foregroundColor(Color("gray3"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .lineLimit(3)
            
            // "size" label (matching Android TextView)
            Text("size")
                .font(.custom("Inter18pt-Medium", size: 15))
                .foregroundColor(Color("gray3"))
                .padding(.horizontal, 30)
                .padding(.top, 10)
            
            // File size value (matching Android size TextView)
            if let size = docSize {
                Text(size)
                    .font(.custom("Inter18pt-Medium", size: 15))
                    .foregroundColor(Color("gray3"))
                    .padding(.horizontal, 30)
            }
            
            // Download button or done icon (matching Android FloatingActionButton)
            if isDownloaded {
                // Done icon (matching Android done drawable)
                Button(action: {
                    openDownloadedFile()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#00A3E9")) // Theme color
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "checkmark")
                            .foregroundColor(.white)
                            .font(.system(size: 20, weight: .bold))
                    }
                }
                .padding(.top, 10)
            } else {
                // Download button
                Button(action: {
                    downloadFile()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#00A3E9")) // Theme color
                            .frame(width: 40, height: 40)
                        
                        Image("downloaddown")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.white)
                    }
                }
                .padding(.top, 10)
                
                // Progress bar (matching Android ProgressBar)
                if isDownloading {
                    ProgressView()
                        .progressViewStyle(LinearProgressViewStyle(tint: Color("TextColor")))
                        .frame(height: 4)
                        .padding(.top, 10)
                }
            }
            
            Spacer()
        }
    }
    
    // Check file and display accordingly
    private func checkFileAndDisplay() {
        print("📄 [DocumentPreviewView] checkFileAndDisplay - fileName: \(fileName), isImage: \(isImage), isVideo: \(isVideo)")
        
        if let localURL = localFileURL {
            print("📄 [DocumentPreviewView] File found at: \(localURL.path)")
            isDownloaded = true
            
            if isImage {
                // Load and display image
                print("📄 [DocumentPreviewView] Loading image from: \(localURL.path)")
                if let image = UIImage(contentsOfFile: localURL.path) {
                    print("✅ [DocumentPreviewView] Image loaded successfully, size: \(image.size)")
                    imageToDisplay = image
                    showImagePreview = true
                } else {
                    print("🚫 [DocumentPreviewView] Failed to load image from: \(localURL.path)")
                }
            } else if isVideo {
                // Setup video player
                print("📄 [DocumentPreviewView] Setting up video player from: \(localURL.path)")
                videoPlayer = AVPlayer(url: localURL)
                showVideoPlayer = true
            } else {
                // Document - will show done button
                print("📄 [DocumentPreviewView] Document type, showing done button")
                showImagePreview = false
                showVideoPlayer = false
            }
        } else {
            print("🚫 [DocumentPreviewView] File not found locally, showing download controls")
            isDownloaded = false
        }
    }
    
    // Download file
    private func downloadFile() {
        guard let downloadUrl = downloadUrl, !downloadUrl.isEmpty else {
            print("🚫 [DocumentPreviewView] No download URL available")
            return
        }
        
        guard !fileName.isEmpty else {
            print("🚫 [DOWNLOAD] No fileName available")
            return
        }
        
        let docsDir = getLocalDocumentsDirectory()
        let destinationFile = docsDir.appendingPathComponent(fileName)
        
        // Check if file already exists
        if FileManager.default.fileExists(atPath: destinationFile.path) {
            // File already exists, mark as downloaded
            isDownloaded = true
            checkFileAndDisplay()
            return
        }
        
        // Check if already downloading
        if BackgroundDownloadManager.shared.isDownloading(fileName: fileName) {
            print("📱 [DOWNLOAD] Already downloading: \(fileName)")
            return
        }
        
        // Light haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Update UI: show progress
        isDownloading = true
        
        // Use BackgroundDownloadManager for background downloads
        BackgroundDownloadManager.shared.downloadImage(
            imageUrl: downloadUrl,
            fileName: fileName,
            destinationFile: destinationFile,
            onProgress: { progress in
                DispatchQueue.main.async {
                    // Progress is handled by BackgroundDownloadManager
                }
            },
            onSuccess: {
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.isDownloaded = true
                    // Refresh display
                    self.checkFileAndDisplay()
                }
            },
            onFailure: { error in
                DispatchQueue.main.async {
                    self.isDownloading = false
                    print("🚫 [DOWNLOAD] Download failed: \(error.localizedDescription)")
                }
            }
        )
    }
    
    // Open downloaded file with external app
    private func openDownloadedFile() {
        guard let localURL = localFileURL else {
            print("🚫 [DocumentPreviewView] File not found locally")
            return
        }
        
        // Use QLPreviewController for document preview
        let previewController = QLPreviewController()
        previewController.dataSource = PreviewDataSource(fileURL: localURL)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(previewController, animated: true)
        }
    }
    
    // Preview data source for QLPreviewController
    class PreviewDataSource: NSObject, QLPreviewControllerDataSource {
        let fileURL: URL
        
        init(fileURL: URL) {
            self.fileURL = fileURL
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return fileURL as QLPreviewItem
        }
    }
    
    // Save file to gallery
    private func saveFileToGallery() {
        guard let localURL = localFileURL else {
            print("🚫 [DocumentPreviewView] File not found locally")
            return
        }
        
        if isImage {
            if let image = UIImage(contentsOfFile: localURL.path) {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                print("✅ Image saved to gallery")
            }
        } else if isVideo {
            // Save video to Photos library
            PHPhotoLibrary.requestAuthorization { status in
                if status == .authorized {
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: localURL)
                    }, completionHandler: { success, error in
                        DispatchQueue.main.async {
                            if success {
                                print("✅ Video saved successfully")
                            } else {
                                print("🚫 Error saving video: \(error?.localizedDescription ?? "Unknown error")")
                            }
                        }
                    })
                }
            }
        } else {
            // Save document using UIActivityViewController
            let activityVC = UIActivityViewController(activityItems: [localURL], applicationActivities: nil)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(activityVC, animated: true)
            }
        }
    }
}

// MARK: - Sender Image Bunch View (matching Android senderImgBunchLyt)
struct SenderImageBunchView: View {
    let selectionBunch: [SelectionBunchModel]
    let selectionCount: String
    let backgroundColor: Color
    let onLongPress: (() -> Void)? // Callback for long press gesture
    let onTap: (() -> Void)? // Callback for single tap gesture (to show full-screen preview)
    
    @State private var showDownloadButton: Bool = false
    @State private var isDownloading: Bool = false
    @State private var downloadProgress: Double = 0.0
    @State private var showDownloadProgress: Bool = false
    @State private var progressTimer: Timer? = nil
    
    // Image dimensions based on selectionCount (matching Android)
    private var imageSize: CGFloat {
        return 120 // 120dp
    }
    
    private var fullHeightSize: CGFloat {
        return 241.5 // 241.5dp for full height images
    }
    
    private var cornerRadius: CGFloat {
        return 20 // 20dp corner radius
    }
    
    private var spacing: CGFloat {
        return 1.5 // 1.5dp spacing between images
    }
    
    var body: some View {
        ZStack {
            // Main grid layout (matching Android LinearLayout horizontal)
            HStack(spacing: spacing) {
                // Left column (matching Android vertical LinearLayout)
                VStack(spacing: spacing) {
                    // img1 - Top left (always visible)
                    BunchImageView(
                        imageUrl: selectionBunch[0].imgUrl,
                        fileName: selectionBunch[0].fileName,
                        width: imageSize,
                        height: selectionCount == "2" || selectionCount == "3" ? fullHeightSize : imageSize,
                        corners: (Int(selectionCount) ?? 0) >= 4 ? .topLeft : [.topLeft, .bottomLeft],
                        cornerRadius: cornerRadius
                    )
                    
                    // img2 - Bottom left (for selectionCount >= "4" or selectionBunch.count >= 4)
                    // Android: img2 uses selectionBunch[3] for count=4 and 5+
                    if (Int(selectionCount) ?? 0) >= 4 && selectionBunch.count > 3 {
                        BunchImageView(
                            imageUrl: selectionBunch[3].imgUrl,
                            fileName: selectionBunch[3].fileName,
                            width: imageSize,
                            height: imageSize,
                            corners: .bottomLeft,
                            cornerRadius: cornerRadius
                        )
                    }
                }
                
                // Right column (matching Android vertical LinearLayout)
                VStack(spacing: spacing) {
                    // img3 - Top right (always visible)
                    // Android: img3 uses selectionBunch[1]
                    // For selectionCount == "2", img3 should be full height (stretched) like img1
                    BunchImageView(
                        imageUrl: selectionBunch[1].imgUrl,
                        fileName: selectionBunch[1].fileName,
                        width: imageSize,
                        height: selectionCount == "2" ? fullHeightSize : imageSize,
                        corners: selectionCount == "2" ? [.topRight, .bottomRight] : .topRight,
                        cornerRadius: cornerRadius
                    )
                    
                    // img4 - Bottom right (for selectionCount >= "3" or selectionBunch.count >= 3)
                    // Android: img4 uses selectionBunch[2] for count=3, 4, and 5+
                    if (Int(selectionCount) ?? 0) >= 3 && selectionBunch.count > 2 {
                        ZStack {
                            BunchImageView(
                                imageUrl: selectionBunch[2].imgUrl,
                                fileName: selectionBunch[2].fileName,
                                width: imageSize,
                                height: imageSize,
                                corners: .bottomRight,
                                cornerRadius: cornerRadius
                            )
                            
                            // Overlay text for +N (if more than 4 images) - matching Android overlayTextImg
                            if selectionBunch.count > 4 {
                                Text("+\(selectionBunch.count - 4)")
                                    .font(.custom("Inter18pt-Regular", size: 15))
                                    .foregroundColor(Color(hex: "#e7ebf4"))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(Color.black.opacity(0.5))
                                    .cornerRadius(cornerRadius, corners: .bottomRight)
                            }
                        }
                    }
                }
            }
            
            // Download button overlay (matching Android downlaodImgBunch FloatingActionButton)
            // Centered on the bunch layout (matching Android layout_centerInParent="true")
            if showDownloadButton && !isDownloading {
                Button(action: {
                    downloadAllImages()
                }) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 35, height: 35)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                        
                        Image("downloaddown")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundColor(Color(hex: "#e7ebf4"))
                    }
                }
            }
            
            // Download progress overlay (matching Android downloadPercentageImageSenderBunch)
            // Centered on the bunch layout (matching Android layout_centerInParent="true")
            if showDownloadProgress && isDownloading {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                    
                    Text("\(Int(downloadProgress))%")
                        .font(.custom("Inter18pt-Bold", size: 15))
                        .foregroundColor(.white)
                }
            }
        }
        .onTapGesture {
            // Single tap to show full-screen preview (matching Android multiple_show_image_screen)
            onTap?()
        }
        .onAppear {
            checkDownloadState()
            startProgressTimer()
        }
        .onDisappear {
            progressTimer?.invalidate()
            progressTimer = nil
        }
    }
    
    private func checkDownloadState() {
        // Check if all images exist locally
        var allExist = true
        for bunch in selectionBunch {
            if !doesLocalImageExist(fileName: bunch.fileName) {
                allExist = false
                break
            }
        }
        
        if allExist {
            showDownloadButton = false
        } else {
            showDownloadButton = true
        }
    }
    
    private func doesLocalImageExist(fileName: String) -> Bool {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagesDir = documentsPath.appendingPathComponent("Enclosure/Media/Images", isDirectory: true)
        let localURL = imagesDir.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: localURL.path)
    }
    
    private func downloadAllImages() {
        // Get local images directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagesDir = documentsPath.appendingPathComponent("Enclosure/Media/Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true, attributes: nil)
        
        // Filter images that need to be downloaded
        var imagesToDownload: [SelectionBunchModel] = []
        for bunch in selectionBunch {
            if !doesLocalImageExist(fileName: bunch.fileName) && !BackgroundDownloadManager.shared.isDownloading(fileName: bunch.fileName) {
                imagesToDownload.append(bunch)
            }
        }
        
        // If all images already exist or are downloading, return
        if imagesToDownload.isEmpty {
            print("📱 [BUNCH] All images already exist or are downloading")
            return
        }
        
        // Light haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Update UI
        isDownloading = true
        showDownloadButton = false
        showDownloadProgress = true
        downloadProgress = 0.0
        
        // Download each image
        var completedCount = 0
        let totalCount = imagesToDownload.count
        
        for bunch in imagesToDownload {
            let destinationFile = imagesDir.appendingPathComponent(bunch.fileName)
            
            BackgroundDownloadManager.shared.downloadImage(
                imageUrl: bunch.imgUrl,
                fileName: bunch.fileName,
                destinationFile: destinationFile,
                onProgress: { progress in
                    // Update overall progress (average of all downloads)
                    DispatchQueue.main.async {
                        self.updateOverallProgress()
                    }
                },
                onSuccess: {
                    completedCount += 1
                    print("✅ [BUNCH] Image downloaded: \(bunch.fileName) (\(completedCount)/\(totalCount))")
                    
                    // Check if all downloads are complete
                    DispatchQueue.main.async {
                        if completedCount >= totalCount {
                            self.isDownloading = false
                            self.showDownloadProgress = false
                            self.showDownloadButton = false
                            self.downloadProgress = 0.0
                            self.checkDownloadState()
                        } else {
                            self.updateOverallProgress()
                        }
                    }
                },
                onFailure: { error in
                    completedCount += 1
                    print("🚫 [BUNCH] Download failed: \(bunch.fileName) - \(error.localizedDescription)")
                    
                    // Check if all downloads are complete (even if some failed)
                    DispatchQueue.main.async {
                        if completedCount >= totalCount {
                            self.isDownloading = false
                            self.showDownloadProgress = false
                            self.checkDownloadState()
                        } else {
                            self.updateOverallProgress()
                        }
                    }
                }
            )
        }
    }
    
    private func updateOverallProgress() {
        // Calculate average progress across all images in the bunch
        var totalProgress: Double = 0.0
        var activeDownloads: Int = 0
        
        for bunch in selectionBunch {
            if let progress = BackgroundDownloadManager.shared.getProgress(fileName: bunch.fileName) {
                totalProgress += progress
                activeDownloads += 1
            } else if BackgroundDownloadManager.shared.isDownloading(fileName: bunch.fileName) {
                // Download started but no progress yet
                activeDownloads += 1
            }
        }
        
        if activeDownloads > 0 {
            downloadProgress = totalProgress / Double(activeDownloads)
            isDownloading = true
            showDownloadProgress = true
            showDownloadButton = false
        } else {
            // Check if all downloads completed
            var allExist = true
            for bunch in selectionBunch {
                if !doesLocalImageExist(fileName: bunch.fileName) {
                    allExist = false
                    break
                }
            }
            
            if allExist {
                isDownloading = false
                showDownloadProgress = false
                showDownloadButton = false
            } else {
                isDownloading = false
                showDownloadProgress = false
                showDownloadButton = true
            }
        }
    }
    
    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            updateOverallProgress()
        }
    }
}

// MARK: - Receiver Image Bunch View (matching Android recImgBunchLyt)
struct ReceiverImageBunchView: View {
    let selectionBunch: [SelectionBunchModel]
    let selectionCount: String
    let onLongPress: (() -> Void)? // Callback for long press gesture
    let onTap: (() -> Void)? // Callback for single tap gesture (to show full-screen preview)
    
    @State private var showDownloadButton: Bool = false
    @State private var isDownloading: Bool = false
    @State private var downloadProgress: Double = 0.0
    @State private var showDownloadProgress: Bool = false
    @State private var progressTimer: Timer? = nil
    
    // Image dimensions based on selectionCount (matching Android)
    private var imageSize: CGFloat {
        return 120 // 120dp
    }
    
    private var fullHeightSize: CGFloat {
        return 241.5 // 241.5dp for full height images
    }
    
    private var cornerRadius: CGFloat {
        return 20 // 20dp corner radius
    }
    
    private var spacing: CGFloat {
        return 1.5 // 1.5dp spacing between images
    }
    
    var body: some View {
        ZStack {
            // Main grid layout (matching Android LinearLayout horizontal)
            HStack(spacing: spacing) {
                // Left column (matching Android vertical LinearLayout)
                VStack(spacing: spacing) {
                    // img1 - Top left (always visible)
                    BunchImageView(
                        imageUrl: selectionBunch[0].imgUrl,
                        fileName: selectionBunch[0].fileName,
                        width: imageSize,
                        height: selectionCount == "2" || selectionCount == "3" ? fullHeightSize : imageSize,
                        corners: (Int(selectionCount) ?? 0) >= 4 ? .topLeft : [.topLeft, .bottomLeft],
                        cornerRadius: cornerRadius
                    )
                    
                    // img2 - Bottom left (for selectionCount >= "4" or selectionBunch.count >= 4)
                    // Android: img2 uses selectionBunch[3] for count=4 and 5+
                    if (Int(selectionCount) ?? 0) >= 4 && selectionBunch.count > 3 {
                        BunchImageView(
                            imageUrl: selectionBunch[3].imgUrl,
                            fileName: selectionBunch[3].fileName,
                            width: imageSize,
                            height: imageSize,
                            corners: .bottomLeft,
                            cornerRadius: cornerRadius
                        )
                    }
                }
                
                // Right column (matching Android vertical LinearLayout)
                VStack(spacing: spacing) {
                    // img3 - Top right (always visible)
                    // Android: img3 uses selectionBunch[1]
                    // For selectionCount == "2", img3 should be full height (stretched) like img1
                    BunchImageView(
                        imageUrl: selectionBunch[1].imgUrl,
                        fileName: selectionBunch[1].fileName,
                        width: imageSize,
                        height: selectionCount == "2" ? fullHeightSize : imageSize,
                        corners: selectionCount == "2" ? [.topRight, .bottomRight] : .topRight,
                        cornerRadius: cornerRadius
                    )
                    
                    // img4 - Bottom right (for selectionCount >= "3" or selectionBunch.count >= 3)
                    // Android: img4 uses selectionBunch[2] for count=3, 4, and 5+
                    if (Int(selectionCount) ?? 0) >= 3 && selectionBunch.count > 2 {
                        ZStack {
                            BunchImageView(
                                imageUrl: selectionBunch[2].imgUrl,
                                fileName: selectionBunch[2].fileName,
                                width: imageSize,
                                height: imageSize,
                                corners: .bottomRight,
                                cornerRadius: cornerRadius
                            )
                            
                            // Overlay text for +N (if more than 4 images) - matching Android overlayTextImg
                            if selectionBunch.count > 4 {
                                Text("+\(selectionBunch.count - 4)")
                                    .font(.custom("Inter18pt-Regular", size: 15))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(Color.black.opacity(0.5))
                                    .cornerRadius(cornerRadius, corners: .bottomRight)
                            }
                        }
                    }
                }
            }
            
            // Download button overlay (matching Android downlaodImgBunch FloatingActionButton)
            // Centered on the bunch layout (matching Android layout_centerInParent="true")
            if showDownloadButton && !isDownloading {
                Button(action: {
                    downloadAllImages()
                }) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 35, height: 35)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                        
                        Image("downloaddown")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.white)
                    }
                }
            }
            
            // Download progress overlay (matching Android downloadPercentageImageSenderBunch)
            // Centered on the bunch layout (matching Android layout_centerInParent="true")
            if showDownloadProgress && isDownloading {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                    
                    Text("\(Int(downloadProgress))%")
                        .font(.custom("Inter18pt-Bold", size: 15))
                        .foregroundColor(.white)
                }
            }
        }
        .onTapGesture {
            // Single tap to show full-screen preview (matching Android multiple_show_image_screen)
            onTap?()
        }
        .onAppear {
            checkDownloadState()
            startProgressTimer()
        }
        .onDisappear {
            progressTimer?.invalidate()
            progressTimer = nil
        }
    }
    
    private func checkDownloadState() {
        // Check if all images exist in Photos library
        var allExist = true
        for bunch in selectionBunch {
            if !PhotosLibraryHelper.shared.imageExistsInPhotosLibrary(fileName: bunch.fileName) {
                allExist = false
                break
            }
        }
        
        if allExist {
            showDownloadButton = false
        } else {
            showDownloadButton = true
        }
    }
    
    private func downloadAllImages() {
        // Filter images that need to be downloaded
        var imagesToDownload: [SelectionBunchModel] = []
        for bunch in selectionBunch {
            let downloadKey = "photos_\(bunch.fileName)"
            if !PhotosLibraryHelper.shared.imageExistsInPhotosLibrary(fileName: bunch.fileName) &&
               !BackgroundDownloadManager.shared.isDownloadingWithKey(key: downloadKey) {
                imagesToDownload.append(bunch)
            }
        }
        
        // If all images already exist or are downloading, return
        if imagesToDownload.isEmpty {
            print("📱 [BUNCH] All images already exist or are downloading")
            return
        }
        
        // Light haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Update UI
        isDownloading = true
        showDownloadButton = false
        showDownloadProgress = true
        downloadProgress = 0.0
        
        // Download each image to Photos library
        var completedCount = 0
        let totalCount = imagesToDownload.count
        
        for bunch in imagesToDownload {
            BackgroundDownloadManager.shared.downloadImageToPhotosLibrary(
                imageUrl: bunch.imgUrl,
                fileName: bunch.fileName,
                onProgress: { progress in
                    // Update overall progress (average of all downloads)
                    DispatchQueue.main.async {
                        self.updateOverallProgress()
                    }
                },
                onSuccess: {
                    completedCount += 1
                    print("✅ [BUNCH] Image downloaded to Photos: \(bunch.fileName) (\(completedCount)/\(totalCount))")
                    
                    // Check if all downloads are complete
                    DispatchQueue.main.async {
                        if completedCount >= totalCount {
                            self.isDownloading = false
                            self.showDownloadProgress = false
                            self.showDownloadButton = false
                            self.downloadProgress = 0.0
                            self.checkDownloadState()
                        } else {
                            self.updateOverallProgress()
                        }
                    }
                },
                onFailure: { error in
                    completedCount += 1
                    print("🚫 [BUNCH] Download failed: \(bunch.fileName) - \(error.localizedDescription)")
                    
                    // Check if all downloads are complete (even if some failed)
                    DispatchQueue.main.async {
                        if completedCount >= totalCount {
                            self.isDownloading = false
                            self.showDownloadProgress = false
                            self.checkDownloadState()
                        } else {
                            self.updateOverallProgress()
                        }
                    }
                }
            )
        }
    }
    
    private func updateOverallProgress() {
        // Calculate average progress across all images in the bunch
        var totalProgress: Double = 0.0
        var activeDownloads: Int = 0
        
        for bunch in selectionBunch {
            let downloadKey = "photos_\(bunch.fileName)"
            if let progress = BackgroundDownloadManager.shared.getProgressWithKey(key: downloadKey) {
                totalProgress += progress
                activeDownloads += 1
            } else if BackgroundDownloadManager.shared.isDownloadingWithKey(key: downloadKey) {
                // Download started but no progress yet
                activeDownloads += 1
            }
        }
        
        if activeDownloads > 0 {
            downloadProgress = totalProgress / Double(activeDownloads)
            isDownloading = true
            showDownloadProgress = true
            showDownloadButton = false
        } else {
            // Check if all downloads completed
            var allExist = true
            for bunch in selectionBunch {
                if !PhotosLibraryHelper.shared.imageExistsInPhotosLibrary(fileName: bunch.fileName) {
                    allExist = false
                    break
                }
            }
            
            if allExist {
                isDownloading = false
                showDownloadProgress = false
                showDownloadButton = false
            } else {
                isDownloading = false
                showDownloadProgress = false
                showDownloadButton = true
            }
        }
    }
    
    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            updateOverallProgress()
        }
    }
}

// MARK: - Bunch Image View (individual image in bunch with rounded corners)
struct BunchImageView: View {
    let imageUrl: String
    let fileName: String
    let width: CGFloat
    let height: CGFloat
    let corners: UIRectCorner
    let cornerRadius: CGFloat
    
    private var localImagesDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("Enclosure/Media/Images", isDirectory: true)
    }
    
    private func localURLIfExists(_ url: URL?) -> URL? {
        guard let url = url else { return nil }
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    
    private var localURLFromFileName: URL? {
        guard !fileName.isEmpty else { return nil }
        return localURLIfExists(localImagesDirectory.appendingPathComponent(fileName))
    }
    
    private var localURLFromImageUrl: URL? {
        guard !imageUrl.isEmpty else { return nil }
        
        if imageUrl.hasPrefix("file://"), let url = URL(string: imageUrl) {
            return localURLIfExists(url)
        }
        
        if imageUrl.hasPrefix("/") {
            return localURLIfExists(URL(fileURLWithPath: imageUrl))
        }
        
        if let url = URL(string: imageUrl), url.isFileURL {
            return localURLIfExists(url)
        }
        
        if let url = URL(string: imageUrl), !url.lastPathComponent.isEmpty {
            return localURLIfExists(localImagesDirectory.appendingPathComponent(url.lastPathComponent))
        }
        
        return nil
    }
    
    // Get image source URL (local first, then online)
    private var sourceURL: URL? {
        if let localURL = localURLFromFileName ?? localURLFromImageUrl {
            return localURL
        }
        
        if let url = URL(string: imageUrl), !imageUrl.isEmpty {
            return url
        }
        
        return nil
    }
    
    var body: some View {
        let topLeft = corners.contains(.topLeft) ? cornerRadius : 0
        let topRight = corners.contains(.topRight) ? cornerRadius : 0
        let bottomLeft = corners.contains(.bottomLeft) ? cornerRadius : 0
        let bottomRight = corners.contains(.bottomRight) ? cornerRadius : 0
        
        Group {
            if let url = sourceURL {
                CachedAsyncImage(
                    url: url,
                    content: { image in
                        ZStack {
                            Color.black
                            image
                                .resizable()
                                .scaledToFill()
                        }
                    },
                    placeholder: {
                        ZStack {
                            Color.black
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                    }
                )
            } else {
                ZStack {
                    Color.black
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }
        }
        .frame(width: width, height: height)
        .clipShape(
            UnevenRoundedRectangle(
                cornerRadii: .init(
                    topLeading: topLeft,
                    bottomLeading: bottomLeft,
                    bottomTrailing: bottomRight,
                    topTrailing: topRight
                )
            )
        )
    }
}

// MARK: - Reply View (matching Android replylyoutGlobal)
struct ReplyView: View {
    let message: ChatMessage
    let isSentByMe: Bool
    let onTap: (() -> Void)?
    @Environment(\.colorScheme) private var colorScheme
    
    init(message: ChatMessage, isSentByMe: Bool, onTap: (() -> Void)? = nil) {
        self.message = message
        self.isSentByMe = isSentByMe
        self.onTap = onTap
    }
    
    var body: some View {
        // Main vertical container matching Android replylyoutGlobal (150dp width, wrap_content height)
        // Everything is inside one vertical container with theme color background for sender
        VStack(spacing: 0) {
            // Upper container - Reply preview section (matching Android replyTheme area)
            // Android has 2 layers: replyTheme (blue) and inner layer (circlebtnhover)
            ZStack(alignment: .topLeading) {
                // Layer 1: replyTheme - Blue background layer (matching Android replyTheme)
                // android:layout_marginVertical="1dp", backgroundTint="@color/blue"
                // message_box_bg_3 has rounded corners only on top (20dp topLeft/topRight, 0dp bottom)
                UnevenRoundedRectangle(
                    cornerRadii: .init(topLeading: 20, bottomLeading: 0, bottomTrailing: 0, topTrailing: 20)
                )
                .fill(Color(hex: Constant.themeColor))
                    .frame(width: 150, height: 50) // 150dp height
                    .padding(.vertical, 1) // marginVertical="1dp"
                
                // Layer 2: Inner content layer (matching Android second LinearLayout)
                // android:layout_marginStart="1dp" marginTop="1dp" marginEnd="1dp"
                // android:backgroundTint="@color/circlebtnhover" (chattingMessageBox color)
                // This layer sits inside Layer 1 with 1dp margins
                UnevenRoundedRectangle(
                    cornerRadii: .init(topLeading: 20, bottomLeading: 0, bottomTrailing: 0, topTrailing: 20)
                )
                .fill(Color("chattingMessageBox")) // circlebtnhover = chattingMessageBox
                    .frame(width: 148, height: 50) // 150 - 1dp start - 1dp end = 148
                    .offset(x: 1, y: 1) // marginStart="1dp" marginTop="1dp"
                    .overlay(
                            // Content
                            HStack(spacing: 0) {
                                // Left side - text content (matching Android LinearLayout with marginHorizontal="10dp")
                                VStack(alignment: .leading, spacing: 2) {
                                    // "You" text (matching Android replyYou)
                                    Text("You")
                                        .font(.custom("Inter18pt-Regular", size: 15))
                                        .fontWeight(.black) // textFontWeight="1000"
                                        .foregroundColor(Color(hex: Constant.themeColor)) // textColor="@color/blue"
                                    
                                    // Reply preview text (matching Android msgreplyText)
                                    if let replyOldData = message.replyOldData, !replyOldData.isEmpty {
                                        Text(replyOldData)
                                            .font(.custom("Inter18pt-Regular", size: 14))
                                            .foregroundColor(Color(hex: "#78787A")) // textColor="#78787A"
                                            .lineLimit(1)
                                    }
                                }
                                .padding(.horizontal, 10) // marginHorizontal="10dp"
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Right side - thumbnails/icons (matching Android right side layout)
                                HStack(spacing: 12) {
                                    // Image/Video thumbnail (matching Android imgcardview - 35dp)
                                    // Show when replyType is Text and there's an image/video to display
                                    if let replyType = message.replyType, replyType == Constant.Text {
                                        // Check if replyOldData contains a URL (starts with http) or is preview text
                                        if let replyOldData = message.replyOldData, !replyOldData.isEmpty {
                                            // If replyOldData is a URL, use it directly (matching Android model.getReplyOldData())
                                            // Otherwise, check if it's "Photo" or "Video" and use document/thumbnail
                                            let imageUrl: String? = {
                                                if replyOldData.hasPrefix("http://") || replyOldData.hasPrefix("https://") {
                                                    return replyOldData
                                                } else if replyOldData == "Photo" || replyOldData == "Video" {
                                                    // For Photo, use document; for Video, use thumbnail or document
                                                    return replyOldData == "Photo" ? message.document : (message.thumbnail ?? message.document)
                                                } else {
                                                    // Try document or thumbnail as fallback
                                                    return !message.document.isEmpty ? message.document : message.thumbnail
                                                }
                                            }()
                                            
                                            if let url = imageUrl, !url.isEmpty {
                                                AsyncImage(url: URL(string: url)) { phase in
                                                    switch phase {
                                                    case .success(let image):
                                                        image
                                                            .resizable()
                                                            .scaledToFill()
                                                    case .failure(_), .empty:
                                                        Color.gray.opacity(0.3)
                                                    @unknown default:
                                                        Color.gray.opacity(0.3)
                                                    }
                                                }
                                                .frame(width: 35, height: 35)
                                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                            }
                                        }
                                    }
                                    
                                    // Contact container (matching Android contactContainerReply - 35dp)
                                    // Show when original message was a contact (check replyType or dataType)
                                    if message.dataType == Constant.contact || message.replyType == Constant.contact {
                                        ZStack {
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [
                                                            Color(hex: Constant.themeColor).opacity(0.8),
                                                            Color(hex: Constant.themeColor).opacity(0.6)
                                                        ]),
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 35, height: 35)
                                            
                                            // First letter of contact name
                                            Text((message.name?.prefix(1) ?? "A").uppercased())
                                                .font(.custom("Inter18pt-Regular", size: 14))
                                                .foregroundColor(.black)
                                        }
                                    }
                                    
                                    // Document/PDF icon (matching Android pageLyt - 26dp)
                                    // Show when original message was a document
                                    if message.dataType == Constant.doc || message.replyType == Constant.doc {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color("TextColor"))
                                                .frame(width: 26, height: 26)
                                            
                                            Text((message.fileExtension ?? "PDF").uppercased().prefix(4))
                                                .font(.custom("Inter18pt-Bold", size: 7.5))
                                                .foregroundColor(Color("BackgroundColor"))
                                                .lineLimit(1)
                                        }
                                    }
                                    
                                    // Music icon (matching Android musicReply - 20dp)
                                    // Show when original message was voice audio
                                    if message.dataType == Constant.voiceAudio || message.replyType == Constant.voiceAudio {
                                        Image(systemName: "music.note")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                            .foregroundColor(Color("TextColor"))
                                    }
                                }
                                .padding(.trailing, 12) // marginEnd="12dp"
                            }
                            .padding(.vertical, 5) // marginVertical="5dp"
                        )
            }
            .frame(width: 150, height: 50)
            
            // Lower container - Reply text section (matching Android replydatalyt)
            // Show reply text below the upper part, inside the same vertical container
            if let replytextData = message.replytextData, !replytextData.isEmpty {
                HStack(spacing: 5) {
                    // Reply text (matching Android repliedData)
                    // Android: maxWidth="220dp", textColor="#e7ebf4", textSize="15sp"
                    Text(replytextData)
                        .font(.custom("Inter18pt-Regular", size: 15))
                        .foregroundColor(isSentByMe ? Color(hex: "#e7ebf4") : Color("TextColor"))
                        .fixedSize(horizontal: false, vertical: true) // Allow text to wrap and expand vertically
                        .frame(maxWidth: 220) // maxWidth="220dp"
                        .padding(.horizontal, 12) // marginHorizontal="12dp"
                        .padding(.top, 2) // marginTop="2dp"
                        .padding(.bottom, 4.5) // marginBottom="4.5dp"
                }
                .frame(width: 150, alignment: .leading) // Match container width
                .overlay(
                    // Border only on left, right, and bottom (not top) for receiver side
                    // With 20dp corner radius at bottom corners
                    Group {
                        if !isSentByMe {
                            GeometryReader { geometry in
                                let width = geometry.size.width
                                let height = geometry.size.height
                                let cornerRadius: CGFloat = 20
                                let borderWidth: CGFloat = 0.5
                                
                                // Draw box border with 20dp corner radius at bottom corners only
                                // Use RoundedCorner shape with bottom corners rounded, then mask top border
                                UnevenRoundedRectangle(
                                    cornerRadii: .init(
                                        topLeading: 0,
                                        bottomLeading: cornerRadius,
                                        bottomTrailing: cornerRadius,
                                        topTrailing: 0
                                    )
                                )
                                .stroke(getGlassBorder(), lineWidth: borderWidth)
                                    .frame(width: width, height: height)
                                    .mask(
                                        // Mask to hide top border - show everything except top edge
                                        Rectangle()
                                            .frame(width: width, height: height + borderWidth)
                                            .offset(y: borderWidth / 2)
                                    )
                            }
                        }
                    }
                )
            }
        }
        .frame(width: 150) // Main container width
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
        .background(
            Group {
                if isSentByMe {
                    // Sender: theme-based color (matching senderMessageBackgroundColor logic)
                    RoundedRectangle(cornerRadius: 20)
                        .fill(getReplyContainerBackgroundColor())
                } else {
                    // Receiver: glassmorphism background (matching modern_glass_background_receiver.xml)
                    // Linear gradient at 135 degrees with glass colors
                    // Border is applied only to reply text area (left, right, bottom), not entire container
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    getGlassBgStart(),
                                    getGlassBgCenter(),
                                    getGlassBgEnd()
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
        )
        .onTapGesture {
            // Handle tap on reply view (matching Android onClick for replyKey)
            if let replyKey = message.replyKey, replyKey == "ReplyKey" {
                onTap?()
            }
        }
    }
    
    // Get reply container background color (matching senderMessageBackgroundColor logic)
    private func getReplyContainerBackgroundColor() -> Color {
        // Light mode: always use legacy bubble color (#011224) to match Android light theme
        guard colorScheme == .dark else {
            return Color(hex: "#011224")
        }
        
        // Dark mode: use theme-based tinted backgrounds (matching Android)
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
    
    // Get glass background start color (matching Android glass_bg_start)
    private func getGlassBgStart() -> Color {
        // Light mode: #80FFFFFF (50% opacity white)
        // Dark mode: #4D1B1B1B (semi-transparent dark)
        return colorScheme == .dark ? Color(hex: "#4D1B1B1B") : Color(hex: "#80FFFFFF")
    }
    
    // Get glass background center color (matching Android glass_bg_center)
    private func getGlassBgCenter() -> Color {
        // Light mode: #66FFFFFF (40% opacity white)
        // Dark mode: #331B1B1B (more transparent)
        return colorScheme == .dark ? Color(hex: "#331B1B1B") : Color(hex: "#66FFFFFF")
    }
    
    // Get glass background end color (matching Android glass_bg_end)
    private func getGlassBgEnd() -> Color {
        // Light mode: #4DFFFFFF (30% opacity white)
        // Dark mode: #1A1B1B1B (even more transparent)
        return colorScheme == .dark ? Color(hex: "#1A1B1B1B") : Color(hex: "#4DFFFFFF")
    }
    
    // Get glass border color (matching Android glass_border)
    private func getGlassBorder() -> Color {
        // Light mode: #80000000 (50% opacity black)
        // Dark mode: #40FFFFFF (25% opacity white) - matching Android values-night/colors.xml
        return colorScheme == .dark ? Color(hex: "#40FFFFFF") : Color(hex: "#80000000")
    }
}

// MARK: - Character Extension for Emoji Detection
extension Character {
    var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmoji && (scalar.value > 0x238C || unicodeScalars.count > 1)
    }
}

// MARK: - Emoji Analysis Helper Functions (matching Android analyzeTextContent and countEmojis)
private func analyzeTextContent(_ content: String) -> String {
    // Remove whitespace and check if content is empty
    let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        return "only_text"
    }
    
    // Check if content contains only emojis
    var hasOnlyEmojis = true
    var hasText = false
    
    for scalar in trimmed.unicodeScalars {
        if CharacterSet.whitespacesAndNewlines.contains(scalar) {
            continue // Skip whitespace
        }
        
        // Check if character is an emoji
        // Emojis are typically in these ranges:
        // - 0x1F300-0x1F9FF (Misc Symbols and Pictographs)
        // - 0x2600-0x26FF (Misc symbols)
        // - 0x2700-0x27BF (Dingbats)
        // - 0xFE00-0xFE0F (Variation Selectors)
        // - 0x1F900-0x1F9FF (Supplemental Symbols and Pictographs)
        // - 0x1F1E0-0x1F1FF (Regional Indicator Symbols - flags)
        // - 0x200D (Zero Width Joiner)
        // - 0x20E3 (Combining Enclosing Keycap)
        // - 0xFE0F (Variation Selector-16)
        let codePoint = scalar.value
        let isEmoji = (codePoint >= 0x1F300 && codePoint <= 0x1F9FF) ||
                     (codePoint >= 0x2600 && codePoint <= 0x26FF) ||
                     (codePoint >= 0x2700 && codePoint <= 0x27BF) ||
                     (codePoint >= 0xFE00 && codePoint <= 0xFE0F) ||
                     (codePoint >= 0x1F900 && codePoint <= 0x1F9FF) ||
                     (codePoint >= 0x1F1E0 && codePoint <= 0x1F1FF) ||
                     codePoint == 0x200D ||
                     codePoint == 0x20E3 ||
                     codePoint == 0xFE0F ||
                     (codePoint >= 0x1FA00 && codePoint <= 0x1FAFF) // Extended emoji range
        
        if !isEmoji {
            hasOnlyEmojis = false
            hasText = true
            break
        }
    }
    
    if hasOnlyEmojis && !hasText {
        return "only_emoji"
    } else if hasText {
        // Check if there are any emojis mixed with text
        let emojiPattern = #"[^\x00-\x7F]"# // Non-ASCII characters (simplified emoji detection)
        if trimmed.range(of: emojiPattern, options: .regularExpression) != nil {
            return "text_and_emoji"
        }
        return "only_text"
    }
    
    return "only_text"
}

private func countEmojis(_ content: String) -> Int {
    let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        return 0
    }
    
    // Use Character's emoji detection which handles complex sequences better
    var emojiCount = 0
    var currentIndex = trimmed.startIndex
    
    while currentIndex < trimmed.endIndex {
        let char = trimmed[currentIndex]
        
        // Skip whitespace
        if char.isWhitespace || char.isNewline {
            currentIndex = trimmed.index(after: currentIndex)
            continue
        }
        
        // Check if character is an emoji using Swift's built-in emoji detection
        // This handles complex emoji sequences (flags, skin tones, ZWJ sequences) correctly
        if char.isEmoji {
            emojiCount += 1
            
            // Move to the end of this emoji sequence
            // Swift's Character already handles multi-scalar emojis, but we need to skip continuation characters
            var nextIndex = trimmed.index(after: currentIndex)
            
            // Skip over variation selectors and zero-width joiners that are part of the emoji
            while nextIndex < trimmed.endIndex {
                let nextChar = trimmed[nextIndex]
                
                // Check if this is a continuation character (variation selector, ZWJ, etc.)
                let scalar = nextChar.unicodeScalars.first
                if let scalar = scalar {
                    let codePoint = scalar.value
                    if codePoint == 0xFE0F || // Variation Selector-16
                       codePoint == 0xFE00 || // Variation Selector-1
                       (codePoint >= 0xFE01 && codePoint <= 0xFE0F) || // Variation Selectors
                       codePoint == 0x200D || // Zero Width Joiner
                       codePoint == 0x20E3 { // Combining Enclosing Keycap
                        nextIndex = trimmed.index(after: nextIndex)
                        continue
                    }
                }
                
                // If next character is also an emoji, it might be part of a sequence (like flags)
                if nextChar.isEmoji {
                    // Check if it's a regional indicator (flag) or part of a ZWJ sequence
                    let nextScalar = nextChar.unicodeScalars.first
                    if let nextScalar = nextScalar {
                        let nextCodePoint = nextScalar.value
                        if (nextCodePoint >= 0x1F1E6 && nextCodePoint <= 0x1F1FF) { // Regional Indicator Symbols
                            // This is part of a flag sequence, continue
                            nextIndex = trimmed.index(after: nextIndex)
                            continue
                        }
                    }
                }
                
                // Not part of emoji sequence, break
                break
            }
            
            currentIndex = nextIndex
        } else {
            // Not an emoji, move to next character
            currentIndex = trimmed.index(after: currentIndex)
        }
    }
    
    return emojiCount
}

// MARK: - Message Bubble View (matching Android sample_sender.xml)
struct MessageBubbleView: View {
    let message: ChatMessage
    let isSentByMe: Bool
    let onHalfSwipe: (ChatMessage) -> Void
    let onReplyTap: ((ChatMessage) -> Void)?
    let onLongPress: ((ChatMessage, CGPoint) -> Void)?
    let onEmojiCardTap: ((ChatMessage) -> Void)?
    let onBunchLongPress: (([SelectionBunchModel]) -> Void)? // Callback for bunch image long press
    let onImageTap: ((SelectionBunchModel) -> Void)? // Callback for single image tap to open ShowImageScreen
    let isHighlighted: Bool
    let isMultiSelectMode: Bool
    let isSelected: Bool
    let onSelectionToggle: ((String) -> Void)?
    let onReceiverPendingComplete: ((ChatMessage) -> Void)?
    let isLastMessage: Bool
    @GestureState private var dragTranslation: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var viewFrame: CGRect = .zero
    @State private var receiverProgressCompleted: Bool = false
    private let halfSwipeThreshold: CGFloat = 60
    @Environment(\.colorScheme) private var colorScheme
    
    init(message: ChatMessage, onHalfSwipe: @escaping (ChatMessage) -> Void = { _ in }, onReplyTap: ((ChatMessage) -> Void)? = nil, onLongPress: ((ChatMessage, CGPoint) -> Void)? = nil, onEmojiCardTap: ((ChatMessage) -> Void)? = nil, onBunchLongPress: (([SelectionBunchModel]) -> Void)? = nil, onImageTap: ((SelectionBunchModel) -> Void)? = nil, isHighlighted: Bool = false, isMultiSelectMode: Bool = false, isSelected: Bool = false, onSelectionToggle: ((String) -> Void)? = nil, onReceiverPendingComplete: ((ChatMessage) -> Void)? = nil, isLastMessage: Bool = false) {
        self.message = message
        self.isSentByMe = message.uid == Constant.SenderIdMy
        self.onBunchLongPress = onBunchLongPress
        self.onImageTap = onImageTap
        self.onHalfSwipe = onHalfSwipe
        self.onReplyTap = onReplyTap
        self.onLongPress = onLongPress
        self.onEmojiCardTap = onEmojiCardTap
        self.isHighlighted = isHighlighted
        self.isMultiSelectMode = isMultiSelectMode
        self.isSelected = isSelected
        self.onSelectionToggle = onSelectionToggle
        self.onReceiverPendingComplete = onReceiverPendingComplete
        self.isLastMessage = isLastMessage
    }
    
    var body: some View {
        HStack(spacing: 0) {
            if isSentByMe {
                Spacer()
            }
            
            VStack(alignment: isSentByMe ? .trailing : .leading, spacing: 0) {
                // Hide reply layout for typing indicator (matching Android behavior)
                if message.dataType != Constant.TYPEINDICATOR {
                replyLayoutView
                }
                
                // Forwarded indicator and message bubble in horizontal layout (matching Android sendLinear/recLinear)
                // In Android: horizontal LinearLayout contains selectionCheckbox, forwarded TextView, and MainSenderBox/MainReceiverBox
                // For sender: checkbox → forwarded → message bubble
                // For receiver: message bubble → forwarded → checkbox
                // Hide forwarded indicator and checkboxes for typing indicator (matching Android behavior)
                if message.dataType != Constant.TYPEINDICATOR {
                HStack(alignment: .center, spacing: 0) {
                    if isSentByMe {
                        Spacer()
                    }
                    
                    // Checkbox for sender (FIRST in horizontal layout, matching Android sample_sender.xml)
                    // android:layout_marginStart="8dp" android:layout_marginEnd="8dp"
                    if isMultiSelectMode && isSentByMe {
                        Image("multitick")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundColor(isSelected ? Color(hex: Constant.themeColor) : Color("gray3"))
                            .padding(.leading, 8) // android:layout_marginStart="8dp"
                            .padding(.trailing, 8) // android:layout_marginEnd="8dp"
                    }
                    
                    // Forwarded indicator positioning differs for sender vs receiver
                    if let forwaredKey = message.forwaredKey,
                       forwaredKey == "forwordKey" {
                        if isSentByMe {
                            // Sender: forwarded indicator BEFORE message bubble (matching Android sample_sender.xml)
                            // android:layout_marginEnd="20dp"
                            forwardedIndicatorView
                                .padding(.trailing, 20) // android:layout_marginEnd="20dp"
                        }
                    }
                    
                mainMessageContentView
                    
                    // Receiver: forwarded indicator AFTER message bubble (matching Android sample_receiver.xml)
                    // In Android: forwarded TextView comes after MainReceiverBox in the horizontal LinearLayout
                    // Negative offset to bring it as close as possible to message bubble
                    if !isSentByMe,
                       let forwaredKey = message.forwaredKey,
                       forwaredKey == "forwordKey" {
                        receiverForwardedIndicatorView
                            .offset(x: -2) // Negative offset to bring it closer to message bubble
                    }
                    
                    // Checkbox for receiver (AFTER forwarded indicator, matching Android sample_receiver.xml)
                    // Matching Android: selectionCheckbox is in the same horizontal LinearLayout
                    // android:layout_marginStart="8dp" android:layout_marginEnd="8dp"
                    if isMultiSelectMode && !isSentByMe {
                        Image("multitick")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundColor(isSelected ? Color(hex: Constant.themeColor) : Color("gray3"))
                            .padding(.leading, 8) // android:layout_marginStart="8dp"
                            .padding(.trailing, 8) // android:layout_marginEnd="8dp"
                    }
                    
                    if !isSentByMe {
                        Spacer()
                    }
                    }
                } else {
                    // For typing indicator, only show the main message content (typing indicator animation)
                    mainMessageContentView
                }
                
                // Time row and emoji card are at the same level (both layout_below="@id/rl" in Android)
                // Emoji card stays positioned relative to progress bar area
                // Hide time row and emoji card for typing indicator (matching Android behavior)
                if message.dataType != Constant.TYPEINDICATOR {
                ZStack(alignment: .bottom) {
                    // Time row (matching Android sendTime with progress indicator)
                timeRowView
                        .frame(maxWidth: .infinity, alignment: isSentByMe ? .trailing : .leading)
                    // Emoji card (matching Android emojiTextCard) - positioned relative to progress bar
                    emojiReactionsCardView
                        .frame(maxWidth: .infinity, alignment: isSentByMe ? .trailing : .leading)
                    }
                }
            }
            
            if !isSentByMe {
                Spacer()
            }
        }
        .padding(.horizontal, 10) // side margin like Android screen margins
        .padding(.vertical, 5) // vertical spacing 5px
        .background(highlightBackground)
        .contentShape(Rectangle()) // Make entire area tappable
        .onTapGesture {
            // Handle tap in multi-select mode (matching Android)
            if isMultiSelectMode {
                onSelectionToggle?(message.id)
            }
        }
        .background(highlightBackground)
        .contentShape(Rectangle())
        .offset(x: isDragging && dragTranslation.width > 0 ? min(dragTranslation.width, halfSwipeThreshold) : 0)
        .overlay(swipeFeedbackOverlay)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: MessageFramePreferenceKey.self, value: geometry.frame(in: .global))
            }
        )
        .onPreferenceChange(MessageFramePreferenceKey.self) { frame in
            viewFrame = frame // Update synchronously to avoid delays
        }
        .onChange(of: message.id) { _ in
            receiverProgressCompleted = false
        }
        .onChange(of: message.receiverLoader) { newValue in
            if newValue != 0 {
                receiverProgressCompleted = false
            }
        }
        .onChange(of: isLastMessage) { isLast in
            if !isLast {
                receiverProgressCompleted = false
            }
        }
        // Use onLongPressGesture which allows scrolling to take priority
        .onLongPressGesture(minimumDuration: 0.5, maximumDistance: 20) {
            // Prefer swipe-to-reply over long press
            if isDragging || dragTranslation != .zero {
                return
            }
            // Long press detected - trigger callback with exact touch location
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onLongPress?(message, CGPoint(x: viewFrame.midX, y: viewFrame.midY))
        }
        // Only apply swipe gesture if not in multi-select mode to avoid gesture conflicts
        // Use highPriorityGesture for swipe so it doesn't interfere with ScrollView
        .simultaneousGesture(isMultiSelectMode ? nil : swipeGesture)
    }
    
    // MARK: - View Components
    
    // Forwarded indicator view for sender (matching Android sample_sender.xml forwarded TextView)
    // android:id="@+id/forwarded" android:background="@drawable/forward_drawable"
    // android:drawableEnd="@drawable/forward_wrapped" android:drawableTint="@color/blue"
    // android:text="forwarded" android:textSize="8sp"
    // android:paddingStart="8dp" android:paddingEnd="2dp" android:drawablePadding="2dp"
    @ViewBuilder
    private var forwardedIndicatorView: some View {
        HStack(alignment: .center, spacing: 2) { // android:drawablePadding="2dp"
            // Text "forwarded" (matching Android)
            Text("forwarded")
                .font(.custom("Inter18pt-Regular", size: 8)) // android:textSize="8sp"
                .foregroundColor(Color("TextColor"))
                .multilineTextAlignment(.center)
            
            // Icon matching Android forward_wrapped (using forward_svg with theme-based color)
            // android:drawableEnd="@drawable/forward_wrapped" 
            // Use TextColor for black/white theme-based color instead of blue
            Image("forward_svg")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16) // Smaller icon for forwarded indicator
                .foregroundColor(Color("TextColor")) // Theme-based black/white color
        }
        .padding(.leading, 8) // android:paddingStart="8dp"
        .padding(.trailing, 2) // android:paddingEnd="2dp"
        .padding(.vertical, 4) // Match forward button vertical padding
        .background(
            // Background matching Android forward_drawable.xml exactly (same as forward button)
            // Layer 1: Outer Border (stroke 5dp, corner radius 20dp)
            // Layer 2: Inner Background (solid chattingMessageBox, left inset 3dp, corner radius 20dp)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Layer 1: Outer Border (matching Android border item)
                    // stroke android:width="5dp" corners android:radius="20dp"
                    // Note: Java code applies theme color to border dynamically
                    RoundedRectangle(cornerRadius: 20) // android:radius="20dp"
                        .stroke(Color(hex: Constant.themeColor), lineWidth: 5)
                        .frame(height: geometry.size.height-5) // Match content height for proper centering
                    
                    // Layer 2: Inner Background (matching Android background item)
                    // android:left="3dp" solid android:color="@color/chattingMessageBox" corners android:radius="20dp"
                    RoundedRectangle(cornerRadius: 20) // android:radius="20dp"
                        .fill(Color("chattingMessageBox")) // solid android:color="@color/chattingMessageBox"
                        .frame(width: geometry.size.width + 3, height: geometry.size.height) // Match content height
                        .offset(x: 2) // Position 3dp from left edge
                }
            }
        )
    }
    
    // Forwarded indicator view for receiver (matching Android sample_receiver.xml forwarded TextView)
    // android:id="@+id/forwarded" android:background="@drawable/forward_drawable_2"
    // android:drawableStart="@drawable/forward_wrapper_2" android:drawableTint="@color/blue"
    // android:text="forwarded" android:textSize="10sp"
    // android:paddingStart="2dp" android:paddingEnd="8dp" android:drawablePadding="2dp"
    @ViewBuilder
    private var receiverForwardedIndicatorView: some View {
        HStack(alignment: .center, spacing: 2) { // android:drawablePadding="2dp"
            // Icon matching Android forward_wrapper_2 (using forward_svg with theme-based color)
            // android:drawableStart="@drawable/forward_wrapper_2"
            // Use TextColor for black/white theme-based color instead of blue
            // Mirror the icon for receiver side (left side)
            Image("forward_svg")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16) // Icon for forwarded indicator
                .scaleEffect(x: -1, y: 1) // Mirror horizontally for receiver side
                .foregroundColor(Color("TextColor")) // Theme-based black/white color
            
            // Text "forwarded" (matching Android)
            Text("forwarded")
                .font(.custom("Inter18pt-Regular", size: 10)) // android:textSize="10sp" (larger for receiver)
                .foregroundColor(Color("TextColor"))
                .multilineTextAlignment(.center)
        }
        .padding(.leading, 2) // android:paddingStart="2dp"
        .padding(.trailing, 8) // android:paddingEnd="8dp"
        .padding(.vertical, 4) // Match forward button vertical padding
        .background(
            // Background matching Android forward_drawable_2.xml (receiver version)
            // Layer 1: Outer Border (stroke 5dp, corner radius 20dp)
            // Layer 2: Inner Background (solid chattingMessageBox, right inset 3dp, corner radius 20dp)
            GeometryReader { geometry in
                ZStack(alignment: .trailing) {
                    // Layer 1: Outer Border (matching Android border item)
                    // stroke android:width="5dp" corners android:radius="20dp"
                    // Note: Java code applies theme color to border dynamically
                    RoundedRectangle(cornerRadius: 20) // android:radius="20dp"
                        .stroke(Color(hex: Constant.themeColor), lineWidth: 5)
                        .frame(height: geometry.size.height-5) // Match content height for proper centering
                    
                    // Layer 2: Inner Background (matching Android background item)
                    // android:right="3dp" solid android:color="@color/chattingMessageBox" corners android:radius="20dp"
                    RoundedRectangle(cornerRadius: 20) // android:radius="20dp"
                        .fill(Color("chattingMessageBox")) // solid android:color="@color/chattingMessageBox"
                        .frame(width: geometry.size.width + 3, height: geometry.size.height) // Match content height
                        .offset(x: -2) // Position 3dp from right edge (opposite of sender)
                }
            }
        )
    }
    
    @ViewBuilder
    private var replyLayoutView: some View {
        // Reply layout (matching Android replylyoutGlobal) - show if replyKey == "ReplyKey"
        if let replyKey = message.replyKey, replyKey == "ReplyKey" {
            HStack {
                if isSentByMe {
                    Spacer(minLength: 0)
                }
                
                // Reply container (matching Android replylyoutGlobal)
                // Use ReplyView exactly as it is - same design for both sender and receiver
                // This includes both upper preview section and lower reply text section
                ReplyView(message: message, isSentByMe: isSentByMe) {
                    onReplyTap?(message)
                }
                
                if !isSentByMe {
                    Spacer(minLength: 0)
                }
            }
            .padding(.bottom, 4) // Add spacing between reply and main message
        }
    }
    
    private var shouldHideMainMessage: Bool {
        if let replyKey = message.replyKey, replyKey == "ReplyKey",
           let replyType = message.replyType, replyType == Constant.Text {
            return true
        }
        return false
    }
    
    @ViewBuilder
    private var mainMessageContentView: some View {
        // Main message bubble container (matching Android MainSenderBox)
        // Hide main message content when replyKey == "ReplyKey" and replyType == Constant.Text
        // (matching Android behavior where sendMessage is set to GONE for text replies)
        if !shouldHideMainMessage {
                    if isSentByMe {
                    // Check if this is an image bunch message (matching Android senderImgBunchLyt)
                    // Allow selectionCount >= 2 (including 5+ images which show 2x2 grid with +N overlay)
                    if message.dataType == Constant.img,
                       let selectionCount = message.selectionCount,
                       let selectionBunch = message.selectionBunch,
                       (Int(selectionCount) ?? 0) >= 2,
                       selectionBunch.count >= 2 {
                        // Sender image bunch message (matching Android senderImgBunchLyt design)
                        HStack {
                            Spacer(minLength: 0) // Push content to end
                            
                            // Container wrapping image bunch and caption with same background as Constant.Text sender messages
                            // Container width matches bunch width exactly (2 images side by side + spacing)
                            VStack(alignment: .trailing, spacing: 0) {
                                SenderImageBunchView(
                                    selectionBunch: selectionBunch,
                                    selectionCount: selectionCount,
                                    backgroundColor: getSenderMessageBackgroundColor(),
                                    onLongPress: nil, // Let parent MessageBubbleView handle long press
                                    onTap: {
                                        // Single tap to show full-screen preview (matching Android multiple_show_image_screen)
                                        print("📸 [BunchPreview] Tap detected on sender bunch with \(selectionBunch.count) images")
                                        for (index, imageModel) in selectionBunch.enumerated() {
                                            print("📸 [BunchPreview] Image \(index): fileName=\(imageModel.fileName), imgUrl=\(imageModel.imgUrl.isEmpty ? "empty" : imageModel.imgUrl)")
                                        }
                                        onBunchLongPress?(selectionBunch)
                                    }
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
                            .frame(width: calculateBunchWidth(selectionCount: selectionCount)) // Container width matches bunch width exactly
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(getSenderMessageBackgroundColor())
                            )
                        }
                        .frame(maxWidth: 250)
                    } else if message.dataType == Constant.img && !message.document.isEmpty {
                        // Sender image message (matching Android senderImg design)
                        HStack {
                            Spacer(minLength: 0) // Push content to end
                            
                            // Container wrapping image and caption with same background as Constant.Text sender messages
                            // Android: wrap_content height, vertical orientation, spacing: 0
                            // Container width matches image width exactly
                            VStack(alignment: .trailing, spacing: 0) {
                                DynamicImageView(
                                    imageUrl: message.document,
                                    fileName: message.fileName,
                                    imageWidth: message.imageWidth,
                                    imageHeight: message.imageHeight,
                                    aspectRatio: message.aspectRatio,
                                    backgroundColor: getSenderMessageBackgroundColor(),
                                    onTap: {
                                        // Open ShowImageScreen for single image
                                        onImageTap?(SelectionBunchModel(
                                            imgUrl: message.document,
                                            fileName: message.fileName ?? ""
                                        ))
                                    }
                                )
                                
                                // Caption text if present (matching Android caption display)
                                // Android: layout_width="match_parent", maxWidth="220dp", layout_marginTop="5dp", layout_marginBottom="5dp", paddingHorizontal="12dp"
                                // Android: textColor="#e7ebf4", textSize="15sp", textFontWeight="400", lineHeight="22dp"
                                // Caption is left-aligned like receiver side
                                if let caption = message.caption, !caption.isEmpty {
                                    HStack {
                                        Text(caption)
                                            .font(.custom("Inter18pt-Regular", size: 15))
                                            .fontWeight(.regular) // Android: textFontWeight="400"
                                            .foregroundColor(Color(hex: "#e7ebf4")) // Android: textColor="#e7ebf4"
                                            .lineSpacing(7) // Android: lineHeight="22dp" (22/15 ≈ 1.47, lineSpacing ≈ 7)
                                            .multilineTextAlignment(.leading) // Left-aligned like receiver
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: .infinity, alignment: .leading) // Fill container width, left-aligned
                                            .padding(.horizontal, 12) // Android: paddingHorizontal="12dp"
                                            .padding(.top, 5) // Android: paddingTop="5dp"
                                            .padding(.bottom, 6) // Android: paddingBottom="6dp"
                                        Spacer(minLength: 0) // Don't expand beyond content
                                    }
                                    .padding(.top, 5) // Android: layout_marginTop="5dp" - spacing between image and caption
                                    .padding(.bottom, 5) // Android: layout_marginBottom="5dp"
                                }
                            }
                            .frame(width: calculateImageSize(imageWidth: message.imageWidth, imageHeight: message.imageHeight, aspectRatio: message.aspectRatio).width) // Container width matches image width exactly
                            .background(
                                // Container background matching sender text message (same as Constant.Text sender messages)
                                RoundedRectangle(cornerRadius: 20) // matching sender text message corner radius
                                    .fill(getSenderMessageBackgroundColor()) // Same background as sender text messages
                            )
                        }
                        .frame(maxWidth: 250) // maxWidth constraint - wrap content up to max
                    } else if message.dataType == Constant.video && !message.document.isEmpty {
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
                                    backgroundColor: getSenderMessageBackgroundColor()
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
                                    .fill(getSenderMessageBackgroundColor())
                            )
                        }
                        .frame(maxWidth: 250)
                    } else if message.dataType == Constant.contact {
                        // Sender contact message (matching Android contactContainer design)
                        let _ = print("📇 [MessageBubbleView] Showing sender contact - dataType: \(message.dataType), name: \(message.name ?? "nil"), phone: \(message.phone ?? "nil")")
                        HStack {
                            Spacer(minLength: 0) // Push content to end
                            
                            // Container wrapping contact and caption with same background as Constant.Text sender messages
                            VStack(alignment: .trailing, spacing: 0) {
                                SenderContactView(
                                    contactName: message.name ?? "",
                                    contactPhone: message.phone ?? "",
                                    backgroundColor: getSenderMessageBackgroundColor(),
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
                                    .fill(getSenderMessageBackgroundColor())
                            )
                        }
                        .frame(maxWidth: 250)
                    } else if message.dataType == Constant.voiceAudio {
                        // Sender voice audio message (matching Android miceContainer design)
                        let _ = print("🎤 [MessageBubbleView] Showing sender voice audio - dataType: \(message.dataType), document: \(message.document.isEmpty ? "empty" : "has URL"), miceTiming: \(message.miceTiming ?? "nil")")
                        HStack {
                            Spacer(minLength: 0) // Push content to end
                            
                            // Container wrapping voice audio and caption with same background as Constant.Text sender messages
                            VStack(alignment: .trailing, spacing: 0) {
                                SenderVoiceAudioView(
                                    audioUrl: message.document,
                                    audioTiming: message.miceTiming ?? "00:00",
                                    micPhoto: message.micPhoto,
                                    backgroundColor: getSenderMessageBackgroundColor()
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
                                    .fill(getSenderMessageBackgroundColor())
                            )
                        }
                        .frame(maxWidth: 250)
                    } else if message.dataType == Constant.doc {
                        // Sender document message (matching Android docLyt design)
                        let _ = print("📄 [MessageBubbleView] Showing sender document - dataType: \(message.dataType), document: \(message.document.isEmpty ? "empty" : "has URL"), fileName: \(message.fileName ?? "nil"), message: \(message.message)")
                        HStack {
                            Spacer(minLength: 0) // Push content to end
                            
                            // Container wrapping document and caption with same background as Constant.Text sender messages
                            VStack(alignment: .trailing, spacing: 0) {
                                SenderDocumentView(
                                    documentUrl: message.document.isEmpty ? (message.fileName ?? "") : message.document,
                                    fileName: message.fileName ?? message.message,
                                    docSize: message.docSize,
                                    fileExtension: message.fileExtension,
                                    backgroundColor: getSenderMessageBackgroundColor(),
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
                                    .fill(getSenderMessageBackgroundColor())
                            )
                        }
                        .frame(maxWidth: 250)
                    } else {
                        // Sender text message (matching Android sendMessage TextView) - wrap content with maxWidth, gravity="end"
                        // Check if message contains a URL (matching Android URLUtil.isValidUrl)
                        if let url = message.message.extractURL(), url.isValidURL() {
                            // Show rich link preview (matching Android richLinkViewLyt)
                            HStack {
                                Spacer(minLength: 0) // Push content to end
                                SenderRichLinkView(
                                    url: url,
                                    backgroundColor: getSenderMessageBackgroundColor(),
                                    linkTitle: message.linkTitle,
                                    linkDescription: message.linkDescription,
                                    linkImageUrl: message.linkImageUrl,
                                    favIconUrl: message.favIconUrl
                                )
                            }
                            .frame(maxWidth: 250) // maxWidth constraint - wrap content up to max
                        } else {
                            // Regular text message with emoji handling (matching Android senderViewHolder)
                            let content = message.message
                            let textContentType = analyzeTextContent(content)
                            
                            // Compute emoji styling values using a closure to avoid view builder issues
                            let (fontSize, showBackground): (CGFloat, Bool) = {
                                if textContentType == "only_emoji" {
                                    let emojiCount = countEmojis(content)
                                    if emojiCount == 1 {
                                        return (80, false) // 80sp for single emoji, no background
                                    } else if emojiCount == 2 {
                                        return (45, false) // 45sp for 2 emojis, no background
                                    } else if emojiCount == 3 {
                                        return (35, false) // 35sp for 3 emojis, no background
                                    } else {
                                        return (15, true) // 15sp for 4+ emojis, with background
                                    }
                                } else {
                                    return (15, true) // Default size for text messages, with background
                                }
                            }()
                            
                            HStack {
                                Spacer(minLength: 0) // Push content to end
                                Group {
                                    if textContentType == "only_emoji" {
                                        Text(content)
                                            .font(.custom("Inter18pt-Regular", size: fontSize))
                                            .fontWeight(.light)
                                            .foregroundColor(Color(hex: "#e7ebf4"))
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .padding(.horizontal, showBackground ? 12 : 0) // padding only if background
                                            .padding(.top, showBackground ? 5 : 0)
                                            .padding(.bottom, showBackground ? 6 : 0)
                                            .background(
                                                showBackground ? RoundedRectangle(cornerRadius: 20)
                                                    .fill(getSenderMessageBackgroundColor()) : nil
                                            )
                                    } else {
                                        // Default text message styling for text_and_emoji and only_text
                                        Text(content)
                                            .font(.custom("Inter18pt-Regular", size: 15)) // textSize="15sp", textFontWeight="200" (light)
                                            .fontWeight(.light) // textFontWeight="200" = Light weight
                                            .foregroundColor(Color(hex: "#e7ebf4")) // textColor="#e7ebf4"
                                            .lineSpacing(7) // lineHeight="22dp" (22 - 15 = 7dp spacing)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true) // allow wrapping
                                            .padding(.horizontal, 12) // layout_marginHorizontal="12dp"
                                            .padding(.top, 5) // paddingTop="5dp"
                                            .padding(.bottom, 6) // paddingBottom="6dp"
                                            .background(
                                                // Background matching message_bg_blue.xml with theme color support
                                                RoundedRectangle(cornerRadius: 20) // android:radius="20dp"
                                                    .fill(getSenderMessageBackgroundColor()) // Theme-based background color
                                            )
                                    }
                                }
                            }
                            .frame(maxWidth: 250) // maxWidth constraint - wrap content up to max
                        }
                    }
                    
                } else {
                    // Check if this is a typing indicator message (matching Android TYPEINDICATOR)
                    if message.dataType == Constant.TYPEINDICATOR {
                        // Typing indicator (matching Android typingIndicator LottieAnimationView)
                        let _ = print("🎬 [TypingIndicator] Rendering typing indicator view")
                        HStack(spacing: 0) {
                            // Get animation name based on theme color
                            let animationName = getTypingIndicatorAnimationName(for: Constant.themeColor)
                            let _ = print("🎬 [TypingIndicator] Animation name: \(animationName), Theme color: \(Constant.themeColor)")
                            
                            #if canImport(Lottie)
                            let _ = print("✅ [TypingIndicator] Lottie package available, using LottieView")
                            LottieView(animationName: animationName, speed: 1.0)
                                .frame(width: 50, height: 50) // Android: 50dp x 50dp
                                .padding(.leading, 12) // Android: layout_marginStart="12dp"
                                .padding(.top, 4) // Android: layout_marginTop="4dp"
                                .padding(.bottom, 4) // Android: layout_marginBottom="4dp"
                            #else
                            let _ = print("⚠️ [TypingIndicator] Lottie package NOT available, using fallback dots")
                            // Fallback: Show animated dots while Lottie package is not available
                            TypingIndicatorDotsView()
                                .frame(width: 50, height: 50)
                                .padding(.leading, 12)
                                .padding(.top, 4)
                                .padding(.bottom, 4)
                            #endif
                            
                            Spacer(minLength: 0)
                        }
                    }
                    // Check if this is an image bunch message (matching Android recImgBunchLyt)
                    // Allow selectionCount >= 2 (including 5+ images which show 2x2 grid with +N overlay)
                    else if message.dataType == Constant.img,
                       let selectionCount = message.selectionCount,
                       let selectionBunch = message.selectionBunch,
                       (Int(selectionCount) ?? 0) >= 2,
                       selectionBunch.count >= 2 {
                        // Receiver image bunch message (matching Android recImgBunchLyt design)
                        HStack {
                            // Container wrapping image bunch and caption with same background as Constant.Text receiver messages
                            // Container width matches bunch width exactly (2 images side by side + spacing)
                            VStack(alignment: .leading, spacing: 0) {
                                ReceiverImageBunchView(
                                    selectionBunch: selectionBunch,
                                    selectionCount: selectionCount,
                                    onLongPress: nil, // Let parent MessageBubbleView handle long press
                                    onTap: {
                                        // Single tap to show full-screen preview (matching Android multiple_show_image_screen)
                                        print("📸 [BunchPreview] Tap detected on receiver bunch with \(selectionBunch.count) images")
                                        for (index, imageModel) in selectionBunch.enumerated() {
                                            print("📸 [BunchPreview] Image \(index): fileName=\(imageModel.fileName), imgUrl=\(imageModel.imgUrl.isEmpty ? "empty" : imageModel.imgUrl)")
                                        }
                                        onBunchLongPress?(selectionBunch)
                                    }
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
                            .frame(width: calculateBunchWidth(selectionCount: selectionCount)) // Container width matches bunch width exactly
                            .background(
                                getReceiverGlassBackground(cornerRadius: 20)
                            )
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: 250)
                    } else if message.dataType == Constant.img && !message.document.isEmpty {
                        // Receiver image message (matching Android receiverImg design)
                        HStack {
                            // Container wrapping image and caption with same background as Constant.Text receiver messages
                            // Android: wrap_content height, vertical orientation, spacing: 0
                            // Container width matches image width exactly
                            VStack(alignment: .leading, spacing: 0) {
                                ReceiverDynamicImageView(
                                    imageUrl: message.document,
                                    fileName: message.fileName,
                                    imageWidth: message.imageWidth,
                                    imageHeight: message.imageHeight,
                                    aspectRatio: message.aspectRatio,
                                    onTap: {
                                        // Open ShowImageScreen for single image
                                        onImageTap?(SelectionBunchModel(
                                            imgUrl: message.document,
                                            fileName: message.fileName ?? ""
                                        ))
                                    }
                                )
                                
                                // Caption text if present (matching Android caption display)
                                // Android: captionText is a direct child of MainReceiverBox (same container as text messages)
                                // Android: layout_width="match_parent", maxWidth="220dp", layout_marginTop="5dp", layout_marginBottom="5dp", paddingHorizontal="12dp"
                                // Android: style="@style/TextColor", textSize="15sp", textFontWeight="400", lineHeight="22dp"
                                // Android: Text is left-aligned (default alignment for receiver)
                                if let caption = message.caption, !caption.isEmpty {
                                    HStack {
                                        Text(caption)
                                            .font(.custom("Inter18pt-Regular", size: 15))
                                            .fontWeight(.regular) // Android: textFontWeight="400"
                                            .foregroundColor(Color("TextColor")) // Android: style="@style/TextColor"
                                            .lineSpacing(7) // Android: lineHeight="22dp" (22/15 ≈ 1.47, lineSpacing ≈ 7)
                                            .multilineTextAlignment(.leading) // Left-aligned for receiver
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: .infinity, alignment: .leading) // Fill container width, left-aligned
                                            .padding(.horizontal, 12) // Android: paddingHorizontal="12dp"
                                            .padding(.top, 5) // Android: paddingTop="5dp"
                                            .padding(.bottom, 6) // Android: paddingBottom="6dp"
                                        Spacer(minLength: 0) // Don't expand beyond content
                                    }
                                    .padding(.top, 5) // Android: layout_marginTop="5dp" - spacing between image and caption
                                    .padding(.bottom, 5) // Android: layout_marginBottom="5dp"
                                }
                            }
                            .frame(width: calculateImageSize(imageWidth: message.imageWidth, imageHeight: message.imageHeight, aspectRatio: message.aspectRatio).width) // Container width matches image width exactly
                            .background(
                                // Container background with glassmorphism (matching modern_glass_background_receiver.xml)
                                getReceiverGlassBackground(cornerRadius: 20) // matching receiver text message corner radius
                            )
                            Spacer(minLength: 0) // Don't expand beyond content
                        }
                        .frame(maxWidth: 250) // maxWidth constraint - wrap content up to max
                    } else if message.dataType == Constant.video && !message.document.isEmpty {
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
                                getReceiverGlassBackground(cornerRadius: 20)
                            )
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: 250)
                    } else if message.dataType == Constant.contact {
                        // Receiver contact message (matching Android contactContainer design)
                        let _ = print("📇 [MessageBubbleView] Showing receiver contact - dataType: \(message.dataType), name: \(message.name ?? "nil"), phone: \(message.phone ?? "nil")")
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
                    } else if message.dataType == Constant.voiceAudio {
                        // Receiver voice audio message (matching Android miceContainer design)
                        let _ = print("🎤 [MessageBubbleView] Showing receiver voice audio - dataType: \(message.dataType), document: \(message.document.isEmpty ? "empty" : "has URL"), miceTiming: \(message.miceTiming ?? "nil")")
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
                    } else if message.dataType == Constant.doc {
                        // Receiver document message (matching Android docLyt design)
                        let _ = print("📄 [MessageBubbleView] Showing receiver document - dataType: \(message.dataType), document: \(message.document.isEmpty ? "empty" : "has URL"), fileName: \(message.fileName ?? "nil"), message: \(message.message)")
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
                    } else {
                        // Receiver text message (matching Android recMessage TextView) - wrap content with maxWidth
                        // Check if message contains a URL (matching Android URLUtil.isValidUrl)
                        if let url = message.message.extractURL(), url.isValidURL() {
                            // Show rich link preview (matching Android richLinkViewLyt)
                            HStack {
                                ReceiverRichLinkView(
                                    url: url,
                                    linkTitle: message.linkTitle,
                                    linkDescription: message.linkDescription,
                                    linkImageUrl: message.linkImageUrl,
                                    favIconUrl: message.favIconUrl
                                )
                                Spacer(minLength: 0) // Don't expand beyond content
                            }
                            .frame(maxWidth: 250) // maxWidth constraint - wrap content up to max
                        } else {
                            // Regular text message with emoji handling (matching Android receiverViewHolder)
                            let content = message.message
                            let textContentType = analyzeTextContent(content)
                            
                            // Compute emoji styling values using a closure to avoid view builder issues
                            let (fontSize, showBackground): (CGFloat, Bool) = {
                                if textContentType == "only_emoji" {
                                    let emojiCount = countEmojis(content)
                                    if emojiCount == 1 {
                                        return (80, false) // 80sp for single emoji, no background
                                    } else if emojiCount == 2 {
                                        return (45, false) // 45sp for 2 emojis, no background
                                    } else if emojiCount == 3 {
                                        return (35, false) // 35sp for 3 emojis, no background
                                    } else {
                                        return (15, true) // 15sp for 4+ emojis, with background
                                    }
                                } else {
                                    return (15, true) // Default size for text messages, with background
                                }
                            }()
                            
                            HStack {
                                Group {
                                    if textContentType == "only_emoji" {
                                        Text(content)
                                            .font(.custom("Inter18pt-Regular", size: fontSize))
                                            .fontWeight(.light)
                                            .foregroundColor(Color("TextColor"))
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .padding(.horizontal, showBackground ? 12 : 0) // padding only if background
                                            .padding(.top, showBackground ? 5 : 0)
                                            .padding(.bottom, showBackground ? 6 : 0)
                                            .background(
                                                showBackground ? getReceiverGlassBackground(cornerRadius: 20) : nil
                                            )
                                    } else {
                                        // Default text message styling for text_and_emoji and only_text
                                        Text(content)
                                            .font(.custom("Inter18pt-Regular", size: 15)) // textSize="15sp" (matching Android)
                                            .fontWeight(.light) // textFontWeight="200" (matching Android)
                                            .foregroundColor(Color("TextColor"))
                                            .lineSpacing(7) // lineHeight="22dp" (22 - 15 = 7dp spacing)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true) // allow wrapping
                                            .padding(.horizontal, 12) // layout_marginHorizontal="12dp"
                                            .padding(.top, 5) // paddingTop="5dp"
                                            .padding(.bottom, 6) // paddingBottom="6dp"
                                            .background(
                                                getReceiverGlassBackground(cornerRadius: 20) // matching Android corner radius
                                            )
                                    }
                                }
                                Spacer(minLength: 0) // Don't expand beyond content
                            }
                            .frame(maxWidth: 250) // maxWidth constraint - wrap content up to max
                        }
                    }
                }
            } // End of if !shouldHideMainMessage
        }
    
    @ViewBuilder
    private var timeRowView: some View {
        // Time row with progress indicator beside time (matching Android placement)
        HStack(spacing: 6) {
            if isSentByMe {
                progressIndicatorView(isSender: true)
                Text(message.time)
                    .font(.custom("Inter18pt-Regular", size: 10))
                    .foregroundColor(Color("gray3"))
            } else {
                Text(message.time)
                    .font(.custom("Inter18pt-Regular", size: 10))
                    .foregroundColor(Color("gray3"))
                progressIndicatorView(isSender: false)
            }
        }
        .padding(.top, 5)
        .padding(.bottom, 7)
        .frame(maxWidth: .infinity, alignment: isSentByMe ? .trailing : .leading)
    }
    
    // MARK: - Emoji Reactions Card (matching Android emojiTextCard)
    @ViewBuilder
    private var emojiReactionsCardView: some View {
        // Show emoji card only if emojiCount is not empty (matching Android visibility logic)
        if let emojiCount = message.emojiCount, !emojiCount.isEmpty {
            // Emoji card (matching Android emojiTextCard CardView)
            // layout_below="@id/rl", layout_alignParentEnd="true" (sender) or layout_alignParentStart="true" (receiver)
            // layout_marginTop="-4dp", layout_marginEnd="54dp" (sender) or layout_marginStart="54dp" (receiver)
            Button(action: {
                // Handle emoji card tap - open emoji reactions bottom sheet (matching Android onClick)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                // Open emoji reactions bottom sheet
                if let onEmojiCardTap = onEmojiCardTap {
                    onEmojiCardTap(message)
                }
            }) {
                // Emoji text container (matching Android emojiText TextView)
                HStack(spacing: 0) {
                    // Build emoji text from emojiModel (matching Android logic)
                    let emojiText = buildEmojiText()
                    
                    // Display emoji text with count if emojiCount is "2"
                    if emojiCount == "2" {
                        // Show emojis with " 2 " at the end (matching Android SpannableString)
                        HStack(spacing: 0) {
                            Text(emojiText)
                                .font(.custom("Inter18pt-Regular", size: 15)) // textSize="15sp"
                            Text(" 2 ")
                                .font(.custom("Inter18pt-Regular", size: 13.5)) // 0.9f relative size (15 * 0.9 = 13.5)
                        }
                    } else {
                        // Show emojis without count
                        Text(emojiText)
                            .font(.custom("Inter18pt-Regular", size: 15)) // textSize="15sp"
                    }
                }
                .foregroundColor(Color("gray3")) // textColor="@color/gray3"
                .padding(.horizontal, 5) // paddingHorizontal="5dp"
                .padding(.vertical, 1.5) // paddingVertical="1.5dp"
                .background(
                    // CardView with corner radius 360dp (circular) and cardBackgroundColornew
                    RoundedRectangle(cornerRadius: 360)
                        .fill(Color("cardBackgroundColornew"))
                )
            }
            .offset(y: -4) // layout_marginTop="-4dp" to overlap message bubble
            .padding(isSentByMe ? .trailing : .leading, 54) // marginEnd="54dp" for sender, marginStart="54dp" for receiver
        }
    }
    
    // Build emoji text from emojiModel (matching Android logic)
    private func buildEmojiText() -> String {
        let emojiModels = message.emojiModel ?? []
        
        // Remove duplicates using Set (matching Android HashSet<emojiModel>)
        // EmojiModel conforms to Hashable, so duplicates are removed based on both name and emoji
        let uniqueEmojiList = Array(Set(emojiModels))
        
        // Build emoji text by appending unique emojis with spaces (matching Android StringBuilder)
        var emojiText = ""
        for emojiModel in uniqueEmojiList {
            let emoji = emojiModel.emoji
            if !emoji.isEmpty {
                emojiText += emoji + " " // Add space between emojis (matching Android)
            }
        }
        
        return emojiText.trimmingCharacters(in: .whitespaces) // Trim trailing space
    }
    
    @ViewBuilder
    private var highlightBackground: some View {
        // Highlight background when message is highlighted or selected in multi-select mode (matching Android highlightcolor)
        // Light mode#e7ebf4, Dark mode: #1B1C1C
        // Applied to full width including horizontal padding (matching Android holder.itemView.setBackgroundColor)
        Group {
            if isHighlighted || (isMultiSelectMode && isSelected) {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(colorScheme == .dark ? Color(hex: "#1B1C1C") : Color(hex: "#e7ebf4"))
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .animation(.easeInOut(duration: 0.3), value: isHighlighted)
                }
            }
        }
    }
    
    private var swipeGesture: some Gesture {
        // Use simultaneousGesture so it doesn't block vertical scrolling
        // Increased minimumDistance to 30 to avoid interfering with ScrollView touches
        DragGesture(minimumDistance: 30)
            .updating($dragTranslation) { value, state, _ in
                let horizontal = value.translation.width
                let vertical = abs(value.translation.height)
                
                // Only activate if horizontal movement is clearly dominant (3x vertical) and swiping right
                // Increased threshold to avoid interfering with ScrollView touches
                if horizontal > 30 && abs(horizontal) > vertical * 3.0 {
                    // Cap the translation at threshold (matching Android behavior)
                    let cappedHorizontal = min(horizontal, halfSwipeThreshold)
                    state = CGSize(width: cappedHorizontal, height: 0)
                    isDragging = true
                } else {
                    // Reset immediately if vertical movement dominates - let scroll view handle it
                    state = .zero
                    isDragging = false
                }
            }
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = abs(value.translation.height)
                
                // Trigger reply only for deliberate right swipes with clear horizontal dominance
                if horizontal > halfSwipeThreshold && abs(horizontal) > vertical * 2.0 {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onHalfSwipe(message)
                }
                
                // Reset drag state with animation
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isDragging = false
                }
            }
    }
    
    // Real-time swipe feedback overlay (matching Android HalfSwipeCallback)
    @ViewBuilder
    private var swipeFeedbackOverlay: some View {
        GeometryReader { geometry in
            let horizontal = isDragging ? dragTranslation.width : 0
            let isSwipingRight = horizontal > 0
            
            if isSwipingRight {
                let swipeDistancePx = halfSwipeThreshold
                let progress = min(abs(horizontal) / swipeDistancePx, 1.0)
                
                // Zoom delay - icon appears after 20% of swipe (matching Android zoomDelay = 0.20f)
                let zoomDelay: CGFloat = 0.20
                let scale: CGFloat = progress > zoomDelay ? {
                    let zoomProgress = (progress - zoomDelay) / (1.0 - zoomDelay)
                    // Ease-out cubic easing (matching Android)
                    let eased = 1.0 - pow(1.0 - zoomProgress, 3)
                    return eased
                }() : 0.0
                
                // Icon and progress circle dimensions (matching Android - smaller sizes)
                // Reduced further to match Android appearance
                let iconSize: CGFloat = 16  // Smaller icon size matching Android
                let progressCircleDiameter: CGFloat = 28  // Smaller circle matching Android
                
                // Center vertically in the message bubble content area (excluding time row and progress bar)
                // Time row has: padding top 5 + text height ~12 + padding bottom 7 = ~24 points
                let timeRowHeight: CGFloat = 24  // Approximate height of time row with padding
                let contentAreaHeight = geometry.size.height - timeRowHeight
                let centerY = contentAreaHeight / 2  // Center in content area, excluding time row
                
                // Same left margin for both sender and receiver bubbles
                let leftMargin: CGFloat = 13  // 13pt margin from left for both sender and receiver (8 + 5)
                // Icon appears at the same left position for both sender and receiver (doesn't move with swipe)
                let iconMoveDistance: CGFloat = 0  // Keep icon at fixed left position for both
                
                let progressLeft = leftMargin + iconMoveDistance
                
                // Progress circle center (matching Android)
                let progressCenterX = progressLeft + progressCircleDiameter / 2
                let progressCenterY = centerY
                
                ZStack {
                    // Circular progress ring (matching Android Paint.Style.STROKE)
                    // Always uses halfReplyColor (gray) regardless of sender/receiver
                    if scale > 0 {
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                getHalfReplyColor(), // Always use halfReplyColor for progress ring
                                style: StrokeStyle(lineWidth: 2, lineCap: .round)
                            )
                            .frame(width: progressCircleDiameter, height: progressCircleDiameter)
                            .rotationEffect(.degrees(-90)) // Start from top (matching Android -90 degrees)
                            .position(x: progressCenterX, y: progressCenterY)
                            .scaleEffect(scale)
                            .opacity(scale)
                        
                        // Reply icon (matching Android reply_svg_black)
                        // Gray color when unfilled (progress < 1.0)
                        // Theme color when 100% filled for sender, black color for receiver
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: iconSize, height: iconSize)
                            .foregroundColor(
                                progress >= 1.0 
                                    ? (isSentByMe ? Color(hex: Constant.themeColor) : Color.black) // Theme color for sender, black for receiver when complete
                                    : getHalfReplyColor() // Gray when unfilled
                            )
                            .position(x: progressCenterX, y: progressCenterY)
                            .scaleEffect(scale)
                            .opacity(scale)
                    }
                }
                .allowsHitTesting(false) // Don't interfere with gestures
            }
        }
    }
    
    // Get halfReplyColor (matching Android R.color.halfReplyColor)
    // Always used for progress ring and icon (until threshold)
    private func getHalfReplyColor() -> Color {
        // Gray color matching Android halfReplyColor
        return Color(red: 0x78/255.0, green: 0x78/255.0, blue: 0x7A/255.0) // #78787A gray
    }
    
    // Get destruction effect color (matching Android logic)
    // Theme color for sender, halfReplyColor for receiver
    private func getDestructionEffectColor() -> Color {
        if isSentByMe {
            // Sender: use theme color (matching Android ThemeColorKey)
            return Color(hex: Constant.themeColor)
        } else {
            // Receiver: use halfReplyColor (matching Android R.color.halfReplyColor)
            return getHalfReplyColor()
        }
    }
    
    // Calculate image size (matching DynamicImageView logic)
    // Calculate bunch width (2 images side by side + spacing)
    private func calculateBunchWidth(selectionCount: String) -> CGFloat {
        let imageSize: CGFloat = 120 // 120dp per image
        let spacing: CGFloat = 1.5 // 1.5dp spacing between columns
        return (imageSize * 2) + spacing // Total width = 2 images + spacing
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
    
    // Get sender message background color based on theme (matching Android dark mode tint colors)
    private func getSenderMessageBackgroundColor() -> Color {
        // Light mode: always use legacy bubble color (#011224) to match Android light theme
        guard colorScheme == .dark else {
            return Color(hex: "#011224")
        }
        
        // Dark mode: use theme-based tinted backgrounds (matching Android)
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
    
    // Get receiver message glassmorphism background (matching modern_glass_background_receiver.xml)
    @ViewBuilder
    private func getReceiverGlassBackground(cornerRadius: CGFloat) -> some View {
        // Linear gradient at 135 degrees with glass colors
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
                // Subtle border for glass effect (0.5dp, matching Android stroke)
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(getReceiverGlassBorder(), lineWidth: 0.5)
            )
    }
    
    // Get glass background start color (matching Android glass_bg_start)
    private func getReceiverGlassBgStart() -> Color {
        // Light mode: #80FFFFFF (50% opacity white)
        // Dark mode: #4D1B1B1B (semi-transparent dark)
        return colorScheme == .dark ? Color(hex: "#4D1B1B1B") : Color(hex: "#80FFFFFF")
    }
    
    // Get glass background center color (matching Android glass_bg_center)
    private func getReceiverGlassBgCenter() -> Color {
        // Light mode: #66FFFFFF (40% opacity white)
        // Dark mode: #331B1B1B (more transparent)
        return colorScheme == .dark ? Color(hex: "#331B1B1B") : Color(hex: "#66FFFFFF")
    }
    
    // Get glass background end color (matching Android glass_bg_end)
    private func getReceiverGlassBgEnd() -> Color {
        // Light mode: #4DFFFFFF (30% opacity white)
        // Dark mode: #1A1B1B1B (even more transparent)
        return colorScheme == .dark ? Color(hex: "#1A1B1B1B") : Color(hex: "#4DFFFFFF")
    }
    
    // Get glass border color (matching Android glass_border)
    private func getReceiverGlassBorder() -> Color {
        // Light mode: #80000000 (50% opacity black)
        // Dark mode: #40FFFFFF (25% opacity white) - matching Android values-night/colors.xml
        return colorScheme == .dark ? Color(hex: "#40FFFFFF") : Color(hex: "#80000000")
    }
    
    // Progress indicator styling based on Android LinearProgressIndicator
    // Shows animated horizontal progress bar when receiverLoader == 0 (pending message)
    private func progressIndicatorView(isSender: Bool) -> some View {
        let themeColor = Color(hex: Constant.themeColor)
        // Sender: use themeColor for both track and indicator; Receiver: use gray (no theme color)
        let indicatorColor = isSender ? themeColor : Color("gray3")
        let trackColor = isSender ? themeColor : Color("gray3")
        let cornerRadius: CGFloat = isSender ? 20 : 10
        
        // Show pending progress for sender, and for receiver only on last message
        let isPendingMessage = message.receiverLoader == 0 && (isSentByMe || (!isSentByMe && isLastMessage))
        let isReceiverPending = !isSentByMe && isLastMessage && message.receiverLoader == 0
        
        // 🔍 PROGRESS BAR LOG: Log why progress bar is shown/hidden
        if isSentByMe || isLastMessage {
            print("🔍 [ProgressBar] Message ID: \(message.id.prefix(8))...")
            print("🔍 [ProgressBar]   - isSentByMe: \(isSentByMe)")
            print("🔍 [ProgressBar]   - isLastMessage: \(isLastMessage)")
            print("🔍 [ProgressBar]   - receiverLoader: \(message.receiverLoader)")
            print("🔍 [ProgressBar]   - isPendingMessage: \(isPendingMessage)")
            print("🔍 [ProgressBar]   - dataType: \(message.dataType)")
            if isPendingMessage {
                print("🔍 [ProgressBar] ✅ SHOWING PROGRESS BAR (receiverLoader == 0, message is pending)")
            } else {
                print("🔍 [ProgressBar] 🚫 HIDING PROGRESS BAR (receiverLoader == \(message.receiverLoader), message is sent)")
            }
        }
        
        if isPendingMessage {
            if isReceiverPending && receiverProgressCompleted {
                let pendingIndicatorColor = isReceiverPending ? Color("gray3") : indicatorColor
                let pendingTrackColor = isReceiverPending ? Color("gray3").opacity(0.3) : trackColor
                return AnyView(
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(pendingTrackColor)
                            .frame(width: 20, height: 1)
                        Capsule()
                            .fill(pendingIndicatorColor)
                            .frame(width: 20, height: 1)
                    }
                    .frame(width: 20, height: 1)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                )
            }
            // Show animated horizontal progress bar for pending messages (matching Android viewnew LinearProgressIndicator)
            let pendingIndicatorColor = isReceiverPending ? Color("gray3") : themeColor
            let pendingTrackColor = isReceiverPending ? Color("gray3").opacity(0.3) : themeColor.opacity(0.3)
            return AnyView(
                AnimatedProgressBarView(
                    indicatorColor: pendingIndicatorColor,
                    trackColor: pendingTrackColor,
                    cornerRadius: cornerRadius,
                    direction: isSentByMe ? .rightToLeft : .leftToRight,
                    shouldRepeat: isSentByMe,
                    duration: 1.0,
                    onComplete: {
                        if isReceiverPending {
                            receiverProgressCompleted = true
                            onReceiverPendingComplete?(message)
                        }
                    }
                )
                .frame(width: 20, height: 1)
            )
        } else {
            // Show static indicator for sent messages (matching Android default behavior)
            return AnyView(
                ZStack(alignment: .leading) {
            Capsule()
                .fill(trackColor)
                .frame(width: 20, height: 1)
            Capsule()
                .fill(indicatorColor)
                .frame(width: 20, height: 1)
        }
        .frame(width: 20, height: 1)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            )
        }
    }
}

// MARK: - Animated Progress Bar View (matching Android viewnew LinearProgressIndicator)
// Shows animated horizontal progress bar for pending messages (receiverLoader == 0)
struct AnimatedProgressBarView: View {
    enum Direction {
        case leftToRight
        case rightToLeft
    }
    
    let indicatorColor: Color
    let trackColor: Color
    let cornerRadius: CGFloat
    let direction: Direction
    let shouldRepeat: Bool
    let duration: Double
    let onComplete: (() -> Void)?
    @State private var animationProgress: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            let barWidth = max(geometry.size.width * 0.4, 8) // 40% of width, minimum 8 points
            let maxOffset = geometry.size.width - barWidth
            let offset = direction == .leftToRight
                ? animationProgress * maxOffset
                : maxOffset - (animationProgress * maxOffset)
            
            ZStack(alignment: .leading) {
                // Track (background) - full width
                Capsule()
                    .fill(trackColor)
                    .frame(height: 1)
                
                // Animated indicator (matching Android indeterminate progress)
                Capsule()
                    .fill(indicatorColor)
                    .frame(width: barWidth, height: 1)
                    .offset(x: offset)
            }
        }
        .frame(height: 1)
        .onAppear {
            animationProgress = 0
            if shouldRepeat {
                // Start continuous animation (matching Android setIndeterminate(true))
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    animationProgress = 1.0
                }
            } else {
                // Run a single cycle and stop (matching Android setIndeterminate(false) after delay)
                withAnimation(.linear(duration: duration)) {
                    animationProgress = 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    onComplete?()
                }
            }
        }
        .onDisappear {
            // Reset animation when view disappears
            animationProgress = 0
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

// MARK: - Gallery thumbnail (parity with Android item_image.xml)
struct GalleryAssetThumbnail: View {
    let asset: PHAsset
    let imageManager: PHCachingImageManager
    let isSelected: Bool
    
    @State private var thumbnail: UIImage? = nil
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Rectangle()
                .fill(Color("BackgroundColor"))
                .frame(width: 80, height: 80)
                .cornerRadius(20)
                .overlay(
                    Group {
                        if let thumb = thumbnail {
                            Image(uiImage: thumb)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Color.gray.opacity(0.2)
                        }
                    }
                    .frame(width: 80, height: 80)
                    .clipped()
                    .cornerRadius(20)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color(hex: Constant.themeColor) : Color.clear, lineWidth: 2)
                )
                .onAppear {
                    requestThumbnail()
                }
        }
    }
    
    private func requestThumbnail() {
        let targetSize = CGSize(width: 160, height: 160)
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isSynchronous = false
        
        imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            if let image = image {
                self.thumbnail = image
            }
        }
    }
}

// MARK: - Multi-Image Preview Dialog (matching Android dialogue_full_screen_dialogue)
struct MultiImagePreviewDialog: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Binding var selectedAssetIds: Set<String>
    let photoAssets: [PHAsset]
    let imageManager: PHCachingImageManager
    @Binding var caption: String
    let onSend: (String) -> Void
    let onDismiss: () -> Void
    
    @State private var currentIndex: Int = 0
    @State private var previewImages: [UIImage?] = []
    @State private var isLoading: Bool = true
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
    
    private var selectedAssets: [PHAsset] {
        photoAssets.filter { selectedAssetIds.contains($0.localIdentifier)
        }
    }
    
    // Helper function to hide keyboard
    private func hideKeyboard() {
        isCaptionFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    var body: some View {
        ZStack {
            // Full-screen background (matching Android transparent background)
            Color.black
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    hideKeyboard()
                }
            
            VStack(spacing: 0) {
                // Top bar with back button and image count (matching Android header)
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
                    
                    // Image count indicator (matching Android counter) - always show
                    Text("\(currentIndex + 1) / \(selectedAssets.count)")
                        .font(.custom("Inter18pt-Medium", size: 16))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Spacer to balance layout (send button is in bottom caption bar)
                    Spacer()
                        .frame(width: 40)
                }
                .frame(height: 60)
                .background(Color.black.opacity(0.3))
                
                // Image preview area (matching Android image preview)
                GeometryReader { geometry in
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        TabView(selection: $currentIndex) {
                            ForEach(Array(selectedAssets.enumerated()), id: \.element.localIdentifier) { index, asset in
                                ZStack {
                                    Color.black
                                    
                                    if index < previewImages.count, let image = previewImages[index] {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .clipped()
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
                            // Load image if not already loaded
                            loadImageIfNeeded(at: newIndex)
                        }
                    }
                }
                
                // Spacing between photo and caption area (5px)
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isCaptionFocused ? Color("TextColor") : Color.gray, lineWidth: isCaptionFocused ? 1.5 : 1.0)
                    )
                    .animation(.easeInOut(duration: 0.2), value: isCaptionFocused)
                    .padding(.leading, 10)
                    .padding(.trailing, 5)
                    
                    // Send button group (matching sendGrpLyt from WhatsAppLikeImagePicker)
                    VStack(spacing: 0) {
                        Button(action: {
                            // Light haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
                            print("MultiImagePreviewDialog: Send button clicked - Caption before trim: '\(caption)' (length: \(caption.count))")
                            print("MultiImagePreviewDialog: Send button clicked - Caption after trim: '\(trimmedCaption)' (length: \(trimmedCaption.count))")
                            onSend(trimmedCaption)
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
                .padding(.bottom, 10)
                .background(Color.black)
            }
        }
        .ignoresSafeArea(.keyboard)
        .simultaneousGesture(
            TapGesture().onEnded { _ in
                hideKeyboard()
            }
        )
        .onAppear {
            print("MultiImagePreviewDialog: onAppear - Initial caption: '\(caption)' (length: \(caption.count))")
            loadAllImages()
        }
        .onDisappear {
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    // Handle swipe down to dismiss (optional)
                    if value.translation.height > 100 {
                        onDismiss()
                    }
                }
        )
    }
    private func loadAllImages() {
        isLoading = true
        previewImages = Array(repeating: nil, count: selectedAssets.count)
        
        let group = DispatchGroup()
        
        for (index, asset) in selectedAssets.enumerated() {
            group.enter()
            loadImageForAsset(asset, at: index) {
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            isLoading = false
            // Load first image immediately
            if !selectedAssets.isEmpty {
                loadImageIfNeeded(at: 0)
            }
        }
    }
    
    private func loadImageIfNeeded(at index: Int) {
        guard index < selectedAssets.count else { return }
        guard index >= previewImages.count || previewImages[index] == nil else { return }
        
        let asset = selectedAssets[index]
        loadImageForAsset(asset, at: index)
    }
    
    private func loadImageForAsset(_ asset: PHAsset, at index: Int, completion: (() -> Void)? = nil) {
        let targetSize = CGSize(width: UIScreen.main.bounds.width * 2, height: UIScreen.main.bounds.height * 2)
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isSynchronous = false
        
        imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            DispatchQueue.main.async {
                if index < self.previewImages.count {
                    self.previewImages[index] = image
                }
                completion?()
            }
        }
    }
}

// MARK: - Voice Recording Bottom Sheet (matching Android bottom_sheet_dialogue_rec.xml)
struct VoiceRecordingBottomSheet: View {
    @Binding var recordingDuration: TimeInterval
    @Binding var recordingProgress: Double
    @Binding var isRecording: Bool
    let onCancel: () -> Void
    let onSend: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private var formattedTime: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress bar container (matching Android LinearLayout with orientation="vertical")
            VStack(spacing: 0) {
                // Progress bar (matching Android LinearProgressIndicator)
                // Rounded corner box with stroke border
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Rounded rectangle box with stroke (border)
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color("gray"), lineWidth: 2) // Rounded stroke border (box outline)
                            .frame(height: 3)
                            .background(
                                // Background fill for empty area
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color("gray").opacity(0.1))
                                    .frame(height: 3)
                            )
                        
                        // Progress indicator fill inside the stroked box
                        // Progress bar fills from left to right as time decreases (matching Android CountDownTimer)
                        // When recordingProgress = 100%, bar is full (time remaining = 60s)
                        // When recordingProgress = 0%, bar is empty (time remaining = 0s)
                        let strokeWidth: CGFloat = 2
                        let innerWidth = geometry.size.width - (strokeWidth * 2)
                        let progressWidth = max(0, min(innerWidth, innerWidth * (recordingProgress / 100.0)))
                        
                        RoundedRectangle(cornerRadius: 8) // Rounded corners matching inner box
                            .fill(Color("gray")) // Solid gray indicator fill
                            .frame(width: progressWidth, height: 1) // Inner fill height (accounting for stroke)
                            .padding(.leading, strokeWidth) // Padding to account for left stroke
                            .padding(.vertical, strokeWidth) // Vertical padding to center inside stroke
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 30) // layout_marginHorizontal="30dp"
                .padding(.top, 10) // layout_marginTop="10dp"
                
                // Bottom controls layout (matching Android galleryLyt LinearLayoutCompat)
                HStack(spacing: 0) {
                    // Cancel button container (matching Android layout_weight="1.6")
                    HStack {
                        Spacer()
                        Button(action: {
                            // Light haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            onCancel()
                        }) {
                            // ImageView matching Android: 35dp x 35dp container, 24dp image
                            Image("baseline_cancel_24")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(Color("red_to_black_tint")) // app:tint="@color/red_to_black_tint"
                                .frame(width: 35, height: 35) // android:layout_width="35dp" android:layout_height="35dp"
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity) // layout_weight="1.6"
                    
                    // Chronometer - centered in the middle (matching Android but visually centered)
                    Text(formattedTime)
                        .font(.custom("Inter18pt-Bold", size: 18)) // android:textSize="18sp" android:textStyle="bold"
                        .foregroundColor(Color("TextColor")) // style="@style/TextColor"
                        .frame(maxWidth: .infinity) // layout_weight="0.5" but we'll center it visually
                        .multilineTextAlignment(.center) // android:gravity="center"
                    
                    // Send button container (matching Android sendGrpLyt layout_weight="1.5")
                    HStack {
                        Spacer()
                        Button(action: {
                            // Light haptic feedback (matching Android Vibrator50)
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            onSend()
                        }) {
                            // Send button (matching Android sendGrpBtm: 56dp x 56dp)
                            ZStack {
                                // Background matching Android callbg drawable with theme color tint
                                Circle()
                                    .fill(Color(hex: Constant.themeColor)) // Theme color (matching Android backgroundTintList)
                                    .frame(width: 56, height: 56) // android:layout_width="56dp" android:layout_height="56dp"
                                
                                // Send icon (matching Android ImageView: 26dp x 24dp)
                                Image("baseline_keyboard_double_arrow_right_24")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 26, height: 24) // android:layout_width="26dp" android:layout_height="24dp"
                                    .foregroundColor(.white)
                                    .padding(.top, 4) // android:layout_marginTop="4dp"
                                    .padding(.bottom, 8) // android:layout_marginBottom="8dp"
                            }
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity) // layout_weight="1.5"
                }
                .padding(15) // android:padding="15dp"
            }
        }
        .background(Color("bottom_sheet_background")) // Matching Android bottom_sheet_background drawable
        .presentationDetents([.height(110)]) // Approximate height: progress bar (3dp + 10dp top + 20dp bottom) + controls (56dp button + 15dp padding * 2) ≈ 110dp
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - Music Player Bottom Sheet (matching Android MusicPlayerBottomSheet)
struct MusicPlayerBottomSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    let audioUrl: String
    let profileImageUrl: String
    let songTitle: String
    
    @State private var audioPlayer: AVPlayer? = nil
    @State private var isPlaying: Bool = false
    @State private var currentTime: TimeInterval = 0.0
    @State private var duration: TimeInterval = 0.0
    @State private var audioTimeObserver: Any? = nil
    @State private var isRotating: Bool = false
    @State private var waveData: [CGFloat] = []
    @State private var progress: CGFloat = 0.0
    
    // Get theme color
    private var themeColor: Color {
        Color(hex: Constant.themeColor)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Profile Image with Modern Design (matching Android iv_profile_image)
            ZStack {
                // Outer Glow Ring
                Circle()
                    .fill(themeColor.opacity(0.3))
                    .frame(width: 140, height: 140)
                
                // Main Profile Image
                AsyncImage(url: URL(string: profileImageUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure(_), .empty:
                        Image("inviteimg")
                            .resizable()
                            .scaledToFill()
                    @unknown default:
                        Image("inviteimg")
                            .resizable()
                            .scaledToFill()
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color("TextColor"), lineWidth: 1)
                )
                .rotationEffect(.degrees(isRotating ? 360 : 0))
                .animation(isRotating ? Animation.linear(duration: 10).repeatForever(autoreverses: false) : .default, value: isRotating)
            }
            .frame(width: 140, height: 140)
            .padding(.top, 14)
            
            // Song Info (matching Android tv_song_title)
            VStack(spacing: 4) {
                Text(songTitle.isEmpty ? "Audio Message" : songTitle)
                    .font(.custom("Inter18pt-Medium", size: 20))
                    .foregroundColor(Color("TextColor"))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 10)
            
            // Audio Wave Container (matching Android audio_wave_progress)
            VStack(spacing: 12) {
                // Wave visualization - centered horizontally with 10px spacing
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        Spacer()
                            .frame(width: 10)
                        AudioWaveView(
                            waveData: waveData,
                            progress: progress,
                            waveColor: Color("TextColor"),
                            progressColor: themeColor,
                            isPlaying: isPlaying,
                            currentTime: currentTime
                        )
                        .frame(height: 56)
                        .frame(maxWidth: .infinity)
                        Spacer()
                            .frame(width: 10)
                    }
                    .frame(width: geometry.size.width)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                // Account for 10px padding on left side
                                let adjustedX = value.location.x - 10
                                let waveWidth = geometry.size.width - 20 // Total width minus both 10px paddings
                                seekToPosition(adjustedX, waveWidth: waveWidth)
                            }
                            .onEnded { value in
                                // Also seek on drag end for better UX
                                let adjustedX = value.location.x - 10
                                let waveWidth = geometry.size.width - 20
                                seekToPosition(adjustedX, waveWidth: waveWidth)
                            }
                    )
                }
                .frame(height: 56)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color("chattingMessageBox").opacity(0.5))
                )
                
                // Time Display (matching Android tv_current_time and tv_total_time)
                HStack {
                    Text(formatTime(currentTime))
                        .font(.custom("Inter18pt-Medium", size: 13))
                        .foregroundColor(Color("TextColor").opacity(0.9))
                    
                    Spacer()
                    
                    Text(formatTime(duration))
                        .font(.custom("Inter18pt-Medium", size: 13))
                        .foregroundColor(Color("TextColor").opacity(0.9))
                }
                .padding(.horizontal, 0)
            }
            .padding(.top, 14)
            .padding(.horizontal, 20)
            
            // Play Controls (matching Android btn_play_pause)
            HStack(spacing: 28) {
                // Previous Button (invisible, matching Android)
                Button(action: {}) {
                    Image("pressbg")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundColor(Color("TextColor"))
                }
                .frame(width: 48, height: 48)
                .opacity(0)
                
                // Main Play/Pause Button
                Button(action: {
                    togglePlayback()
                }) {
                    ZStack {
                        Circle()
                            .fill(themeColor)
                            .frame(width: 70, height: 70)
                            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                        
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(Color("TextColor"))
                    }
                }
                .frame(width: 70, height: 70)
                
                // Next Button (invisible, matching Android)
                Button(action: {}) {
                    Image("next")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundColor(Color("TextColor"))
                }
                .frame(width: 48, height: 48)
                .opacity(0)
            }
            .padding(.top, 18)
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color("chattingMessageBox"))
        )
        .onAppear {
            setupAudioPlayer()
        }
        .onDisappear {
            stopAudioPlayer()
        }
    }
    
    // Format time (matching Android formatTime)
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // Setup audio player
    private func setupAudioPlayer() {
        // Check for local file first (matching Android logic)
        var finalAudioUrl = audioUrl
        var localFilePath: String? = nil
        
        // Check local Audios directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audiosDir = documentsPath.appendingPathComponent("Enclosure/Media/Audios", isDirectory: true)
        
        // Extract fileName from URL - get only the filename, not the path
        // Handle cases like "chats/11_kgf_rocky_climax.mp3" or full URLs
        let fileName: String
        if let url = URL(string: audioUrl) {
            // Get the last path component (filename only)
            var pathComponent = url.lastPathComponent
            
            // If lastPathComponent is empty or still contains path separators, extract manually
            if pathComponent.isEmpty || pathComponent.contains("/") {
                // Split by "/" and take the last non-empty part
                let parts = audioUrl.components(separatedBy: "/").filter { !$0.isEmpty }
                pathComponent = parts.last ?? audioUrl
            }
            
            // Remove any query parameters if present
            if let queryIndex = pathComponent.firstIndex(of: "?") {
                pathComponent = String(pathComponent[..<queryIndex])
            }
            
            fileName = pathComponent
        } else {
            // If not a valid URL, try to extract filename from string
            let parts = audioUrl.components(separatedBy: "/").filter { !$0.isEmpty }
            var extractedName = parts.last ?? audioUrl
            
            // Remove any query parameters if present
            if let queryIndex = extractedName.firstIndex(of: "?") {
                extractedName = String(extractedName[..<queryIndex])
            }
            
            fileName = extractedName
        }
        
        print("🎵 [MusicPlayer] Extracted fileName: \(fileName) from audioUrl: \(audioUrl)")
        
        if FileManager.default.fileExists(atPath: audiosDir.path) {
            let localFile = audiosDir.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: localFile.path) {
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: localFile.path)[.size] as? Int64) ?? 0
                if fileSize > 0 {
                    localFilePath = localFile.path
                    finalAudioUrl = "file://" + localFilePath!
                    print("✅ [MusicPlayer] Using local file: \(localFilePath!)")
                } else {
                    print("🚫 [MusicPlayer] Local file exists but is empty")
                }
            } else {
                print("🚫 [MusicPlayer] Local file not found: \(localFile.path)")
            }
        } else {
            print("🚫 [MusicPlayer] Audios directory not found: \(audiosDir.path)")
        }
        
        // Create player
        let url: URL
        if finalAudioUrl.hasPrefix("file://") {
            url = URL(fileURLWithPath: String(finalAudioUrl.dropFirst(7)))
        } else if finalAudioUrl.hasPrefix("/") {
            url = URL(fileURLWithPath: finalAudioUrl)
        } else if let httpUrl = URL(string: finalAudioUrl) {
            url = httpUrl
        } else {
            print("🚫 [MusicPlayer] Invalid audio URL: \(finalAudioUrl)")
            return
        }
        
        audioPlayer = AVPlayer(url: url)
        
        // Get duration
        if let duration = audioPlayer?.currentItem?.asset.duration {
            self.duration = CMTimeGetSeconds(duration)
            // Generate wave data based on duration
            generateWaveData(for: self.duration)
        }
        
        // Observe time updates
        audioTimeObserver = audioPlayer?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { time in
            self.currentTime = CMTimeGetSeconds(time)
            if self.duration > 0 {
                self.progress = CGFloat(self.currentTime / self.duration)
            }
        }
        
        // Start playing
        audioPlayer?.play()
        isPlaying = true
        isRotating = true
        
        // Observe playback end
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: audioPlayer?.currentItem,
            queue: .main
        ) { _ in
            self.isPlaying = false
            self.isRotating = false
            self.currentTime = 0.0
            self.progress = 0.0
            self.audioPlayer?.seek(to: .zero)
            self.dismiss()
        }
    }
    
    // Toggle playback
    private func togglePlayback() {
        guard let player = audioPlayer else { return }
        
        if isPlaying {
            player.pause()
            isPlaying = false
            isRotating = false
        } else {
            player.play()
            isPlaying = true
            isRotating = true
        }
    }
    
    // Seek to position
    private func seekToPosition(_ x: CGFloat, waveWidth: CGFloat) {
        guard let player = audioPlayer, duration > 0, waveWidth > 0 else { return }
        
        // Calculate progress from touch position
        let touchProgress = max(0, min(1, x / waveWidth))
        let seekTime = TimeInterval(touchProgress) * duration
        
        // Update UI immediately for responsive feedback (synchronously on main thread)
        // Since gestures are already on main thread, we can update directly
        self.currentTime = seekTime
        self.progress = CGFloat(touchProgress)
        
        // Seek the player to the new position
        player.seek(to: CMTime(seconds: seekTime, preferredTimescale: 600))
    }
    
    // Generate wave data (matching Android generateWaveDataForDuration)
    private func generateWaveData(for duration: TimeInterval) {
        let durationMs = Int(duration * 1000)
        let dataLength = max(100, durationMs / 10) // 1 data point per 10ms
        var data: [CGFloat] = []
        
        for i in 0..<dataLength {
            let frequency = 0.02 + Double(i % 100) * 0.001
            let amplitude = 30 + sin(Double(i) * 0.01) * 20
            let value = sin(Double(i) * frequency) * amplitude + Double.random(in: 0...10)
            data.append(CGFloat(value))
        }
        
        waveData = data
    }
    
    // Stop audio player
    private func stopAudioPlayer() {
        audioPlayer?.pause()
        audioPlayer = nil
        isPlaying = false
        isRotating = false
        currentTime = 0.0
        duration = 0.0
        progress = 0.0
        if let observer = audioTimeObserver {
            audioPlayer?.removeTimeObserver(observer)
            audioTimeObserver = nil
        }
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Audio Wave View (matching Android AudioWaveView)
struct AudioWaveView: View {
    let waveData: [CGFloat]
    let progress: CGFloat
    let waveColor: Color
    let progressColor: Color
    let isPlaying: Bool
    let currentTime: TimeInterval
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<min(waveData.count, 200), id: \.self) { index in
                let baseHeight = waveData[index]
                let isActive = CGFloat(index) / CGFloat(waveData.count) < progress
                
                // Animate bars based on playback position and music timing
                // Use currentTime to create a wave effect that syncs with music
                let timeOffset = currentTime * 3 // Speed of animation (higher = faster)
                let indexOffset = Double(index) * 0.2 // Phase offset per bar (creates wave effect)
                let animationOffset = isPlaying ? sin(timeOffset + indexOffset) * 5 : 0
                let animatedHeight = max(3, baseHeight + CGFloat(animationOffset))
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(isActive ? progressColor : waveColor.opacity(0.5))
                    .frame(width: 4, height: max(3, min(animatedHeight, 28)))
            }
        }
    }
}

// MARK: - Sender Contact View (matching Android sender contactContainer)
struct SenderContactView: View {
    let contactName: String
    let contactPhone: String
    let backgroundColor: Color
    let contactDocumentUrl: String?
    
    @State private var isContactSaved: Bool = false
    @State private var showDownloadButton: Bool = false
    @State private var isDownloading: Bool = false
    @State private var downloadProgress: Double = 0.0
    @State private var showDownloadProgress: Bool = false
    @State private var showContactActionBottomSheet: Bool = false
    @State private var showCreateContactBottomSheet: Bool = false
    @State private var showContactPicker: Bool = false
    
    // Get first letter of name for circular icon
    private var firstLetter: String {
        guard let firstChar = contactName.first else { return "" }
        return String(firstChar).uppercased()
    }
    
    // Get local contacts directory
    private func getLocalContactsDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let contactsDir = documentsPath.appendingPathComponent("Enclosure/Media/Contacts", isDirectory: true)
        try? FileManager.default.createDirectory(at: contactsDir, withIntermediateDirectories: true, attributes: nil)
        return contactsDir
    }
    
    // Check if contact is saved locally
    private var hasLocalContact: Bool {
        let contactsDir = getLocalContactsDirectory()
        let contactFile = contactsDir.appendingPathComponent("\(contactName)_\(contactPhone).vcf")
        return FileManager.default.fileExists(atPath: contactFile.path)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main container - matching Android contactContainer LinearLayout
            VStack(spacing: 0) {
                // Debug: Ensure contact data is available
                let _ = print("📇 [SenderContactView] Rendering - name: '\(contactName)', phone: '\(contactPhone)', isEmpty: \(contactName.isEmpty && contactPhone.isEmpty)")
                
                // Horizontal layout with icon and name/phone - matching Android
                HStack(spacing: 0) {
                    // Download button (if contact document URL exists) - matching SelectionBunchLayout download design
                    if let documentUrl = contactDocumentUrl, !documentUrl.isEmpty, !hasLocalContact, !isDownloading {
                        Button(action: {
                            downloadContact()
                        }) {
                            ZStack {
                                // iOS glassmorphism background (matching SelectionBunchLayout)
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 35, height: 35)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                                
                                Image("downloaddown")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                    .foregroundColor(Color(hex: "#e7ebf4")) // Matching sender SelectionBunchLayout
                            }
                        }
                        .padding(.trailing, 5)
                    }
                    
                    // Circular gradient icon - matching Android contact_gradient_cirlce
                    ZStack {
                        // Gradient circle background
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(hex: "#E8E8E8"),
                                        Color(hex: "#D0D0D0")
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 45, height: 45)
                        
                        // First letter text - matching Android firstText
                        Text(firstLetter.isEmpty ? "?" : firstLetter)
                            .font(.custom("Inter18pt-Regular", size: 15))
                            .foregroundColor(.black)
                    }
                    .frame(width: 45, height: 45)
                    
                    // Name and phone layout - matching Android cnamenamelyt
                    VStack(alignment: .leading, spacing: 1) {
                        // Name - matching Android cName
                        Text(contactName.isEmpty ? "Unknown" : contactName)
                            .font(.custom("Inter18pt-Regular", size: 15))
                            .foregroundColor(Color(hex: "#e7ebf4"))
                            .lineLimit(2)
                            .frame(minWidth: 100, maxWidth: 170, alignment: .leading)
                        
                        // Phone - matching Android cPhone
                        Text(contactPhone.isEmpty ? "No phone" : contactPhone)
                            .font(.custom("Inter18pt-Regular", size: 13))
                            .foregroundColor(Color("gray"))
                            .lineLimit(1)
                            .frame(maxWidth: 210, alignment: .leading)
                    }
                    .padding(.leading, 7)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
                
                // Add button - matching Android viewContact
                Button(action: {
                    showContactActionBottomSheet = true
                }) {
                    HStack {
                        Spacer()
                        Text("Add")
                            .font(.custom("Inter18pt-Regular", size: 12))
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                            .textCase(.none)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 20) // Android save_bg_for_all uses 20dp radius
                            .fill(Color(hex: "#E8E8E8"))
                    )
                }
                .padding(.top, 10)
                .padding(.horizontal, 2)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 7)
        }
        .onAppear {
            checkLocalContact()
            if let documentUrl = contactDocumentUrl, !documentUrl.isEmpty, !hasLocalContact {
                showDownloadButton = true
            }
        }
        .sheet(isPresented: $showContactActionBottomSheet) {
            ContactActionBottomSheet(
                contactName: contactName,
                contactPhone: contactPhone,
                onCreateContact: {
                    showContactActionBottomSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showCreateContactBottomSheet = true
                    }
                },
                onDismiss: {
                    showContactActionBottomSheet = false
                }
            )
            .presentationDetents([.height(120)]) // Wrap content height - approximately 20dp top + 20dp bottom + 15dp padding * 2 + text height
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showCreateContactBottomSheet) {
            CreateContactBottomSheet(
                contactName: contactName,
                contactPhone: contactPhone,
                onSave: { firstName, lastName, phone in
                    saveContactToPhone(firstName: firstName, lastName: lastName, phone: phone)
                    showCreateContactBottomSheet = false
                },
                onDismiss: {
                    showCreateContactBottomSheet = false
                }
            )
            .presentationDetents([.height(200)]) // Same height as ContactActionBottomSheet
            .presentationDragIndicator(.hidden)
        }
    }
    
    // Check if contact exists locally
    private func checkLocalContact() {
        isContactSaved = hasLocalContact
    }
    
    // Save contact to phone (matching Android save onClick)
    private func saveContactToPhone(firstName: String, lastName: String, phone: String) {
        let store = CNContactStore()
        
        // Request authorization
        store.requestAccess(for: .contacts) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    let contact = CNMutableContact()
                    
                    // Set name
                    contact.givenName = firstName
                    contact.familyName = lastName
                    
                    // Set phone
                    let phoneNumber = CNPhoneNumber(stringValue: phone)
                    let phoneValue = CNLabeledValue(label: CNLabelPhoneNumberMobile, value: phoneNumber)
                    contact.phoneNumbers = [phoneValue]
                    
                    // Save contact
                    let saveRequest = CNSaveRequest()
                    saveRequest.add(contact, toContainerWithIdentifier: nil)
                    
                    do {
                        try store.execute(saveRequest)
                        print("✅ [Contact] Contact saved successfully")
                        
                        // Save to local storage
                        saveContactToLocalStorage(firstName: firstName, lastName: lastName, phone: phone)
                        
                        // Update UI
                        isContactSaved = true
                        
                        // Show success message (matching Android Toast)
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = windowScene.windows.first {
                            let toast = UILabel()
                            toast.text = "Contact saved successfully"
                            toast.textColor = .white
                            toast.backgroundColor = UIColor.black.withAlphaComponent(0.7)
                            toast.textAlignment = .center
                            toast.layer.cornerRadius = 8
                            toast.clipsToBounds = true
                            toast.font = UIFont.systemFont(ofSize: 14)
                            toast.frame = CGRect(x: window.bounds.width / 2 - 100, y: window.bounds.height - 150, width: 200, height: 40)
                            window.addSubview(toast)
                            
                            UIView.animate(withDuration: 0.3, delay: 1.5, options: .curveEaseOut, animations: {
                                toast.alpha = 0
                            }) { _ in
                                toast.removeFromSuperview()
                            }
                        }
                    } catch {
                        print("🚫 [Contact] Failed to save contact: \(error.localizedDescription)")
                    }
                }
            } else {
                print("🚫 [Contact] Contact access denied")
            }
        }
    }
    
    // Save contact to local storage (matching Android local storage)
    private func saveContactToLocalStorage(firstName: String, lastName: String, phone: String) {
        let contactsDir = getLocalContactsDirectory()
        let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        let contactFile = contactsDir.appendingPathComponent("\(fullName.replacingOccurrences(of: " ", with: "_"))_\(phone).vcf")
        
        // Create VCF content
        let vcfContent = """
        BEGIN:VCARD
        VERSION:3.0
        FN:\(fullName)
        TEL;TYPE=CELL:\(phone)
        END:VCARD
        """
        
        do {
            try vcfContent.write(to: contactFile, atomically: true, encoding: .utf8)
            print("✅ [Contact] Contact saved to local storage: \(contactFile.path)")
        } catch {
            print("🚫 [Contact] Failed to save contact to local storage: \(error.localizedDescription)")
        }
    }
    
    // Download contact VCF file (matching Android download logic)
    private func downloadContact() {
        guard let documentUrl = contactDocumentUrl, !documentUrl.isEmpty else { return }
        guard let url = URL(string: documentUrl) else { return }
        
        let contactsDir = getLocalContactsDirectory()
        let contactFile = contactsDir.appendingPathComponent("\(contactName)_\(contactPhone).vcf")
        
        // Check if already downloading
        if BackgroundDownloadManager.shared.isDownloading(fileName: contactFile.lastPathComponent) {
            print("📱 [Contact] Already downloading")
            return
        }
        
        // Light haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Update UI
        isDownloading = true
        showDownloadButton = false
        showDownloadProgress = true
        downloadProgress = 0.0
        
        // Use BackgroundDownloadManager for download
        BackgroundDownloadManager.shared.downloadImage(
            imageUrl: documentUrl,
            fileName: contactFile.lastPathComponent,
            destinationFile: contactFile,
            onProgress: { progress in
                DispatchQueue.main.async {
                    self.downloadProgress = progress
                    if progress > 0 {
                        self.showDownloadProgress = true
                    }
                }
            },
            onSuccess: {
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.showDownloadProgress = false
                    self.showDownloadButton = false
                    self.downloadProgress = 0.0
                    print("✅ [Contact] Contact VCF downloaded successfully")
                }
            },
            onFailure: { error in
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.showDownloadProgress = false
                    self.showDownloadButton = true
                    self.downloadProgress = 0.0
                    print("🚫 [Contact] Download failed: \(error.localizedDescription)")
                }
            }
        )
    }
    
}

// MARK: - Receiver Contact View (matching Android receiver contactContainer)
struct ReceiverContactView: View {
    @Environment(\.colorScheme) var colorScheme
    let contactName: String
    let contactPhone: String
    let contactDocumentUrl: String?
    
    @State private var isContactSaved: Bool = false
    @State private var showDownloadButton: Bool = false
    @State private var isDownloading: Bool = false
    @State private var downloadProgress: Double = 0.0
    @State private var showDownloadProgress: Bool = false
    @State private var showContactActionBottomSheet: Bool = false
    @State private var showCreateContactBottomSheet: Bool = false
    @State private var showContactPicker: Bool = false
    
    // Get first letter of name for circular icon
    private var firstLetter: String {
        guard let firstChar = contactName.first else { return "" }
        return String(firstChar).uppercased()
    }
    
    // Get local contacts directory
    private func getLocalContactsDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let contactsDir = documentsPath.appendingPathComponent("Enclosure/Media/Contacts", isDirectory: true)
        try? FileManager.default.createDirectory(at: contactsDir, withIntermediateDirectories: true, attributes: nil)
        return contactsDir
    }
    
    // Check if contact is saved locally
    private var hasLocalContact: Bool {
        let contactsDir = getLocalContactsDirectory()
        let contactFile = contactsDir.appendingPathComponent("\(contactName)_\(contactPhone).vcf")
        return FileManager.default.fileExists(atPath: contactFile.path)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main container - matching Android contactContainer LinearLayout
            VStack(spacing: 0) {
                // Debug: Ensure contact data is available
                let _ = print("📇 [ReceiverContactView] Rendering - name: '\(contactName)', phone: '\(contactPhone)', isEmpty: \(contactName.isEmpty && contactPhone.isEmpty)")
                
                // Horizontal layout with name/phone and icon - matching Android (reversed order)
                // Android: inner LinearLayout has wrap_content width and layout_gravity="center"
                HStack(spacing: 0) {
                    Spacer() // Center the content horizontally
                    
                    // Download button (if contact document URL exists) - matching SelectionBunchLayout download design
                    if let documentUrl = contactDocumentUrl, !documentUrl.isEmpty, !hasLocalContact, !isDownloading {
                        Button(action: {
                            downloadContact()
                        }) {
                            ZStack {
                                // iOS glassmorphism background (matching SelectionBunchLayout)
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 35, height: 35)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                                
                                Image("downloaddown")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                    .foregroundColor(.white) // Matching receiver SelectionBunchLayout
                            }
                        }
                        .padding(.leading, 5)
                    }
                    
                    // Name and phone layout - matching Android cnamenamelyt (on left for receiver)
                    VStack(alignment: .leading, spacing: 1) {
                        // Name - matching Android cName
                        Text(contactName.isEmpty ? "Unknown" : contactName)
                            .font(.custom("Inter18pt-Regular", size: 15))
                            .foregroundColor(Color("TextColor"))
                            .lineLimit(2)
                            .frame(minWidth: 100, maxWidth: 210, alignment: .leading)
                        
                        // Phone - matching Android cPhone
                        Text(contactPhone.isEmpty ? "No phone" : contactPhone)
                            .font(.custom("Inter18pt-Regular", size: 15))
                            .foregroundColor(Color("edittextremoveline"))
                            .lineLimit(1)
                            .frame(maxWidth: 210, alignment: .leading)
                    }
                    .padding(.trailing, 7) // Android: layout_marginEnd="7dp"
                    
                    // Circular gradient icon - matching Android contact_gradient_cirlce_receiver
                    ZStack {
                        // Gradient circle background (receiver style) - Android uses black radial gradient
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        Color.black,
                                        Color.black
                                    ]),
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 18
                                )
                            )
                            .frame(width: 45, height: 45)
                        
                        // First letter text - matching Android firstText (white color)
                        Text(firstLetter.isEmpty ? "?" : firstLetter)
                            .font(.custom("Inter18pt-Regular", size: 15))
                            .foregroundColor(.white)
                    }
                    .frame(width: 45, height: 45)
                    
                    Spacer() // Center the content horizontally
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
                
                // Add button - matching Android viewContact (receiver style)
                // Android: LinearLayout with layout_width="match_parent", layout_marginTop="10dp", padding="2dp"
                // Android: TextView has layout_height="wrap_content", layout_marginTop="1dp", layout_gravity="center_vertical"
                // Android: background="@drawable/save_bg_for_all_receiver" -> save_scale_b_receiver.xml
                // Android: save_scale_b_receiver has corners radius="20dp", stroke width="0.8dp" color="black", solid color="black"
                Button(action: {
                    showContactActionBottomSheet = true
                }) {
                    Text("Add")
                        .font(.custom("Inter18pt-Regular", size: 12))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .textCase(.none)
                        .frame(maxWidth: .infinity) // Android: TextView layout_width="match_parent"
                        .frame(height: nil) // Android: layout_height="wrap_content"
                        .padding(.top, 1) // Android: layout_marginTop="1dp" on TextView
                }
                .frame(maxWidth: .infinity) // Android: LinearLayout layout_width="match_parent"
                .padding(.top, 2) // Android: padding="2dp" on LinearLayout (top)
                .padding(.bottom, 2) // Android: padding="2dp" on LinearLayout (bottom)
                .padding(.horizontal, 2) // Android: padding="2dp" on LinearLayout (horizontal)
                .background(
                    RoundedRectangle(cornerRadius: 20) // Android: corners radius="20dp"
                        .fill(Color.black) // Android: solid color="black"
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.black, lineWidth: 0.8) // Android: stroke width="0.8dp" color="black"
                        )
                )
                .padding(.top, 10) // Android: layout_marginTop="10dp"
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 7)
        }
        .onAppear {
            checkLocalContact()
            if let documentUrl = contactDocumentUrl, !documentUrl.isEmpty, !hasLocalContact {
                showDownloadButton = true
            }
        }
        .sheet(isPresented: $showContactActionBottomSheet) {
            ContactActionBottomSheet(
                contactName: contactName,
                contactPhone: contactPhone,
                onCreateContact: {
                    showContactActionBottomSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showCreateContactBottomSheet = true
                    }
                },
                onDismiss: {
                    showContactActionBottomSheet = false
                }
            )
            .presentationDetents([.height(120)]) // Wrap content height - approximately 20dp top + 20dp bottom + 15dp padding * 2 + text height
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showCreateContactBottomSheet) {
            CreateContactBottomSheet(
                contactName: contactName,
                contactPhone: contactPhone,
                onSave: { firstName, lastName, phone in
                    saveContactToPhone(firstName: firstName, lastName: lastName, phone: phone)
                    showCreateContactBottomSheet = false
                },
                onDismiss: {
                    showCreateContactBottomSheet = false
                }
            )
            .presentationDetents([.height(200)]) // Same height as ContactActionBottomSheet
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showContactPicker) {
            ContactPickerViewControllerWrapper(
                phoneNumber: contactPhone,
                onDismiss: {
                    showContactPicker = false
                }
            )
        }
    }
    
    // Check if contact exists locally
    private func checkLocalContact() {
        isContactSaved = hasLocalContact
    }
    
    // Download contact VCF file (matching Android download logic)
    private func downloadContact() {
        guard let documentUrl = contactDocumentUrl, !documentUrl.isEmpty else { return }
        guard let url = URL(string: documentUrl) else { return }
        
        let contactsDir = getLocalContactsDirectory()
        let contactFile = contactsDir.appendingPathComponent("\(contactName)_\(contactPhone).vcf")
        
        // Check if already downloading
        if BackgroundDownloadManager.shared.isDownloading(fileName: contactFile.lastPathComponent) {
            print("📱 [Contact] Already downloading")
            return
        }
        
        // Light haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Update UI
        isDownloading = true
        showDownloadButton = false
        showDownloadProgress = true
        downloadProgress = 0.0
        
        // Use BackgroundDownloadManager for download
        BackgroundDownloadManager.shared.downloadImage(
            imageUrl: documentUrl,
            fileName: contactFile.lastPathComponent,
            destinationFile: contactFile,
            onProgress: { progress in
                DispatchQueue.main.async {
                    self.downloadProgress = progress
                    if progress > 0 {
                        self.showDownloadProgress = true
                    }
                }
            },
            onSuccess: {
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.showDownloadProgress = false
                    self.showDownloadButton = false
                    self.downloadProgress = 0.0
                    print("✅ [Contact] Contact VCF downloaded successfully")
                }
            },
            onFailure: { error in
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.showDownloadProgress = false
                    self.showDownloadButton = true
                    self.downloadProgress = 0.0
                    print("🚫 [Contact] Download failed: \(error.localizedDescription)")
                }
            }
        )
    }
    
    // Save contact to phone (matching Android save onClick)
    private func saveContactToPhone(firstName: String, lastName: String, phone: String) {
        let store = CNContactStore()
        
        // Request authorization
        store.requestAccess(for: .contacts) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    let contact = CNMutableContact()
                    
                    // Set name
                    contact.givenName = firstName
                    contact.familyName = lastName
                    
                    // Set phone
                    let phoneNumber = CNPhoneNumber(stringValue: phone)
                    let phoneValue = CNLabeledValue(label: CNLabelPhoneNumberMobile, value: phoneNumber)
                    contact.phoneNumbers = [phoneValue]
                    
                    // Save contact
                    let saveRequest = CNSaveRequest()
                    saveRequest.add(contact, toContainerWithIdentifier: nil)
                    
                    do {
                        try store.execute(saveRequest)
                        print("✅ [Contact] Contact saved successfully")
                        
                        // Save to local storage
                        saveContactToLocalStorage(firstName: firstName, lastName: lastName, phone: phone)
                        
                        // Update UI
                        isContactSaved = true
                        
                        // Show success message (matching Android Toast)
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = windowScene.windows.first {
                            let toast = UILabel()
                            toast.text = "Contact saved successfully"
                            toast.textColor = .white
                            toast.backgroundColor = UIColor.black.withAlphaComponent(0.7)
                            toast.textAlignment = .center
                            toast.layer.cornerRadius = 8
                            toast.clipsToBounds = true
                            toast.font = UIFont.systemFont(ofSize: 14)
                            toast.frame = CGRect(x: window.bounds.width / 2 - 100, y: window.bounds.height - 150, width: 200, height: 40)
                            window.addSubview(toast)
                            
                            UIView.animate(withDuration: 0.3, delay: 1.5, options: .curveEaseOut, animations: {
                                toast.alpha = 0
                            }) { _ in
                                toast.removeFromSuperview()
                            }
                        }
                    } catch {
                        print("🚫 [Contact] Failed to save contact: \(error.localizedDescription)")
                    }
                }
            } else {
                print("🚫 [Contact] Contact access denied")
            }
        }
    }
    
    // Save contact to local storage (matching Android local storage)
    private func saveContactToLocalStorage(firstName: String, lastName: String, phone: String) {
        let contactsDir = getLocalContactsDirectory()
        let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        let contactFile = contactsDir.appendingPathComponent("\(fullName.replacingOccurrences(of: " ", with: "_"))_\(phone).vcf")
        
        // Create VCF content
        let vcfContent = """
        BEGIN:VCARD
        VERSION:3.0
        FN:\(fullName)
        TEL;TYPE=CELL:\(phone)
        END:VCARD
        """
        
        do {
            try vcfContent.write(to: contactFile, atomically: true, encoding: .utf8)
            print("✅ [Contact] Contact saved to local storage: \(contactFile.path)")
        } catch {
            print("🚫 [Contact] Failed to save contact to local storage: \(error.localizedDescription)")
        }
    }
}

// MARK: - Sender Voice Audio View (matching Android sender miceContainer)
struct SenderVoiceAudioView: View {
    let audioUrl: String
    let audioTiming: String
    let micPhoto: String?
    let backgroundColor: Color
    
    @State private var audioPlayer: AVPlayer? = nil
    @State private var isPlaying: Bool = false
    @State private var currentTime: TimeInterval = 0.0
    @State private var duration: TimeInterval = 0.0
    @State private var audioTimeObserver: Any? = nil
    @State private var hasLocalFile: Bool = false
    @State private var showMusicPlayerBottomSheet: Bool = false
    
    // Get local audios directory
    private func getLocalAudiosDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audiosDir = documentsPath.appendingPathComponent("Enclosure/Media/Audios", isDirectory: true)
        try? FileManager.default.createDirectory(at: audiosDir, withIntermediateDirectories: true, attributes: nil)
        return audiosDir
    }
    
    // Check if audio file exists locally
    private func checkLocalFile() {
        guard !audioUrl.isEmpty else { return }
        let fileName = extractFileName(from: audioUrl)
        let localFile = getLocalAudiosDirectory().appendingPathComponent(fileName)
        hasLocalFile = FileManager.default.fileExists(atPath: localFile.path)
    }
    
    // Extract filename from URL
    private func extractFileName(from urlString: String) -> String {
        guard let url = URL(string: urlString) else { return (urlString as NSString).lastPathComponent }
        let lastPathComponent = url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent
        if let queryIndex = lastPathComponent.firstIndex(of: "?") {
            return String(lastPathComponent[..<queryIndex])
        }
        return lastPathComponent
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main container - matching Android miceContainer LinearLayout
            // Android: layout_marginHorizontal="7dp", layout_marginVertical="7dp", orientation="vertical", gravity="center"
            VStack(spacing: 0) {
                // Inner container - matching Android inner LinearLayout
                // Android: layout_width="wrap_content", backgroundTint="#021D3A", orientation="horizontal", layout_marginHorizontal="3dp"
                HStack(alignment: .center, spacing: 0) {
                    // Download controls (optional) - matching Android audioDownloadControls RelativeLayout
                    // Note: Download controls are typically hidden for sender (already sent)
                    
                    // Play button - matching Android micePlay AppCompatImageButton
                    // Android: layout_marginEnd="5dp", scaleX="1.4", scaleY="1.4", src="@drawable/play_arrow_sender"
                    Button(action: {
                        openMusicPlayer()
                    }) {
                        Image("play_arrow_sender")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .scaleEffect(1.4) // Android: scaleX="1.4", scaleY="1.4"
                    }
                    .padding(.trailing, 5) // Android: layout_marginEnd="5dp"
                    
                    // Vertical container for progress bar and timing - vertically centered
                    VStack(spacing: 0) {
                        // Progress bar - matching Android miceProgressbar LinearProgressIndicator
                        // Android: layout_marginTop="19dp", indicatorColor="@color/teal_700", trackCornerRadius="20dp", trackThickness="5dp"
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 20) // Android: trackCornerRadius="20dp"
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 5) // Android: trackThickness="5dp"
                                
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(hex: "#018786")) // Android: indicatorColor="@color/teal_700"
                                    .frame(width: geometry.size.width * CGFloat(duration > 0 ? currentTime / duration : 0), height: 5)
                            }
                        }
                        .frame(height: 5)
                        .padding(.top, 19) // Android: layout_marginTop="19dp"
                        
                        // Timing text - matching Android miceTiming TextView
                        // Android: layout_marginTop="5dp", textColor="#e7ebf4", textSize="10sp", fontFamily="@font/inter", layout_gravity="start"
                        // Display miceTiming (duration) from message, not current playback time
                        Text(audioTiming)
                            .font(.custom("Inter18pt-Regular", size: 10)) // Android: fontFamily="@font/inter", textSize="10sp"
                            .foregroundColor(Color(hex: "#e7ebf4")) // Android: textColor="#e7ebf4"
                            .frame(maxWidth: .infinity, alignment: .leading) // Android: layout_gravity="start"
                            .padding(.top, 5) // Android: layout_marginTop="5dp"
                    }
                    .frame (minWidth: 150) // Android: minWidth="150dp"
                    .padding(.horizontal, 5) // Android: layout_marginHorizontal="5dp"
                    .frame(maxHeight: .infinity, alignment: .center) // Vertically center with play button
                }
                .padding(.horizontal, 3) // Android: layout_marginHorizontal="3dp"
               
            }
            .padding(.horizontal, 7) // Android: layout_marginHorizontal="7dp"
            .padding(.vertical, 7) // Android: layout_marginVertical="7dp"
        }
        .sheet(isPresented: $showMusicPlayerBottomSheet) {
            MusicPlayerBottomSheet(
                audioUrl: audioUrl,
                profileImageUrl: micPhoto ?? "",
                songTitle: extractFileName(from: audioUrl)
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            checkLocalFile()
            if hasLocalFile {
                setupAudioPlayer()
            }
        }
        .onDisappear {
            stopAudioPlayer()
        }
    }
    
    // Open music player bottom sheet
    private func openMusicPlayer() {
        print("🎵 [SenderVoiceAudioView] Opening music player - audioUrl: \(audioUrl)")
        showMusicPlayerBottomSheet = true
    }
    
    // Format time
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // Setup audio player
    private func setupAudioPlayer() {
        guard !audioUrl.isEmpty else { return }
        
        let fileName = extractFileName(from: audioUrl)
        let localFile = getLocalAudiosDirectory().appendingPathComponent(fileName)
        
        let playerURL: URL
        if hasLocalFile && FileManager.default.fileExists(atPath: localFile.path) {
            playerURL = localFile
        } else if let url = URL(string: audioUrl) {
            playerURL = url
        } else {
            return
        }
        
        audioPlayer = AVPlayer(url: playerURL)
        
        // Get duration
        if let durationValue = audioPlayer?.currentItem?.asset.duration {
            let durationSeconds = CMTimeGetSeconds(durationValue)
            if !durationSeconds.isNaN && durationSeconds.isFinite {
                duration = durationSeconds
            }
        }
        
        // Add time observer
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        audioTimeObserver = audioPlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [self] time in
            let timeSeconds = CMTimeGetSeconds(time)
            if !timeSeconds.isNaN && timeSeconds.isFinite {
                currentTime = timeSeconds
            }
        }
        
        // Listen for playback end
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: audioPlayer?.currentItem,
            queue: .main
        ) { [self] _ in
            isPlaying = false
            currentTime = 0.0
            audioPlayer?.seek(to: .zero)
        }
    }
    
    // Toggle playback
    private func togglePlayback() {
        guard let player = audioPlayer else {
            setupAudioPlayer()
            return
        }
        
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }
    
    // Stop audio player
    private func stopAudioPlayer() {
        audioPlayer?.pause()
        audioPlayer = nil
        isPlaying = false
        currentTime = 0.0
        duration = 0.0
        if let observer = audioTimeObserver {
            audioPlayer?.removeTimeObserver(observer)
            audioTimeObserver = nil
        }
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Receiver Voice Audio View (matching Android receiver miceContainer)
struct ReceiverVoiceAudioView: View {
    @Environment(\.colorScheme) var colorScheme
    let audioUrl: String
    let audioTiming: String
    let micPhoto: String?
    
    @State private var audioPlayer: AVPlayer? = nil
    @State private var isPlaying: Bool = false
    @State private var currentTime: TimeInterval = 0.0
    @State private var duration: TimeInterval = 0.0
    @State private var audioTimeObserver: Any? = nil
    @State private var hasLocalFile: Bool = false
    @State private var showDownloadButton: Bool = false
    @State private var isDownloading: Bool = false
    @State private var downloadProgress: Double = 0.0
    @State private var showDownloadProgress: Bool = false
    @State private var showMusicPlayerBottomSheet: Bool = false
    
    // Get local audios directory
    private func getLocalAudiosDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audiosDir = documentsPath.appendingPathComponent("Enclosure/Media/Audios", isDirectory: true)
        try? FileManager.default.createDirectory(at: audiosDir, withIntermediateDirectories: true, attributes: nil)
        return audiosDir
    }
    
    // Check if audio file exists locally
    private func checkLocalFile() {
        guard !audioUrl.isEmpty else { return }
        let fileName = extractFileName(from: audioUrl)
        let localFile = getLocalAudiosDirectory().appendingPathComponent(fileName)
        hasLocalFile = FileManager.default.fileExists(atPath: localFile.path)
    }
    
    // Extract filename from URL
    private func extractFileName(from urlString: String) -> String {
        guard let url = URL(string: urlString) else { return (urlString as NSString).lastPathComponent }
        let lastPathComponent = url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent
        if let queryIndex = lastPathComponent.firstIndex(of: "?") {
            return String(lastPathComponent[..<queryIndex])
        }
        return lastPathComponent
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main container - matching Android miceContainer LinearLayout
            // Android: layout_width="wrap_content", layout_marginHorizontal="7dp", layout_marginVertical="7dp", orientation="vertical", gravity="center"
            VStack(spacing: 0) {
                // Inner container - matching Android inner LinearLayout
                // Android: layout_width="wrap_content", orientation="horizontal", layout_gravity="center", gravity="center"
                HStack(alignment: .center, spacing: 0) {
                    // Download controls - matching Android audioDownloadControlsReceiver RelativeLayout
                    // Android: layout_marginEnd="7dp"
                    if !hasLocalFile && !isDownloading {
                        Button(action: {
                            downloadAudio()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 35, height: 35)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                                
                                Image("downloaddown")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.trailing, 7) // Android: layout_marginEnd="7dp"
                    }
                    
                    // Play button - matching Android micePlay AppCompatImageButton
                    // Android: scaleX="1.4", scaleY="1.4", src="@drawable/play_arrow_receiver", tint="@color/TextColor"
                    Button(action: {
                        openMusicPlayer()
                    }) {
                        Image("play_arrow_receiver")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundColor(Color("TextColor")) // Android: tint="@color/TextColor"
                            .scaleEffect(1.4) // Android: scaleX="1.4", scaleY="1.4"
                    }
                    
                    // Vertical container for progress bar and timing - vertically centered
                    VStack(spacing: 0) {
                        // Progress bar - matching Android miceProgressbar LinearProgressIndicator
                        // Android: layout_marginTop="19dp", indicatorColor="@color/teal_700", trackCornerRadius="20dp", trackThickness="5dp"
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 20) // Android: trackCornerRadius="20dp"
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 5) // Android: trackThickness="5dp"
                                
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(hex: "#018786")) // Android: indicatorColor="@color/teal_700"
                                    .frame(width: geometry.size.width * CGFloat(duration > 0 ? currentTime / duration : 0), height: 5)
                            }
                        }
                        .frame(height: 5)
                        .padding(.top, 19) // Android: layout_marginTop="19dp"
                        
                        // Timing text - matching Android miceTiming TextView
                        // Android: layout_marginTop="5dp", style="@style/TextColor", textSize="10sp", fontFamily="@font/inter", layout_gravity="start"
                        // Display miceTiming (duration) from message, not current playback time
                        Text(audioTiming)
                            .font(.custom("Inter18pt-Regular", size: 10)) // Android: fontFamily="@font/inter", textSize="10sp"
                            .foregroundColor(Color("TextColor")) // Android: style="@style/TextColor"
                            .frame(maxWidth: .infinity, alignment: .leading) // Android: layout_gravity="start"
                            .padding(.top, 5) // Android: layout_marginTop="5dp"
                    }
                    .frame(minWidth: 150) // Android: minWidth="150dp"
                    .padding(.horizontal, 5) // Android: layout_marginHorizontal="5dp"
                    .frame(maxHeight: .infinity, alignment: .center) // Vertically center with play button
                }
            }
            .padding(.horizontal, 7) // Android: layout_marginHorizontal="7dp"
            .padding(.vertical, 7) // Android: layout_marginVertical="7dp"
        }
        .sheet(isPresented: $showMusicPlayerBottomSheet) {
            MusicPlayerBottomSheet(
                audioUrl: audioUrl,
                profileImageUrl: micPhoto ?? "",
                songTitle: extractFileName(from: audioUrl)
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            checkLocalFile()
            if hasLocalFile {
                setupAudioPlayer()
            } else if !audioUrl.isEmpty {
                showDownloadButton = true
            }
        }
        .onDisappear {
            stopAudioPlayer()
        }
    }
    
    // Open music player bottom sheet
    private func openMusicPlayer() {
        print("🎵 [ReceiverVoiceAudioView] Opening music player - audioUrl: \(audioUrl)")
        showMusicPlayerBottomSheet = true
    }
    
    // Format time
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // Setup audio player
    private func setupAudioPlayer() {
        guard !audioUrl.isEmpty else { return }
        
        let fileName = extractFileName(from: audioUrl)
        let localFile = getLocalAudiosDirectory().appendingPathComponent(fileName)
        
        let playerURL: URL
        if hasLocalFile && FileManager.default.fileExists(atPath: localFile.path) {
            playerURL = localFile
        } else if let url = URL(string: audioUrl) {
            playerURL = url
        } else {
            return
        }
        
        audioPlayer = AVPlayer(url: playerURL)
        
        // Get duration
        if let durationValue = audioPlayer?.currentItem?.asset.duration {
            let durationSeconds = CMTimeGetSeconds(durationValue)
            if !durationSeconds.isNaN && durationSeconds.isFinite {
                duration = durationSeconds
            }
        }
        
        // Add time observer
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        audioTimeObserver = audioPlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [self] time in
            let timeSeconds = CMTimeGetSeconds(time)
            if !timeSeconds.isNaN && timeSeconds.isFinite {
                currentTime = timeSeconds
            }
        }
        
        // Listen for playback end
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: audioPlayer?.currentItem,
            queue: .main
        ) { [self] _ in
            isPlaying = false
            currentTime = 0.0
            audioPlayer?.seek(to: .zero)
        }
    }
    
    // Toggle playback
    private func togglePlayback() {
        guard let player = audioPlayer else {
            setupAudioPlayer()
            return
        }
        
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }
    
    // Download audio
    private func downloadAudio() {
        guard !audioUrl.isEmpty else { return }
        guard let url = URL(string: audioUrl) else { return }
        
        let fileName = extractFileName(from: audioUrl)
        let audiosDir = getLocalAudiosDirectory()
        let audioFile = audiosDir.appendingPathComponent(fileName)
        
        // Check if already downloading
        if BackgroundDownloadManager.shared.isDownloading(fileName: fileName) {
            print("🎤 [VoiceAudio] Already downloading")
            return
        }
        
        // Light haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Update UI
        isDownloading = true
        showDownloadButton = false
        showDownloadProgress = true
        downloadProgress = 0.0
        
        // Use BackgroundDownloadManager for download
        BackgroundDownloadManager.shared.downloadImage(
            imageUrl: audioUrl,
            fileName: fileName,
            destinationFile: audioFile,
            onProgress: { progress in
                DispatchQueue.main.async {
                    self.downloadProgress = progress
                    if progress > 0 {
                        self.showDownloadProgress = true
                    }
                }
            },
            onSuccess: {
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.showDownloadProgress = false
                    self.showDownloadButton = false
                    self.downloadProgress = 0.0
                    self.hasLocalFile = true
                    self.setupAudioPlayer()
                    print("✅ [VoiceAudio] Audio downloaded successfully")
                }
            },
            onFailure: { error in
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.showDownloadProgress = false
                    self.showDownloadButton = true
                    self.downloadProgress = 0.0
                    print("🚫 [VoiceAudio] Download failed: \(error.localizedDescription)")
                }
            }
        )
    }
    
    // Stop audio player
    private func stopAudioPlayer() {
        audioPlayer?.pause()
        audioPlayer = nil
        isPlaying = false
        currentTime = 0.0
        duration = 0.0
        if let observer = audioTimeObserver {
            audioPlayer?.removeTimeObserver(observer)
            audioTimeObserver = nil
        }
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Contact Action Bottom Sheet (matching Android view_contact_btmsheet_lyt.xml)
struct ContactActionBottomSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    let contactName: String
    let contactPhone: String
    let onCreateContact: () -> Void
    let onDismiss: () -> Void
    
    private var themeColor: Color {
        Color(hex: Constant.themeColor)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main container - matching Android outer LinearLayout (vertical)
            VStack(spacing: 0) {
                // CardView container - matching Android CardView
                // Android: style="@style/cardBackgroundColor" (which is cardBackgroundColornew)
                // Android: app:cardCornerRadius="20dp"
                // Android: layout_marginHorizontal="16dp", layout_marginTop="20dp", layout_marginBottom="20dp"
                VStack(spacing: 0) {
                    // Create New Contact button - matching Android createContact TextView
                    // Android: android:background="@drawable/background_effect_for_chattting_hover_all" (which uses cardBackgroundColornew)
                    // Android: android:padding="15dp", android:textSize="14sp", style="@style/TextColor", android:textStyle="bold"
                    Button(action: {
                        onCreateContact()
                        dismiss()
                    }) {
                        Text("Create New Contact")
                            .font(.custom("Inter18pt-Bold", size: 14)) // Android: android:fontFamily="@font/inter_bold", android:textSize="14sp", android:textStyle="bold"
                            .foregroundColor(Color("TextColor")) // Android: style="@style/TextColor"
                            .frame(maxWidth: .infinity) // Android: android:layout_width="match_parent"
                            .padding(15) // Android: android:padding="15dp" (all sides)
                            .background(
                                RoundedRectangle(cornerRadius: 20) // 20dp corner radius for the button
                                    .fill(Color("cardBackgroundColornew")) // Android: android:background="@drawable/background_effect_for_chattting_hover_all"
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .background(
                    RoundedRectangle(cornerRadius: 20) // Android: app:cardCornerRadius="20dp"
                        .fill(Color("cardBackgroundColornew")) // Android: style="@style/cardBackgroundColor"
                )
                .padding(.horizontal, 16) // Android: layout_marginHorizontal="16dp"
                .padding(.top, 20) // Android: layout_marginTop="20dp"
                .padding(.bottom, 20) // Android: layout_marginBottom="20dp"
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color("chattingMessageBox")) // Bottom sheet background
    }
}

// MARK: - Create Contact Bottom Sheet (matching Android create_contact_layout_bottom.xml)
struct CreateContactBottomSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    let contactName: String
    let contactPhone: String
    let onSave: (String, String, String) -> Void
    let onDismiss: () -> Void
    
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var phone: String = ""
    @FocusState private var isFirstNameFocused: Bool
    @FocusState private var isLastNameFocused: Bool
    @FocusState private var isPhoneFocused: Bool
    
    private var themeColor: Color {
        Color(hex: Constant.themeColor)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header - matching Android header LinearLayout
            // Android: layout_marginTop="20dp", orientation="horizontal"
            HStack {
                // Cancel button - matching Android cancel TextView
                // Android: layout_marginStart="20dp", layout_weight="1"
                Button(action: {
                    onDismiss()
                    dismiss()
                }) {
                    Text("cancel")
                        .font(.custom("Inter18pt-Medium", size: 15)) // Android: android:fontFamily="@font/inter_medium", android:textSize="15sp"
                        .foregroundColor(themeColor) // Android: android:textColor="@color/bluetohovertext"
                }
                .frame(maxWidth: .infinity, alignment: .leading) // Android: layout_weight="1"
                .padding(.leading, 20) // Android: layout_marginStart="20dp"
                
                // Title - matching Android "New Contact" TextView
                // Android: layout_weight="1", layout_gravity="center", gravity="center"
                Text("New Contact")
                    .font(.custom("Inter18pt-Bold", size: 16)) // Android: android:fontFamily="@font/inter_bold", android:textSize="16dp"
                    .foregroundColor(Color("TextColor")) // Android: style="@style/TextColor"
                    .frame(maxWidth: .infinity) // Android: layout_weight="1"
                
                // Save button - matching Android save TextView
                // Android: layout_marginEnd="20dp", layout_weight="1", gravity="end"
                Button(action: {
                    saveContact()
                }) {
                    Text("Save")
                        .font(.custom("Inter18pt-Medium", size: 15)) // Android: android:fontFamily="@font/inter_medium", android:textSize="15sp"
                        .foregroundColor(themeColor) // Android: android:textColor="@color/bluetohovertext"
                }
                .frame(maxWidth: .infinity, alignment: .trailing) // Android: layout_weight="1", gravity="end"
                .padding(.trailing, 20) // Android: layout_marginEnd="20dp"
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20) // Android: layout_marginTop="20dp" on header LinearLayout
            
            // First Name CardView - matching Android CardView with cardCornerRadius="8dp"
            VStack(spacing: 0) {
                TextField("First Name", text: $firstName)
                    .font(.custom("Inter18pt-Bold", size: 14))
                    .foregroundColor(Color("TextColor"))
                    .focused($isFirstNameFocused)
                    .padding(.vertical, 15)
                    .padding(.horizontal, 15)
                    .background(Color("background_effect_for_chattting_hover_all"))
                
                // Divider - matching Android View with height="0.5dp"
                Rectangle()
                    .fill(Color("gray3"))
                    .frame(height: 0.5)
                
                TextField("Last Name", text: $lastName)
                    .font(.custom("Inter18pt-Bold", size: 14))
                    .foregroundColor(Color("TextColor"))
                    .focused($isLastNameFocused)
                    .padding(.vertical, 15)
                    .padding(.horizontal, 15)
                    .background(Color("background_effect_for_chattting_hover_all"))
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "#E2E4EA"))
            )
            .padding(.horizontal, 16)
            .padding(.top, 20)
            
            // Phone CardView - matching Android CardView with cardCornerRadius="8dp"
            HStack(spacing: 0) {
                // Mobile label - matching Android mobile TextView
                Text("Mobile")
                    .font(.custom("Inter18pt-Medium", size: 14))
                    .foregroundColor(themeColor)
                    .padding(.leading, 15)
                    .padding(.vertical, 15)
                    .background(Color("background_effect_for_chattting_hover_all"))
                
                // Chevron icon - matching Android ImageView
                Image("baseline_chevron_right_24")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(Color("icon_tints"))
                    .padding(.horizontal, 8)
                    .background(Color("background_effect_for_chattting_hover_all"))
                
                // Phone TextField - matching Android phoneNumber EditText
                TextField("Phone", text: $phone)
                    .font(.custom("Inter18pt-Bold", size: 14))
                    .foregroundColor(Color("TextColor"))
                    .focused($isPhoneFocused)
                    .keyboardType(.phonePad)
                    .padding(.leading, 7)
                    .padding(.vertical, 15)
                    .background(Color("background_effect_for_chattting_hover_all"))
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "#E2E4EA"))
            )
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color("chattingMessageBox"))
        )
        .onAppear {
            // Pre-fill fields from contact data (matching Android logic)
            let nameParts = contactName.components(separatedBy: " ")
            firstName = nameParts.first ?? ""
            if nameParts.count > 1 {
                lastName = nameParts.dropFirst().joined(separator: " ")
            }
            phone = contactPhone
        }
    }
    
    private func saveContact() {
        guard !firstName.isEmpty || !lastName.isEmpty, !phone.isEmpty else { return }
        onSave(firstName, lastName, phone)
        dismiss()
    }
}

// MARK: - Contact Picker View Controller Wrapper (for adding to existing contact)
struct ContactPickerViewControllerWrapper: UIViewControllerRepresentable {
    let phoneNumber: String
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(phoneNumber: phoneNumber, onDismiss: onDismiss)
    }
    
    class Coordinator: NSObject, CNContactPickerDelegate {
        let phoneNumber: String
        let onDismiss: () -> Void
        
        init(phoneNumber: String, onDismiss: @escaping () -> Void) {
            self.phoneNumber = phoneNumber
            self.onDismiss = onDismiss
        }
        
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            // Add phone number to selected contact
            let store = CNContactStore()
            let mutableContact = contact.mutableCopy() as! CNMutableContact
            
            let phoneNumberValue = CNPhoneNumber(stringValue: phoneNumber)
            let phoneValue = CNLabeledValue(label: CNLabelPhoneNumberMobile, value: phoneNumberValue)
            mutableContact.phoneNumbers.append(phoneValue)
            
            let saveRequest = CNSaveRequest()
            saveRequest.update(mutableContact)
            
            do {
                try store.execute(saveRequest)
                print("✅ [Contact] Phone number added to existing contact")
            } catch {
                print("🚫 [Contact] Failed to add phone number: \(error.localizedDescription)")
            }
            
            picker.dismiss(animated: true) {
                self.onDismiss()
            }
        }
        
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            picker.dismiss(animated: true) {
                self.onDismiss()
            }
        }
    }
}

// MARK: - URL Detection Helper
extension String {
    /// Check if string is a valid URL (matching Android URLUtil.isValidUrl)
    func isValidURL() -> Bool {
        guard !self.isEmpty else { return false }
        guard let url = URL(string: self.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
        return url.scheme != nil && url.host != nil
    }
    
    /// Extract URL from text if present
    func extractURL() -> String? {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isValidURL() {
            return trimmed
        }
        // Try to find URL in text using regex
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count))
        return matches?.first?.url?.absoluteString
    }
}

// MARK: - Link Preview Image View Helper
struct LinkPreviewImageView: View {
    let imageUrlString: String
    let width: CGFloat
    let height: CGFloat
    
    private var imageURL: URL? {
        // Support local file paths as well as remote URLs
        if imageUrlString.hasPrefix("file://"), let url = URL(string: imageUrlString) {
            return url
        }
        if FileManager.default.fileExists(atPath: imageUrlString) {
            return URL(fileURLWithPath: imageUrlString)
        }
        if let url = URL(string: imageUrlString) {
            return url
        } else if let encoded = imageUrlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: encoded) {
            return url
        }
        return nil
    }
    
    @ViewBuilder
    var body: some View {
        if let imageURL = imageURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        Color.black
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: height)
                case .failure(let error):
                    let _ = print("🚫 [LinkPreview] Failed to load image from \(imageUrlString): \(error.localizedDescription)")
                    DefaultLinkIconView(width: width, height: height)
                @unknown default:
                    DefaultLinkIconView(width: width, height: height)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()
            .onAppear {
                print("🖼️ [LinkPreview] Loading image from: \(imageUrlString)")
            }
        } else {
            let _ = print("⚠️ [LinkPreview] Invalid image URL string: \(imageUrlString)")
            DefaultLinkIconView(width: width, height: height)
        }
    }
}

// MARK: - Default Link Icon View Helper
struct DefaultLinkIconView: View {
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        ZStack {
            Color.black
            Image(systemName: "link")
                .resizable()
                .scaledToFit()
                .foregroundColor(.white)
                .padding(20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }
}

// MARK: - Link Preview Caching Helpers
private struct LinkPreviewCacheEntry: Codable {
    let title: String?
    let description: String?
    let imagePath: String?
    let favIconPath: String?
}

private func linkPreviewCacheDirectory() -> URL {
    let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    let dir = base.appendingPathComponent("LinkPreviewCache", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

private func safeFileName(for url: String) -> String {
    let allowed = CharacterSet.alphanumerics
    let replaced = url.unicodeScalars.map { allowed.contains($0) ? String($0) : "_" }.joined()
    return replaced.isEmpty ? "link_preview" : replaced
}

private func cacheFilePath(for url: String) -> URL {
    linkPreviewCacheDirectory().appendingPathComponent("\(safeFileName(for: url)).json")
}

private func loadCachedLinkPreview(for url: String) -> LinkPreviewCacheEntry? {
    let path = cacheFilePath(for: url)
    guard FileManager.default.fileExists(atPath: path.path),
          let data = try? Data(contentsOf: path) else { return nil }
    return try? JSONDecoder().decode(LinkPreviewCacheEntry.self, from: data)
}

private func saveCachedLinkPreview(for url: String, title: String?, description: String?, imagePath: String?, favIconPath: String?) {
    let entry = LinkPreviewCacheEntry(title: title, description: description, imagePath: imagePath, favIconPath: favIconPath)
    let path = cacheFilePath(for: url)
    if let data = try? JSONEncoder().encode(entry) {
        try? data.write(to: path)
    }
}

private func cacheImageIfNeeded(from urlString: String) -> String? {
    guard !urlString.isEmpty else { return nil }
    
    // If already a local file path, just return it
    if urlString.hasPrefix("file://") {
        return urlString
    }
    if FileManager.default.fileExists(atPath: urlString) {
        return urlString
    }
    
    guard let url = URL(string: urlString) else { return nil }
    let ext = url.pathExtension.isEmpty ? "img" : url.pathExtension
    let localPath = linkPreviewCacheDirectory().appendingPathComponent("\(safeFileName(for: urlString)).\(ext)")
    
    if FileManager.default.fileExists(atPath: localPath.path) {
        return localPath.path
    }
    
    if let data = try? Data(contentsOf: url) {
        try? data.write(to: localPath)
        return localPath.path
    }
    return nil
}

private func urlFromStringAllowFile(_ value: String) -> URL? {
    if value.hasPrefix("file://") {
        return URL(string: value)
    }
    if FileManager.default.fileExists(atPath: value) {
        return URL(fileURLWithPath: value)
    }
    return URL(string: value)
}

// MARK: - Sender Rich Link View (matching Android sender richLinkViewLyt)
struct SenderRichLinkView: View {
    @Environment(\.colorScheme) var colorScheme
    let url: String
    let backgroundColor: Color
    let linkTitle: String?
    let linkDescription: String?
    let linkImageUrl: String?
    let favIconUrl: String?
    
    @State private var showFullPreview: Bool = false
    @State private var fetchedTitle: String? = nil
    @State private var fetchedDescription: String? = nil
    @State private var fetchedImageUrl: String? = nil
    @State private var fetchedFavIconUrl: String? = nil
    @State private var isFetching: Bool = false
    
    private var themeColor: Color {
        Color(hex: Constant.themeColor)
    }
    
    // Get sender message background color (matching Constant.Text messages)
    private var senderMessageBackgroundColor: Color {
        // Light mode: always use legacy bubble color (#011224) to match Android light theme
        guard colorScheme == .dark else {
            return Color(hex: "#011224")
        }
        
        // Dark mode: use theme-based tinted backgrounds (matching Android)
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
    
    @ViewBuilder
    private var linkImageView: some View {
        let imageUrlString = linkImageUrl ?? fetchedImageUrl
        let _ = print("🖼️ [LinkPreview] linkImageView - linkImageUrl: \(linkImageUrl ?? "nil"), fetchedImageUrl: \(fetchedImageUrl ?? "nil")")
        if let imageUrlString = imageUrlString, !imageUrlString.isEmpty {
            LinkPreviewImageView(imageUrlString: imageUrlString, width: 180, height: 100)
        } else {
            let _ = print("⚠️ [LinkPreview] No image URL available - linkImageUrl: \(linkImageUrl ?? "nil"), fetchedImageUrl: \(fetchedImageUrl ?? "nil")")
            DefaultLinkIconView(width: 180, height: 100)
        }
    }
    
    @ViewBuilder
    var body: some View {
        Group {
            // If no preview data, show just the URL as underlined text (matching Android linkActualUrl)
            // Android: when linkPreviewModel.getUrl().equals(""), show linkActualUrl only
            if !showFullPreview {
                // Link actual URL - matching Android linkActualUrl TextView (when no preview data)
                // Android: textColor="@color/blue", textSize="15sp", fontFamily="@font/inter", maxWidth="210dp", textFontWeight="400"
                // Android: layout_marginHorizontal="2dp"
                Text(url)
                    .font(.custom("Inter18pt-Regular", size: 15))
                    .fontWeight(.regular)
                    .foregroundColor(themeColor)
                    .frame(maxWidth: 210, alignment: .leading)
                    .underline()
                    .padding(.horizontal, 2)
                    .onTapGesture {
                        if let url = URL(string: self.url) {
                            UIApplication.shared.open(url)
                        }
                    }
            } else {
                // Full rich link preview (matching Android when linkPreviewModel has data)
                VStack(spacing: 0) {
                    // Main container - matching Android CardView
                    // Android: cardBackgroundColor="#e7ebf4", cardCornerRadius="20dp", cardElevation="0dp"
                    VStack(spacing: 0) {
                        // Link image - matching Android linkImg ImageView
                        // Android: layout_width="180dp", layout_height="100dp", background="#000000", scaleType="centerCrop"
                        linkImageView
                            .frame(maxWidth: .infinity)
                        
                        // Rich box - matching Android richBox LinearLayout
                        // Android: background="@color/appThemeColor", orientation="vertical"
                        VStack(spacing: 0) {
                            // Inner container - matching Android inner LinearLayout
                            // Android: background="@drawable/custome_ripple_chatting", padding="10dp", orientation="vertical"
                            VStack(alignment: .leading, spacing: 0) {
                                // Link title - matching Android linkTitle TextView
                                // Android: textColor="#e7ebf4", textSize="15sp", fontFamily="@font/inter", maxWidth="210dp", singleLine="true"
                                if let title = (linkTitle ?? fetchedTitle), !title.isEmpty {
                                    Text(title)
                                        .font(.custom("Inter18pt-Regular", size: 15))
                                        .foregroundColor(Color(hex: "#e7ebf4"))
                                        .lineLimit(1)
                                        .frame(maxWidth: 210, alignment: .leading)
                                        .padding(.bottom, 2)
                                }
                                
                                // Link description - matching Android linkDesc TextView
                                // Android: textColor="@color/gray", textSize="13sp", fontFamily="@font/inter", maxWidth="210dp", maxLines="2"
                                if let desc = (linkDescription ?? fetchedDescription), !desc.isEmpty {
                                    Text(desc)
                                        .font(.custom("Inter18pt-Regular", size: 13))
                                        .foregroundColor(Color("gray"))
                                        .lineLimit(2)
                                        .frame(maxWidth: 210, alignment: .leading)
                                        .padding(.bottom, 2)
                                }
                                
                                // Link URL with favicon - matching Android HStack with linkImg2 and link
                                // Android: orientation="horizontal", gravity="center_vertical"
                                HStack(alignment: .center, spacing: 5) {
                                    // Favicon - matching Android linkImg2 ImageView
                                    // Android: layout_width="15dp", layout_height="15dp", layout_marginEnd="5dp"
                                    if let favIcon = (favIconUrl ?? fetchedFavIconUrl), !favIcon.isEmpty {
                                        AsyncImage(url: urlFromStringAllowFile(favIcon)) { phase in
                                            switch phase {
                                            case .empty:
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: themeColor))
                                                    .frame(width: 15, height: 15)
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .scaledToFit()
                                            case .failure:
                                                Image(systemName: "link.circle.fill")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .foregroundColor(themeColor)
                                            @unknown default:
                                                Image(systemName: "link.circle.fill")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .foregroundColor(themeColor)
                                            }
                                        }
                                        .frame(width: 15, height: 15)
                                    } else {
                                        Image(systemName: "link.circle.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .foregroundColor(themeColor)
                                            .frame(width: 15, height: 15)
                                    }
                                    
                                    // Link URL - matching Android link TextView
                                    // Android: textColor="@color/blue", textSize="13sp", fontFamily="@font/inter", maxWidth="210dp", singleLine="true", linksClickable="true"
                                    Text(url)
                                        .font(.custom("Inter18pt-Regular", size: 13))
                                        .foregroundColor(themeColor)
                                        .lineLimit(1)
                                        .frame(maxWidth: 210, alignment: .leading)
                                        .underline()
                                        .onTapGesture {
                                            if let url = URL(string: self.url) {
                                                UIApplication.shared.open(url)
                                            }
                                        }
                                }
                                .padding(.bottom, 1)
                            }
                            .padding(10)
                            .background(senderMessageBackgroundColor) // Matching Constant.Text/Constant.doc sender message background
                        }
                        .background(themeColor) // Android: background="@color/appThemeColor"
                    }
                    .background(senderMessageBackgroundColor) // Android: cardBackgroundColor matching Constant.Text messages
                    .clipShape(RoundedRectangle(cornerRadius: 20)) // Android: cardCornerRadius="20dp"
                    .onTapGesture {
                        if let url = URL(string: self.url) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }
        }
        .onAppear {
            // Load cached preview immediately (offline / instant show)
            applyCachedPreviewIfAvailable()
            // Check if we have link preview data (from message)
            let hasTitle = linkTitle != nil && !linkTitle!.isEmpty
            let hasDesc = linkDescription != nil && !linkDescription!.isEmpty
            let hasImage = linkImageUrl != nil && !linkImageUrl!.isEmpty
            let hasFavIcon = favIconUrl != nil && !favIconUrl!.isEmpty
            
            if hasTitle || hasDesc || hasImage || hasFavIcon {
                // We have preview data from message, show it
                showFullPreview = true
                print("✅ [LinkPreview] Using message data - Title: \(linkTitle ?? "nil"), Image: \(linkImageUrl ?? "nil")")
            } else {
                // No preview data, try to fetch it
                print("🔍 [LinkPreview] No message data, fetching preview for: \(url)")
                fetchLinkPreview()
            }
        }
        .onChange(of: fetchedTitle) { _ in
            // Update preview when fetched data changes
            if fetchedTitle != nil || fetchedDescription != nil || fetchedImageUrl != nil || fetchedFavIconUrl != nil {
                showFullPreview = true
                print("✅ [LinkPreview] onChange - Setting showFullPreview to true")
            }
        }
        .onChange(of: fetchedDescription) { _ in
            if fetchedTitle != nil || fetchedDescription != nil || fetchedImageUrl != nil || fetchedFavIconUrl != nil {
                showFullPreview = true
            }
        }
        .onChange(of: fetchedImageUrl) { _ in
            if fetchedTitle != nil || fetchedDescription != nil || fetchedImageUrl != nil || fetchedFavIconUrl != nil {
                showFullPreview = true
            }
        }
        .onChange(of: fetchedFavIconUrl) { _ in
            if fetchedTitle != nil || fetchedDescription != nil || fetchedImageUrl != nil || fetchedFavIconUrl != nil {
                showFullPreview = true
            }
        }
    }
    
    // Load cached preview data (including locally stored images) for instant display
    private func applyCachedPreviewIfAvailable() {
        guard let cache = loadCachedLinkPreview(for: url) else { return }
        fetchedTitle = cache.title
        fetchedDescription = cache.description
        fetchedImageUrl = cache.imagePath
        fetchedFavIconUrl = cache.favIconPath
        if cache.title != nil || cache.description != nil || cache.imagePath != nil || cache.favIconPath != nil {
            showFullPreview = true
        }
    }
    
    private func fetchLinkPreview() {
        guard !isFetching, let urlToFetch = URL(string: url) else { return }
        isFetching = true
        
        print("🔍 [LinkPreview] Fetching preview for: \(url)")
        print("🔍 [LinkPreview] URL host: \(urlToFetch.host ?? "nil"), path: \(urlToFetch.path)")
        
        // Create a URL request
        var request = URLRequest(url: urlToFetch)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let html = String(data: data, encoding: .utf8),
                  error == nil else {
                print("🚫 [LinkPreview] Failed to fetch HTML: \(error?.localizedDescription ?? "unknown error")")
                DispatchQueue.main.async {
                    self.isFetching = false
                }
                return
            }
            
            // Parse Open Graph and meta tags
            var title: String? = nil
            var description: String? = nil
            var imageUrl: String? = nil
            var favIconUrl: String? = nil
            
            // Helper function to extract content from meta tags
            func extractMetaContent(html: String, property: String) -> String? {
                // Try property="og:title" content="value" format (double quotes)
                let pattern1 = #"<meta\s+property=["']\#(property)["']\s+content=["']([^"']+)["']"#
                if let regex = try? NSRegularExpression(pattern: pattern1, options: .caseInsensitive) {
                    let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
                    for match in matches {
                        if match.numberOfRanges > 2 {
                            let contentRange = Range(match.range(at: 2), in: html)!
                            let content = String(html[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                            if !content.isEmpty {
                                return content
                            }
                        }
                    }
                }
                
                // Try property='og:title' content='value' format (single quotes)
                let pattern2 = #"<meta\s+property=[']\#(property)[']\s+content=[']([^']+)[']"#
                if let regex = try? NSRegularExpression(pattern: pattern2, options: .caseInsensitive) {
                    let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
                    for match in matches {
                        if match.numberOfRanges > 2 {
                            let contentRange = Range(match.range(at: 2), in: html)!
                            let content = String(html[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                            if !content.isEmpty {
                                return content
                            }
                        }
                    }
                }
                
                // Try content="value" property="og:title" format (reversed order)
                let pattern3 = #"<meta\s+content=["']([^"']+)["']\s+property=["']\#(property)["']"#
                if let regex = try? NSRegularExpression(pattern: pattern3, options: .caseInsensitive) {
                    let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
                    for match in matches {
                        if match.numberOfRanges > 2 {
                            let contentRange = Range(match.range(at: 1), in: html)!
                            let content = String(html[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                            if !content.isEmpty {
                                return content
                            }
                        }
                    }
                }
                
                return nil
            }
            
            // Extract Open Graph tags
            title = extractMetaContent(html: html, property: "og:title")
            description = extractMetaContent(html: html, property: "og:description")
            imageUrl = extractMetaContent(html: html, property: "og:image")
            
            // Try og:image:secure_url as fallback
            if imageUrl == nil {
                imageUrl = extractMetaContent(html: html, property: "og:image:secure_url")
            }
            
            // Try Twitter Card tags as fallback
            if imageUrl == nil {
                imageUrl = extractMetaContent(html: html, property: "twitter:image")
            }
            if imageUrl == nil {
                imageUrl = extractMetaContent(html: html, property: "twitter:image:src")
            }
            if title == nil {
                title = extractMetaContent(html: html, property: "twitter:title")
            }
            if description == nil {
                description = extractMetaContent(html: html, property: "twitter:description")
            }
            
            // Try link rel="image_src" (used by some sites)
            if imageUrl == nil {
                if let regex = try? NSRegularExpression(pattern: #"<link\s+rel=["']image_src["']\s+href=["']([^"']+)["']"#, options: .caseInsensitive),
                   let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                   match.numberOfRanges > 1 {
                    let imgRange = Range(match.range(at: 1), in: html)!
                    imageUrl = String(html[imgRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            // Try link rel="preload" as="image" (used by some sites)
            if imageUrl == nil {
                if let regex = try? NSRegularExpression(pattern: #"<link\s+rel=["']preload["']\s+as=["']image["']\s+href=["']([^"']+)["']"#, options: .caseInsensitive),
                   let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                   match.numberOfRanges > 1 {
                    let imgRange = Range(match.range(at: 1), in: html)!
                    imageUrl = String(html[imgRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            // For YouTube short URLs, try to extract video ID and construct thumbnail URL
            if imageUrl == nil {
                if urlToFetch.host?.contains("youtu.be") == true || urlToFetch.host?.contains("youtube.com") == true {
                    // Extract video ID from URL
                    var videoId: String? = nil
                    if urlToFetch.host?.contains("youtu.be") == true {
                        videoId = urlToFetch.pathComponents.last?.components(separatedBy: "?").first
                    } else if let queryItems = URLComponents(url: urlToFetch, resolvingAgainstBaseURL: false)?.queryItems,
                              let vParam = queryItems.first(where: { $0.name == "v" })?.value {
                        videoId = vParam
                    }
                    
                    if let videoId = videoId, !videoId.isEmpty {
                        imageUrl = "https://img.youtube.com/vi/\(videoId)/maxresdefault.jpg"
                        print("🎬 [LinkPreview] Constructed YouTube thumbnail URL: \(imageUrl ?? "nil")")
                    }
                }
            }
            
            // Fallback to regular meta tags if OG tags not found
            if title == nil {
                if let regex = try? NSRegularExpression(pattern: #"<title>([^<]+)</title>"#, options: .caseInsensitive),
                   let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                   match.numberOfRanges > 1 {
                    let titleRange = Range(match.range(at: 1), in: html)!
                    title = String(html[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            if description == nil {
                if let regex = try? NSRegularExpression(pattern: #"<meta\s+name=["']description["']\s+content=["']([^"']+)["']"#, options: .caseInsensitive),
                   let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                   match.numberOfRanges > 1 {
                    let descRange = Range(match.range(at: 1), in: html)!
                    description = String(html[descRange])
                }
            }
            
            // Try to find any image in meta tags as last resort
            if imageUrl == nil {
                if let regex = try? NSRegularExpression(pattern: #"<meta\s+name=["']image["']\s+content=["']([^"']+)["']"#, options: .caseInsensitive),
                   let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                   match.numberOfRanges > 1 {
                    let imgRange = Range(match.range(at: 1), in: html)!
                    imageUrl = String(html[imgRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            // Extract favicon
            if let regex = try? NSRegularExpression(pattern: #"<link\s+rel=["'](?:shortcut\s+)?icon["']\s+href=["']([^"']+)["']"#, options: .caseInsensitive),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               match.numberOfRanges > 1 {
                let faviconRange = Range(match.range(at: 1), in: html)!
                var faviconPath = String(html[faviconRange])
                // Make favicon URL absolute if relative
                if faviconPath.hasPrefix("//") {
                    faviconPath = "https:" + faviconPath
                } else if faviconPath.hasPrefix("/") {
                    faviconPath = "\(urlToFetch.scheme ?? "https")://\(urlToFetch.host ?? "")\(faviconPath)"
                } else if !faviconPath.hasPrefix("http") {
                    faviconPath = "\(urlToFetch.scheme ?? "https")://\(urlToFetch.host ?? "")/\(faviconPath)"
                }
                favIconUrl = faviconPath
            }
            
            // Make image URL absolute if relative and decode HTML entities
            if var imgUrl = imageUrl {
                // Trim whitespace
                imgUrl = imgUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Decode HTML entities
                imgUrl = imgUrl
                    .replacingOccurrences(of: "&amp;", with: "&")
                    .replacingOccurrences(of: "&lt;", with: "<")
                    .replacingOccurrences(of: "&gt;", with: ">")
                    .replacingOccurrences(of: "&quot;", with: "\"")
                    .replacingOccurrences(of: "&#39;", with: "'")
                    .replacingOccurrences(of: "&nbsp;", with: " ")
                
                // Remove any leading/trailing quotes
                imgUrl = imgUrl.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                
                // Make URL absolute if relative
                if !imgUrl.hasPrefix("http") && !imgUrl.hasPrefix("//") {
                    if imgUrl.hasPrefix("/") {
                        imgUrl = "\(urlToFetch.scheme ?? "https")://\(urlToFetch.host ?? "")\(imgUrl)"
                    } else {
                        imgUrl = "\(urlToFetch.scheme ?? "https")://\(urlToFetch.host ?? "")/\(imgUrl)"
                    }
                } else if imgUrl.hasPrefix("//") {
                    imgUrl = "https:" + imgUrl
                }
                
                // Validate and clean URL
                if let url = URL(string: imgUrl) {
                    imageUrl = imgUrl
                    print("✅ [LinkPreview] Valid image URL: \(imgUrl)")
                } else {
                    // Try URL encoding spaces and special characters
                    if let encoded = imgUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                       URL(string: encoded) != nil {
                        imageUrl = encoded
                        print("✅ [LinkPreview] Encoded image URL: \(encoded)")
                    } else {
                        print("⚠️ [LinkPreview] Invalid image URL after processing: \(imgUrl)")
                        imageUrl = nil
                    }
                }
            }
            
            print("🔍 [LinkPreview] Extracted - Title: \(title ?? "nil"), Desc: \(description ?? "nil"), Image: \(imageUrl ?? "nil"), Favicon: \(favIconUrl ?? "nil")")
            
            // Cache images locally (if available) for offline reuse
            let imageLocalPath = imageUrl.flatMap { cacheImageIfNeeded(from: $0) }
            let favIconLocalPath = favIconUrl.flatMap { cacheImageIfNeeded(from: $0) }
            
            DispatchQueue.main.async {
                print("📦 [LinkPreview] Setting fetched data - Title: \(title != nil ? "✓" : "✗"), Desc: \(description != nil ? "✓" : "✗"), Image: \(imageUrl != nil ? "✓" : "✗"), Favicon: \(favIconUrl != nil ? "✓" : "✗")")
                
                self.fetchedTitle = title
                self.fetchedDescription = description
                self.fetchedImageUrl = imageLocalPath ?? imageUrl
                self.fetchedFavIconUrl = favIconLocalPath ?? favIconUrl
                
                // Persist cache for fast re-open without network
                saveCachedLinkPreview(
                    for: self.url,
                    title: title,
                    description: description,
                    imagePath: self.fetchedImageUrl,
                    favIconPath: self.fetchedFavIconUrl
                )
                
                // Show preview if we got any data
                if title != nil || description != nil || imageUrl != nil || favIconUrl != nil {
                    self.showFullPreview = true
                    print("✅ [LinkPreview] Showing full preview - Image URL: \(imageUrl ?? "none")")
                    print("✅ [LinkPreview] showFullPreview set to: \(self.showFullPreview)")
                } else {
                    print("⚠️ [LinkPreview] No preview data found")
                }
                self.isFetching = false
            }
        }.resume()
    }
}

// MARK: - Receiver Rich Link View (matching Android receiver richLinkViewLyt)
struct ReceiverRichLinkView: View {
    @Environment(\.colorScheme) var colorScheme
    let url: String
    let linkTitle: String?
    let linkDescription: String?
    let linkImageUrl: String?
    let favIconUrl: String?
    
    @State private var showFullPreview: Bool = false
    @State private var fetchedTitle: String? = nil
    @State private var fetchedDescription: String? = nil
    @State private var fetchedImageUrl: String? = nil
    @State private var fetchedFavIconUrl: String? = nil
    @State private var isFetching: Bool = false
    
    private var themeColor: Color {
        Color(hex: Constant.themeColor)
    }
    
    // Get receiver message glassmorphism background (matching modern_glass_background_receiver.xml)
    @ViewBuilder
    private func getReceiverGlassBackground(cornerRadius: CGFloat) -> some View {
        // Linear gradient at 135 degrees with glass colors
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
                // Subtle border for glass effect (0.5dp, matching Android stroke)
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(getReceiverGlassBorder(), lineWidth: 0.5)
            )
    }
    
    // Get glass background start color (matching Android glass_bg_start)
    private func getReceiverGlassBgStart() -> Color {
        // Light mode: #80FFFFFF (50% opacity white)
        // Dark mode: #4D1B1B1B (semi-transparent dark)
        return colorScheme == .dark ? Color(hex: "#4D1B1B1B") : Color(hex: "#80FFFFFF")
    }
    
    // Get glass background center color (matching Android glass_bg_center)
    private func getReceiverGlassBgCenter() -> Color {
        // Light mode: #66FFFFFF (40% opacity white)
        // Dark mode: #331B1B1B (more transparent)
        return colorScheme == .dark ? Color(hex: "#331B1B1B") : Color(hex: "#66FFFFFF")
    }
    
    // Get glass background end color (matching Android glass_bg_end)
    private func getReceiverGlassBgEnd() -> Color {
        // Light mode: #4DFFFFFF (30% opacity white)
        // Dark mode: #1A1B1B1B (even more transparent)
        return colorScheme == .dark ? Color(hex: "#1A1B1B1B") : Color(hex: "#4DFFFFFF")
    }
    
    // Get glass border color (matching Android glass_border)
    private func getReceiverGlassBorder() -> Color {
        // Light mode: #80000000 (50% opacity black)
        // Dark mode: #40FFFFFF (25% opacity white) - matching Android values-night/colors.xml
        return colorScheme == .dark ? Color(hex: "#40FFFFFF") : Color(hex: "#80000000")
    }
    
    @ViewBuilder
    private var linkImageView: some View {
        let imageUrlString = linkImageUrl ?? fetchedImageUrl
        let _ = print("🖼️ [LinkPreview] Receiver linkImageView - linkImageUrl: \(linkImageUrl ?? "nil"), fetchedImageUrl: \(fetchedImageUrl ?? "nil")")
        if let imageUrlString = imageUrlString, !imageUrlString.isEmpty {
            LinkPreviewImageView(imageUrlString: imageUrlString, width: 210, height: 130)
        } else {
            let _ = print("⚠️ [LinkPreview] No image URL available - linkImageUrl: \(linkImageUrl ?? "nil"), fetchedImageUrl: \(fetchedImageUrl ?? "nil")")
            DefaultLinkIconView(width: 210, height: 130)
        }
    }
    
    @ViewBuilder
    var body: some View {
        Group {
            // If no preview data, show just the URL as underlined text (matching Android linkActualUrl)
            // Android: when linkPreviewModel.getUrl().equals(""), show linkActualUrl only
            if !showFullPreview {
                // Link actual URL - matching Android linkActualUrl TextView (when no preview data)
                // Android: textColor="@color/blue", textSize="15sp", fontFamily="@font/inter", maxWidth="210dp", textFontWeight="400"
                // Android: layout_marginHorizontal="2dp"
                Text(url)
                    .font(.custom("Inter18pt-Regular", size: 15))
                    .fontWeight(.regular)
                    .foregroundColor(themeColor)
                    .frame(maxWidth: 210, alignment: .leading)
                    .underline()
                    .padding(.horizontal, 2)
                    .onTapGesture {
                        if let url = URL(string: self.url) {
                            UIApplication.shared.open(url)
                        }
                    }
            } else {
                // Full rich link preview (matching Android when linkPreviewModel has data)
                VStack(spacing: 0) {
                    // Main container - matching Android CardView
                    // Android: cardBackgroundColor="@color/white", cardCornerRadius="20dp", cardElevation="0dp"
                    VStack(spacing: 0) {
                        // Link image - matching Android linkImg ImageView
                        // Android: layout_width="210dp", layout_height="130dp", background="#000000", scaleType="centerCrop"
                        linkImageView
                            .frame(maxWidth: .infinity)
                        
                        // Rich box - matching Android LinearLayout
                        // Android: background="@color/receiverChatBox", orientation="vertical"
                        VStack(spacing: 0) {
                            // Inner container - matching Android inner LinearLayout
                            // Android: background="@drawable/custome_ripple_chatting", padding="10dp", orientation="vertical"
                            VStack(alignment: .leading, spacing: 0) {
                                // Link title - matching Android linkTitle TextView
                                // Android: style="@style/TextColor", textSize="15sp", fontFamily="@font/inter", maxWidth="210dp", singleLine="true"
                                if let title = (linkTitle ?? fetchedTitle), !title.isEmpty {
                                    Text(title)
                                        .font(.custom("Inter18pt-Regular", size: 15))
                                        .foregroundColor(Color("TextColor"))
                                        .lineLimit(1)
                                        .frame(maxWidth: 210, alignment: .leading)
                                        .padding(.bottom, 2)
                                }
                                
                                // Link description - matching Android linkDesc TextView
                                // Android: textColor="@color/gray", textSize="15sp", fontFamily="@font/inter", maxWidth="210dp", maxLines="2"
                                if let desc = (linkDescription ?? fetchedDescription), !desc.isEmpty {
                                    Text(desc)
                                        .font(.custom("Inter18pt-Regular", size: 15))
                                        .foregroundColor(Color("gray"))
                                        .lineLimit(2)
                                        .frame(maxWidth: 210, alignment: .leading)
                                        .padding(.bottom, 2)
                                }
                                
                                // Link URL with favicon - matching Android HStack with linkImg2 and link
                                // Android: orientation="horizontal", gravity="center_vertical"
                                HStack(alignment: .center, spacing: 5) {
                                    // Favicon - matching Android linkImg2 ImageView
                                    // Android: layout_width="15dp", layout_height="15dp", layout_marginEnd="5dp"
                                    if let favIcon = (favIconUrl ?? fetchedFavIconUrl), !favIcon.isEmpty {
                                        AsyncImage(url: urlFromStringAllowFile(favIcon)) { phase in
                                            switch phase {
                                            case .empty:
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: themeColor))
                                                    .frame(width: 15, height: 15)
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .scaledToFit()
                                            case .failure:
                                                Image(systemName: "link.circle.fill")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .foregroundColor(themeColor)
                                            @unknown default:
                                                Image(systemName: "link.circle.fill")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .foregroundColor(themeColor)
                                            }
                                        }
                                        .frame(width: 15, height: 15)
                                    } else {
                                        Image(systemName: "link.circle.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .foregroundColor(themeColor)
                                            .frame(width: 15, height: 15)
                                    }
                                    
                                    // Link URL - matching Android link TextView
                                    // Android: textColor="@color/blue", textSize="15sp", fontFamily="@font/inter", maxWidth="210dp", singleLine="true", linksClickable="true"
                                    Text(url)
                                        .font(.custom("Inter18pt-Regular", size: 15))
                                        .foregroundColor(themeColor)
                                        .lineLimit(1)
                                        .frame(maxWidth: 210, alignment: .leading)
                                        .underline()
                                        .onTapGesture {
                                            if let url = URL(string: self.url) {
                                                UIApplication.shared.open(url)
                                            }
                                        }
                                }
                                .padding(.bottom, 1)
                            }
                            .padding(10)
                            .background(getReceiverGlassBackground(cornerRadius: 20)) // Matching Constant.voiceAudio receiver container color with glassmorphism
                        }
                        .background(Color("receiverChatBox")) // Android: background="@color/receiverChatBox"
                    }
                    .background(getReceiverGlassBackground(cornerRadius: 20)) // Android: cardBackgroundColor matching modern_glass_background_receiver.xml
                    .clipShape(RoundedRectangle(cornerRadius: 20)) // Android: cardCornerRadius="20dp"
                    .onTapGesture {
                        if let url = URL(string: self.url) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }
        }
        .onAppear {
            // Load cached preview immediately (offline / instant show)
            applyCachedPreviewIfAvailable()
            // Check if we have link preview data (from message)
            let hasTitle = linkTitle != nil && !linkTitle!.isEmpty
            let hasDesc = linkDescription != nil && !linkDescription!.isEmpty
            let hasImage = linkImageUrl != nil && !linkImageUrl!.isEmpty
            let hasFavIcon = favIconUrl != nil && !favIconUrl!.isEmpty
            
            if hasTitle || hasDesc || hasImage || hasFavIcon {
                // We have preview data from message, show it
                showFullPreview = true
                print("✅ [LinkPreview] Using message data - Title: \(linkTitle ?? "nil"), Image: \(linkImageUrl ?? "nil")")
            } else {
                // No preview data, try to fetch it
                print("🔍 [LinkPreview] No message data, fetching preview for: \(url)")
                fetchLinkPreview()
            }
        }
        .onChange(of: fetchedTitle) { _ in
            // Update preview when fetched data changes
            if fetchedTitle != nil || fetchedDescription != nil || fetchedImageUrl != nil || fetchedFavIconUrl != nil {
                showFullPreview = true
                print("✅ [LinkPreview] onChange - Setting showFullPreview to true")
            }
        }
        .onChange(of: fetchedDescription) { _ in
            if fetchedTitle != nil || fetchedDescription != nil || fetchedImageUrl != nil || fetchedFavIconUrl != nil {
                showFullPreview = true
            }
        }
        .onChange(of: fetchedImageUrl) { _ in
            if fetchedTitle != nil || fetchedDescription != nil || fetchedImageUrl != nil || fetchedFavIconUrl != nil {
                showFullPreview = true
            }
        }
        .onChange(of: fetchedFavIconUrl) { _ in
            if fetchedTitle != nil || fetchedDescription != nil || fetchedImageUrl != nil || fetchedFavIconUrl != nil {
                showFullPreview = true
            }
        }
    }
    
    // Load cached preview data (including locally stored images) for instant display
    private func applyCachedPreviewIfAvailable() {
        guard let cache = loadCachedLinkPreview(for: url) else { return }
        fetchedTitle = cache.title
        fetchedDescription = cache.description
        fetchedImageUrl = cache.imagePath
        fetchedFavIconUrl = cache.favIconPath
        if cache.title != nil || cache.description != nil || cache.imagePath != nil || cache.favIconPath != nil {
            showFullPreview = true
        }
    }
    
    private func fetchLinkPreview() {
        guard !isFetching, let urlToFetch = URL(string: url) else { return }
        isFetching = true
        
        print("🔍 [LinkPreview] Fetching preview for: \(url)")
        print("🔍 [LinkPreview] URL host: \(urlToFetch.host ?? "nil"), path: \(urlToFetch.path)")
        
        // Create a URL request
        var request = URLRequest(url: urlToFetch)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let html = String(data: data, encoding: .utf8),
                  error == nil else {
                print("🚫 [LinkPreview] Failed to fetch HTML: \(error?.localizedDescription ?? "unknown error")")
                DispatchQueue.main.async {
                    self.isFetching = false
                }
                return
            }
            
            // Parse Open Graph and meta tags
            var title: String? = nil
            var description: String? = nil
            var imageUrl: String? = nil
            var favIconUrl: String? = nil
            
            // Helper function to extract content from meta tags
            func extractMetaContent(html: String, property: String) -> String? {
                // Try property="og:title" content="value" format (double quotes)
                let pattern1 = #"<meta\s+property=["']\#(property)["']\s+content=["']([^"']+)["']"#
                if let regex = try? NSRegularExpression(pattern: pattern1, options: .caseInsensitive) {
                    let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
                    for match in matches {
                        if match.numberOfRanges > 2 {
                            let contentRange = Range(match.range(at: 2), in: html)!
                            let content = String(html[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                            if !content.isEmpty {
                                return content
                            }
                        }
                    }
                }
                
                // Try property='og:title' content='value' format (single quotes)
                let pattern2 = #"<meta\s+property=[']\#(property)[']\s+content=[']([^']+)[']"#
                if let regex = try? NSRegularExpression(pattern: pattern2, options: .caseInsensitive) {
                    let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
                    for match in matches {
                        if match.numberOfRanges > 2 {
                            let contentRange = Range(match.range(at: 2), in: html)!
                            let content = String(html[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                            if !content.isEmpty {
                                return content
                            }
                        }
                    }
                }
                
                // Try content="value" property="og:title" format (reversed order)
                let pattern3 = #"<meta\s+content=["']([^"']+)["']\s+property=["']\#(property)["']"#
                if let regex = try? NSRegularExpression(pattern: pattern3, options: .caseInsensitive) {
                    let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
                    for match in matches {
                        if match.numberOfRanges > 2 {
                            let contentRange = Range(match.range(at: 1), in: html)!
                            let content = String(html[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                            if !content.isEmpty {
                                return content
                            }
                        }
                    }
                }
                
                return nil
            }
            
            // Extract Open Graph tags
            title = extractMetaContent(html: html, property: "og:title")
            description = extractMetaContent(html: html, property: "og:description")
            imageUrl = extractMetaContent(html: html, property: "og:image")
            
            // Try og:image:secure_url as fallback
            if imageUrl == nil {
                imageUrl = extractMetaContent(html: html, property: "og:image:secure_url")
            }
            
            // Try Twitter Card tags as fallback
            if imageUrl == nil {
                imageUrl = extractMetaContent(html: html, property: "twitter:image")
            }
            if imageUrl == nil {
                imageUrl = extractMetaContent(html: html, property: "twitter:image:src")
            }
            if title == nil {
                title = extractMetaContent(html: html, property: "twitter:title")
            }
            if description == nil {
                description = extractMetaContent(html: html, property: "twitter:description")
            }
            
            // Try link rel="image_src" (used by some sites)
            if imageUrl == nil {
                if let regex = try? NSRegularExpression(pattern: #"<link\s+rel=["']image_src["']\s+href=["']([^"']+)["']"#, options: .caseInsensitive),
                   let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                   match.numberOfRanges > 1 {
                    let imgRange = Range(match.range(at: 1), in: html)!
                    imageUrl = String(html[imgRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            // Try link rel="preload" as="image" (used by some sites)
            if imageUrl == nil {
                if let regex = try? NSRegularExpression(pattern: #"<link\s+rel=["']preload["']\s+as=["']image["']\s+href=["']([^"']+)["']"#, options: .caseInsensitive),
                   let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                   match.numberOfRanges > 1 {
                    let imgRange = Range(match.range(at: 1), in: html)!
                    imageUrl = String(html[imgRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            // For YouTube short URLs, try to extract video ID and construct thumbnail URL
            if imageUrl == nil {
                if urlToFetch.host?.contains("youtu.be") == true || urlToFetch.host?.contains("youtube.com") == true {
                    // Extract video ID from URL
                    var videoId: String? = nil
                    if urlToFetch.host?.contains("youtu.be") == true {
                        videoId = urlToFetch.pathComponents.last?.components(separatedBy: "?").first
                    } else if let queryItems = URLComponents(url: urlToFetch, resolvingAgainstBaseURL: false)?.queryItems,
                              let vParam = queryItems.first(where: { $0.name == "v" })?.value {
                        videoId = vParam
                    }
                    
                    if let videoId = videoId, !videoId.isEmpty {
                        imageUrl = "https://img.youtube.com/vi/\(videoId)/maxresdefault.jpg"
                        print("🎬 [LinkPreview] Constructed YouTube thumbnail URL: \(imageUrl ?? "nil")")
                    }
                }
            }
            
            // Fallback to regular meta tags if OG tags not found
            if title == nil {
                if let regex = try? NSRegularExpression(pattern: #"<title>([^<]+)</title>"#, options: .caseInsensitive),
                   let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                   match.numberOfRanges > 1 {
                    let titleRange = Range(match.range(at: 1), in: html)!
                    title = String(html[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            if description == nil {
                if let regex = try? NSRegularExpression(pattern: #"<meta\s+name=["']description["']\s+content=["']([^"']+)["']"#, options: .caseInsensitive),
                   let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                   match.numberOfRanges > 1 {
                    let descRange = Range(match.range(at: 1), in: html)!
                    description = String(html[descRange])
                }
            }
            
            // Try to find any image in meta tags as last resort
            if imageUrl == nil {
                if let regex = try? NSRegularExpression(pattern: #"<meta\s+name=["']image["']\s+content=["']([^"']+)["']"#, options: .caseInsensitive),
                   let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                   match.numberOfRanges > 1 {
                    let imgRange = Range(match.range(at: 1), in: html)!
                    imageUrl = String(html[imgRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            // Extract favicon
            if let regex = try? NSRegularExpression(pattern: #"<link\s+rel=["'](?:shortcut\s+)?icon["']\s+href=["']([^"']+)["']"#, options: .caseInsensitive),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               match.numberOfRanges > 1 {
                let faviconRange = Range(match.range(at: 1), in: html)!
                var faviconPath = String(html[faviconRange])
                // Make favicon URL absolute if relative
                if faviconPath.hasPrefix("//") {
                    faviconPath = "https:" + faviconPath
                } else if faviconPath.hasPrefix("/") {
                    faviconPath = "\(urlToFetch.scheme ?? "https")://\(urlToFetch.host ?? "")\(faviconPath)"
                } else if !faviconPath.hasPrefix("http") {
                    faviconPath = "\(urlToFetch.scheme ?? "https")://\(urlToFetch.host ?? "")/\(faviconPath)"
                }
                favIconUrl = faviconPath
            }
            
            // Make image URL absolute if relative
            // Make image URL absolute if relative and decode HTML entities
            if var imgUrl = imageUrl {
                // Trim whitespace
                imgUrl = imgUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Decode HTML entities
                imgUrl = imgUrl
                    .replacingOccurrences(of: "&amp;", with: "&")
                    .replacingOccurrences(of: "&lt;", with: "<")
                    .replacingOccurrences(of: "&gt;", with: ">")
                    .replacingOccurrences(of: "&quot;", with: "\"")
                    .replacingOccurrences(of: "&#39;", with: "'")
                    .replacingOccurrences(of: "&nbsp;", with: " ")
                
                // Remove any leading/trailing quotes
                imgUrl = imgUrl.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                
                // Make URL absolute if relative
                if !imgUrl.hasPrefix("http") && !imgUrl.hasPrefix("//") {
                    if imgUrl.hasPrefix("/") {
                        imgUrl = "\(urlToFetch.scheme ?? "https")://\(urlToFetch.host ?? "")\(imgUrl)"
                    } else {
                        imgUrl = "\(urlToFetch.scheme ?? "https")://\(urlToFetch.host ?? "")/\(imgUrl)"
                    }
                } else if imgUrl.hasPrefix("//") {
                    imgUrl = "https:" + imgUrl
                }
                
                // Validate and clean URL
                if let url = URL(string: imgUrl) {
                    imageUrl = imgUrl
                    print("✅ [LinkPreview] Valid image URL: \(imgUrl)")
                } else {
                    // Try URL encoding spaces and special characters
                    if let encoded = imgUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                       URL(string: encoded) != nil {
                        imageUrl = encoded
                        print("✅ [LinkPreview] Encoded image URL: \(encoded)")
                    } else {
                        print("⚠️ [LinkPreview] Invalid image URL after processing: \(imgUrl)")
                        imageUrl = nil
                    }
                }
            }
            
            print("🔍 [LinkPreview] Extracted - Title: \(title ?? "nil"), Desc: \(description ?? "nil"), Image: \(imageUrl ?? "nil"), Favicon: \(favIconUrl ?? "nil")")
            
            // Cache images locally (if available) for offline reuse
            let imageLocalPath = imageUrl.flatMap { cacheImageIfNeeded(from: $0) }
            let favIconLocalPath = favIconUrl.flatMap { cacheImageIfNeeded(from: $0) }
            
            DispatchQueue.main.async {
                print("📦 [LinkPreview] Setting fetched data - Title: \(title != nil ? "✓" : "✗"), Desc: \(description != nil ? "✓" : "✗"), Image: \(imageUrl != nil ? "✓ (\(imageUrl ?? ""))" : "✗"), Favicon: \(favIconUrl != nil ? "✓" : "✗")")
                
                self.fetchedTitle = title
                self.fetchedDescription = description
                self.fetchedImageUrl = imageLocalPath ?? imageUrl
                self.fetchedFavIconUrl = favIconLocalPath ?? favIconUrl
                
                // Persist cache for fast re-open without network
                saveCachedLinkPreview(
                    for: self.url,
                    title: title,
                    description: description,
                    imagePath: self.fetchedImageUrl,
                    favIconPath: self.fetchedFavIconUrl
                )
                
                // Show preview if we got any data
                if title != nil || description != nil || imageUrl != nil || favIconUrl != nil {
                    self.showFullPreview = true
                    print("✅ [LinkPreview] Showing full preview - Image URL: \(imageUrl ?? "none")")
                    print("✅ [LinkPreview] showFullPreview set to: \(self.showFullPreview)")
                } else {
                    print("⚠️ [LinkPreview] No preview data found")
                }
                self.isFetching = false
            }
        }.resume()
    }
}

// MARK: - Share Sheet for saving files publicly
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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

// MARK: - Custom Button Style with Hover Effect
struct DialogButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                // Hover/press effect background (matching Android ripple effect)
                Color.gray.opacity(configuration.isPressed ? 0.1 : 0.0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Message Long Press Dialog (matching Android sender_long_press_dialogue.xml and receiver_long_press_dialogue.xml)
struct MessageLongPressDialog: View {
    let message: ChatMessage
    let isSentByMe: Bool
    let position: CGPoint
    let contact: UserActiveContactModel
    @Binding var isPresented: Bool
    let onReply: () -> Void
    let onForward: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onMultiSelect: () -> Void
    let onImageTap: ((SelectionBunchModel) -> Void)? // Callback for single image tap to open ShowImageScreen
    
    @Environment(\.colorScheme) private var colorScheme
    
    // Emoji reactions state
    @State private var availableEmojis: [EmojiData] = [] // Emojis from API
    @State private var currentEmojiModels: [EmojiModel] = [] // Current reactions from Firebase
    @State private var displayEmojis: [DisplayEmoji] = [] // Combined static + Firebase emojis for display
    @State private var isLoadingEmojis: Bool = false
    @State private var showEmojiPicker: Bool = false
    @State private var emojiListenerHandle: DatabaseHandle?
    
    // Animation state for Android-style unfold animation
    // Initial values: sender starts at -45°, receiver at 45°, both scale from 0
    @State private var rotationAngle: Double = 0.0 // Will be set based on isSentByMe
    @State private var scaleValue: CGFloat = 0.0
    @State private var opacityValue: Double = 0.0
    @State private var backdropOpacity: Double = 0.0
    @State private var isDismissing: Bool = false // Track if we're currently dismissing
    
    // Presentation tuning for a softer, magical feel
    private let presentRotation: Double = 12
    private let dismissRotation: Double = 18
    private let presentScale: CGFloat = 0.92
    private let dismissScale: CGFloat = 0.86
    
    // Helper function for smooth dismissal
    private func dismissDialog() {
        guard !isDismissing else { return } // Prevent multiple taps
        isDismissing = true
        animateOut()
        // Dismiss after animation completes (slightly longer to ensure smooth transition)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isPresented = false
            isDismissing = false
        }
    }
    
    private func animateIn() {
        rotationAngle = presentRotation
        scaleValue = presentScale
        opacityValue = 0.0
        backdropOpacity = 0.0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                rotationAngle = 0.0
                scaleValue = 1.0
                opacityValue = 1.0
                backdropOpacity = 1.0
            }
        }
    }
    
    private func animateOut() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            rotationAngle = dismissRotation
            scaleValue = dismissScale
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
                    // For empty emoji, use a unique static identifier to avoid duplicate IDs
                    self.id = "empty-emoji-placeholder"
                } else {
                    self.id = character
                }
            } else {
                // If slug exists, check if character is empty to ensure uniqueness
                if character.isEmpty {
                    // Use a unique identifier for empty emoji with slug to avoid conflicts
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
                // Use ReplyView exactly as it is - same design for both sender and receiver
                ReplyView(message: message, isSentByMe: isSentByMe) {
                    onReply()
                }
                
                if !isSentByMe {
                    Spacer(minLength: 0)
                }
            }
            .padding(.bottom, 4) // Add spacing between reply and main message
        }
    }
    
    // Text message preview view - matching MessageBubbleView exact styling with time/progress bar
    @ViewBuilder
    private var textMessagePreviewView: some View {
        VStack(alignment: isSentByMe ? .trailing : .leading, spacing: 0) {
            // Show reply layout if present (matching MessageBubbleView structure)
            replyLayoutPreviewView
            
            // Main message content - hide if this is a reply message with text replyType
            // (matching MessageBubbleView shouldHideMainMessage logic)
            if !shouldHideMainMessage {
                // Check if message contains a URL (matching Android URLUtil.isValidUrl)
                if let url = messageContent.extractURL(), url.isValidURL() {
                    // Show rich link preview (matching Android richLinkViewLyt)
                                HStack {
                        if isSentByMe {
                            Spacer(minLength: 0) // Push content to end (right side gravity - end)
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
                            Spacer(minLength: 0) // Don't expand beyond content
                        }
                    }
                    .frame(maxWidth: 250) // maxWidth constraint - wrap content up to max
                } else {
                    // Regular text message (no URL) - matching MessageBubbleView structure
                    // Alignment is handled by outer HStack, so no need for internal Spacer
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
                                        .background(getReceiverGlassBackground(cornerRadius: 20))
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
            
            // Time row with progress indicator (matching MessageBubbleView timeRowView)
            // Always show for text messages in dialog
            timeRowPreviewView
        }
    }
    
    // Time row preview view - matching MessageBubbleView timeRowView
    @ViewBuilder
    private var timeRowPreviewView: some View {
        // Time row with progress indicator beside time (matching Android placement)
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
    
    // Progress indicator preview view - matching MessageBubbleView progressIndicatorView
    @ViewBuilder
    private func progressIndicatorPreviewView(isSender: Bool) -> some View {
        let themeColor = Color(hex: Constant.themeColor)
        // Sender: use themeColor for both track and indicator (per ThemeColorKey); Receiver: asset colors
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
    
    // Image message preview view - matching MessageBubbleView exact styling
    @ViewBuilder
    private var imageMessagePreviewView: some View {
        VStack(alignment: isSentByMe ? .trailing : .leading, spacing: 0) {
            // Show reply layout if present (matching MessageBubbleView structure)
            replyLayoutPreviewView
            
            // Main image content - hide if this is a reply message
            if !shouldHideMainMessage {
                if isSentByMe {
                    // Sender image message (matching Android senderImg design)
                    HStack {
                        Spacer(minLength: 0) // Push content to end
                        
                        // Container wrapping image and caption with same background as Constant.Text sender messages
                        VStack(alignment: .trailing, spacing: 0) {
                            DynamicImageView(
                                imageUrl: message.document,
                                fileName: message.fileName,
                                imageWidth: message.imageWidth,
                                imageHeight: message.imageHeight,
                                aspectRatio: message.aspectRatio,
                                backgroundColor: getSenderMessageBackgroundColor(colorScheme: colorScheme),
                                onTap: {
                                    // Open ShowImageScreen for single image
                                    onImageTap?(SelectionBunchModel(
                                        imgUrl: message.document,
                                        fileName: message.fileName ?? ""
                                    ))
                                }
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
                        .frame(width: calculateImageSize(imageWidth: message.imageWidth, imageHeight: message.imageHeight, aspectRatio: message.aspectRatio).width)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(getSenderMessageBackgroundColor(colorScheme: colorScheme))
                        )
                    }
                    .frame(maxWidth: 250)
                } else {
                    // Receiver image message (matching Android receiverImg design)
                    HStack {
                        // Container wrapping image and caption with same background as Constant.Text receiver messages
                            VStack(alignment: .leading, spacing: 0) {
                                ReceiverDynamicImageView(
                                    imageUrl: message.document,
                                    fileName: message.fileName,
                                    imageWidth: message.imageWidth,
                                    imageHeight: message.imageHeight,
                                    aspectRatio: message.aspectRatio,
                                    onTap: {
                                        // Open ShowImageScreen for single image
                                        onImageTap?(SelectionBunchModel(
                                            imgUrl: message.document,
                                            fileName: message.fileName ?? ""
                                        ))
                                    }
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
                        .frame(width: calculateImageSize(imageWidth: message.imageWidth, imageHeight: message.imageHeight, aspectRatio: message.aspectRatio).width)
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
                                
    // Calculate image size (matching MessageBubbleView calculateImageSize)
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
    
    // Get receiver glass background (matching MessageBubbleView)
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
    
    // Helper functions for receiver glass background (matching MessageBubbleView)
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
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Blurred background overlay - covers entire screen and is tappable everywhere
                Color.black.opacity(0.35 * backdropOpacity)
                    .background(.ultraThinMaterial)
                    .opacity(backdropOpacity)
                    .contentShape(Rectangle()) // Make entire area tappable
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
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
                                        onReply()
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
                                // Multi-Select button (matching Android SelectLyt)
                                // paddingTop=10dp, marginStart=15dp, icon size=24dp, marginStart=3dp
                                Button(action: {
                                    // Haptic feedback (matching Android Constant.Vibrator)
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    onMultiSelect()
                                }) {
                                    HStack(spacing: 0) {
                                        // TextView: weight=1, marginStart=15dp, textSize=16sp, bold, Inter font, lineHeight=24dp
                                        Text("Multi-Select")
                                            .font(.custom("Inter18pt-Regular", size: 16))
                                            .fontWeight(.bold)
                                            .foregroundColor(Color("TextColor"))
                                            .lineLimit(1)
                                            .lineSpacing(0) // lineHeight="24dp"
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.leading, 15)
                                        
                                        // ImageView container: weight=4, size=24dp, marginStart=3dp (from container edge)
                                        HStack {
                                        Spacer()
                                            Image("multitick")
                                                .renderingMode(.template)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 24, height: 24)
                                            .foregroundColor(Color("gray3"))
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
                                
                                // Forward button (matching Android forward)
                                // paddingTop=10dp, marginStart=15dp, icon size=26.05x24dp, marginStart=3dp
                                Button(action: {
                                    // Haptic feedback (matching Android Constant.Vibrator)
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    onForward()
                                }) {
                                    HStack(spacing: 0) {
                                        // TextView: weight=1, marginStart=15dp, lineHeight=24dp
                                        Text("Forward")
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
                                            Image("forward_svg")
                                                .renderingMode(.template)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 26.05, height: 24) // Exact Android size: 26.05dp x 24dp
                                            .foregroundColor(Color("gray3"))
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
                                
                                // Copy button (matching Android copy)
                                // Only show for Text datatype messages
                                // paddingTop=10dp, marginStart=15dp, icon size=23x23dp, marginStart=5dp
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
                .frame(width: 310)
                .frame(maxHeight: geometry.size.height * 0.8)
                .allowsHitTesting(true) // Allow touches on ScrollView content
                // Android unfold animation: rotate and scale with correct anchor points
                // Apply animation to content VStack so anchor is relative to 310-width content, not full-width container
                // Both sender and receiver animate from top-left
                .rotationEffect(.degrees(rotationAngle), anchor: .topLeading)
                .scaleEffect(scaleValue, anchor: .topLeading)
                .opacity(opacityValue)
                    
                    // For receiver (start gravity): add spacer at end
                    // For sender (end gravity): no spacer - content aligns to right
                    if !isSentByMe {
                        Spacer()
            }
                }
                .frame(maxWidth: .infinity) // Ensure HStack takes full width
            }
            .frame(maxWidth: .infinity) // Ensure ZStack content takes full width
            .offset(x: 0, y: adjustedOffsetY(in: geometry)) // Only offset Y, X is handled by HStack padding (matching reference file)
                .zIndex(1) // Dialog content on top of blur
                .background(Color.clear.contentShape(Rectangle()).allowsHitTesting(false)) // Don't block touches in empty areas
            }
        }
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
    
    // Horizontal spacing constant - exactly 10px from edges
    private let horizontalSpacing: CGFloat = 10

    // Calculate adjusted offset Y - position dialog at exact touch location
    private func adjustedOffsetY(in geometry: GeometryProxy) -> CGFloat {
        // Estimate message preview height (similar to contactCardHeight in ChatLongPressDialog)
        // This is approximate - actual height may vary based on message type
        let messagePreviewHeight: CGFloat = 100 // Approximate height for message preview
        let emojiCardHeight: CGFloat = 60 // Emoji reactions card height
        let actionButtonsHeight: CGFloat = 200 // Action buttons card height
        let dialogHeight = emojiCardHeight + messagePreviewHeight + actionButtonsHeight
        let padding: CGFloat = 20
        
        // Check if position is valid (not zero)
        guard position.y > 0 else {
            // If position is invalid, center dialog vertically
            let centeredY = (geometry.size.height - dialogHeight) / 2
            print("🟣 [MessageLongPressDialog] Invalid position, centering dialog at Y: \(centeredY)")
            return max(centeredY, padding)
        }
        
        let frame = geometry.frame(in: .global)
        // position is now the exact touch location in global coordinates
        // Convert to local coordinates within the dialog's parent view
        let localY = position.y - frame.minY
        
        // Position dialog so the touch location is near the center of the emoji card
        // This provides a better UX - the dialog appears centered around where the user touched
        let emojiCardCenterOffset = emojiCardHeight / 2
        let dialogTopY = localY - emojiCardCenterOffset
        
        // Ensure dialog stays within screen bounds
        let maxY = geometry.size.height - dialogHeight - padding
        let minY = padding
        
        print("🟣 [MessageLongPressDialog] Positioning - Touch Y: \(position.y), Local Y: \(localY), Dialog Top Y: \(dialogTopY), isSentByMe: \(isSentByMe)")
        return min(max(dialogTopY, minY), maxY)
    }
    
    // MARK: - Emoji Reactions View (matching Android emojiCard and emojiLongRec)
    @ViewBuilder
    private var emojiReactionsView: some View {
        // Main container (matching Android RelativeLayout)
        ZStack(alignment: .center) {
            // Emoji reactions horizontal scroll (matching Android emojiLongRec RecyclerView)
            // LinearLayout with padding="5dp" containing RecyclerView
            HStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Show displayEmojis (static + Firebase combined)
                        // If displayEmojis is empty, show static emojis as fallback
                        ForEach(displayEmojis.isEmpty ? staticEmojis : displayEmojis) { displayEmoji in
                            if !displayEmoji.character.isEmpty {
                                emojiReactionButton(displayEmoji: displayEmoji)
                            }
                        }
                    }
                }
                .padding(.trailing, 15) // android:layout_marginEnd="15dp" on RecyclerView
                Spacer()
            }
            .padding(5) // android:padding="5dp" on LinearLayout
            
            // Right gradient bars + Add emoji button (matching Android - aligned to end, centered vertically)
            HStack {
                Spacer()
                rightGradientBars
                // Add emoji button (matching Android addEmoji - 40dp x 40dp, aligned to end)
                Button(action: {
                    // Haptic feedback (matching Android Constant.Vibrator for Android Q+)
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    
                    // Show emoji picker (matching Android Constant.bottomsheetEmoji and bottomSheetDialog.show())
                    showEmojiPicker = true
                    
                    // Fetch available emojis (matching Android Webservice.get_emojiAdd)
                    // Always fetch when button is clicked (Android calls get_emojiAdd every time)
                    fetchAvailableEmojis()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color("gray3"))
                        .frame(width: 40, height: 40) // android:layout_width="40dp" android:layout_height="40dp"
                }
                .padding(.trailing, 5) // android:layout_marginEnd="5dp"
            }
            
            // Left gradient bars (matching Android - aligned to start, centered vertically)
            HStack {
                leftGradientBars
                Spacer()
            }
        }
        .frame(width: 305) // android:layout_width="305dp"
        .background(
            RoundedRectangle(cornerRadius: 20) // app:cardCornerRadius="20dp"
                .fill(Color("cardBackgroundColornew")) // style="@style/cardBackgroundColor"
        )
        .clipShape(RoundedRectangle(cornerRadius: 20)) // Clip content to rounded corners
        .padding(.trailing, isSentByMe ? 0 : 0) // No outer side spacing for emoji card
        .padding(.leading, isSentByMe ? 0 : 0)
        .padding(.top, 2) // android:layout_marginTop="2dp"
        .padding(.bottom, 2) // android:layout_marginBottom="2dp"
        .onAppear {
            // Initialize with static emojis first (matching Android - adapter is set immediately)
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
    
    // Left gradient bars (matching Android LinearLayout bars on left side - ttt, tt, t, and one more)
    @ViewBuilder
    private var leftGradientBars: some View {
        // HStack(spacing: 0) {
        //     // Bars with decreasing alpha: 0.6, 0.5, 0.4, 0.3 (matching Android ttt, tt, t, and one more)
        //     gradientBar(alpha: 0.6) // ttt
        //     gradientBar(alpha: 0.5) // tt
        //     gradientBar(alpha: 0.4) // t
        //     gradientBar(alpha: 0.3) // one more
        // }
    }
    
    // Right gradient bars (matching Android LinearLayout bars on right side - before addEmoji)
    @ViewBuilder
    private var rightGradientBars: some View {
        // HStack(spacing: 0) {
        //     // Bars with increasing alpha: 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.0, 1.0, 1.0
        //     gradientBar(alpha: 0.1)
        //     gradientBar(alpha: 0.2)
        //     gradientBar(alpha: 0.3)
        //     gradientBar(alpha: 0.4)
        //     gradientBar(alpha: 0.5)
        //     gradientBar(alpha: 0.6)
        //     gradientBar(alpha: 0.7)
        //     gradientBar(alpha: 0.8)
        //     gradientBar(alpha: 0.9)
        //     gradientBar(alpha: 1.0)
        //     gradientBar(alpha: 1.0)
        //     gradientBar(alpha: 1.0)
        //     gradientBar(alpha: 1.0)
        // }
    }
    
    // Individual gradient bar (matching Android LinearLayout bars)
    @ViewBuilder
    private func gradientBar(alpha: Double) -> some View {
        Rectangle()
            .fill(Color("cardBackgroundColornew"))
            .opacity(alpha) // android:alpha
            .frame(width: 4, height: 40) // android:layout_width="4dp" android:layout_height="40dp"
    }
    
    // MARK: - Emoji Reaction Button (matching Android emojiAdapterChatAdapter)
    @ViewBuilder
    private func emojiReactionButton(displayEmoji: DisplayEmoji) -> some View {
        let currentUserId = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        // Check if current user has reacted with this emoji
        let userReaction = currentEmojiModels.first { $0.name == currentUserId && $0.emoji == displayEmoji.character }
        let isUserReaction = userReaction != nil
        
        // Determine emoji container size (matching Android: customSize = unicodeName.isEmpty ? 25 : 40)
        // If unicodeName is empty (Firebase emoji), container size is 25dp, otherwise 40dp (static emoji)
        // Text size is always 25sp (matching Android textSize="25sp")
        let containerSize: CGFloat = displayEmoji.unicodeName.isEmpty ? 25 : 40
        let textSize: CGFloat = 25 // Always 25sp (matching Android textSize="25sp")
        
        Button(action: {
            handleEmojiTap(displayEmoji: displayEmoji)
        }) {
            Text(displayEmoji.character)
                .font(.system(size: textSize)) // Always 25sp text size (matching Android textSize="25sp")
                .frame(width: containerSize, height: nil) // Fixed width, height wraps text space (matching Android wrap_content)
                .frame(minHeight: containerSize) // Minimum height matching container size
                .background(
                    Circle()
                        .fill(isUserReaction ? Color(hex: "#00A3E9").opacity(0.3) : Color.clear) // color_circle for user, custome_ripple_circle for others
                )
        }
        .padding(.horizontal, 2) // android:layout_marginHorizontal="2dp"
    }
    
    // MARK: - Helper Functions for Emoji Reactions
    
    // Setup Firebase listener for emoji updates (matching Android get_emojiChatadapter)
    private func setupEmojiListener() {
        let currentUserId = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        let receiverUid = contact.uid
        let receiverRoom = receiverUid + currentUserId
        let messageId = message.id
        
        let database = Database.database().reference()
        let emojiPath = "\(Constant.CHAT)/\(receiverRoom)/\(messageId)/emojiModel"
        
        // Initialize displayEmojis with static emojis first (matching Android)
        displayEmojis = staticEmojis
        
        // Initialize with current message emojiModel
        if let emojiModels = message.emojiModel {
            currentEmojiModels = emojiModels.filter { !$0.name.isEmpty && !$0.emoji.isEmpty }
        }
        
        // Listen for Firebase updates and combine with static emojis (matching Android get_emojiChatadapter)
        // Use continuous listener to update when new emojis are added (matching Android adapter behavior)
        emojiListenerHandle = database.child(emojiPath).observe(.value) { snapshot in
            var emojiModels: [EmojiModel] = []
            var emojiHashSet = Set<String>() // Track duplicates (matching Android HashSet)
            
            // Add static emojis to HashSet first (matching Android)
            for emoji in self.staticEmojis {
                emojiHashSet.insert(emoji.character)
            }
            
            // Get Firebase emojis (matching Android snapshot.getChildren())
            if let emojiArray = snapshot.value as? [[String: Any]] {
                for emojiDict in emojiArray {
                    let emoji = emojiDict["emoji"] as? String ?? ""
                    let name = emojiDict["name"] as? String ?? ""
                    
                    // Only process non-empty emojis (matching Android null checks)
                    if !emoji.isEmpty && !name.isEmpty {
                        emojiModels.append(EmojiModel(name: name, emoji: emoji))
                        
                        // Track unique emojis (matching Android HashSet logic)
                        if !emojiHashSet.contains(emoji) {
                            emojiHashSet.insert(emoji)
                        }
                    }
                }
            }
            
            // Update currentEmojiModels and rebuild displayEmojis (matching Android adapter.notifyDataSetChanged())
            DispatchQueue.main.async {
                self.currentEmojiModels = emojiModels
                // Rebuild displayEmojis from static + Firebase (matching Android)
                self.updateDisplayEmojis()
            }
        }
    }
    
    // Update display emojis combining static and Firebase (matching Android get_emojiChatadapter)
    private func updateDisplayEmojis() {
        var combinedEmojis = staticEmojis
        var emojiHashSet = Set<String>() // Track duplicates (matching Android HashSet)
        
        // Add static emojis to HashSet first (matching Android)
        for emoji in staticEmojis {
            emojiHashSet.insert(emoji.character)
        }
        
        // Add Firebase emojis that aren't in static list (matching Android logic)
        // Android: if (emoji != null && name != null && !emojiHashSet.contains(emoji))
        for emojiModel in currentEmojiModels {
            let emoji = emojiModel.emoji
            let name = emojiModel.name
            
            // Only add if emoji is not null, name is not null, and not already in HashSet
            if !emoji.isEmpty && !name.isEmpty && !emojiHashSet.contains(emoji) {
                let firebaseEmoji = DisplayEmoji(
                    slug: "",
                    character: emoji,
                    unicodeName: name,
                    codePoint: "",
                    isFromFirebase: true
                )
                combinedEmojis.append(firebaseEmoji)
                emojiHashSet.insert(emoji) // Add to HashSet to prevent duplicates
            }
        }
        
        // Always add empty emoji at end if last one isn't empty (matching Android)
        // Android: if (!emojis.get(emojis.size() - 1).getCharacter().isEmpty())
        if let lastEmoji = combinedEmojis.last, !lastEmoji.character.isEmpty {
            let emptyEmoji = DisplayEmoji(
                slug: "e0-6-red-heart",
                character: "",
                unicodeName: "",
                codePoint: "2764 FE0F"
            )
            combinedEmojis.append(emptyEmoji)
        }
        
        // Update displayEmojis (matching Android adapter.notifyDataSetChanged())
        displayEmojis = combinedEmojis
    }
    
    // Remove Firebase listener
    private func removeEmojiListener() {
        if let handle = emojiListenerHandle {
            let database = Database.database().reference()
            let currentUserId = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
            let receiverUid = contact.uid
            let receiverRoom = receiverUid + currentUserId
            let messageId = message.id
            let emojiPath = "\(Constant.CHAT)/\(receiverRoom)/\(messageId)/emojiModel"
            database.child(emojiPath).removeObserver(withHandle: handle)
            emojiListenerHandle = nil
        }
    }
    
    // Fetch available emojis from API (matching Android Webservice.get_emojiAdd)
    private func fetchAvailableEmojis() {
        // If already loading or already have emojis, skip (matching Android behavior)
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
    
    // Handle emoji tap - add or remove (matching Android emojiAdapterChatAdapter onClick)
    private func handleEmojiTap(displayEmoji: DisplayEmoji) {
        guard !displayEmoji.character.isEmpty else { return } // Skip empty emoji
        
        // Haptic feedback (matching Android Constant.Vibrator(mContext))
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        let currentUserId = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        // Check if user already reacted with this emoji
        let userReaction = currentEmojiModels.first { $0.name == currentUserId && $0.emoji == displayEmoji.character }
        
        // Dismiss dialog when tapping emoji (matching Android BlurHelper.dialogLayoutColor.dismiss())
        isPresented = false
        
        if let reaction = userReaction {
            // Remove emoji (matching Android delete emoji logic)
            removeEmoji(emojiCharacter: displayEmoji.character)
        } else {
            // Add emoji (matching Android add emoji logic)
            addEmoji(emojiCharacter: displayEmoji.character)
        }
    }
    
    // Add emoji to Firebase (matching Android emojiAdapterChatAdapter add logic)
    private func addEmoji(emojiCharacter: String) {
        let currentUserId = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        let receiverUid = contact.uid
        let receiverRoom = receiverUid + currentUserId
        let senderRoom = currentUserId + receiverUid
        let messageId = message.id
        
        let database = Database.database().reference()
        let emojiPath = "\(Constant.CHAT)/\(receiverRoom)/\(messageId)/emojiModel"
        
        database.child(emojiPath).observeSingleEvent(of: .value) { snapshot in
            var emojiMap: [String: EmojiModel] = [:]
            var isUpdated = false
            
            if snapshot.exists(), let emojiArray = snapshot.value as? [[String: Any]] {
                for emojiDict in emojiArray {
                    let name = emojiDict["name"] as? String ?? ""
                    let emoji = emojiDict["emoji"] as? String ?? ""
                    if !name.isEmpty {
                        if name == currentUserId {
                            // Update existing emoji for same user
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
            
            // Update receiver room
            database.child(emojiPath).setValue(emojiList.map { ["name": $0.name, "emoji": $0.emoji] })
            database.child("\(Constant.CHAT)/\(receiverRoom)/\(messageId)/emojiCount").setValue(emojiCountStr)
            
            // Update sender room
            database.child("\(Constant.CHAT)/\(senderRoom)/\(messageId)/emojiModel").setValue(emojiList.map { ["name": $0.name, "emoji": $0.emoji] })
            database.child("\(Constant.CHAT)/\(senderRoom)/\(messageId)/emojiCount").setValue(emojiCountStr)
            
            // TODO: Send notification (matching Android Webservice.create_individual_chattingForEmojiReact)
        }
    }
    
    // Add emoji from picker (matching Android emoji_adapter_addbtn onClick logic exactly)
    private func addEmojiFromPicker(emojiCharacter: String) {
        let currentUserId = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        guard !currentUserId.isEmpty else { return } // Ensure name is non-empty (matching Android)
        
        let receiverUid = contact.uid
        let receiverRoom = receiverUid + currentUserId
        let senderRoom = currentUserId + receiverUid
        let messageId = message.id
        
        let database = Database.database().reference()
        let emojiPath = "\(Constant.CHAT)/\(receiverRoom)/\(messageId)/emojiModel"
        
        database.child(emojiPath).observeSingleEvent(of: .value) { snapshot in
            var emojiMap: [String: EmojiModel] = [:]
            var isUpdated = false
            let newEmoji = emojiCharacter
            
            // Load old data (matching Android snapshot.exists() check)
            if snapshot.exists(), let emojiArray = snapshot.value as? [[String: Any]] {
                for emojiDict in emojiArray {
                    let name = emojiDict["name"] as? String ?? ""
                    let emoji = emojiDict["emoji"] as? String ?? ""
                    if !name.isEmpty {
                        if name == currentUserId {
                            // Update existing emoji for the same name (matching Android existingEmoji.setEmoji(newEmoji))
                            emojiMap[name] = EmojiModel(name: name, emoji: newEmoji)
                            isUpdated = true
                        } else {
                            emojiMap[name] = EmojiModel(name: name, emoji: emoji)
                        }
                    }
                }
            }
            
            // If not updated, add new entry (matching Android)
            if !isUpdated {
                emojiMap[currentUserId] = EmojiModel(name: currentUserId, emoji: newEmoji)
            }
            
            // Update database only if changes are made (matching Android !emojiMap.isEmpty check)
            if !emojiMap.isEmpty {
                let emojiList = Array(emojiMap.values)
                let emojiCountStr = String(emojiList.count)
                
                // Update receiver room (matching Android emojiRef.setValue)
                database.child(emojiPath).setValue(emojiList.map { ["name": $0.name, "emoji": $0.emoji] }) { error, _ in
                    if error == nil {
                        // Update emoji count (matching Android onCompleteListener)
                        database.child("\(Constant.CHAT)/\(receiverRoom)/\(messageId)/emojiCount").setValue(emojiCountStr)
                        database.child("\(Constant.CHAT)/\(senderRoom)/\(messageId)/emojiModel").setValue(emojiList.map { ["name": $0.name, "emoji": $0.emoji] })
                        database.child("\(Constant.CHAT)/\(senderRoom)/\(messageId)/emojiCount").setValue(emojiCountStr)
                    }
                }
            }
        }
    }
    
    // Remove emoji from Firebase (matching Android emojiAdapterChatAdapter remove logic)
    private func removeEmoji(emojiCharacter: String) {
        let currentUserId = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        let receiverUid = contact.uid
        let receiverRoom = receiverUid + currentUserId
        let senderRoom = currentUserId + receiverUid
        let messageId = message.id
        
        let database = Database.database().reference()
        let emojiPath = "\(Constant.CHAT)/\(receiverRoom)/\(messageId)/emojiModel"
        
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
                // Insert empty emojiModel (matching Android)
                let emptyList: [[String: String]] = [["name": "", "emoji": ""]]
                database.child(emojiPath).setValue(emptyList)
                database.child("\(Constant.CHAT)/\(senderRoom)/\(messageId)/emojiModel").setValue(emptyList)
            } else {
                database.child(emojiPath).setValue(emojiList.map { ["name": $0.name, "emoji": $0.emoji] })
                database.child("\(Constant.CHAT)/\(senderRoom)/\(messageId)/emojiModel").setValue(emojiList.map { ["name": $0.name, "emoji": $0.emoji] })
            }
            
            // Update emoji count
            database.child("\(Constant.CHAT)/\(receiverRoom)/\(messageId)/emojiCount").setValue(emojiCountStr)
            database.child("\(Constant.CHAT)/\(senderRoom)/\(messageId)/emojiCount").setValue(emojiCountStr)
        }
    }
    
    // Emoji picker sheet (matching Android bottom_emoji_lyt)
    @ViewBuilder
    private var emojiPickerSheet: some View {
        NavigationView {
            ZStack {
                // Show progress indicator while loading (matching Android ProgressBar visibility)
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
                    // Show emoji list (matching Android RecyclerView with GridLayoutManager, 9 columns)
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 40), spacing: 8)], spacing: 8) {
                            ForEach(availableEmojis, id: \.slug) { emojiData in
                                Button(action: {
                                    // Haptic feedback (matching Android Constant.Vibrator for Android Q+)
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                    
                                    // Add emoji to Firebase (matching Android emoji_adapter_addbtn onClick)
                                    addEmojiFromPicker(emojiCharacter: emojiData.character)
                                    
                                    // Dismiss emoji picker sheet (matching Android Constant.bottomSheetDialog.dismiss())
                                    showEmojiPicker = false
                                    
                                    // Dismiss long press dialog (matching Android BlurHelper.dialogLayoutColor.dismiss())
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
    
    // Helper function to get message preview text for non-text messages
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
    
    // Helper function to detect text content type (matching MessageBubbleView logic)
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
}

// MARK: - ChattingScreen Extension for Emoji Reactions
extension ChattingScreen {
    // MARK: - Emoji Reactions Bottom Sheet (matching Android bottom_emoji_lyt)
    @ViewBuilder
    var emojiReactionsBottomSheet: some View {
        VStack(spacing: 0) {
            // Custom drag handle (matching Android CardView with black_white_cross background)
            // CardView (40dp x 5dp) containing LinearLayout with two small dots inside
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color("black_white_cross"))
                    .frame(width: 40, height: 5)
                
                // Two small dots inside the bar (matching Android LinearLayout inside CardView)
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color("edittextBg"))
                        .frame(width: 3, height: 3)
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color("edittextBg"))
                        .frame(width: 3, height: 3)
                }
            }
            .padding(.vertical, 5)
            
            // Emoji reactions list (matching Android RecyclerView)
            if isLoadingEmojiReactions {
                ProgressView()
                    .progressViewStyle(LinearProgressViewStyle(tint: Color("TextColor")))
                    .frame(height: 4)
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(emojiReactionsList, id: \.name) { emojiModel in
                            EmojiReactionRow(emojiModel: emojiModel, receiverUid: contact.uid)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .frame(height: 400) // android:layout_height="400dp"
            }
        }
        .background(Color("BackgroundColor"))
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden) // Hide default drag indicator, use custom one
        .applyPresentationBackground() // Remove white background (iOS 16.4+)
        .onDisappear {
            removeEmojiReactionsListener()
        }
    }
    
    // Load emoji reactions from Firebase (matching Android emojiRef.addValueEventListener)
    func loadEmojiReactions(for message: ChatMessage) {
        isLoadingEmojiReactions = true
        emojiReactionsList = []
        
        let currentUserId = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        let receiverUid = contact.uid
        let receiverRoom = receiverUid + currentUserId
        let messageId = message.id
        
        let database = Database.database().reference()
        let emojiPath = "\(Constant.CHAT)/\(receiverRoom)/\(messageId)/emojiModel"
        
        // Remove existing listener if any
        removeEmojiReactionsListener()
        
        // Add listener for real-time updates
        emojiReactionsListenerHandle = database.child(emojiPath).observe(.value) { snapshot in
            var emojiList: [EmojiModel] = []
            
            if snapshot.exists(), let emojiArray = snapshot.value as? [[String: Any]] {
                for emojiDict in emojiArray {
                    let name = emojiDict["name"] as? String ?? ""
                    let emoji = emojiDict["emoji"] as? String ?? ""
                    if !name.isEmpty && !emoji.isEmpty {
                        emojiList.append(EmojiModel(name: name, emoji: emoji))
                    }
                }
            }
            
            emojiReactionsList = emojiList
            isLoadingEmojiReactions = false
        }
    }
    
    // Remove emoji reactions listener
    func removeEmojiReactionsListener() {
        if let handle = emojiReactionsListenerHandle {
            Database.database().reference().removeObserver(withHandle: handle)
            emojiReactionsListenerHandle = nil
        }
    }
}

// MARK: - MessageLongPressDialog Extension
extension MessageLongPressDialog {
    // Get sender message background color (matching Android senderMessageBackgroundColor)
    private func getSenderMessageBackgroundColor(colorScheme: ColorScheme) -> Color {
        // Light mode: always use legacy bubble color (#011224) to match Android light theme
        guard colorScheme == .dark else {
            return Color(hex: "#011224")
        }
        
        // Dark mode: use theme-based tinted backgrounds (matching Android)
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
    
    // Get receiver message background color (matching Android receiver glass background)
    private func getReceiverMessageBackgroundColor() -> Color {
        // Use glassmorphism background similar to receiver messages
        return Color("cardBackgroundColornew")
    }
}

// MARK: - View Extension for Presentation Background
extension View {
    @ViewBuilder
    func applyPresentationBackground() -> some View {
        if #available(iOS 16.4, *) {
            self.presentationBackground(Color("BackgroundColor"))
        } else {
            self
        }
    }
}

// MARK: - Emoji Reaction Row (matching Android emoji_people_row.xml)
struct EmojiReactionRow: View {
    let emojiModel: EmojiModel
    let receiverUid: String
    @State private var userName: String = ""
    @State private var userPhotoUrl: String = ""
    @State private var isLoading: Bool = true
    
    var body: some View {
        HStack(spacing: 0) {
            // Profile image (matching Android contact1img)
            AsyncImage(url: URL(string: userPhotoUrl)) { phase in
                switch phase {
                case .empty:
                    Image("inviteimg")
                        .resizable()
                        .scaledToFill()
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Image("inviteimg")
                        .resizable()
                        .scaledToFill()
                @unknown default:
                    Image("inviteimg")
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .padding(.top, 16)
            
            // User name (matching Android contact1text)
            Text(userName)
                .font(.custom("Inter18pt-Bold", size: 16))
                .fontWeight(.semibold)
                .foregroundColor(Color("TextColor"))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Emoji (matching Android emojiTxt)
            Text(emojiModel.emoji)
                .font(.system(size: 22))
                .foregroundColor(Color(hex: "#000000"))
                .padding(.trailing, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("BackgroundColor"))
        .onAppear {
            loadUserInfo()
        }
    }
    
    private func loadUserInfo() {
        let currentUserId = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        
        if emojiModel.name == currentUserId {
            // Current user - use local data (matching Android logic)
            userName = UserDefaults.standard.string(forKey: Constant.full_name) ?? ""
            userPhotoUrl = UserDefaults.standard.string(forKey: Constant.profilePic) ?? ""
            isLoading = false
        } else {
            // Other user - fetch from API (matching Android Webservice.get_profile_UserInfoEmoji)
            // TODO: Implement API call to fetch user info
            // For now, use the UID as name
            userName = emojiModel.name
            isLoading = false
        }
    }
}

// MARK: - Bunch Image Preview Dialog (for viewing selectionBunch images - matching Android multiple_show_image_screen)
struct BunchImagePreviewDialog: View {
    @Environment(\.dismiss) private var dismiss
    let images: [SelectionBunchModel]
    @Binding var currentIndex: Int
    let onDismiss: () -> Void
    
    init(images: [SelectionBunchModel], currentIndex: Binding<Int>, onDismiss: @escaping () -> Void) {
        print("📸 [BunchPreview] BunchImagePreviewDialog init called with \(images.count) images")
        for (index, img) in images.enumerated() {
            print("📸 [BunchPreview] Init image \(index): fileName=\(img.fileName), imgUrl=\(img.imgUrl.isEmpty ? "empty" : String(img.imgUrl.prefix(50)))")
        }
        self.images = images
        self._currentIndex = currentIndex
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        ZStack {
            // Full-screen background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar with back button and image count
                HStack {
                    // Back button
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
                    
                    // Image count indicator
                    Text("\(currentIndex + 1) / \(images.count)")
                        .font(.custom("Inter18pt-Medium", size: 16))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Spacer to balance layout
                    Spacer()
                        .frame(width: 40)
                }
                .frame(height: 60)
                .background(Color.black.opacity(0.3))
                
                // Image preview area (matching Android RecyclerView with MultipleImageAdapter)
                GeometryReader { geometry in
                    TabView(selection: $currentIndex) {
                            ForEach(Array(images.enumerated()), id: \.offset) { index, imageModel in
                                ZStack {
                                    Color.black
                                    
                                    // Use CachedAsyncImage for better loading (matching Android MultipleImageAdapter)
                                    Group {
                                        if let imageURL = getImageURL(for: imageModel) {
                                            CachedAsyncImage(
                                                url: imageURL,
                                                content: { image in
                                                    print("✅ [BunchPreview] Image \(index) loaded successfully from: \(imageURL.absoluteString)")
                                                    return image
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                                        .clipped()
                                                },
                                                placeholder: {
                                                    print("⏳ [BunchPreview] Image \(index) loading from: \(imageURL.absoluteString)")
                                                    return ProgressView()
                                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                                }
                                            )
                                        } else {
                                            // Fallback if URL is invalid
                                            VStack {
                                                Image(systemName: "photo")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 100, height: 100)
                                                    .foregroundColor(.white.opacity(0.5))
                                                Text("Image not available")
                                                    .foregroundColor(.white.opacity(0.7))
                                                    .font(.caption)
                                                Text("fileName: \(imageModel.fileName)")
                                                    .foregroundColor(.white.opacity(0.5))
                                                    .font(.caption2)
                                                Text("imgUrl: \(imageModel.imgUrl.isEmpty ? "empty" : String(imageModel.imgUrl.prefix(50)))")
                                                    .foregroundColor(.white.opacity(0.5))
                                                    .font(.caption2)
                                            }
                                        }
                                    }
                                    .onAppear {
                                        let imageURL = getImageURL(for: imageModel)
                                        print("📸 [BunchPreview] Image \(index) - URL result: \(imageURL?.absoluteString ?? "nil")")
                                        if imageURL == nil {
                                            print("🚫 [BunchPreview] Image \(index) - No valid URL found. fileName: '\(imageModel.fileName)', imgUrl: '\(imageModel.imgUrl)'")
                                        }
                                    }
                                }
                                .tag(index)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .onChange(of: currentIndex) { newIndex in
                            // Update binding when user swipes (TabView handles the swipe automatically)
                            print("📸 [BunchPreview] Swiped to image \(newIndex + 1) / \(images.count)")
                        }
                    }
                }
            }
        .onAppear {
            print("📸 [BunchPreview] ========== DIALOG APPEARED ==========")
            print("📸 [BunchPreview] Total images: \(images.count)")
            print("📸 [BunchPreview] Current index: \(currentIndex)")
            
            if images.isEmpty {
                print("🚫 [BunchPreview] ERROR: images array is EMPTY!")
            } else {
                for (index, imageModel) in images.enumerated() {
                    print("📸 [BunchPreview] --- Image \(index) ---")
                    print("📸 [BunchPreview]   fileName: '\(imageModel.fileName)'")
                    print("📸 [BunchPreview]   imgUrl: '\(imageModel.imgUrl.isEmpty ? "EMPTY" : imageModel.imgUrl)'")
                    print("📸 [BunchPreview]   imgUrl length: \(imageModel.imgUrl.count)")
                    
                    // Test URL resolution immediately
                    let testURL = getImageURL(for: imageModel)
                    print("📸 [BunchPreview]   Resolved URL: \(testURL?.absoluteString ?? "nil")")
                }
            }
            print("📸 [BunchPreview] ======================================")
        }
    }
    
    private func getImageURL(for imageModel: SelectionBunchModel) -> URL? {
        print("🔍 [BunchPreview] getImageURL called - fileName: '\(imageModel.fileName)', imgUrl: '\(imageModel.imgUrl.isEmpty ? "empty" : imageModel.imgUrl)'")
        
        // Check local file first (matching Android doesFileExist logic)
        if !imageModel.fileName.isEmpty {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let imagesDir = documentsPath.appendingPathComponent("Enclosure/Media/Images", isDirectory: true)
            let localURL = imagesDir.appendingPathComponent(imageModel.fileName)
            
            print("📁 [BunchPreview] Checking local file at: \(localURL.path)")
            
            // Check if directory exists
            var isDirectory: ObjCBool = false
            let dirExists = FileManager.default.fileExists(atPath: imagesDir.path, isDirectory: &isDirectory)
            print("📁 [BunchPreview] Images directory exists: \(dirExists), isDirectory: \(isDirectory.boolValue)")
            
            if FileManager.default.fileExists(atPath: localURL.path) {
                print("✅ [BunchPreview] Local file FOUND: \(localURL.path)")
                return localURL
            } else {
                print("🚫 [BunchPreview] Local file NOT FOUND: \(localURL.path)")
                // List files in directory for debugging
                if let files = try? FileManager.default.contentsOfDirectory(atPath: imagesDir.path) {
                    print("📁 [BunchPreview] Files in directory: \(files.prefix(10))")
                }
            }
        } else {
            print("⚠️ [BunchPreview] fileName is empty")
        }
        
        // Fallback to online URL (matching Android network URL loading)
        if !imageModel.imgUrl.isEmpty {
            print("🌐 [BunchPreview] Checking network URL: \(imageModel.imgUrl)")
            if let url = URL(string: imageModel.imgUrl) {
                print("✅ [BunchPreview] Valid network URL created: \(url.absoluteString)")
                return url
            } else {
                print("🚫 [BunchPreview] Invalid network URL format: \(imageModel.imgUrl)")
            }
        } else {
            print("⚠️ [BunchPreview] imgUrl is empty for fileName: \(imageModel.fileName)")
        }
        
        print("🚫 [BunchPreview] No valid URL found for image")
        return nil
    }
}

// MARK: - Typing Indicator Dots View (Fallback when Lottie is not available)
struct TypingIndicatorDotsView: View {
    @State private var animationPhase: CGFloat = 0
    @State private var dotOpacities: [Double] = [0.3, 0.3, 0.3]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color("TextColor"))
                    .frame(width: 8, height: 8)
                    .opacity(dotOpacities[index])
            }
        }
        .onAppear {
            let _ = print("🎬 [TypingIndicatorDotsView] View appeared, starting animation")
            // Animate dots with staggered timing
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.0)) {
                dotOpacities[0] = 1.0
            }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.2)) {
                dotOpacities[1] = 1.0
            }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.4)) {
                dotOpacities[2] = 1.0
            }
        }
    }
}

// MARK: - Clear Chat Dialog (matching Android delete_popup_row.xml)
struct ClearChatDialog: View {
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

// MARK: - Block User Dialog (matching Android delete_ac_dialogue.xml)
struct BlockUserDialog: View {
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
            
            // Dialog card (matching Clear All dialog size: 268dp width, cardBackgroundColornew, 20dp corner radius, 20dp padding)
            VStack(spacing: 0) {
                // Inner content (matching Clear All dialog structure)
                VStack(spacing: 0) {
                    // Title text (matching Android TextView: layout_marginTop="20dp", layout_marginStart="10dp", layout_marginEnd="10dp")
                    Text("Block this user.\nBlock it's message.")
                        .font(.custom("Inter18pt-Regular", size: 17))
                        .foregroundColor(Color("TextColor"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(25) // Matching Android lineHeight="25dp"
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20) // Matching Android layout_marginTop="20dp"
                        .padding(.horizontal, 10) // Matching Android layout_marginStart="10dp" and layout_marginEnd="10dp"
                    
                    // Buttons container (matching Android LinearLayout: layout_marginTop="20dp", layout_marginBottom="20dp")
                    HStack(spacing: 0) {
                        // Cancel button (matching Android AppCompatButton: layout_marginEnd="20dp", 36dp height, 15sp, black backgroundTint, white text)
                        Button(action: {
                            withAnimation {
                                isPresented = false
                            }
                        }) {
                            Text("Cancel")
                                .font(.custom("Inter18pt-Medium", size: 15))
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .frame(height: 36) // Matching Android layout_height="36dp"
                                .padding(.horizontal, 20)
                                .background(Color.black) // Matching Android backgroundTint="@color/black"
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.trailing, 20) // Matching Android layout_marginEnd="20dp"
                        
                        // Sure button (matching Android AppCompatButton: 36dp height, 15sp, red backgroundTint, white text)
                        Button(action: {
                            withAnimation {
                                isPresented = false
                            }
                            onConfirm()
                        }) {
                            Text("Sure")
                                .font(.custom("Inter18pt-Medium", size: 15))
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .frame(height: 36) // Matching Android layout_height="36dp"
                                .padding(.horizontal, 20)
                                .background(Color.red) // Matching Android backgroundTint="@color/red"
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20) // Matching Android layout_marginTop="20dp"
                    .padding(.bottom, 20) // Matching Android layout_marginBottom="20dp"
                }
            }
            .padding(20) // Matching Clear All dialog padding="20dp"
            .frame(width: 268) // Matching Clear All dialog width="268dp"
            .background(
                RoundedRectangle(cornerRadius: 20) // Matching Android cardCornerRadius="20dp"
                    .fill(Color("cardBackgroundColornew")) // Matching Android cardBackgroundColor="@color/cardBackgroundColornew"
                    .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10) // Matching Android elevation="20dp"
            )
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPresented)
    }
}
