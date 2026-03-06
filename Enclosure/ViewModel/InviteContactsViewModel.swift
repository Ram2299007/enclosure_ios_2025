//
//  InviteContactsViewModel.swift
//  Enclosure
//
//  Created by ChatGPT on 19/11/25.
//

import Foundation
import SwiftUI

final class InviteContactsViewModel: ObservableObject {
    @Published var contactList: [InviteContactModel] = []
    @Published var isLoading = false
    @Published var isPaginating = false
    @Published var errorMessage: String?
    @Published var hasCachedContacts = false
    @Published var isSearching = false
    @Published var isSyncingContacts = false
    @Published var toastMessage: String?
    
    private let cacheManager = CallCacheManager.shared
    private let networkMonitor = NetworkMonitor.shared
    private let contactSyncManager = ContactSyncManager.shared
    
    private var currentPage: Int = 1
    private var hasMorePages = true
    private var requestedUID: String?
    private var activeSearchKeyword: String?
    private var currentSearchToken: UUID?
    
    func loadContacts(uid: String, forceRefresh: Bool = false) {
        if !forceRefresh && activeSearchKeyword == nil && requestedUID == uid && (!contactList.isEmpty || isLoading) {
            return
        }
        
        requestedUID = uid
        currentPage = 1
        hasMorePages = true
        errorMessage = nil
        isLoading = true
        activeSearchKeyword = nil
        currentSearchToken = nil
        
        cacheManager.fetchInviteContacts { [weak self] cachedContacts in
            guard let self = self else { return }
            if !cachedContacts.isEmpty {
                self.contactList = cachedContacts
                self.hasCachedContacts = true
            }
        }
        
        guard networkMonitor.isConnected else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = self.contactList.isEmpty
                    ? "You are offline. No cached contacts available."
                    : nil
            }
            return
        }
        
        fetchContacts(page: 1, append: false)
    }
    
    func loadMoreIfNeeded(currentContact contact: InviteContactModel) {
        guard let uid = requestedUID,
              hasMorePages,
              !isPaginating,
              activeSearchKeyword == nil,
              contactList.last?.uniqueKey == contact.uniqueKey
        else { return }
        
        isPaginating = true
        fetchContacts(page: currentPage + 1, append: true, uidOverride: uid)
    }
    
    func retry() {
        guard let uid = requestedUID else { return }
        if let keyword = activeSearchKeyword, !keyword.isEmpty {
            searchContacts(keyword: keyword)
        } else {
        loadContacts(uid: uid, forceRefresh: true)
        }
    }
    
    private func fetchContacts(page: Int, append: Bool, uidOverride: String? = nil) {
        guard let uid = uidOverride ?? requestedUID else { return }
        
        ApiService.getUsersAllContact(uid: uid, page: page) { [weak self] success, message, data in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if append {
                    self.isPaginating = false
                } else {
                    self.isLoading = false
                }
                
                guard success, let data = data else {
                    if !append && self.contactList.isEmpty {
                        self.errorMessage = message.isEmpty ? "Unable to load contacts." : message
                    }
                    if !append && (message.lowercased().contains("no data") || message.lowercased().contains("data not found")) {
                        self.hasMorePages = false
                    }
                    return
                }
                
                let newItems = data
                self.hasMorePages = !newItems.isEmpty
                
                if append {
                    let existingKeys = Set(self.contactList.map { $0.uniqueKey })
                    let filtered = newItems.filter { !existingKeys.contains($0.uniqueKey) }
                    self.contactList.append(contentsOf: filtered)
                    self.currentPage = page
                } else {
                    self.contactList = newItems
                    self.currentPage = 1
                }
                
                self.hasCachedContacts = !self.contactList.isEmpty
                self.errorMessage = (self.contactList.isEmpty ? message : nil)
                self.cacheManager.cacheInviteContacts(self.contactList)
            }
        }
    }
    
    func searchContacts(keyword: String) {
        guard let uid = requestedUID else { return }
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            resetSearch()
            return
        }
        
        let token = UUID()
        activeSearchKeyword = trimmed
        currentSearchToken = token
        isSearching = true
        errorMessage = nil
        
        ApiService.searchInviteContacts(uid: uid, keyword: trimmed) { [weak self] success, message, data in
            DispatchQueue.main.async {
                guard let self = self, self.currentSearchToken == token else { return }
                self.isSearching = false
                self.isLoading = false
                
                guard success, let data = data else {
                    let fallback = message.isEmpty ? "Unable to search contacts." : message
                    self.errorMessage = fallback
                    self.toastMessage = fallback
                    return
                }
                
                self.contactList = data
                self.hasMorePages = false
                self.errorMessage = data.isEmpty ? "No contacts found" : nil
            }
        }
    }
    
    func resetSearch() {
        guard activeSearchKeyword != nil else { return }
        activeSearchKeyword = nil
        currentSearchToken = nil
        isSearching = false
        if let uid = requestedUID {
            loadContacts(uid: uid, forceRefresh: true)
        }
    }
    
    func syncContacts() {
        guard !isSyncingContacts else { return }
        isSyncingContacts = true
        toastMessage = nil
        
        contactSyncManager.syncContacts { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isSyncingContacts = false
                
                switch result {
                case .success:
                    self.toastMessage = "Contacts synced successfully."
                    if let uid = self.requestedUID {
                        self.loadContacts(uid: uid, forceRefresh: true)
                    }
                case .failure(let error):
                    self.toastMessage = error.localizedDescription
                }
            }
        }
    }
}


