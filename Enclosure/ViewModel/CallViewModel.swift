//
//  CallViewModel.swift
//  Enclosure
//
//  Created by Ram Lohar on 30/04/25.
//

import Foundation

class CallViewModel: ObservableObject {
    @Published var contactList: [CallingContactModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchContactList(uid: String) {
        print("📞 [CallViewModel] fetchContactList called with uid: \(uid)")
        isLoading = true
        errorMessage = nil
        contactList = [] // Clear previous data
        
        ApiService.get_calling_contact_list(uid: uid) { success, message, data in
            DispatchQueue.main.async {
                print("📞 [CallViewModel] API callback received - success: \(success), message: '\(message)', data count: \(data?.count ?? 0)")
                print("📞 [CallViewModel] Data received: \(data?.map { $0.fullName } ?? [])")
                self.isLoading = false
                
                // Always set the contact list if data is available, regardless of success flag
                if let contactData = data {
                    self.contactList = contactData
                    print("📞 [CallViewModel] Set contactList - count: \(self.contactList.count)")
                    if self.contactList.isEmpty {
                        print("⚠️ [CallViewModel] WARNING - contactList is empty after setting data")
                    }
                } else {
                    self.contactList = []
                    print("⚠️ [CallViewModel] No data received - contactList set to empty")
                }
                
                if success {
                    self.errorMessage = nil
                    print("📞 [CallViewModel] SUCCESS - contactList count: \(self.contactList.count)")
                } else {
                    self.errorMessage = message.isEmpty ? nil : message
                    print("📞 [CallViewModel] ERROR - errorMessage: '\(self.errorMessage ?? "nil")', contactList count: \(self.contactList.count)")
                }
            }
        }
    }
}

