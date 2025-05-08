import SwiftUI

struct EditmyProfile: View {

    @Environment(\.dismiss) var dismiss
    @State private var isPressed = false
    @State private var profile: GetProfileModel?
    @State private var name: String = ""
    @State private var caption: String = "First Begin to believe, then believe\nto begin, life goes on that way!"


    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Button(action: {
                        withAnimation {
                            isPressed = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            dismiss()
                        }
                    }) {
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

                    Text("for visible")
                        .font(.custom("Inter18pt-Medium", size: 16))
                        .foregroundColor(Color("TextColor"))
                        .fontWeight(.medium)
                        .lineSpacing(24) // Equivalent to lineHeight
                        .padding(.leading, 6)
                    Spacer()
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)


                HStack{
                    Spacer()
                    if let profile = profile {
                        AsyncImage(url: URL(string: profile.photo)) { phase in
                            switch phase {
                            case .empty:
                                // Display the "inviteimg" placeholder without an empty area
                                Image("inviteimg")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 107, height: 107)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                                    .padding(.trailing, 16)
                                    .padding(.top,16)

                            case .success(let image):
                                // Display the image once it's loaded successfully
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 107, height: 107)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                                    .padding(.trailing, 16)
                                    .padding(.top,16)

                            case .failure(_):
                                // Show the fallback image in case of failure
                                Image("inviteimg")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 107, height: 107)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                                    .padding(.trailing, 16)
                                    .padding(.top,16)

                            @unknown default:
                                // Fallback case
                                Image("inviteimg")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 107, height: 107)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                                    .padding(.trailing, 16)
                                    .padding(.top,16)
                            }
                        }
                    }else{
                        Image("inviteimg")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 107, height: 107)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .padding(.trailing, 16)
                            .padding(.top,16)
                    }
                }


                HStack(spacing: 30) {
                    // Delete Button
                    HStack(spacing: 10) {
                        Text("Delete")
                            .font(.custom("Inter18pt-Medium", size: 16))
                            .foregroundColor(Color.red)
                            .lineSpacing(4)

                        Image("minus") // Assumes you added "minus" asset in Assets.xcassets
                            .resizable()
                            .frame(width: 20, height: 20)
                    }
                    .padding(6)


                    // Add Button
                    HStack(spacing: 10) {
                        Text("Add")
                            .font(.custom("Inter18pt-Medium", size: 16))
                            .foregroundColor(Color("TextColor")) // Define in Assets if needed
                            .lineSpacing(4)

                        Image("plus")
                            .resizable()
                            .frame(width: 20, height: 20)
                    }
                    .padding(6)

                }
                .padding(.top, 20)
                .padding(.trailing, 20)
                .frame(maxWidth: .infinity, alignment: .trailing)


                HStack(alignment: .center, spacing: 10) {
                    Spacer()

                    MultiDemoView()

                    //                    ScrollView(.horizontal, showsIndicators: false) {
                    //                        HStack {
                    //                            // Add dynamic images/cards here
                    //                        }
                    //                    }

                    Button(action: {
                        // Action for plus button
                    }) {
                        Image("plus")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .padding()
                    }
                    .frame(width: 40, height: 40)
                }
                .padding(.top, 34)
                .padding(.trailing, 16)

                VStack(spacing: 34) {
                    // Name Label + Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.custom("Inter18pt-Medium", size: 12))
                            .foregroundColor(Color("gray"))

                        TextField("Enter your name", text: $name)
                            .padding(.horizontal, 13)
                            .frame(height: 49)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color("gray"))
                            )
                            .font(.custom("Inter18pt-Medium", size: 15))
                            .foregroundColor(Color("TextColor"))

                    }
                    .padding(.horizontal, 20)

                    // Caption Label + Input
                    VStack(alignment: .leading, spacing: 8) {
                            Text("Caption")
                                .font(.custom("Inter18pt-Medium", size: 12))
                                .foregroundColor(Color("gray"))

                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $caption)
                                    .frame(height: 100)
                                    .padding(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color("gray"))
                                    )
                                    .font(.custom("Inter18pt-Medium", size: 15))
                                    .lineSpacing(6)
                                    .foregroundColor(Color("TextColor"))
                                    .onChange(of: caption) { newValue in
                                        if caption.count > 300 {
                                            caption = String(caption.prefix(300))
                                        }
                                    }

                                // Optional: Character count label
                                Text("\(caption.count)/300")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding([.top, .trailing], 12)
                                    .frame(
                                        maxWidth: .infinity,
                                        alignment: .bottomTrailing
                                    )
                            }
                        }
                        .padding(.horizontal, 20)



                    Button(action: {

                    }) {
                        Image("tick_new_dvg")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 52, height: 52)
                            .foregroundColor(Color("TextColor"))
                            .padding()

                    }
                    .frame(width: 52, height: 52)
                    .buttonStyle(CircularRippleStyle())
                }
                .padding(.top, 34)
                .padding(.bottom, 10)




                Spacer()
            }



        }
        .navigationBarHidden(true)
    }
}
struct MultiDemoView: View {
    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<4) { index in
                ProfileCardView()
            }
        }
    }
}

struct ProfileCardView: View {
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 5) {
            Image("inviteimg") // Add inviteimg to Assets
                .resizable()
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .onTapGesture {
            showDeleteConfirmation.toggle()
        }
    }
}


struct CircularRippleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                GeometryReader { geometry in
                    ZStack {
                        if configuration.isPressed {
                            Circle()
                                .fill(Color("circlebtnhover").opacity(0.3))
                                .frame(
                                    width: geometry.size.width,
                                    height: geometry.size.height
                                )
                                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        }
                    }
                }
            )
            .clipShape(Circle()) // Ensures the button remains circular
            .scaleEffect(configuration.isPressed ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}



#Preview {
    EditmyProfile()
        .environment(
            \.managedObjectContext,
             PersistenceController.preview.container.viewContext
        )
}
