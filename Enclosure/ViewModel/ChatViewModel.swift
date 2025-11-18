//
//  ChatViewModel.swift
//  Enclosure
//
//  Created by Ram Lohar on 02/05/25.
//


import Foundation


class ChatViewModel: ObservableObject {
    @Published var chatList: [UserActiveContactModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func fetchChatList(uid: String) {
        print("🔵 [ChatViewModel] fetchChatList called with uid: \(uid)")
        isLoading = true
        errorMessage = nil // Clear previous error
        print("🔵 [ChatViewModel] isLoading set to true, errorMessage cleared")
        
        ApiService.get_user_active_chat_list(uid: uid) { success, message, data in
            DispatchQueue.main.async {
                print("🔵 [ChatViewModel] API callback received - success: \(success), message: '\(message)', data count: \(data?.count ?? 0)")
                self.isLoading = false
                if success {
                    self.chatList = data ?? []
                    self.errorMessage = nil // Clear error on success
                    print("🔵 [ChatViewModel] SUCCESS - chatList count: \(self.chatList.count), errorMessage: \(self.errorMessage ?? "nil")")
                } else {
                    // Only set error message if message is not empty
                    self.errorMessage = message.isEmpty ? nil : message
                    self.chatList = data ?? [] // Set data even on error if available
                    print("🔵 [ChatViewModel] ERROR - errorMessage: '\(self.errorMessage ?? "nil")', chatList count: \(self.chatList.count)")
                }
            }
        }
    }
}
