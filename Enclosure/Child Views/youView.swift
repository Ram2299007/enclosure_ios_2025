//
//  youView.swift
//  Enclosure
//
//  Created by Ram Lohar on 30/04/25.
//

import Foundation
import SwiftUI
import SwiftUI


struct youView: View {
    @State private var dragOffset: CGSize = .zero
    @State private var isStretchedUp = false
    @State private var youView = false
    @Binding var isMainContentVisible: Bool
    @State private var isPressed = false
    @StateObject private var viewModel = YouViewModel()

    @State private var profile: GetProfileModel?




    var body: some View {

        ScrollView(.vertical) {
            VStack(spacing: 0) {


                if(youView){
                    Button(action: {
                        withAnimation {
                            isPressed = true
                            isStretchedUp = false
                            isMainContentVisible = true


                            withAnimation(.easeInOut(duration: 0.30)){
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    youView = false
                                    isPressed = false
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

                    .padding(.leading, 20)
                    .padding(.bottom,30)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                //TODO: From here main content start

                NavigationLink(destination: EditmyProfile()) {
                    HStack {
                        Image("plus")
                            .resizable()

                            .frame(width: 20, height: 20)
                            .padding(.leading, 2)


                        Text("for visible")
                            .font(.custom("Inter18pt-Medium", size: 16))
                            .foregroundColor(Color("TextColor"))
                            .fontWeight(.medium)
                            .lineSpacing(24) // Equivalent to lineHeight
                            .padding(.leading, 6)

                    }
                    .padding(.leading,16)
                    .foregroundColor(.black) // Set the text color
                    .cornerRadius(50) // For the ripple effect
                    .frame(maxWidth: .infinity, alignment: .leading)
                }


                //TODO: api work here

                HStack {
                    Spacer() // Align to the end (right side)

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

                            case .success(let image):
                                // Display the image once it's loaded successfully
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 107, height: 107)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                                    .padding(.trailing, 16)

                            case .failure(_):
                                // Show the fallback image in case of failure
                                Image("inviteimg")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 107, height: 107)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                                    .padding(.trailing, 16)

                            @unknown default:
                                // Fallback case
                                Image("inviteimg")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 107, height: 107)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                                    .padding(.trailing, 16)
                            }
                        }
                    }else{
                        Image("inviteimg")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 107, height: 107)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .padding(.trailing, 16)
                    }






                }
                .padding(.top, 15)




                HStack {
                    Spacer()
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(viewModel.listImages, id: \.id) { imageData in
                                AsyncImage(url: URL(string: imageData.photo)) { phase in
                                    switch phase {
                                    case .empty:
                                        Image("inviteimg")
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 60, height: 60)
                                            .clipShape(RoundedRectangle(cornerRadius: 5))

                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 60, height: 60)
                                            .clipShape(RoundedRectangle(cornerRadius: 5))

                                    case .failure(_):
                                        Image("inviteimg")
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 60, height: 60)
                                            .clipShape(RoundedRectangle(cornerRadius: 5))

                                    @unknown default:
                                        Image("inviteimg")
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 60, height: 60)
                                            .clipShape(RoundedRectangle(cornerRadius: 5))
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 15)
                    }.fixedSize()
                        .allowsHitTesting(false)



                }
                .padding(.top, 27)

                HStack(alignment: .center, spacing: 20) {
                    // Colored bar matches text block height
                    Rectangle()
                        .fill(Color("appThemeColrBackground"))
                        .frame(width: 4)



                    VStack(alignment: .leading, spacing: 3) {
                        Text(profile?.full_name ?? "Name")
                            .font(.custom("Inter18pt-SemiBold", size: 19))
                            .foregroundColor(Color("TextColor"))

                        Text(profile?.mobile_no ?? "Mobile Number")
                            .font(.custom("Inter18pt-Medium", size: 15))
                            .foregroundColor(Color("gray"))
                    }
                    Spacer()
                }.frame(width: .infinity,height: 45,alignment:.center)
                    .padding(.leading, 20)
                    .padding(.top, 50)
                    .padding(.bottom,50)


                VStack{
                    Text(profile?.caption ?? "First Begin to believe\nthen believe to begin")
                        .font(.custom("Inter18pt-Medium", size: 16))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .frame(width: 300)
                        .padding(.vertical, 20)

                }
                .frame(maxWidth: .infinity)
                .background( Color("appThemeColrBackground"))
                .padding(.bottom, 50)




            }
            .padding(.top,15)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear.contentShape(Rectangle())) // Make whole area touchable
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        withAnimation(.easeInOut(duration: 0.30)) {
                            if value.translation.height < -50 {
                                // Stretched upward
                                isStretchedUp = true
                                isMainContentVisible = false
                                // isTopHeaderVisible = true
                                print("Stretched upward!")
                                youView = true
                            } else if value.translation.height > 50 {
                                // Stretched downward
                                withAnimation {
                                    isPressed = true
                                    isStretchedUp = false
                                    isMainContentVisible = true
                                    withAnimation(.easeInOut(duration: 0.30)){
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            youView = false
                                            isPressed = false
                                        }
                                    }

                                }

                            }
                            dragOffset = .zero
                        }
                    }
            )
            .animation(.spring(), value: dragOffset)
        }.onAppear {

            viewModel.fetch_profile_YouFragment(uid: Constant.SenderIdMy)
            viewModel.fetch_user_profile_images_youFragment(uid: Constant.SenderIdMy)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { // Delay for API response
                if let fetchedProfile = viewModel.list.first {
                    profile = fetchedProfile
                    /// for set data default
                    UserDefaults.standard.set(profile?.photo , forKey: Constant.profilePic)
                    UserDefaults.standard.set(profile?.full_name, forKey: Constant.full_name)
                } else {
                    print("No profile data available or list is empty")
                }
            }
        }

    }

}


