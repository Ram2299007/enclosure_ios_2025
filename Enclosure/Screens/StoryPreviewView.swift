import SwiftUI
import Photos
import AVKit

// MARK: - Story Preview
// Matches MultiImagePreviewDialog design: black bg, top bar, swipeable pager,
// caption bar, remove current asset, video play-on-tap.
struct StoryPreviewView: View {
    @State var assets: [PHAsset]
    var onPost: (([PHAsset], String) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex = 0
    @State private var captionText = ""
    @State private var loadedImages: [String: UIImage] = [:]
    @State private var players: [String: AVPlayer] = [:]
    @State private var playingVideoId: String? = nil
    @FocusState private var isCaptionFocused: Bool

    private let imageManager = PHCachingImageManager()

    private func hideKeyboard() {
        isCaptionFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { hideKeyboard() }

            VStack(spacing: 0) {

                // ── Top bar ──
                HStack {
                    // Back
                    Button(action: { dismiss() }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 40, height: 40)
                            Image("leftvector")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 25, height: 18)
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 16)

                    Spacer()

                    // Counter — centered
                    if assets.count > 1 {
                        Text("\(currentIndex + 1) / \(assets.count)")
                            .font(.custom("Inter18pt-Medium", size: 16))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    // Remove current asset
                    Button(action: removeCurrentAsset) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 40, height: 40)
                            Image(systemName: "trash")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 16)
                }
                .frame(height: 60)
                .background(Color.black.opacity(0.3))

                // ── Pager ──
                GeometryReader { _ in
                    TabView(selection: $currentIndex) {
                        ForEach(Array(assets.enumerated()), id: \.element.localIdentifier) { index, asset in
                            assetPage(asset)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .onChange(of: currentIndex) { _ in
                        // Pause any playing video when swiping away
                        playingVideoId = nil
                        players.values.forEach { $0.pause() }
                    }
                }

                // 5 pt gap
                Spacer().frame(height: 5)

                // ── Caption bar ──
                HStack(spacing: 0) {
                    // Caption input
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            ZStack(alignment: .leading) {
                                // Hint
                                if captionText.isEmpty {
                                    Text("Add stories")
                                        .font(.custom("Inter18pt-Medium", size: 17))
                                        .foregroundColor(Color(hex: "#9EA6B9"))
                                        .padding(.leading, 15)
                                        .padding(.trailing, 20)
                                        .padding(.vertical, 5)
                                }
                                TextField("", text: $captionText, axis: .vertical)
                                    .font(.custom("Inter18pt-Medium", size: 17))
                                    .foregroundColor(.white)
                                    .lineLimit(4)
                                    .lineSpacing(4)
                                    .frame(maxWidth: 220, alignment: .leading)
                                    .padding(.leading, 15)
                                    .padding(.trailing, 20)
                                    .padding(.vertical, 5)
                                    .background(Color.clear)
                                    .focused($isCaptionFocused)
                                    .tint(Color.white)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(hex: "#1B1C1C"))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isCaptionFocused ? Color.white : Color.gray, lineWidth: isCaptionFocused ? 1.5 : 1.0)
                    )
                    .animation(.easeInOut(duration: 0.2), value: isCaptionFocused)
                    .padding(.leading, 10)
                    .padding(.trailing, 5)

                    // Add to Story button
                    Button(action: handlePost) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: Constant.themeColor))
                                .frame(width: 50, height: 50)
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 5)
                }
                .padding(.bottom, 10)
                .background(Color.black)
            }
        }
        .ignoresSafeArea(.keyboard)
        .simultaneousGesture(
            TapGesture().onEnded { _ in hideKeyboard() }
        )
        .gesture(
            DragGesture(minimumDistance: 20).onEnded { value in
                if value.translation.height > 100 { dismiss() }
            }
        )
        .onAppear { preloadAssets() }
        .onDisappear {
            players.values.forEach { $0.pause() }
        }
    }

    // MARK: - Asset Page

    @ViewBuilder
    private func assetPage(_ asset: PHAsset) -> some View {
        if asset.mediaType == .video {
            ZStack {
                Color.black
                if let player = players[asset.localIdentifier], playingVideoId == asset.localIdentifier {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                } else {
                    // Show video thumbnail + play button
                    if let thumb = loadedImages[asset.localIdentifier] {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    // Play button overlay
                    Button(action: { playVideo(asset) }) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 72, height: 72)
                            Image(systemName: "play.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .offset(x: 3)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            ZStack {
                Color.black
                if let image = loadedImages[asset.localIdentifier] {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView().tint(.white)
                }
            }
        }
    }

    // MARK: - Video Play

    private func playVideo(_ asset: PHAsset) {
        if let player = players[asset.localIdentifier] {
            player.seek(to: .zero)
            player.play()
            playingVideoId = asset.localIdentifier
        } else {
            let opts = PHVideoRequestOptions()
            opts.deliveryMode = .automatic
            opts.isNetworkAccessAllowed = true
            PHImageManager.default().requestAVAsset(forVideo: asset, options: opts) { avAsset, _, _ in
                guard let avAsset else { return }
                DispatchQueue.main.async {
                    let player = AVPlayer(playerItem: AVPlayerItem(asset: avAsset))
                    players[asset.localIdentifier] = player
                    player.play()
                    playingVideoId = asset.localIdentifier
                }
            }
        }
    }

    // MARK: - Remove current asset

    private func removeCurrentAsset() {
        guard !assets.isEmpty else { return }
        let id = assets[currentIndex].localIdentifier
        players[id]?.pause()
        players.removeValue(forKey: id)
        loadedImages.removeValue(forKey: id)
        if playingVideoId == id { playingVideoId = nil }

        assets.remove(at: currentIndex)

        if assets.isEmpty {
            dismiss()
        } else {
            currentIndex = min(currentIndex, assets.count - 1)
        }
    }

    // MARK: - Preload

    private func preloadAssets() {
        for asset in assets {
            if asset.mediaType == .image {
                let opts = PHImageRequestOptions()
                opts.deliveryMode = .highQualityFormat
                opts.isNetworkAccessAllowed = true
                imageManager.requestImage(
                    for: asset,
                    targetSize: CGSize(width: UIScreen.main.bounds.width * 2,
                                      height: UIScreen.main.bounds.height * 2),
                    contentMode: .aspectFit,
                    options: opts
                ) { img, _ in
                    if let img { DispatchQueue.main.async { loadedImages[asset.localIdentifier] = img } }
                }
            } else if asset.mediaType == .video {
                // Load thumbnail for video poster frame
                let opts = PHImageRequestOptions()
                opts.deliveryMode = .fastFormat
                opts.isNetworkAccessAllowed = true
                imageManager.requestImage(
                    for: asset,
                    targetSize: CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height),
                    contentMode: .aspectFit,
                    options: opts
                ) { img, _ in
                    if let img { DispatchQueue.main.async { loadedImages[asset.localIdentifier] = img } }
                }
            }
        }
    }

    // MARK: - Post

    private func handlePost() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        let caption = captionText.trimmingCharacters(in: .whitespacesAndNewlines)
        onPost?(assets, caption)
        dismiss()
    }
}
