import SwiftUI
import AVKit
import SafariServices

// MARK: - Safari helper

private struct UnifiedSafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

// MARK: - Flat queue segment
// Each UserStory and each AdData image is one independent segment so the progress
// bar shows all of them in a single unified row — matching Android behaviour.

enum FlatQueueSegment {
    case story(story: UserStory, ownerUid: String, ownerName: String, ownerPhotoURL: URL?)
    case adMedia(ad: AdData, mediaIndex: Int)

    var segmentId: String {
        switch self {
        case .story(let s, _, _, _):  return "s_\(s.id)"
        case .adMedia(let ad, let i): return "a_\(ad.id)_\(i)"
        }
    }
}

// MARK: - Queue presentation wrapper (drives fullScreenCover)

struct StoryQueuePresentation: Identifiable {
    let id         = UUID()
    let segments: [FlatQueueSegment]
    let startIndex: Int
}

// MARK: - UnifiedStoryQueueView
// Single full-screen viewer with one continuous progress bar spanning every story + ad image.

struct UnifiedStoryQueueView: View {

    let segments: [FlatQueueSegment]
    @Binding var shownAdIds: Set<String>
    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex: Int
    @State private var elapsed: Double       = 0
    @State private var isPaused              = false
    @State private var player: AVPlayer?     = nil
    @State private var videoDuration: Double = 0
    @State private var seenStoryIds: Set<String>   = []
    @State private var impressedAdIds: Set<String> = []
    @State private var now = Date()

    // Story UI state
    @State private var replyText = ""
    @FocusState private var isReplyFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    @State private var isLiked    = false
    @State private var likesCount = 0
    @State private var showRepliesSheet  = false
    @State private var navigateToProfile = false
    @State private var showHideAlert     = false
    @State private var isOwnerHidden     = false

    // Ad UI state
    @State private var showWebView    = false
    @State private var descExpanded   = false

    // Own-story viewers sheet
    @State private var showViewersSheet = false

    private let tickInterval  = 1.0 / 60.0
    private let imageDuration = 5.0
    private let seenThreshold = 1.0

    private var safeTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.safeAreaInsets.top ?? 50
    }

    private var currentSegment: FlatQueueSegment? {
        guard !segments.isEmpty, currentIndex < segments.count else { return nil }
        return segments[currentIndex]
    }

    private var currentDuration: Double { videoDuration > 0 ? videoDuration : imageDuration }
    private var segmentProgress: Double  { min(elapsed / max(currentDuration, 0.001), 1.0) }

    init(segments: [FlatQueueSegment], startIndex: Int, shownAdIds: Binding<Set<String>>) {
        self.segments = segments
        _shownAdIds   = shownAdIds
        _currentIndex = State(initialValue: max(0, min(startIndex, max(0, segments.count - 1))))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                // Content (non-interactive)
                if let seg = currentSegment {
                    segmentContent(seg)
                        .id(currentIndex)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                // Caption overlay for media stories (interactive — expand/collapse)
                if let seg = currentSegment,
                   case .story(let story, let ownerUid, _, _) = seg,
                   story.storyType == "media",
                   !story.caption.isEmpty {
                    VStack {
                        Spacer()
                        StoryCaptionOverlay(caption: story.caption,
                                            isOwnStory: ownerUid == Constant.SenderIdMy)
                            .id(currentIndex)
                            .padding(.bottom, 100)
                    }
                    .ignoresSafeArea()
                    .allowsHitTesting(true)
                }

                // Tap zones (left = back, right = forward)
                HStack(spacing: 0) {
                    Color.clear.contentShape(Rectangle()).onTapGesture { goToPrevious() }
                    Color.clear.contentShape(Rectangle()).onTapGesture { goToNext() }
                }
                .ignoresSafeArea()
                .onLongPressGesture(minimumDuration: 0.2, pressing: { pressing in
                    isPaused = pressing
                    if pressing { player?.pause() } else { player?.play() }
                }, perform: {})

                // Hidden NavigationLink to profile (story segments only)
                if let seg = currentSegment,
                   case .story(let _, let ownerUid, let ownerName, _) = seg {
                    NavigationLink(
                        destination: UserInfoScreen(recUserId: ownerUid, recUserName: ownerName),
                        isActive: $navigateToProfile
                    ) { EmptyView() }.hidden()
                }

                // Header + footer overlay
                VStack(spacing: 0) {
                    headerOverlay
                    Spacer()
                    footerOverlay
                }
            }
            .gesture(DragGesture(minimumDistance: 40).onEnded { val in
                if val.translation.height > 80 { dismiss() }
            })
            .ignoresSafeArea()
        }
        .onAppear { loadCurrentSegment(); loadLikeStatus(); updateOwnerHiddenState() }
        .onDisappear { player?.pause(); player = nil }
        .onChange(of: currentIndex) { _ in
            elapsed = 0; videoDuration = 0
            replyText = ""; isLiked = false; likesCount = 0
            descExpanded = false
            loadCurrentSegment(); loadLikeStatus(); updateOwnerHiddenState()
        }
        .onReceive(Timer.publish(every: tickInterval, on: .main, in: .common).autoconnect()) { _ in tick() }
        .onReceive(Timer.publish(every: 1,           on: .main, in: .common).autoconnect()) { date in now = date }
        .sheet(isPresented: $showWebView)      { adWebViewSheet }
        .sheet(isPresented: $showRepliesSheet) { repliesSheetView }
        .sheet(isPresented: $showViewersSheet) { viewersSheetView }
        .onChange(of: showRepliesSheet) { open in if !open { isPaused = false; player?.play() } }
        .alert(hideAlertTitle, isPresented: $showHideAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Hide", role: .destructive) {
                if let seg = currentSegment, case .story(_, let uid, _, _) = seg {
                    var uids = Set(UserDefaults.standard.stringArray(forKey: "hiddenStoryUids") ?? [])
                    uids.insert(uid)
                    UserDefaults.standard.set(Array(uids), forKey: "hiddenStoryUids")
                    isOwnerHidden = true
                    dismiss()
                }
            }
        } message: {
            Text("You won't be notified of mentions from this contact. Their new status updates also won't appear at the top of the status list anymore.")
        }
    }

    // MARK: - Unified progress bar + header

    private var headerOverlay: some View {
        VStack(spacing: 12) {
            // One segment per story / per ad image — the entire queue in a single bar
            HStack(spacing: 3) {
                ForEach(0..<segments.count, id: \.self) { i in
                    progressSegment(index: i)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, safeTop + 8)

            headerInfoRow
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
        }
        .background(
            LinearGradient(colors: [Color.black.opacity(0.7), Color.clear],
                           startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        )
    }

    @ViewBuilder
    private var headerInfoRow: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image("leftvector").renderingMode(.template)
                    .resizable().scaledToFit()
                    .frame(width: 22, height: 16)
                    .foregroundColor(.white).padding(8)
            }
            .buttonStyle(.plain)

            if let seg = currentSegment,
               case .story(let story, let ownerUid, let ownerName, let ownerPhotoURL) = seg {
                let isOwn = ownerUid == Constant.SenderIdMy

                if isOwn {
                    CachedAsyncImage(url: ownerPhotoURL) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Image("inviteimg").resizable().scaledToFill()
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 1.5))
                } else {
                    Button {
                        isPaused = true; player?.pause(); navigateToProfile = true
                    } label: {
                        CachedAsyncImage(url: ownerPhotoURL) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Image("inviteimg").resizable().scaledToFill()
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(ownerName)
                        .font(.custom("Inter18pt-SemiBold", size: 14))
                        .foregroundColor(.white)
                    if let date = story.createdDate {
                        Text(relativeTime(from: date))
                            .font(.custom("Inter18pt-Regular", size: 11))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                Spacer()
                Menu {
                    if isOwn {
                        Button("Delete Story", role: .destructive) {
                            StoryUploadManager.shared.deleteStory(id: story.id)
                            dismiss()
                        }
                    } else {
                        Button("For Visible") { navigateToProfile = true }
                        if isOwnerHidden {
                            Button("Unhide \(ownerName)") {
                                var uids = Set(UserDefaults.standard.stringArray(forKey: "hiddenStoryUids") ?? [])
                                uids.remove(ownerUid)
                                UserDefaults.standard.set(Array(uids), forKey: "hiddenStoryUids")
                                isOwnerHidden = false
                            }
                        } else {
                            Button("Hide \(ownerName)", role: .destructive) { showHideAlert = true }
                        }
                    }
                } label: {
                    VStack(spacing: 3) {
                        Circle().fill(Color("menuPointColor")).frame(width: 4, height: 4)
                        Circle().fill(Color(hex: Constant.themeColor)).frame(width: 4, height: 4)
                        Circle().fill(Color(red: 0x9E/255, green: 0xA6/255, blue: 0xB9/255)).frame(width: 4, height: 4)
                    }
                    .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)

            } else if let seg = currentSegment, case .adMedia(let ad, _) = seg {
                CachedAsyncImage(url: ad.ownerPhotoURL ?? resolvedOwnerPhoto(for: ad)) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Image("inviteimg").resizable().scaledToFill()
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 1.5))

                let adOwnerName = ad.ownerName.isEmpty ? resolvedOwnerName(for: ad) : ad.ownerName
                if !adOwnerName.isEmpty {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(adOwnerName)
                            .font(.custom("Inter18pt-SemiBold", size: 14))
                            .foregroundColor(.white)
                    }
                }
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func progressSegment(index: Int) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.35)).frame(height: 2.5)
                Capsule().fill(Color.white).frame(
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

    // MARK: - Content rendering

    @ViewBuilder
    private func segmentContent(_ seg: FlatQueueSegment) -> some View {
        switch seg {
        case .story(let story, _, _, _): storyContent(story)
        case .adMedia(let ad, let idx):  adContent(ad: ad, mediaIndex: idx)
        }
    }

    @ViewBuilder
    private func storyContent(_ story: UserStory) -> some View {
        if story.storyType == "text" {
            ZStack {
                storyTextBg(story).ignoresSafeArea()
                if story.bgType == "gradient" { NightWindParticlesView().ignoresSafeArea() }
                let fi       = resolvedFontIndex(story)
                let scale    = fontSizeScale(story.textContent)
                let solidHex = story.bgColor.split(separator: ":").first.map(String.init) ?? story.bgColor
                let isLight  = story.bgType == "solid" && solidHex.lowercased() == "#ffc107"
                Text(story.textContent)
                    .font(storyRoyalFonts[fi].typingFont(scale: scale))
                    .foregroundColor(isLight ? .black : .white)
                    .multilineTextAlignment(.center)
                    .padding(40)
                    .shadow(color: .black.opacity(0.4), radius: 4)
            }
        } else if let item = story.mediaItems.first {
            if item.isVideo {
                if let p = player {
                    StoryVideoPlayerView(player: p).ignoresSafeArea()
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
    private func adContent(ad: AdData, mediaIndex: Int) -> some View {
        if ad.mediaURLs.isEmpty {
            ZStack {
                LinearGradient(colors: [Color(hex: "#00A3E9"), Color(hex: "#005080")],
                               startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                Text(ad.title)
                    .font(.custom("Inter18pt-Bold", size: 28))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center).padding(40)
            }
        } else {
            let url = ad.mediaURLs[min(mediaIndex, ad.mediaURLs.count - 1)]
            if isVideoURL(url), let p = player {
                StoryVideoPlayerView(player: p).ignoresSafeArea()
            } else if !isVideoURL(url) {
                CachedAsyncImage(url: url) { img in
                    img.resizable().scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } placeholder: {
                    ProgressView().tint(.white)
                }
                .ignoresSafeArea()
            } else {
                ProgressView().tint(.white)
            }
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footerOverlay: some View {
        if let seg = currentSegment, case .story(let story, let ownerUid, let ownerName, _) = seg {
            if ownerUid == Constant.SenderIdMy {
                ownStoriesFooter(story: story)
            } else {
                replyBar(ownerName: ownerName, storyId: story.id)
            }
        } else if let seg = currentSegment, case .adMedia(let ad, _) = seg {
            adBottomOverlay(ad: ad)
        }
    }

    // MARK: - Own-story footer (viewers count + pill)

    private func ownStoriesFooter(story: UserStory) -> some View {
        VStack(spacing: 0) {
            // Viewers button — centered, large tap target, glowing capsule like Android
            Button {
                isPaused = true; player?.pause(); showViewersSheet = true
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text("\(story.viewsCount)")
                        .font(.custom("Inter18pt-Bold", size: 13))
                        .foregroundColor(.white)
                }
                .padding(12)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .overlay(Circle().stroke(Color.white.opacity(0.55), lineWidth: 1.5))
                )
                .shadow(color: Color.white.opacity(0.25), radius: 8, x: 0, y: 0)
                .shadow(color: Color.black.opacity(0.5), radius: 5, x: 0, y: 2)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 16)
            .padding(.bottom, 14)

            HStack {
                HStack(spacing: 5) {
                    Text("My stories")
                        .font(.custom("Inter18pt-SemiBold", size: 13))
                    Image(systemName: "arrow.up")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(LinearGradient(
                    colors: [Color(hex: Constant.themeColor), .purple, .pink],
                    startPoint: .leading, endPoint: .trailing
                ))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.leading, 12)
                Spacer()
            }
            .padding(.bottom, 32)
        }
        .background(LinearGradient(
            colors: [Color.clear, Color.black.opacity(0.7)],
            startPoint: .top, endPoint: .bottom
        ))
    }

    @ViewBuilder
    private var viewersSheetView: some View {
        if let seg = currentSegment, case .story(let story, _, _, _) = seg {
            StoryViewersSheet(storyId: story.id, viewsCount: story.viewsCount)
        }
    }

    // MARK: - Reply bar (contact stories)

    private func replyBar(ownerName: String, storyId: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button(action: sendLike) {
                    ZStack {
                        Circle()
                            .fill(isLiked ? Color(hex: Constant.themeColor) : Color.white.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 19, weight: .regular))
                            .foregroundColor(isLiked ? .white : .white.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)

                Button { isPaused = true; player?.pause(); showRepliesSheet = true } label: {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.15)).frame(width: 44, height: 44)
                        Image(systemName: "bubble.left.fill")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                .buttonStyle(.plain)

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
                        .onSubmit { sendReply(storyId: storyId) }
                }
                .frame(height: 44)
                .background(Capsule().stroke(Color.white.opacity(0.45), lineWidth: 1.2))

                Button(action: { sendReply(storyId: storyId) }) {
                    ZStack {
                        Circle()
                            .fill(replyText.isEmpty
                                  ? Color.white.opacity(0.15)
                                  : Color(hex: Constant.themeColor))
                            .frame(width: 44, height: 44)
                        Image("baseline_keyboard_double_arrow_right_24")
                            .renderingMode(.template).resizable().scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundColor(replyText.isEmpty ? .white.opacity(0.35) : .white)
                            .padding(.top, 3).padding(.bottom, 6)
                    }
                }
                .buttonStyle(.plain).disabled(replyText.isEmpty)
            }
            .padding(.horizontal, 12).padding(.top, 10)
            .padding(.bottom, keyboardHeight > 0 ? 12 : 32)
        }
        .background(
            LinearGradient(colors: [Color.clear, Color.black.opacity(0.75)],
                           startPoint: .top, endPoint: .bottom)
        )
        .padding(.bottom, keyboardHeight)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notif in
            let frame = (notif.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect) ?? .zero
            let dur   = (notif.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
            withAnimation(.easeOut(duration: dur)) { keyboardHeight = frame.height }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { notif in
            let dur = (notif.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
            withAnimation(.easeOut(duration: dur)) { keyboardHeight = 0 }
        }
    }

    @ViewBuilder
    private func adBottomOverlay(ad: AdData) -> some View {
        VStack(alignment: .center, spacing: 6) {
            let trimTitle = ad.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimTitle.isEmpty {
                Text(trimTitle)
                    .font(.custom("Inter18pt-Bold", size: 15))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            let trimDesc = ad.description.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimDesc.isEmpty {
                Text(trimDesc)
                    .font(.custom("Inter18pt-SemiBold", size: 14))
                    .foregroundColor(.white)
                    .lineLimit(descExpanded ? nil : 3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                Button(descExpanded ? "less" : "more") { descExpanded.toggle() }
                    .font(.custom("Inter18pt-SemiBold", size: 13))
                    .foregroundColor(.white.opacity(0.85))
                    .underline()
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            let trimLink = ad.link.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimLink.isEmpty {
                let display = trimLink
                    .replacingOccurrences(of: "https://", with: "")
                    .replacingOccurrences(of: "http://", with: "")
                Button { showWebView = true } label: {
                    Text(display)
                        .font(.custom("Inter18pt-SemiBold", size: 13))
                        .foregroundColor(Color(hex: "#4A9EFF"))
                        .underline().lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.plain)
            }
            HStack {
                Text("Ad")
                    .font(.custom("Inter18pt-SemiBold", size: 11))
                    .foregroundColor(Color.white.opacity(0.8))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.267)))
                Spacer()
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(
            LinearGradient(colors: [Color.clear, Color.black.opacity(0.85)],
                           startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        )
    }

    // MARK: - Sheet builders

    @ViewBuilder
    private var adWebViewSheet: some View {
        if let seg = currentSegment, case .adMedia(let ad, _) = seg {
            let raw  = ad.link.trimmingCharacters(in: .whitespacesAndNewlines)
            let norm = (raw.hasPrefix("http://") || raw.hasPrefix("https://")) ? raw : "https://\(raw)"
            if let url = URL(string: norm) {
                UnifiedSafariView(url: url).ignoresSafeArea()
            }
        }
    }

    @ViewBuilder
    private var repliesSheetView: some View {
        if let seg = currentSegment, case .story(let story, _, _, _) = seg {
            StoryViewersSheet(storyId: story.id, viewsCount: story.viewsCount,
                              initialTab: 1, repliesOnly: true)
        }
    }

    private var hideAlertTitle: String {
        if let seg = currentSegment, case .story(_, _, let name, _) = seg {
            return "Hide \(name)'s status updates?"
        }
        return "Hide user?"
    }

    // MARK: - Timer tick

    private func tick() {
        guard !isPaused && !isReplyFocused else { return }

        // Video: sync elapsed to actual player time
        if let p = player, let item = p.currentItem {
            elapsed += tickInterval
            markSeenIfNeeded()
            let d = item.duration.seconds
            let t = p.currentTime().seconds
            if d.isFinite && d > 0 {
                videoDuration = d
                if t > 0.1 { elapsed = t }
                if t >= d - 0.1 { goToNext() }
            }
            return
        }

        elapsed += tickInterval
        markSeenIfNeeded()
        if elapsed >= currentDuration { goToNext() }
    }

    private func markSeenIfNeeded() {
        guard let seg = currentSegment,
              case .story(let story, let ownerUid, _, _) = seg,
              elapsed >= seenThreshold,
              !seenStoryIds.contains(story.id) else { return }
        let myUid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        guard ownerUid != myUid else { return }
        seenStoryIds.insert(story.id)
        var local = Set(UserDefaults.standard.stringArray(forKey: "localSeenStoryIds") ?? [])
        local.insert(story.id)
        UserDefaults.standard.set(Array(local), forKey: "localSeenStoryIds")
        ApiService.shared.markStorySeen(storyId: story.id)
    }

    // MARK: - Navigation

    private func goToNext() {
        // Mark ad as shown when we leave its last image
        if let seg = currentSegment, case .adMedia(let ad, let idx) = seg,
           idx >= ad.mediaURLs.count - 1 {
            shownAdIds.insert(ad.id)
        }
        let next = currentIndex + 1
        if next < segments.count { currentIndex = next } else { dismiss() }
    }

    private func goToPrevious() {
        if elapsed > 0.8 {
            elapsed = 0
            loadCurrentSegment()
        } else if currentIndex > 0 {
            currentIndex -= 1
        } else {
            dismiss()
        }
    }

    // MARK: - Load media

    private func loadCurrentSegment() {
        player?.pause(); player = nil; videoDuration = 0

        switch currentSegment {
        case .story(let story, _, _, _):
            guard story.storyType == "media",
                  let item = story.mediaItems.first,
                  item.isVideo, !item.mediaURL.isEmpty else { return }
            let urlStr = item.mediaURL
            let full   = urlStr.hasPrefix("http") ? urlStr : Constant.baseURL + urlStr
            guard let url = URL(string: full) else { return }
            let p = AVPlayer(url: url); player = p; p.play()

        case .adMedia(let ad, let idx):
            if !impressedAdIds.contains(ad.id) {
                impressedAdIds.insert(ad.id)
                let uid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
                if !uid.isEmpty { ApiService.shared.recordAdImpression(uid: uid, adId: ad.id) }
            }
            guard idx < ad.mediaURLs.count else { return }
            let url = ad.mediaURLs[idx]
            guard isVideoURL(url) else { return }
            let p = AVPlayer(url: url); player = p; p.play()

        case .none: break
        }
    }

    // MARK: - Reply / Like

    private func sendReply(storyId: String) {
        let text = replyText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        replyText = ""; isReplyFocused = false
        ApiService.shared.postStoryReply(storyId: storyId, message: text) { _ in }
    }

    private func sendLike() {
        guard let seg = currentSegment,
              case .story(let story, _, _, _) = seg else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            isLiked.toggle()
            likesCount = max(0, likesCount + (isLiked ? 1 : -1))
        }
        ApiService.shared.toggleStoryLike(storyId: story.id) { status in
            DispatchQueue.main.async { isLiked = status.liked; likesCount = status.likesCount }
        }
    }

    private func loadLikeStatus() {
        guard let seg = currentSegment,
              case .story(let story, let ownerUid, _, _) = seg else { return }
        let myUid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        guard ownerUid != myUid else { return }
        isLiked = false; likesCount = 0
        ApiService.shared.getStoryLikeStatus(storyId: story.id) { status in
            DispatchQueue.main.async { isLiked = status.liked; likesCount = status.likesCount }
        }
    }

    private func updateOwnerHiddenState() {
        guard let seg = currentSegment,
              case .story(_, let ownerUid, _, _) = seg else { return }
        isOwnerHidden = Set(
            UserDefaults.standard.stringArray(forKey: "hiddenStoryUids") ?? []
        ).contains(ownerUid)
    }

    // MARK: - Helpers

    private func relativeTime(from date: Date) -> String {
        let diff = now.timeIntervalSince(date)
        if diff < 60    { return "just now" }
        if diff < 3600  { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        return "\(Int(diff / 86400))d ago"
    }

    private func isVideoURL(_ url: URL) -> Bool {
        ["mp4", "mov", "m4v", "avi"].contains(url.pathExtension.lowercased())
    }

    private func resolvedOwnerName(for ad: AdData) -> String {
        let myUid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        guard !myUid.isEmpty, ad.uid == myUid else { return "" }
        return UserDefaults.standard.string(forKey: Constant.full_name) ?? ""
    }

    private func resolvedOwnerPhoto(for ad: AdData) -> URL? {
        let myUid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        guard !myUid.isEmpty, ad.uid == myUid else { return nil }
        let pic = UserDefaults.standard.string(forKey: Constant.profilePic) ?? ""
        guard !pic.isEmpty else { return nil }
        return URL(string: pic)
    }

    @ViewBuilder
    private func storyTextBg(_ story: UserStory) -> some View {
        if story.bgType == "gradient", !story.gradientStart.isEmpty {
            let startLower = story.gradientStart.lowercased()
            let hexColors  = storyGradients
                .first(where: { $0.hexColors[0].lowercased() == startLower })?.hexColors
                ?? [story.gradientStart, story.gradientMid, story.gradientEnd].filter { !$0.isEmpty }
            LinearGradient(colors: hexColors.map { Color(hex: $0) },
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            let hex = story.bgColor.split(separator: ":").first.map(String.init) ?? story.bgColor
            Color(hex: hex.isEmpty ? "#1a1a1a" : hex)
        }
    }

    private func resolvedFontIndex(_ story: UserStory) -> Int {
        let raw: Int = {
            if story.bgType == "gradient" {
                let parts = story.gradientEnd.split(separator: ":", maxSplits: 1)
                if parts.count == 2, let n = Int(parts[1]) { return n }
                return Int(story.bgColor) ?? story.fontIndex
            } else {
                let parts = story.bgColor.split(separator: ":", maxSplits: 1)
                return parts.count == 2 ? (Int(parts[1]) ?? story.fontIndex) : story.fontIndex
            }
        }()
        return max(0, min(raw, storyRoyalFonts.count - 1))
    }

    private func fontSizeScale(_ text: String) -> CGFloat {
        let lines = max(text.components(separatedBy: "\n").count, max(0, text.count / 24))
        switch lines {
        case 0...4:  return 1.00
        case 5...7:  return 0.78
        case 8...10: return 0.62
        default:     return 0.50
        }
    }
}
