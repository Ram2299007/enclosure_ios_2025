import SwiftUI
import Photos
import PhotosUI

// MARK: - Story Photo Picker (iOS native Photos-style)
struct StoryPhotoPicker: View {
    @Environment(\.dismiss) private var dismiss

    var onAssetSelected: ((PHAsset) -> Void)? = nil

    // Albums
    @State private var allAlbums: [PHAssetCollection] = []
    @State private var selectedAlbum: PHAssetCollection? = nil
    @State private var selectedAlbumTitle: String = "Recents"
    @State private var showAlbumSheet = false          // replaces Menu to avoid _UIReparentingView

    // Assets
    @State private var assets: [PHAsset] = []
    @State private var isLoading: Bool = true
    @State private var permissionDenied: Bool = false

    // Camera
    @State private var showCameraView: Bool = false

    private let imageManager = PHCachingImageManager()
    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    private let thumbnailSize = CGSize(width: 200, height: 200)

    var body: some View {
        ZStack(alignment: .top) {
            Color(UIColor.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ──
                ZStack {
                    // Center: Album picker button (no Menu — uses confirmationDialog instead)
                    Button {
                        showAlbumSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedAlbumTitle)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.primary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: Capsule())
                    }

                    // Left: Cancel
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 36, height: 36)
                                .background(.thinMaterial, in: Circle())
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider()

                // ── Text + Camera row (above grid) ──
                if !permissionDenied {
                    HStack {
                        Text("Add to Your Story")
                            .font(.custom("Inter18pt-SemiBold", size: 15))
                            .foregroundColor(Color("TextColor"))

                        Spacer()

                        Button {
                            handleCameraButtonClick()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Camera")
                                    .font(.custom("Inter18pt-Medium", size: 14))
                            }
                            .foregroundColor(Color(hex: Constant.themeColor))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(hex: Constant.themeColor).opacity(0.12))
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 0)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )
                }

                // ── Content ──
                if permissionDenied {
                    permissionView
                } else if isLoading {
                    loadingView
                } else if assets.isEmpty {
                    emptyView
                } else {
                    gridView
                }
            }
        }
        // Album picker as confirmationDialog — avoids _UIReparentingView
        .confirmationDialog(
            "Select Album",
            isPresented: $showAlbumSheet,
            titleVisibility: .visible
        ) {
            ForEach(allAlbums, id: \.localIdentifier) { album in
                Button(album.localizedTitle ?? "Album") {
                    selectAlbum(album)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        // Camera
        .fullScreenCover(isPresented: $showCameraView) {
            StoryCameraGalleryView { assets, caption in
                if let first = assets.first {
                    onAssetSelected?(first)
                }
                dismiss()
            }
        }
        .onAppear { requestPhotoAccess() }
    }

    // MARK: - Sub-views

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView().progressViewStyle(.circular).scaleEffect(1.4)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48)).foregroundColor(.secondary)
            Text("No Photos or Videos")
                .font(.system(size: 17, weight: .medium)).foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var permissionView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "lock.fill").font(.system(size: 48)).foregroundColor(.secondary)
            Text("No Access to Photos").font(.system(size: 17, weight: .semibold))
            Text("Allow access in Settings to pick photos and videos.")
                .font(.system(size: 14)).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(assets, id: \.localIdentifier) { asset in
                    AssetThumbnailCell(asset: asset, imageManager: imageManager, thumbnailSize: thumbnailSize) {
                        onAssetSelected?(asset)
                        dismiss()
                    }
                }
            }
            .padding(.top, 2)
        }
    }

    // MARK: - Camera Handler (same pattern as ChattingScreen)
    private func handleCameraButtonClick() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        AndroidStylePermissionManager.shared.requestPermissionWithDialogFromTopVC(for: .camera) { granted in
            DispatchQueue.main.async {
                if granted { showCameraView = true }
            }
        }
    }

    // MARK: - Photo Library Logic

    private func requestPhotoAccess() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            loadAlbums()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        loadAlbums()
                    } else {
                        isLoading = false
                        permissionDenied = true
                    }
                }
            }
        default:
            isLoading = false
            permissionDenied = true
        }
    }

    private func loadAlbums() {
        DispatchQueue.global(qos: .userInitiated).async {
            var albums: [PHAssetCollection] = []

            let smartSubtypes: [PHAssetCollectionSubtype] = [
                .smartAlbumRecentlyAdded, .smartAlbumUserLibrary, .smartAlbumFavorites,
                .smartAlbumVideos, .smartAlbumSlomoVideos, .smartAlbumTimelapses,
                .smartAlbumPanoramas, .smartAlbumScreenshots, .smartAlbumBursts,
                .smartAlbumSelfPortraits, .smartAlbumLivePhotos, .smartAlbumDepthEffect,
                .smartAlbumLongExposures
            ]
            for subtype in smartSubtypes {
                let r = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: subtype, options: nil)
                r.enumerateObjects { col, _, _ in
                    if PHAsset.fetchAssets(in: col, options: nil).count > 0 { albums.append(col) }
                }
            }
            PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
                .enumerateObjects { col, _, _ in
                    if PHAsset.fetchAssets(in: col, options: nil).count > 0 { albums.append(col) }
                }
            PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumSyncedAlbum, options: nil)
                .enumerateObjects { col, _, _ in
                    if PHAsset.fetchAssets(in: col, options: nil).count > 0 { albums.append(col) }
                }

            DispatchQueue.main.async {
                allAlbums = albums
                let recents = albums.first(where: { $0.assetCollectionSubtype == .smartAlbumRecentlyAdded })
                    ?? albums.first(where: { $0.assetCollectionSubtype == .smartAlbumUserLibrary })
                    ?? albums.first
                if let r = recents { selectAlbum(r) } else { isLoading = false }
            }
        }
    }

    private func selectAlbum(_ album: PHAssetCollection) {
        selectedAlbum = album
        selectedAlbumTitle = album.localizedTitle ?? "Recents"
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let opts = PHFetchOptions()
            opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            opts.predicate = NSPredicate(format: "mediaType == %d OR mediaType == %d",
                                         PHAssetMediaType.image.rawValue,
                                         PHAssetMediaType.video.rawValue)
            let result = PHAsset.fetchAssets(in: album, options: opts)
            var fetched: [PHAsset] = []
            result.enumerateObjects { a, _, _ in fetched.append(a) }
            DispatchQueue.main.async {
                assets = fetched
                isLoading = false
            }
        }
    }
}

// MARK: - Asset Thumbnail Cell
private struct AssetThumbnailCell: View {
    let asset: PHAsset
    let imageManager: PHCachingImageManager
    let thumbnailSize: CGSize
    let onTap: () -> Void

    @State private var thumbnail: UIImage? = nil
    private var isVideo: Bool { asset.mediaType == .video }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                if let img = thumbnail {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.width).clipped()
                } else {
                    Rectangle()
                        .fill(Color(UIColor.secondarySystemBackground))
                        .frame(width: geo.size.width, height: geo.size.width)
                        .overlay(ProgressView().scaleEffect(0.7))
                }
                if isVideo {
                    HStack(spacing: 4) {
                        Image(systemName: "video.fill").font(.system(size: 10, weight: .semibold))
                        Text(durationString(asset.duration)).font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 4).shadow(radius: 2)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
            .onAppear { loadThumbnail(size: thumbnailSize) }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func loadThumbnail(size: CGSize) {
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .opportunistic
        opts.resizeMode = .fast
        opts.isNetworkAccessAllowed = true
        imageManager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: opts) { img, _ in
            if let img { DispatchQueue.main.async { thumbnail = img } }
        }
    }

    private func durationString(_ d: TimeInterval) -> String {
        String(format: "%d:%02d", Int(d) / 60, Int(d) % 60)
    }
}
