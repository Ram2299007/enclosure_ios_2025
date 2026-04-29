import SwiftUI

// MARK: - Queue item type

enum StoryQueueContent {
    case stories(group: ContactStoryGroup, startIndex: Int)
    case ad(AdData)
}

// MARK: - Queue presentation wrapper (drives fullScreenCover)

struct StoryQueuePresentation: Identifiable {
    let id = UUID()
    let queue: [StoryQueueContent]
    let startIndex: Int
}

// MARK: - QueuedContentView
// Holds the queue internally and transitions between story groups and ads
// without dismissing the fullScreenCover — mirrors Android's no-animation Activity swap.

struct QueuedContentView: View {
    let queue: [StoryQueueContent]
    @Binding var shownAdIds: Set<String>
    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex: Int

    init(queue: [StoryQueueContent], startIndex: Int, shownAdIds: Binding<Set<String>>) {
        self.queue = queue
        _shownAdIds = shownAdIds
        _currentIndex = State(initialValue: max(0, min(startIndex, queue.count - 1)))
    }

    var body: some View {
        ZStack {
            if currentIndex >= 0 && currentIndex < queue.count {
                switch queue[currentIndex] {

                case .stories(let group, let si):
                    StoryViewerView(
                        stories: group.stories,
                        ownerUid: group.id,
                        ownerName: group.fullName,
                        ownerPhotoURL: group.photoURL,
                        isOwnStory: false,
                        startIndex: si,
                        onQueueAdvance: { advance() },
                        onGoBack: { goBack() }
                    )

                case .ad(let adData):
                    AdvertisePreviewView(
                        ad: adData,
                        isViewOnly: true,
                        onQueueAdvance: {
                            shownAdIds.insert(adData.id)
                            advance()
                        },
                        onGoBack: { goBack() }
                    )
                }
            }
        }
        // .id forces a full view swap (no animation — matches Android FLAG_ACTIVITY_NO_ANIMATION)
        .id(currentIndex)
    }

    private func advance() {
        let next = currentIndex + 1
        if next < queue.count {
            currentIndex = next
        } else {
            dismiss()
        }
    }

    private func goBack() {
        let prev = currentIndex - 1
        if prev >= 0 {
            currentIndex = prev
        } else {
            dismiss()
        }
    }
}
