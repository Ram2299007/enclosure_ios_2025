//
//  groupMessageView.swift
//  Enclosure
//
//  Created by Ram Lohar on 30/04/25.
//

import SwiftUI

struct groupMessageView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var dragOffset: CGSize = .zero
    @State private var isStretchedUp = false
    @State private var isBackHeaderVisible = false
    @Binding var isMainContentVisible: Bool
    @Binding var isTopHeaderVisible: Bool
    @State private var isPressed = false
    @State private var isSearchVisible = false
    @State private var searchText = ""
    @FocusState private var isSearchFieldFocused: Bool
    @StateObject private var viewModel = GroupMessageViewModel()
    @State private var hasLoadedGroups = false
    @State private var isNewGroupPresented = false
    @State private var isBackActionInProgress = false
    @State private var lastBackPressTime: Date = Date.distantPast
    @State private var isBackButtonEnabled = true
    @State private var mainvectorTintColor: Color = Color(hex: "#01253B") // Dynamic background tint color (darker theme color)
    
    // Long press dialog state - use @Binding to connect to parent
    @Binding var selectedGroupForDialog: GroupModel?
    @Binding var groupDialogPosition: CGPoint
    @Binding var showGroupDialog: Bool
    
    // Navigation state
    @State private var selectedGroupForNavigation: GroupModel?
    @State private var navigateToGroupChatting: Bool = false
    
    // Computed property for background tint: appThemeColor in light mode, darker tint in dark mode
    private var backgroundTintColor: Color {
        if colorScheme == .light {
            return Color("appThemeColor") // Use appThemeColor in light mode
        } else {
            return mainvectorTintColor // Use darker tint in dark mode
        }
    }
    
    private var filteredGroups: [GroupModel] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return viewModel.groups }
        return viewModel.groups.filter { group in
            group.name.lowercased().contains(trimmed.lowercased()) ||
            group.lastMessage.lowercased().contains(trimmed.lowercased())
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    
                    infoSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                    
                    searchToggleSection
                        .padding(.horizontal, 20)
                    
                    labelSection
                        .padding(.top, 15)
                    
                    listContainer
                }
                .padding(.top, 15)
                
                FloatingActionButton {
                    isNewGroupPresented = true
                }
                .padding(.trailing, 20)
                .padding(.bottom, 0)
                .ignoresSafeArea(edges: .bottom)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear.contentShape(Rectangle()))
            .gesture(
                // Only apply drag gesture when not stretched up to avoid interfering with scrolling
                !isStretchedUp ? DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        if value.translation.height < -50 {
                            withAnimation(.easeInOut(duration: 0.45)) {
                                isStretchedUp = true
                                isMainContentVisible = false
                                isBackHeaderVisible = true
                                isTopHeaderVisible = true
                            }
                        } else if value.translation.height > 50 {
                            // For drag gesture, check if back action is not in progress
                            guard !isBackActionInProgress && isBackButtonEnabled else { return }
                            isBackActionInProgress = true
                            isBackButtonEnabled = false
                            handleSwipeDown()
                        }
                        dragOffset = .zero
                    } : nil
            )
            .animation(.spring(), value: dragOffset)
            .background(
                Group {
                    NavigationLink(
                        destination: NewGroupView(isPresented: $isNewGroupPresented),
                        isActive: $isNewGroupPresented
                    ) {
                        EmptyView()
                    }
                    .hidden()
                    
                    NavigationLink(
                        destination: Group {
                            if let selectedGroup = selectedGroupForNavigation {
                                GroupChattingScreen(group: selectedGroup)
                            } else {
                                EmptyView()
                            }
                        },
                        isActive: $navigateToGroupChatting
                    ) {
                        EmptyView()
                    }
                    .hidden()
                }
            )
            .onAppear {
                isTopHeaderVisible = false
                // Reset back button state when view appears
                isBackHeaderVisible = false
                isBackActionInProgress = false
                isPressed = false
                isBackButtonEnabled = true
                lastBackPressTime = Date.distantPast
                mainvectorTintColor = getMainvectorTintColor(for: Constant.themeColor) // Initialize tint color
                
                if !hasLoadedGroups {
                    hasLoadedGroups = true
                    viewModel.fetchGroups(uid: Constant.SenderIdMy)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ThemeColorUpdated"))) { _ in
                mainvectorTintColor = getMainvectorTintColor(for: Constant.themeColor) // Update tint color when theme changes
            }
            .onChange(of: isNewGroupPresented) { newValue in
                // When returning from NewGroupView, reset all back button states
                if !newValue {
                    // Disable button immediately to prevent any presses during state transition
                    isBackButtonEnabled = false
                    
                    // Reset immediately and synchronously
                    isBackHeaderVisible = false
                    isBackActionInProgress = false
                    isPressed = false
                    isStretchedUp = false
                    isMainContentVisible = true
                    isTopHeaderVisible = false
                    // Reset the debounce timer - set to past to allow immediate press
                    lastBackPressTime = Date.distantPast
                    
                    // Re-enable button after a delay to ensure NavigationLink state is settled
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if !isNewGroupPresented {
                            self.isBackActionInProgress = false
                            self.isPressed = false
                            self.lastBackPressTime = Date.distantPast
                            self.isBackButtonEnabled = true
                        }
                    }
                }
            }
        }
    }
    
    private var header: some View {
           Group {
               if isBackHeaderVisible {
                   HStack(spacing: 12) {
                       backArrowButton()
                           .frame(width: 40, height: 40)
                       
                   }
                   .padding(.horizontal, 20)
                   .padding(.top, 10)
                   .padding(.bottom, 24)
           }
       }
   }
    
    private var listContainer: some View {
        GeometryReader { geometry in
            Group {
                if viewModel.isLoading && !viewModel.hasCachedGroups {
                    centeredContent(loadingView)
                } else if let errorMessage = viewModel.errorMessage, filteredGroups.isEmpty {
                    centeredContent(errorStateView(message: errorMessage))
                } else if filteredGroups.isEmpty {
                    centeredContent(emptyStateView)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredGroups) { group in
                                GroupRowView(
                                    group: group,
                                    onTap: {
                                        selectedGroupForNavigation = group
                                        navigateToGroupChatting = true
                                    },
                                    onLongPress: { group, position in
                                        selectedGroupForDialog = group
                                        groupDialogPosition = position
                                        showGroupDialog = true
                                    }
                                )
                            }
                        }
                        .padding(.top, 5)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
    }
    
    private var infoSection: some View {
        VStack(alignment: .center, spacing: 12) {
            Text("Create Your Group.\nMessage send will be received individually.")
                .font(.custom("Inter18pt-Medium", size: 13))
                .foregroundColor(Color("TextColor"))
                .lineSpacing(6)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }
    
    private var searchToggleSection: some View {
        HStack(alignment: .center, spacing: 12) {
            if isSearchVisible {
                HStack {
                    Rectangle()
                        .fill(Color(hex: Constant.themeColor)) // Use original theme color in both light and dark mode
                        .frame(width: 1, height: 19.24)
                        .padding(.leading, 13)
                    
                    TextField("Search Name or Number", text: $searchText)
                        .font(.custom("Inter18pt-Regular", size: 15))
                        .foregroundColor(Color("TextColor"))
                        .padding(.leading, 13)
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($isSearchFieldFocused)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
            
            Spacer()
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isSearchVisible.toggle()
                    if !isSearchVisible {
                        searchText = ""
                    }
                    if isSearchVisible {
                        isStretchedUp = true
                        isMainContentVisible = false
                        isBackHeaderVisible = true
                        isTopHeaderVisible = true
                    }
                }
                
                if isSearchVisible {
                    DispatchQueue.main.async {
                        isSearchFieldFocused = true
                    }
                } else {
                    hideKeyboard()
                }
            }) {
                Image("search")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .padding(10)
                    .clipShape(Circle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    private var labelSection: some View {
        HStack {
            VStack(spacing: 6) {
                Text("Groups")
                    .font(.custom("Inter18pt-SemiBold", size: 12))
                    .foregroundColor(.white)
                    .frame(width: 70, height: 30)
                    .background(Color("buttonColorTheme"))
                    .cornerRadius(20)
            }
            .padding(.leading, 20)
            
            Spacer()
        }
    }
    
    private func backArrowButton() -> some View {
        Button(action: handleBackArrowTap) {
            ZStack {
                if isPressed {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .scaleEffect(isPressed ? 1.2 : 1.0)
                        .animation(.easeOut(duration: 0.3), value: isPressed)
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
                        isPressed = false
                    }
                }
        )
        .allowsHitTesting(isBackButtonEnabled && !isBackActionInProgress && !isNewGroupPresented)
        .opacity(isBackButtonEnabled ? 1.0 : 0.5)
        .buttonStyle(.plain)
    }
    
    private var loadingView: some View {
        ZStack {
            Color("BackgroundColor")
            HorizontalProgressBar()
                .frame(width: 40, height: 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func errorStateView(message: String) -> some View {
        VStack(spacing: 8) {
            Text("Unable to load groups")
                .font(.custom("Inter18pt-SemiBold", size: 16))
                .foregroundColor(Color("TextColor"))
            Text(message)
                .font(.custom("Inter18pt-Medium", size: 14))
                .foregroundColor(Color("gray"))
            Button("Retry") {
                viewModel.fetchGroups(uid: Constant.SenderIdMy)
            }
            .font(.custom("Inter18pt-SemiBold", size: 14))
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Color("buttonColorTheme"))
            .foregroundColor(.white)
            .cornerRadius(20)
        }
        .padding(.vertical, 40)
    }
    
    private var emptyStateView: some View {
        VStack {
            // CardView equivalent with wrap_content size and center positioning
            VStack(spacing: 0) {
                // "Call On Enclosure" text (initially hidden like Android visibility="gone")
                // This can be shown conditionally if needed
                Text("Call On Enclosure")
                    .font(.custom("Inter18pt-Medium", size: 14))
                    .foregroundColor(Color(red: 100/255, green: 100/255, blue: 100/255))
                    .multilineTextAlignment(.center)
                    .hidden() // visibility="gone" equivalent
                
                // LinearLayout with marginTop="2dp" and horizontal orientation
                HStack(spacing: 0) {
                    Text("Press  ")
                        .font(.custom("Inter18pt-Medium", size: 14))
                        .foregroundColor(Color("black_white_cross"))
                    
                    Image("floating")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(Color("black_white_cross"))
                        .frame(width: 20, height: 20)
                    
                    Text(" to create")
                        .font(.custom("Inter18pt-Medium", size: 14))
                        .foregroundColor(Color("black_white_cross"))
                }
                .padding(.top, 2) // layout_marginTop="2dp"
            }
            .padding(12) // android:padding="12dp"
            .background(
                // Use a more contrasting background that works in both light and dark modes with elevation
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color("cardBackgroundColornew"))
                    .shadow(
                        color: Color.black.opacity(0.1), // Light shadow for elevation
                        radius: 8, // Android elevation equivalent
                        x: 0,
                        y: 4
                    )
            )
            .overlay(
                // Add a subtle border for better visibility in light mode
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // layout_centerInParent="true" equivalent
    }
    
    private func centeredContent<Content: View>(_ content: Content) -> some View {
        VStack {
            Spacer()
            content
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension groupMessageView {
    private func hideKeyboard() {
        isSearchFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func handleBackArrowTap() {
        // Check if button is enabled
        guard isBackButtonEnabled && !isBackActionInProgress && !isNewGroupPresented else {
            return
        }
        
        if isSearchVisible {
            isSearchVisible = false
            searchText = ""
            hideKeyboard()
        }

        let now = Date()
        
        // Simple debounce: prevent multiple presses within 1.5 seconds
        guard now.timeIntervalSince(lastBackPressTime) > 1.5 else {
            return
        }
        
        // Disable button immediately
        isBackButtonEnabled = false
        lastBackPressTime = now
        isBackActionInProgress = true
        
        withAnimation {
            isPressed = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.isPressed = false
            self.handleSwipeDown()
        }
    }
    
    private func handleSwipeDown() {
        // First animation: collapse the view and show main content
        withAnimation(.easeInOut(duration: 0.45)) {
            isPressed = true
            isStretchedUp = false
            isMainContentVisible = true
            isTopHeaderVisible = false
        }
        
        // Second animation: hide back header and reset pressed state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.45)) {
                self.isBackHeaderVisible = false
                self.isPressed = false
            }
            
            // Reset flags after animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                self.isBackActionInProgress = false
                self.isBackButtonEnabled = true
            }
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

struct GroupRowView: View {
    let group: GroupModel
    var onTap: (() -> Void)?
    var onLongPress: ((GroupModel, CGPoint) -> Void)?
    
    @State private var isPressed = false
    @State private var exactTouchLocation: CGPoint = .zero
    @State private var isLongPressing = false
    
    private var captionIcon: String? {
        switch group.messageType {
        case .text:
            return nil
        case .photo:
            return "photo"
        case .video:
            return "video"
        case .audio:
            return "mic"
        case .contact:
            return "person.crop.circle"
        case .file:
            return "doc"
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isPressed ? Color.gray.opacity(0.2) : Color.clear)
                
                HStack(alignment: .top, spacing: 16) {
                    GroupAvatarView(imageURL: group.iconURL)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .center) {
                            Text(group.name)
                                .font(.custom("Inter18pt-SemiBold", size: 16))
                                .foregroundColor(Color("TextColor"))
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(group.lastMessageTime)
                                .font(.custom("Inter18pt-Medium", size: 12))
                                .foregroundColor(Color("gray"))
                        }
                        
                        HStack(alignment: .center, spacing: 6) {
                            if let icon = captionIcon {
                                Image(systemName: icon)
                                    .font(.system(size: 12))
                                    .foregroundColor(Color("gray"))
                            }
                            
                            Text(group.lastMessage)
                                .font(.custom("Inter18pt-Medium", size: 13))
                                .foregroundColor(Color("gray"))
                                .lineLimit(1)
                            
                            Spacer()
                            
                            if group.unreadCount > 0 {
                                Text("\(group.unreadCount)")
                                    .font(.custom("Inter18pt-SemiBold", size: 12))
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 20)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color("buttonColorTheme"))
                                    )
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .contentShape(Rectangle())
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isPressed)
            .onTapGesture {
                // Only perform tap action if it wasn't a long press
                if !isLongPressing {
                    onTap?()
                }
                // Reset long press flag after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isLongPressing = false
                }
            }
            .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
                // Update press state for visual feedback
                isPressed = pressing
                if pressing {
                    // Get center point when press starts
                    let globalFrame = geometry.frame(in: .global)
                    exactTouchLocation = CGPoint(x: globalFrame.width / 2, y: globalFrame.height / 2)
                }
            }, perform: {
                // Mark that long press occurred to prevent tap action
                isLongPressing = true
                
                // Convert to global screen coordinates (using center as approximation)
                let globalFrame = geometry.frame(in: .global)
                let globalX = globalFrame.midX
                let globalY = globalFrame.midY
                print("👥 Long press on group at location - Global: (\(globalX), \(globalY))")
                if let onLongPress {
                    onLongPress(group, CGPoint(x: globalX, y: globalY))
                }
                
                // Reset long press flag after action
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isLongPressing = false
                }
            })
        }
        .frame(height: 82) // Fixed height for consistent layout
    }
}

struct FloatingActionButton: View {
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image("floating")
                .resizable()
                .scaledToFit()
                .frame(width: 25, height: 25)
                .padding(16)
                .background(
                    Circle()
                        .fill(Color(hex: Constant.themeColor))
                )
                .frame(width: 53, height: 53)
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct GroupAvatarView: View {
    let imageURL: String
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color("BorderColor"), lineWidth: 1)
                .frame(width: 54, height: 54)
                .overlay(
                    Circle()
                        .fill(Color("BackgroundColor"))
                        .frame(width: 54, height: 54)
                )
            
            CachedAsyncImage(url: URL(string: imageURL)) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            } placeholder: {
                placeholder
            }
            .frame(width: 50, height: 50)
        }
        .frame(width: 54, height: 54)
    }
    
    private var placeholder: some View {
        Image("inviteimg")
            .resizable()
            .scaledToFill()
            .frame(width: 50, height: 50)
            .clipShape(Circle())
    }
}

private enum GroupCacheReason: CustomStringConvertible, Equatable {
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

final class GroupMessageViewModel: ObservableObject {
    @Published var groups: [GroupModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasCachedGroups = false
    
    private let cacheManager = CallCacheManager.shared
    private let networkMonitor = NetworkMonitor.shared
    
    init() {
        // Listen for immediate delete notifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DeleteGroupImmediately"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let groupId = notification.userInfo?["groupId"] as? String {
                self?.removeFromList(groupId: groupId)
            }
        }
    }
    
    func fetchGroups(uid: String) {
        guard !uid.isEmpty else {
            errorMessage = "Missing user id"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        loadCachedGroups(reason: .prefetch, shouldStopLoading: false)
        
        guard networkMonitor.isConnected else {
            loadCachedGroups(reason: .offline)
            return
        }
        
        ApiService.get_group_list(uid: uid) { success, message, data in
            DispatchQueue.main.async {
                self.isLoading = false
                if success {
                    let mapped = data.map { GroupModel(item: $0) }
                    self.groups = mapped
                    self.hasCachedGroups = !mapped.isEmpty
                    self.errorMessage = nil
                    self.cacheManager.cacheGroupMessages(mapped)
                } else {
                    if !self.hasCachedGroups {
                        self.loadCachedGroups(reason: .error(message))
                    } else {
                        self.errorMessage = message.isEmpty ? "Something went wrong." : message
                    }
                }
            }
        }
    }
    
    private func loadCachedGroups(reason: GroupCacheReason, shouldStopLoading: Bool = true) {
        cacheManager.fetchGroupMessages { [weak self] cachedGroups in
            guard let self = self else { return }
            if cachedGroups.isEmpty && reason == .prefetch {
                if shouldStopLoading {
                    self.isLoading = false
                }
                return
            }
            
            self.groups = cachedGroups
            self.hasCachedGroups = !cachedGroups.isEmpty
            if shouldStopLoading {
                self.isLoading = false
            }
            
            switch reason {
            case .offline:
                self.errorMessage = cachedGroups.isEmpty ? "You are offline. No cached groups available." : nil
            case .prefetch:
                break
            case .error(let message):
                if cachedGroups.isEmpty {
                    self.errorMessage = message?.isEmpty == false ? message : "Unable to load groups."
                } else {
                    self.errorMessage = nil
                }
            }
            
            print("👥 [GroupMessageViewModel] Loaded \(cachedGroups.count) cached groups for reason: \(reason)")
        }
    }
    
    private func removeFromList(groupId: String) {
        // Remove group with matching groupId
        groups.removeAll { $0.groupId == groupId }
        
        // Update cache immediately
        cacheManager.cacheGroupMessages(groups)
        print("👥 [GroupMessageViewModel] Removed group with groupId \(groupId) from list and updated cache.")
    }
}

struct GroupModel: Identifiable, Codable {
    let id: UUID
    let groupId: String // API group_id for deletion
    let name: String
    let lastMessage: String
    let lastMessageTime: String
    let messageType: GroupMessageType
    let iconURL: String
    let unreadCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case groupId
        case name
        case lastMessage
        case lastMessageTime
        case messageType
        case iconURL
        case unreadCount
    }
    
    init(item: GroupListItem) {
        id = UUID()
        groupId = item.group_id
        name = item.group_name
        iconURL = item.group_icon
        messageType = GroupMessageType.fromAPI(item.data_type)
        let trimmedMessage = item.l_msg?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedMessage.isEmpty {
            lastMessage = messageType.placeholderText
        } else {
            lastMessage = trimmedMessage
        }
        
        if let sent = item.sent_time, !sent.isEmpty {
            lastMessageTime = sent
        } else if let sr = item.sr_nos {
            lastMessageTime = "ID \(sr)"
        } else {
            lastMessageTime = ""
        }
        unreadCount = 0
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        groupId = try container.decode(String.self, forKey: .groupId)
        name = try container.decode(String.self, forKey: .name)
        lastMessage = try container.decode(String.self, forKey: .lastMessage)
        lastMessageTime = try container.decode(String.self, forKey: .lastMessageTime)
        messageType = try container.decode(GroupMessageType.self, forKey: .messageType)
        iconURL = try container.decode(String.self, forKey: .iconURL)
        unreadCount = try container.decode(Int.self, forKey: .unreadCount)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(groupId, forKey: .groupId)
        try container.encode(name, forKey: .name)
        try container.encode(lastMessage, forKey: .lastMessage)
        try container.encode(lastMessageTime, forKey: .lastMessageTime)
        try container.encode(messageType, forKey: .messageType)
        try container.encode(iconURL, forKey: .iconURL)
        try container.encode(unreadCount, forKey: .unreadCount)
    }
}

enum GroupMessageType: String, Codable {
    case text
    case photo
    case video
    case audio
    case contact
    case file
    
    static func fromAPI(_ rawValue: String?) -> GroupMessageType {
        switch rawValue?.lowercased() {
        case "img":
            return .photo
        case "video":
            return .video
        case "voiceaudio":
            return .audio
        case "contact":
            return .contact
        case "text":
            return .text
        case "doc":
            return .file
        default:
            return .text
        }
    }
    
    var placeholderText: String {
        switch self {
        case .text:
            return "Message"
        case .photo:
            return "Photo"
        case .video:
            return "Video"
        case .audio:
            return "Audio"
        case .contact:
            return "Contact"
        case .file:
            return "File"
        }
    }
}

// MARK: - GroupLongPressDialog
// Matching Android grp_chat_group_row_blur_dialogue.xml
extension groupMessageView {
    struct GroupLongPressDialog: View {
        let group: GroupModel
        let position: CGPoint
        @Binding var isShowing: Bool
        let onDelete: () -> Void
        
        // Calculate adjusted offset X - full width (match_parent)
        private func adjustedOffsetX(in geometry: GeometryProxy) -> CGFloat {
            return 0 // Full width, no horizontal offset
        }
        
        // Calculate adjusted offset Y
        private func adjustedOffsetY(in geometry: GeometryProxy) -> CGFloat {
            let groupCardHeight: CGFloat = 82 // Group card with padding
            let deleteButtonHeight: CGFloat = 83 // Button (48) + margins (10+25)
            let dialogHeight = groupCardHeight + deleteButtonHeight // ~165
            let padding: CGFloat = 20
            let frame = geometry.frame(in: .global)
            let localY = position.y - frame.minY
            let centeredY = localY - (groupCardHeight / 2) // Center card at touch point
            let maxY = geometry.size.height - dialogHeight - padding
            return min(max(centeredY, padding), maxY)
        }
        
        private var captionIcon: String? {
            switch group.messageType {
            case .text:
                return nil
            case .photo:
                return "gallery"
            case .video:
                return "videopng"
            case .audio:
                return "mike"
            case .contact:
                return "contact"
            case .file:
                return "documentsvg"
            }
        }
        
        var body: some View {
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    // Blurred background overlay
                    Color.black.opacity(0.3)
                        .background(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .zIndex(0)
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.2)) {
                                isShowing = false
                            }
                        }
                    
                    // Dialog content
                    VStack(spacing: 0) {
                        // Group card view (matching grp_chat_group_row_blur_dialogue.xml)
                        VStack(spacing: 0) {
                            // LinearLayout id="contact1" with marginStart="16dp" marginTop="16dp"
                            HStack(alignment: .top, spacing: 0) {
                                // FrameLayout id="themeBorder" - group icon with border
                                // marginStart="1dp" marginEnd="16dp" padding="2dp"
                                ZStack {
                                    Circle()
                                        .stroke(Color(hex: Constant.themeColor), lineWidth: 2)
                                        .frame(width: 54, height: 54)
                                    
                                    CachedAsyncImage(url: URL(string: group.iconURL)) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 50, height: 50)
                                            .clipShape(Circle())
                                    } placeholder: {
                                        Image("inviteimg")
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 50, height: 50)
                                            .clipShape(Circle())
                                    }
                                    .frame(width: 50, height: 50)
                                }
                                .frame(width: 54, height: 54)
                                .padding(.leading, 1) // marginStart="1dp"
                                .padding(.trailing, 16) // marginEnd="16dp"
                                
                                // Vertical LinearLayout for name/caption
                                VStack(alignment: .leading, spacing: 0) {
                                    // First horizontal LinearLayout (Name and Time)
                                    HStack(spacing: 0) {
                                        // TextView id="grpName"
                                        // fontFamily="@font/inter_bold" textSize="16sp" lineHeight="18dp"
                                        Text(group.name.count > 20 ? String(group.name.prefix(20)) + "..." : group.name)
                                            .font(.custom("Inter18pt-SemiBold", size: 16))
                                            .foregroundColor(Color("TextColor"))
                                            .lineLimit(1)
                                            .frame(height: 18) // lineHeight="18dp"
                                        
                                        Spacer()
                                        
                                        // TextView id="time"
                                        // textSize="12sp" fontFamily="@font/inter_medium"
                                        Text(group.lastMessageTime)
                                            .font(.custom("Inter18pt-Medium", size: 12))
                                            .foregroundColor(Color("gray3"))
                                            .padding(.trailing, 8) // layout_marginEnd="8dp"
                                    }
                                    
                                    // Second horizontal LinearLayout (Caption and Notification)
                                    HStack(alignment: .center, spacing: 0) {
                                        // TextView id="caption"
                                        // layout_marginTop="2dp" drawablePadding="3dp" textSize="13sp"
                                        HStack(spacing: 3) {
                                            if let iconName = captionIcon {
                                                Image(iconName)
                                                    .renderingMode(.template)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 16, height: 16)
                                                    .foregroundColor(Color(red: 0x78/255.0, green: 0x78/255.0, blue: 0x7A/255.0))
                                            }
                                            
                                            Text(group.lastMessage.count > 25 ? String(group.lastMessage.prefix(25)) + "..." : group.lastMessage)
                                                .font(.custom("Inter18pt-Medium", size: 13))
                                                .foregroundColor(Color("gray3"))
                                                .lineLimit(1)
                                        }
                                        .padding(.top, 2) // layout_marginTop="2dp"
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        Spacer()
                                        
                                        // Notification badge
                                        if group.unreadCount > 0 {
                                            ZStack {
                                                Image("notiiconsvg")
                                                    .resizable()
                                                    .scaledToFit()
                                                
                                                Text("\(group.unreadCount)")
                                                    .foregroundColor(.white)
                                                    .font(.custom("Inter18pt-Regular", size: 12))
                                            }
                                            .frame(width: 32, height: 20)
                                            .padding(.top, 5) // layout_marginTop="5dp"
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.leading, 16) // contact1 marginStart="16dp"
                            .padding(.top, 16) // contact1 marginTop="16dp"
                            .padding(.bottom, 16) // Spacing below group card
                            .padding(.trailing, 16) // Right padding for symmetry
                        }
                        .background(Color("BackgroundColor"))
                        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5) // elevation
                        
                        // Delete button (deletecardview)
                        // layout_marginHorizontal="20dp" layout_marginTop="10dp" layout_marginBottom="25dp"
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                onDelete()
                            }
                        }) {
                            HStack(spacing: 0) {
                                Spacer()
                                
                                // ImageView - delete icon
                                // width="26.5dp" height="24dp" layout_marginEnd="2dp"
                                Image("baseline_delete_forever_24")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 26.5, height: 24)
                                    .foregroundColor(Color("gray3"))
                                    .padding(.trailing, 2)
                                
                                // TextView - "Delete" text
                                // textSize="16sp" fontFamily="@font/inter" textStyle="bold"
                                Text("Delete")
                                    .font(.custom("Inter18pt-Bold", size: 16))
                                    .foregroundColor(Color("TextColor"))
                                
                                Spacer()
                            }
                            .frame(height: 48) // layout_height="48dp"
                            .frame(maxWidth: .infinity)
                            .background(Color("dxForward"))
                            .cornerRadius(20) // cardCornerRadius="20dp"
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 20) // layout_marginHorizontal="20dp"
                        .padding(.top, 10) // layout_marginTop="10dp"
                        .padding(.bottom, 25) // layout_marginBottom="25dp"
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.clear)
                    .offset(x: adjustedOffsetX(in: geometry), y: adjustedOffsetY(in: geometry))
                    .zIndex(1)
                }
            }
        }
    }
}
