import SwiftUI
import AVKit
import SafariServices

// MARK: - Safari view

private struct AdSafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

// MARK: - Truncation detection key

private struct AdDescDiffKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - AdvertisePreviewView

struct AdvertisePreviewView: View {
    let ad: AdData
    let isViewOnly: Bool
    var onQueueAdvance: (() -> Void)? = nil
    var onGoBack: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var currentMediaIndex = 0
    @State private var elapsed: Double = 0
    @State private var isPaused = false
    @State private var player: AVPlayer? = nil
    @State private var descExpanded = false
    @State private var isDescTruncated = false
    @State private var showWebView = false

    private let tickInterval: Double = 1.0 / 60.0
    private let adDuration: Double = 5.0
    private var totalMedia: Int { max(1, ad.mediaURLs.count) }

    // Resolved owner fields — fall back to current user's cached data when ad.uid matches self
    private var resolvedOwnerName: String {
        if !ad.ownerName.isEmpty { return ad.ownerName }
        let myUid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        guard !myUid.isEmpty, ad.uid == myUid else { return "" }
        return UserDefaults.standard.string(forKey: Constant.full_name) ?? ""
    }

    private var resolvedOwnerPhotoURL: URL? {
        if let url = ad.ownerPhotoURL { return url }
        let myUid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        guard !myUid.isEmpty, ad.uid == myUid else { return nil }
        let pic = UserDefaults.standard.string(forKey: Constant.profilePic) ?? ""
        guard !pic.isEmpty else { return nil }
        return URL(string: pic)
    }

    private var safeTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.safeAreaInsets.top ?? 50
    }

    private var relativeTimeText: String {
        guard ad.createdAt > 0 else { return "" }
        let diff = Date().timeIntervalSince1970 - ad.createdAt
        if diff < 60    { return "just now" }
        if diff < 3600  { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        return "\(Int(diff / 86400))d ago"
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            mediaContent

            // Tap zones: left = back, right = forward
            HStack(spacing: 0) {
                Color.clear.contentShape(Rectangle())
                    .onTapGesture { handleBack() }
                Color.clear.contentShape(Rectangle())
                    .onTapGesture { handleForward() }
            }
            .ignoresSafeArea()
            .onLongPressGesture(minimumDuration: 0.2, pressing: { pressing in
                isPaused = pressing
                if pressing { player?.pause() } else { player?.play() }
            }, perform: {})

            VStack(spacing: 0) {
                headerOverlay
                Spacer()
                bottomOverlay
            }
        }
        .ignoresSafeArea()
        .gesture(DragGesture(minimumDistance: 40).onEnded { val in
            if val.translation.height > 80 { dismiss() }
        })
        .onAppear {
            loadMedia(for: 0)
            if isViewOnly { recordImpression() }
        }
        .onDisappear { player?.pause(); player = nil }
        .onChange(of: currentMediaIndex) { _ in loadMedia(for: currentMediaIndex) }
        .onReceive(Timer.publish(every: tickInterval, on: .main, in: .common).autoconnect()) { _ in tick() }
        .sheet(isPresented: $showWebView) {
            let raw = ad.link.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = (raw.hasPrefix("http://") || raw.hasPrefix("https://")) ? raw : "https://\(raw)"
            if let url = URL(string: normalized) {
                AdSafariView(url: url).ignoresSafeArea()
            }
        }
    }

    // MARK: - Media content

    @ViewBuilder
    private var mediaContent: some View {
        if ad.mediaURLs.isEmpty {
            LinearGradient(
                colors: [Color(hex: "#00A3E9"), Color(hex: "#005080")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            Text(ad.title)
                .font(.custom("Inter18pt-Bold", size: 28))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(40)
        } else {
            let url = ad.mediaURLs[min(currentMediaIndex, ad.mediaURLs.count - 1)]
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

    // MARK: - Header overlay

    private var headerOverlay: some View {
        VStack(spacing: 12) {
            // Progress bars — one per media item
            HStack(spacing: 3) {
                ForEach(0..<totalMedia, id: \.self) { i in
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.35))
                                .frame(height: 2.5)
                            Capsule()
                                .fill(Color.white)
                                .frame(
                                    width: geo.size.width * progressFraction(for: i),
                                    height: 2.5
                                )
                        }
                    }
                    .frame(height: 2.5)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, safeTop + 8)

            // Owner info row
            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Image("leftvector")
                        .renderingMode(.template)
                        .resizable().scaledToFit()
                        .frame(width: 22, height: 16)
                        .foregroundColor(.white)
                        .padding(8)
                }
                .buttonStyle(.plain)

                CachedAsyncImage(url: resolvedOwnerPhotoURL) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Image("inviteimg").resizable().scaledToFill()
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 1.5))

                VStack(alignment: .leading, spacing: 1) {
                    let name = resolvedOwnerName
                    if !name.isEmpty {
                        Text(name)
                            .font(.custom("Inter18pt-SemiBold", size: 14))
                            .foregroundColor(.white)
                    }
                    let t = relativeTimeText
                    if !t.isEmpty {
                        Text(t)
                            .font(.custom("Inter18pt-Regular", size: 11))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()
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
    }

    // MARK: - Bottom overlay

    private var bottomOverlay: some View {
        VStack(alignment: .center, spacing: 6) {
            let trimTitle = ad.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimTitle.isEmpty {
                Text(trimTitle)
                    .font(.custom("Inter18pt-Bold", size: 15))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            let trimDesc = ad.description.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimDesc.isEmpty {
                Text(trimDesc)
                    .font(.custom("Inter18pt-SemiBold", size: 14))
                    .foregroundColor(.white)
                    .lineSpacing(2)
                    .lineLimit(descExpanded ? nil : 3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .overlay(
                        GeometryReader { limited in
                            Color.clear.overlay(
                                Text(trimDesc)
                                    .font(.custom("Inter18pt-SemiBold", size: 14))
                                    .lineSpacing(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .hidden()
                                    .background(
                                        GeometryReader { full in
                                            Color.clear.preference(
                                                key: AdDescDiffKey.self,
                                                value: full.size.height - limited.size.height
                                            )
                                        }
                                    )
                                    .frame(width: limited.size.width)
                            )
                        }
                    )
                    .onPreferenceChange(AdDescDiffKey.self) { diff in isDescTruncated = diff > 1 }

                if isDescTruncated || descExpanded {
                    Button(descExpanded ? "less" : "more") { descExpanded.toggle() }
                        .font(.custom("Inter18pt-SemiBold", size: 13))
                        .foregroundColor(Color.white.opacity(0.85))
                        .underline()
                        .frame(maxWidth: .infinity, alignment: .center)
                }
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
                        .underline()
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.plain)
            }

            // "Ad" pill (left) — matches Android advertise_tag_bg: #44FFFFFF fill, 6dp corners
            HStack {
                Text("Ad")
                    .font(.custom("Inter18pt-SemiBold", size: 11))
                    .foregroundColor(Color.white.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.267)))
                Spacer()
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.85)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    // MARK: - Progress

    private func progressFraction(for index: Int) -> CGFloat {
        if index < currentMediaIndex { return 1.0 }
        if index > currentMediaIndex { return 0.0 }
        return CGFloat(min(elapsed / adDuration, 1.0))
    }

    // MARK: - Timer

    private func tick() {
        guard !isPaused else { return }
        elapsed += tickInterval
        if elapsed >= adDuration { advanceMedia() }
    }

    private func advanceMedia() {
        elapsed = 0
        if currentMediaIndex < ad.mediaURLs.count - 1 {
            currentMediaIndex += 1
        } else {
            handleForward()
        }
    }

    // MARK: - Navigation

    private func handleForward() {
        elapsed = adDuration
        if let advance = onQueueAdvance {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { advance() }
        } else {
            dismiss()
        }
    }

    private func handleBack() {
        if currentMediaIndex > 0 {
            elapsed = 0
            currentMediaIndex -= 1
        } else {
            if let back = onGoBack { back() } else { dismiss() }
        }
    }

    // MARK: - Helpers

    private func isVideoURL(_ url: URL) -> Bool {
        ["mp4", "mov", "m4v", "avi"].contains(url.pathExtension.lowercased())
    }

    private func loadMedia(for index: Int) {
        player?.pause()
        player = nil
        guard index < ad.mediaURLs.count else { return }
        let url = ad.mediaURLs[index]
        guard isVideoURL(url) else { return }
        let p = AVPlayer(url: url)
        player = p
        p.play()
    }

    private func recordImpression() {
        let uid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        guard !uid.isEmpty, !ad.id.isEmpty else { return }
        ApiService.shared.recordAdImpression(uid: uid, adId: ad.id)
    }
}
