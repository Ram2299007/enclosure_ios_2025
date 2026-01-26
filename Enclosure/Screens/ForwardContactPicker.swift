//
//  ForwardContactPicker.swift
//  Enclosure
//
//  Created for forward message functionality
//

import SwiftUI

struct ForwardContactPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    let maxSelection: Int
    let onContactsSelected: ([UserActiveContactModel]) -> Void
    
    @StateObject private var viewModel = ChatViewModel()
    @State private var selectedContactIds: Set<String> = []
    @State private var isLoading: Bool = true
    @State private var searchText: String = ""
    @State private var isPressed: Bool = false
    @FocusState private var isSearchFocused: Bool
    
    init(maxSelection: Int = 50, onContactsSelected: @escaping ([UserActiveContactModel]) -> Void) {
        self.maxSelection = maxSelection
        self.onContactsSelected = onContactsSelected
    }
    
    private var filteredContacts: [UserActiveContactModel] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return viewModel.chatList
        }
        
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return viewModel.chatList.filter { contact in
            contact.fullName.lowercased().contains(trimmed) ||
            contact.mobileNo.contains(trimmed)
        }
    }
    
    // Selected contacts for display (matching Android forwardnameAdapter)
    private var selectedContacts: [UserActiveContactModel] {
        filteredContacts.filter { selectedContactIds.contains($0.uid) }
    }
    
    // Helper function to hide keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    var body: some View {
        ZStack {
            // Background matching Android BackgroundColor style
            Color("background_color")
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    hideKeyboard()
                }
            
            VStack(spacing: 0) {
                // Header section (matching Android searchlyt)
                VStack(spacing: 0) {
                    // Top bar with cancel button and "Contacts" text (matching Android)
                    HStack(spacing: 0) {
                        // Cancel button (matching Android backarrow LinearLayout)
                        Button(action: {
                            handleCancel()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color("circlebtnhover").opacity(0.1))
                                    .frame(width: 26, height: 26)
                                
                                Image("leftvector")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 25, height: 18)
                                    .foregroundColor(Color("TextColor"))
                                    .padding(2)
                            }
                        }
                        .padding(.leading, 20) // layout_marginStart="20dp"
                        
                        // "Contacts" text (matching Android theme TextView)
                        Text("Contacts")
                            .font(.custom("Inter18pt-Medium", size: 16))
                            .fontWeight(.medium)
                            .foregroundColor(Color("TextColor"))
                            .padding(.leading, 21) // layout_marginStart="21dp"
                        
                        Spacer()
                    }
                    .padding(.top, 20) // layout_marginTop="20dp"
                    .padding(.trailing, 17) // layout_marginEnd="17dp"
                    
                    // Network loader (matching Android networkLoader)
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(LinearProgressViewStyle(tint: Color("TextColor")))
                            .frame(height: 4)
                            .padding(.top, 10) // layout_marginTop="10dp"
                    }
                    
                    // Search bar (matching Android searchLytNew LinearLayout)
                    // layout_marginTop="20dp" padding="8dp" layout_weight="1" layout_marginEnd="10dp"
                    HStack {
                        // Blue indicator line (matching Android viewnewnn)
                        Rectangle()
                            .fill(Color("blue"))
                            .frame(width: 1, height: 19.24) // layout_height="19.24dp"
                            .padding(.leading, 13)
                        
                        // Search field (matching Android searchview AutoCompleteTextView)
                        TextField("Search Name", text: $searchText)
                            .font(.custom("Inter18pt-Regular", size: 15)) // textSize="15sp"
                            .foregroundColor(Color("TextColor"))
                            .focused($isSearchFocused)
                            .lineSpacing(0) // lineHeight="22.5dp"
                            .padding(.leading, 13)
                    }
                    .padding(.top, 20) // layout_marginTop="20dp"
                    .padding(.leading, 8) // padding="8dp" (left only)
                    .padding(.trailing, 20) // Same right spacing as checkbox (20dp)
                }
                .padding(.horizontal, 0)
                
                // Contact List (matching Android recyclerview in FrameLayout)
                // FrameLayout: layout_below="@+id/searchlyt" layout_above="@id/dx" layout_marginTop="15dp"
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredContacts) { contact in
                            ForwardContactRowView(
                                contact: contact,
                                isSelected: selectedContactIds.contains(contact.uid),
                                canSelect: selectedContactIds.contains(contact.uid) || selectedContactIds.count < maxSelection,
                                onTap: {
                                    toggleSelection(for: contact)
                                }
                            )
                        }
                    }
                }
                .padding(.top, 15) // layout_marginTop="15dp" on FrameLayout
                
                Spacer()
                
                // Bottom bar (matching Android dx LinearLayout)
                // layout_height="60dp" background="@drawable/rect" backgroundTint="@color/dxForward"
                if !selectedContactIds.isEmpty {
                    HStack(spacing: 0) {
                        // Selected contacts names (matching Android namerecyclerview with forwardnameAdapter)
                        // Infinite width, keep left to the icon
                        // layout_marginStart="15dp" layout_marginEnd="5dp"
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 0) {
                                ForEach(Array(selectedContacts.enumerated()), id: \.element.uid) { index, contact in
                                    // Each name displayed as separate item (matching forwardname_row.xml)
                                    Text(displaySelectedContactName(contact: contact, index: index, total: selectedContacts.count))
                                        .font(.custom("Inter18pt-Medium", size: 13)) // textSize="13sp" fontFamily="@font/inter_medium"
                                        .foregroundColor(Color("gray3")) // textColor="@color/gray3"
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false) // wrap_content width
                                }
                            }
                            .padding(.leading, 15) // layout_marginStart="15dp"
                            .padding(.trailing, 5) // layout_marginEnd="5dp"
                        }
                        .frame(height: 40) // layout_height="40dp"
                        .frame(maxWidth: .infinity) // Infinite width - takes all available space
                        
                        // Forward icon (positioned after names, before button)
                        Image("forward_svg")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundColor(Color("TextColor"))
                            .padding(.trailing, 2) // Keep it close to the forbg button
                        
                        // Forward button container (matching Android richBox LinearLayout)
                        // android:layout_width="match_parent" android:layout_height="match_parent"
                        // android:layout_marginTop="11dp" android:layout_marginBottom="7dp"
                        // android:background="@drawable/forbg"
                        Button(action: {
                            handleForward()
                        }) {
                            // TextView inside richBox (matching Android forward TextView)
                            // android:layout_width="match_parent" android:layout_height="wrap_content"
                            // android:layout_gravity="center" android:gravity="center"
                            // android:layout_marginStart="15dp"
                            Text("Forward")
                                .font(.custom("Inter18pt-Regular", size: 16)) // android:fontFamily="@font/inter" android:textSize="16sp"
                                .fontWeight(.bold) // android:textStyle="bold"
                                .foregroundColor(Color("whitetogray")) // android:textColor="@color/whitetogray"
                                .padding(.leading, 15) // android:layout_marginStart="15dp"
                                .frame(maxWidth: .infinity) // android:layout_width="match_parent"
                                .frame(maxHeight: .infinity) // android:layout_height="wrap_content" with layout_gravity="center"
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 80) // Fixed width 80px
                        .background(
                            // Background using original forbg asset from drawable (trapezoidal shape with angled left edge)
                            Image("forbg")
                                .resizable()
                                .scaledToFill()
                        )
                        .padding(.top, 11) // android:layout_marginTop="11dp"
                        .padding(.bottom, 7) // android:layout_marginBottom="7dp"
                    }
                    .frame(height: 60) // layout_height="60dp"
                    .background(
                        // Background matching Android @drawable/rect with @color/dxForward tint
                        // android:background="@drawable/rect" android:backgroundTint="@color/dxForward"
                        Color("dxForward")
                    )
                }
            }
        }
        .navigationBarHidden(true)
        .background(NavigationGestureEnabler())
        .onAppear {
            loadContacts()
        }
        .onChange(of: viewModel.isLoading) { loading in
            if !loading {
                isLoading = false
            }
        }
        .onChange(of: viewModel.chatList.count) { count in
            if count > 0 {
                isLoading = false
            }
        }
    }
    
    // Get richBox background color based on theme (matching Android forwardAdapter logic)
    // Android applies background tint only in dark mode
    private func getRichBoxBackgroundColor() -> Color {
        // Only apply theme-based tint in dark mode (matching Android forwardAdapter)
        guard colorScheme == .dark else {
            // Light mode: use default forbg drawable color
            return Color("chattingMessageBox")
        }
        
        // Dark mode: use theme-based background tint (matching Android forwardAdapter)
        let themeColor = Constant.themeColor.lowercased()
        
        switch themeColor {
        case "#ff0080": return Color(hex: "#4D0026")
        case "#00a3e9": return Color(hex: "#01253B")
        case "#7adf2a": return Color(hex: "#25430D")
        case "#ec0001": return Color(hex: "#470000")
        case "#16f3ff": return Color(hex: "#05495D")
        case "#ff8a00": return Color(hex: "#663700")
        case "#7f7f7f": return Color(hex: "#2B3137")
        case "#d9b845": return Color(hex: "#413815")
        case "#346667": return Color(hex: "#1F3D3E")
        case "#9846d9": return Color(hex: "#2d1541")
        case "#a81010": return Color(hex: "#430706")
        default: return Color(hex: "#01253B")
        }
    }
    
    // Display selected contact name (matching Android forwardnameAdapter logic)
    // Android format: "Name1 , Name2 , Name3" (with spaces around comma, last name without comma)
    private func displaySelectedContactName(contact: UserActiveContactModel, index: Int, total: Int) -> String {
        if total == 1 {
            return contact.fullName
        } else if total > 1 {
            if index == total - 1 {
                // Last item: just the name
                return contact.fullName
            } else {
                // Not last: name + " , " (matching Android: model.getName()+" "+","+" ")
                return contact.fullName + " , "
            }
        }
        return contact.fullName
    }
    
    private func loadContacts() {
        isLoading = true
        viewModel.fetchChatList(uid: Constant.SenderIdMy)
        
        // Check loading state after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if !viewModel.isLoading {
                isLoading = false
            }
        }
        
        // Also observe when chatList is populated
        if !viewModel.chatList.isEmpty {
            isLoading = false
        }
    }
    
    private func toggleSelection(for contact: UserActiveContactModel) {
        if selectedContactIds.contains(contact.uid) {
            selectedContactIds.remove(contact.uid)
        } else {
            guard selectedContactIds.count < maxSelection else { return }
            selectedContactIds.insert(contact.uid)
        }
    }
    
    private func handleForward() {
        guard !selectedContactIds.isEmpty else { return }
        
        let selectedContacts = filteredContacts.filter { selectedContactIds.contains($0.uid) }
        onContactsSelected(selectedContacts)
        dismiss()
    }
    
    private func handleCancel() {
        if isSearchFocused {
            isSearchFocused = false
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        } else {
            withAnimation {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                dismiss()
                isPressed = false
            }
        }
    }
}

// MARK: - Forward Contact Row View (matching Android forward_layout_row.xml)
struct ForwardContactRowView: View {
    @Environment(\.colorScheme) var colorScheme
    
    let contact: UserActiveContactModel
    let isSelected: Bool
    let canSelect: Bool
    let onTap: () -> Void
    
    // Truncate name to 20 characters (matching Android)
    private var displayName: String {
        if contact.fullName.count > 20 {
            return String(contact.fullName.prefix(20)) + "..."
        }
        return contact.fullName
    }
    
    var body: some View {
        Button(action: {
            if canSelect {
                withAnimation(.easeInOut(duration: 0.2)) {
                    onTap()
                }
            }
        }) {
            HStack(alignment: .center, spacing: 0) {
                // Profile image (matching Android contact1img: 50dp x 50dp)
                AsyncImage(url: URL(string: contact.photo)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image("inviteimg")
                        .resizable()
                        .scaledToFill()
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                .padding(.leading, 16) // layout_marginHorizontal="16dp"
                .padding(.trailing, 20) // marginEnd="20dp"
                
                // Name (matching Android contact1text)
                // fontFamily="@font/inter_bold" textSize="16sp" textFontWeight="600"
                Text(displayName)
                    .font(.custom("Inter18pt-Bold", size: 16))
                    .fontWeight(.semibold)
                    .foregroundColor(Color("TextColor"))
                    .lineLimit(1)
                    .lineSpacing(0) // lineHeight="18dp"
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                // Checkbox (matching Android checkbox_bg visual size - smaller than drawable)
                // layout_gravity="end" - vertically centered in LinearLayout
                // Aligned to same right edge as search icon (16dp from right)
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color("TextColor") : Color.clear)
                        .frame(width: 18, height: 18) // Reduced size
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color("TextColor"), lineWidth: 2)
                        )
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .foregroundColor(colorScheme == .dark ? Color.black : Color(red: 0xF6/255, green: 0xF7/255, blue: 0xFF/255))
                            .font(.system(size: 9, weight: .bold)) // Smaller checkmark to match smaller box
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                // No trailing padding - parent HStack already has .padding(.horizontal, 16) which aligns with search icon
            }
            .padding(.top, 10) // paddingTop="10dp"
            .padding(.bottom, 10) // paddingBottom="10dp"
            .padding(.leading, 16) // layout_marginStart="16dp"
            .padding(.trailing, 20) // 20dp right margin to align with search icon
            .background(Color("background_color"))
            .opacity(canSelect ? 1.0 : 0.5)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
