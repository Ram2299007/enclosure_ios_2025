import SwiftUI

struct VideoCallScreen: View {
    @Environment(\.dismiss) private var dismiss
    private let payload: VideoCallPayload
    
    init(payload: VideoCallPayload) {
        self.payload = payload
    }

    var body: some View {
        NativeVideoCallScreen(payload: payload)
    }
}
