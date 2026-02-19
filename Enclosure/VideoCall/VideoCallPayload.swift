import Foundation

struct VideoCallPayload: Identifiable {
    let id = UUID()
    let receiverId: String
    let receiverName: String
    let receiverPhoto: String
    let receiverToken: String
    let receiverDeviceType: String
    let receiverPhone: String
    let roomId: String?
    let isSender: Bool
}
