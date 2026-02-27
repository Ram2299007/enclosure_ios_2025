import Foundation
import SwiftUI
import FirebaseDatabase
import UIKit

struct chatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var tappedIndex: Int? = nil
    var searchText: String = ""
    
    // Long press dialog state - use @Binding to connect to parent
    @Binding var selectedChatForDialog: UserActiveContactModel?
    @Binding var dialogPosition: CGPoint
    @Binding var showLongPressDialog: Bool

    // Navigation state for chatting screen
    @Binding var selectedChatForNavigation: UserActiveContactModel?
    
    // Navigation state for UserInfoScreen
    @State private var navigateToUserInfoScreen: Bool = false
    @State private var selectedUserForInfo: (uid: String, name: String)?
    
    // Firebase listener handle
    @State private var firebaseListenerHandle: DatabaseHandle?
    @State private var showSessionEndedDialog: Bool = false
    @State private var didCheckSessionStatus: Bool = false
    @State private var lastUpdateTimestamp: Date = Date() // Force UI refresh trigger

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredChatList: [UserActiveContactModel] {
        guard !trimmedSearchText.isEmpty else { return viewModel.chatList }

        return viewModel.chatList.filter { chat in
            chat.fullName.lowercased().contains(trimmedSearchText.lowercased()) ||
            chat.mobileNo.contains(trimmedSearchText)
        }
    }



    var body: some View {
        let _ = print("🟡 [chatView] Rendering - isLoading: \(viewModel.isLoading), errorMessage: '\(viewModel.errorMessage ?? "nil")', chatList count: \(viewModel.chatList.count)")
        
        return VStack(spacing: 0) {
            if viewModel.isLoading && !viewModel.hasCachedChats {
                let _ = print("🟡 [chatView] Showing LOADING state (no cache)")
                ZStack {
                    Color("BackgroundColor")
                    HorizontalProgressBar()
                        .frame(width: 40, height: 2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if let errorMessage = viewModel.errorMessage {
                let _ = print("🟡 [chatView] Showing ERROR state - message: '\(errorMessage)'")
                // Show error message
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.red.opacity(0.6))
                    Text(errorMessage)
                        .font(.custom("Inter18pt-Medium", size: 16))
                        .foregroundColor(Color("TextColor"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if viewModel.chatList.isEmpty {
                let _ = print("🟡 [chatView] Showing EMPTY state - showing placeholder")
                // Show placeholder contact card when no chats are available
                List {
                    PlaceholderContactCardView()
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color("background_color"))
                }
                .listStyle(PlainListStyle())
                .background(Color("background_color"))
            } else if filteredChatList.isEmpty {
                Text("No chats found")
                    .font(.custom("Inter18pt-Medium", size: 14))
                    .foregroundColor(Color("TextColor"))
                    .padding(16)
                    .background(Color("cardBackgroundColornew"))
                    .cornerRadius(20)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let _ = print("🟡 [chatView] Showing DATA state - \(filteredChatList.count) items (filtered from \(viewModel.chatList.count))")
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(filteredChatList, id: \.uid) { chat in
                            ContactCardView(
                                chat: chat,
                                selectedChatForNavigation: $selectedChatForNavigation,
                                onLongPress: { chat, position in
                                    selectedChatForDialog = chat
                                    dialogPosition = position
                                    showLongPressDialog = true
                                },
                                onProfileImageTap: { chat in
                                    // Navigate to UserInfoScreen when profile image is tapped
                                    selectedUserForInfo = (uid: chat.uid, name: chat.fullName)
                                    navigateToUserInfoScreen = true
                                }
                            )
                            .background(Color("background_color"))
                        }
                    }
                }
                .background(Color("background_color"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            print("🟡 [chatView] onAppear - fetching chat list for uid: \(Constant.SenderIdMy)")
            viewModel.fetchChatList(uid: Constant.SenderIdMy)
            
            // Set up Firebase Realtime Database listener for chattingSocket (matching Android)
            setupChattingSocketListener(uid: Constant.SenderIdMy)
            
            // Check if current session is still active on this device
            checkSessionStatus()
        }
        .onDisappear {
            // Remove Firebase listener when view disappears
            removeChattingSocketListener()
        }
        .onChange(of: viewModel.chatList) { newChatList in
            // Recalculate badge count whenever chat list changes
            print("📱 [chatView] Chat list changed - count: \(newChatList.count)")
            
            // Debug: Print notification counts
            let totalNotifications = newChatList.reduce(0) { $0 + $1.notification }
            let chatsWithNotifications = newChatList.filter { $0.notification > 0 }
            print("📱 [chatView] Total notifications: \(totalNotifications)")
            print("📱 [chatView] Chats with unread: \(chatsWithNotifications.count)")
            
            if !chatsWithNotifications.isEmpty {
                print("📱 [chatView] Chats with unread messages:")
                for chat in chatsWithNotifications {
                    print("📱 [chatView]   - \(chat.fullName): \(chat.notification) unread")
                }
            }
            
            if !newChatList.isEmpty {
                BadgeManager.shared.calculateTotalBadgeFromChats(chatList: newChatList)
                print("📱 [chatView] Badge recalculated from \(newChatList.count) chats")
            }
            
            // Force UI refresh by updating timestamp
            lastUpdateTimestamp = Date()
            print("📱 [chatView] UI refresh triggered at \(lastUpdateTimestamp)")
        }
        .overlay(
            ConfirmationDialogView(
                isPresented: $showSessionEndedDialog,
                message: "Session ended:\nThis number is now active on another device.",
                showCancel: false,
                confirmTitle: "Sure",
                cancelTitle: "Cancel",
                onConfirm: {
                    handleSessionEndedConfirmation()
                },
                onCancel: {}
            )
        )
        .background(
            // Hidden NavigationLink for UserInfoScreen
            NavigationLink(
                destination: Group {
                    if let userInfo = selectedUserForInfo {
                        UserInfoScreen(
                            recUserId: userInfo.uid,
                            recUserName: userInfo.name
                        )
                    } else {
                        EmptyView()
                    }
                },
                isActive: $navigateToUserInfoScreen
            ) {
                EmptyView()
            }
            .hidden()
        )
    }

    

    struct ContactCardView: View {
        var chat: UserActiveContactModel
        @Binding var selectedChatForNavigation: UserActiveContactModel?
        var onLongPress: (UserActiveContactModel, CGPoint) -> Void
        var onProfileImageTap: ((UserActiveContactModel) -> Void)? // Callback for profile image tap
        
        @State private var profileImageTapped = false // Track if profile image was tapped
        @State private var rowFrame: CGRect = .zero
        
        var body: some View {
            HStack(alignment: .center, spacing: 0) {
                // Contact Image with border - matching Android layout
                // FrameLayout equivalent: marginStart="1dp", layout_gravity="center_vertical"
                CardView(image: chat.photo, themeColor: chat.themeColor)
                    .padding(.leading, 1) // marginStart="1dp" for FrameLayout
                    .padding(.trailing, 16) // marginEnd="16dp" for FrameLayout
                    .onTapGesture {
                        // Mark that profile image was tapped
                        profileImageTapped = true
                        // Open UserInfoScreen when profile image is tapped
                        onProfileImageTap?(chat)
                    }

                // Vertical LinearLayout - layout_gravity="center_vertical"
                VStack(alignment: .leading, spacing: 0) {
                    // First horizontal LinearLayout (Name and Time)
                    HStack(spacing: 0) {
                        Text(Constant.formatNameWithYou(uid: chat.uid, fullName: chat.fullName))
                            .font(.custom("Inter18pt-SemiBold", size: 16))
                            .foregroundColor(Color("TextColor"))
                            .lineLimit(1) // singleLine="true" equivalent
                        
                        Spacer()
                        
                        Text(chat.sentTime)
                            .font(.custom("Inter18pt-Medium", size: 12))
                            .foregroundColor(chat.notification > 0 ? Color(hex: Constant.themeColor) : Color("gray3"))
                            .padding(.trailing, 8) // layout_marginEnd="8dp"
                    }

                    // Second horizontal LinearLayout (Caption and Notification)
                    HStack(alignment: .center, spacing: 0) {
                        // Caption TextView - matching Android adapter logic
                        CaptionTextView(chat: chat)
                            .padding(.top, 2) // layout_marginTop="2dp"
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Spacer()

                        // Notification Badge LinearLayout - layout_gravity="end", marginTop="5dp"
                        if chat.notification > 0 {
                            NotificationBadge(count: chat.notification)
                                .padding(.top, 5) // layout_marginTop="5dp"
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, 10) // marginStart="10dp" for LinearLayout
            .padding(.top, 16) // marginTop="16dp" for LinearLayout
            .padding(.bottom, 16) // marginTop="16dp" for divider View (effective bottom spacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 82) // Fixed height for consistent layout
            .contentShape(Rectangle())
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { rowFrame = geo.frame(in: .global) }
                        .onChange(of: geo.frame(in: .global)) { newFrame in
                            rowFrame = newFrame
                        }
                }
            )
            .onTapGesture {
                if !profileImageTapped {
                    print("Tapped: \(chat.fullName)")
                    ChatCacheManager.shared.upsertContact(chat)
                    print("[NOTIF_RECEIVER_DEVICE] selected receiver_uid=\(chat.uid) full_name=\(chat.fullName) device_type=\(chat.deviceType)")
                    DispatchQueue.main.async {
                        selectedChatForNavigation = chat
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    profileImageTapped = false
                }
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                let globalX = rowFrame.midX
                let globalY = rowFrame.midY
                print("🔵 Long press - Global: (\(globalX), \(globalY))")
                onLongPress(chat, CGPoint(x: globalX, y: globalY))
            }
        }
    }

    struct CardView: View {
        var image: String?
        var themeColor: String = ""

        private var borderColor: Color {
            let color = themeColor.isEmpty ? Constant.themeColor : themeColor
            return Color(hex: color)
        }

        var body: some View {
            // FrameLayout with border - matching Android card_border
            // FrameLayout: padding="2dp", background="@drawable/card_border"
            // CardView inside: cardCornerRadius="360dp" (fully circular)
            // Image: 50dp x 50dp, scaleType="centerCrop"
            ZStack {
                // Border background (card_border equivalent)
                // The border is 2dp wide, so outer circle is 54dp (50 + 2*2)
                Circle()
                    .stroke(borderColor, lineWidth: 2) // 2dp border stroke
                    .frame(width: 54, height: 54)
                
                CachedAsyncImage(url: URL(string: image ?? "")) { image in
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
                .frame(width: 50, height: 50) // 50dp x 50dp as per Android
            }
            .frame(width: 54, height: 54) // Total FrameLayout size: 54dp x 54dp (50dp image + 2dp border on each side)
        }
    }



    struct NotificationBadge: View {
        var count: Int
        var body: some View {
            ZStack {
                // Custom shape with rounded corners only on the left side
                LeftRoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: Constant.themeColor))
                Text("\(count)")
                    .foregroundColor(.white)
                    .font(.custom("Inter18pt-Regular", size: 12))
            }
            .frame(width: 32, height: 20) // Matching Android: 32dp width, 20dp height
        }
    }
    
    // Custom shape that rounds only the left corners (top-left and bottom-left)
    struct LeftRoundedRectangle: Shape {
        var cornerRadius: CGFloat
        
        func path(in rect: CGRect) -> Path {
            var path = Path()
            
            let radius = min(cornerRadius, rect.height / 2)
            
            // Start from top-left corner (rounded)
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
            
            // Top edge
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            
            // Right edge (no rounding)
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            
            // Bottom edge
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            
            // Bottom-left corner (rounded)
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius), control: CGPoint(x: rect.minX, y: rect.maxY))
            
            // Left edge
            path.closeSubpath()
            
            return path
        }
    }
    
    struct CaptionTextView: View {
        var chat: UserActiveContactModel
        
        // Computed property to get caption text and image icon based on dataType
        // Matching Android adapter logic: lines 305-422
        // Android drawables: gallery, videopng, mike, contact, documentsvg
        private var captionContent: (text: String, imageName: String?) {
            // If message is empty, show dataType-specific text and image icon
            if chat.message.isEmpty {
                switch chat.dataType {
                case "img":
                    return ("Photo", "gallery") // R.drawable.gallery
                case "video":
                    return ("Video", "videopng") // R.drawable.videopng
                case "voiceAudio":
                    return ("Mic", "mike") // R.drawable.mike
                case "contact":
                    return ("Contact", "contact") // R.drawable.contact
                case "Text":
                    return ("", nil) // No icon for text, clear drawables
                case "doc":
                    // For documents, Android checks message field for filename
                    // If message is empty or equals "doc", show "Document"
                    // Since we're in message.isEmpty block, show "Document"
                    return ("Document", "documentsvg") // R.drawable.documentsvg
                default:
                    return ("File", "documentsvg") // R.drawable.documentsvg for file
                }
            } else {
                // If message is not empty, show the message text (truncated to 25 chars)
                // Android: lines 416-421
                // For doc type with message, it might be a filename
                if chat.dataType == "doc" && chat.message != "doc" {
                    // Show filename from message field
                    let fileName = chat.message
                    if fileName.count > 25 {
                        return (String(fileName.prefix(25)) + "...", "documentsvg")
                    } else {
                        return (fileName, "documentsvg")
                    }
                } else {
                    // Regular message text
                    let messageText = chat.message
                    if messageText.count > 25 {
                        return (String(messageText.prefix(25)) + "...", nil)
                    } else {
                        return (messageText, nil)
                    }
                }
            }
        }
        
        var body: some View {
            HStack(spacing: 3) { // drawablePadding="3dp" from Android XML (exact match)
                // Image icon (if available) - matching Android drawable resources
                if let imageName = captionContent.imageName {
                    Image(imageName)
                        .renderingMode(.template) // Required for tint color to work
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16) // 16dp size matching Android
                        .foregroundColor(Color(red: 0x78/255.0, green: 0x78/255.0, blue: 0x7A/255.0)) // Exact Android tint color #78787A
                }
                
                // Text
                Text(captionContent.text)
                    .font(.custom("Inter18pt-Medium", size: 13))
                    .foregroundColor(Color("gray3"))
                    .lineLimit(1) // singleLine="true" equivalent
            }
        }
    }
    
    // MARK: - Firebase Realtime Database Listener (matching Android ChattingRoom.java)
    private func setupChattingSocketListener(uid: String) {
        let database = Database.database().reference()
        let chattingSocketPath = "\(Constant.chattingSocket)/\(uid)"
        
        print("🔵 [chatView] Setting up Firebase listener for path: \(chattingSocketPath)")
        print("🔵 [chatView] Current UID: \(uid)")
        
        // Remove existing listener if any
        if let existingHandle = firebaseListenerHandle {
            database.child(chattingSocketPath).removeObserver(withHandle: existingHandle)
            firebaseListenerHandle = nil
        }
        
        // Listen for value changes (matching Android addValueEventListener)
        firebaseListenerHandle = database.child(chattingSocketPath).observe(.value) { [weak viewModel] snapshot in
            guard let viewModel = viewModel else {
                print("⚠️ [chatView] ViewModel is nil, skipping update")
                return
            }
            
            // Check if snapshot exists and has a value (matching Android message != null check)
            if snapshot.exists() {
                // Get the message value (matching Android snapshot.getValue(String.class))
                if let message = snapshot.value as? String {
                    print("🔵 [chatView] Live update received: \(message)")
                    print("🔵 [chatView] Current chat list count: \(viewModel.chatList.count)")
                    
                    // Refresh chat list when socket message changes (matching Android commented code)
                    // This triggers a refresh of the active chat list
                    DispatchQueue.main.async {
                        print("🔵 [chatView] Refreshing chat list due to socket update")
                        print("🔵 [chatView] Before refresh - Total notifications: \(viewModel.chatList.reduce(0) { $0 + $1.notification })")
                        viewModel.fetchChatList(uid: uid)
                    }
                } else {
                    // Value exists but is not a String (could be other type or null)
                    print("⚠️ [chatView] Snapshot exists but value is not String. Value type: \(type(of: snapshot.value)), Value: \(String(describing: snapshot.value))")
                }
            } else {
                // Snapshot doesn't exist (null value) - matching Android "No message found"
                print("⚠️ [chatView] No message found (snapshot doesn't exist)")
            }
        } withCancel: { error in
            // Handle cancellation/error (matching Android onCancelled)
            print("❌ [chatView] Firebase database error: \(error.localizedDescription)")
        }
        
        // Verify listener was set up
        if firebaseListenerHandle != nil {
            print("✅ [chatView] Firebase listener set up successfully with handle: \(firebaseListenerHandle!)")
            
            // Also read the current value once to verify the path exists
            database.child(chattingSocketPath).observeSingleEvent(of: .value) { snapshot in
                if snapshot.exists() {
                    print("🔵 [chatView] Initial value at path: \(String(describing: snapshot.value))")
                } else {
                    print("⚠️ [chatView] Path exists but has no value (this is normal if no messages yet)")
                }
            }
        } else {
            print("❌ [chatView] Failed to set up Firebase listener")
        }
    }
    
    private func removeChattingSocketListener() {
        guard let handle = firebaseListenerHandle else { return }
        
        let database = Database.database().reference()
        let chattingSocketPath = "\(Constant.chattingSocket)/\(Constant.SenderIdMy)"
        
        print("🔵 [chatView] Removing Firebase listener for path: \(chattingSocketPath)")
        database.child(chattingSocketPath).removeObserver(withHandle: handle)
        firebaseListenerHandle = nil
    }
    
    private func checkSessionStatus() {
        guard !didCheckSessionStatus else { return }
        didCheckSessionStatus = true
        
        let mobileNo = UserDefaults.standard.string(forKey: Constant.PHONE_NUMBERKEY) ?? ""
        let phoneId = UIDevice.current.identifierForVendor?.uuidString ?? ""
        print("🟠 [chatView] checkSessionStatus - mobile: '\(mobileNo)', phoneId: '\(phoneId)'")
        
        guard !mobileNo.isEmpty, !phoneId.isEmpty else {
            print("🟠 [chatView] checkSessionStatus skipped - missing mobile or phoneId")
            return
        }
        
        let allowedQuery = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "+"))
        let encodedMobile = mobileNo.addingPercentEncoding(withAllowedCharacters: allowedQuery) ?? mobileNo
        
        var components = URLComponents(string: Constant.baseURL + "get_phone_id_by_mobile")
        components?.percentEncodedQuery = "mobile_no=\(encodedMobile)"
        
        guard let url = components?.url else {
            print("🟠 [chatView] checkSessionStatus invalid URL")
            return
        }
        print("🟠 [chatView] checkSessionStatus request: \(url.absoluteString)")
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("🟠 [chatView] checkSessionStatus error: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("🟠 [chatView] checkSessionStatus no data")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("🟠 [chatView] checkSessionStatus response: \(json)")
                    let errorCode: Int? = {
                        if let codeInt = json["error_code"] as? Int {
                            return codeInt
                        }
                        if let codeString = json["error_code"] as? String {
                            return Int(codeString)
                        }
                        return nil
                    }()
                    
                    if errorCode == 200,
                       let dataDict = json["data"] as? [String: Any],
                       let serverPhoneId = dataDict["phone_id"] as? String {
                        if serverPhoneId != phoneId {
                            DispatchQueue.main.async {
                                print("🟠 [chatView] Session mismatch detected - showing dialog")
                                showSessionEndedDialog = true
                            }
                        } else {
                            print("🟠 [chatView] Session OK - phoneId matches")
                        }
                    } else {
                        print("🟠 [chatView] checkSessionStatus no valid match - errorCode: \(String(describing: errorCode))")
                    }
                }
            } catch {
                print("🟠 [chatView] checkSessionStatus parse error: \(error.localizedDescription)")
                return
            }
        }.resume()
    }
    
    private func handleSessionEndedConfirmation() {
        let defaults = UserDefaults.standard
        defaults.set("0", forKey: Constant.UID_KEY)
        defaults.set("", forKey: Constant.PHONE_NUMBERKEY)
        defaults.set("", forKey: Constant.country_Code)
        defaults.set("0", forKey: "lockKey")
        defaults.set("sleepKeyCheckOFF", forKey: "sleepKeyCheckOFF")
        defaults.removeObject(forKey: Constant.loggedInKey)
        defaults.synchronize()
        
        NotificationCenter.default.post(name: NSNotification.Name("ForceLogout"), object: nil)
    }
    
    struct PlaceholderContactCardView: View {
        @State private var isPressed = false
        
        // Computed property to get current time in "11:00 am" format
        private var currentTime: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: Date())
        }
        
        var body: some View {
            HStack(spacing: 0) {
                // Contact Image - using ec_modern as placeholder
                Image("ec_modern")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .cornerRadius(6)
                    .padding(.trailing, 16)
                    .padding(.leading, 16)
                
                VStack(alignment: .leading, spacing: 0) {
                    // Name and Time
                    HStack {
                        Text("@Enclosureforworld")
                            .font(.custom("Inter18pt-SemiBold", size: 16))
                            .foregroundColor(Color("TextColor"))
                        Spacer()
                        Text(currentTime)
                            .font(.custom("Inter18pt-Medium", size: 12))
                            .foregroundColor(Color(hex: Constant.themeColor))
                            .padding(.trailing, 8)
                    }
                    
                    HStack {
                        // Caption
                        Text("Welcome to Enclosure Messagi...")
                            .font(.custom("Inter18pt-Medium", size: 13))
                            .foregroundColor(Color("gray3"))
                            .lineLimit(1)
                            .padding(.vertical, 5)
                        
                        Spacer()
                        
                        // Notification Badge
                        NotificationBadge(count: 1)
                    }
                }
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
            .background(isPressed ? Color.gray.opacity(0.1) : Color.clear)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in
                        isPressed = false
                        // Placeholder card - no action needed
                    }
            )
            .onLongPressGesture(minimumDuration: 0.01, pressing: { pressing in
                isPressed = pressing
            }, perform: {
                // Optional: Handle tap if needed
            })
        }
    }
    
    // ChatLongPressDialog - Matching Android get_user_active_chat_blur_dialogue.xml
    struct ChatLongPressDialog: View {
        let chat: UserActiveContactModel
        let position: CGPoint
        @Binding var isShowing: Bool
        let onDelete: () -> Void
        
        // Calculate adjusted offset X - full width (match_parent)
        private func adjustedOffsetX(in geometry: GeometryProxy) -> CGFloat {
            // Android XML uses match_parent for dialog width, so no horizontal offset needed
            return 0
        }
        
        // Calculate adjusted offset Y - matching messageLmtView.swift logic
        private func adjustedOffsetY(in geometry: GeometryProxy) -> CGFloat {
            let contactCardHeight: CGFloat = 82 // Contact card with padding
            let deleteButtonHeight: CGFloat = 83 // Button (48) + margins (10+25)
            let dialogHeight = contactCardHeight + deleteButtonHeight // ~165
            let padding: CGFloat = 20
            let frame = geometry.frame(in: .global)
            let localY = position.y - frame.minY
            let centeredY = localY - (contactCardHeight / 2) // Center contact card at touch point
            let maxY = geometry.size.height - dialogHeight - padding
            print("🟣 Dialog positioning - Touch Y: \(position.y), Local Y: \(localY), Centered Y: \(centeredY)")
            return min(max(centeredY, padding), maxY)
        }
        
        var body: some View {
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    // Blurred background overlay - matching editmyProfile.swift ImageDialogView
                    Color.black.opacity(0.3)
                        .background(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .zIndex(0) // Background layer
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.2)) {
                                isShowing = false
                            }
                        }
                    
                    // Dialog content positioned at exact touch location using .offset()
                    VStack(spacing: 0) {
                        // Contact card view (matching the XML contact1 layout - RelativeLayout with id="view")
                        VStack(spacing: 0) {
                            // LinearLayout id="contact1" with marginStart="16dp" marginTop="16dp"
                            HStack(alignment: .center, spacing: 0) {
                                // FrameLayout id="themeBorder" - profile image with border
                                // marginStart="1dp" marginEnd="16dp" padding="2dp"
                                CardView(image: chat.photo, themeColor: chat.themeColor)
                                    .padding(.leading, 1) // marginStart="1dp"
                                    .padding(.trailing, 16) // marginEnd="16dp"
                                
                                // Vertical LinearLayout for name/caption
                                VStack(alignment: .leading, spacing: 0) {
                                    // First horizontal LinearLayout (Name and Time)
                                    HStack(spacing: 0) {
                                        // TextView id="contact1text" - Name
                                        // fontFamily="@font/inter_bold" textSize="16sp" textColor="@color/TextColor"
                                        let displayName = Constant.formatNameWithYou(uid: chat.uid, fullName: chat.fullName)
                                        Text(displayName.count > 20 ? String(displayName.prefix(20)) + "..." : displayName)
                                            .font(.custom("Inter18pt-SemiBold", size: 16))
                                            .foregroundColor(Color("TextColor"))
                                            .lineLimit(1)
                                        
                                        Spacer()
                                        
                                        // TextView id="time" - Time
                                        // layout_marginEnd="8dp" fontFamily="@font/inter_medium" textSize="12sp"
                                        Text(chat.sentTime)
                                            .font(.custom("Inter18pt-Medium", size: 12))
                                            .foregroundColor(chat.notification > 0 ? Color("blue") : Color("gray3"))
                                            .padding(.trailing, 8) // layout_marginEnd="8dp"
                                    }
                                    
                                    // Second horizontal LinearLayout (Caption and Notification)
                                    HStack(alignment: .center, spacing: 0) {
                                        // TextView id="captiontext" - Caption
                                        // layout_marginTop="2dp" drawablePadding="3dp" textSize="13sp"
                                        DialogCaptionTextView(chat: chat)
                                            .padding(.top, 2) // layout_marginTop="2dp"
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        Spacer()
                                        
                                        // LinearLayout id="notiBack" - Notification badge
                                        // layout_marginTop="5dp" width="32dp" height="20dp"
                                        if chat.notification > 0 {
                                            NotificationBadge(count: chat.notification)
                                                .padding(.top, 5) // layout_marginTop="5dp"
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.leading, 16) // contact1 marginStart="16dp"
                            .padding(.top, 16) // contact1 marginTop="16dp"
                            .padding(.bottom, 16) // Spacing below contact card
                            .padding(.trailing, 16) // Right padding for symmetry
                        }
                        .background(Color("BackgroundColor"))
                        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5) // elevation="10dp"
                        
                        // CardView id="deletecardview" - Delete button
                        // layout_marginHorizontal="20dp" layout_marginTop="10dp" layout_marginBottom="25dp"
                        // cardCornerRadius="20dp" cardBackgroundColor="@color/dxForward"
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                onDelete()
                            }
                        }) {
                            // LinearLayout id="delete" - height="48dp"
                            HStack(spacing: 0) {
                                Spacer()
                                
                                // ImageView - delete icon (baseline_delete_forever_24)
                                // width="26.5dp" height="24dp" layout_marginEnd="2dp"
                                Image("baseline_delete_forever_24")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 26.5, height: 24)
                                    .foregroundColor(Color("gray3")) // tint="@color/gray3"
                                    .padding(.trailing, 2) // layout_marginEnd="2dp"
                                
                                // TextView - "Delete" text
                                // fontFamily="@font/inter" textSize="16sp" textStyle="bold"
                                Text("Delete")
                                    .font(.custom("Inter18pt-Bold", size: 16))
                                    .foregroundColor(Color("TextColor"))
                                
                                Spacer()
                            }
                            .frame(height: 48) // layout_height="48dp"
                            .frame(maxWidth: .infinity)
                            .background(Color("dxForward")) // cardBackgroundColor="@color/dxForward"
                            .cornerRadius(20) // cardCornerRadius="20dp"
                        }
                        .buttonStyle(PlainButtonStyle()) // Remove default button styling
                        .padding(.horizontal, 20) // layout_marginHorizontal="20dp"
                        .padding(.top, 10) // layout_marginTop="10dp"
                        .padding(.bottom, 25) // layout_marginBottom="25dp"
                    }
                    .frame(maxWidth: .infinity) // match_parent width like Android XML
                    .background(Color.clear) // Ensure background doesn't block touches
                    .offset(x: adjustedOffsetX(in: geometry), y: adjustedOffsetY(in: geometry))
                    .zIndex(1) // Dialog content on top of blur
                }
            }
        }
    }
    
    // DialogCaptionTextView - Caption text with icon for dialog (matching Android logic lines 686-695)
    struct DialogCaptionTextView: View {
        var chat: UserActiveContactModel
        
        private var captionContent: (text: String, imageName: String?) {
            if chat.message.isEmpty {
                switch chat.dataType {
                case "img":
                    return ("Photo", "gallery")
                case "video":
                    return ("Video", "videopng")
                case "voiceAudio":
                    return ("Mic", "mike")
                case "contact":
                    return ("Contact", "contact")
                case "Text":
                    return ("", nil)
                case "doc":
                    return ("Document", "documentsvg")
                default:
                    return ("File", "documentsvg")
                }
            } else {
                if chat.dataType == "doc" && chat.message != "doc" {
                    let fileName = chat.message
                    if fileName.count > 25 {
                        return (String(fileName.prefix(25)) + "...", "documentsvg")
                    } else {
                        return (fileName, "documentsvg")
                    }
                } else {
                    let messageText = chat.message
                    if messageText.count > 25 {
                        return (String(messageText.prefix(25)) + "...", nil)
                    } else {
                        return (messageText, nil)
                    }
                }
            }
        }
        
        var body: some View {
            HStack(spacing: 3) { // drawablePadding="3dp" from Android XML
                if let imageName = captionContent.imageName {
                    Image(imageName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16) // 16dp icon size
                        .foregroundColor(Color(red: 0x78/255.0, green: 0x78/255.0, blue: 0x7A/255.0)) // #78787A
                }
                
                Text(captionContent.text)
                    .font(.custom("Inter18pt-Medium", size: 13)) // textSize="13sp"
                    .foregroundColor(chat.notification > 0 ? 
                        Color(red: 0x00/255.0, green: 0x00/255.0, blue: 0x00/255.0) : // #000000 when notification > 0
                        Color(red: 0x9E/255.0, green: 0xA6/255.0, blue: 0xB9/255.0)   // #9EA6B9 when notification == 0
                    )
                    .lineLimit(1) // singleLine="true"
            }
        }
    }

}

struct ConfirmationDialogView: View {
    @Binding var isPresented: Bool
    let message: String
    let showCancel: Bool
    let confirmTitle: String
    let cancelTitle: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    private var dialogWidth: CGFloat {
        min(UIScreen.main.bounds.width - 80, 320)
    }
    
    var body: some View {
        if isPresented {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Text(message)
                        .font(.custom("Inter18pt-Regular", size: 17))
                        .foregroundColor(Color("TextColor"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(25)
                        .padding(.top, 20)
                        .padding(.horizontal, 10)
                    
                    HStack(spacing: 20) {
                        if showCancel {
                            Button(action: {
                                isPresented = false
                                onCancel()
                            }) {
                                Text(cancelTitle)
                                    .font(.custom("Inter18pt-Medium", size: 15))
                                    .foregroundColor(.white)
                                    .frame(height: 36)
                                    .padding(.horizontal, 20)
                                    .background(Color.black)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        Button(action: {
                            isPresented = false
                            onConfirm()
                        }) {
                            Text(confirmTitle)
                                .font(.custom("Inter18pt-Medium", size: 15))
                                .foregroundColor(.white)
                                .frame(height: 36)
                                .padding(.horizontal, 20)
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                }
                .padding(20)
                .frame(width: dialogWidth)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color("cardBackgroundColornew"))
                )
            }
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPresented)
        }
    }
}

#Preview {
    chatView(
        selectedChatForDialog: .constant(nil),
        dialogPosition: .constant(.zero),
        showLongPressDialog: .constant(false),
        selectedChatForNavigation: .constant(nil)
    )
    .environment(
        \.managedObjectContext,
         PersistenceController.preview.container.viewContext
    )
}