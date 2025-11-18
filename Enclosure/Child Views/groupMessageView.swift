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
    @State private var isPressed = false
    @State private var isSearchVisible = false
    @State private var searchText = ""
    @StateObject private var viewModel = GroupMessageViewModel()
    @State private var hasLoadedGroups = false
    
    private var filteredGroups: [GroupModel] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return viewModel.groups }
        return viewModel.groups.filter { group in
            group.name.lowercased().contains(trimmed.lowercased()) ||
            group.lastMessage.lowercased().contains(trimmed.lowercased())
        }
    }

    var body: some View {
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
                // Placeholder create group action
                print("Create group tapped")
            }
            .padding(.trailing, 20)
            .padding(.bottom, 50)
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
                        }
                    } else if value.translation.height > 50 {
                        handleSwipeDown()
                    }
                    dragOffset = .zero
                }
        )
        .animation(.spring(), value: dragOffset)
        .onAppear {
            if !hasLoadedGroups {
                hasLoadedGroups = true
                viewModel.fetchGroups(uid: Constant.SenderIdMy)
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
                   .padding(.bottom, 24)
               }
           }
       }
   
    
    private var listContainer: some View {
        GeometryReader { geometry in
            Group {
                if viewModel.isLoading && viewModel.groups.isEmpty {
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
                    .background(Color("cardBackgroundColornew"))
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
        Button(action: {
            handleBackArrowTap()
                }) {
                    ZStack {
                        if isPressed {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 40, height: 40)
                                .scaleEffect(isPressed ? 1.2 : 1.0)
                                .animation(.easeOut(duration: 0.1), value: isPressed)
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
        handleSwipeDown()
    }
    
    private func handleSwipeDown() {
        withAnimation(.easeInOut(duration: 0.45)) {
                                isPressed = true
                                isStretchedUp = false
                                isMainContentVisible = true
        }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.45)) {
                isBackHeaderVisible = false
                                        isPressed = false
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
                .frame(width: 20, height: 20)
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
            
            AsyncImage(url: URL(string: imageURL)) { phase in
                switch phase {
                case .empty:
                    placeholder
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                case .failure:
                    placeholder
                @unknown default:
                    placeholder
                }
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

final class GroupMessageViewModel: ObservableObject {
    @Published var groups: [GroupModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchGroups(uid: String) {
        guard !uid.isEmpty else {
            errorMessage = "Missing user id"
            return
        }
        
        isLoading = true
        errorMessage = nil
        ApiService.get_group_list(uid: uid) { success, message, data in
            DispatchQueue.main.async {
                self.isLoading = false
                if success {
                    self.groups = data.map { GroupModel(item: $0) }
                    if self.groups.isEmpty {
                        self.errorMessage = nil
                    }
                } else {
                    self.groups = []
                    self.errorMessage = message.isEmpty ? "Something went wrong." : message
                }
            }
        }
    }
}

struct GroupModel: Identifiable {
    let id = UUID()
    let name: String
    let lastMessage: String
    let lastMessageTime: String
    let messageType: GroupMessageType
    let iconURL: String
    let unreadCount: Int
    
    init(item: GroupListItem) {
        name = item.group_name
        iconURL = item.group_icon
        messageType = GroupMessageType(rawValue: item.data_type)
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
}

enum GroupMessageType {
    case text
    case photo
    case video
    case audio
    case contact
    case file
    
    init(rawValue: String?) {
        switch rawValue?.lowercased() {
        case "img":
            self = .photo
        case "video":
            self = .video
        case "voiceaudio":
            self = .audio
        case "contact":
            self = .contact
        case "text":
            self = .text
        case "doc":
            self = .file
        default:
            self = .text
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

