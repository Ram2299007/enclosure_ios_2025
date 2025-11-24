//
//  groupMessageView.swift
//  Enclosure
//
//  Created by Ram Lohar on 30/04/25.
//

import SwiftUI

struct groupMessageView: View {
    @State private var dragOffset: CGSize = .zero
    @State private var isStretchedUp = false
    @State private var isBackHeaderVisible = false
    @Binding var isMainContentVisible: Bool
    @Binding var isTopHeaderVisible: Bool
    @State private var isPressed = false
    @State private var isSearchVisible = false
    @State private var searchText = ""
    @StateObject private var viewModel = GroupMessageViewModel()
    @State private var hasLoadedGroups = false
    @State private var isNewGroupPresented = false
    @State private var isBackActionInProgress = false
    @State private var lastBackPressTime: Date = Date.distantPast
    @State private var isBackButtonEnabled = true
    
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
                DragGesture()
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
                    }
            )
            .animation(.spring(), value: dragOffset)
            .background(
                NavigationLink(
                    destination: NewGroupView(isPresented: $isNewGroupPresented),
                    isActive: $isNewGroupPresented
                ) {
                    EmptyView()
                }
                .hidden()
            )
            .onAppear {
                isTopHeaderVisible = false
                // Reset back button state when view appears
                isBackHeaderVisible = false
                isBackActionInProgress = false
                isPressed = false
                isBackButtonEnabled = true
                lastBackPressTime = Date.distantPast
                
                if !hasLoadedGroups {
                    hasLoadedGroups = true
                    viewModel.fetchGroups(uid: Constant.SenderIdMy)
                }
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
                                GroupRowView(group: group)
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
                HStack(spacing: 12) {
                    Rectangle()
                        .fill(Color("blue"))
                        .frame(width: 1, height: 19.24)
                        .padding(.leading, 3)
                    
                    TextField("Search Name or Number", text: $searchText)
                        .font(.custom("Inter18pt-Regular", size: 15))
                        .foregroundColor(Color("TextColor"))
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 50)
                        .fill(Color("cardBackgroundColornew"))
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
            
            Spacer()
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isSearchVisible.toggle()
                    if !isSearchVisible {
                        searchText = ""
                    }
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
        VStack(spacing: 0) {
            Text("Call On Enclosure")
                .font(.custom("Inter18pt-Medium", size: 14))
                .foregroundColor(Color(red: 100/255, green: 100/255, blue: 100/255))
                .multilineTextAlignment(.center)
                .padding(.bottom, 2)
                .hidden()
            
            HStack(spacing: 4) {
                Text("Press")
                    .font(.custom("Inter18pt-Medium", size: 14))
                    .foregroundColor(Color("black_white_cross"))
                
                Image("floating")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(Color("black_white_cross"))
                    .frame(width: 20, height: 20)
                
                Text("to create")
                    .font(.custom("Inter18pt-Medium", size: 14))
                    .foregroundColor(Color("black_white_cross"))
            }
            .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color("cardBackgroundColornew"))
        )
        .padding(.horizontal, 40)
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
    private func handleBackArrowTap() {
        // Check if button is enabled
        guard isBackButtonEnabled && !isBackActionInProgress && !isNewGroupPresented else {
            return
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
}

struct GroupRowView: View {
    let group: GroupModel
    var onTap: (() -> Void)?
    
    @State private var isPressed = false
    
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
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.1)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeOut(duration: 0.1)) {
                    isPressed = false
                }
                onTap?()
            }
        }
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
                        .fill(Color(hex: "#00A3E9"))
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
}

struct GroupModel: Identifiable, Codable {
    let id: UUID
    let name: String
    let lastMessage: String
    let lastMessageTime: String
    let messageType: GroupMessageType
    let iconURL: String
    let unreadCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case lastMessage
        case lastMessageTime
        case messageType
        case iconURL
        case unreadCount
    }
    
    init(item: GroupListItem) {
        id = UUID()
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

