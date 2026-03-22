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

// MARK: - Album model
private struct AlbumItem: Identifiable {
    let id: String
    let collection: PHAssetCollection
    let title: String
    let count: Int
    var thumbnail: UIImage? = nil
}

// MARK: - Story Photo Picker
struct StoryPhotoPicker: View {
    @Environment(\.dismiss) private var dismiss
    var onPost: (([PHAsset], String) -> Void)? = nil

    @State private var allAlbums: [AlbumItem] = []
    @State private var selectedAlbumTitle: String = "All Photos"
    @State private var showAlbumDropdown = false
    @State private var assets: [PHAsset] = []
    @State private var isLoading: Bool = true
    @State private var permissionDenied: Bool = false
    @State private var selectedAssets: [PHAsset] = []
    @State private var showCameraView: Bool = false
    @State private var showPreview: Bool = false
    @State private var showTextEditor: Bool = false
    @State private var headerHeight: CGFloat = 0

    private let imageManager = PHCachingImageManager()
    private let albumImageManager = PHCachingImageManager()
    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    private let thumbnailSize = CGSize(width: 300, height: 300)

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                    .background(
                        GeometryReader { geo in
                            Color.clear.onAppear { headerHeight = geo.size.height }
                        }
                    )

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

            // Album dropdown overlay
            if showAlbumDropdown {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.22)) { showAlbumDropdown = false }
                    }

                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(allAlbums) { item in
                                AlbumRow(item: item, isSelected: item.title == selectedAlbumTitle) {
                                    withAnimation(.easeInOut(duration: 0.22)) { showAlbumDropdown = false }
                                    selectAlbum(item.collection)
                                }
                                if item.id != allAlbums.last?.id {
                                    Divider()
                                        .background(Color.white.opacity(0.08))
                                        .padding(.leading, 72)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 400)
                }
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(white: 0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 8)
                .padding(.horizontal, 12)
                .padding(.top, headerHeight + 8)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
            }
        }
        .fullScreenCover(isPresented: $showTextEditor) {
            StoryTextEditorView { assets, caption in onPost?(assets, caption); dismiss() }
        }
        .fullScreenCover(isPresented: $showCameraView) {
            StoryCameraOnlyView { assets, caption in onPost?(assets, caption); dismiss() }
        }
        .fullScreenCover(isPresented: $showPreview) {
            StoryPreviewView(assets: selectedAssets) { assets, caption in onPost?(assets, caption); dismiss() }
        }
        .onAppear { requestPhotoAccess() }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 0) {
            // Close
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)

            Spacer()

            // Album picker pill
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    showAlbumDropdown.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Text(selectedAlbumTitle)
                        .font(.custom("Inter18pt-SemiBold", size: 15))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Image(systemName: showAlbumDropdown ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(Color.white.opacity(0.12))
                )
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)

            Spacer()

            // Next button
            if !selectedAssets.isEmpty {
                Button { showPreview = true } label: {
                    HStack(spacing: 6) {
                        Text("Next")
                            .font(.custom("Inter18pt-SemiBold", size: 15))
                            .foregroundColor(.white)
                        ZStack {
                            Circle()
                                .fill(Color(hex: Constant.themeColor))
                                .frame(width: 22, height: 22)
                            Text("\(selectedAssets.count)")
                                .font(.custom("Inter18pt-Bold", size: 11))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                    .overlay(Capsule().stroke(Color(hex: Constant.themeColor).opacity(0.6), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale))
            } else {
                // Placeholder to maintain layout
                Color.clear.frame(width: 38, height: 38)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .animation(.easeInOut(duration: 0.2), value: selectedAssets.isEmpty)
    }

    // MARK: - Grid

    private var gridView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 2) {
                // Action cards row
                HStack(spacing: 2) {
                    actionCard(icon: "textformat", label: "Text") { showTextEditor = true }
                    actionCard(icon: "camera.fill", label: "Camera") { handleCameraButtonClick() }
                }
                .padding(.bottom, 2)

                // Photo grid
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(assets, id: \.localIdentifier) { asset in
                        let selIdx = selectedAssets.firstIndex(where: { $0.localIdentifier == asset.localIdentifier })
                        AssetThumbnailCell(
                            asset: asset,
                            imageManager: imageManager,
                            thumbnailSize: thumbnailSize,
                            isSelected: selIdx != nil,
                            selectionNumber: selIdx.map { $0 + 1 }
                        ) { toggleSelection(asset) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func actionCard(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }
                Text(label)
                    .font(.custom("Inter18pt-Medium", size: 13))
                    .foregroundColor(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.white.opacity(0.06))
        }
        .buttonStyle(.plain)
    }

    // MARK: - State views

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView().progressViewStyle(.circular).tint(.white).scaleEffect(1.3)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 46))
                .foregroundColor(.white.opacity(0.3))
            Text("No Photos or Videos")
                .font(.custom("Inter18pt-Medium", size: 16))
                .foregroundColor(.white.opacity(0.4))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var permissionView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 44))
                .foregroundColor(.white.opacity(0.3))
            Text("No Access to Photos")
                .font(.custom("Inter18pt-SemiBold", size: 17))
                .foregroundColor(.white)
            Text("Allow access in Settings to pick photos and videos.")
                .font(.custom("Inter18pt-Regular", size: 14))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.custom("Inter18pt-SemiBold", size: 15))
            .foregroundColor(.black)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Capsule().fill(Color.white))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Selection

    private func toggleSelection(_ asset: PHAsset) {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) {
            if let idx = selectedAssets.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }) {
                selectedAssets.remove(at: idx)
            } else {
                selectedAssets.append(asset)
            }
        }
    }

    // MARK: - Camera

    private func handleCameraButtonClick() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        AndroidStylePermissionManager.shared.requestPermissionWithDialogFromTopVC(for: .camera) { granted in
            DispatchQueue.main.async { if granted { showCameraView = true } }
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
                // Thumbnail
                Group {
                    if let thumb = item.thumbnail {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.white.opacity(0.07)
                    }
                }
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Title
                Text(item.title)
                    .font(.custom(isSelected ? "Inter18pt-SemiBold" : "Inter18pt-Regular", size: 15))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                // Checkmark for active album
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(hex: Constant.themeColor))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Asset Thumbnail Cell

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
            let size = geo.size.width

            ZStack(alignment: .bottomLeading) {
                // Thumbnail or placeholder
                Group {
                    if let img = thumbnail {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color(white: 0.14)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white.opacity(0.35))
                                    .scaleEffect(0.65)
                            )
                    }
                }
                .frame(width: size, height: size)
                .clipped()

                // Selection dim
                if isSelected {
                    Color.black.opacity(0.35).frame(width: size, height: size)
                }

                // Video duration badge (bottom-left)
                if isVideo {
                    HStack(spacing: 3) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 9, weight: .semibold))
                        Text(durationString(asset.duration))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(Color.black.opacity(0.55))
                    )
                    .padding(6)
                }
            }
            .overlay(alignment: .topTrailing) {
                // Selection badge
                selectionBadge
                    .padding(5)
            }
            // Selected: ring outline around entire cell
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(isSelected ? Color(hex: Constant.themeColor) : Color.clear, lineWidth: 2.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
            .scaleEffect(isSelected ? 0.97 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: isSelected)
            .onAppear { loadThumbnail(size: thumbnailSize) }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private var selectionBadge: some View {
        if isSelected, let num = selectionNumber {
            ZStack {
                Circle()
                    .fill(Color(hex: Constant.themeColor))
                    .frame(width: 24, height: 24)
                    .shadow(color: Color(hex: Constant.themeColor).opacity(0.5), radius: 4)
                Text("\(num)")
                    .font(.custom("Inter18pt-Bold", size: 11))
                    .foregroundColor(.white)
            }
            .transition(.scale.combined(with: .opacity))
        } else {
            Circle()
                .stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.black.opacity(0.25)))
        }
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
