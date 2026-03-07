import SwiftUI

struct InviteScreen: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var viewModel = InviteContactsViewModel()
    @ObservedObject private var networkMonitor = NetworkMonitor.shared

    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var searchWorkItem: DispatchWorkItem?
    @FocusState private var isSearchFieldFocused: Bool
    @State private var mainvectorTintColor: Color = Color(hex: "#01253B") // Dynamic background tint color (darker theme color)
    @State private var selectedChatContact: UserActiveContactModel?
    @State private var navigateToChattingScreen = false
    
    // Computed property for background tint: appThemeColor in light mode, darker tint in dark mode
    private var backgroundTintColor: Color {
        if colorScheme == .light {
            return Color("appThemeColor") // Use appThemeColor in light mode
        } else {
            return mainvectorTintColor // Use darker tint in dark mode
        }
    }
    
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
    
    // Helper function to hide keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    var body: some View {
        ZStack {
            Color("background_color")
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    hideKeyboard()
                }

            VStack(spacing: 0) {
                if !networkMonitor.isConnected {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .tint(Color("appThemeColor"))
                    .padding(.horizontal, 20)
                }

                content
            }
        }
        .navigationTitle(isSearchActive ? "" : "Contacts")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isSearchActive)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if isSearchActive {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSearchActive = false
                            searchText = ""
                            viewModel.resetSearch()
                            isSearchFieldFocused = false
                        }
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                ToolbarItem(placement: .principal) {
                    TextField("Search Name", text: $searchText)
                        .font(.custom("Inter18pt-Medium", size: 16))
                        .foregroundColor(Color("TextColor"))
                        .focused($isSearchFieldFocused)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
            } else {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isSearchActive = true
                    } label: {
                        Image("search")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        AndroidStylePermissionManager.shared.requestPermissionWithDialogFromTopVC(for: .contacts) { granted in
                            if granted {
                                viewModel.syncContacts()
                            }
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                } label: {
                    VStack(spacing: 3) {
                        Circle()
                            .fill(Color("menuPointColor"))
                            .frame(width: 4, height: 4)
                        Circle()
                            .fill(Color(hex: Constant.themeColor))
                            .frame(width: 4, height: 4)
                        Circle()
                            .fill(Color(red: 0x9E/255, green: 0xA6/255, blue: 0xB9/255))
                            .frame(width: 4, height: 4)
                    }
                    .frame(width: 24, height: 24)
                }
            }
        }
        .background(NavigationGestureEnabler())
        .navigationDestination(isPresented: $navigateToChattingScreen) {
            if let contact = selectedChatContact {
                ChattingScreen(contact: contact)
            } else {
                EmptyView()
            }
        }
        .onChange(of: navigateToChattingScreen) { isPresented in
            if !isPresented {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    selectedChatContact = nil
                }
            }
        }
        .onAppear {
            mainvectorTintColor = getMainvectorTintColor(for: Constant.themeColor) // Initialize tint color
            guard viewModel.contactList.isEmpty else { return }
            viewModel.loadContacts(uid: Constant.SenderIdMy)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ThemeColorUpdated"))) { _ in
            mainvectorTintColor = getMainvectorTintColor(for: Constant.themeColor) // Update tint color when theme changes
        }
        .onChange(of: isSearchActive) { active in
            if active {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isSearchFieldFocused = true
                }
            }
        }
        .onChange(of: searchText) { newValue in
            handleSearchChange(newValue)
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
                        .contentShape(Rectangle())
                        .onTapGesture {
                            openChat(contact: contact)
                        }
                }
                
                ForEach(inviteContacts, id: \.uniqueKey) { contact in
                    InviteContactCard(contact: contact) { sendInviteSMS(to: contact) }
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
    
    private func openChat(contact: InviteContactModel) {
        let activeContact = UserActiveContactModel(
            photo: contact.photo,
            fullName: contact.fullName,
            mobileNo: contact.mobileNo,
            caption: contact.caption,
            uid: contact.uid,
            sentTime: "",
            dataType: "",
            message: "",
            fToken: contact.fToken,
            notification: 0,
            msgLimit: 0,
            deviceType: contact.deviceType,
            messageId: "",
            createdAt: "",
            block: contact.block,
            iamblocked: contact.iamBlocked
        )
        selectedChatContact = activeContact
        navigateToChattingScreen = true
    }
    
    private func sendInviteSMS(to contact: InviteContactModel) {
        let message = """
        Inviting you to Download Enclosure !
        Your message will become more valuable here
        New messaging app -
        for billion people https://enclosureapp.com
        """
        
        var components = URLComponents()
        components.scheme = "sms"
        components.path = contact.displayNumber
        components.queryItems = [URLQueryItem(name: "body", value: message)]
        
        guard let url = components.url else {
            Constant.showToast(message: "Unable to open Messages.")
            return
        }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            Constant.showToast(message: "Messages is not available on this device.")
        }
    }
    
    private func getMainvectorTintColor(for themeColor: String) -> Color {
        // Use case-insensitive comparison to handle mixed case theme colors
        let colorKey = themeColor.lowercased()
        switch colorKey {
        case "#ff0080":
            return Color(hex: "#4D0026")
        case "#00a3e9":
            return Color(hex: "#01253B")
        case "#7adf2a":
            return Color(hex: "#25430D")
        case "#ec0001":
            return Color(hex: "#470000")
        case "#16f3ff":
            return Color(hex: "#05495D")
        case "#ff8a00":
            return Color(hex: "#663700")
        case "#7f7f7f":
            return Color(hex: "#2B3137")
        case "#d9b845":
            return Color(hex: "#413815")
        case "#346667":
            return Color(hex: "#1F3D3E")
        case "#9846d9":
            return Color(hex: "#2d1541")
        case "#a81010":
            return Color(hex: "#430706")
        default:
            return Color(hex: "#01253B")
        }
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
                Text(Constant.formatNameWithYou(uid: contact.uid, fullName: contact.isActiveUser ? contact.fullName : contact.contactName))
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
                Text(Constant.formatNameWithYou(uid: contact.uid, fullName: contact.isActiveUser ? contact.fullName : contact.contactName))
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
            VStack(spacing: 16) {
                // Loader - matching whatsTheCode.swift design
                HorizontalProgressBar()
                    .frame(width: 40, height: 2)

                // Loading Text - matching whatsTheCode.swift design
                Text(message)
                    .foregroundColor(Color("TextColor"))
                    .font(.custom("Inter18pt-Medium", size: 16))
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(width: 220, height: 140)
            .background(Color("cardBackgroundColornew").opacity(0.95))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 2, y: 2)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear.ignoresSafeArea()) // Ensures full-screen coverage
    }
}

private struct InviteShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

