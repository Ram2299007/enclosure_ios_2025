//
//  ForGroupVisibleScreen.swift
//  Enclosure
//
//  Created by Auto on 2025.
//

import SwiftUI

struct ForGroupVisibleScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    let group: GroupModel
    
    @State private var groupName: String = ""
    @State private var groupIcon: String = ""
    @State private var members: [GroupMember] = []
    @State private var isLoading: Bool = false
    @State private var showNetworkLoader: Bool = false
    @State private var themeColorHex: String = Constant.themeColor
    @State private var mainvectorTintColor: Color = Color(hex: "#01253B")
    
    // Navigation state
    @State private var navigateToUserInfo: Bool = false
    @State private var navigateToShowImage: Bool = false
    @State private var selectedUserId: String = ""
    @State private var selectedUserName: String = ""
    @State private var selectedImageForShow: SelectionBunchModel?
    
    // Helper function to hide keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    var body: some View {
        ZStack {
            Color("BackgroundColor")
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    hideKeyboard()
                }
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Network loader
                if showNetworkLoader {
                    HorizontalProgressBar()
                        .frame(height: 2)
                }
                
                // Content
                ScrollView {
                    VStack(alignment: .trailing, spacing: 0) {
                        // Profile image section (aligned to end/right, matching Android layout_gravity="end")
                        profileImageView
                            .padding(.top, 25)
                            .padding(.trailing, 25)
                        
                        // Group name section with theme bar (matching Android layout_marginStart="20dp", layout_marginTop="60dp")
                        groupNameView
                            .padding(.top, 60)
                            .padding(.leading, 20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Added badge (matching Android layout_marginTop="60dp", layout_marginStart="15dp", layout_marginBottom="20dp")
                        addedBadgeView
                            .padding(.top, 60)
                            .padding(.leading, 15)
                            .padding(.bottom, 20)
                        
                        // Members list (RecyclerView - no extra padding needed)
                        membersListView
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .background(NavigationGestureEnabler())
        .onAppear {
            loadGroupDetails()
            setupThemeColor()
        }
        .background(
            // Hidden NavigationLink for UserInfoScreen
            NavigationLink(
                destination: UserInfoScreen(
                    recUserId: selectedUserId,
                    recUserName: selectedUserName
                )
                .onDisappear {
                    navigateToUserInfo = false
                },
                isActive: $navigateToUserInfo
            ) {
                EmptyView()
            }
            .hidden()
        )
        .background(
            // Hidden NavigationLink for ShowImageScreen
            NavigationLink(
                destination: Group {
                    if let imageModel = selectedImageForShow {
                        ShowImageScreen(
                            imageModel: imageModel,
                            viewHolderTypeKey: nil
                        )
                    } else {
                        EmptyView()
                    }
                }
                .onDisappear {
                    navigateToShowImage = false
                },
                isActive: $navigateToShowImage
            ) {
                EmptyView()
            }
            .hidden()
        )
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Back button
                Button(action: {
                    dismiss()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color("circlebtnhover"))
                            .frame(width: 40, height: 40)
                        
                        Image("leftvector")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 18)
                            .foregroundColor(Color("TextColor"))
                    }
                }
                .padding(.leading, 20)
                .padding(.trailing, 5)
                
                // Title
                Text("For visible")
                    .font(.custom("Inter18pt-Medium", size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(Color("TextColor"))
                    .padding(.leading, 15)
                
                Spacer()
            }
            .padding(.top, 10)
            .frame(height: 50)
        }
        .background(Color("edittextBg"))
    }
    
    // MARK: - Profile Image View
    private var profileImageView: some View {
        HStack {
            Spacer()
            
            // Profile image with border (clickable to open ShowImageScreen - matching Android)
            Button(action: {
                // Open ShowImageScreen for group icon (matching Android profile.setOnClickListener)
                if !groupIcon.isEmpty {
                    selectedImageForShow = SelectionBunchModel(
                        imgUrl: groupIcon,
                        fileName: ""
                    )
                    navigateToShowImage = true
                }
            }) {
                ZStack {
                    // Border
                    RoundedRectangle(cornerRadius: 360)
                        .stroke(Color("cardBorder"), lineWidth: 2)
                        .frame(width: 111, height: 111)
                    
                    // Profile image
                    CachedAsyncImage(
                        url: URL(string: groupIcon.isEmpty ? "" : groupIcon),
                        content: { image in
                            image
                                .resizable()
                                .scaledToFill()
                        },
                        placeholder: {
                            Image("inviteimg")
                                .resizable()
                                .scaledToFill()
                        }
                    )
                    .frame(width: 107, height: 107)
                    .clipShape(Circle())
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Group Name View
    private var groupNameView: some View {
        HStack(spacing: 0) {
            // Theme-colored vertical bar
            Rectangle()
                .fill(getThemeBarColor())
                .frame(width: 4)
                .padding(.trailing, 20)
            
            // Group name (left-aligned, clickable to open ShowImageScreen)
            Button(action: {
                // Open ShowImageScreen for group icon when name is clicked
                if !groupIcon.isEmpty {
                    selectedImageForShow = SelectionBunchModel(
                        imgUrl: groupIcon,
                        fileName: ""
                    )
                    navigateToShowImage = true
                }
            }) {
                Text(groupName.isEmpty ? group.name : groupName)
                    .font(.custom("Inter18pt-Medium", size: 19))
                    .fontWeight(.bold)
                    .foregroundColor(Color("TextColor"))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Added Badge View
    private var addedBadgeView: some View {
        HStack {
            Text("Added")
                .font(.custom("Inter18pt-Medium", size: 12))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black)
                )
                .frame(width: 70, height: 30)
            
            Spacer()
        }
    }
    
    // MARK: - Members List View
    private var membersListView: some View {
        VStack(spacing: 0) {
            if filteredMembers.isEmpty {
                // Show message if no members (centered)
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                } else {
                    HStack {
                        Spacer()
                        Text("No members found")
                            .font(.custom("Inter18pt-Medium", size: 14))
                            .foregroundColor(Color("TextColor"))
                            .padding()
                        Spacer()
                    }
                }
            } else {
                ForEach(filteredMembers) { member in
                    MemberRowView(
                        member: member,
                        onImageTap: {
                            // Open ShowImageScreen
                            if let photo = member.photo, !photo.isEmpty {
                                selectedImageForShow = SelectionBunchModel(
                                    imgUrl: photo,
                                    fileName: ""
                                )
                                navigateToShowImage = true
                            }
                        },
                        onRowTap: {
                            // Navigate to UserInfoScreen
                            if let uid = member.uid, !uid.isEmpty {
                                selectedUserId = uid
                                selectedUserName = member.full_name ?? ""
                                navigateToUserInfo = true
                            }
                        }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading) // Ensure list aligns left
    }
    
    // MARK: - Filtered Members (excluding current user)
    private var filteredMembers: [GroupMember] {
        let currentUid = Constant.SenderIdMy
        return members.filter { member in
            guard let uid = member.uid else { return false }
            return uid != currentUid
        }
    }
    
    // MARK: - Get Theme Bar Color (matching Android richBox backgroundTintList logic)
    private func getThemeBarColor() -> Color {
        // In light mode, use "#011224" (matching Android else block)
        if colorScheme == .light {
            return Color(hex: "#011224")
        }
        
        // In dark mode, use theme-based darker tint colors (matching Android if block)
        let themeColor = themeColorHex.uppercased() // Android uses uppercase comparison
        
        switch themeColor {
        case "#FF0080":
            return Color(hex: "#4D0026")
        case "#00A3E9":
            return Color(hex: "#01253B")
        case "#7ADF2A":
            return Color(hex: "#25430D")
        case "#EC0001":
            return Color(hex: "#470000")
        case "#16F3FF":
            return Color(hex: "#05495D")
        case "#FF8A00":
            return Color(hex: "#663700")
        case "#7F7F7F":
            return Color(hex: "#2B3137")
        case "#D9B845":
            return Color(hex: "#413815")
        case "#346667":
            return Color(hex: "#1F3D3E")
        case "#9846D9":
            return Color(hex: "#2d1541")
        case "#A81010":
            return Color(hex: "#430706")
        default:
            return Color(hex: "#01253B")
        }
    }
    
    // MARK: - Setup Theme Color (matching Android ThemeColorKey logic)
    private func setupThemeColor() {
        // Get theme color from UserDefaults (matching Android Constant.getSF.getString(Constant.ThemeColorKey, "#00A3E9"))
        // Use Constant.themeColor which should already read from UserDefaults
        themeColorHex = Constant.themeColor
        
        if colorScheme == .dark {
            mainvectorTintColor = getMainvectorTintColor(for: themeColorHex)
        }
    }
    
    // MARK: - Load Group Details
    private func loadGroupDetails() {
        // Set initial values from group model
        groupName = group.name
        groupIcon = group.iconURL
        
        // Fetch group members
        fetchGroupMembers()
    }
    
    // MARK: - Fetch Group Members
    private func fetchGroupMembers() {
        isLoading = true
        showNetworkLoader = true
        
        // Use get_group_details API (matching Android Webservice.get_group_details)
        // Android uses MultipartBody with form data, so we'll use URL-encoded form data
        let urlString = "\(Constant.baseURL)get_group_details"
        guard let url = URL(string: urlString) else {
            print("🚫 [ForGroupVisible] Invalid URL")
            isLoading = false
            showNetworkLoader = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Get viewer_uid (matching Android Constant.getSF.getString(Constant.UID_KEY, ""))
        let viewerUid = Constant.SenderIdMy
        
        // Create form-encoded body (matching Android MultipartBody)
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "group_id", value: group.groupId),
            URLQueryItem(name: "viewer_uid", value: viewerUid)
        ]
        request.httpBody = components.query?.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                showNetworkLoader = false
                
                if let error = error {
                    print("🚫 [ForGroupVisible] Error fetching group members: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    print("🚫 [ForGroupVisible] No data received")
                    return
                }
                
                do {
                    // Print raw response for debugging
                    if let rawString = String(data: data, encoding: .utf8) {
                        print("📥 [ForGroupVisible] Raw API response: \(rawString.prefix(500))")
                    }
                    
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("📥 [ForGroupVisible] Parsed JSON keys: \(json.keys)")
                        print("📥 [ForGroupVisible] Full JSON: \(json)")
                        
                        // Check error_code first (matching API response structure)
                        if let errorCode = json["error_code"] as? String, errorCode != "200" {
                            print("🚫 [ForGroupVisible] API returned error: \(errorCode)")
                            if let message = json["message"] as? String {
                                print("🚫 [ForGroupVisible] Error message: \(message)")
                            }
                            return
                        }
                        
                        // Response structure: { "data": { "group_name": "...", "group_icon": "...", "themeColor": "...", "members": [...] } }
                        // Matching Android get_group_detailsResponseModel -> groupD -> members
                        if let dataDict = json["data"] as? [String: Any] {
                            print("✅ [ForGroupVisible] Found data dictionary")
                            
                            // Update group name and icon from response (matching Android)
                            if let groupNameFromAPI = dataDict["group_name"] as? String {
                                self.groupName = groupNameFromAPI
                                print("✅ [ForGroupVisible] Updated group name: \(groupNameFromAPI)")
                            }
                            
                            if let groupIconFromAPI = dataDict["group_icon"] as? String {
                                self.groupIcon = groupIconFromAPI
                                print("✅ [ForGroupVisible] Updated group icon: \(groupIconFromAPI)")
                            }
                            
                            // Get themeColor from data level (matching API response)
                            if let themeColorFromAPI = dataDict["themeColor"] as? String {
                                self.themeColorHex = themeColorFromAPI
                                print("✅ [ForGroupVisible] Updated theme color: \(themeColorFromAPI)")
                            }
                            
                            // Get members array from data.members (matching Android data.getMembers())
                            if let membersArray = dataDict["members"] as? [[String: Any]] {
                                print("✅ [ForGroupVisible] Found members array with \(membersArray.count) items")
                                
                                var fetchedMembers: [GroupMember] = []
                                for (index, memberDict) in membersArray.enumerated() {
                                    print("📥 [ForGroupVisible] Parsing member \(index): \(memberDict.keys)")
                                    print("📥 [ForGroupVisible] Member data: \(memberDict)")
                                    
                                    // Create a properly formatted member dictionary for GroupMember
                                    var formattedMember: [String: Any] = [:]
                                    
                                    // Map API fields to GroupMember fields
                                    if let uid = memberDict["uid"] {
                                        formattedMember["uid"] = uid
                                    }
                                    if let fullName = memberDict["full_name"] {
                                        formattedMember["full_name"] = fullName
                                    }
                                    if let mobileNo = memberDict["mobile_no"] {
                                        formattedMember["mobile_no"] = mobileNo
                                    }
                                    if let photo = memberDict["photo"] {
                                        formattedMember["photo"] = photo
                                    }
                                    if let caption = memberDict["caption"] {
                                        formattedMember["caption"] = caption
                                    }
                                    // Use themeColor from data level for all members
                                    formattedMember["themeColor"] = dataDict["themeColor"] ?? self.themeColorHex
                                    
                                    // Try to decode member
                                    do {
                                        let memberData = try JSONSerialization.data(withJSONObject: formattedMember)
                                        let decoder = JSONDecoder()
                                        let member = try decoder.decode(GroupMember.self, from: memberData)
                                        fetchedMembers.append(member)
                                        print("✅ [ForGroupVisible] Successfully parsed member \(index): \(member.full_name ?? "no name"), uid: \(member.uid ?? "no uid")")
                                    } catch {
                                        print("🚫 [ForGroupVisible] Failed to parse member \(index): \(error.localizedDescription)")
                                        print("🚫 [ForGroupVisible] Decoding error details: \(error)")
                                        print("🚫 [ForGroupVisible] Formatted member dict: \(formattedMember)")
                                    }
                                }
                                
                                self.members = fetchedMembers
                                print("✅ [ForGroupVisible] Loaded \(fetchedMembers.count) members out of \(membersArray.count) total")
                                print("✅ [ForGroupVisible] Current user UID: \(Constant.SenderIdMy)")
                                print("✅ [ForGroupVisible] Filtered members count: \(self.filteredMembers.count)")
                            } else {
                                print("⚠️ [ForGroupVisible] No 'members' array found in data dictionary")
                                print("⚠️ [ForGroupVisible] Data keys: \(dataDict.keys)")
                            }
                        } else {
                            print("⚠️ [ForGroupVisible] No 'data' dictionary found in response")
                            print("⚠️ [ForGroupVisible] Response structure: \(json)")
                        }
                    } else {
                        print("🚫 [ForGroupVisible] Failed to parse JSON as dictionary")
                    }
                } catch {
                    print("🚫 [ForGroupVisible] JSON parsing error: \(error.localizedDescription)")
                    if let rawString = String(data: data, encoding: .utf8) {
                        print("🚫 [ForGroupVisible] Raw response: \(rawString)")
                    }
                }
            }
        }.resume()
    }
}

// MARK: - Member Row View
struct MemberRowView: View {
    let member: GroupMember
    let onImageTap: () -> Void
    let onRowTap: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: {
            onRowTap()
        }) {
            HStack(spacing: 0) {
                // Profile image with theme border
                Button(action: {
                    onImageTap()
                }) {
                    ZStack {
                        // Border with theme color
                        RoundedRectangle(cornerRadius: 360)
                            .stroke(getThemeBorderColor(), lineWidth: 2)
                            .frame(width: 52, height: 52)
                        
                        // Profile image
                        CachedAsyncImage(
                            url: URL(string: member.photo ?? ""),
                            content: { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            },
                            placeholder: {
                                Image("inviteimg")
                                    .resizable()
                                    .scaledToFill()
                            }
                        )
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.leading, 18)
                .padding(.trailing, 20)
                
                // Name and caption
                VStack(alignment: .leading, spacing: 0) {
                    // Name (truncated to 20 chars)
                    Text(getDisplayName())
                        .font(.custom("Inter18pt-Bold", size: 16))
                        .fontWeight(.bold)
                        .foregroundColor(Color("TextColor"))
                        .lineLimit(1)
                    
                    // Caption (truncated to 35 chars)
                    Text(getDisplayCaption())
                        .font(.custom("Inter18pt-Medium", size: 12))
                        .fontWeight(.medium)
                        .foregroundColor(Color(hex: "#9EA6B9"))
                        .lineLimit(1)
                        .padding(.top, 0)
                }
                
                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 17)
            .background(
                isPressed ? Color("customRipple") : Color.clear
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
    
    // MARK: - Get Display Name
    private func getDisplayName() -> String {
        let currentUid = Constant.SenderIdMy
        let name: String
        
        if let uid = member.uid, uid == currentUid {
            // Show current user's name with "(You)"
            let userName = UserDefaults.standard.string(forKey: Constant.full_name) ?? ""
            name = userName.isEmpty ? (member.full_name ?? "") : userName
            return name + " (You)"
        } else {
            name = member.full_name ?? ""
        }
        
        // Truncate to 20 chars
        if name.count > 20 {
            return String(name.prefix(20)) + "..."
        }
        return name
    }
    
    // MARK: - Get Display Caption
    private func getDisplayCaption() -> String {
        let caption = member.caption ?? ""
        
        // Truncate to 35 chars
        if caption.count > 35 {
            return String(caption.prefix(35)) + "..."
        }
        return caption
    }
    
    // MARK: - Get Theme Border Color
    private func getThemeBorderColor() -> Color {
        guard let themeColor = member.themeColor, !themeColor.isEmpty else {
            return Color(hex: Constant.themeColor)
        }
        return Color(hex: themeColor)
    }
}

// MARK: - Helper Function
private func getMainvectorTintColor(for themeColor: String) -> Color {
    // Return darker tint color based on theme (matching Android logic)
    return Color(hex: "#01253B")
}
