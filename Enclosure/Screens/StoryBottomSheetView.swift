import SwiftUI

// MARK: - Story Bottom Sheet
struct StoryBottomSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var storySearchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Story")
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

            Divider()

            // My Story Row
            HStack(spacing: 14) {
                // Profile picture with + badge
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle()
                                .stroke(Color(hex: Constant.themeColor), lineWidth: 2)
                        )
                        .overlay(
                            Text("...")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color("TextColor"))
                        )

                    // + badge
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 22, height: 22)
                        Circle()
                            .fill(Color(hex: Constant.themeColor))
                            .frame(width: 18, height: 18)
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .offset(x: 2, y: 2)
                }

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    Text("My Story")
                        .font(.custom("Inter18pt-SemiBold", size: 16))
                        .foregroundColor(Color(hex: Constant.themeColor))

                    Text("Tap to add story")
                        .font(.custom("Inter18pt-Regular", size: 13))
                        .foregroundColor(Color("TextColor").opacity(0.6))
                }

                Spacer()

                // Settings gear icon
                Button {
                    // Story settings
                } label: {
                    Image("setting")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundColor(Color(hex: Constant.themeColor))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(hex: Constant.themeColor).opacity(0.15))

            Spacer()
        }
        .background(Color("BackgroundColor"))
    }
}
