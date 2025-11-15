import Foundation
import SwiftUI

struct chatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var tappedIndex: Int? = nil



    var body: some View {
        VStack {
            // Show loading indicator while fetching data
            if viewModel.isLoading {
                ZStack {
                    Color("BackgroundColor")
                    HorizontalProgressBar()
                        .frame(width: 40, height: 2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if let errorMessage = viewModel.errorMessage {
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
                // Show placeholder contact card when no chats are available
                List {
                    PlaceholderContactCardView()
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                }
                .listStyle(PlainListStyle())
            } else {
                // Show chat list if data is fetched successfully
                List(viewModel.chatList, id: \.uid) { chat in
                    ContactCardView(chat: chat)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden) // Hides the separator
                }
                .listStyle(PlainListStyle()) // Optional for clean appearance
            }
        }
        .onAppear {
            viewModel.fetchChatList(uid: Constant.SenderIdMy)
        }
    }


    struct ContactCardView: View {
        var chat: UserActiveContactModel
        @State private var isPressed = false
        var body: some View {
            HStack {
                // Contact Image
                CardView(image: chat.photo)
                    .padding(.trailing,16)
                    .padding(.leading,16)

                VStack(alignment: .leading,spacing:0) {
                    // Name and Time
                    HStack {
                        Text(chat.fullName)
                            .font(.custom("Inter18pt-SemiBold", size: 16))
                            .foregroundColor(Color("TextColor"))
                        Spacer()
                        Text(chat.sentTime)
                            .font(.custom("Inter18pt-Medium", size: 12))
                            .foregroundColor(chat.notification > 0 ? Color("blue"): Color("Gray3"))
                            .padding(.trailing,8)
                    }



                    HStack{
                        // Caption
                        Text(chat.message.isEmpty ? chat.caption : chat.message)
                            .font(.custom("Inter18pt-Medium", size: 13))
                            .foregroundColor(Color("Gray3"))
                            .lineLimit(1)
                            .padding(.vertical, chat.notification > 0 ? 0 : 5)

                        Spacer()


                        // Notification Badge
                        if chat.notification > 0 {

                            NotificationBadge(count: chat.notification)
                        }
                    }




                }

            } .padding(.vertical, 16)
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
            // Using AsyncImage to fetch the image from the URL
            AsyncImage(url: URL(string: image ?? "")) { phase in
                switch phase {
                case .empty:
                    // Placeholder image while the image is loading
                    Image("inviteimg")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .cornerRadius(6)
                case .success(let image):
                    // Loaded image
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .cornerRadius(6)
                case .failure:
                    // Fallback image if the network image loading fails
                    Image("inviteimg")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .cornerRadius(6)
                @unknown default:
                    // Default case
                    Image("inviteimg")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .cornerRadius(6)
                }
            }
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
            .frame(width: 32, height: 32)
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
    chatView( )
        .environment(
            \.managedObjectContext,
             PersistenceController.preview.container.viewContext
        )
}


