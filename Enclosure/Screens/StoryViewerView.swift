import SwiftUI
import AVKit

// MARK: - StoryViewerView
// WhatsApp-style full-screen story viewer with horizontal progress bars,
// tap left/right navigation, long-press pause, auto-advance, and bottom reply bar.
struct StoryViewerView: View {

    let stories: [UserStory]
    let ownerName: String
    let ownerPhotoURL: URL?
    var isOwnStory: Bool = false

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    @State private var elapsed: Double = 0
    @State private var isPaused = false
    @State private var replyText = ""
    @FocusState private var isReplyFocused: Bool
    @State private var player: AVPlayer? = nil
    @State private var videoDuration: Double = 0
    @State private var now = Date()
    @State private var showViewersSheet = false

    private let tickInterval: Double = 1.0 / 60.0
    private let imageDuration: Double = 5.0

    private var safeAreaTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.safeAreaInsets.top ?? 50
    }

    init(stories: [UserStory], ownerName: String, ownerPhotoURL: URL?,
         isOwnStory: Bool = false, startIndex: Int = 0) {
        self.stories = stories
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
        ZStack {
            Color.black.ignoresSafeArea()

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

            // ── Header + reply bar overlay ──
            VStack(spacing: 0) {
                // Progress bars + user info
                VStack(spacing: 6) {
                    HStack(spacing: 3) {
                        ForEach(0..<stories.count, id: \.self) { i in
                            progressSegment(index: i)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, safeAreaTop + 8)   // below Dynamic Island / status bar

                    HStack(spacing: 10) {
                        // Avatar
                        CachedAsyncImage(url: ownerPhotoURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Image("inviteimg").resizable().scaledToFill()
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 1.5))

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

                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(10)
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
        .onAppear { loadStory(at: currentIndex) }
        .onDisappear { player?.pause(); player = nil }
        .onReceive(Timer.publish(every: tickInterval, on: .main, in: .common).autoconnect()) { _ in
            tickProgress()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
            now = date
        }
        .sheet(isPresented: $showViewersSheet) {
            StoryViewersSheet(story: currentStory)
        }
        .ignoresSafeArea()
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

    @ViewBuilder
    private func storyContent(_ story: UserStory) -> some View {
        if story.storyType == "text" {
            ZStack {
                textBackground(story).ignoresSafeArea()
                Text(story.textContent)
                    .font(.custom("Inter18pt-Bold", size: 26))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(40)
                    .shadow(color: .black.opacity(0.5), radius: 4)
            }
        } else if let item = story.mediaItems.first {
            if item.mediaType == "video" {
                if let p = player {
                    VideoPlayer(player: p)
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

    // MARK: - Reply bar

    private var replyBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
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

                Button(action: sendReply) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 22))
                        .foregroundColor(
                            replyText.isEmpty
                                ? Color.white.opacity(0.4)
                                : Color(hex: Constant.themeColor)
                        )
                }
                .buttonStyle(.plain)
                .disabled(replyText.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 32)
        }
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.75)],
                startPoint: .top, endPoint: .bottom
            )
        )
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
                    Text("\(currentStory?.viewsCount ?? 0)")
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

        // For video stories, sync elapsed with actual player time
        if let story = currentStory,
           story.storyType == "media",
           story.mediaItems.first?.mediaType == "video",
           let p = player,
           let item = p.currentItem {
            let d = item.duration.seconds
            let t = p.currentTime().seconds
            if d.isFinite && d > 0 {
                videoDuration = d
                elapsed = t
                if t >= d - 0.1 { goToNext() }
            }
            return
        }

        elapsed += tickInterval
        if elapsed >= currentDuration { goToNext() }
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
        guard !replyText.isEmpty else { return }
        // TODO: send reply via API
        replyText = ""
        isReplyFocused = false
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

// MARK: - Story Viewers / Comments Bottom Sheet

private struct StoryViewersSheet: View {
    let story: UserStory?
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 40, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 16)

            // Tab picker
            Picker("", selection: $selectedTab) {
                Text("Seen by").tag(0)
                Text("Replies").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Divider()

            if selectedTab == 0 {
                seenByTab
            } else {
                repliesTab
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    // MARK: Seen By tab

    private var seenByTab: some View {
        Group {
            if let count = story?.viewsCount, count > 0 {
                List {
                    Section {
                        ForEach(0..<count, id: \.self) { i in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color(hex: Constant.themeColor).opacity(0.25))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(Color(hex: Constant.themeColor))
                                    )
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Viewer \(i + 1)")
                                        .font(.custom("Inter18pt-SemiBold", size: 15))
                                    Text("Viewed")
                                        .font(.custom("Inter18pt-Regular", size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: Constant.themeColor).opacity(0.6))
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text("\(count) view\(count == 1 ? "" : "s")")
                            .font(.custom("Inter18pt-Medium", size: 13))
                            .foregroundColor(.secondary)
                            .textCase(nil)
                    }
                }
                .listStyle(.plain)
            } else {
                Spacer()
                VStack(spacing: 14) {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No views yet")
                        .font(.custom("Inter18pt-Medium", size: 16))
                        .foregroundColor(.secondary)
                    Text("When people see your story, they'll appear here.")
                        .font(.custom("Inter18pt-Regular", size: 13))
                        .foregroundColor(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                Spacer()
            }
        }
    }

    // MARK: Replies tab
    // Shows replies that other users sent to the story owner via the reply bar.
    // Wire `storyReplies` from the API to replace the empty-state placeholder.

    private var repliesTab: some View {
        Group {
            // TODO: replace [] with real replies array fetched from API
            let replies: [String] = []

            if replies.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "arrowshape.turn.up.left")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.45))
                    Text("No replies yet")
                        .font(.custom("Inter18pt-Medium", size: 16))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List(replies, id: \.self) { reply in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: Constant.themeColor).opacity(0.2))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(hex: Constant.themeColor))
                            )
                        Text(reply)
                            .font(.custom("Inter18pt-Regular", size: 15))
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
    }
}
