import SwiftUI
import AVKit

struct AdvertisePreviewView: View {
    let ad: AdData
    let isViewOnly: Bool
    var onQueueAdvance: (() -> Void)? = nil
    var onGoBack: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var elapsed: Double = 0
    @State private var isPaused = false
    @State private var player: AVPlayer? = nil

    private let tickInterval: Double = 1.0 / 60.0
    private let adDuration: Double = 5.0

    private var safeTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.safeAreaInsets.top ?? 50
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // ── Media content ──
            mediaContent

            // ── Tap zones: left = back, right = forward ──
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

            // ── Header + bottom overlay ──
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
            loadMedia()
            if isViewOnly { recordImpression() }
        }
        .onDisappear { player?.pause(); player = nil }
        .onReceive(Timer.publish(every: tickInterval, on: .main, in: .common).autoconnect()) { _ in
            tick()
        }
    }

    // MARK: - Media

    @ViewBuilder
    private var mediaContent: some View {
        if let url = ad.mediaURLs.first {
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
        } else {
            // No media: gradient background with title
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
        }
    }

    // MARK: - Header

    private var headerOverlay: some View {
        VStack(spacing: 12) {
            // Single progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.35))
                        .frame(height: 2.5)
                    Capsule()
                        .fill(Color.white)
                        .frame(
                            width: geo.size.width * CGFloat(min(elapsed / adDuration, 1.0)),
                            height: 2.5
                        )
                }
            }
            .frame(height: 2.5)
            .padding(.horizontal, 10)
            .padding(.top, safeTop + 8)

            // User info row
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

                CachedAsyncImage(url: ad.ownerPhotoURL) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Image("inviteimg").resizable().scaledToFill()
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 1.5))

                VStack(alignment: .leading, spacing: 1) {
                    Text(ad.ownerName.isEmpty ? "Sponsored" : ad.ownerName)
                        .font(.custom("Inter18pt-SemiBold", size: 14))
                        .foregroundColor(.white)
                    Text("Sponsored")
                        .font(.custom("Inter18pt-Regular", size: 11))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                Text("AD")
                    .font(.custom("Inter18pt-Bold", size: 10))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
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

    // MARK: - Bottom info

    private var bottomOverlay: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !ad.title.isEmpty {
                Text(ad.title)
                    .font(.custom("Inter18pt-Bold", size: 18))
                    .foregroundColor(.white)
                    .lineLimit(2)
            }
            if !ad.description.isEmpty {
                Text(ad.description)
                    .font(.custom("Inter18pt-Regular", size: 14))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(3)
            }
            if !ad.link.isEmpty {
                let linkStr = ad.link.hasPrefix("http") ? ad.link : "https://\(ad.link)"
                if let url = URL(string: linkStr) {
                    Link(destination: url) {
                        HStack {
                            Text("Visit Link")
                                .font(.custom("Inter18pt-SemiBold", size: 15))
                                .foregroundColor(.white)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(hex: Constant.themeColor))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 48)
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.85)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    // MARK: - Timer

    private func tick() {
        guard !isPaused else { return }
        elapsed += tickInterval
        if elapsed >= adDuration { handleForward() }
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
        if let back = onGoBack { back() } else { dismiss() }
    }

    // MARK: - Helpers

    private func isVideoURL(_ url: URL) -> Bool {
        ["mp4", "mov", "m4v", "avi"].contains(url.pathExtension.lowercased())
    }

    private func loadMedia() {
        guard let url = ad.mediaURLs.first, isVideoURL(url) else { return }
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
