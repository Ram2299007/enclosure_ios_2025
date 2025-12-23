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
    
    var body: some View {
        ZStack {
            // Background color matching Android modetheme2
            Color("BackgroundColor")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Message list
                ZStack(alignment: .top) {
                    messageListView
                    
                    // Date view overlay (matching Android datelyt)
                    if showDateView {
                        dateView
                            .zIndex(1000) // Ensure it's on top
                            .padding(.top, 8) // Add some top padding
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
                    }
                }
                
                // Bottom input area
                bottomInputView
            }
            
            // Menu overlay
            if showMenu {
                menuOverlay
            }
        }
        .navigationBarHidden(true)
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
                }
            )
            .onAppear {
                print("MultiDocumentPreviewDialog: fullScreenCover onAppear")
                print("MultiDocumentPreviewDialog: Captured documents count: \(documentsToShow.count)")
                print("MultiDocumentPreviewDialog: Captured documents: \(documentsToShow.map { $0.lastPathComponent })")
                print("MultiDocumentPreviewDialog: Current state documents count: \(multiDocumentPreviewURLs.count)")
            }
        }
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
            
            // Fetch messages (matching Android fetchMessages)
            fetchMessages(receiverRoom: receiverRoom) {
                print("✅ Messages fetched successfully")
            }
        }
        .onDisappear {
            // Remove Firebase listeners when leaving screen
            removeFirebaseListeners()
            
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
                ScrollView {
                    LazyVStack(spacing: 8) { // spacing="8dp" matching Android layout_marginTop="8dp"
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
                            ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                                MessageBubbleView(
                                    message: message,
                                    onHalfSwipe: { swipedMessage in
                                        handleHalfSwipeReply(swipedMessage)
                                    }
                                )
                                    .id(message.id)
                                    .background(
                                        // Detect when first message (index 0) becomes visible (matching Android findFirstVisibleItemPosition == 0)
                                        Group {
                                            if index == 0 {
                                                GeometryReader { geo in
                                                    Color.clear.preference(
                                                        key: ScrollOffsetPreferenceKey.self,
                                                        value: geo.frame(in: .named("scroll")).minY
                                                    )
                                                }
                                    }
                                        }
                                    )
                                    .background(
                                        // Track first visible message for date display
                                        GeometryReader { geo in
                                            let frame = geo.frame(in: .named("scroll"))
                                            // Consider item visible if it's in the visible area (minY >= 0 and maxY <= screen height)
                                            let isVisible = frame.minY >= -50 && frame.maxY <= UIScreen.main.bounds.height + 50
                                            return Color.clear.preference(
                                                key: FirstVisibleItemPreferenceKey.self,
                                                value: isVisible ? index : nil
                                            )
                                        }
                                    )
                                    .onAppear {
                                        handleLastItemVisibility(id: message.id, index: index, isAppearing: true)
                                        
                                        // When last message appears, scroll to it once (for initial load only)
                                        // This ensures we only scroll once when the view is actually rendered (like WhatsApp)
                                        if index == messages.count - 1 && hasPerformedInitialScroll && !hasScrolledToBottom {
                                            print("🟢 [SCROLL_DEBUG] Last message appeared - performing single scroll to: \(message.id)")
                                            
                                            // Scroll immediately when last message appears (like WhatsApp)
                                            print("🟢 [SCROLL_DEBUG] Executing scroll to: \(message.id)")
                                            
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
                                                print("🟢 [SCROLL_DEBUG] Initial scroll completed - loadMore enabled")
                                            }
                                        }
                                    }
                                    .onDisappear {
                                        handleLastItemVisibility(id: message.id, index: index, isAppearing: false)
                                    }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .coordinateSpace(name: "scroll")
                // Show date view on touch anywhere in the message list (drag with minimumDistance 0 = touch down)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            // Fire once per touch sequence
                            if !isTouchGestureActive {
                                isTouchGestureActive = true
                                print("📅 [DATE_TAP] List touched - calling expandDateView()")
                                expandDateView()
                            }
                        }
                        .onEnded { _ in
                            isTouchGestureActive = false
                        }
                )
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
                    print("🟢 [SCROLL_DEBUG] onChange(initialLoadDone) called - done: \(done), hasScrolledToBottom: \(hasScrolledToBottom), messages.count: \(messages.count)")
                }
                .onChange(of: pendingInitialScrollId) { targetId in
                    guard let id = targetId, !hasScrolledToBottom else { return }
                    print("🟢 [SCROLL_DEBUG] Performing initial scroll via pendingInitialScrollId - id: \(id)")
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
                        print("🟢 [SCROLL_DEBUG] Initial scroll completed - loadMore enabled")
                    }
                }
                .onChange(of: messages.count) { newCount in
                    print("🔵 [SCROLL_DEBUG] onChange(messages.count) called - newCount: \(newCount), hasScrolledToBottom: \(hasScrolledToBottom), previousCount: \(messages.count), isInitialScrollInProgress: \(isInitialScrollInProgress), hasPerformedInitialScroll: \(hasPerformedInitialScroll)")
                    guard newCount > 0, let lastMessage = messages.last else {
                        print("🔵 [SCROLL_DEBUG] Scroll skipped - no messages or no lastMessage")
                        return
                    }
                    
                    // For new incoming messages after initial scroll
                    if hasScrolledToBottom && !isInitialScrollInProgress && hasPerformedInitialScroll {
                        if allowAnimatedScroll {
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
        }
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
                    .frame(height: 50) // Match send button height (50dp)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color("message_box_bg"))
                    )
                    .padding(.horizontal, 5)
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
                    
                    // Small counter badge (Android multiSelectSmallCounterText)
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
            .padding(.top, 30) // Add top padding to make room for counter badge
            .contentShape(Rectangle()) // Clear boundary for message input area to prevent gesture interference
            .background(Color("edittextBg")) // Ensure solid background to prevent visual overlap
            .clipped() // Clip the message input area to prevent overflow
            
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
        .clipped() // Clip the entire message input container
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
                    print("❌ [fetchEmojis] Error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    print("❌ [fetchEmojis] No data received")
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
                    print("❌ [fetchEmojis] JSON parsing error: \(error.localizedDescription)")
                }
            }
        }.resume()
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
                        print("❌ [fetchMessages] Error parsing message for key: \(childKey), error: \(error.localizedDescription)")
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
                print("❌ [fetchMessages] Error fetching initial messages: \(error.localizedDescription)")
                
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
                                      oldModel.timestamp != updatedModel.timestamp ||
                                      oldModel.document != updatedModel.document
                        
                        if isChanged {
                            DispatchQueue.main.async {
                                self.messages[index] = updatedModel
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
        
        // Handle Text, Image, Video, Document, Contact, and VoiceAudio datatype messages
        guard model.dataType == Constant.Text || model.dataType == Constant.img || model.dataType == Constant.video || model.dataType == Constant.doc || model.dataType == Constant.contact || model.dataType == Constant.voiceAudio else {
            print("📱 [handleChildAdded] Skipping unsupported message type: \(model.dataType)")
            return
        }
        
        // Skip messages that were already loaded in initial fetch (prevent duplicates)
        // When listener attaches, it fires for all existing messages, not just new ones
        // But we want to add older messages that weren't in the initial load
        if initiallyLoadedMessageIds.contains(model.id) {
            print("📱 [handleChildAdded] Skipping duplicate - message already loaded in initial fetch: \(model.id)")
            return
        }
        
        // Check if message already exists in current list (additional duplicate check)
        // This handles cases where message might have been added from listener before
        if messages.contains(where: { $0.id == model.id }) {
            print("📱 [handleChildAdded] Skipping duplicate - message already in list: \(model.id)")
            return
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
            self.messages = updatedMessageList
            
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
                // Scroll will be handled by ScrollViewReader in messageListView
                print("📱 [handleChildAdded] 🚀 FAST REAL-TIME SCROLL - New receiver message")
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
            print("❌ [parseMessageFromDict] Error parsing message: \(error.localizedDescription)")
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
            print("❌ [loadMore] Error loading more messages: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.isLoadingMore = false
            }
        }
    }
    
    /// Scroll to the bottom message, optionally animated (mirrors Android smooth scroll)
    private func scrollToBottom(animated: Bool) {
        guard let lastId = messages.last?.id, let proxy = scrollViewProxy else { return }
        
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
    
    /// Trigger reply UI (Android half-swipe) for a given message
    private func handleHalfSwipeReply(_ message: ChatMessage) {
        let senderName = message.uid == Constant.SenderIdMy ? "You" : (message.userName?.isEmpty == false ? message.userName! : contact.fullName)
        let previewText = replyPreviewText(for: message)
        
        withAnimation {
            replySenderName = senderName
            replyMessage = previewText
            replyDataType = message.dataType
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
                    // User is at the last message, hide down button (matching Android)
                    self.isLastItemVisible = true
                    self.showScrollDownButton = false
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
    
    // MARK: - Gallery helpers (iOS parity with Android dataRecview)
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
        
        // Upload all images to Firebase Storage, then push to API + RTDB
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
        
        dispatchGroup.notify(queue: .main) {
            if uploadResults.isEmpty {
                print("❌ [MULTI_IMAGE] Upload failed - no results")
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
            
            let newMessage = ChatMessage(
                id: modelId,
                uid: senderId,
                message: "",
                time: currentDateTimeString,
                document: first.downloadURL,
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
                fileName: first.fileName,
                thumbnail: nil,
                fileNameThumbnail: nil,
                caption: trimmedCaption,
                notification: 1,
                currentDate: currentDateString,
                emojiModel: [EmojiModel(name: "", emoji: "")],
                emojiCount: nil,
                timestamp: timestamp,
                imageWidth: "\(first.width)",
                imageHeight: "\(first.height)",
                aspectRatio: aspectRatioValue,
                selectionCount: "\(sortedResults.count)",
                selectionBunch: selectionBunchModels,
                receiverLoader: 0
            )
            
            // Add to UI immediately
            self.messages.append(newMessage)
            self.isLastItemVisible = true
            self.showScrollDownButton = false
            
            let userFTokenKey = UserDefaults.standard.string(forKey: Constant.FCM_TOKEN) ?? ""
            
            MessageUploadService.shared.uploadMessage(
                model: newMessage,
                filePath: nil,
                userFTokenKey: userFTokenKey,
                deviceType: "2"
            ) { success, errorMessage in
                if success {
                    print("✅ [MULTI_IMAGE] Uploaded \(sortedResults.count) images for modelId=\(modelId)")
                } else {
                    print("❌ [MULTI_IMAGE] Upload error: \(errorMessage ?? "Unknown error")")
                    Constant.showToast(message: "Failed to send images. Please try again.")
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
            print("❌ [LOCAL_STORAGE] Error saving image to local storage: \(error.localizedDescription)")
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
            print("❌ [LOCAL_STORAGE] Error listing images: \(error.localizedDescription)")
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
        
        // Request microphone permission
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
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
                
                // Add to UI immediately
                DispatchQueue.main.async {
                    self.messages.append(newMessage)
                    self.isLastItemVisible = true
                    self.showScrollDownButton = false
                }
                
                // Upload via MessageUploadService
                let userFTokenKey = UserDefaults.standard.string(forKey: Constant.FCM_TOKEN) ?? ""
                
                MessageUploadService.shared.uploadMessage(
                    model: newMessage,
                    filePath: fileURL.path,
                    userFTokenKey: userFTokenKey,
                    deviceType: "2"
                ) { success, errorMessage in
                    if success {
                        print("✅ [VOICE_RECORDING] Uploaded audio for modelId=\(modelId)")
                    } else {
                        print("❌ [VOICE_RECORDING] Upload error: \(errorMessage ?? "Unknown error")")
                        Constant.showToast(message: "Failed to send audio. Please try again.")
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
            print("❌ [DOWNLOAD] No fileName available")
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
                    print("❌ [DOWNLOAD] Download failed: \(error.localizedDescription)")
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
            print("❌ [DOWNLOAD] No fileName available")
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
                    print("❌ [DOWNLOAD] Download failed: \(error.localizedDescription)")
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
        
        print("❌ [VIDEO] No valid video URL found. hasLocalFile: \(hasLocalFile), videoUrl: \(videoUrl)")
        return nil
    }
    
    // Play video
    private func playVideo() {
        print("▶️ [VIDEO] Play button tapped")
        
        guard let videoURL = getVideoURL() else {
            print("❌ [VIDEO] No video URL available")
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
            print("❌ [DOWNLOAD] No fileName available")
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
                    print("❌ [DOWNLOAD] Download failed: \(error.localizedDescription)")
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
                                print("❌ [VIDEO] Player is nil in sheet")
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
            print("❌ [VIDEO] No video URL available")
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
            print("❌ [DOWNLOAD] No fileName available")
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
                    print("❌ [DOWNLOAD] Download failed: \(error.localizedDescription)")
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
                                print("❌ [VIDEO] Player is nil in sheet")
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
            print("❌ [DOWNLOAD] No fileName available")
            return
        }
        
        guard !documentUrl.isEmpty else {
            print("❌ [DOWNLOAD] No document URL available")
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
                    print("❌ [DOWNLOAD] Download failed: \(error.localizedDescription)")
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
                            print("❌ [SenderDocumentView] fullScreenCover triggered but documentPreviewURL is nil!")
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
                    print("❌ [SenderDocumentView] Local file exists but is empty")
                }
            } else {
                print("❌ [SenderDocumentView] Local file not found: \(localFile.path)")
            }
        } else {
            print("❌ [SenderDocumentView] Audios directory not found: \(audiosDir.path)")
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
            print("❌ [SenderDocumentView] No document URL available")
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
            print("❌ [DOWNLOAD] No fileName available")
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
                    print("❌ [DOWNLOAD] Download failed: \(error.localizedDescription)")
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
            print("❌ [DOWNLOAD] No fileName available")
            return
        }
        
        guard !documentUrl.isEmpty else {
            print("❌ [DOWNLOAD] No document URL available")
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
                    print("❌ [DOWNLOAD] Download failed: \(error.localizedDescription)")
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
                            print("❌ [ReceiverDocumentView] fullScreenCover triggered but documentPreviewURL is nil!")
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
                    print("❌ [ReceiverDocumentView] Local file exists but is empty")
                }
            } else {
                print("❌ [ReceiverDocumentView] Local file not found: \(localFile.path)")
            }
        } else {
            print("❌ [ReceiverDocumentView] Audios directory not found: \(audiosDir.path)")
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
            print("❌ [ReceiverDocumentView] No document URL available")
        }
    }
    
    // Download document and open when complete
    private func downloadDocumentAndOpen() {
        guard !fileName.isEmpty else {
            print("❌ [DOWNLOAD] No fileName available")
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
                    print("❌ [DOWNLOAD] Download failed: \(error.localizedDescription)")
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
        print("❌ [DocumentPreviewView] File not found locally: \(fileName)")
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
                            .scaledToFit()
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
                    print("❌ [DocumentPreviewView] Failed to load image from: \(localURL.path)")
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
            print("❌ [DocumentPreviewView] File not found locally, showing download controls")
            isDownloaded = false
        }
    }
    
    // Download file
    private func downloadFile() {
        guard let downloadUrl = downloadUrl, !downloadUrl.isEmpty else {
            print("❌ [DocumentPreviewView] No download URL available")
            return
        }
        
        guard !fileName.isEmpty else {
            print("❌ [DOWNLOAD] No fileName available")
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
                    print("❌ [DOWNLOAD] Download failed: \(error.localizedDescription)")
                }
            }
        )
    }
    
    // Open downloaded file with external app
    private func openDownloadedFile() {
        guard let localURL = localFileURL else {
            print("❌ [DocumentPreviewView] File not found locally")
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
            print("❌ [DocumentPreviewView] File not found locally")
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
                                print("❌ Error saving video: \(error?.localizedDescription ?? "Unknown error")")
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
                    print("❌ [BUNCH] Download failed: \(bunch.fileName) - \(error.localizedDescription)")
                    
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
                    print("❌ [BUNCH] Download failed: \(bunch.fileName) - \(error.localizedDescription)")
                    
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
    
    // Check if local file exists (for sender)
    private var hasLocalFile: Bool {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagesDir = documentsPath.appendingPathComponent("Enclosure/Media/Images", isDirectory: true)
        let localURL = imagesDir.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: localURL.path)
    }
    
    // Get image source URL (local first, then online)
    private var sourceURL: URL? {
        // Check local file first
        if hasLocalFile {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let imagesDir = documentsPath.appendingPathComponent("Enclosure/Media/Images", isDirectory: true)
            return imagesDir.appendingPathComponent(fileName)
        }
        
        // Fallback to online URL
        if let url = URL(string: imageUrl), !imageUrl.isEmpty {
            return url
        }
        
        return nil
    }
    
    var body: some View {
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
        .clipShape(RoundedCorner(radius: cornerRadius, corners: corners))
    }
}

// MARK: - Message Bubble View (matching Android sample_sender.xml)
struct MessageBubbleView: View {
    let message: ChatMessage
    let isSentByMe: Bool
    let onHalfSwipe: (ChatMessage) -> Void
    @GestureState private var dragTranslation: CGSize = .zero
    @State private var isDragging: Bool = false
    private let halfSwipeThreshold: CGFloat = 60
    @Environment(\.colorScheme) private var colorScheme
    
    init(message: ChatMessage, onHalfSwipe: @escaping (ChatMessage) -> Void = { _ in }) {
        self.message = message
        self.isSentByMe = message.uid == Constant.SenderIdMy
        self.onHalfSwipe = onHalfSwipe
    }
    
    var body: some View {
        HStack {
            if isSentByMe {
                Spacer()
            }
            
            VStack(alignment: isSentByMe ? .trailing : .leading, spacing: 0) {
                // Main message bubble container (matching Android MainSenderBox)
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
                                    backgroundColor: getSenderMessageBackgroundColor()
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
                            // Regular text message
                            HStack {
                                Spacer(minLength: 0) // Push content to end
                                Text(message.message)
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
                            .frame(maxWidth: 250) // maxWidth constraint - wrap content up to max
                        }
                    }
                    
                } else {
                    // Check if this is an image bunch message (matching Android recImgBunchLyt)
                    // Allow selectionCount >= 2 (including 5+ images which show 2x2 grid with +N overlay)
                    if message.dataType == Constant.img,
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
                                    selectionCount: selectionCount
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
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color("message_box_bg"))
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
                                    aspectRatio: message.aspectRatio
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
                                // Container background matching receiver text message (same as Constant.Text receiver messages)
                                RoundedRectangle(cornerRadius: 12) // matching receiver text message corner radius
                                    .fill(Color("message_box_bg")) // Same background as receiver text messages
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
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color("message_box_bg"))
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
                                RoundedRectangle(cornerRadius: 20) // Android: contactContainer should match message container corner radius
                                    .fill(Color("message_box_bg"))
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
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color("message_box_bg"))
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
                                RoundedRectangle(cornerRadius: 20) // Changed to 20dp to match Android
                                    .fill(Color("message_box_bg"))
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
                            // Regular text message
                            HStack {
                                Text(message.message)
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
                                        RoundedRectangle(cornerRadius: 12) // matching Android corner radius
                                            .fill(Color("message_box_bg"))
                                    )
                                Spacer(minLength: 0) // Don't expand beyond content
                            }
                            .frame(maxWidth: 250) // maxWidth constraint - wrap content up to max
                        }
                    }
                }
                
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
            
            if !isSentByMe {
                Spacer()
            }
        }
        .padding(.horizontal, 10) // side margin like Android screen margins
        .contentShape(Rectangle())
        .offset(x: isDragging && dragTranslation.width > 0 ? min(dragTranslation.width, halfSwipeThreshold) : 0)
        .overlay(
            // Real-time swipe feedback overlay (matching Android HalfSwipeCallback drawReplyIconWithoutBackground)
            swipeFeedbackOverlay
        )
        .simultaneousGesture(
            // Use simultaneousGesture so it doesn't block vertical scrolling
            DragGesture(minimumDistance: 15)
                .updating($dragTranslation) { value, state, _ in
                    let horizontal = value.translation.width
                    let vertical = abs(value.translation.height)
                    
                    // Only activate if horizontal movement is clearly dominant (2x vertical) and swiping right
                    // This ensures vertical scrolling works smoothly
                    if horizontal > 15 && abs(horizontal) > vertical * 2.0 {
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
        )
        
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
                
                // Icon and progress circle dimensions (matching Android)
                let iconSize: CGFloat = 60
                let progressCircleDiameter: CGFloat = 90
                let iconMoveDistance = horizontal / 2 // Icon moves half the swipe distance
                
                // Start from left edge (matching Android leftMargin = 0)
                let leftMargin: CGFloat = 0
                let progressLeft = leftMargin + iconMoveDistance
                
                // Center vertically in the message bubble
                let centerY = geometry.size.height / 2
                
                // Progress circle center (matching Android)
                let progressCenterX = progressLeft + progressCircleDiameter / 2
                let progressCenterY = centerY
                
                ZStack {
                    // Circular progress ring (matching Android Paint.Style.STROKE)
                    if scale > 0 {
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                getReplyIconColor(),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: progressCircleDiameter, height: progressCircleDiameter)
                            .rotationEffect(.degrees(-90)) // Start from top (matching Android -90 degrees)
                            .position(x: progressCenterX, y: progressCenterY)
                            .scaleEffect(scale)
                            .opacity(scale)
                        
                        // Reply icon (matching Android reply_svg_black)
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: iconSize, height: iconSize)
                            .foregroundColor(progress >= 1.0 ? .red : getReplyIconColor())
                            .position(x: progressCenterX, y: progressCenterY)
                            .scaleEffect(scale)
                            .opacity(scale)
                        
                        // Fill effect when threshold reached (matching Android destruction effect)
                        if progress >= 1.0 {
                            Circle()
                                .fill(getReplyIconColor())
                                .frame(width: progressCircleDiameter, height: progressCircleDiameter)
                                .position(x: progressCenterX, y: progressCenterY)
                                .blendMode(.sourceAtop)
                        }
                    }
                }
                .allowsHitTesting(false) // Don't interfere with gestures
            }
        }
    }
    
    // Get reply icon color based on sender (matching Android logic)
    private func getReplyIconColor() -> Color {
        if isSentByMe {
            // Sender: use theme color
            return Color(hex: Constant.themeColor)
        } else {
            // Receiver: use gray color (matching Android R.color.halfReplyColor)
            // Fallback to gray if color asset doesn't exist
            return Color(red: 0x78/255.0, green: 0x78/255.0, blue: 0x7A/255.0) // #78787A gray
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
    
    // Progress indicator styling based on Android LinearProgressIndicator
    private func progressIndicatorView(isSender: Bool) -> some View {
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
    
    private var selectedAssets: [PHAsset] {
        photoAssets.filter { selectedAssetIds.contains($0.localIdentifier)         }
    }
    
    var body: some View {
        ZStack {
            // Full-screen background (matching Android transparent background)
            Color.black
                .ignoresSafeArea()
            
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
                .padding(.bottom, keyboardHeight > 0 ? keyboardHeight - 20 : 10)
                .background(Color.black)
            }
        }
        .onAppear {
            print("MultiImagePreviewDialog: onAppear - Initial caption: '\(caption)' (length: \(caption.count))")
            loadAllImages()
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
                    print("❌ [MusicPlayer] Local file exists but is empty")
                }
            } else {
                print("❌ [MusicPlayer] Local file not found: \(localFile.path)")
            }
        } else {
            print("❌ [MusicPlayer] Audios directory not found: \(audiosDir.path)")
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
            print("❌ [MusicPlayer] Invalid audio URL: \(finalAudioUrl)")
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
                        print("❌ [Contact] Failed to save contact: \(error.localizedDescription)")
                    }
                }
            } else {
                print("❌ [Contact] Contact access denied")
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
            print("❌ [Contact] Failed to save contact to local storage: \(error.localizedDescription)")
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
                    print("❌ [Contact] Download failed: \(error.localizedDescription)")
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
                    print("❌ [Contact] Download failed: \(error.localizedDescription)")
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
                        print("❌ [Contact] Failed to save contact: \(error.localizedDescription)")
                    }
                }
            } else {
                print("❌ [Contact] Contact access denied")
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
            print("❌ [Contact] Failed to save contact to local storage: \(error.localizedDescription)")
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
                    print("❌ [VoiceAudio] Download failed: \(error.localizedDescription)")
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
                print("❌ [Contact] Failed to add phone number: \(error.localizedDescription)")
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
                    let _ = print("❌ [LinkPreview] Failed to load image from \(imageUrlString): \(error.localizedDescription)")
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
                print("❌ [LinkPreview] Failed to fetch HTML: \(error?.localizedDescription ?? "unknown error")")
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
                            .background(Color("message_box_bg")) // Matching Constant.voiceAudio receiver container color
                        }
                        .background(Color("receiverChatBox")) // Android: background="@color/receiverChatBox"
                    }
                    .background(Color("message_box_bg")) // Android: cardBackgroundColor matching Constant.Text receiver messages
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
                print("❌ [LinkPreview] Failed to fetch HTML: \(error?.localizedDescription ?? "unknown error")")
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

