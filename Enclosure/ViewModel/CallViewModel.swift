//
//  CallViewModel.swift
//  Enclosure
//
//  Created by Ram Lohar on 30/04/25.
//

import Foundation

private enum CallContactCacheReason: CustomStringConvertible {
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

class CallViewModel: ObservableObject {
    @Published var contactList: [CallingContactModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasCachedContacts = false
    
    private let cacheManager = CallCacheManager.shared
    private let networkMonitor = NetworkMonitor.shared
    
    func fetchContactList(uid: String) {
        print("📞 [CallViewModel] fetchContactList called with uid: \(uid)")
        isLoading = true
        errorMessage = nil
        
        loadCachedContacts(reason: .prefetch, shouldStopLoading: false)
        
        guard networkMonitor.isConnected else {
            print("📞 [CallViewModel] No internet connection, loading cached contacts")
            loadCachedContacts(reason: .offline)
            return
        }
        
        ApiService.get_calling_contact_list(uid: uid) { success, message, data in
            DispatchQueue.main.async {
                print("📞 [CallViewModel] API callback received - success: \(success), message: '\(message)', data count: \(data?.count ?? 0)")
                self.isLoading = false
                
                if success, let contactData = data {
                    self.contactList = contactData
                    self.hasCachedContacts = !contactData.isEmpty
                    self.errorMessage = nil
                    self.cacheManager.cacheContacts(contactData)
                    print("📞 [CallViewModel] SUCCESS - contactList count: \(contactData.count)")
                } else {
                    self.errorMessage = message.isEmpty ? nil : message
                    print("📞 [CallViewModel] ERROR - errorMessage: '\(self.errorMessage ?? "nil")', contactList count: \(self.contactList.count)")
                    
                    if self.contactList.isEmpty {
                        self.loadCachedContacts(reason: .error(message))
                    }
                }
            }
        }
    }
    
    private func loadCachedContacts(reason: CallContactCacheReason, shouldStopLoading: Bool = true) {
        cacheManager.fetchContacts { [weak self] cachedContacts in
            guard let self = self else { return }
            self.contactList = cachedContacts
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
            
            print("📞 [CallViewModel] Loaded \(cachedContacts.count) cached contacts for reason: \(reason)")
        }
    }
}

