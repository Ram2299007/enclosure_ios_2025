//
//  ShareExternalDataContactScreen.swift
//  Enclosure
//
//  Created by Ram Lohar on 30/04/25.
//

import SwiftUI

struct ShareExternalDataContactScreen: View {
    let sharedContent: SharedContent
    let caption: String
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @StateObject private var viewModel = ChatViewModel()
    @State private var selectedContactIds: Set<String> = []
    @State private var isLoading: Bool = true
    @State private var searchText: String = ""
    @State private var showNetworkLoader: Bool = false
    @FocusState private var isSearchFocused: Bool
    
    private var filteredContacts: [UserActiveContactModel] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return viewModel.chatList
        }
        
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return viewModel.chatList.filter { contact in
            contact.fullName.lowercased().contains(trimmed) ||
            contact.mobileNo.contains(trimmed)
        }
    }
    
    // Selected contacts for display (matching Android forwardnameAdapter)
    private var selectedContacts: [UserActiveContactModel] {
        viewModel.chatList.filter { selectedContactIds.contains($0.uid) }
    }
    
    var body: some View {
        ZStack {
            Color("BackgroundColor")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Search section (matching Android searchlyt LinearLayout)
                searchSection
                
                // Network loader (matching Android networkLoader LinearProgressIndicator)
                if showNetworkLoader {
                    ProgressView()
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 4)
                        .padding(.top, 5)
                }
                
                // Contacts list (matching Android recyclerview RecyclerView)
                contactsList
                
                // Bottom selected contacts and share button (matching Android dx LinearLayout)
                if !selectedContactIds.isEmpty {
                    bottomShareSection
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadContacts()
        }
    }
    
    // MARK: - Search Section
    private var searchSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Search container (matching Android searchLytNew LinearLayout)
                HStack(spacing: 13) {
                    // Blue vertical bar (matching Android viewnewnn View)
                    Rectangle()
                        .fill(Color("blue"))
                        .frame(width: 1, height: 19.24)
                        .padding(.leading, 23)
                    
                    // Search field (matching Android searchview AutoCompleteTextView)
                    TextField("Search Name", text: $searchText)
                        .font(.custom("Inter18pt-Regular", size: 15))
                        .fontWeight(.medium)
                        .foregroundColor(Color("TextColor"))
                        .accentColor(Color("TextColor"))
                        .focused($isSearchFocused)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Search icon (matching Android searchIcon ImageView)
                Image("search")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .padding(.trailing, 10)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
        }
    }
    
    // MARK: - Contacts List
    private var contactsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 50)
                } else if filteredContacts.isEmpty {
                    Text("No contacts found")
                        .font(.custom("Inter18pt-Regular", size: 16))
                        .foregroundColor(Color("gray3"))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 50)
                } else {
                    ForEach(filteredContacts) { contact in
                        ShareContactRowView(
                            contact: contact,
                            isSelected: selectedContactIds.contains(contact.uid),
                            onTap: {
                                toggleSelection(for: contact)
                            }
                        )
                    }
                }
            }
            .padding(.top, 15)
        }
    }
    
    // MARK: - Bottom Share Section
    private var bottomShareSection: some View {
        HStack(spacing: 5) {
            // Selected contacts horizontal list (matching Android namerecyclerview RecyclerView)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(selectedContacts.prefix(5)) { contact in
                        // Selected contact chip (matching Android forwardnameAdapter design)
                        HStack(spacing: 4) {
                            AsyncImage(url: URL(string: contact.photo)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Image("inviteimg")
                                    .resizable()
                                    .scaledToFill()
                            }
                            .frame(width: 30, height: 30)
                            .clipShape(Circle())
                            
                            Text(getContactInitials(contact))
                                .font(.custom("Inter18pt-Regular", size: 12))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color("blue"))
                        )
                    }
                    
                    if selectedContacts.count > 5 {
                        Text("+\(selectedContacts.count - 5)")
                            .font(.custom("Inter18pt-Regular", size: 12))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color("blue"))
                            )
                    }
                }
                .padding(.leading, 5)
            }
            .frame(height: 40)
            
            // Share button (matching Android forward LinearLayout)
            Button(action: {
                handleShare()
            }) {
                Text("Share")
                    .font(.custom("Inter18pt-Regular", size: 16))
                    .fontWeight(.bold)
                    .foregroundColor(Color("whitetogray"))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color("dxForward"))
                    )
            }
            .padding(.trailing, 10)
        }
        .frame(height: 60)
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(Color("dxForward"))
        )
    }
    
    // MARK: - Helper Functions
    private func loadContacts() {
        isLoading = true
        showNetworkLoader = true
        
        viewModel.fetchChatList(uid: Constant.SenderIdMy)
        
        // Check loading state after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isLoading = false
            showNetworkLoader = false
        }
        
        // Also observe when chatList is populated
        if !viewModel.chatList.isEmpty {
            isLoading = false
            showNetworkLoader = false
        }
    }
    
    private func toggleSelection(for contact: UserActiveContactModel) {
        if selectedContactIds.contains(contact.uid) {
            selectedContactIds.remove(contact.uid)
        } else {
            selectedContactIds.insert(contact.uid)
        }
    }
    
    private func handleShare() {
        guard !selectedContactIds.isEmpty else { return }
        
        let selectedContacts = viewModel.chatList.filter { selectedContactIds.contains($0.uid) }
        
        // TODO: Implement sharing logic - send sharedContent to selected contacts
        // This should call the appropriate API/service to send the shared content
        print("📤 Sharing to \(selectedContacts.count) contacts")
        print("📤 Shared content type: \(sharedContent.type)")
        print("📤 Caption: \(caption)")
        
        // Dismiss after sharing
        dismiss()
    }
    
    private func getContactInitials(_ contact: UserActiveContactModel) -> String {
        let name = contact.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return "?" }
        
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            let first = String(components[0].prefix(1))
            let last = String(components[components.count - 1].prefix(1))
            return (first + last).uppercased()
        }
        return String(name.prefix(1)).uppercased()
    }
}

// MARK: - Share Contact Row View (matching Android shareContactAdapter design)
struct ShareContactRowView: View {
    let contact: UserActiveContactModel
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            onTap()
        }) {
            HStack(spacing: 20) {
                // Profile image (matching Android contact image: 50dp x 50dp)
                AsyncImage(url: URL(string: contact.photo)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image("inviteimg")
                        .resizable()
                        .scaledToFill()
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                .padding(.leading, 16)
                
                // Name (matching Android contact name text)
                Text(contact.fullName)
                    .font(.custom("Inter18pt-Medium", size: 16))
                    .foregroundColor(Color("TextColor"))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                // Checkbox (matching Android checkbox design)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? Color("blue") : Color("gray3"))
                    .font(.system(size: 24))
                    .padding(.trailing, 16)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
