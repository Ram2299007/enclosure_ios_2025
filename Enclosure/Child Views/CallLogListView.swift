import SwiftUI

struct CallLogListView: View {
    let sections: [CallLogSection]
    let logType: CallLogViewModel.LogType
    var onEntrySelected: ((CallLogUserInfo) -> Void)? = nil
    var onLongPress: ((CallLogUserInfo, CGPoint) -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(sections) { section in
                CallLogSectionView(
                    section: section,
                    logType: logType,
                    onEntrySelected: onEntrySelected,
                    onLongPress: onLongPress
                )
            }
        }
        .padding(.top, 5)
    }
}

struct CallLogSectionView: View {
    let section: CallLogSection
    let logType: CallLogViewModel.LogType
    var onEntrySelected: ((CallLogUserInfo) -> Void)? = nil
    var onLongPress: ((CallLogUserInfo, CGPoint) -> Void)? = nil
    
    private var formattedTitle: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = dateFormatter.date(from: section.date) else {
            return section.date
        }
        
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "MMM d"
            return outputFormatter.string(from: date)
        }
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 10) {
                Text(formattedTitle)
                    .font(.custom("Inter18pt-SemiBold", size: 14))
                    .foregroundColor(Color("TextColor"))
                    .padding(.leading, 20)
                
                VStack(spacing: 0) {
                    ForEach(section.userInfo) { entry in
                        CallLogUserRowView(
                            entry: entry,
                            logType: logType,
                            onEntrySelected: onEntrySelected,
                            onLongPress: onLongPress
                        )
                            .padding(.bottom, 2)
                    }
                }
                .background(Color("background_color"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}

struct CallLogUserRowView: View {
    let entry: CallLogUserInfo
    let logType: CallLogViewModel.LogType
    var onEntrySelected: ((CallLogUserInfo) -> Void)? = nil
    var onLongPress: ((CallLogUserInfo, CGPoint) -> Void)? = nil
    
    @State private var isExpanded: Bool = false
    @State private var callButtonWidth: CGFloat = 0
    @State private var isPressed = false
    @State private var exactTouchLocation: CGPoint = .zero
    @State private var isLongPressing = false
    
    private var displayName: String {
        if entry.fullName.count > 22 {
            return String(entry.fullName.prefix(22)) + "..."
        }
        return entry.fullName
    }
    
    private var callStatusIconName: String {
        switch entry.callingFlag {
        case "0":
            return "outgoingcall"
        case "1":
            return "incomingcall"
        case "2":
            return "miss_call_svg"
        default:
            return "incomingcall"
        }
    }
    
    private var callStatusColor: Color {
        switch entry.callingFlag {
        case "0", "1":
            // Matches Android green_call (#0FA430)
            return Color(hex: "#0FA430")
        case "2":
            // Matches Android miss_call color (#EC0000)
            return Color(hex: "#EC0000")
        default:
            return Color("TextColor")
        }
    }
    
    private var formattedTime: String {
        let rawTime = entry.endTime.isEmpty ? entry.startTime : entry.endTime
        guard !rawTime.isEmpty else { return "--" }
        
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "hh:mm:ss a"
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "hh:mm a"
        outputFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        if let date = inputFormatter.date(from: rawTime) {
            return outputFormatter.string(from: date)
        }
        
        // Try without seconds
        inputFormatter.dateFormat = "hh:mm a"
        if let date = inputFormatter.date(from: rawTime) {
            return outputFormatter.string(from: date)
        }
        
        return rawTime
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Main content container - matching Android LinearLayout with margins
                HStack(spacing: 0) {
                    // Profile image - matching Android themeBorder FrameLayout
                    // Android: 48dp image, 2dp padding = 52dp total
                    CallLogContactCardView(image: entry.photo, themeColor: entry.themeColor)
                        .padding(.leading, 20) // Reduced outer horizontal margin
                    
                    // Name and time container - matching Android LinearLayout
                    HStack(spacing: 0) {
                        // Name and time VStack - matching Android LinearLayout with marginStart="24dp"
                        VStack(alignment: .leading, spacing: 0) {
                            // Name TextView - matching Android: 16sp, Inter Bold, lineHeight="18dp"
                            Text(displayName)
                                .font(.custom("Inter18pt-SemiBold", size: 16))
                                .foregroundColor(Color("TextColor"))
                                .lineLimit(1)
                                .lineSpacing(0)
                                .frame(height: 18) // lineHeight="18dp"
                            
                            // Time row - matching Android LinearLayout with marginTop="4dp"
                            HStack(spacing: 8) {
                                // Calling flag icon - matching Android: 15dp height, weight 4
                                Image(callStatusIconName)
                                    .resizable()
                                    .renderingMode(.template)
                                    .foregroundColor(callStatusColor)
                                    .frame(width: 17, height: 15, alignment: .leading)
                                
                                // Time TextView - matching Android: 13sp, Inter Medium, weight 1
                                Text(formattedTime)
                                    .font(.custom("Inter18pt-Medium", size: 13))
                                    .foregroundColor(Color("Gray3"))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.top, 4) // marginTop="4dp"
                        }
                        .padding(.leading, 24) // marginStart="24dp" from image to name
                        .frame(maxWidth: .infinity) // layout_weight="1"
                        
                        // Call icon container - matching Android call1 LinearLayout
                        // Android: layout_weight="5", gravity="center|end"
                        HStack {
                            Spacer()
                            HStack(spacing: isExpanded ? 0 : 6) {
                                // Call icon - matching Android callIcon
                                Button(action: {
                                    expandCallButton()
                                }) {
                                    Group {
                                        if logType == .video {
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
                                        } else {
                                            Image("cllingnewpng")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 22, height: 22)
                                                .foregroundColor(Color(hex: entry.themeColor.isEmpty ? "#00A3E9" : entry.themeColor))
                                        }
                                    }
                                }
                                
                                // Expandable call button - matching CallingContactRowView design
                                if isExpanded {
                                    Button(action: {
                                        print("📞 Call log action -> \(entry.fullName)")
                                        // TODO: Hook actual call flow
                                    }) {
                                        ZStack {
                                            // Matching Android curve_left_bg: rounded left corners 100dp, right corners 0dp
                                            UnevenRoundedRectangle(
                                                cornerRadii: .init(
                                                    topLeading: 100,
                                                    bottomLeading: 100,
                                                    bottomTrailing: 0,
                                                    topTrailing: 0
                                                )
                                            )
                                            .fill(Color(hex: entry.themeColor.isEmpty ? "#00A3E9" : entry.themeColor))
                                            
                                            Text("Call")
                                                .font(.custom("Inter18pt-Bold", size: 16))
                                                .foregroundColor(.white)
                                        }
                                        .frame(width: callButtonWidth, height: 40, alignment: .center)
                                    }
                                }
                            }
                            .padding(.trailing, isExpanded ? 0 : 22) // remove spacing when expanded so button touches edge
                        }
                        .frame(maxWidth: .infinity) // layout_weight="5"
                    }
                    .frame(maxWidth: .infinity) // layout_weight="1" for outer container
                    .padding(.trailing, 0) // Reduced outer horizontal margin
                }
                .padding(.top, 5) // marginTop="5dp"
                .padding(.bottom, 5) // marginBottom="5dp"
                .frame(maxWidth: .infinity) // layout_weight="1"
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isPressed ? Color.gray.opacity(0.1) : Color("background_color"))
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isPressed)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isPressed = true
                        // Capture exact touch location
                        exactTouchLocation = value.location
                    }
                    .onEnded { _ in
                        isPressed = false
                        // Single tap - only execute if not a long press
                        if !isLongPressing {
                            if let onEntrySelected {
                                onEntrySelected(entry)
                            } else if !isExpanded {
                                expandCallButton()
                            }
                        }
                        // Reset long press flag after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isLongPressing = false
                        }
                    }
            )
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        // Mark that long press occurred to prevent tap action
                        isLongPressing = true
                        
                        // Convert exact touch location to global screen coordinates
                        let globalFrame = geometry.frame(in: .global)
                        let globalX = globalFrame.minX + exactTouchLocation.x
                        let globalY = globalFrame.minY + exactTouchLocation.y
                        print("🟢 Long press on call log at exact location - Local: \(exactTouchLocation), Global: (\(globalX), \(globalY))")
                        if let onLongPress {
                            onLongPress(entry, CGPoint(x: globalX, y: globalY))
                        }
                    }
            )
        }
        .frame(height: 62) // Fixed height for consistent layout (5+52+5)
    }
    
    private func expandCallButton() {
        isExpanded = true
        // Android request: keep bg_rect width to 60dp (≈ 70pt in iOS) - matching CallingContactRowView
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

// Call log specific contact card view - matching Android: 48dp image, 2dp padding = 52dp total
struct CallLogContactCardView: View {
    var image: String?
    var themeColor: String
    
    var body: some View {
        // FrameLayout with border - matching Android card_border
        // FrameLayout: padding="2dp", Image: 48dp x 48dp (not 50dp)
        ZStack {
            // Border background (card_border equivalent) - using theme color
            // The border is 2dp wide, so outer circle is 52dp (48 + 2*2)
            Circle()
                .stroke(Color(hex: themeColor.isEmpty ? "#00A3E9" : themeColor), lineWidth: 2)
                .frame(width: 52, height: 52)
            
            CachedAsyncImage(url: URL(string: image ?? "")) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
            } placeholder: {
                Image("inviteimg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
            }
            .frame(width: 48, height: 48) // 48dp x 48dp as per Android
        }
        .frame(width: 52, height: 52) // Total FrameLayout size: 52dp x 52dp
    }
}

