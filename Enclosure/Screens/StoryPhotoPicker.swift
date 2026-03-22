import SwiftUI
import Photos
import PhotosUI

// MARK: - Liquid Glass helper
private extension View {
    @ViewBuilder
    func liquidGlass<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(in: shape)
        } else {
            self.background(.thinMaterial, in: shape)
        }
    }
}

// MARK: - Album model (name + count + cover thumbnail)
private struct AlbumItem: Identifiable {
    let id: String
    let collection: PHAssetCollection
    let title: String
    let count: Int
    var thumbnail: UIImage? = nil
}

// MARK: - Story Photo Picker (iOS native Photos-style, multi-select)
struct StoryPhotoPicker: View {
    @Environment(\.dismiss) private var dismiss

    /// Called with the final assets + caption after the user taps "Add to Story" in preview.
    var onPost: (([PHAsset], String) -> Void)? = nil

    // Albums
    @State private var allAlbums: [AlbumItem] = []
    @State private var selectedAlbumTitle: String = "All Photos"
    @State private var showAlbumDropdown = false

    // Assets
    @State private var assets: [PHAsset] = []
    @State private var isLoading: Bool = true
    @State private var permissionDenied: Bool = false

    // Multi-select
    @State private var selectedAssets: [PHAsset] = []

    // Navigation
    @State private var showCameraView: Bool = false
    @State private var showPreview: Bool = false

    // Header height for dropdown positioning
    @State private var headerHeight: CGFloat = 0

    private let imageManager = PHCachingImageManager()
    private let albumImageManager = PHCachingImageManager()
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
                    // Center: Album picker button
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAlbumDropdown.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedAlbumTitle)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.primary)
                            Image(systemName: showAlbumDropdown ? "chevron.up" : "chevron.down")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                                .animation(.easeInOut(duration: 0.2), value: showAlbumDropdown)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .liquidGlass(in: Capsule())
                    }

                    HStack {
                        // Left: Cancel
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 36, height: 36)
                                .liquidGlass(in: Circle())
                        }

                        Spacer()

                        // Right: Next button (visible when assets are selected)
                        if !selectedAssets.isEmpty {
                            Button {
                                showPreview = true
                            } label: {
                                HStack(spacing: 4) {
                                    Text("Next")
                                        .font(.system(size: 15, weight: .semibold))
                                    Text("\(selectedAssets.count)")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 20, height: 20)
                                        .background(Circle().fill(Color(hex: Constant.themeColor)))
                                }
                                .foregroundColor(Color(hex: Constant.themeColor))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .liquidGlass(in: Capsule())
                            }
                            .transition(.opacity.combined(with: .scale))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .animation(.easeInOut(duration: 0.2), value: selectedAssets.isEmpty)
                .background(
                    GeometryReader { geo in
                        Color.clear.onAppear { headerHeight = geo.size.height }
                    }
                )

                Divider()

                // ── Text + Camera cards ──
                if !permissionDenied {
                    HStack(spacing: 12) {
                        // Text card
                        Button { /* future: text story */ } label: {
                            VStack(spacing: 5) {
                                Image(systemName: "textformat")
                                    .font(.system(size: 20, weight: .regular))
                                    .foregroundColor(Color("TextColor"))
                                Text("Text")
                                    .font(.custom("Inter18pt-Regular", size: 12))
                                    .foregroundColor(Color("TextColor"))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .liquidGlass(in: RoundedRectangle(cornerRadius: 14))
                        }

                        // Camera card
                        Button { handleCameraButtonClick() } label: {
                            VStack(spacing: 5) {
                                Image(systemName: "camera")
                                    .font(.system(size: 20, weight: .regular))
                                    .foregroundColor(Color("TextColor"))
                                Text("Camera")
                                    .font(.custom("Inter18pt-Regular", size: 12))
                                    .foregroundColor(Color("TextColor"))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .liquidGlass(in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
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

            // ── Album Dropdown Overlay ──
            if showAlbumDropdown {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) { showAlbumDropdown = false }
                    }

                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(allAlbums) { item in
                                AlbumRow(item: item, isSelected: item.title == selectedAlbumTitle) {
                                    withAnimation(.easeInOut(duration: 0.2)) { showAlbumDropdown = false }
                                    selectAlbum(item.collection)
                                }
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    .frame(maxHeight: 420)
                }
                .liquidGlass(in: RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 4)
                .padding(.horizontal, 16)
                .padding(.top, headerHeight + 16)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
            }
        }
        // Camera
        .fullScreenCover(isPresented: $showCameraView) {
            StoryCameraOnlyView { assets, caption in
                onPost?(assets, caption)
                dismiss()
            }
        }
        // Preview
        .fullScreenCover(isPresented: $showPreview) {
            StoryPreviewView(assets: selectedAssets) { assets, caption in
                onPost?(assets, caption)
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
                    let selectionIndex = selectedAssets.firstIndex(where: { $0.localIdentifier == asset.localIdentifier })
                    let isSelected = selectionIndex != nil

                    AssetThumbnailCell(
                        asset: asset,
                        imageManager: imageManager,
                        thumbnailSize: thumbnailSize,
                        isSelected: isSelected,
                        selectionNumber: isSelected ? (selectionIndex! + 1) : nil
                    ) {
                        toggleSelection(asset)
                    }
                }
            }
            .padding(.top, 2)
        }
    }

    // MARK: - Selection

    private func toggleSelection(_ asset: PHAsset) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if let idx = selectedAssets.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }) {
                selectedAssets.remove(at: idx)
            } else {
                selectedAssets.append(asset)
            }
        }
    }

    // MARK: - Camera Handler

    private func handleCameraButtonClick() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        AndroidStylePermissionManager.shared.requestPermissionWithDialogFromTopVC(for: .camera) { granted in
            DispatchQueue.main.async {
                if granted { showCameraView = true }
            }
        }
    }

    // MARK: - Photo Library

    private func requestPhotoAccess() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited: loadAlbums()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { s in
                DispatchQueue.main.async {
                    if s == .authorized || s == .limited { loadAlbums() }
                    else { isLoading = false; permissionDenied = true }
                }
            }
        default:
            isLoading = false
            permissionDenied = true
        }
    }

    private func loadAlbums() {
        DispatchQueue.global(qos: .userInitiated).async {
            var items: [AlbumItem] = []

            func addCollection(_ col: PHAssetCollection) {
                let assets = PHAsset.fetchAssets(in: col, options: nil)
                guard assets.count > 0 else { return }
                let title = col.localizedTitle ?? "Album"
                var item = AlbumItem(id: col.localIdentifier, collection: col,
                                     title: "\(title) (\(assets.count))", count: assets.count)
                if let first = assets.firstObject {
                    let opts = PHImageRequestOptions()
                    opts.isSynchronous = true
                    opts.deliveryMode = .fastFormat
                    PHImageManager.default().requestImage(
                        for: first, targetSize: CGSize(width: 80, height: 80),
                        contentMode: .aspectFill, options: opts
                    ) { img, _ in item.thumbnail = img }
                }
                items.append(item)
            }

            let smartSubtypes: [PHAssetCollectionSubtype] = [
                .smartAlbumUserLibrary, .smartAlbumRecentlyAdded, .smartAlbumFavorites,
                .smartAlbumVideos, .smartAlbumSlomoVideos, .smartAlbumTimelapses,
                .smartAlbumPanoramas, .smartAlbumScreenshots, .smartAlbumBursts,
                .smartAlbumSelfPortraits, .smartAlbumLivePhotos, .smartAlbumDepthEffect,
                .smartAlbumLongExposures
            ]
            for subtype in smartSubtypes {
                PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: subtype, options: nil)
                    .enumerateObjects { col, _, _ in addCollection(col) }
            }
            PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
                .enumerateObjects { col, _, _ in addCollection(col) }
            PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumSyncedAlbum, options: nil)
                .enumerateObjects { col, _, _ in addCollection(col) }

            DispatchQueue.main.async {
                allAlbums = items
                let defaultAlbum = items.first(where: { $0.collection.assetCollectionSubtype == .smartAlbumUserLibrary })
                    ?? items.first
                if let a = defaultAlbum { selectAlbum(a.collection) } else { isLoading = false }
            }
        }
    }

    private func selectAlbum(_ album: PHAssetCollection) {
        let rawTitle = album.localizedTitle ?? "All Photos"
        selectedAlbumTitle = rawTitle
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

// MARK: - Album Row
private struct AlbumRow: View {
    let item: AlbumItem
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Text(item.title)
                    .font(.system(size: 17, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Spacer()
                if let thumb = item.thumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(UIColor.tertiarySystemFill))
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Asset Thumbnail Cell (with multi-select overlay)
private struct AssetThumbnailCell: View {
    let asset: PHAsset
    let imageManager: PHCachingImageManager
    let thumbnailSize: CGSize
    let isSelected: Bool
    let selectionNumber: Int?
    let onTap: () -> Void

    @State private var thumbnail: UIImage? = nil
    private var isVideo: Bool { asset.mediaType == .video }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                // Thumbnail
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

                // Video badge
                if isVideo {
                    HStack(spacing: 4) {
                        Image(systemName: "video.fill").font(.system(size: 10, weight: .semibold))
                        Text(durationString(asset.duration)).font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 4).shadow(radius: 2)
                }

                // Selection dim overlay
                if isSelected {
                    Color.black.opacity(0.25)
                        .frame(width: geo.size.width, height: geo.size.width)
                }
            }
            .overlay(alignment: .topTrailing) {
                // Selection number badge
                ZStack {
                    if isSelected, let num = selectionNumber {
                        Circle()
                            .fill(Color(hex: Constant.themeColor))
                            .frame(width: 26, height: 26)
                        Text("\(num)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Color.black.opacity(0.2)))
                    }
                }
                .padding(6)
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
