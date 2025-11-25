//
//  ChatViewModel.swift
//  Enclosure
//
//  Created by Ram Lohar on 02/05/25.
//


import Foundation

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
    }

    func fetchChatList(uid: String) {
        print("🔵 [ChatViewModel] fetchChatList called with uid: \(uid)")
        isLoading = true
        errorMessage = nil // Clear previous error
        print("🔵 [ChatViewModel] isLoading set to true, errorMessage cleared")

        // Populate cached data immediately so UI can reuse it while fresh data loads.
        loadCachedChats(reason: .prefetch, shouldStopLoading: false)

        guard networkMonitor.isConnected else {
            print("🔵 [ChatViewModel] No internet connection, loading cached chats")
            loadCachedChats(reason: .offline)
            return
        }
        
        ApiService.get_user_active_chat_list(uid: uid) { success, message, data in
            DispatchQueue.main.async {
                print("🔵 [ChatViewModel] API callback received - success: \(success), message: '\(message)', data count: \(data?.count ?? 0)")
                self.isLoading = false
                if success {
                    self.chatList = data ?? []
                    self.errorMessage = nil // Clear error on success
                    self.hasCachedChats = !self.chatList.isEmpty
                    print("🔵 [ChatViewModel] SUCCESS - chatList count: \(self.chatList.count), errorMessage: \(self.errorMessage ?? "nil")")
                    self.cacheManager.cacheChats(self.chatList)
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

    private func loadCachedChats(reason: ChatCacheFallbackReason, shouldStopLoading: Bool = true) {
        cacheManager.fetchChats { [weak self] cachedChats in
            guard let self = self else { return }
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
    
    // Immediately remove chat from list (optimistic update)
    private func removeFromList(uid: String) {
        print("🔴 [ChatViewModel] Immediately removing chat from list - uid: \(uid)")
        chatList.removeAll { $0.uid == uid }
        // Update cache immediately
        cacheManager.cacheChats(chatList)
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
                    // No toast shown
                } else {
                    print("🔴 [ChatViewModel] Delete FAILED - message: \(message)")
                    // Show error toast only
                    Constant.showToast(message: "Failed to delete chat")
                }
            }
        }
    }
}
