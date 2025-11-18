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
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    
                    infoSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                    
                    searchToggleSection
                        .padding(.horizontal, 20)
                    
                    labelSection
                        .padding(.top, 15)
                    
                    LazyVStack(spacing: 0) {
                        ForEach(filteredGroups) { group in
                            GroupRowView(group: group)
                        }
                    }
                    .padding(.top, 5)
                }
                .padding(.top, 15)
            }
            
            Button(action: {
                // Placeholder create group action
                print("Create group tapped")
            }) {
                Image("plus")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .padding(18)
                    .background(Color("buttonColorTheme"))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            .padding(.trailing, 24)
            .padding(.bottom, 24)
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
    }
    
    private var header: some View {
        Group {
            if isBackHeaderVisible {
                HStack(spacing: 12) {
                    backArrowButton()
                        .frame(width: 40, height: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Group message")
                            .font(.custom("Inter18pt-SemiBold", size: 20))
                            .foregroundColor(Color("TextColor"))
                        Text("See your latest group conversations")
                            .font(.custom("Inter18pt-Medium", size: 14))
                            .foregroundColor(Color("gray"))
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            } else {
                Spacer().frame(height: 8)
            }
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
        VStack(spacing: 12) {
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
            
            Divider()
                .background(Color("cardBackgroundColornew"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
    @Published var groups: [GroupModel] = GroupModel.sampleData
}

struct GroupModel: Identifiable {
    let id = UUID()
    let name: String
    let lastMessage: String
    let lastMessageTime: String
    let messageType: GroupMessageType
    let iconURL: String
    let unreadCount: Int
    
    static let sampleData: [GroupModel] = [
        GroupModel(name: "Marketing Crew", lastMessage: "Campaign assets shared!", lastMessageTime: "11:00 AM", messageType: .photo, iconURL: "https://picsum.photos/id/1025/80/80", unreadCount: 2),
        GroupModel(name: "Product Launch", lastMessage: "Latest specs approved", lastMessageTime: "09:42 AM", messageType: .text, iconURL: "https://picsum.photos/id/1027/80/80", unreadCount: 0),
        GroupModel(name: "Design Standup", lastMessage: "Shared a new prototype", lastMessageTime: "Yesterday", messageType: .file, iconURL: "https://picsum.photos/id/1021/80/80", unreadCount: 4),
        GroupModel(name: "Sales All Hands", lastMessage: "Recording is now available", lastMessageTime: "Mon", messageType: .video, iconURL: "https://picsum.photos/id/1022/80/80", unreadCount: 0)
    ]
}

enum GroupMessageType {
    case text
    case photo
    case video
    case audio
    case contact
    case file
}

