import SwiftUI

struct InviteScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = InviteContactsViewModel()
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    
    @State private var searchText = ""
    @State private var isSearchVisible = false
    @State private var showMenu = false
    @State private var isSharePresented = false
    @State private var shareItems: [Any] = []
    @State private var searchWorkItem: DispatchWorkItem?
    @FocusState private var isSearchFieldFocused: Bool
    @State private var isBackPressed = false
    
    private var uniqueContacts: [InviteContactModel] {
        var seen = Set<String>()
        return viewModel.contactList.filter { contact in
            let key = contact.uniqueKey
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }
    
    private var activeContacts: [InviteContactModel] {
        uniqueContacts.filter { $0.isActiveUser }
    }
    
    private var inviteContacts: [InviteContactModel] {
        uniqueContacts.filter { !$0.isActiveUser }
    }
    
    var body: some View {
        ZStack {
            Color("background_color")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 15)
                    .padding(.bottom, 12)
                
                if !networkMonitor.isConnected {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .tint(Color("appThemeColor"))
                    .padding(.horizontal, 20)
                }
                
                content
                    .padding(.top, 0)
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $isSharePresented) {
            ShareSheet(items: shareItems)
        }
        .confirmationDialog("", isPresented: $showMenu, titleVisibility: .hidden) {
            Button("Refresh contacts") {
                viewModel.syncContacts()
            }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            guard viewModel.contactList.isEmpty else { return }
            viewModel.loadContacts(uid: Constant.SenderIdMy)
        }
        .onChange(of: searchText) { newValue in
            handleSearchChange(newValue)
        }
        .onChange(of: isSearchVisible) { isVisible in
            if isVisible {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isSearchFieldFocused = true
                }
            } else {
                isSearchFieldFocused = false
                searchText = ""
                viewModel.resetSearch()
            }
        }
        .onChange(of: viewModel.toastMessage) { message in
            guard let message = message else { return }
            Constant.showToast(message: message)
            DispatchQueue.main.async {
                viewModel.toastMessage = nil
            }
        }
        .overlay(alignment: .center) {
            if viewModel.isSyncingContacts {
                SyncOverlay(message: "Your contacts are synchronizing...")
            }
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 12) {
            Button(action: handleBackTap) {
                ZStack {
                    if isBackPressed {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 40, height: 40)
                            .scaleEffect(isBackPressed ? 1.2 : 1.0)
                            .animation(.easeOut(duration: 0.3), value: isBackPressed)
                    }
                    
                Image("leftvector")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 25, height: 18)
                    .foregroundColor(Color("icontintGlobal"))
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { _ in
                        withAnimation {
                            isBackPressed = false
                        }
                    }
            )
                .buttonStyle(.plain)
            
                Text("Contacts")
                    .font(.custom("Inter18pt-SemiBold", size: 16))
                .foregroundColor(Color("TextColor"))
            
            Spacer()
        }
            
            HStack(spacing: 12) {
                Spacer()
                
                if isSearchVisible {
                    HStack(spacing: 5) {
                        Rectangle()
                            .fill(Color("blue"))
                            .frame(width: 1, height: 19.24)
                            .padding(.leading, 0)
            
                        TextField("Search Name", text: $searchText)
                .font(.custom("Inter18pt-Regular", size: 15))
                .foregroundColor(Color("TextColor"))
                .disableAutocorrection(true)
                .textInputAutocapitalization(.never)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .focused($isSearchFieldFocused)
            
            if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                viewModel.resetSearch()
                            } label: {
                    Image(systemName: "xmark.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                        .foregroundColor(Color("gray"))
                }
                            .buttonStyle(.plain)
            }
        }
                    .frame(height: 40)
                    .padding(.trailing, 12)
                    .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(Color("cardBackgroundColornew"))
        )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                
                HeaderIconButton {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSearchVisible.toggle()
                    }
                } label: {
                    if let searchImage = UIImage(named: "search") {
                        Image(uiImage: searchImage)
                            .resizable()
                            .renderingMode(.template)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .resizable()
                    }
                }
                
                HeaderIconButton {
                    showMenu = true
                } label: {
                    MenuDotsIcon()
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isSearchVisible)
        }
    }
    
    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && !viewModel.hasCachedContacts {
            LoadingView(title: "Loading contacts…")
                .padding(.horizontal, 20)
        } else if let error = viewModel.errorMessage, viewModel.contactList.isEmpty {
            ErrorStateView(
                title: "Unable to load contacts",
                message: error,
                actionTitle: "Retry",
                action: { viewModel.retry() }
            )
            .padding(.horizontal, 20)
        } else if viewModel.contactList.isEmpty {
            EmptyStateView(
                title: "No contacts yet",
                message: "Sync your contacts to see who is already on Enclosure."
            )
            .padding(.horizontal, 20)
        } else {
            List {
                if viewModel.isSearching {
                    HorizontalProgressBar()
                        .frame(width: 40, height: 2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                
                ForEach(activeContacts, id: \.uniqueKey) { contact in
                    ActiveContactRow(contact: contact)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .onAppear { viewModel.loadMoreIfNeeded(currentContact: contact) }
                }
                
                ForEach(inviteContacts, id: \.uniqueKey) { contact in
                    InviteContactCard(contact: contact) { share(contact: contact) }
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .onAppear { viewModel.loadMoreIfNeeded(currentContact: contact) }
                }
                
                if viewModel.isPaginating {
                    HorizontalProgressBar()
                        .frame(width: 40, height: 2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
    
    private func handleSearchChange(_ text: String) {
        searchWorkItem?.cancel()
        
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            viewModel.resetSearch()
            return
        }
        
        let workItem = DispatchWorkItem {
            viewModel.searchContacts(keyword: trimmed)
        }
        searchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: workItem)
    }
    
    private func handleBackTap() {
        isSearchFieldFocused = false
        withAnimation {
            isBackPressed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            dismiss()
            isBackPressed = false
        }
    }
    
    private func share(contact: InviteContactModel) {
        let inviteURL = "https://enclosureapp.com/invite"
        let message = """
        Hey \(contact.displayName.isEmpty ? "there" : contact.displayName)! 👋
        I'm using Enclosure to stay connected securely. Download the app and join me: \(inviteURL)
        """
        shareItems = [message]
        isSharePresented = true
    }
}

private struct HeaderIconButton<Content: View>: View {
    var action: () -> Void
    @ViewBuilder var label: Content
    
    var body: some View {
        Button(action: action) {
            label
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundColor(Color("TextColor"))
                .padding(10)
                .background(
                    Circle()
                        .fill(Color("cardBackgroundColornew"))
                )
        }
        .buttonStyle(.plain)
    }
}

private struct MenuDotsIcon: View {
    var body: some View {
        VStack(spacing: 3) {
            Circle()
                .fill(Color(hex: "#011224"))
                .frame(width: 4, height: 4)
            Circle()
                .fill(Color(hex: "#00A3E9"))
                .frame(width: 4, height: 4)
            Circle()
                .fill(Color(hex: "#9EA6B9"))
                .frame(width: 4, height: 4)
        }
        .frame(width: 20, height: 20)
    }
}

private struct LoadingView: View {
    let title: String
    
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color("appThemeColor")))
            Text(title)
                .font(.custom("Inter18pt-Medium", size: 14))
                .foregroundColor(Color("gray"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ErrorStateView: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.custom("Inter18pt-SemiBold", size: 16))
                .foregroundColor(Color("TextColor"))
            
            Text(message)
                .font(.custom("Inter18pt-Medium", size: 13))
                .foregroundColor(Color("gray"))
                .multilineTextAlignment(.center)
            
            Button(action: action) {
                Text(actionTitle)
                    .font(.custom("Inter18pt-SemiBold", size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color("buttonColorTheme"))
                    .cornerRadius(20)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct EmptyStateView: View {
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.custom("Inter18pt-SemiBold", size: 16))
                .foregroundColor(Color("TextColor"))
            
            Text(message)
                .font(.custom("Inter18pt-Medium", size: 13))
                .foregroundColor(Color("gray"))
                .multilineTextAlignment(.center)
    }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ActiveContactRow: View {
    let contact: InviteContactModel
    
    var body: some View {
        HStack(spacing: 18) {
            CallingContactCardView(image: contact.photo, themeColor: contact.resolvedThemeColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.displayName)
                    .font(.custom("Inter18pt-SemiBold", size: 16))
                    .foregroundColor(Color("TextColor"))
                    .lineLimit(1)
                Text(contact.caption.isEmpty ? contact.displayNumber : contact.caption)
                    .font(.custom("Inter18pt-Medium", size: 13))
                    .foregroundColor(Color("gray"))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 0)
        .background(Color.clear)
    }
}

private struct InviteContactCard: View {
    let contact: InviteContactModel
    var onInvite: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            CallingContactCardView(image: nil, themeColor: contact.resolvedThemeColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.displayName)
                    .font(.custom("Inter18pt-SemiBold", size: 15))
                    .foregroundColor(Color("TextColor"))
                    .lineLimit(1)
                Text(contact.displayNumber)
                    .font(.custom("Inter18pt-Medium", size: 13))
                    .foregroundColor(Color("gray"))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            Text("I n v i t e")
                .font(.custom("Inter18pt-SemiBold", size: 16))
                .foregroundColor(Color("gray"))
        }
        .padding(.vertical, 6)
        .background(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onInvite()
        }
    }
}

private struct SyncOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                Text(message)
                    .font(.custom("Inter18pt-Medium", size: 14))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .background(Color("TextColor").opacity(0.9))
            .cornerRadius(16)
            .padding(.horizontal, 40)
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
