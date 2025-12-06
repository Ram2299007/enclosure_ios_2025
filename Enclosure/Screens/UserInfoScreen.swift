//
//  UserInfoScreen.swift
//  Enclosure
//
//  Created by Ram Lohar on 30/04/25.
//

import SwiftUI

struct UserInfoScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    let recUserId: String
    let recUserName: String
    
    @State private var isPressed: Bool = false
    @State private var profile: GetProfileModel?
    @State private var profileImages: [GetUserProfileImagesModel] = []
    @State private var themeColorHex: String = Constant.themeColor
    @State private var mainvectorTintColor: Color = Color(hex: "#01253B")
    
    @StateObject private var viewModel = EditProfileViewModel()
    
    // Computed property for background tint: appThemeColor in light mode, darker tint in dark mode
    private var backgroundTintColor: Color {
        if colorScheme == .light {
            return Color("appThemeColor")
        } else {
            return mainvectorTintColor
        }
    }
    
    var body: some View {
        ZStack {
            // Background color
            Color("BackgroundColor")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Content
                ScrollView {
                    VStack(spacing: 0) {
                        // Profile section
                        profileSection
                        
                        // Name and phone section
                        namePhoneSection
                        
                        // Caption section
                        captionSection
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            print("UserInfoScreen: onAppear - recUserId: \(recUserId), recUserName: \(recUserName)")
            mainvectorTintColor = getMainvectorTintColor(for: themeColorHex)
            loadProfileData()
        }
        .onChange(of: viewModel.list) { newList in
            print("UserInfoScreen: viewModel.list changed, count: \(newList.count)")
            if let firstProfile = newList.first {
                applyProfileData(from: firstProfile)
            }
        }
        .onChange(of: viewModel.listImages) { newImages in
            print("UserInfoScreen: viewModel.listImages changed, count: \(newImages.count)")
            profileImages = newImages
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Back button
                Button(action: handleBackTap) {
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
                .padding(.leading, 20)
                .padding(.trailing, 5)
                
                // Name text
                Text(recUserName)
                    .font(.custom("Inter18pt-Medium", size: 16))
                    .foregroundColor(Color("TextColor"))
                    .fontWeight(.medium)
                    .lineSpacing(24)
                    .padding(.leading, 15)
                
                Spacer()
            }
            .padding(.top, 10)
            .frame(height: 50)
        }
        .background(Color("edittextBg"))
    }
    
    // MARK: - Profile Section
    private var profileSection: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                // Profile image with theme border
                // Show placeholder if profile is nil, otherwise show actual image
                if profile != nil {
                    ThemeBorderProfileImage(
                        imageURL: profile?.photo,
                        themeColorHex: themeColorHex
                    )
                    .padding(.trailing, 16)
                } else {
                    // Show placeholder while loading
                    ThemeBorderProfileImage(
                        imageURL: nil,
                        themeColorHex: themeColorHex
                    )
                    .padding(.trailing, 16)
                }
            }
            .padding(.top, 15)
            
            // Status images RecyclerView
            HStack {
                Spacer()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach(profileImages.reversed(), id: \.id) { imageData in
                            ThemeBorderStatusImage(imageURL: imageData.photo)
                        }
                    }
                    .padding(.horizontal, 15)
                }
                .fixedSize()
                .allowsHitTesting(false)
            }
            .padding(.top, 27)
        }
    }
    
    // MARK: - Name and Phone Section
    private var namePhoneSection: some View {
        HStack(alignment: .center, spacing: 20) {
            // Colored bar - 4dp width, use profile's theme color
            Rectangle()
                .fill(Color(hex: themeColorHex))
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 3) {
                // Name
                Text(profile?.full_name ?? "Name")
                    .font(.custom("Inter18pt-SemiBold", size: 19))
                    .foregroundColor(Color("TextColor"))
                
                // Phone
                Text(profile?.mobile_no ?? "Mobile Number")
                    .font(.custom("Inter18pt-Medium", size: 15))
                    .foregroundColor(Color("gray"))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 20)
        .padding(.top, 50)
        .padding(.bottom, 50)
    }
    
    // MARK: - Caption Section
    private var captionSection: some View {
        VStack {
            Text(profile?.caption ?? "First Begin to believe\nthen believe to begin")
                .font(.custom("Inter18pt-Medium", size: 16))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .frame(width: 300)
                .padding(.vertical, 20)
        }
        .frame(maxWidth: .infinity)
        .background(backgroundTintColor)
        .padding(.bottom, 50)
    }
    
    // MARK: - Helper Functions
    private func handleBackTap() {
        withAnimation {
            isPressed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            dismiss()
            isPressed = false
        }
    }
    
    private func loadProfileData() {
        // Load profile
        viewModel.fetch_profile_EditProfile(uid: recUserId)
        
        // Load profile images
        viewModel.fetch_user_profile_images_EditProfile(uid: recUserId)
    }
    
    private func applyProfileData(from newProfile: GetProfileModel?) {
        guard let newProfile = newProfile else {
            print("UserInfoScreen: No profile data received")
            return
        }
        print("UserInfoScreen: Profile loaded - \(newProfile.full_name), Photo: \(newProfile.photo)")
        profile = newProfile
        if let newThemeColor = newProfile.themeColor, !newThemeColor.isEmpty {
            themeColorHex = newThemeColor
            mainvectorTintColor = getMainvectorTintColor(for: newThemeColor)
        } else {
            // Use default theme color if not provided
            themeColorHex = Constant.themeColor
            mainvectorTintColor = getMainvectorTintColor(for: Constant.themeColor)
        }
    }
    
    private func getMainvectorTintColor(for themeColor: String) -> Color {
        let colorKey = themeColor.lowercased()
        switch colorKey {
        case "#ff0080": return Color(hex: "#4D0026")
        case "#00a3e9": return Color(hex: "#01253B")
        case "#7adf2a": return Color(hex: "#25430D")
        case "#ec0001": return Color(hex: "#470000")
        case "#16f3ff": return Color(hex: "#05495D")
        case "#ff8a00": return Color(hex: "#663700")
        case "#7f7f7f": return Color(hex: "#2B3137")
        case "#d9b845": return Color(hex: "#413815")
        case "#346667": return Color(hex: "#1F3D3E")
        case "#9846d9": return Color(hex: "#2d1541")
        case "#a81010": return Color(hex: "#430706")
        default: return Color(hex: "#01253B")
        }
    }
}

#Preview {
    UserInfoScreen(
        recUserId: "123",
        recUserName: "John Doe"
    )
}

