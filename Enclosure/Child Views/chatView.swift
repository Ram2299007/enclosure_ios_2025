import Foundation
import SwiftUI

struct chatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var tappedIndex: Int? = nil
    var searchText: String = ""

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
        
        return VStack {
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
                }
                .listStyle(PlainListStyle())
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
                chatListView
            }
        }
        .onAppear {
            print("🟡 [chatView] onAppear - fetching chat list for uid: \(Constant.SenderIdMy)")
            viewModel.fetchChatList(uid: Constant.SenderIdMy)
        }
    }

    private var chatListView: some View {
        List(filteredChatList, id: \.uid) { chat in
            ContactCardView(chat: chat)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
        }
        .listStyle(PlainListStyle())
    }


    struct ContactCardView: View {
        var chat: UserActiveContactModel
        @State private var isPressed = false
        var body: some View {
            HStack(alignment: .center, spacing: 0) {
                // Contact Image with border - matching Android layout
                // FrameLayout equivalent: marginStart="1dp", layout_gravity="center_vertical"
                CardView(image: chat.photo)
                    .padding(.leading, 1) // marginStart="1dp" for FrameLayout
                    .padding(.trailing, 16) // marginEnd="16dp" for FrameLayout

                // Vertical LinearLayout - layout_gravity="center_vertical"
                VStack(alignment: .leading, spacing: 0) {
                    // First horizontal LinearLayout (Name and Time)
                    HStack(spacing: 0) {
                        Text(chat.fullName)
                            .font(.custom("Inter18pt-SemiBold", size: 16))
                            .foregroundColor(Color("TextColor"))
                            .lineLimit(1) // singleLine="true" equivalent
                        
                        Spacer()
                        
                        Text(chat.sentTime)
                            .font(.custom("Inter18pt-Medium", size: 12))
                            .foregroundColor(chat.notification > 0 ? Color("blue"): Color("Gray3"))
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
                .contentShape(Rectangle())
                .background(isPressed ? Color.gray.opacity(0.1) : Color.clear)
                .scaleEffect(isPressed ? 0.98 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isPressed)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in isPressed = true }
                        .onEnded { _ in
                            isPressed = false
                            print("Tapped: \(chat.fullName)") // Handle single tap
                        }
                )
                .onLongPressGesture(minimumDuration: 0.01, pressing: { pressing in
                    isPressed = pressing
                }, perform: {
                    // Optional: Handle tap if needed
                })
        }
    }

    struct CardView: View {
        var image: String?

        var body: some View {
            // FrameLayout with border - matching Android card_border
            // FrameLayout: padding="2dp", background="@drawable/card_border"
            // CardView inside: cardCornerRadius="360dp" (fully circular)
            // Image: 50dp x 50dp, scaleType="centerCrop"
            ZStack {
                // Border background (card_border equivalent)
                // The border is 2dp wide, so outer circle is 54dp (50 + 2*2)
                Circle()
                    .stroke(Color("blue"), lineWidth: 2) // 2dp border stroke
                    .frame(width: 54, height: 54)
                
                // Inner circular image - 50dp x 50dp
                // Using AsyncImage to fetch the image from the URL
                AsyncImage(url: URL(string: image ?? "")) { phase in
                    switch phase {
                    case .empty:
                        // Placeholder image while the image is loading
                        Image("inviteimg")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    case .success(let image):
                        // Loaded image - centerCrop equivalent
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    case .failure:
                        // Fallback image if the network image loading fails
                        Image("inviteimg")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    @unknown default:
                        // Default case
                        Image("inviteimg")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    }
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
                Image("notiiconsvg")
                    .resizable()
                    .scaledToFit()

                Text("\(count)")
                    .foregroundColor(.white)
                    .font(.custom("Inter18pt-Regular", size: 12))
            }
            .frame(width: 32, height: 20) // Matching Android: 32dp width, 20dp height
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
            HStack(spacing: 5) { // 5dp spacing between icon and text (matching Android drawablePadding)
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
                    .foregroundColor(Color("Gray3"))
                    .lineLimit(1) // singleLine="true" equivalent
            }
        }
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
                            .foregroundColor(Color("blue"))
                            .padding(.trailing, 8)
                    }
                    
                    HStack {
                        // Caption
                        Text("Welcome to Enclosure Messagi...")
                            .font(.custom("Inter18pt-Medium", size: 13))
                            .foregroundColor(Color("Gray3"))
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

}

#Preview {
    chatView()
        .environment(
            \.managedObjectContext,
             PersistenceController.preview.container.viewContext
        )
}


