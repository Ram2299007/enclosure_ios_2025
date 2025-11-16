//
//  callView.swift
//  Enclosure
//
//  Created by Ram Lohar on 30/04/25.
//

import Foundation
import SwiftUI

struct callView: View {
    @StateObject private var viewModel = CallViewModel()
    @State private var dragOffset: CGSize = .zero
    @State private var isStretchedUp = false
    @State private var isButtonVisible = false
    @Binding var isMainContentVisible: Bool
    @State private var isPressed = false
    
    // Tab state
    @State private var selectedTab: CallTab = .log
    @State private var isSearchVisible = false
    @State private var searchText = ""
    @State private var isBackLayoutVisible = false
    @State private var isContactLayoutVisible = false
    @State private var isBottomCallerVisible = false
    
    enum CallTab {
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
                        Button(action: {
                            withAnimation {
                                isBackLayoutVisible = false
                                isMainContentVisible = true
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.clear)
                                    .frame(width: 40, height: 40)
                                
                                Image("leftvector")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 25, height: 18)
                                    .foregroundColor(Color("icontintGlobal"))
                            }
                        }
                        .frame(width: 40, height: 40)
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
                            withAnimation {
                                selectedTab = .log
                                // Hide search layout when Last tab is clicked (matching Android)
                                isSearchVisible = false
                            }
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
                            withAnimation {
                                selectedTab = .contact
                            }
                            // Fetch contact list when A-Z tab is clicked
                            viewModel.fetchContactList(uid: Constant.SenderIdMy)
                            // Don't show search automatically - only show when search icon is clicked
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
                    if selectedTab == .log {
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
                        ScrollView {
                            VStack(spacing: 0) {
                                // Call log items will go here
                                Text("Call Log")
                                    .font(.custom("Inter18pt-Medium", size: 16))
                                    .foregroundColor(Color("TextColor"))
                                    .padding()
                                
                                // Placeholder for call log items
                                ForEach(0..<10) { index in
                                    CallLogRowView()
                                }
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
                                let _ = print("📞 [callView] Showing empty state - contactList count: \(viewModel.contactList.count), isLoading: \(viewModel.isLoading)")
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
                                let _ = print("📞 [callView] Showing contact list - contactList count: \(viewModel.contactList.count)")
                                // Contact list
                                ScrollView {
                                    VStack(spacing: 0) {
                                        ForEach(viewModel.contactList, id: \.uid) { contact in
                                            CallingContactRowView(contact: contact)
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
                
                // Bottom caller section (bottomcaller) - initially hidden
                if isBottomCallerVisible {
                    HStack(spacing: 0) {
                        // Contact info and call button will go here
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
                    withAnimation(.easeInOut(duration: 0.45)) {
                        if value.translation.height < -50 {
                            // Stretched upward
                            isStretchedUp = true
                            isMainContentVisible = false
                            isBackLayoutVisible = true
                            isButtonVisible = true
                        } else if value.translation.height > 50 {
                            // Stretched downward
                            isStretchedUp = false
                            isMainContentVisible = true
                            isBackLayoutVisible = false
                            isButtonVisible = false
                        }
                        dragOffset = .zero
                    }
                }
        )
        .overlay(
            // Back button overlay when stretched up
            Group {
                if isButtonVisible {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.45)) {
                        isPressed = true
                        isStretchedUp = false
                        isMainContentVisible = true
                            isBackLayoutVisible = false

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isButtonVisible = false
                                isPressed = false
                            }
                        }
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
                    .padding(.leading, 20)
                    .padding(.bottom, 30)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
                }
            },
            alignment: .bottomLeading
        )
    }
}

// Placeholder views for call log and contact rows
struct CallLogRowView: View {
    var body: some View {
        HStack {
            Image("inviteimg")
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                .padding(.leading, 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Contact Name")
                    .font(.custom("Inter18pt-SemiBold", size: 16))
                    .foregroundColor(Color("TextColor"))
                
                Text("Mobile Number")
                    .font(.custom("Inter18pt-Medium", size: 13))
                    .foregroundColor(Color("Gray3"))
            }
            .padding(.leading, 16)
            
            Spacer()

            Text("10:30 AM")
                .font(.custom("Inter18pt-Medium", size: 12))
                .foregroundColor(Color("Gray3"))
                .padding(.trailing, 20)
        }
        .padding(.vertical, 12)
        .background(Color("background_color"))
    }
}

// Contact row view matching Android get_calling_contact_voice_row.xml
struct CallingContactRowView: View {
    let contact: CallingContactModel
    @State private var isExpanded = false
    
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
                
                // Name and call icon - matching Android LinearLayout
                HStack(spacing: 0) {
                    Text(displayName)
                        .font(.custom("Inter18pt-Bold", size: 16))
                        .foregroundColor(Color("TextColor"))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Call icon - matching Android callIcon with marginEnd="22dp"
                    Image("cllingnewpng")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .padding(.trailing, 22) // marginEnd="22dp"
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 10) // marginTop="10dp" from Android call1 LinearLayout
            .padding(.bottom, 10) // marginBottom="10dp" from Android call1 LinearLayout
            
            // Expandable call button (initially hidden, expands on click)
            if isExpanded {
                HStack {
                    Spacer()
                    Text("Call")
                        .font(.custom("Inter18pt-Bold", size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            Image("curve_left_bg")
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(Color(hex: contact.themeColor.isEmpty ? "#00A3E9" : contact.themeColor))
                        )
                }
                .frame(width: 200)
                .transition(.move(edge: .trailing))
            }
        }
        .background(Color("background_color"))
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.4)) {
                isExpanded.toggle()
            }
        }
    }
}

// Profile card view matching chatView CardView design but with theme color
struct CallingContactCardView: View {
    var image: String?
    var themeColor: String
    
    var body: some View {
        // FrameLayout with border - matching Android card_border and chatView CardView
        // FrameLayout: padding="2dp", background="@drawable/card_border"
        // CardView inside: cardCornerRadius="360dp" (fully circular)
        // Image: 50dp x 50dp, scaleType="centerCrop"
        ZStack {
            // Border background (card_border equivalent) - using theme color instead of blue
            // The border is 2dp wide, so outer circle is 54dp (50 + 2*2)
            Circle()
                .stroke(Color(hex: themeColor.isEmpty ? "#00A3E9" : themeColor), lineWidth: 2) // 2dp border stroke with theme color
                .frame(width: 54, height: 54)
            
            // Inner circular image - 50dp x 50dp
            // Using AsyncImage to fetch the image from the URL with proper phase handling
            AsyncImage(url: URL(string: image ?? "")) { phase in
                switch phase {
                case .empty:
                    // Placeholder image while the image is loading
                    Image("inviteimg")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                case .success(let image):
                    // Loaded image - centerCrop equivalent
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                case .failure:
                    // Fallback image if the network image loading fails
                    Image("inviteimg")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                @unknown default:
                    // Default case
                    Image("inviteimg")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                }
            }
            .frame(width: 50, height: 50) // 50dp x 50dp as per Android
        }
        .frame(width: 54, height: 54) // Total FrameLayout size: 54dp x 54dp (50dp image + 2dp border on each side)
    }
}

// Helper extension for hex color
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 163, 233) // Default blue
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
