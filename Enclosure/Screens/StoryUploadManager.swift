import Foundation
import Photos

// MARK: - Story Models
struct UserStory: Identifiable {
    let id: String
    let storyType: String        // "media" | "text"
    let textContent: String
    let bgType: String
    let bgColor: String
    let gradientStart: String
    let gradientMid: String
    let gradientEnd: String
    let fontIndex: Int
    let mediaItems: [StoryMediaItem]
    let caption: String
    let createdAt: String
    let viewsCount: Int

    init?(dict: [String: Any]) {
        guard let id = dict["id"] as? String else { return nil }
        self.id            = id
        self.storyType     = dict["story_type"]      as? String ?? ""
        self.textContent   = dict["text_content"]    as? String ?? ""
        self.bgType        = dict["bg_type"]         as? String ?? ""
        self.bgColor       = dict["bg_color"]        as? String ?? ""
        self.gradientStart = dict["gradient_start"]  as? String ?? ""
        self.gradientMid   = dict["gradient_mid"]    as? String ?? ""
        self.gradientEnd   = dict["gradient_end"]    as? String ?? ""
        self.fontIndex     = (dict["font_index"] as? NSNumber)?.intValue
                          ?? Int(dict["font_index"] as? String ?? "") ?? 0
        self.caption       = dict["caption"]         as? String ?? ""
        self.createdAt     = dict["created_at"]      as? String ?? ""
        let raw = dict["media_items"] as? [[String: Any]] ?? []
        self.mediaItems = raw.compactMap { StoryMediaItem(dict: $0) }
        self.viewsCount    = (dict["views_count"] as? NSNumber)?.intValue
                          ?? Int(dict["views_count"] as? String ?? "") ?? 0
    }

    /// Parsed server date — used for the real-time "5m ago" timer.
    var createdDate: Date? { StoryUploadManager.parseServerDate(createdAt) }

    /// Full URL for the first displayable thumbnail.
    /// For images: thumbnailURL → mediaURL. For videos: thumbnailURL only (mp4 can't be shown as image).
    var firstThumbnailURL: URL? {
        guard storyType == "media", let item = mediaItems.first else { return nil }
        let path: String
        if item.mediaType == "video" {
            path = item.thumbnailURL   // only use thumbnail; don't fall back to .mp4
        } else {
            path = item.thumbnailURL.isEmpty ? item.mediaURL : item.thumbnailURL
        }
        guard !path.isEmpty else { return nil }
        let full = path.hasPrefix("http") ? path : Constant.baseURL + path
        return URL(string: full)
    }
}

struct StoryMediaItem {
    let mediaURL: String
    let thumbnailURL: String
    let mediaType: String      // "image" | "video"

    init?(dict: [String: Any]) {
        self.mediaURL     = dict["media_url"]     as? String ?? ""
        self.thumbnailURL = dict["thumbnail_url"] as? String ?? ""
        self.mediaType    = dict["media_type"]    as? String ?? ""
    }
}

// MARK: - Contact Story Group
struct ContactStoryGroup: Identifiable {
    let id: String          // uid of the contact
    let fullName: String
    let photo: String
    let stories: [UserStory]

    /// Profile photo full URL
    var photoURL: URL? {
        guard !photo.isEmpty else { return nil }
        let full = photo.hasPrefix("http") ? photo : Constant.baseURL + photo
        return URL(string: full)
    }

    /// Most recent story's createdDate (for "Xm ago" badge)
    var latestDate: Date? { stories.first?.createdDate }

    init?(dict: [String: Any]) {
        guard let uid = dict["uid"] as? String else { return nil }
        self.id       = uid
        self.fullName = dict["full_name"] as? String ?? ""
        self.photo    = dict["photo"]     as? String ?? ""
        let raw = dict["stories"] as? [[String: Any]] ?? []
        self.stories  = raw.compactMap { UserStory(dict: $0) }
        guard !self.stories.isEmpty else { return nil }
    }
}

// MARK: - Story Upload Manager
// Singleton — state persists even when StoryBottomSheetView is dismissed/recreated.
final class StoryUploadManager: ObservableObject {
    static let shared = StoryUploadManager()
    private init() {}

    @Published var isUploading  = false
    @Published var progress: Double = 0.0   // 0.0 → 1.0
    @Published var lastPostedAt: Date? = nil
    @Published var myStories: [UserStory] = []
    @Published var contactStoryGroups: [ContactStoryGroup] = []

    // MARK: - Date parsing (server uses "yyyy-MM-dd HH:mm:ss" UTC)
    static func parseServerDate(_ str: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale     = Locale(identifier: "en_US_POSIX")
        // No forced timezone — server stores local time with no UTC offset in the string
        return f.date(from: str)
    }

    // MARK: - Fetch
    func fetchMyStories() {
        ApiService.shared.fetchMyStories { [weak self] stories in
            DispatchQueue.main.async {
                self?.myStories = stories
                // Restore the real-time timer from the API — survives app restarts
                if let date = stories.first?.createdDate {
                    self?.lastPostedAt = date
                }
            }
        }
    }

    func fetchContactStories() {
        ApiService.shared.fetchContactStories { [weak self] groups in
            DispatchQueue.main.async {
                self?.contactStoryGroups = groups
            }
        }
    }

    // MARK: - Delete
    func deleteStory(id: String) {
        ApiService.shared.deleteMyStory(storyId: id) { [weak self] success in
            guard success else { return }
            DispatchQueue.main.async {
                self?.myStories.removeAll { $0.id == id }
                // Keep timer in sync after deletion
                if let date = self?.myStories.first?.createdDate {
                    self?.lastPostedAt = date
                } else {
                    self?.lastPostedAt = nil
                }
            }
        }
    }

    // MARK: - Upload media
    // Each PHAsset is uploaded as its own story so every photo/video gets a separate card.
    func uploadMedia(assets: [PHAsset], caption: String) {
        guard !assets.isEmpty else { return }
        isUploading = true
        progress    = 0.0
        uploadNextAsset(assets: assets, caption: caption, index: 0, total: assets.count)
    }

    private func uploadNextAsset(assets: [PHAsset], caption: String, index: Int, total: Int) {
        guard index < total else {
            // All assets done
            DispatchQueue.main.async {
                self.isUploading   = false
                self.progress      = 0.0
                self.lastPostedAt  = Date()
                self.fetchMyStories()
            }
            return
        }
        ApiService.shared.uploadMediaStory(
            assets: [assets[index]],
            caption: caption,
            progressHandler: { [weak self] fraction in
                DispatchQueue.main.async {
                    self?.progress = (Double(index) + fraction) / Double(total)
                }
            }
        ) { [weak self] _, _ in
            // Proceed to the next asset regardless of success/failure
            self?.uploadNextAsset(assets: assets, caption: caption, index: index + 1, total: total)
        }
    }

    // MARK: - Upload text
    func uploadText(textContent: String, bgType: String, bgColor: String,
                    gradStart: String, gradMid: String, gradEnd: String, fontIndex: Int) {
        isUploading = true
        progress    = 0.0
        ApiService.shared.uploadTextStory(
            textContent: textContent, bgType: bgType, bgColor: bgColor,
            gradientStart: gradStart, gradientMid: gradMid, gradientEnd: gradEnd,
            fontIndex: fontIndex
        ) { [weak self] success, _ in
            DispatchQueue.main.async {
                self?.isUploading = false
                self?.progress    = 0.0
                if success {
                    self?.lastPostedAt = Date()
                    self?.fetchMyStories()
                }
            }
        }
    }
}
