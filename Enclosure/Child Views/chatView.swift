import Foundation
import SwiftUI

struct chatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var tappedIndex: Int? = nil

    var body: some View {
        VStack {
            // Show loading indicator while fetching data
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }else

            if let errorMessage = viewModel.errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
            }
            // Show chat list if data is fetched successfully
            else {
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

                VStack(alignment: .leading) {
                    // Name and Time
                    HStack {
                        Text(chat.fullName)
                            .font(.custom("Inter18pt-SemiBold", size: 16))
                            .foregroundColor(Color("TextColor"))
                        Spacer()
                        Text(chat.sentTime)
                            .font(.custom("Inter18pt-Medium", size: 12))
                            .foregroundColor(Color("Gray3"))
                            .padding(.trailing,8)
                    }



                    HStack{
                        // Caption
                        Text(chat.message.isEmpty ? chat.caption : chat.message)
                            .font(.custom("Inter18pt-Medium", size: 13))
                            .foregroundColor(Color("Gray3"))
                            .lineLimit(1)

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

}


#Preview {
    chatView( )
        .environment(
            \.managedObjectContext,
             PersistenceController.preview.container.viewContext
        )
}


