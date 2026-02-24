import Foundation
import Combine

/// ViewModel for the Add Member sheet in audio/video calls.
/// Fetches contacts, handles search/filter, and sends call invitation to selected contact.
final class AddMemberViewModel: ObservableObject {

    @Published var contacts: [CallingContactModel] = []
    @Published var filteredContacts: [CallingContactModel] = []
    @Published var searchText: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var inviteSent = false

    /// Current call's roomId — new member joins this room
    let roomId: String
    /// Whether this is a video call (true) or voice call (false)
    let isVideoCall: Bool
    /// The current receiver's uid (already in the call) — excluded from list
    let currentReceiverId: String

    private var cancellables = Set<AnyCancellable>()

    init(roomId: String, isVideoCall: Bool, currentReceiverId: String) {
        self.roomId = roomId
        self.isVideoCall = isVideoCall
        self.currentReceiverId = currentReceiverId

        // Auto-filter when searchText changes
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] query in
                self?.filterContacts(query: query)
            }
            .store(in: &cancellables)
    }

    // MARK: - Fetch Contacts

    func fetchContacts() {
        let uid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        guard !uid.isEmpty else {
            errorMessage = "User not logged in"
            return
        }

        isLoading = true
        errorMessage = nil

        ApiService.get_calling_contact_list(uid: uid) { [weak self] success, message, contactList in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false

                if success, let list = contactList {
                    // Exclude current user and the person already in the call
                    let myUid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
                    self.contacts = list.filter { contact in
                        contact.uid != myUid &&
                        contact.uid != self.currentReceiverId &&
                        !contact.block
                    }
                    self.filteredContacts = self.contacts
                    NSLog("📞 [AddMember] Loaded \(self.contacts.count) contacts")
                } else {
                    self.contacts = []
                    self.filteredContacts = []
                    if !message.isEmpty {
                        self.errorMessage = message
                    }
                }
            }
        }
    }

    // MARK: - Filter

    private func filterContacts(query: String) {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            filteredContacts = contacts
        } else {
            let lowered = query.lowercased()
            filteredContacts = contacts.filter {
                $0.fullName.lowercased().contains(lowered) ||
                $0.mobileNo.contains(lowered)
            }
        }
    }

    // MARK: - Send Invitation

    /// Send a call notification to the selected contact so they join the existing room.
    func inviteContact(_ contact: CallingContactModel, completion: @escaping (Bool) -> Void) {
        let myUid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""

        NSLog("📞 [AddMember] Inviting \(contact.fullName) (uid=\(contact.uid)) to room \(roomId)")

        if isVideoCall {
            MessageUploadService.shared.sendVideoCallNotification(
                receiverToken: contact.fToken,
                receiverDeviceType: contact.deviceType,
                receiverId: contact.uid,
                receiverPhone: contact.mobileNo,
                roomId: roomId,
                voipToken: contact.voipToken
            )
        } else {
            MessageUploadService.shared.sendVoiceCallNotification(
                receiverToken: contact.fToken,
                receiverDeviceType: contact.deviceType,
                receiverId: contact.uid,
                receiverPhone: contact.mobileNo,
                roomId: roomId,
                voipToken: contact.voipToken
            )
        }

        // Log group calling via API
        logGroupCalling(friendId: contact.uid, myUid: myUid)

        DispatchQueue.main.async {
            self.inviteSent = true
            completion(true)
        }
    }

    // MARK: - Log Group Calling API

    private func logGroupCalling(friendId: String, myUid: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.string(from: Date())

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "hh:mm:ss a"
        let currentTime = timeFormatter.string(from: Date())

        let callType = isVideoCall ? "2" : "1"  // 1=voice, 2=video (matches Android)
        let callingFlag = "0"  // 0=outgoing

        ApiService.create_group_calling(
            uid: myUid,
            friendId: friendId,
            invitedFriendList: "",
            date: date,
            startTime: currentTime,
            callingFlag: callingFlag,
            endTime: currentTime,
            callType: callType
        ) { success, message in
            NSLog("📞 [AddMember] create_group_calling: success=\(success), message=\(message)")
        }
    }
}
