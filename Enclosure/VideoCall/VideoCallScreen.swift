import SwiftUI

struct VideoCallScreen: View {
    @Environment(\.dismiss) private var dismiss
    private let payload: VideoCallPayload
    
    init(payload: VideoCallPayload) {
        self.payload = payload
    }

    var body: some View {
        #if targetEnvironment(simulator)
        Text("Video calling is not available on Simulator")
            .font(.headline)
            .foregroundColor(.gray)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        #else
        NativeVideoCallScreen(payload: payload)
        #endif
    }
}
