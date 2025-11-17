import SwiftUI

struct CallLogListView: View {
    let sections: [CallLogSection]
    let logType: CallLogViewModel.LogType
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(sections) { section in
                CallLogSectionView(section: section, logType: logType)
            }
        }
        .padding(.top, 5)
    }
}

struct CallLogSectionView: View {
    let section: CallLogSection
    let logType: CallLogViewModel.LogType
    
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
                        CallLogUserRowView(entry: entry, logType: logType)
                            .padding(.bottom, 2)
                    }
                }
                .background(Color("background_color"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 12)
        }
    }
}

struct CallLogUserRowView: View {
    let entry: CallLogUserInfo
    let logType: CallLogViewModel.LogType
    
    @State private var isExpanded: Bool = false
    @State private var callButtonWidth: CGFloat = 0
    
    private var displayName: String {
        if entry.fullName.count > 22 {
            return String(entry.fullName.prefix(22)) + "..."
        }
        return entry.fullName
    }
    
    private var callStatusIconName: String {
        switch entry.callingFlag {
        case "0":
            return "arrow.up.right"
        case "1":
            return "arrow.down.left"
        case "2":
            return "phone.down"
        default:
            return "phone"
        }
    }
    
    private var callStatusColor: Color {
        switch entry.callingFlag {
        case "0":
            return Color(hex: "#27AE60")
        case "1":
            return Color(hex: "#00A3E9")
        case "2":
            return Color.red
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
        HStack(spacing: 0) {
            CallingContactCardView(image: entry.photo, themeColor: entry.themeColor)
                .padding(.leading, 20)
                .padding(.trailing, 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.custom("Inter18pt-Bold", size: 16))
                    .foregroundColor(Color("TextColor"))
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Image(systemName: callStatusIconName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(callStatusColor)
                    
                    Text(formattedTime)
                        .font(.custom("Inter18pt-Medium", size: 13))
                        .foregroundColor(Color("Gray3"))
                }
            }
            .padding(.trailing, 10)
            
            Spacer()
            
            HStack(spacing: isExpanded ? 0 : 6) {
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
                                .foregroundColor(Color(hex: entry.themeColor))
                        }
                    }
                }
                
                if isExpanded {
                    Button(action: {
                        print("📞 Call log action -> \(entry.fullName)")
                        // TODO: Hook actual call flow
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
                            .fill(Color(hex: entry.themeColor))
                            
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
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("background_color"))
        .contentShape(Rectangle())
        .onTapGesture {
            if !isExpanded {
                expandCallButton()
            }
        }
    }
    
    private func expandCallButton() {
        isExpanded = true
        callButtonWidth = 0
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.4)) {
                callButtonWidth = 80
            }
        }
    }
}

