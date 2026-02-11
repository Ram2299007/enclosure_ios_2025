import Foundation

struct VoiceCallPayload: Identifiable, Equatable {
    let id = UUID()
    let receiverId: String
    let receiverName: String
    let receiverPhoto: String
    let receiverToken: String
    let receiverDeviceType: String
    let receiverPhone: String
    let roomId: String?
    let isSender: Bool
    
    // Equatable conformance - compare by id
    static func == (lhs: VoiceCallPayload, rhs: VoiceCallPayload) -> Bool {
        return lhs.id == rhs.id
    }
}
