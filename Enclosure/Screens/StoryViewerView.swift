import SwiftUI
import AVKit

// MARK: - StoryViewerView
// WhatsApp-style full-screen story viewer with horizontal progress bars,
// tap left/right navigation, long-press pause, auto-advance, and bottom reply bar.
struct StoryViewerView: View {

    let stories: [UserStory]
    let ownerUid: String
    let ownerName: String
    let ownerPhotoURL: URL?
    var isOwnStory: Bool = false

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = StoryUploadManager.shared
    @State private var currentIndex: Int
    @State private var elapsed: Double = 0
    @State private var isPaused = false
    @State private var replyText = ""
    @FocusState private var isReplyFocused: Bool
    @State private var player: AVPlayer? = nil
    @State private var videoDuration: Double = 0
    @State private var now = Date()
    @State private var showViewersSheet = false
    @State private var showRepliesSheet = false
    @State private var showHideAlert = false
    @State private var isOwnerHidden = false
    @State private var isLiked = false
    @State private var likesCount: Int = 0
    @State private var keyboardHeight: CGFloat = 0
    @State private var navigateToProfile = false
    // Tracks which story IDs have already been marked seen this session
    @State private var seenStoryIds: Set<String> = []

    private let tickInterval: Double = 1.0 / 60.0
    // Mark as seen after this many seconds of actual (unpaused) viewing
    private let seenThreshold: Double = 1.0
    private let imageDuration: Double = 5.0

    private var safeAreaTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.safeAreaInsets.top ?? 50
    }

    init(stories: [UserStory], ownerUid: String = "", ownerName: String, ownerPhotoURL: URL?,
         isOwnStory: Bool = false, startIndex: Int = 0) {
        self.stories = stories
        self.ownerUid = ownerUid
        self.ownerName = ownerName
        self.ownerPhotoURL = ownerPhotoURL
        self.isOwnStory = isOwnStory
        _currentIndex = State(
            initialValue: stories.isEmpty ? 0 : max(0, min(startIndex, stories.count - 1))
        )
    }

    private var currentStory: UserStory? {
        guard !stories.isEmpty, currentIndex < stories.count else { return nil }
        return stories[currentIndex]
    }

    private var currentDuration: Double {
        videoDuration > 0 ? videoDuration : imageDuration
    }

    private var segmentProgress: Double {
        min(elapsed / max(currentDuration, 0.001), 1.0)
    }

    var body: some View {
        NavigationStack {
        ZStack {
            Color.black.ignoresSafeArea()

            // Hidden navigation to profile
            NavigationLink(
                destination: UserInfoScreen(recUserId: ownerUid, recUserName: ownerName),
                isActive: $navigateToProfile
            ) { EmptyView() }
                .hidden()

            // ── Story content (non-interactive, taps handled by zones below) ──
            if let story = currentStory {
                storyContent(story)
                    .id(currentIndex)   // force view + ImageLoader recreation on story change
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // ── Left / right tap navigation zones ──
            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { goToPrevious() }
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { goToNext() }
            }
            .ignoresSafeArea()
            .onLongPressGesture(minimumDuration: 0.2, pressing: { pressing in
                isPaused = pressing
                if pressing { player?.pause() } else { player?.play() }
            }, perform: {})

            // ── Caption overlay (interactive — must be outside allowsHitTesting(false)) ──
            if let story = currentStory,
               story.storyType == "media",
               !story.caption.isEmpty {
                VStack {
                    Spacer()
                    StoryCaptionOverlay(caption: story.caption, isOwnStory: isOwnStory)
                        .id(currentIndex)   // reset expand state on story change
                        .padding(.bottom, isOwnStory ? 130 : 100)
                }
                .ignoresSafeArea()
                .allowsHitTesting(true)
            }

            // ── Header + reply bar overlay ──
            VStack(spacing: 0) {
                // Progress bars + user info
                VStack(spacing: 12) {
                    HStack(spacing: 3) {
                        ForEach(0..<stories.count, id: \.self) { i in
                            progressSegment(index: i)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, safeAreaTop + 8)   // below Dynamic Island / status bar

                    HStack(spacing: 10) {
                        // Back button — simple, no background
                        Button { dismiss() } label: {
                            Image("leftvector")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 22, height: 16)
                                .foregroundColor(.white)
                                .padding(8)
                        }
                        .buttonStyle(.plain)

                        // Avatar — tap to view profile
                        Button {
                            isPaused = true
                            player?.pause()
                            navigateToProfile = true
                        } label: {
                            CachedAsyncImage(url: ownerPhotoURL) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Image("inviteimg").resizable().scaledToFill()
                            }
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(ownerName)
                                .font(.custom("Inter18pt-SemiBold", size: 14))
                                .foregroundColor(.white)
                            if let date = currentStory?.createdDate {
                                Text(relativeTime(from: date))
                                    .font(.custom("Inter18pt-Regular", size: 11))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }

                        Spacer()

                        // 3-dot menu — same style as MainActivityOld
                        Menu {
                            Button("For Visible") { navigateToProfile = true }
                            if isOwnStory {
                                Button("Delete Story", role: .destructive) {
                                    if let story = currentStory {
                                        StoryUploadManager.shared.deleteStory(id: story.id)
                                        dismiss()
                                    }
                                }
                            } else if isOwnerHidden {
                                Button("Unhide \(ownerName)") {
                                    var uids = Set(UserDefaults.standard.stringArray(forKey: "hiddenStoryUids") ?? [])
                                    uids.remove(ownerUid)
                                    UserDefaults.standard.set(Array(uids), forKey: "hiddenStoryUids")
                                    isOwnerHidden = false
                                }
                            } else {
                                Button("Hide \(ownerName)", role: .destructive) {
                                    showHideAlert = true
                                }
                            }
                        } label: {
                            VStack(spacing: 3) {
                                Circle()
                                    .fill(Color("menuPointColor"))
                                    .frame(width: 4, height: 4)
                                Circle()
                                    .fill(Color(hex: Constant.themeColor))
                                    .frame(width: 4, height: 4)
                                Circle()
                                    .fill(Color(red: 0x9E/255, green: 0xA6/255, blue: 0xB9/255))
                                    .frame(width: 4, height: 4)
                            }
                            .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)
                }
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0.7), Color.clear],
                        startPoint: .top, endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )

                Spacer()

                // Reply bar (only for other people's stories)
                if !isOwnStory {
                    replyBar
                } else {
                    // Own stories: just a bottom gradient + "My Stories ↑" pill
                    ownStoriesFooter
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { val in
                    if val.translation.height > 80 { dismiss() }
                }
        )
        .onAppear {
            loadStory(at: currentIndex)
            loadLikeStatus()
            if isOwnStory { manager.fetchMyStories() }
            isOwnerHidden = Set(UserDefaults.standard.stringArray(forKey: "hiddenStoryUids") ?? []).contains(ownerUid)
        }
        .onChange(of: currentIndex) { _ in
            loadLikeStatus()
        }
        .onDisappear { player?.pause(); player = nil }
        .onReceive(Timer.publish(every: tickInterval, on: .main, in: .common).autoconnect()) { _ in
            tickProgress()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
            now = date
        }
        .sheet(isPresented: $showViewersSheet) {
            if let story = currentStory {
                StoryViewersSheet(storyId: story.id, viewsCount: story.viewsCount)
            }
        }
        .sheet(isPresented: $showRepliesSheet) {
            if let story = currentStory {
                StoryViewersSheet(storyId: story.id, viewsCount: story.viewsCount, initialTab: 1, repliesOnly: true)
            }
        }
        .onChange(of: showRepliesSheet) { open in
            if !open { isPaused = false; player?.play() }
        }
        .alert("Hide \(ownerName)'s status updates?", isPresented: $showHideAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Hide", role: .destructive) {
                var uids = Set(UserDefaults.standard.stringArray(forKey: "hiddenStoryUids") ?? [])
                uids.insert(ownerUid)
                UserDefaults.standard.set(Array(uids), forKey: "hiddenStoryUids")
                isOwnerHidden = true
                dismiss()
            }
        } message: {
            Text("You won't be notified of mentions from this contact. Their new status updates also won't appear at the top of the status list anymore.")
        }
        .ignoresSafeArea()
        } // end NavigationStack
    }

    // MARK: - Progress bar segment

    @ViewBuilder
    private func progressSegment(index: Int) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .frame(height: 2.5)
                Capsule()
                    .fill(Color.white)
                    .frame(
                        width: index < currentIndex
                            ? geo.size.width
                            : index == currentIndex
                                ? geo.size.width * segmentProgress
                                : 0,
                        height: 2.5
                    )
            }
        }
        .frame(height: 2.5)
    }

    // MARK: - Story content

    private func storyFontSizeMultiplier(_ text: String) -> CGFloat {
        let lines = max(text.components(separatedBy: "\n").count, max(0, text.count / 24))
        switch lines {
        case 0...4:  return 1.00
        case 5...7:  return 0.78
        case 8...10: return 0.62
        default:     return 0.50
        }
    }

    @ViewBuilder
    private func storyContent(_ story: UserStory) -> some View {
        if story.storyType == "text" {
            ZStack {
                textBackground(story).ignoresSafeArea()
                if story.bgType == "gradient" {
                    NightWindParticlesView().ignoresSafeArea()
                }
                // Recover font index:
                // - gradient: font index encoded as suffix on gradient_end ("#HEX:N")
                //             — falls back to bg_color integer or story.fontIndex
                // - solid:    bg_color is "#RRGGBB:N"
                let rawFontIndex: Int = {
                    if story.bgType == "gradient" {
                        let parts = story.gradientEnd.split(separator: ":", maxSplits: 1)
                        if parts.count == 2, let n = Int(parts[1]) { return n }
                        return Int(story.bgColor) ?? story.fontIndex
                    } else {
                        let parts = story.bgColor.split(separator: ":", maxSplits: 1)
                        return parts.count == 2 ? (Int(parts[1]) ?? story.fontIndex) : story.fontIndex
                    }
                }()
                let fontIndex = max(0, min(rawFontIndex, storyRoyalFonts.count - 1))
                let scale = storyFontSizeMultiplier(story.textContent)
                // Amber solid (#FFC107) needs dark text; parse hex from bg_color
                let solidHex = story.bgColor.split(separator: ":").first.map(String.init) ?? story.bgColor
                let isLight = story.bgType == "solid" && solidHex.lowercased() == "#ffc107"
                Text(story.textContent)
                    .font(storyRoyalFonts[fontIndex].typingFont(scale: scale))
                    .foregroundColor(isLight ? .black : .white)
                    .multilineTextAlignment(.center)
                    .padding(40)
                    .shadow(color: .black.opacity(0.4), radius: 4)
            }
        } else if let item = story.mediaItems.first {
            if item.mediaType == "video" {
                if let p = player {
                    StoryVideoPlayerView(player: p)
                        .ignoresSafeArea()
                } else {
                    ZStack {
                        Color.black
                        if let thumb = story.firstThumbnailURL {
                            CachedAsyncImage(url: thumb) { img in
                                img.resizable().scaledToFit()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } placeholder: {
                                ProgressView().tint(.white).scaleEffect(1.4)
                            }
                        } else {
                            ProgressView().tint(.white).scaleEffect(1.4)
                        }
                    }
                }
            } else {
                let urlStr = item.mediaURL.isEmpty ? item.thumbnailURL : item.mediaURL
                let url: URL? = {
                    guard !urlStr.isEmpty else { return nil }
                    let full = urlStr.hasPrefix("http") ? urlStr : Constant.baseURL + urlStr
                    return URL(string: full)
                }()
                ZStack {
                    Color.black
                    CachedAsyncImage(url: url) { img in
                        img.resizable().scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } placeholder: {
                        ProgressView().tint(.white)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func textBackground(_ story: UserStory) -> some View {
        if story.bgType == "gradient", !story.gradientStart.isEmpty {
            // Reverse-lookup: find the matching gradient entry by start hex so we always
            // get all 3 colours regardless of whether the server returns gradient_mid.
            let startLower = story.gradientStart.lowercased()
            let hexColors: [String] = storyGradients
                .first(where: { $0.hexColors[0].lowercased() == startLower })?
                .hexColors
                ?? [story.gradientStart, story.gradientMid, story.gradientEnd].filter { !$0.isEmpty }
            LinearGradient(
                colors: hexColors.map { Color(hex: $0) },
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        } else {
            // Strip the ":fontIndex" suffix before using as a Color hex
            let hex = story.bgColor.split(separator: ":").first.map(String.init) ?? story.bgColor
            Color(hex: hex.isEmpty ? "#1a1a1a" : hex)
        }
    }

    // MARK: - Reply bar

    private var replyBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {

                // ── Heart / like button (LEFT) — always visible ──
                Button(action: sendLike) {
                    ZStack {
                        Circle()
                            .fill(isLiked
                                  ? Color(hex: Constant.themeColor)
                                  : Color.white.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 19, weight: .regular))
                            .foregroundColor(isLiked ? .white : .white.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)

                // ── Replies bubble button ──
                Button {
                    isPaused = true
                    player?.pause()
                    showRepliesSheet = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "bubble.left.fill")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                .buttonStyle(.plain)

                // ── Reply text field ──
                ZStack(alignment: .leading) {
                    if replyText.isEmpty {
                        Text("Reply to \(ownerName)...")
                            .font(.custom("Inter18pt-Regular", size: 15))
                            .foregroundColor(.white.opacity(0.55))
                            .padding(.horizontal, 16)
                    }
                    TextField("", text: $replyText)
                        .font(.custom("Inter18pt-Regular", size: 15))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .focused($isReplyFocused)
                        .tint(.white)
                        .submitLabel(.send)
                        .onSubmit { sendReply() }
                }
                .frame(height: 44)
                .background(Capsule().stroke(Color.white.opacity(0.45), lineWidth: 1.2))

                // ── Send button (RIGHT) — always visible, active when text present ──
                Button(action: sendReply) {
                    ZStack {
                        Circle()
                            .fill(replyText.isEmpty
                                  ? Color.white.opacity(0.15)
                                  : Color(hex: Constant.themeColor))
                            .frame(width: 44, height: 44)
                        Image("baseline_keyboard_double_arrow_right_24")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundColor(replyText.isEmpty ? .white.opacity(0.35) : .white)
                            .padding(.top, 3)
                            .padding(.bottom, 6)
                    }
                }
                .buttonStyle(.plain)
                .disabled(replyText.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, keyboardHeight > 0 ? 12 : 32)
        }
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.75)],
                startPoint: .top, endPoint: .bottom
            )
        )
        .padding(.bottom, keyboardHeight)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notif in
            let frame = (notif.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect) ?? .zero
            let duration = (notif.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
            withAnimation(.easeOut(duration: duration)) { keyboardHeight = frame.height }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { notif in
            let duration = (notif.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
            withAnimation(.easeOut(duration: duration)) { keyboardHeight = 0 }
        }
    }

    // MARK: - Own story footer

    private var ownStoriesFooter: some View {
        VStack(spacing: 0) {
            // Eye icon + count — centered above the bottom bar
            Button {
                isPaused = true
                player?.pause()
                showViewersSheet = true
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: "eye")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    Text("\(manager.myStories.first(where: { $0.id == currentStory?.id })?.viewsCount ?? currentStory?.viewsCount ?? 0)")
                        .font(.custom("Inter18pt-SemiBold", size: 12))
                        .foregroundColor(.white)
                }
                .shadow(color: .black.opacity(0.55), radius: 3)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
            .padding(.bottom, 8)

            // "My stories ↑" pill — left-aligned
            HStack {
                HStack(spacing: 5) {
                    Text("My stories")
                        .font(.custom("Inter18pt-SemiBold", size: 13))
                    Image(systemName: "arrow.up")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: Constant.themeColor), .purple, .pink],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.leading, 12)
                Spacer()
            }
            .padding(.bottom, 32)
        }
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.6)],
                startPoint: .top, endPoint: .bottom
            )
        )
        .onChange(of: showViewersSheet) { open in
            if !open {
                isPaused = false
                player?.play()
            }
        }
    }

    // MARK: - Timer tick

    private func tickProgress() {
        guard !isPaused && !isReplyFocused else { return }

        // For video stories, drive progress from the player but always tick wall-clock for mark-seen
        if let story = currentStory,
           story.storyType == "media",
           let mediaItem = story.mediaItems.first,
           mediaItem.mediaType == "video" {
            // Always advance elapsed as wall-clock — ensures mark-seen fires even if video fails
            elapsed += tickInterval
            markSeenIfNeeded(story: story, elapsed: elapsed)

            // If player is ready, sync progress bar to player time — but only when player
            // is actually moving (t > 0.1). If video decode fails (Fig -12900 etc.) t stays
            // at 0 forever; in that case we keep wall-clock elapsed so mark-seen still fires.
            if let p = player,
               let item = p.currentItem {
                let d = item.duration.seconds
                let t = p.currentTime().seconds
                if d.isFinite && d > 0 {
                    videoDuration = d
                    if t > 0.1 { elapsed = t }  // only sync when player is advancing
                    if t >= d - 0.1 { goToNext() }
                }
            }
            return
        }

        elapsed += tickInterval
        if let story = currentStory {
            markSeenIfNeeded(story: story, elapsed: elapsed)
        }
        if elapsed >= currentDuration { goToNext() }
    }

    // Call mark_story_seen API once, only for other people's stories, after seenThreshold seconds
    private func markSeenIfNeeded(story: UserStory, elapsed: Double) {
        guard !isOwnStory,
              elapsed >= seenThreshold,
              !seenStoryIds.contains(story.id) else { return }
        seenStoryIds.insert(story.id)
        ApiService.shared.markStorySeen(storyId: story.id)
    }

    // MARK: - Navigation

    private func goToNext() {
        let next = currentIndex + 1
        if next < stories.count {
            currentIndex = next
            elapsed = 0
            loadStory(at: next)
        } else {
            dismiss()
        }
    }

    private func goToPrevious() {
        if elapsed > 0.8 {
            elapsed = 0
            loadStory(at: currentIndex)
        } else if currentIndex > 0 {
            currentIndex -= 1
            elapsed = 0
            loadStory(at: currentIndex)
        }
    }

    // MARK: - Load story media

    private func loadStory(at index: Int) {
        player?.pause()
        player = nil
        videoDuration = 0

        guard index < stories.count else { return }
        let story = stories[index]

        guard story.storyType == "media",
              let item = story.mediaItems.first,
              item.mediaType == "video",
              !item.mediaURL.isEmpty else { return }

        let urlStr = item.mediaURL
        let full = urlStr.hasPrefix("http") ? urlStr : Constant.baseURL + urlStr
        guard let url = URL(string: full) else { return }

        let p = AVPlayer(url: url)
        player = p
        p.play()
    }

    // MARK: - Reply

    private func sendReply() {
        guard !replyText.isEmpty, let story = currentStory else { return }
        let text = replyText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        print("📨 [StoryViewerView] sendReply storyId=\(story.id) message=\(text)")
        replyText = ""
        isReplyFocused = false
        ApiService.shared.postStoryReply(storyId: story.id, message: text) { reply in
            DispatchQueue.main.async {
                if let reply = reply {
                    print("✅ [StoryViewerView] reply posted id=\(reply.id)")
                } else {
                    print("🔴 [StoryViewerView] reply post failed")
                }
            }
        }
    }

    private func sendLike() {
        guard let story = currentStory else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        // Optimistic update
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            isLiked.toggle()
            likesCount = max(0, likesCount + (isLiked ? 1 : -1))
        }
        ApiService.shared.toggleStoryLike(storyId: story.id) { status in
            DispatchQueue.main.async {
                isLiked    = status.liked
                likesCount = status.likesCount
            }
        }
    }

    private func loadLikeStatus() {
        guard !isOwnStory, let story = currentStory else { return }
        isLiked    = false
        likesCount = 0
        ApiService.shared.getStoryLikeStatus(storyId: story.id) { status in
            DispatchQueue.main.async {
                isLiked    = status.liked
                likesCount = status.likesCount
            }
        }
    }

    // MARK: - Helpers

    private func relativeTime(from date: Date) -> String {
        let diff = now.timeIntervalSince(date)
        if diff < 60    { return "just now" }
        if diff < 3600  { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        return "\(Int(diff / 86400))d ago"
    }
}

// MARK: - Caption overlay with expand / collapse (WhatsApp style)

private struct StoryCaptionOverlay: View {
    let caption: String
    let isOwnStory: Bool

    @State private var isExpanded = false
    @State private var isTruncated = false

    var body: some View {
        VStack(spacing: 0) {
            Text(caption)
                .font(.custom("Inter18pt-SemiBold", size: 14))
                .lineLimit(isExpanded ? nil : 3)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.7), radius: 4, x: 0, y: 2)
                .fixedSize(horizontal: false, vertical: true)

            if isTruncated || isExpanded {
                Spacer().frame(height: 6)
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) { isExpanded.toggle() }
                } label: {
                    Text(isExpanded ? "less" : "more")
                        .font(.custom("Inter18pt-SemiBold", size: 13))
                        .foregroundColor(.white.opacity(0.85))
                        .underline()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.6)],
                startPoint: .top, endPoint: .bottom
            )
        )
        // Measure full vs 4-line height to decide whether "more" is needed
        .background(
            GeometryReader { container in
                CaptionTruncationDetector(
                    caption: caption,
                    width: container.size.width - 40,
                    isTruncated: $isTruncated
                )
            }
        )
    }
}

/// Two hidden Text views at identical width: one unconstrained, one limited to 4 lines.
/// Sets isTruncated = true when the unconstrained height exceeds the limited height.
private struct CaptionTruncationDetector: View {
    let caption: String
    let width: CGFloat
    @Binding var isTruncated: Bool

    @State private var fullH: CGFloat = 0
    @State private var limitH: CGFloat = 0

    var body: some View {
        ZStack {
            Text(caption)
                .font(.custom("Inter18pt-SemiBold", size: 14))
                .lineLimit(nil)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: width)
                .hidden()
                .background(GeometryReader { g in
                    Color.clear
                        .onAppear     { fullH = g.size.height; compare() }
                        .onChange(of: g.size.height) { fullH = $0; compare() }
                })

            Text(caption)
                .font(.custom("Inter18pt-SemiBold", size: 14))
                .lineLimit(3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: width)
                .hidden()
                .background(GeometryReader { g in
                    Color.clear
                        .onAppear     { limitH = g.size.height; compare() }
                        .onChange(of: g.size.height) { limitH = $0; compare() }
                })
        }
        .frame(width: 0, height: 0)   // occupies no space in the layout
    }

    private func compare() {
        guard fullH > 0, limitH > 0 else { return }
        let result = fullH > limitH + 2
        if result != isTruncated { isTruncated = result }
    }
}

// MARK: - Controls-free video player (WhatsApp style)

private struct StoryVideoPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> StoryVideoUIView {
        let view = StoryVideoUIView()
        view.backgroundColor = .black
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspect
        view.layer.addSublayer(layer)
        view.playerLayer = layer
        return view
    }

    func updateUIView(_ uiView: StoryVideoUIView, context: Context) {
        uiView.playerLayer?.player = player
    }
}

private final class StoryVideoUIView: UIView {
    var playerLayer: AVPlayerLayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
}

// MARK: - Story Viewers / Replies Bottom Sheet

private struct StoryViewerRow: Identifiable {
    let id: String
    let name: String
    let photo: String
    let seenAt: String

    var photoURL: URL? {
        guard !photo.isEmpty else { return nil }
        let full = photo.hasPrefix("http") ? photo : Constant.baseURL + photo
        return URL(string: full)
    }
}

private struct StoryViewersSheet: View {
    let storyId: String
    let viewsCount: Int
    var initialTab: Int = 0
    var repliesOnly: Bool = false

    @State private var selectedTab = 0
    @State private var viewers: [StoryViewerRow] = []
    @State private var likerUids: Set<String> = []
    @State private var isLoading = false

    // Replies state
    @State private var replies: [ApiService.StoryReply] = []
    @State private var repliesLoaded = false
    @State private var repliesLoading = false
    @State private var replyText = ""
    @State private var isPostingReply = false
    @State private var replyingTo: ApiService.StoryReply? = nil   // nil = top-level
    @State private var expandedThreads: Set<String> = []           // parent IDs with children visible
    @FocusState private var replyFieldFocused: Bool

    // MARK: - Derived reply structure

    private var topLevelReplies: [ApiService.StoryReply] {
        replies.filter { $0.isTopLevel }
    }

    private func childReplies(of parentId: String) -> [ApiService.StoryReply] {
        replies.filter { $0.parentId == parentId }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 40, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 16)

            if !repliesOnly {
                Picker("", selection: $selectedTab) {
                    Text("Seen by").tag(0)
                    Text("Replies").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                Divider()
            }

            if repliesOnly || selectedTab == 1 {
                repliesTab
            } else {
                seenByTab
            }
        }
        .background(Color("background_color"))
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            selectedTab = initialTab
            loadData()
            if initialTab == 1 { loadReplies() }
        }
        .onChange(of: selectedTab, perform: { newTab in
            print("📋 [StoryViewersSheet] tab changed to \(newTab)")
            if newTab == 1 && !repliesLoaded { loadReplies() }
        })
    }

    // MARK: - Data loading

    private func loadData() {
        isLoading = true
        let group = DispatchGroup()

        group.enter()
        ApiService.shared.fetchStoryViewers(storyId: storyId) { data in
            DispatchQueue.main.async {
                viewers = data.compactMap { dict -> StoryViewerRow? in
                    guard let id = dict["viewer_uid"] as? String else { return nil }
                    return StoryViewerRow(
                        id: id,
                        name: dict["full_name"] as? String ?? "Unknown",
                        photo: dict["photo"] as? String ?? "",
                        seenAt: dict["seen_at"] as? String ?? ""
                    )
                }
            }
            group.leave()
        }

        group.enter()
        ApiService.shared.fetchStoryLikes(storyId: storyId) { data in
            DispatchQueue.main.async {
                likerUids = Set(data.compactMap { dict -> String? in
                    if let s = dict["uid"] as? String { return s }
                    if let n = dict["uid"] as? Int    { return String(n) }
                    return nil
                })
            }
            group.leave()
        }

        group.notify(queue: .main) {
            isLoading = false
            print("📊 [StoryViewersSheet] viewers=\(viewers.map { $0.id }) likerUids=\(likerUids)")
        }
    }

    private func loadReplies() {
        print("📋 [StoryViewersSheet] loadReplies() called for storyId=\(storyId)")
        repliesLoading = true
        ApiService.shared.fetchStoryReplies(storyId: storyId) { data in
            DispatchQueue.main.async {
                replies = data
                repliesLoaded = true
                repliesLoading = false
            }
        }
    }

    private func sendReply() {
        let text = replyText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isPostingReply else { return }
        let parentId = replyingTo?.id
        isPostingReply = true
        ApiService.shared.postStoryReply(storyId: storyId, message: text, parentReplyId: parentId) { reply in
            DispatchQueue.main.async {
                isPostingReply = false
                if let reply = reply {
                    replyText = ""
                    replyingTo = nil
                    replies.append(reply)
                    // Auto-expand thread if this is a nested reply
                    if let pid = reply.parentId, pid != "0" {
                        expandedThreads.insert(pid)
                    }
                }
            }
        }
    }

    private func toggleReplyLike(reply: ApiService.StoryReply) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        // Optimistic update
        if let idx = replies.firstIndex(where: { $0.id == reply.id }) {
            replies[idx].isLiked = !replies[idx].isLiked
            replies[idx].likesCount += replies[idx].isLiked ? 1 : -1
        }
        ApiService.shared.toggleReplyLike(replyId: reply.id) { liked, count in
            DispatchQueue.main.async {
                if let idx = replies.firstIndex(where: { $0.id == reply.id }) {
                    replies[idx].isLiked = liked
                    replies[idx].likesCount = count
                }
            }
        }
    }

    // MARK: - Seen By tab

    private var seenByTab: some View {
        Group {
            if isLoading {
                Spacer()
                ProgressView().scaleEffect(1.3)
                Spacer()
            } else if viewers.isEmpty {
                Spacer()
                VStack(spacing: 14) {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No views yet")
                        .font(.custom("Inter18pt-Medium", size: 16))
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(viewers) { viewer in
                            viewerRow(viewer)
                            Divider().padding(.leading, 76)
                        }
                    }
                }
                .background(Color("background_color"))
            }
        }
    }

    @ViewBuilder
    private func viewerRow(_ viewer: StoryViewerRow) -> some View {
        let liked = likerUids.contains(viewer.id)
        HStack(alignment: .center, spacing: 0) {
            ZStack {
                Circle()
                    .stroke(Color(hex: Constant.themeColor), lineWidth: 2)
                    .frame(width: 54, height: 54)
                CachedAsyncImage(url: viewer.photoURL) { img in
                    img.resizable().scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } placeholder: {
                    Image("inviteimg").resizable().scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                }
                .frame(width: 50, height: 50)
            }
            .padding(.leading, 1)
            .padding(.trailing, 16)

            Text(viewer.name)
                .font(.custom("Inter18pt-SemiBold", size: 16))
                .foregroundColor(Color("TextColor"))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if liked {
                Image(systemName: "heart.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: Constant.themeColor))
                    .padding(.trailing, 16)
            }
        }
        .padding(.leading, 10)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 82)
        .background(Color("background_color"))
    }

    // MARK: - Replies tab

    private var repliesTab: some View {
        VStack(spacing: 0) {
            if repliesLoading {
                Spacer()
                ProgressView().scaleEffect(1.3)
                Spacer()
            } else if topLevelReplies.isEmpty {
                Spacer()
                VStack(spacing: 14) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary.opacity(0.45))
                    Text("No replies yet\nBe the first to reply!")
                        .multilineTextAlignment(.center)
                        .font(.custom("Inter18pt-Medium", size: 15))
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(topLevelReplies) { reply in
                            // Top-level comment
                            commentRow(reply, isNested: false)

                            let children = childReplies(of: reply.id)
                            if !children.isEmpty {
                                let expanded = expandedThreads.contains(reply.id)
                                // Toggle to show/hide nested replies
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if expanded { expandedThreads.remove(reply.id) }
                                        else        { expandedThreads.insert(reply.id) }
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Rectangle()
                                            .fill(Color(hex: Constant.themeColor).opacity(0.5))
                                            .frame(width: 24, height: 1)
                                        Text(expanded ? "Hide replies" : "\(children.count) \(children.count == 1 ? "reply" : "replies")")
                                            .font(.custom("Inter18pt-SemiBold", size: 12))
                                            .foregroundColor(Color(hex: Constant.themeColor))
                                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(Color(hex: Constant.themeColor))
                                    }
                                    .padding(.leading, 64)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)

                                if expanded {
                                    ForEach(children) { child in
                                        commentRow(child, isNested: true)
                                    }
                                }
                            }

                            Divider().padding(.leading, 64)
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                }
            }

            Divider()

            // Reply-to context chip
            if let target = replyingTo {
                HStack(spacing: 8) {
                    Text("Replying to \(target.name)")
                        .font(.custom("Inter18pt-Regular", size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button(action: { replyingTo = nil; replyText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.08))
            }

            // Input bar
            HStack(spacing: 10) {
                // My profile avatar
                let myPhotoRaw = UserDefaults.standard.string(forKey: Constant.profilePic) ?? ""
                let myPhotoURL: URL? = myPhotoRaw.isEmpty ? nil : URL(string: myPhotoRaw.hasPrefix("http") ? myPhotoRaw : Constant.baseURL + myPhotoRaw)
                CachedAsyncImage(url: myPhotoURL) { img in
                    img.resizable().scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                } placeholder: {
                    Image("inviteimg").resizable().scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                }
                .frame(width: 36, height: 36)

                TextField(replyingTo == nil ? "Add a reply…" : "Reply to \(replyingTo!.name)…",
                          text: $replyText)
                    .font(.custom("Inter18pt-Regular", size: 15))
                    .focused($replyFieldFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())

                Button(action: sendReply) {
                    if isPostingReply {
                        ProgressView().frame(width: 44, height: 44)
                    } else {
                        ZStack {
                            Circle()
                                .fill(
                                    replyText.trimmingCharacters(in: .whitespaces).isEmpty
                                        ? Color.secondary.opacity(0.25)
                                        : Color(hex: Constant.themeColor)
                                )
                                .frame(width: 44, height: 44)
                            Image("baseline_keyboard_double_arrow_right_24")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(replyText.trimmingCharacters(in: .whitespaces).isEmpty || isPostingReply)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color("background_color"))
        }
    }

    // MARK: - Comment row (YouTube style)

    @ViewBuilder
    private func commentRow(_ reply: ApiService.StoryReply, isNested: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Indent nested replies
            if isNested {
                Spacer().frame(width: 40)
            }

            // Avatar
            CachedAsyncImage(url: reply.photoURL) { img in
                img.resizable().scaledToFill()
                    .frame(width: isNested ? 30 : 38, height: isNested ? 30 : 38)
                    .clipShape(Circle())
            } placeholder: {
                Image("inviteimg").resizable().scaledToFill()
                    .frame(width: isNested ? 30 : 38, height: isNested ? 30 : 38)
                    .clipShape(Circle())
            }
            .frame(width: isNested ? 30 : 38, height: isNested ? 30 : 38)

            VStack(alignment: .leading, spacing: 4) {
                // Name + time
                HStack(spacing: 5) {
                    Text(reply.name)
                        .font(.custom("Inter18pt-SemiBold", size: isNested ? 12 : 13))
                        .foregroundColor(Color("TextColor"))
                    Text("•")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text(reply.relativeTime)
                        .font(.custom("Inter18pt-Regular", size: isNested ? 11 : 12))
                        .foregroundColor(.secondary)
                }

                // Message
                Text(reply.message)
                    .font(.custom("Inter18pt-Regular", size: isNested ? 13 : 14))
                    .foregroundColor(Color("TextColor"))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)

                // Action row: Reply button (only on top-level comments)
                if !isNested {
                    Button(action: {
                        replyingTo = reply
                        replyFieldFocused = true
                    }) {
                        Text("Reply")
                            .font(.custom("Inter18pt-SemiBold", size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }

            Spacer()
        }
        .padding(.leading, isNested ? 8 : 14)
        .padding(.trailing, 14)
        .padding(.vertical, 10)
        .background(Color("background_color"))
    }
}
