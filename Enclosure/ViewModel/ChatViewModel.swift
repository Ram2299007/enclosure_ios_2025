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
        isLoading = true
        ApiService.get_user_active_chat_list(uid: uid) { success, message, data in
            DispatchQueue.main.async {
                  self.isLoading = false
                if success {
                    self.chatList = data ?? []
                } else {
                    self.errorMessage = message
                }
            }
        }
    }
}
