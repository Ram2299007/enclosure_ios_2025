//
//  youViewModel.swift
//  Enclosure
//
//  Created by Ram Lohar on 08/05/25.
//

import Foundation
import SwiftUI

private enum MsgLimitCacheReason: CustomStringConvertible, Equatable {
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

class MsgLimitViewModel: ObservableObject {
    @Published var chatList: [UserActiveContactModel] = []
    @Published var filteredChatList: [UserActiveContactModel] = []
    @Published var AllLmtList: [GetMessageLimitForAllUsersModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showAlert = false
    @Published var tapPosition = CGPoint.zero
    @Published var currentUserLimit: String = "0"
    @Published var hasCachedContacts = false
    
    private var allChatList: [UserActiveContactModel] = []
    private let cacheManager = CallCacheManager.shared
    private let networkMonitor = NetworkMonitor.shared

    func fetch_user_active_chat_list_for_msgLmt(uid: String) {
        isLoading = true
        errorMessage = nil
        
        loadCachedContacts(reason: .prefetch, shouldStopLoading: false)
        
        guard networkMonitor.isConnected else {
            loadCachedContacts(reason: .offline)
            return
        }
        
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
                    self.hasCachedContacts = !self.allChatList.isEmpty
                    self.cacheManager.cacheMsgLimitContacts(self.allChatList)
                } else {
                    self.errorMessage = message
                    if !self.hasCachedContacts {
                        self.loadCachedContacts(reason: .error(message))
                    }
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
    
    private func loadCachedContacts(reason: MsgLimitCacheReason, shouldStopLoading: Bool = true) {
        cacheManager.fetchMsgLimitContacts { [weak self] cachedContacts in
            guard let self = self else { return }
            if cachedContacts.isEmpty && reason == .prefetch {
                if shouldStopLoading {
                    self.isLoading = false
                }
                return
            }
            
            self.allChatList = cachedContacts
            self.chatList = cachedContacts
            self.filteredChatList = cachedContacts
            self.hasCachedContacts = !cachedContacts.isEmpty
            if shouldStopLoading {
                self.isLoading = false
            }
            
            switch reason {
            case .offline:
                self.errorMessage = cachedContacts.isEmpty ? "You are offline. No cached contacts available." : nil
            case .prefetch:
                break
            case .error(let message):
                if cachedContacts.isEmpty {
                    self.errorMessage = message?.isEmpty == false ? message : "Unable to load contacts."
                } else {
                    self.errorMessage = nil
                }
            }
            
            print("📊 [MsgLimitViewModel] Loaded \(cachedContacts.count) cached contacts for reason: \(reason)")
        }
    }
}
