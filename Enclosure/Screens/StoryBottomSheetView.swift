import SwiftUI

// MARK: - Story Bottom Sheet
struct StoryBottomSheetView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var uploadManager = StoryUploadManager.shared
    @State private var showPhotoPicker = false
    @State private var now = Date()
    @State private var isExpanded = true   // collapse / expand the cards section

    private var myProfileImageURL: String {
        UserDefaults.standard.string(forKey: Constant.profilePic) ?? ""
    }

    private var hasStories: Bool {
        !uploadManager.myStories.isEmpty || uploadManager.isUploading
    }

    private var subtitleText: String {
        if uploadManager.isUploading {
            let pct = Int(uploadManager.progress * 100)
            return pct > 0 ? "Posting stories... \(pct)%" : "Posting stories..."
        }
        if let posted = uploadManager.lastPostedAt {
            let diff = now.timeIntervalSince(posted)
            if diff < 60    { return "just now" }
            if diff < 3600  { return "\(Int(diff / 60))m ago" }
            if diff < 86400 { return "\(Int(diff / 3600))h ago" }
            return "\(Int(diff / 86400))d ago"
        }
        return "Tap to add story"
    }

    private var subtitleColor: Color {
        (uploadManager.isUploading || uploadManager.lastPostedAt != nil)
            ? Color(hex: Constant.themeColor) : Color("gray3")
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Top header ──────────────────────────────────────────────
            HStack {
                Text("Stories")
                    .font(.custom("Inter18pt-Bold", size: 24))
                    .foregroundColor(Color("TextColor"))
                Spacer()
                Button { } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(hex: Constant.themeColor))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // ── My Stories row (tap to expand / collapse when stories exist) ──
            HStack(spacing: 14) {
                // Profile picture — + badge only when no stories
                ZStack(alignment: .bottomTrailing) {
                    profileImage(size: 56)
                        .overlay(Circle().stroke(Color(hex: Constant.themeColor), lineWidth: 2))
                    if !hasStories {
                        plusBadge
                    }
                }
                .onTapGesture {
                    if hasStories {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            isExpanded.toggle()
                        }
                    } else {
                        showPhotoPicker = true
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("My Stories")
                        .font(.custom("Inter18pt-SemiBold", size: 16))
                        .foregroundColor(Color(hex: Constant.themeColor))
                    Text(subtitleText)
                        .font(.custom("Inter18pt-Medium", size: 13))
                        .foregroundColor(subtitleColor)
                        .animation(.easeInOut(duration: 0.2), value: subtitleText)
                }

                Spacer()

                // Chevron — only shown when stories exist
                if hasStories {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: Constant.themeColor))
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
                        .padding(.trailing, 4)
                }

                Button { } label: {
                    Image("setting")
                        .renderingMode(.template)
                        .resizable().scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color(hex: Constant.themeColor).opacity(0.15))
            .contentShape(Rectangle())
            .onTapGesture {
                if hasStories {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        isExpanded.toggle()
                    }
                } else {
                    showPhotoPicker = true
                }
            }

            // ── Story cards (expandable) ────────────────────────────────
            if hasStories {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        // Add-more button at the far left — matches story card size
                        Button { showPhotoPicker = true } label: {
                            ZStack {
                                // Profile pic fills the card
                                CachedAsyncImage(url: URL(string: myProfileImageURL)) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Image("inviteimg").resizable().scaledToFill()
                                }
                                .frame(width: 110, height: 170)
                                .clipped()

                                // Dark overlay so the + icon reads clearly
                                Color.black.opacity(0.35)

                                // Plus icon centered
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: Constant.themeColor))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(width: 110, height: 170)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: Constant.themeColor), lineWidth: 1.5))
                        }
                        .buttonStyle(BorderlessButtonStyle())

                        // One card per story (each asset was uploaded separately)
                        ForEach(uploadManager.myStories) { story in
                            storyCard(story)
                        }

                        // Uploading placeholder card
                        if uploadManager.isUploading {
                            uploadingCard
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .background(Color(hex: Constant.themeColor).opacity(0.07))
                .frame(height: isExpanded ? nil : 0, alignment: .top)
                .clipped()
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
            }

            Spacer()
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    if isExpanded && hasStories {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            isExpanded = false
                        }
                    }
                }
        }
        .background(Color("BackgroundColor"))
        .onAppear { uploadManager.fetchMyStories() }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
            now = date
        }
        .fullScreenCover(isPresented: $showPhotoPicker) {
            StoryPhotoPicker(
                onPost: { assets, caption in
                    uploadManager.uploadMedia(assets: assets, caption: caption)
                },
                onTextPost: { text, bgType, bgColor, gradStart, gradEnd in
                    uploadManager.uploadText(textContent: text, bgType: bgType,
                                             bgColor: bgColor, gradStart: gradStart,
                                             gradEnd: gradEnd)
                }
            )
        }
    }

    // MARK: - Shared helpers

    @ViewBuilder
    private func profileImage(size: CGFloat) -> some View {
        CachedAsyncImage(url: URL(string: myProfileImageURL)) { image in
            image.resizable().scaledToFill()
                .frame(width: size, height: size).clipShape(Circle())
        } placeholder: {
            Image("inviteimg").resizable().scaledToFill()
                .frame(width: size, height: size).clipShape(Circle())
        }
        .frame(width: size, height: size)
    }

    private var plusBadge: some View {
        ZStack {
            Circle().fill(Color(hex: Constant.themeColor)).frame(width: 20, height: 20)
            Image(systemName: "plus").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
        }
        .offset(x: 2, y: 2)
    }

    // MARK: - Story card

    @ViewBuilder
    private func storyCard(_ story: UserStory) -> some View {
        ZStack {
            // Background — thumbnail for media, colour/gradient for text
            Group {
                if story.storyType == "media", let url = story.firstThumbnailURL {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color(hex: Constant.themeColor).opacity(0.25)
                    }
                } else if story.storyType == "media" {
                    // Video with no thumbnail yet — dark placeholder
                    Color.black
                } else {
                    textStoryBackground(story)
                }
            }
            .frame(width: 110, height: 170)
            .clipped()

            // Play icon overlay for video stories
            if story.storyType == "media",
               story.mediaItems.first?.mediaType == "video" {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 36, height: 36)
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: 1)
                }
            }

            // Delete button — top trailing
            VStack {
                HStack {
                    Spacer()
                    Button { uploadManager.deleteStory(id: story.id) } label: {
                        ZStack {
                            Circle().fill(Color.black.opacity(0.45)).frame(width: 26, height: 26)
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(6)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                Spacer()
            }

            // Text preview for text stories
            if story.storyType == "text", !story.textContent.isEmpty {
                Text(story.textContent)
                    .font(.custom("Inter18pt-SemiBold", size: 11))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .padding(.horizontal, 6)
                    .shadow(color: .black.opacity(0.6), radius: 2)
            }
        }
        .frame(width: 110, height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: Constant.themeColor), lineWidth: 1.5))
    }

    @ViewBuilder
    private func textStoryBackground(_ story: UserStory) -> some View {
        if story.bgType == "gradient",
           !story.gradientStart.isEmpty, !story.gradientEnd.isEmpty {
            LinearGradient(
                colors: [Color(hex: story.gradientStart), Color(hex: story.gradientEnd)],
                startPoint: .top, endPoint: .bottom
            )
        } else {
            Color(hex: story.bgColor.isEmpty ? "#1a1a1a" : story.bgColor)
        }
    }

    // MARK: - Uploading placeholder card

    private var uploadingCard: some View {
        ZStack {
            Color(hex: Constant.themeColor).opacity(0.15)
            VStack(spacing: 8) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: Constant.themeColor)))
                    .scaleEffect(1.2)
                if uploadManager.progress > 0 {
                    Text("\(Int(uploadManager.progress * 100))%")
                        .font(.custom("Inter18pt-Medium", size: 12))
                        .foregroundColor(Color(hex: Constant.themeColor))
                }
            }
        }
        .frame(width: 110, height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: Constant.themeColor), lineWidth: 1.5))
    }
}
