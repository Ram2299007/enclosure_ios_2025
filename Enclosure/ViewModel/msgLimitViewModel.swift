//
//  youViewModel.swift
//  Enclosure
//
//  Created by Ram Lohar on 08/05/25.
//

import Foundation
import SwiftUI

class MsgLimitViewModel: ObservableObject {
    @Published var chatList: [UserActiveContactModel] = []
    @Published var filteredChatList: [UserActiveContactModel] = []
    @Published var AllLmtList: [GetMessageLimitForAllUsersModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showAlert = false
    @Published var tapPosition = CGPoint.zero
    @Published var currentUserLimit: String = "0"
    
    private var allChatList: [UserActiveContactModel] = []

    func fetch_user_active_chat_list_for_msgLmt(uid: String) {
        isLoading = true
        ApiService.get_user_active_chat_list_for_msgLmt(uid: uid) { success, message, data in
            DispatchQueue.main.async {
                self.isLoading = false
                if success {
                    let fetchedList = data ?? []
                    // Filter out current user and blocked users (similar to Android)
                    self.allChatList = fetchedList.filter { contact in
                        contact.uid != uid // Filter out current user
                        // Note: Add block check if UserActiveContactModel has a block property
                    }
                    self.chatList = self.allChatList
                    self.filteredChatList = self.allChatList
                } else {
                    self.errorMessage = message
                    self.chatList = []
                    self.filteredChatList = []
                }
            }
        }
    }

    func fetch_message_limit_for_all_users(uid: String) {
        isLoading = true
        ApiService.get_message_limit_for_all_users(uid: uid) { success, message, data in
            DispatchQueue.main.async {
                self.isLoading = false
                if success {
                    self.AllLmtList = data ?? []
                    // Get the limit value from the first item or UserDefaults
                    if let firstLimit = data?.first?.msg_limit {
                        self.currentUserLimit = firstLimit
                    } else {
                        // Try to get from UserDefaults (saved from previous set)
                        let savedLimit = UserDefaults.standard.string(forKey: "msg_limitFORALL") ?? "0"
                        self.currentUserLimit = savedLimit
                    }
                } else {
                    self.errorMessage = message
                    // Try to get from UserDefaults if API fails
                    let savedLimit = UserDefaults.standard.string(forKey: "msg_limitFORALL") ?? "0"
                    self.currentUserLimit = savedLimit
                }
            }
        }
    }
    
    func set_message_limit_for_all_users(uid: String, msg_limit: String) {
        ApiService.set_message_limit_for_all_users(uid: uid, msg_limit: msg_limit) { success, message in
            DispatchQueue.main.async {
                if success {
                    self.currentUserLimit = msg_limit
                    // Refresh the chat list after setting limit
                    self.fetch_user_active_chat_list_for_msgLmt(uid: uid)
                    Constant.showToast(message: "Msg limit is shown for privacy for a day - \(msg_limit)")
                } else {
                    self.errorMessage = message
                }
            }
        }
    }
    
    func set_message_limit_for_user_chat(uid: String, friend_id: String, msg_limit: String) {
        ApiService.set_message_limit_for_user_chat(uid: uid, friend_id: friend_id, msg_limit: msg_limit) { success, message in
            DispatchQueue.main.async {
                if success {
                    // Update the specific contact's limit in the list
                    if let index = self.chatList.firstIndex(where: { $0.uid == friend_id }) {
                        // Note: UserActiveContactModel might need to be updated to reflect the new limit
                        // For now, we'll refresh the list
                        self.fetch_user_active_chat_list_for_msgLmt(uid: uid)
                    }
                    Constant.showToast(message: "Msg limit is shown for privacy for a day - \(msg_limit)")
                } else {
                    self.errorMessage = message
                }
            }
        }
    }
    
    func filterChatList(searchText: String) {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            filteredChatList = chatList
        } else {
            filteredChatList = chatList.filter { contact in
                contact.fullName.lowercased().contains(trimmed.lowercased()) ||
                contact.mobileNo.contains(trimmed)
            }
        }
    }
}
