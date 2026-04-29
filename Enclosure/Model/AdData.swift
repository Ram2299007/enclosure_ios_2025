import Foundation

struct AdData: Identifiable {
    let id: String
    let uid: String
    let title: String
    let description: String
    let link: String
    let status: String
    let endDate: String
    let totalBudget: Double
    let mediaURLs: [URL]
    let ownerName: String
    let ownerPhotoURL: URL?
    let createdAt: TimeInterval  // unix seconds

    init?(dict: [String: Any]) {
        guard let rawId = dict["id"] else { return nil }
        id = "\(rawId)"
        uid = "\(dict["uid"] ?? "")"
        title = dict["title"] as? String ?? ""
        description = dict["description"] as? String ?? ""
        link = dict["link"] as? String ?? ""
        status = dict["status"] as? String ?? ""
        endDate = dict["end_date"] as? String ?? ""
        totalBudget = (dict["total_budget"] as? Double)
            ?? Double(dict["total_budget"] as? String ?? "") ?? 0

        // API returns media as [String] of absolute URLs
        if let arr = dict["media"] as? [String] {
            mediaURLs = arr.compactMap { URL(string: $0) }
        } else if let str = dict["media"] as? String, !str.isEmpty {
            mediaURLs = str.split(separator: ",")
                .compactMap { URL(string: String($0).trimmingCharacters(in: .whitespaces)) }
        } else {
            mediaURLs = []
        }

        ownerName = dict["owner_name"] as? String ?? ""
        if let photo = dict["owner_photo"] as? String, !photo.isEmpty {
            let full = photo.hasPrefix("http") ? photo : Constant.baseURL + photo
            ownerPhotoURL = URL(string: full)
        } else {
            ownerPhotoURL = nil
        }
        createdAt = dict["created_at"] as? TimeInterval ?? 0
    }
}
