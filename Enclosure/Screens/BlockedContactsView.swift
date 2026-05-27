import SwiftUI

struct BlockedContactsView: View {

    // Called when the list changes so SettingsView can refresh its count
    var onCountChanged: ((Int) -> Void)?

    @State private var blockedUsers: [BlockedUserModel] = []
    @State private var isLoading: Bool = true
    @State private var unblockingId: String? = nil   // uid currently being unblocked

    private var themeColor: Color { Color(hex: Constant.themeColor) }

    var body: some View {
        ZStack {
            Color("background_color").ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: themeColor))
                    .scaleEffect(1.4)
            } else if blockedUsers.isEmpty {
                emptyState
            } else {
                userList
            }
        }
        .navigationTitle("Blocked contacts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .background(NavigationGestureEnabler())
        .onAppear {
            loadBlockedUsers()
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.xmark")
                .font(.system(size: 52))
                .foregroundColor(Color("TextColor").opacity(0.3))
            Text("No blocked contacts")
                .font(.custom("Inter18pt-Medium", size: 16))
                .foregroundColor(Color("TextColor").opacity(0.5))
        }
    }

    // MARK: - User List
    private var userList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(blockedUsers) { user in
                    BlockedUserRow(
                        user: user,
                        isUnblocking: unblockingId == user.id,
                        onUnblock: { unblock(user) }
                    )
                    Divider()
                        .padding(.leading, 86)
                        .opacity(0.4)
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Load
    private func loadBlockedUsers() {
        isLoading = true
        ApiService.getBlockedUsers(uid: Constant.SenderIdMy) { users in
            DispatchQueue.main.async {
                blockedUsers = users
                isLoading = false
                onCountChanged?(users.count)
            }
        }
    }

    // MARK: - Unblock
    private func unblock(_ user: BlockedUserModel) {
        guard unblockingId == nil else { return }
        unblockingId = user.id

        ApiService.unblockUser(uid: Constant.SenderIdMy, blockedUid: user.id) { success, message in
            DispatchQueue.main.async {
                unblockingId = nil
                if success {
                    blockedUsers.removeAll { $0.id == user.id }
                    onCountChanged?(blockedUsers.count)
                    Constant.showToast(message: "\(user.fullName) unblocked")
                } else {
                    Constant.showToast(message: "Could not unblock: \(message)")
                }
            }
        }
    }
}

// MARK: - Row (matches chat list ContactCardView style exactly)
private struct BlockedUserRow: View {
    let user: BlockedUserModel
    let isUnblocking: Bool
    let onUnblock: () -> Void

    private var themeColor: Color { Color(hex: Constant.themeColor) }
    private var borderColor: Color { themeColor }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {

            // ── Avatar (same as chatView.CardView) ────────────────────
            ZStack {
                // Themed circle border — matches every other contact row
                Circle()
                    .stroke(borderColor, lineWidth: 2)
                    .frame(width: 54, height: 54)

                CachedAsyncImage(url: URL(string: user.photo)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } placeholder: {
                    Image("inviteimg")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                }
                .frame(width: 50, height: 50)
            }
            .frame(width: 54, height: 54)          // ← explicit frame prevents ZStack expanding
            .padding(.leading, 1)
            .padding(.trailing, 16)

            // ── Name ──────────────────────────────────────────────────
            Text(Constant.formatNameWithYou(uid: user.id, fullName: user.fullName))
                .font(.custom("Inter18pt-SemiBold", size: 16))   // matches chat list font
                .foregroundColor(Color("TextColor"))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // ── Unblock button ────────────────────────────────────────
            if isUnblocking {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: themeColor))
                    .frame(width: 76, height: 34)
            } else {
                Button(action: onUnblock) {
                    Text("Unblock")
                        .font(.custom("Inter18pt-Medium", size: 13))
                        .foregroundColor(themeColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(themeColor, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
            }

            // small trailing gap
            Spacer().frame(width: 16)
        }
        .padding(.leading, 10)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
