//
//  WhatsAppLikeContactPicker.swift
//  Enclosure
//
//  Created by Ram Lohar on 30/04/25.
//

import SwiftUI
import Contacts
import UIKit

struct ContactPickerInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let phone: String?
    let email: String?
    
    var displayName: String {
        name.isEmpty ? "Unknown" : name
    }
    
    var initial: String {
        guard !name.isEmpty else { return "?" }
        return String(name.prefix(1)).uppercased()
    }
}

struct WhatsAppLikeContactPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    let maxSelection: Int
    let onContactsSelected: ([ContactPickerInfo], String) -> Void
    
    @State private var allContacts: [ContactPickerInfo] = []
    @State private var filteredContacts: [ContactPickerInfo] = []
    @State private var selectedContactIds: Set<String> = []
    @State private var captionText: String = ""
    @State private var isLoading: Bool = true
    @State private var searchText: String = ""
    @State private var isMessageBoxFocused: Bool = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var isPressed: Bool = false
    @FocusState private var isCaptionFocused: Bool
    @FocusState private var isSearchFocused: Bool
    
    private let contactStore = CNContactStore()
    
    // Typography (match Android messageBox sizing prefs)
    private var messageInputFont: Font {
        let pref = UserDefaults.standard.string(forKey: "Font_Size") ?? "medium"
        let size: CGFloat
        switch pref {
        case "small":
            size = 13
        case "large":
            size = 19
        default:
            size = 16
        }
        return .custom("Inter18pt-Regular", size: size)
    }
    
    init(maxSelection: Int = 50, onContactsSelected: @escaping ([ContactPickerInfo], String) -> Void) {
        self.maxSelection = maxSelection
        self.onContactsSelected = onContactsSelected
    }
    
    var body: some View {
        ZStack {
            // Background matching Android bottom_sheet_background
            Color("chattingMessageBox")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Cancel button and Search bar - top (matching Android layout)
                HStack(spacing: 0) {
                    // Cancel button (matching WhatsAppLikeImagePicker positioning)
                    Button(action: {
                        handleCancel()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color("circlebtnhover").opacity(0.1))
                                .frame(width: 40, height: 40)
                            
                            if isPressed {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 40, height: 40)
                                    .scaleEffect(isPressed ? 1.2 : 1.0)
                                    .animation(.easeOut(duration: 0.3), value: isPressed)
                            }
                            
                            Image("leftvector")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 25, height: 18)
                                .foregroundColor(Color("TextColor"))
                        }
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { _ in
                                withAnimation {
                                    isPressed = false
                                }
                            }
                    )
                    .buttonStyle(.plain)
                    .padding(.leading, 16)
                    .padding(.trailing, 10)
                    
                    // Search bar (matching Android searchEditText - textColor adapts to light/dark mode)
                    ZStack(alignment: .leading) {
                        // Placeholder hint color (android:textColorHint="@color/gray")
                        if searchText.isEmpty {
                            Text("Search contacts...")
                                .font(.custom("Inter18pt-Regular", size: 16))
                                .foregroundColor(Color("gray")) // android:textColorHint="@color/gray"
                                .padding(.leading, 16)
                        }
                        
                        TextField("", text: $searchText)
                            .font(.custom("Inter18pt-Regular", size: 16))
                            .foregroundColor(colorScheme == .light ? Color("TextColor") : .white) // Black in light mode, white in dark mode
                            .accentColor(colorScheme == .light ? Color("TextColor") : .white) // Cursor color adapts to mode
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .focused($isSearchFocused)
                            .onChange(of: searchText) { newValue in
                                filterContacts(query: newValue)
                            }
                    }
                    .frame(minHeight: 45)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color("circlebtnhover")) // android:backgroundTint="@color/circlebtnhover"
                    )
                }
                .padding(.top, 20) // android:layout_marginTop="20dp"
                .padding(.horizontal, 16) // android:padding="16dp"
                
                // Contact List (matching Android RecyclerView)
                if isLoading {
                    ProgressView()
                        .progressViewStyle(LinearProgressViewStyle(tint: Color("TextColor")))
                        .frame(height: 4)
                        .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredContacts) { contact in
                                ContactRowView(
                                    contact: contact,
                                    isSelected: selectedContactIds.contains(contact.id),
                                    canSelect: selectedContactIds.contains(contact.id) || selectedContactIds.count < maxSelection,
                                    onTap: {
                                        toggleSelection(for: contact)
                                    }
                                )
                            }
                        }
                    }
                    .padding(.top, 10)
                }
                
                Spacer(minLength: 0)
                
                // Caption bar + Done button (matching Android captionlyt and WhatsAppLikeImagePicker)
                captionBarView
                    .padding(.bottom, keyboardHeight > 0 ? keyboardHeight - 20 : 10)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            requestContactsAndLoad()
            setupKeyboardObservers()
        }
        .onDisappear {
            removeKeyboardObservers()
        }
    }
    
    // MARK: - Caption Bar View (matching CameraGalleryView and WhatsAppLikeImagePicker design)
    private var captionBarView: some View {
        HStack(spacing: 0) {
            // Caption input container (matching messageBox design from CameraGalleryView)
            HStack(spacing: 0) {
                // Message input field container - layout_weight="1"
                VStack(alignment: .leading, spacing: 0) {
                    TextField("Add Caption", text: $captionText, axis: .vertical)
                        .font(messageInputFont)
                        .foregroundColor(Color("black_white_cross"))
                        .lineLimit(4)
                        .frame(maxWidth: 180, alignment: .leading)
                        .padding(.leading, 10) // start padding 10px
                        .padding(.trailing, 20)
                        .padding(.top, 5)
                        .padding(.bottom, 5)
                        .background(Color.clear)
                        .focused($isCaptionFocused)
                        .onChange(of: isCaptionFocused) { focused in
                            isMessageBoxFocused = focused
                        }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 50) // Match send button height (50dp)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color("circlebtnhover")) // match Android backgroundTint on message_box_bg
            )
            .padding(.leading, 10)
            .padding(.trailing, 5)
            
            // Send button group (matching sendGrpLyt from CameraGalleryView)
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    Button(action: {
                        handleDone()
                    }) {
                        ZStack {
                            Circle()
                                .fill(selectedContactIds.count > 0 ? Color(hex: Constant.themeColor) : Color(hex: Constant.themeColor))
                                .frame(width: 50, height: 50)
                            
                            // Send icon (keyboard double arrow right) - same as Android
                            Image("baseline_keyboard_double_arrow_right_24")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 26, height: 26)
                                .foregroundColor(.white)
                                .padding(.top, 4)
                                .padding(.bottom, 8)
                        }
                    }
                    .disabled(selectedContactIds.count == 0)
                    .opacity(selectedContactIds.count > 0 ? 1.0 : 0.5)
                }
                
                // Small counter badge (Android multiSelectSmallCounterText)
                if selectedContactIds.count > 0 {
                    Text("\(selectedContactIds.count)")
                        .font(.custom("Inter18pt-Bold", size: 12))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(Color(hex: Constant.themeColor)) // match Android counter tint
                        )
                        .offset(x: -13, y: -30) // lift badge above send button with extra right margin
                }
            }
            .padding(.horizontal, 5)
        }
    }
    
    // MARK: - Contact Row View (matching contact_picker_row.xml)
    private struct ContactRowView: View {
        @Environment(\.colorScheme) var colorScheme
        let contact: ContactPickerInfo
        let isSelected: Bool
        let canSelect: Bool
        let onTap: () -> Void
        
        var body: some View {
            HStack(spacing: 0) {
                // Selection indicator (matching Android selectionIndicator)
                if isSelected {
                    Rectangle()
                        .fill(Color("TextColor"))
                        .frame(width: 4)
                        .padding(.trailing, 16)
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 4)
                        .padding(.trailing, 16)
                }
                
                // Contact Avatar (matching Android contactAvatar)
                ZStack {
                    Circle()
                        .fill(Color("modetheme2"))
                        .frame(width: 48, height: 48)
                    
                    Text(contact.initial)
                        .font(.custom("Inter18pt-Bold", size: 18))
                        .foregroundColor(Color("TextColor"))
                }
                .padding(.trailing, 16)
                
                // Contact Info (matching Android contact info layout)
                VStack(alignment: .leading, spacing: 4) {
                    Text(contact.displayName)
                        .font(.custom("Inter18pt-Bold", size: 16))
                        .foregroundColor(Color("TextColor"))
                    
                    if let phone = contact.phone, !phone.isEmpty {
                        Text(phone)
                            .font(.custom("Inter18pt-Regular", size: 14))
                            .foregroundColor(Color("TextColor"))
                            .opacity(0.7)
                    }
                    
                    if let email = contact.email, !email.isEmpty {
                        Text(email)
                            .font(.custom("Inter18pt-Regular", size: 14))
                            .foregroundColor(Color("TextColor"))
                            .opacity(0.7)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Selection Check Icon (matching Android selectionCheckIcon)
                if isSelected {
                    ZStack {
                        Circle()
                            .fill(Color("BackgroundColor"))
                            .frame(width: 24, height: 24)
                        
                        Image("multitick")
                            .renderingMode(.template) // Enable template rendering for color tinting
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundColor(colorScheme == .light ? .black : .white) // Black in light mode, white in dark mode
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color("circlebtnhover"))
            )
            .opacity(canSelect ? 1.0 : 0.5)
            .contentShape(Rectangle())
            .onTapGesture {
                if canSelect {
                    onTap()
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func toggleSelection(for contact: ContactPickerInfo) {
        if selectedContactIds.contains(contact.id) {
            selectedContactIds.remove(contact.id)
        } else {
            guard selectedContactIds.count < maxSelection else { return }
            selectedContactIds.insert(contact.id)
        }
    }
    
    private func handleDone() {
        guard !selectedContactIds.isEmpty else { return }
        
        let selectedContacts = allContacts.filter { selectedContactIds.contains($0.id) }
        onContactsSelected(selectedContacts, captionText.trimmingCharacters(in: .whitespacesAndNewlines))
        dismiss()
    }
    
    private func handleCancel() {
        // Matching Android handleBackPress: if messageBox is focused, clear focus; otherwise dismiss
        if isMessageBoxFocused || isCaptionFocused {
            // Clear focus and hide keyboard
            isCaptionFocused = false
            isMessageBoxFocused = false
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        } else {
            // Dismiss with animation matching CameraGalleryView
            withAnimation {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                dismiss()
                isPressed = false
            }
        }
    }
    
    private func requestContactsAndLoad() {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized:
            loadAllContacts()
        case .notDetermined:
            contactStore.requestAccess(for: .contacts) { granted, error in
                DispatchQueue.main.async {
                    if granted {
                        self.loadAllContacts()
                    } else {
                        self.isLoading = false
                    }
                }
            }
        default:
            isLoading = false
        }
    }
    
    private func loadAllContacts() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            var contacts: [ContactPickerInfo] = []
            
            let keys: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor,
                CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
            ]
            
            let request = CNContactFetchRequest(keysToFetch: keys)
            request.sortOrder = .givenName
            
            do {
                try self.contactStore.enumerateContacts(with: request) { contact, stop in
                    // Only include contacts with phone numbers (matching Android HAS_PHONE_NUMBER > 0)
                    guard !contact.phoneNumbers.isEmpty else { return }
                    
                    let fullName = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
                    guard !fullName.isEmpty else { return }
                    
                    let phone = contact.phoneNumbers.first?.value.stringValue
                    let email = contact.emailAddresses.first?.value as String?
                    
                    let contactInfo = ContactPickerInfo(
                        id: contact.identifier,
                        name: fullName,
                        phone: phone,
                        email: email
                    )
                    contacts.append(contactInfo)
                }
            } catch {
                print("Error loading contacts: \(error.localizedDescription)")
            }
            
            DispatchQueue.main.async {
                print("📇 [WhatsAppContactPicker] Loaded \(contacts.count) contacts")
                self.allContacts = contacts
                self.filteredContacts = contacts
                self.isLoading = false
            }
        }
    }
    
    private func filterContacts(query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if trimmedQuery.isEmpty {
            filteredContacts = allContacts
        } else {
            filteredContacts = allContacts.filter { contact in
                contact.name.lowercased().contains(trimmedQuery) ||
                contact.phone?.lowercased().contains(trimmedQuery) ?? false ||
                contact.email?.lowercased().contains(trimmedQuery) ?? false
            }
        }
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            keyboardHeight = 0
        }
    }
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self)
    }
}

