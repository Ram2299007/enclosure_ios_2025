import SwiftUI

struct InviteScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
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
    @State private var mainvectorTintColor: Color = Color(hex: "#01253B") // Dynamic background tint color (darker theme color)
    @State private var isMenuButtonPressed = false // Track menu button press state
    
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
        .overlay(alignment: .topTrailing) {
            if showMenu {
                RefreshContactsDialog(
                    isPresented: $showMenu,
                    onRefresh: {
                        viewModel.syncContacts()
                    }
                )
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
                            .fill(Color(hex: Constant.themeColor)) // Use original theme color in both light and dark mode
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
                
                // Menu button - matching MainActivityOld.swift design
                ZStack {
                    // Background circle for visual feedback
                    if isMenuButtonPressed {
                        Circle()
                            .fill(Color("circlebtnhover").opacity(0.3))
                            .frame(width: 44, height: 44)
                            .transition(.opacity)
                    }
                    
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
                }
                .frame(width: 44, height: 44) // Standard iOS touch target size
                .contentShape(Rectangle()) // Ensure entire area is tappable
                .onTapGesture {
                    // Add haptic feedback for better UX
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    
                    // Visual feedback
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isMenuButtonPressed = true
                    }
                    
                    // Smooth animation when opening menu
                    withAnimation(.easeInOut(duration: 0.2)) {
                    showMenu = true
                    }
                    
                    // Reset pressed state
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isMenuButtonPressed = false
                        }
                    }
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
                .fill(Color(hex: Constant.themeColor))
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

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct RefreshContactsDialog: View {
    @Binding var isPresented: Bool
    var onRefresh: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Semi-transparent background with ultra thin material blur to dismiss on tap outside
            Color.black.opacity(0.01)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPresented = false
                    }
                }
            
            // Refresh button positioned at top-right, matching Android design
            // Android: RelativeLayout padding="10dp", button margin="10dp", layout_alignParentEnd="true"
            // Button dimensions: 130dp width, 50dp height, 10dp corner radius
            // Android uses @drawable/menurect which uses @color/menuRect
            VStack {
                HStack {
                    Spacer()
                    
                    ZStack {
                        // Enhanced shadow layer for CardView effect (elevation 5dp equivalent)
                        // More visible shadow in light mode to match Android CardView
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                colorScheme == .light 
                                    ? Color.black.opacity(0.25) 
                                    : Color.black.opacity(0.15)
                            )
                            .frame(width: 130, height: 50)
                            .offset(x: 0, y: 4)
                            .blur(radius: colorScheme == .light ? 10 : 8)
                            .allowsHitTesting(false)
                        
                        // Additional subtle shadow for depth in light mode
                        if colorScheme == .light {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.black.opacity(0.1))
                                .frame(width: 130, height: 50)
                                .offset(x: 0, y: 2)
                                .blur(radius: 6)
                                .allowsHitTesting(false)
                        }
                        
                        // Button card - matches Android: 130dp width, 50dp height, 10dp corner radius
                        // Using menuRect color to match Android @drawable/menurect
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isPresented = false
                            }
                            // Small delay to allow dismiss animation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                onRefresh()
                            }
                        }) {
                            Text("Refresh")
                                .font(.custom("Inter18pt-SemiBold", size: 16))
                                .foregroundColor(Color("TextColor"))
                                .frame(width: 130, height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color("menuRect"))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.trailing, 10) // Android margin 10dp from right edge
                    .padding(.top, 65) // Position below header area
                }
                
                Spacer()
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(.easeInOut(duration: 0.2), value: isPresented)
    }
}
