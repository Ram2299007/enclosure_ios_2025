import SwiftUI

/// Full-screen sheet showing contacts to invite to the current call.
/// Matches Android's `multiple_group_recyclerview` layout.
struct AddMemberSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AddMemberViewModel

    init(roomId: String, isVideoCall: Bool, currentReceiverId: String) {
        _viewModel = StateObject(wrappedValue: AddMemberViewModel(
            roomId: roomId,
            isVideoCall: isVideoCall,
            currentReceiverId: currentReceiverId
        ))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                searchBar

                // Content
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Loading contacts...")
                        .foregroundColor(.gray)
                    Spacer()
                } else if viewModel.filteredContacts.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.5))
                        Text(viewModel.searchText.isEmpty ? "No contacts available" : "No results found")
                            .foregroundColor(.gray)
                            .font(.subheadline)
                    }
                    Spacer()
                } else {
                    contactList
                }
            }
            .navigationTitle("Add Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .onAppear {
            viewModel.fetchContacts()
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search contacts...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Contact List

    private var contactList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.filteredContacts, id: \.uid) { contact in
                    contactRow(contact)
                    Divider()
                        .padding(.leading, 72)
                }
            }
        }
    }

    // MARK: - Contact Row

    private func contactRow(_ contact: CallingContactModel) -> some View {
        HStack(spacing: 12) {
            // Profile photo
            AsyncImage(url: URL(string: contact.photo)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    firstLetterAvatar(name: contact.fullName)
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())

            // Name + number
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.fullName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(contact.mobileNo)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            Spacer()

            // Invite button
            Button {
                viewModel.inviteContact(contact) { success in
                    if success {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            dismiss()
                        }
                    }
                }
            } label: {
                Text(viewModel.inviteSent ? "Invited" : "Invite")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(viewModel.inviteSent ? Color.gray : Color.blue)
                    .cornerRadius(20)
            }
            .disabled(viewModel.inviteSent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - First Letter Avatar

    private func firstLetterAvatar(name: String) -> some View {
        let letter = String(name.prefix(1)).uppercased()
        return ZStack {
            Circle()
                .fill(Color.blue.opacity(0.2))
            Text(letter)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.blue)
        }
    }
}
