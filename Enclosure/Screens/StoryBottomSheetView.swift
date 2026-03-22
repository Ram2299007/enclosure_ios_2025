import SwiftUI

// MARK: - Story Bottom Sheet
struct StoryBottomSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var storySearchText = ""
    @State private var showPhotoPicker = false

    private var myProfileImageURL: String {
        UserDefaults.standard.string(forKey: Constant.profilePic) ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Stories")
                    .font(.custom("Inter18pt-Bold", size: 24))
                    .foregroundColor(Color("TextColor"))

                Spacer()

                Button {
                    // Search in stories
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(hex: Constant.themeColor))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // My Story Row
            HStack(spacing: 14) {
                // Profile picture with + badge — tappable
                ZStack(alignment: .bottomTrailing) {
                    CachedAsyncImage(url: URL(string: myProfileImageURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                    } placeholder: {
                        Image("inviteimg")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                    }
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .stroke(Color(hex: Constant.themeColor), lineWidth: 2)
                    )

                    // + badge
                    ZStack {
                        Circle()
                            .fill(Color(hex: Constant.themeColor))
                            .frame(width: 20, height: 20)
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .offset(x: 2, y: 2)
                }
                .onTapGesture {
                    showPhotoPicker = true
                }

                // Text — tappable
                VStack(alignment: .leading, spacing: 3) {
                    Text("My Story")
                        .font(.custom("Inter18pt-SemiBold", size: 16))
                        .foregroundColor(Color("TextColor"))

                    Text("Tap to add story")
                        .font(.custom("Inter18pt-Medium", size: 13))
                        .foregroundColor(Color("gray3"))
                }
                .onTapGesture {
                    showPhotoPicker = true
                }

                Spacer()

                // Settings gear icon
                Button {
                    // Story settings
                } label: {
                    Image("setting")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color(hex: Constant.themeColor).opacity(0.15))

            Spacer()
        }
        .background(Color("BackgroundColor"))
        .fullScreenCover(isPresented: $showPhotoPicker) {
            StoryPhotoPicker { assets, caption in
                // TODO: upload assets + caption to story backend
                print("Post story: \(assets.count) asset(s), caption: \(caption)")
            }
        }
    }
}
