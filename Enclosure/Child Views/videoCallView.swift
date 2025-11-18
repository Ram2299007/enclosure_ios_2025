//
//  videoCallView.swift
//  Enclosure
//
//  Created by Ram Lohar on 30/04/25.
//

import Foundation
import SwiftUI

struct videoCallView: View {
    @StateObject private var viewModel = CallViewModel()
    @StateObject private var callLogViewModel = CallLogViewModel(logType: .video)
    @State private var dragOffset: CGSize = .zero
    @State private var isStretchedUp = false
    @State private var isButtonVisible = false
    @Binding var isMainContentVisible: Bool
    @State private var isPressed = false
    
    // Tab state
    @State private var selectedTab: VideoCallTab = .log
    @State private var isSearchVisible = false
    @State private var searchText = ""
    @State private var isBackLayoutVisible = false
    @State private var isContactLayoutVisible = false
    @State private var isBottomCallerVisible = false
    
    enum VideoCallTab {
        case log, contact
    }

    var body: some View {
        ZStack {
            Color("background_color")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Back arrow layout (backlyt) - initially hidden
                if isBackLayoutVisible {
                    HStack(spacing: 0) {
                        // Back arrow button
                        backArrowButton()
                            .padding(.leading, 20)
                            .padding(.trailing, 5)
                        
                        Spacer()
                        
                        // Menu button (3 dots)
                        Button(action: {
                            // Menu action
                        }) {
                            VStack(spacing: 3) {
                                Circle()
                                    .fill(Color("menuPointColor"))
                                    .frame(width: 4, height: 4)
                                Circle()
                                    .fill(Color("blue"))
                                    .frame(width: 4, height: 4)
                                Circle()
                                    .fill(Color("Gray3"))
                                    .frame(width: 4, height: 4)
                            }
                            .frame(width: 40, height: 40)
                        }
                        .frame(width: 40, height: 40)
                        .padding(.trailing, 10)
                    }
                    .frame(height: 50)
                    .padding(.top, 15)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Search section (searchData) - matching MainActivityOld.swift pattern and Android spacing
                // Search icon always visible when on contact tab, search bar slides in/out
                if selectedTab == .contact {
        VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            // Search bar - slides in from trailing edge when visible (matching MainActivityOld.swift)
                            if isSearchVisible {
                                HStack(spacing: 0) {
                                    Rectangle()
                                        .fill(Color("blue"))
                                        .frame(width: 1, height: 19.24)
                                        .padding(.leading, 23)
                                    
                                    TextField("Search Name or Number", text: $searchText)
                                        .font(.custom("Inter18pt-Regular", size: 15))
                                        .foregroundColor(Color("TextColor"))
                                        .padding(.leading, 13)
                                        .textFieldStyle(PlainTextFieldStyle())
                                }
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                            }
                            
                            Spacer() // Push search icon to end
                            
                            // Search icon button - always visible at end (matching MainActivityOld.swift)
                            Button(action: {
                                withAnimation {
                                    isSearchVisible.toggle()
                                }
                            }) {
                                Image("search")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                            }
                            .frame(width: 40, height: 40)
                        }
                        .padding(.top, 10) // marginTop="10dp" from Android searchData inner layout
                    }
                    .padding(.top, 2) // marginTop="2dp" from searchData layout
                    .padding(.trailing, 18) // marginEnd="18dp" for search icon
                }
                
                // Tabs section (label) - matching Android design with exact spacing
                HStack(spacing: 0) {
                    // Last/Log tab - matching Android radius_black_6dp when selected, radius_6dp_transp when not
                    VStack(spacing: 5) {
                        Button(action: {
                            handleLogTabClick()
                        }) {
                            Text("Last")
                                .font(.custom("Inter18pt-Medium", size: 12))
                                .fontWeight(.bold)
                                .foregroundColor(selectedTab == .log ? .white : .black) // White when selected, black when not (matching Android)
                                .frame(width: 70, height: 30)
                                .background(
                                    selectedTab == .log 
                                        ? Color("buttonColorTheme") // radius_black_6dp equivalent
                                        : Color("gray2") // radius_6dp_transp equivalent (atoz = gray2)
                                )
                                .cornerRadius(20) // 20dp corner radius as per Android
                        }
                    }
                    
                    // A-Z/Contact tab - matching Android radius_black_6dp when selected, radius_6dp_transp when not
                    VStack(spacing: 5) {
                Button(action: {
                    handleContactTabClick()
                        }) {
                            Text("A - Z")
                                .font(.custom("Inter18pt-Medium", size: 12))
                                .fontWeight(.bold)
                                .foregroundColor(selectedTab == .contact ? .white : .black) // White when selected, black when not (matching Android)
                                .frame(width: 70, height: 30)
                                .background(
                                    selectedTab == .contact 
                                        ? Color("buttonColorTheme") // radius_black_6dp equivalent
                                        : Color("gray2") // radius_6dp_transp equivalent (atoz = gray2)
                                )
                                .cornerRadius(20) // 20dp corner radius as per Android
                        }
                    }
                    .padding(.leading, 15) // marginStart="15dp" from Android
                    
                    Spacer()
                    
                    // Menu button (3 dots) - visible when on log tab
                    if selectedTab == .log && !isBackLayoutVisible {
                        Button(action: {
                            // Show clear log dialog
                        }) {
                            VStack(spacing: 3) {
                                Circle()
                                    .fill(Color("menuPointColor"))
                                    .frame(width: 4, height: 4)
                                Circle()
                                    .fill(Color("blue"))
                                    .frame(width: 4, height: 4)
                                Circle()
                                    .fill(Color("Gray3"))
                                    .frame(width: 4, height: 4)
                            }
                            .frame(width: 40, height: 40)
                        }
                        .frame(width: 40, height: 40)
                        .padding(.trailing, 15) // marginEnd="15dp" from Android
                    }
                }
                .padding(.leading, 20) // marginStart="20dp" from Android label layout
                .padding(.top, 15) // marginTop="15dp" from Android
                
                // Content area - RecyclerViews
                ZStack {
                    // Log RecyclerView (recyclerviewLast)
                    if selectedTab == .log {
                        ZStack {
                            if callLogViewModel.isLoading {
                                ZStack {
                                    Color("background_color")
                                        .ignoresSafeArea()
                                    HorizontalProgressBar()
                                        .frame(width: 40, height: 2)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else if let errorMessage = callLogViewModel.errorMessage,
                                      !errorMessage.isEmpty,
                                      callLogViewModel.sections.isEmpty {
                                logEmptyStateView(text: errorMessage)
                            } else if callLogViewModel.sections.isEmpty {
                                logEmptyStateView(text: "No call history yet")
                            } else {
                                ScrollView {
                                    CallLogListView(sections: callLogViewModel.sections, logType: .video)
                                }
                                .transition(.opacity)
                            }
                        }
                        .transition(.opacity)
                    }
                    
                    // Contact RecyclerView (recyclerviewAZ)
                    if selectedTab == .contact {
                        ZStack {
                            if viewModel.isLoading {
                                // Progress bar - matching Android
                                ProgressView()
                                    .progressViewStyle(LinearProgressViewStyle(tint: Color("TextColor")))
                                    .frame(width: 40, height: 2)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else if viewModel.contactList.isEmpty {
                                let _ = print("📹 [videoCallView] Showing empty state - contactList count: \(viewModel.contactList.count), isLoading: \(viewModel.isLoading)")
                                // Empty state card - matching Android noData card
                                HStack(spacing: 0) {
                                    Text("Press")
                                        .font(.custom("Inter18pt-Medium", size: 14))
                                        .foregroundColor(Color("TextColor"))
                                    Text("  A - Z  ")
                                        .font(.custom("Inter18pt-Medium", size: 14))
                                        .foregroundColor(Color("TextColor"))
                                    Text("for contact")
                                        .font(.custom("Inter18pt-Medium", size: 14))
                                        .foregroundColor(Color("TextColor"))
                                }
                                .padding(12)
                                .background(Color("cardBackgroundColornew"))
                                .cornerRadius(20)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                let _ = print("📹 [videoCallView] Showing contact list - contactList count: \(viewModel.contactList.count)")
                                // Contact list
                                ScrollView {
                                    VStack(spacing: 0) {
                                        ForEach(viewModel.contactList, id: \.uid) { contact in
                                            VideoCallingContactRowView(contact: contact)
                                        }
                                    }
                                }
                                .transition(.opacity)
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .padding(.top, 5) // 5dp spacing between tabs and list view
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Bottom caller section (bottomcaller2) - initially hidden
                if isBottomCallerVisible {
                    HStack(spacing: 0) {
                        // Contact info and video call button will go here
                        Text("Bottom Caller Section")
                            .font(.custom("Inter18pt-Medium", size: 16))
                            .foregroundColor(.white)
                            .padding()
                    }
                    .frame(height: 78)
                    .frame(maxWidth: .infinity)
                    .background(Color("dxPatti"))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .padding(.top, 15)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    if value.translation.height < -50 {
                        withAnimation(.easeInOut(duration: 0.45)) {
                            // Stretched upward
                            isStretchedUp = true
                            isMainContentVisible = false
                            isBackLayoutVisible = true
                            isButtonVisible = true
                        }
                    } else if value.translation.height > 50 {
                        handleSwipeDown()
                    }
                    dragOffset = .zero
                }
        )
        .overlay(
            // Back button overlay when stretched up
            Group {
                if isButtonVisible && !isBackLayoutVisible {
                    backArrowButton()
                        .padding(.leading, 20)
                        .padding(.bottom, 30)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                }
            },
            alignment: .bottomLeading
        )
        .onAppear {
            callLogViewModel.fetchCallLogs(uid: Constant.SenderIdMy, force: true)
        }
    }
}

extension videoCallView {
    private func handleBackArrowTap() {
        handleSwipeDown()
    }
    
    private func handleSwipeDown() {
        withAnimation(.easeInOut(duration: 0.45)) {
            isPressed = true
            isStretchedUp = false
            isMainContentVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.45)) {
                isBackLayoutVisible = false
                isButtonVisible = false
                isPressed = false
            }
        }
    }
    
    private func backArrowButton() -> some View {
        Button(action: {
            handleBackArrowTap()
        }) {
            ZStack {
                if isPressed {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .scaleEffect(isPressed ? 1.2 : 1.0)
                        .animation(.easeOut(duration: 0.1), value: isPressed)
                }
                
                Image("leftvector")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 25, height: 18)
                    .foregroundColor(Color("icontintGlobal"))
            }
        }
        .frame(width: 40, height: 40)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in
                    withAnimation {
                        isPressed = false
                    }
                }
        )
    }
}

// Placeholder views for video call log and contact rows
// Video call contact row view matching Android get_calling_contact_list_row.xml
struct VideoCallingContactRowView: View {
    let contact: CallingContactModel
    @State private var isExpanded = false
    @State private var callButtonWidth: CGFloat = 0
    
    // Truncate name to 22 characters like Android
    private var displayName: String {
        if contact.fullName.count > 22 {
            return String(contact.fullName.prefix(22)) + "..."
        }
        return contact.fullName
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Main content area - matching Android call1 LinearLayout with marginTop="10dp" and marginBottom="10dp"
            HStack(spacing: 0) {
                // Profile image with theme border - matching chatView CardView design
                // Android: marginLeft="20dp", marginRight="20dp" on themeBorder FrameLayout
                CallingContactCardView(image: contact.photo, themeColor: contact.themeColor)
                    .padding(.leading, 20) // marginLeft="20dp"
                    .padding(.trailing, 20) // marginRight="20dp"
                
                // Name and video icon/button stack - matching Android LinearLayout
                HStack(spacing: 0) {
                    Text(displayName)
                        .font(.custom("Inter18pt-SemiBold", size: 16))
                        .foregroundColor(Color("TextColor"))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    HStack(spacing: isExpanded ? 0 : 6) {
                        // Video icon - matching Android videosvgnew2 with marginEnd="22dp"
                        // Android: 26dp width, 16dp height, with polysvg inside
                        // Video icon is clickable and triggers expansion
                        Button(action: {
                            expandCallButton()
                        }) {
                            ZStack {
                                Image("videosvgnew2")
                                    .resizable()
                                    .renderingMode(.template)
                                    .foregroundColor(Color("blue"))
                                    .scaledToFit()
                                    .frame(width: 26, height: 16)
                                
                                Image("polysvg")
                                    .resizable()
                                    .renderingMode(.template)
                                    .foregroundColor(.white)
                                    .scaledToFit()
                                    .frame(width: 5, height: 5)
                            }
                        }
                        
                        if isExpanded {
                            Button(action: {
                                // Call action - matching Android clickView onClick
                                print("📹 Video Calling: \(contact.fullName)")
                                // TODO: Implement actual video call functionality
                            }) {
                                ZStack {
                                    UnevenRoundedRectangle(
                                        cornerRadii: .init(
                                            topLeading: 100,
                                            bottomLeading: 100,
                                            bottomTrailing: 0,
                                            topTrailing: 0
                                        )
                                    )
                                    .fill(Color(hex: contact.themeColor.isEmpty ? "#00A3E9" : contact.themeColor))
                                    
                                    Text("Call")
                                        .font(.custom("Inter18pt-Bold", size: 16))
                                        .foregroundColor(.white)
                                }
                                .frame(width: callButtonWidth, height: 40, alignment: .center)
                            }
                        }
                    }
                    .padding(.trailing, isExpanded ? 0 : 22)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 10) // marginTop="10dp" from Android call1 LinearLayout
            .padding(.bottom, 10) // marginBottom="10dp" from Android call1 LinearLayout
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("background_color"))
        .contentShape(Rectangle())
        .onTapGesture {
            // Clicking on row expands the call button (matching Android itemView onClick)
            if !isExpanded {
                expandCallButton()
            }
        }
    }
    
    // Expand call button animation matching Android expandViewFromLeft
    private func expandCallButton() {
        isExpanded = true
        // Android request: keep bg_rect width to 60dp (≈ 60pt in iOS)
        let finalWidth: CGFloat = 70
        
        // Animate width from 0 to finalWidth over 0.4 seconds (400ms)
        callButtonWidth = 0
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.4)) {
                self.callButtonWidth = finalWidth
            }
        }
    }
}

// MARK: - Tab handling helpers
extension videoCallView {
    private func handleLogTabClick() {
        withAnimation {
            selectedTab = .log
            isSearchVisible = false
        }
        searchText = ""
        callLogViewModel.fetchCallLogs(uid: Constant.SenderIdMy, force: true)
    }
    
    private func handleContactTabClick() {
        withAnimation {
            selectedTab = .contact
        }
        if viewModel.contactList.isEmpty {
            viewModel.fetchContactList(uid: Constant.SenderIdMy)
        }
    }
    
    @ViewBuilder
    private func logEmptyStateView(text: String) -> some View {
        VStack {
            HStack {
                Text(text)
                    .font(.custom("Inter18pt-Medium", size: 14))
                    .foregroundColor(Color("TextColor"))
            }
            .padding(12)
            .background(Color("cardBackgroundColornew"))
            .cornerRadius(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
