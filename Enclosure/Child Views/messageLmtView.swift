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
    @State private var allValueLmt = "0"
    @State private var isScrollEnabled = false
    @State private var limitText: String = ""
    @State private var showAlertBinding: Bool = false

    @StateObject private var viewModel = MsgLimitViewModel()


    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if messageLmtView {
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
                    .padding(.leading, 5)
                    .padding(.bottom, 15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .center, spacing: 0) {
                    Text("Set message limit per day \nUser can send message upto limit you set.")
                        .font(.custom("Inter18pt-Medium", size: 12))
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .foregroundColor(Color("TextColor"))
                }
                .frame(maxWidth: .infinity, alignment: .center)

                HStack {
                    Spacer()
                    if isSearchActive {
                        HStack {
                            Rectangle()
                                .fill(Color("blue"))
                                .frame(width: 1, height: 19.24)
                            TextField("Search Name", text: $searchText)
                                .font(.custom("Inter18pt-Regular", size: 15))
                                .foregroundColor(Color("TextColor"))
                                .padding(.leading, 13)
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                    Button(action: {
                        withAnimation {
                            isSearchActive.toggle()
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
                }
                .padding(.top, 15)

                HStack(alignment: .center, spacing: 0) {
                    // Left Side: "A - Z" Label + Down Arrow
                    VStack(spacing: 0) {
                        Text("A - Z")
                            .font(.custom("Inter18pt-Medium", size: 12))
                            .foregroundColor(.white)
                            .frame(width: 70, height: 30)
                            .multilineTextAlignment(.center)
                            .background(
                                Image("rectinfinity")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 70, height: 30)
                                    .cornerRadius(6)
                                    .clipped()
                            )
                            .cornerRadius(6)
                    }

                    Spacer()

                    // Right Side: All Msg Limit View
                    Button(action: {
                        // Optional: Keep button action for fallback
                        print("Button tapped")
                        viewModel.showAlert = true
                    }) {
                        HStack {
                            Text(allValueLmt)
                                .font(.custom("Inter18pt-Medium", size: 12))
                                .foregroundColor(.white)
                                .lineSpacing(2)
                                .frame(width: 51, height: 24)
                        }
                        .background(
                            Image("rectinfinity")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        )
                        .frame(width: 51, height: 24)
                        .padding(.trailing, 5)
                    }
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        SpatialTapGesture(coordinateSpace: .global)
                            .onEnded { value in
                                viewModel.tapPosition = value.location
                                viewModel.showAlert = true
                            }
                    )
                }
                .padding(.top, 15)
                .padding(.bottom, 10)

                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else if let errorMessage = viewModel.errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.chatList, id: \.uid) { chat in
                                ContactCardView(viewModel:viewModel,chat: chat)
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
                                        print("Scroll enabled")
                                    } else if value.translation.height > 50 {
                                        isPressed = true
                                        isStretchedUp = false
                                        isMainContentVisible = true
                                        withAnimation(.easeInOut(duration: 0.30)) {
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                messageLmtView = false
                                                isPressed = false
                                                isScrollEnabled = false
                                                print("Scroll disabled")
                                            }
                                        }
                                    }
                                    dragOffset = .zero
                                }
                            }
                    )
                    .animation(.spring(), value: dragOffset)


                }
                Spacer()
            }
            .padding(.top, 15)
            .padding(.horizontal, 15)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear.contentShape(Rectangle()))
            // Disable parent DragGesture to avoid conflicts
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
                                print("Stretched upward!")
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
                viewModel.fetch_message_limit_for_all_users(
                        uid: Constant.SenderIdMy
                    )

                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { // Delay for API response
                    if let fetchedProfile = viewModel.AllLmtList.first {
                        allValueLmt = "4"

                    } else {
                        print("No profile data available or list is empty")
                        Spacer()
                    }
                }

            }

            // Custom Alert
            if viewModel.showAlert {
                LimitCardView(isPresented: $viewModel.showAlert, position: viewModel.tapPosition)
                    .onChange(of: showAlertBinding) { newValue in
                        if !newValue {
                            viewModel.showAlert = false
                        }
                    }
            }
        }
    }
}

// ContactCardView remains unchanged
struct ContactCardView: View {
    @ObservedObject var viewModel: MsgLimitViewModel
    var chat: UserActiveContactModel
    @State private var isPressed = false
    var body: some View {
        HStack {
            CardView(image: chat.photo)
                .padding(.trailing, 16)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(chat.fullName)
                        .font(.custom("Inter18pt-SemiBold", size: 16))
                        .foregroundColor(Color("TextColor"))
                    Spacer()

                    Button(action:{
                        print("Button tapped")
                        viewModel.showAlert = true
                    }){
                        HStack {
                            Text("0")
                                .font(.custom("Inter18pt-Medium", size: 12))
                                .foregroundColor(.white)
                                .lineSpacing(2)
                                .frame(width: 51, height: 24)
                        }
                        .background(
                            Image("rectinfinity")
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(Color("blue"))
                                .aspectRatio(contentMode: .fill)
                        )
                        .contentShape(Rectangle())
                        .simultaneousGesture(
                            SpatialTapGesture(coordinateSpace: .global)
                                .onEnded { value in
                                    viewModel.tapPosition = value.location
                                    viewModel.showAlert = true
                                }
                        )
                        .frame(width: 51, height: 24)
                        .padding(.trailing, 5)
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }
}

// CardView remains unchanged

struct CardView: View {
    var image: String?
    var body: some View {
        AsyncImage(url: URL(string: image ?? "")) { phase in
            switch phase {
            case .empty:
                Image("inviteimg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .cornerRadius(6)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .cornerRadius(6)
            case .failure:
                Image("inviteimg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .cornerRadius(6)
            @unknown default:
                Image("inviteimg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .cornerRadius(6)
            }
        }
    }
}

struct LimitCardView: View {
    @Binding var isPresented: Bool
    var position: CGPoint
    @State private var limitText: String = ""
    @FocusState private var isTextFieldFocused: Bool  // 👈 Focus state

    private func adjustedOffsetX(in geometry: GeometryProxy) -> CGFloat {
        let cardWidth: CGFloat = 141
        let padding: CGFloat = 8
        let maxX = geometry.size.width - cardWidth - padding
        return min(max(position.x, padding), maxX)
    }

    private func adjustedOffsetY(in geometry: GeometryProxy) -> CGFloat {
        let cardHeight: CGFloat = 54
        let padding: CGFloat = 8
        let maxY = geometry.size.height - cardHeight - padding
        return min(max(position.y, padding), maxY)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Background Blur + Tap to dismiss
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut) {
                            isPresented = false
                            isTextFieldFocused = false  // 👈 Hide keyboard

                        }
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
                        .focused($isTextFieldFocused)  // 👈 Bind focus
                        .onChange(of: limitText) { newValue in
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered.count > 3 {
                                limitText = String(filtered.prefix(3))
                            } else if filtered != newValue {
                                limitText = filtered
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
                        isTextFieldFocused = true  // 👈 Auto focus on appear
                    }
                }
            }
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
