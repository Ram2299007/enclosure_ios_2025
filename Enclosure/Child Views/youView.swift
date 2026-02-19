//
//  youView.swift
//  Enclosure
//
//  Created by Ram Lohar on 30/04/25.
//

import Foundation
import SwiftUI
import PopGestureRecognizerSwiftUI


struct youView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var dragOffset: CGSize = .zero
    @State private var isStretchedUp = false
    @State private var youView = false
    @Binding var isMainContentVisible: Bool
    @Binding var isTopHeaderVisible: Bool
    @State private var isPressed = false
    @StateObject private var viewModel = YouViewModel()

    @State private var profile: GetProfileModel?
    @State private var themeColorHex: String = Constant.themeColor
    @State private var mainvectorTintColor: Color = Color(hex: "#01253B") // Dynamic background tint color (darker theme color)
    
    // Computed property for background tint: appThemeColor in light mode, darker tint in dark mode
    private var backgroundTintColor: Color {
        if colorScheme == .light {
            return Color("appThemeColor") // Use appThemeColor in light mode
        } else {
            return mainvectorTintColor // Use darker tint in dark mode
        }
    }




    var body: some View {

        ScrollView(.vertical) {
            VStack(spacing: 0) {


                if youView {
                    HStack(spacing: 0) {
                    Button(action: handleBackArrowTap) {
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
                    .buttonStyle(.plain)

                        Spacer()
                    }
                    .padding(.leading, 20)
                    .padding(.trailing, 10)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
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
                    ThemeBorderProfileImage(imageURL: profile?.photo, themeColorHex: themeColorHex)
                        .padding(.trailing, 16)
                }
                .padding(.top, 15)




                HStack {
                    Spacer()
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(viewModel.listImages, id: \.id) { imageData in
                                ThemeBorderStatusImage(imageURL: imageData.photo)
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
                        .fill(Color(hex: Constant.themeColor)) // Use original theme color in both light and dark mode
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
                .background(backgroundTintColor) // Use appThemeColor in light mode, darker tint in dark mode
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
                        if value.translation.height < -50 {
                            withAnimation(.easeInOut(duration: 0.45)) {
                                // Stretched upward
                                isStretchedUp = true
                                isMainContentVisible = false
                                print("Stretched upward!")
                                youView = true
                                isTopHeaderVisible = true
                            }
                        } else if value.translation.height > 50 {
                            handleSwipeDown()
                        }
                        dragOffset = .zero
                    }
            )
            .animation(.spring(), value: dragOffset)
        }
        // Ensure native back-swipe stays enabled for pushes from this screen
        .background(NavigationGestureEnabler())
        .onAppear {
            isTopHeaderVisible = false
            mainvectorTintColor = getMainvectorTintColor(for: themeColorHex) // Initialize tint color
            viewModel.fetch_profile_YouFragment(uid: Constant.SenderIdMy)
            viewModel.fetch_user_profile_images_youFragment(uid: Constant.SenderIdMy)
            applyProfileData(from: viewModel.list.first)
        }
        .onChange(of: viewModel.list) { newList in
            applyProfileData(from: newList.first)
        }

    }

}

extension youView {
    private func handleBackArrowTap() {
        withAnimation {
            isPressed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPressed = false
            handleSwipeDown()
        }
    }
    
    private func handleSwipeDown() {
        withAnimation(.easeInOut(duration: 0.45)) {
            isPressed = true
            isStretchedUp = false
            isMainContentVisible = true
            isTopHeaderVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.45)) {
                youView = false
                isPressed = false
            }
        }
    }

    private func applyProfileData(from newProfile: GetProfileModel?) {
        guard let newProfile = newProfile else { return }
        profile = newProfile
        UserDefaults.standard.set(newProfile.photo, forKey: Constant.profilePic)
        UserDefaults.standard.set(newProfile.full_name, forKey: Constant.full_name)
        // Only save device_type when it matches get_user_active_chat_list format ("1" or "2"), not UUID
        if !newProfile.device_type.isEmpty, (newProfile.device_type == "1" || newProfile.device_type == "2") {
            UserDefaults.standard.set(newProfile.device_type, forKey: Constant.DEVICE_TYPE_KEY)
        }
        if let newThemeColor = newProfile.themeColor, !newThemeColor.isEmpty {
            themeColorHex = newThemeColor
            UserDefaults.standard.set(newThemeColor, forKey: Constant.ThemeColorKey)
            mainvectorTintColor = getMainvectorTintColor(for: newThemeColor) // Update background tint color
        }
    }
    
    private func getMainvectorTintColor(for themeColor: String) -> Color {
        // Use case-insensitive comparison to handle mixed case theme colors
        let colorKey = themeColor.lowercased()
        switch colorKey {
        case "#ff0080":
            return Color(hex: "#4D0026")
        case "#00a3e9":
            return Color(hex: "#01253B")
        case "#7adf2a":
            return Color(hex: "#25430D")
        case "#ec0001":
            return Color(hex: "#470000")
        case "#16f3ff":
            return Color(hex: "#05495D")
        case "#ff8a00":
            return Color(hex: "#663700")
        case "#7f7f7f":
            return Color(hex: "#2B3137")
        case "#d9b845":
            return Color(hex: "#413815")
        case "#346667":
            return Color(hex: "#1F3D3E")
        case "#9846d9":
            return Color(hex: "#2d1541")
        case "#a81010":
            return Color(hex: "#430706")
        default:
            return Color(hex: "#01253B")
        }
    }
}


struct ThemeBorderProfileImage: View {
    var imageURL: String?
    var themeColorHex: String
    
    private let imageSize: CGFloat = 107
    private let borderPadding: CGFloat = 4.0
    
    private var borderColor: Color {
        Color(hex: themeColorHex.isEmpty ? Constant.themeColor : themeColorHex)
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(borderColor, lineWidth: 1.5)
                .frame(width: imageSize + borderPadding * 2, height: imageSize + borderPadding * 2)
                .overlay(
                    Circle()
                        .fill(Color("BackgroundColor"))
                        .frame(width: imageSize + borderPadding * 2, height: imageSize + borderPadding * 2)
                )
            
            CachedAsyncImage(url: URL(string: imageURL ?? "")) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: imageSize, height: imageSize)
                    .clipShape(Circle())
            } placeholder: {
                placeholder
            }
            .frame(width: imageSize, height: imageSize)
        }
        .frame(width: imageSize + borderPadding * 2, height: imageSize + borderPadding * 2)
    }
    
    private var placeholder: some View {
        Image("inviteimg")
            .resizable()
            .scaledToFill()
            .frame(width: imageSize, height: imageSize)
            .clipShape(Circle())
    }
}

struct ThemeBorderStatusImage: View {
    var imageURL: String?
    
    private let imageSize: CGFloat = 60
    private let borderWidth: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color("gray"), lineWidth: borderWidth)
                .frame(width: imageSize + borderWidth * 2, height: imageSize + borderWidth * 2)
            
            CachedAsyncImage(url: URL(string: imageURL ?? "")) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: imageSize, height: imageSize)
                    .clipShape(Circle())
            } placeholder: {
                placeholder
            }
            .frame(width: imageSize, height: imageSize)
        }
        .frame(width: imageSize + borderWidth * 2, height: imageSize + borderWidth * 2)
    }
    
    private var placeholder: some View {
        Image("inviteimg")
            .resizable()
            .scaledToFill()
            .frame(width: imageSize, height: imageSize)
            .clipShape(Circle())
    }
}


