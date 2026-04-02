import SwiftUI

// MARK: - Story Contact Picker (reused for "Only share with" and "Never share with")
struct StoryOnlyShareWithView: View {
    @Environment(\.dismiss) private var dismiss
    var screenTitle: String = "Only share with"
    var preSelectedIds: Set<String> = []
    let onDone: (Set<String>) -> Void

    @StateObject private var viewModel = ChatViewModel()
    @State private var selectedIds: Set<String> = []
    @State private var searchText = ""

    private var filtered: [UserActiveContactModel] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return viewModel.chatList.filter { !$0.block } }
        return viewModel.chatList.filter { !$0.block && (
            $0.fullName.lowercased().contains(trimmed) ||
            $0.mobileNo.contains(trimmed)
        )}
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color("BackgroundColor").ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Search bar ──
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color("gray3"))
                        .font(.system(size: 16))
                    TextField("Search", text: $searchText)
                        .font(.custom("Inter18pt-Regular", size: 15))
                        .foregroundColor(Color("TextColor"))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color("gray3").opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // ── Contact list ──
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered) { contact in
                            ContactPrivacyRow(
                                contact: contact,
                                isSelected: selectedIds.contains(contact.uid)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    if selectedIds.contains(contact.uid) {
                                        selectedIds.remove(contact.uid)
                                    } else {
                                        selectedIds.insert(contact.uid)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── FAB done button ──
            Button {
                onDone(selectedIds)
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(hex: Constant.themeColor))
                        .frame(width: 56, height: 56)
                        .shadow(color: Color(hex: Constant.themeColor).opacity(0.4), radius: 8, x: 0, y: 4)
                    Image(systemName: "checkmark")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(.trailing, 20)
            .padding(.bottom, 30)
        }
        .navigationTitle(screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color("TextColor"))
                }
            }
        }
        .onAppear {
            viewModel.fetchChatList(uid: Constant.SenderIdMy)
            if selectedIds.isEmpty { selectedIds = preSelectedIds }
        }
    }
}

// MARK: - Contact Row
private struct ContactPrivacyRow: View {
    let contact: UserActiveContactModel
    let isSelected: Bool

    private var initials: String {
        contact.fullName.first.map { String($0).uppercased() } ?? "?"
    }

    private var activeLabel: String {
        guard !contact.sentTime.isEmpty,
              let date = StoryUploadManager.parseServerDate(contact.sentTime) else {
            return ""
        }
        let diff = Date().timeIntervalSince(date)
        if diff < 3600      { return "Active \(max(1, Int(diff / 60)))m ago" }
        if diff < 86400     { return "Active \(Int(diff / 3600))h ago" }
        if diff < 604800    { return "Active \(Int(diff / 86400))d ago" }
        return "Active \(Int(diff / 604800))w ago"
    }

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color(red: 0.56, green: 0.58, blue: 0.82).opacity(0.25))
                    .frame(width: 50, height: 50)
                if let url = photoURL {
                    CachedAsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    } placeholder: {
                        initialsView
                    }
                } else {
                    initialsView
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())

            // Name + active
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.fullName)
                    .font(.custom("Inter18pt-SemiBold", size: 15))
                    .foregroundColor(Color("TextColor"))
                    .lineLimit(1)
                if !activeLabel.isEmpty {
                    Text(activeLabel)
                        .font(.custom("Inter18pt-Regular", size: 13))
                        .foregroundColor(Color("gray3"))
                }
            }

            Spacer()

            // Radio circle
            ZStack {
                Circle()
                    .stroke(isSelected ? Color(hex: Constant.themeColor) : Color("gray3").opacity(0.45), lineWidth: 1.8)
                    .frame(width: 22, height: 22)
                if isSelected {
                    Circle()
                        .fill(Color(hex: Constant.themeColor))
                        .frame(width: 14, height: 14)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var photoURL: URL? {
        guard !contact.photo.isEmpty else { return nil }
        let full = contact.photo.hasPrefix("http") ? contact.photo : Constant.baseURL + contact.photo
        return URL(string: full)
    }

    private var initialsView: some View {
        Text(initials)
            .font(.custom("Inter18pt-Bold", size: 18))
            .foregroundColor(Color(red: 0.42, green: 0.44, blue: 0.72))
    }
}
