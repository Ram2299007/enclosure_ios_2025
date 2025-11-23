//
//  NewGroupView.swift
//  Enclosure
//
//  Created by Ram Lohar on 30/04/25.
//

import SwiftUI
import PhotosUI

struct NewGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = NewGroupViewModel()
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    
    @State private var isImagePickerPresented = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isCreatingGroup = false
    @State private var isBackPressed = false
    
    private var filteredContacts: [UserActiveContactModel] {
        viewModel.contacts
    }
    
    var body: some View {
        ZStack {
            Color("BackgroundColor")
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Back arrow and title - matching youView design
                    HStack(spacing: 0) {
                        Button(action: {
                            handleBackTap()
                        }) {
                            ZStack {
                                if isBackPressed {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 40, height: 40)
                                        .scaleEffect(isBackPressed ? 1.2 : 1.0)
                                        .animation(.easeOut(duration: 0.1), value: isBackPressed)
                                }

                                Image("leftvector")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 25, height: 18)
                                    .foregroundColor(Color("icontintGlobal"))
                            }
                        }
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { _ in
                                    withAnimation {
                                        isBackPressed = false
                                    }
                                }
                        )
                        .frame(width: 40, height: 40)
                        
                        // "Create new group" text
                        Text("Create new group")
                            .font(.custom("Inter18pt-SemiBold", size: 16))
                            .foregroundColor(Color("TextColor"))
                            .padding(.leading, 15)

                        Spacer()
                    }
                    .padding(.leading, 20)
                    .padding(.trailing, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                    
                    if !networkMonitor.isConnected {
                        ProgressView()
                            .progressViewStyle(.linear)
                            .tint(Color("buttonColorTheme"))
                            .frame(height: 2)
                    }
                    
                    groupNameSection
                    
                    totalMembersSection
                        .padding(.top, 25)
                    
                    contactsHeader
                        .padding(.top, 25)
                    
                    contactsList
                        .padding(.top, 16)
                }
            }
            
            submitButton
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $isImagePickerPresented) {
            ImagePicker(sourceType: .photoLibrary, selectedImage: Binding(
                get: { nil },
                set: { newImage in
                    if let image = newImage {
                        DispatchQueue.main.async {
                            viewModel.processSelectedImage(image)
                        }
                    }
                }
            ))
        }
        .onAppear {
            // Check all icons on view appear
            print("🔍 [NewGroupView] Checking icons...")
            let iconsToCheck = ["leftvector", "group_new_svg", "tick_new_dvg", "inviteimg"]
            for iconName in iconsToCheck {
                ImageLoaderHelper.checkImageExists(iconName)
            }
            print("🔍 [NewGroupView] Icon check complete")
            
            viewModel.fetchContacts(uid: Constant.SenderIdMy)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .overlay {
            if viewModel.isLoading && !viewModel.hasCachedContacts {
                HorizontalProgressBar()
                    .frame(height: 4)
                    .tint(Color("TextColor"))
            }
            
            if let errorMessage = viewModel.errorMessage, viewModel.contacts.isEmpty && !viewModel.isLoading {
                emptyStateView(message: errorMessage)
            }
        }
    }
    
    private var groupNameSection: some View {
        HStack(alignment: .center, spacing: 0) {
            // LinearLayout with id="group" - 45dp x 45dp, center gravity, vertical orientation
            Button(action: {
                isImagePickerPresented = true
            }) {
                VStack {
                    // CircleImageView 28x28dp, centerCrop scaleType, center gravity
                    if let image = viewModel.selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 28, height: 28)
                            .clipShape(Circle())
                    } else {
                        Image("group_new_svg")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                            .logImageLoad("group_new_svg")
                    }
                }
                .frame(width: 45, height: 45)
                .background(
                    Circle()
                        .fill(Color("blue"))
                )
            }
            .frame(width: 45, height: 45)
            .buttonStyle(.plain)
            
            // EditText - match_parent width, 48dp height, marginStart=16dp, marginEnd=31dp
            // No background, just plain TextField like Android
            HStack(alignment: .center, spacing: 0) {
                // Vertical line on start side - 1dp width, 19.24dp height, marginStart=13dp
                Rectangle()
                    .fill(Color("blue"))
                    .frame(width: 1, height: 19.24)
                    .padding(.leading, 13)
                    .padding(.trailing,13)
                
                TextField("Type name of the group", text: $viewModel.groupName)
                    .font(.custom("Inter18pt-Regular", size: 15)) // fontFamily="@font/inter" textFontWeight="500" textSize="15sp"
                    .foregroundColor(Color("black_white_cross"))
                    .accentColor(Color("buttonColorTheme"))
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(height: 48)
                    .padding(.leading, 0) // No extra padding, line spacing handles it
                    .padding(.trailing, 31)
            }
            .frame(height: 48)
        }
        .padding(.horizontal, 20)
        .padding(.top, 0)
    }
    
    private var totalMembersSection: some View {
        HStack {
            Text("Total Group Members : ")
                .font(.custom("Inter18pt-SemiBold", size: 17)) // inter_bold, 18sp
                .foregroundColor(Color("TextColor"))
            
            Text("\(viewModel.selectedCount)")
                .font(.custom("Inter18pt-SemiBold", size: 17)) // inter_bold, 18sp
                .foregroundColor(Color(hex: "#011224"))
            
            Spacer()
        }
        .padding(.leading, 16)
    }
    
    private var contactsHeader: some View {
        HStack {
            VStack(spacing: 6) {
                Text("Contacts")
                    .font(.custom("Inter18pt-SemiBold", size: 12))
                    .foregroundColor(.white)
                    .frame(width: 70, height: 30)
                    .background(Color("buttonColorTheme"))
                    .cornerRadius(20)
            }
            .padding(.leading, 15)
            
            Spacer()
        }
    }
    
    private var contactsList: some View {
        VStack(spacing: 0) {
            if filteredContacts.isEmpty && !viewModel.isLoading {
                emptyContactsView
            } else {
                ForEach(filteredContacts, id: \.uid) { contact in
                    ContactRowView(
                        contact: contact,
                        isSelected: viewModel.isContactSelected(contact.uid),
                        onToggle: {
                            viewModel.toggleContactSelection(contact.uid)
                        }
                    )
                }
            }
        }
    }
    
    private var emptyContactsView: some View {
        VStack(spacing: 0) {
            Text("Call On Enclosure")
                .font(.custom("Inter18pt-Regular", size: 14))
                .foregroundColor(Color(hex: "#646464"))
                .multilineTextAlignment(.center)
                .hidden()
            
            HStack(spacing: 0) {
                Text("No contacts available")
                    .font(.custom("Inter18pt-Regular", size: 14)) // inter, 14sp, normal
                    .foregroundColor(Color(hex: "#646464"))
            }
            .padding(.top, 2)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
        )
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Text("Unable to load contacts")
                .font(.custom("Inter18pt-SemiBold", size: 16))
                .foregroundColor(Color("TextColor"))
            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.custom("Inter18pt-Medium", size: 14))
                    .foregroundColor(Color("gray"))
            }
            Button("Retry") {
                viewModel.fetchContacts(uid: Constant.SenderIdMy)
            }
            .font(.custom("Inter18pt-SemiBold", size: 14))
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Color("buttonColorTheme"))
            .foregroundColor(.white)
            .cornerRadius(20)
        }
        .padding(.vertical, 40)
    }
    
    private func emptyStateView(message: String) -> some View {
        VStack(spacing: 8) {
            Text("Unable to load contacts")
                .font(.custom("Inter18pt-SemiBold", size: 16))
                .foregroundColor(Color("TextColor"))
            Text(message)
                .font(.custom("Inter18pt-Medium", size: 14))
                .foregroundColor(Color("gray"))
            Button("Retry") {
                viewModel.fetchContacts(uid: Constant.SenderIdMy)
            }
            .font(.custom("Inter18pt-SemiBold", size: 14))
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Color("buttonColorTheme"))
            .foregroundColor(.white)
            .cornerRadius(20)
        }
        .padding(.vertical, 40)
    }
    
    private var submitButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: {
                    handleSubmit()
                }) {
                    Image("tick_new_dvg")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundColor(Color("icontintGlobal"))
                        .frame(width: 52, height: 52)
                        .background(
                            Circle()
                                .fill(Color("buttonColorTheme"))
                        )
                        .logImageLoad("tick_new_dvg")
                }
                .buttonStyle(.plain)
                .disabled(isCreatingGroup)
                Spacer()
            }
            .padding(.top, 55)
            .padding(.bottom, 50)
        }
    }
    
    private func handleBackTap() {
        withAnimation(.easeOut(duration: 0.1)) {
            isBackPressed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation {
                isBackPressed = false
            }
            dismiss()
        }
    }
    
    private func handleSubmit() {
        guard !viewModel.groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Missing group name"
            showError = true
            return
        }
        
        guard viewModel.invitedFriendListJSON != "NODATA" else {
            errorMessage = "Please add contacts to create group"
            showError = true
            return
        }
        
        isCreatingGroup = true
        
        viewModel.createGroup(uid: Constant.SenderIdMy) { success, message in
            DispatchQueue.main.async {
                isCreatingGroup = false
                if success {
                    dismiss()
                } else {
                    errorMessage = message
                    showError = true
                }
            }
        }
    }
}

struct ContactRowView: View {
    let contact: UserActiveContactModel
    let isSelected: Bool
    let onToggle: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Contact Image with border - matching chatView CardView design
            ZStack {
                // Border background (card_border equivalent) - 2dp border
                Circle()
                    .stroke(Color("blue"), lineWidth: 2) // 2dp border stroke matching chatView
                    .frame(width: 54, height: 54)
                
                CachedAsyncImage(url: URL(string: contact.photo)) { image in
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
                        .logImageLoad("inviteimg")
                }
                .frame(width: 50, height: 50) // 50dp x 50dp as per chatView
            }
            .frame(width: 54, height: 54) // Total FrameLayout size: 54dp x 54dp
            .padding(.leading, 1) // marginStart="1dp" for FrameLayout matching chatView
            .padding(.trailing, 16) // marginEnd="16dp" for FrameLayout matching chatView
            
            // Name text - matching chatView font and size
            Text(contact.fullName)
                .font(.custom("Inter18pt-SemiBold", size: 16)) // Matching chatView ContactCardView
                .foregroundColor(Color("TextColor"))
                .lineLimit(1) // singleLine="true" equivalent
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            // Checkbox at end - matching Android layout
            CheckboxView(isSelected: isSelected)
                .padding(.trailing, 20) // marginEnd="20dp" matching Android
        }
        .padding(.leading, 15) // marginStart="10dp" for LinearLayout matching chatView
        .padding(.top, 16) // marginTop="16dp" for LinearLayout matching chatView
        .padding(.bottom, 16) // marginBottom="16dp" matching chatView
        .contentShape(Rectangle())
        .background(isPressed ? Color.gray.opacity(0.1) : Color.clear) // Matching chatView
        .scaleEffect(isPressed ? 0.98 : 1.0) // Matching chatView
        .animation(.easeInOut(duration: 0.15), value: isPressed) // Matching chatView
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in
                    isPressed = false
                    onToggle()
                }
        )
        .onLongPressGesture(minimumDuration: 0.01, pressing: { pressing in
            isPressed = pressing
        }, perform: {
            // Handle toggle on long press if needed
        })
    }
}

struct CheckboxView: View {
    let isSelected: Bool
    @Environment(\.colorScheme) var colorScheme
    
    // Checkbox colors - only black and white
    private var borderColor: Color {
        // Black in light mode, white in dark mode
        colorScheme == .dark ? .white : .black
    }
    
    private var fillColor: Color {
        // Black in light mode, white in dark mode
        colorScheme == .dark ? .white : .black
    }
    
    private var checkmarkColor: Color {
        // White checkmark in light mode (on black), black checkmark in dark mode (on white)
        colorScheme == .dark ? .black : .white
    }
    
    var body: some View {
        ZStack {
            if isSelected {
                // Selected state - filled circle with checkmark (black/white only)
                Circle()
                    .fill(fillColor)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(checkmarkColor)
                    )
            } else {
                // Unselected state - empty circle with border (black/white only)
                Circle()
                    .stroke(borderColor, lineWidth: 1)
                    .frame(width: 22, height: 22)
            }
        }
        .frame(width: 22, height: 22)
    }
}

