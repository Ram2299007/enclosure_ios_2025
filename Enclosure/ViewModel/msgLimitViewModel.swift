//
//  youViewModel.swift
//  Enclosure
//
//  Created by Ram Lohar on 08/05/25.
//

import Foundation

class MsgLimitViewModel: ObservableObject {
    @Published var chatList: [UserActiveContactModel] = []
    @Published var AllLmtList: [GetMessageLimitForAllUsersModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showAlert = false
    @Published var tapPosition = CGPoint.zero

    func fetch_user_active_chat_list_for_msgLmt(uid: String) {
        isLoading = true
        ApiService.get_user_active_chat_list_for_msgLmt(uid: uid) { success, message, data in
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


    func fetch_message_limit_for_all_users(uid: String) {
        isLoading = true
        ApiService.get_message_limit_for_all_users(uid: uid) { success, message, data in
            DispatchQueue.main.async {
                  self.isLoading = false
                if success {
                    self.AllLmtList = data ?? []
                } else {
                    self.errorMessage = message
                }
            }
        }
    }


}
