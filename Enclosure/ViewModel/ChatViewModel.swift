//
//  ChatViewModel.swift
//  Enclosure
//
//  Created by Ram Lohar on 02/05/25.
//


import Foundation
import FirebaseDatabase

private enum ChatCacheFallbackReason: CustomStringConvertible {
    case prefetch
    case offline
    case error(String?)

    var description: String {
        switch self {
        case .prefetch:
            return "prefetch"
        case .offline:
            return "offline"
        case .error(let message):
            return "error(\(message ?? "nil"))"
        }
    }
}

class ChatViewModel: ObservableObject {
    @Published var chatList: [UserActiveContactModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasCachedChats = false

    private let cacheManager = ChatCacheManager.shared
    private let networkMonitor = NetworkMonitor.shared
    
    // Firebase listener handle
    private var firebaseListenerHandle: DatabaseHandle?
    private var isRefreshingFromSocket = false // Prevent recursive calls
    private var isFetchInFlight = false // Prevent duplicate API calls
    
    init() {
        // Listen for immediate delete notifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DeleteChatImmediately"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let uid = notification.userInfo?["uid"] as? String {
                self?.removeFromList(uid: uid)
            }
        }

        // Refresh chat list when returning from ChattingScreen
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RefreshChatListAfterChattingScreen"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            print("🔵 [ChatViewModel] Refresh requested after ChattingScreen")
            self.fetchChatList(uid: Constant.SenderIdMy)
        }
    }
    
    deinit {
        // Remove Firebase listener when view model is deallocated
        removeChattingSocketListener()
    }

    // Internal method to fetch chat list without setting up listener (used by socket refresh)
    private func fetchChatListInternal(uid: String) {
        if isFetchInFlight {
            print("🔵 [ChatViewModel] fetchChatListInternal skipped (already in flight)")
            return
        }
        isFetchInFlight = true

        // Populate cached data immediately so UI can reuse it while fresh data loads.
        loadCachedChats(reason: .prefetch, shouldStopLoading: false)

        guard networkMonitor.isConnected else {
            print("🔵 [ChatViewModel] No internet connection, loading cached chats")
            loadCachedChats(reason: .offline)
            isFetchInFlight = false
            return
        }
        
        ApiService.get_user_active_chat_list(uid: uid) { success, message, data, myDeviceType in
            DispatchQueue.main.async {
                self.isFetchInFlight = false
                print("🔵 [ChatViewModel] API callback received - success: \(success), message: '\(message)', data count: \(data?.count ?? 0)")
                // Reset socket refresh flag
                self.isRefreshingFromSocket = false
                self.isLoading = false
                if success {
                    self.chatList = data ?? []
                    self.errorMessage = nil // Clear error on success
                    self.hasCachedChats = !self.chatList.isEmpty
                    print("🔵 [ChatViewModel] SUCCESS - chatList count: \(self.chatList.count), errorMessage: \(self.errorMessage ?? "nil")")

                    // Donate intents for top chats so Communication UI has metadata on device
                    self.donateCommunicationIntentsIfNeeded()
                    
                    // Sender device_type from get_user_active_chat_list (for send_notification_api) - do not use static "2"
                    if let dt = myDeviceType, !dt.isEmpty {
                        UserDefaults.standard.set(dt, forKey: Constant.DEVICE_TYPE_KEY)
                        print("🔵 [ChatViewModel] device_type from get_user_active_chat_list (my_device_type): \(dt)")
                    }
                    
                    // Print FCM tokens for all contacts
                    print("🔵 [ChatViewModel] ===== CONTACT FCM TOKENS =====")
                    for (index, contact) in self.chatList.enumerated() {
                        print("🔵 [ChatViewModel] Contact #\(index + 1) - UID: \(contact.uid), Name: \(contact.fullName)")
                        print("🔵 [ChatViewModel]   FCM Token: \(contact.fToken.isEmpty ? "EMPTY" : contact.fToken)")
                        print("🔵 [ChatViewModel]   FCM Token Preview: \(contact.fToken.isEmpty ? "EMPTY" : "\(contact.fToken.prefix(50))...")")
                    }
                    print("🔵 [ChatViewModel] ===== END FCM TOKENS =====")
                    
                    self.cacheManager.cacheChats(self.chatList)
                    print("🔵 [ChatViewModel] Contacts cached to SQLite database")
                    
                    // Optionally refresh device_type from get_profile only when value is "1" or "2" (same format as get_user_active_chat_list)
                    if myDeviceType == nil || myDeviceType?.isEmpty == true {
                        ApiService.get_profile(uid: uid) { _, profile, _ in
                            if let dt = profile?.device_type, !dt.isEmpty, (dt == "1" || dt == "2") {
                                UserDefaults.standard.set(dt, forKey: Constant.DEVICE_TYPE_KEY)
                                print("🔵 [ChatViewModel] device_type from get_profile (1/2): \(dt)")
                            }
                        }
                    }
                } else {
                    // Only set error message if message is not empty
                    self.errorMessage = message.isEmpty ? nil : message
                    self.chatList = data ?? [] // Set data even on error if available
                    print("🔵 [ChatViewModel] ERROR - errorMessage: '\(self.errorMessage ?? "nil")', chatList count: \(self.chatList.count)")

                    if self.chatList.isEmpty {
                        self.loadCachedChats(reason: .error(message))
                    }
                }
            }
        }
    }

    private func donateCommunicationIntentsIfNeeded() {
        guard #available(iOS 15.0, *) else { return }
        let maxDonate = 10
        let topChats = chatList.prefix(maxDonate)
        for contact in topChats {
            let senderName = contact.fullName
            let message = contact.message
            let senderUid = contact.uid
            let photoUrl = contact.photo
            CommunicationNotificationManager.shared.donateIntent(
                senderName: senderName,
                message: message,
                senderUid: senderUid,
                photoUrl: photoUrl
            )
        }
        print("🔵 [ChatViewModel] Donated intents for top \(topChats.count) chats")
    }
    
    func fetchChatList(uid: String) {
        print("🔵 [ChatViewModel] fetchChatList called with uid: \(uid)")
        
        // Set up Firebase listener if not already set up (matching Android ChattingRoomUtils)
        // Only set up once, not on every fetch
        if firebaseListenerHandle == nil {
            setupChattingSocketListener(uid: uid)
        }
        
        // Ensure @Published updates happen on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Don't show loading indicator if refreshing from socket (matching Android behavior)
            if !self.isRefreshingFromSocket {
                self.isLoading = true
            }
            self.errorMessage = nil // Clear previous error
            print("🔵 [ChatViewModel] isLoading set to true, errorMessage cleared")
        }

        // Call internal method to fetch chat list
        fetchChatListInternal(uid: uid)
    }
    
    // MARK: - Firebase Realtime Database Listener (matching Android ChattingRoomUtils)
    private func setupChattingSocketListener(uid: String) {
        // Only set up listener once
        guard firebaseListenerHandle == nil else {
            print("🔵 [ChatViewModel] Firebase listener already set up")
            return
        }
        
        let database = Database.database().reference()
        let chattingSocketPath = "\(Constant.chattingSocket)/\(uid)"
        
        print("🔵 [ChatViewModel] Setting up Firebase listener for path: \(chattingSocketPath)")
        
        // Listen for value changes (matching Android addValueEventListener)
        firebaseListenerHandle = database.child(chattingSocketPath).observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            
            // Get the message value (matching Android snapshot.getValue(String.class))
            if snapshot.exists(), let message = snapshot.value as? String {
                print("🔵 [ChatViewModel] Live update received: \(message)")
                
                // Refresh chat list when socket message changes (matching Android)
                // This triggers a refresh of the active chat list
                DispatchQueue.main.async {
                    print("🔵 [ChatViewModel] Refreshing chat list due to socket update")
                    self.isRefreshingFromSocket = true
                    // Call fetchChatListInternal to avoid setting up listener again
                    self.fetchChatListInternal(uid: uid)
                }
            } else {
                // No message found (matching Android "No message found")
                print("⚠️ [ChatViewModel] No message found (snapshot doesn't exist or value is not String)")
            }
        } withCancel: { error in
            // Handle cancellation/error (matching Android onCancelled)
            print("🚫 [ChatViewModel] Firebase database error: \(error.localizedDescription)")
        }
        
        // Verify listener was set up
        if firebaseListenerHandle != nil {
            print("✅ [ChatViewModel] Firebase listener set up successfully with handle: \(firebaseListenerHandle!)")
        } else {
            print("🚫 [ChatViewModel] Failed to set up Firebase listener")
        }
    }
    
    private func removeChattingSocketListener() {
        guard let handle = firebaseListenerHandle else { return }
        
        let database = Database.database().reference()
        let chattingSocketPath = "\(Constant.chattingSocket)/\(Constant.SenderIdMy)"
        
        print("🔵 [ChatViewModel] Removing Firebase listener for path: \(chattingSocketPath)")
        database.child(chattingSocketPath).removeObserver(withHandle: handle)
        firebaseListenerHandle = nil
    }

    private func loadCachedChats(reason: ChatCacheFallbackReason, shouldStopLoading: Bool = true) {
        cacheManager.fetchChats { [weak self] cachedChats in
            guard let self = self else { return }
            // Ensure all @Published property updates happen on main thread
            DispatchQueue.main.async {
                self.chatList = cachedChats
                self.hasCachedChats = !cachedChats.isEmpty
                if shouldStopLoading {
                    self.isLoading = false
                }

                switch reason {
                case .offline:
                    self.errorMessage = cachedChats.isEmpty ? "You are offline. No cached chats available." : nil
                case .prefetch:
                    // Keep any existing error state; just ensure cached items are visible.
                    break
                case .error(let message):
                    if cachedChats.isEmpty {
                        self.errorMessage = message?.isEmpty == false ? message : "Unable to load chats."
                    } else {
                        self.errorMessage = nil
                    }
                }

                print("🔵 [ChatViewModel] Loaded \(cachedChats.count) cached chats for reason: \(reason)")
            }
        }
    }
    
    // Immediately remove chat from list (optimistic update)
    private func removeFromList(uid: String) {
        print("🔴 [ChatViewModel] Immediately removing chat from list - uid: \(uid)")
        // Ensure @Published updates happen on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.chatList.removeAll { $0.uid == uid }
            // Update cache immediately
            self.cacheManager.cacheChats(self.chatList)
        }
    }
    
    // Delete chat functionality
    func deleteChat(uid: String, receiverUid: String) {
        print("🔴 [ChatViewModel] deleteChat called - uid: \(uid), receiverUid: \(receiverUid)")
        
        // Immediately remove from local list (optimistic update)
        removeFromList(uid: receiverUid)
        
        // Call API in background
        ApiService.delete_individual_user_chatting(uid: uid, friendId: receiverUid) { success, message in
            DispatchQueue.main.async {
                if success {
                    print("🔴 [ChatViewModel] Delete SUCCESS")
                } else {
                    print("🔴 [ChatViewModel] Delete FAILED - message: \(message)")
                }
            }
        }
    }
}
