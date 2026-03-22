import SwiftUI
import Photos
import AVKit

// MARK: - Story Preview
// Swipeable pager showing selected assets, caption field, and "Add to Story" button.
struct StoryPreviewView: View {
    let assets: [PHAsset]
    var onPost: (([PHAsset], String) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex = 0
    @State private var captionText = ""
    @State private var loadedImages: [String: UIImage] = [:]
    @State private var players: [String: AVPlayer] = [:]

    private let imageManager = PHCachingImageManager()

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Swipeable pager ──
                TabView(selection: $currentIndex) {
                    ForEach(Array(assets.enumerated()), id: \.element.localIdentifier) { index, asset in
                        assetPage(asset)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: assets.count > 1 ? .always : .never))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(edges: .top)

                // ── Bottom: caption + button ──
                VStack(spacing: 12) {
                    // Caption field
                    HStack(spacing: 10) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.7))
                        TextField("Add a caption...", text: $captionText)
                            .font(.custom("Inter18pt-Regular", size: 15))
                            .foregroundColor(.white)
                            .tint(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white.opacity(0.15))
                    )

                    // Add to Story button
                    Button(action: handlePost) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Add to Story")
                                .font(.custom("Inter18pt-SemiBold", size: 16))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(Color(hex: Constant.themeColor))
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 44)
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0.0), Color.black.opacity(0.85)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            }

            // ── Top overlay: back + counter ──
            HStack {
                Button(action: { dismiss() }) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.45))
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

                Spacer()

                if assets.count > 1 {
                    Text("\(currentIndex + 1) / \(assets.count)")
                        .font(.custom("Inter18pt-SemiBold", size: 14))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.black.opacity(0.45)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .onAppear { preloadAssets() }
        .onDisappear { players.values.forEach { $0.pause() } }
    }

    // MARK: - Asset Page

    @ViewBuilder
    private func assetPage(_ asset: PHAsset) -> some View {
        if asset.mediaType == .video {
            if let player = players[asset.localIdentifier] {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onAppear { player.seek(to: .zero); player.play() }
                    .onDisappear { player.pause() }
            } else {
                Color.black
                    .overlay(ProgressView().tint(.white))
            }
        } else {
            if let image = loadedImages[asset.localIdentifier] {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Color.black
                    .overlay(ProgressView().tint(.white))
            }
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
                    targetSize: PHImageManagerMaximumSize,
                    contentMode: .aspectFit,
                    options: opts
                ) { img, _ in
                    if let img {
                        DispatchQueue.main.async { loadedImages[asset.localIdentifier] = img }
                    }
                }
            } else if asset.mediaType == .video {
                let opts = PHVideoRequestOptions()
                opts.deliveryMode = .automatic
                opts.isNetworkAccessAllowed = true
                PHImageManager.default().requestAVAsset(forVideo: asset, options: opts) { avAsset, _, _ in
                    if let avAsset {
                        DispatchQueue.main.async {
                            let player = AVPlayer(playerItem: AVPlayerItem(asset: avAsset))
                            players[asset.localIdentifier] = player
                        }
                    }
                }
            }
        }
    }

    // MARK: - Post

    private func handlePost() {
        let caption = captionText.trimmingCharacters(in: .whitespacesAndNewlines)
        onPost?(assets, caption)
        dismiss()
    }
}
