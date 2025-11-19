import Foundation
import SwiftUI

struct messageLmtView: View {
    @State private var isPressed = false
    @State private var dragOffset: CGSize = .zero
    @State private var isStretchedUp = false
    @State private var messageLmtView = false
    @Binding var isMainContentVisible: Bool

    @State private var isSearchActive = false
    @State private var searchText = ""
    @State private var isScrollEnabled = false
    @State private var limitText: String = ""
    @State private var showAlertBinding: Bool = false
    @State private var isSettingAllUsersLimit = true // Track if setting limit for all users or individual
    @State private var selectedFriendId: String = ""

    @StateObject private var viewModel = MsgLimitViewModel()

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Back arrow header (shown when messageLmtView is true)
                // Android: marginStart="20dp", marginTop="15dp", marginEnd="10dp"
                if messageLmtView {
                    HStack(spacing: 0) {
                        Button(action: {
                            withAnimation {
                                isPressed = true
                                isStretchedUp = false
                                isMainContentVisible = true
                                withAnimation(.easeInOut(duration: 0.30)) {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        messageLmtView = false
                                        isPressed = false
                                        isScrollEnabled = false
                                    }
                                }
                            }
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
                        .frame(width: 40, height: 40)
                        .padding(.trailing, 5) // marginEnd="5dp" for the button container
                        
                        Spacer()
                    }
                    .padding(.leading, 20) // marginStart="20dp"
                    .padding(.trailing, 10) // marginEnd="10dp"
                    .padding(.top, 15) // marginTop="15dp"
                }

                // Header text
                // Android: layout_below="@+id/backlyt", layout_marginTop="10dp"
                VStack(alignment: .center, spacing: 0) {
                    Text("Set message limit per day \nUser can send message upto limit you set.")
                        .font(.custom("Inter18pt-Medium", size: 13)) // Match groupMessageView font style
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .foregroundColor(Color("TextColor"))
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 10) // layout_marginTop="10dp"

                // Search section
                // Android: layout_below="@id/create", layout_marginTop="15dp"
                HStack(spacing: 0) {
                    Spacer()
                    if isSearchActive {
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color("blue"))
                                .frame(width: 1, height: 19.24)
                                .padding(.leading, 23) // marginStart="23dp"
                            TextField("Search Name or Number", text: $searchText)
                                .font(.custom("Inter18pt-Regular", size: 15))
                                .foregroundColor(Color("TextColor"))
                                .padding(.leading, 13) // marginStart="13dp"
                                .textFieldStyle(PlainTextFieldStyle())
                                .onChange(of: searchText) { newValue in
                                    viewModel.filterChatList(searchText: newValue)
                                }
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                    Button(action: {
                        withAnimation {
                            isSearchActive.toggle()
                            if !isSearchActive {
                                searchText = ""
                                viewModel.filterChatList(searchText: "")
                            }
                        }
                    }) {
                        Image("search")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .padding(10)
                    }
                    .frame(width: 40, height: 40)
                    .background(Color.clear)
                    .clipShape(Circle())
                    .buttonStyle(CircularRippleStyle())
                    .padding(.trailing, 20) // marginEnd="20dp"
                }
                .padding(.top, 15) // layout_marginTop="15dp"

                // Label section with A-Z - positioned on left side
                // Android: layout_marginLeft="20dp", marginTop="15dp", marginRight="15dp", marginBottom="10dp"
                HStack(alignment: .center, spacing: 0) {
                    // "A - Z" Label - left aligned
                    VStack(spacing: 0) {
                        Text("A - Z")
                            .font(.custom("Inter18pt-SemiBold", size: 12)) // Match groupMessageView "Groups" label style
                            .foregroundColor(.white)
                            .frame(width: 70, height: 30)
                            .multilineTextAlignment(.center)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color("buttonColorTheme"))
                                    .frame(width: 70, height: 30)
                            )
                    }
                    
                    Spacer() // Push A-Z to the left
                }
                .padding(.leading, 20) // marginLeft="20dp"
                .padding(.trailing, 15) // marginRight="15dp"
                .padding(.top, 15) // marginTop="15dp"
                .padding(.bottom, 10) // marginBottom="10dp"

                // Content area - RecyclerView layout_below="@id/label"
                if viewModel.isLoading && !viewModel.hasCachedContacts {
                    ZStack {
                        Color("BackgroundColor")
                        HorizontalProgressBar()
                            .frame(width: 40, height: 2) // Match groupMessageView progress bar height
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else if viewModel.filteredChatList.isEmpty && !viewModel.isLoading {
                    // No data view - Android: layout_centerInParent="true"
                    ZStack {
                        Color("BackgroundColor")
                        VStack {
                            Spacer()
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color("menuRect"))
                                VStack(spacing: 4) {
                                    Text("No contacts available")
                                        .font(.custom("MicrosoftPhagspa", size: 14))
                                        .foregroundColor(Color("black_white_cross"))
                                }
                                .padding(12) // Android: padding="12dp"
                            }
                            .frame(width: 200, height: 80)
                            Spacer()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.filteredChatList, id: \.uid) { chat in
                                ContactCardView(viewModel: viewModel, chat: chat, isSettingAllUsersLimit: $isSettingAllUsersLimit, selectedFriendId: $selectedFriendId)
                                    .contentShape(Rectangle())
                            }
                        }
                        .padding(.bottom, 20)
                        .frame(maxHeight: .infinity, alignment: .top)
                    }
                    .scrollDisabled(!isScrollEnabled)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation
                            }
                            .onEnded { value in
                                withAnimation(.easeInOut(duration: 0.30)) {
                                    if value.translation.height < -50 {
                                        isStretchedUp = true
                                        isMainContentVisible = false
                                        messageLmtView = true
                                        isScrollEnabled = true
                                    } else if value.translation.height > 50 {
                                        isPressed = true
                                        isStretchedUp = false
                                        isMainContentVisible = true
                                        withAnimation(.easeInOut(duration: 0.30)) {
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                messageLmtView = false
                                                isPressed = false
                                                isScrollEnabled = false
                                            }
                                        }
                                    }
                                    dragOffset = .zero
                                }
                            }
                    )
                    .animation(.spring(), value: dragOffset)
                }
            }
            .padding(.horizontal, 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("BackgroundColor"))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        withAnimation(.easeInOut(duration: 0.30)) {
                            if value.translation.height < -50 {
                                isStretchedUp = true
                                isMainContentVisible = false
                                messageLmtView = true
                                isScrollEnabled = true
                            } else if value.translation.height > 50 {
                                isPressed = true
                                isStretchedUp = false
                                isMainContentVisible = true
                                withAnimation(.easeInOut(duration: 0.30)) {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        messageLmtView = false
                                        isPressed = false
                                        isScrollEnabled = false
                                    }
                                }
                            }
                            dragOffset = .zero
                        }
                    }
            )
            .animation(.spring(), value: dragOffset)
            .onAppear {
                viewModel.fetch_user_active_chat_list_for_msgLmt(uid: Constant.SenderIdMy)
                viewModel.fetch_message_limit_for_all_users(uid: Constant.SenderIdMy)
            }
            .onChange(of: viewModel.currentUserLimit) { newValue in
                // Update when limit changes
            }

            // Custom Alert for setting limit
            if viewModel.showAlert {
                LimitCardView(
                    isPresented: $viewModel.showAlert,
                    position: viewModel.tapPosition,
                    isSettingAllUsersLimit: isSettingAllUsersLimit,
                    viewModel: viewModel,
                    friendId: selectedFriendId
                )
            }
        }
    }
}

// ContactCardView - matches Android msg_limit_row.xml layout exactly
struct ContactCardView: View {
    @ObservedObject var viewModel: MsgLimitViewModel
    var chat: UserActiveContactModel
    @Binding var isSettingAllUsersLimit: Bool
    @Binding var selectedFriendId: String
    @State private var isPressed = false
    
    var body: some View {
        // Android: RelativeLayout with custom_ripple background
        // Android: LinearLayout (hori1) with marginTop="10dp" and marginBottom="10dp"
        HStack(spacing: 0) {
            // Android: FrameLayout with marginLeft="20dp", marginRight="20dp", padding="2dp", card_border background
            // Android: CardView with cardCornerRadius="360dp" (circular)
            // Android: ImageView 48dp x 48dp
            ZStack {
                // Card border background (Android: @drawable/card_border) - using theme color stroke
                // The border is 2dp wide, so outer circle is 52dp (48 + 2*2)
                Circle()
                    .stroke(Color("blue"), lineWidth: 2) // 2dp border stroke with theme color
                    .frame(width: 52, height: 52)
                
                // Circular image container - 48dp x 48dp
                CardView(image: chat.photo)
                    .frame(width: 48, height: 48)
            }
            .padding(.leading, 20) // marginLeft="20dp"
            .padding(.trailing, 20) // marginRight="20dp"
            
            // Android: LinearLayout with layout_weight="1" for name, layout_weight="3" for button container
            HStack(spacing: 0) {
                // Android: TextView name - fontFamily="@font/inter_bold", maxWidth="200dp", layout_weight="1"
                Text(chat.fullName)
                    .font(.custom("Inter18pt-SemiBold", size: 16)) // Match groupMessageView group name style
                    .foregroundColor(Color("TextColor"))
                    .lineLimit(1)
                    .frame(maxWidth: 200, alignment: .leading) // maxWidth="200dp"
                    .frame(maxWidth: .infinity, alignment: .leading) // layout_weight="1"
                
                // Android: LinearLayout with layout_weight="3", layout_marginEnd="15dp"
                HStack(spacing: 0) {
                    Spacer()
                    
                    // Android: LinearLayout (l1) - 51dp x 24dp, background="@drawable/radius_black_6dp"
                    // Android: TextView txt1 - textColor="@color/whitenew", fontFamily="@font/inter_medium"
                    Button(action: {
                        isSettingAllUsersLimit = false
                        selectedFriendId = chat.uid
                        viewModel.showAlert = true
                    }) {
                        HStack(spacing: 0) {
                            Text("\(chat.msgLimit)")
                                .font(.custom("Inter18pt-Medium", size: 12))
                                .foregroundColor(.white) // textColor="@color/whitenew" - using white
                                .lineSpacing(2)
                                .frame(width: 51, height: 24)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color("buttonColorTheme"))
                                .frame(width: 51, height: 24)
                        )
                        .frame(width: 51, height: 24)
                    }
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        SpatialTapGesture(coordinateSpace: .global)
                            .onEnded { value in
                                isSettingAllUsersLimit = false
                                selectedFriendId = chat.uid
                                viewModel.tapPosition = value.location
                                viewModel.showAlert = true
                            }
                    )
                    .padding(.trailing, 15) // layout_marginEnd="15dp"
                }
                .frame(maxWidth: .infinity) // layout_weight="3"
            }
        }
        .padding(.top, 10) // marginTop="10dp"
        .padding(.bottom, 10) // marginBottom="10dp"
        .contentShape(Rectangle())
        .background(
            // Android: custom_ripple background
            Color.clear
        )
        .onTapGesture {
            // Ripple effect on tap
            withAnimation(.easeOut(duration: 0.1)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.1)) {
                    isPressed = false
                }
            }
        }
    }
}

// CardView for profile image - Android: CardView with cardCornerRadius="360dp" (circular)
struct CardView: View {
    var image: String?
    var body: some View {
        CachedAsyncImage(url: URL(string: image ?? "")) { image in
            image
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(Circle())
        } placeholder: {
            Image("inviteimg")
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(Circle())
        }
    }
}

// LimitCardView for setting message limit
struct LimitCardView: View {
    @Binding var isPresented: Bool
    var position: CGPoint
    var isSettingAllUsersLimit: Bool
    @ObservedObject var viewModel: MsgLimitViewModel
    var friendId: String
    @State private var limitText: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var isResettingText = false

    private func adjustedOffsetX(in geometry: GeometryProxy) -> CGFloat {
        let cardWidth: CGFloat = 141
        let padding: CGFloat = 8
        let frame = geometry.frame(in: .global)
        let localX = position.x - frame.minX
        let centeredX = localX - (cardWidth / 2)
        let maxX = geometry.size.width - cardWidth - padding
        return min(max(centeredX, padding), maxX)
    }
    
    private func adjustedOffsetY(in geometry: GeometryProxy) -> CGFloat {
        let cardHeight: CGFloat = 54
        let padding: CGFloat = 8
        let frame = geometry.frame(in: .global)
        let localY = position.y - frame.minY
        let centeredY = localY - (cardHeight / 2)
        let maxY = geometry.size.height - cardHeight - padding
        return min(max(centeredY, padding), maxY)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Background Blur + Tap to dismiss
                Rectangle()
                    .fill(Color.black.opacity(0.001))
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissWithoutSaving()
                    }

                // Limit Input Card
                VStack {
                    TextField("Set limit", text: $limitText)
                        .keyboardType(.numberPad)
                        .frame(width: 100)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 5)
                        .foregroundColor(Color("black_white_cross"))
                        .font(.custom("Inter18pt-Medium", size: 14))
                        .focused($isTextFieldFocused)
                        .onChange(of: limitText) { newValue in
                            guard !isResettingText else {
                                isResettingText = false
                                return
                            }
                            
                            let filtered = newValue.filter { $0.isNumber }
                            let truncated = String(filtered.prefix(3))
                            
                            if truncated != newValue {
                                limitText = truncated
                                return
                            }
                            
                            let finalValue = truncated.isEmpty ? "0" : truncated
                            sendLimitToAPI(with: finalValue)
                            
                            if truncated.count == 3 {
                                closeCard()
                            }
                        }
                        .onChange(of: isTextFieldFocused) { focused in
                            // When keyboard is dismissed, submit if there's text
                            if !focused && limitText.count == 3 {
                                closeCard()
                            }
                        }
                }
                .frame(width: 141, height: 54)
                .background(Color("menuRect"))
                .cornerRadius(4)
                .shadow(radius: 1)
                .offset(x: adjustedOffsetX(in: geometry), y: adjustedOffsetY(in: geometry))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isTextFieldFocused = true
                    }
                }
            }
        }
    }
    
    private func dismissWithoutSaving() {
        closeCard()
    }
    
    private func sendLimitToAPI(with value: String) {
        if isSettingAllUsersLimit {
            viewModel.set_message_limit_for_all_users(uid: Constant.SenderIdMy, msg_limit: value)
        } else {
            viewModel.set_message_limit_for_user_chat(uid: Constant.SenderIdMy, friend_id: friendId, msg_limit: value)
        }
    }
    
    private func closeCard() {
        guard isPresented else { return }
        isResettingText = true
        limitText = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isTextFieldFocused = false
            isPresented = false
        }
    }
}

#Preview {
    messageLmtView(isMainContentVisible: .constant(false))
        .environment(
            \.managedObjectContext,
             PersistenceController.preview.container.viewContext
        )
}
