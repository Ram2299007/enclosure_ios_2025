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
    @StateObject private var callLogViewModel = CallLogViewModel()
    @State private var dragOffset: CGSize = .zero
    @State private var isStretchedUp = false
    @State private var isButtonVisible = false
    @Binding var isMainContentVisible: Bool
    @Binding var isTopHeaderVisible: Bool
    @State private var isPressed = false
    
    // Long press dialog state - use @Binding to connect to parent
    @Binding var selectedCallLogForDialog: CallLogUserInfo?
    @Binding var callDialogPosition: CGPoint
    @Binding var showCallLogDialog: Bool
    
    // Clear log dialog state - use @Binding to connect to parent
    @Binding var showClearLogDialog: Bool
    
    // Tab state
    @State private var selectedTab: CallTab = .log
    @State private var isSearchVisible = false
    @State private var searchText = ""
    @State private var isBackLayoutVisible = false
    @State private var isContactLayoutVisible = false
    @State private var isBottomCallerVisible = false
    @State private var isShowingCallHistory = false
    @State private var selectedHistoryContact: CallLogUserInfo?
    @State private var selectedHistoryEntries: [CallHistoryEntry] = []
    @State private var selectedHistoryDateLabel: String = ""
    @State private var wasBackLayoutVisibleBeforeHistory = false
    @State private var wasTopHeaderVisibleBeforeHistory = false
    
    enum CallTab {
        case log, contact
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredContacts: [CallingContactModel] {
        guard !trimmedSearchText.isEmpty else { return viewModel.contactList }

        return viewModel.contactList.filter { contact in
            contact.fullName.lowercased().contains(trimmedSearchText.lowercased()) ||
            contact.mobileNo.contains(trimmedSearchText)
        }
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
                            withAnimation(.easeOut(duration: 0.2)) {
                                showClearLogDialog = true
                            }
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
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Search section (searchData) - matching MainActivityOld.swift pattern and Android spacing
                // Search icon always visible when on contact tab, search bar slides in/out
                if selectedTab == .contact && !isShowingCallHistory {
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
                                    if !isSearchVisible {
                                        searchText = ""
                                    }
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
                
                if isShowingCallHistory, let selectedHistoryContact {
                    CallHistoryHeaderView(
                        contact: selectedHistoryContact,
                        dateLabel: selectedHistoryDateLabel
                    )
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Tabs section (label) - matching Android design with exact spacing
                if !isShowingCallHistory {
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
                                withAnimation(.easeOut(duration: 0.2)) {
                                    showClearLogDialog = true
                                }
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
                }
                
                // Content area - RecyclerViews
                ZStack {
                    if isShowingCallHistory {
                if selectedHistoryEntries.isEmpty {
                    logEmptyStateView(text: "No detailed history yet")
                } else {
                    ScrollView {
                        CallHistoryListView(
                            entries: selectedHistoryEntries,
                            logType: .voice,
                            themeHex: selectedHistoryContact?.themeColor ?? "#00A3E9"
                        )
                        .padding(.top, 4)
                    }
                    .transition(.opacity)
                }
                    }
                    // Log RecyclerView (recyclerviewLast)
                    else if selectedTab == .log {
                        ZStack {
                            if callLogViewModel.isLoading && !callLogViewModel.hasCachedSections {
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
                                callHistoryEmptyStateView()
                            } else {
                                ScrollView {
                                    CallLogListView(
                                        sections: callLogViewModel.sections,
                                        logType: .voice,
                                        onEntrySelected: handleCallHistorySelection,
                                        onLongPress: { callLog, position in
                                            selectedCallLogForDialog = callLog
                                            callDialogPosition = position
                                            showCallLogDialog = true
                                        }
                                    )
                                }
                                .transition(.opacity)
                            }
                        }
                        .transition(.opacity)
                    }
                    
                    // Contact RecyclerView (recyclerviewAZ)
                    if selectedTab == .contact {
                        ZStack {
                            if viewModel.isLoading && !viewModel.hasCachedContacts {
                                // Progress bar - matching Android
                                ProgressView()
                                    .progressViewStyle(LinearProgressViewStyle(tint: Color("TextColor")))
                                    .frame(width: 40, height: 2)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else if filteredContacts.isEmpty {
                                if viewModel.contactList.isEmpty {
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
                                    Text("No contacts found")
                                        .font(.custom("Inter18pt-Medium", size: 14))
                                        .foregroundColor(Color("TextColor"))
                                        .padding(12)
                                        .background(Color("cardBackgroundColornew"))
                                        .cornerRadius(20)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                            } else {
                                let _ = print("📞 [callView] Showing contact list - contactList count: \(filteredContacts.count)")
                                // Contact list
                                ScrollView {
                                    VStack(spacing: 0) {
                                        ForEach(filteredContacts, id: \.uid) { contact in
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
            // Only apply drag gesture when not stretched up to avoid interfering with scrolling
            !isStretchedUp ? DragGesture()
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
                            isTopHeaderVisible = true
                        }
                    } else if value.translation.height > 50 {
                        handleSwipeDown()
                    }
                    dragOffset = .zero
                } : nil
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
            isTopHeaderVisible = false
            callLogViewModel.fetchCallLogs(uid: Constant.SenderIdMy, force: true)
        }
        }
    }


// MARK: - Tab handling helpers
extension callView {
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
    
    private func handleCallHistorySelection(entry: CallLogUserInfo) {
        wasBackLayoutVisibleBeforeHistory = isBackLayoutVisible
        wasTopHeaderVisibleBeforeHistory = isTopHeaderVisible
        selectedHistoryContact = entry
        selectedHistoryDateLabel = formattedHistoryDate(from: entry.date)
        
        let sortedHistory = entry.callHistory.sorted { first, second in
            let firstDate = CallHistoryFormatter.combinedDate(
                date: first.date.isEmpty ? entry.date : first.date,
                time: historyReferenceTime(for: first)
            )
            let secondDate = CallHistoryFormatter.combinedDate(
                date: second.date.isEmpty ? entry.date : second.date,
                time: historyReferenceTime(for: second)
            )
            
            switch (firstDate, secondDate) {
            case let (lhs?, rhs?):
                return lhs > rhs
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            default:
                return (first.id) > (second.id)
            }
        }
        
        selectedHistoryEntries = sortedHistory
        
        withAnimation(.easeInOut(duration: 0.35)) {
            isShowingCallHistory = true
            isBackLayoutVisible = true
            isTopHeaderVisible = wasTopHeaderVisibleBeforeHistory
        }
    }
    
    private func historyReferenceTime(for entry: CallHistoryEntry) -> String {
        if !entry.endTime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return entry.endTime
        }
        if !entry.startTime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return entry.startTime
        }
        return ""
    }
    
    private func clearHistorySelection(animated: Bool = true) {
        let resetState = {
            self.isShowingCallHistory = false
            self.selectedHistoryEntries = []
            self.selectedHistoryContact = nil
            self.selectedHistoryDateLabel = ""
            self.isBackLayoutVisible = self.wasBackLayoutVisibleBeforeHistory
            self.isTopHeaderVisible = self.wasTopHeaderVisibleBeforeHistory
            self.wasBackLayoutVisibleBeforeHistory = false
            self.wasTopHeaderVisibleBeforeHistory = false
        }
        
        if animated {
            withAnimation(.easeInOut(duration: 0.3)) {
                resetState()
            }
        } else {
            resetState()
        }
    }
    
    private func formattedHistoryDate(from rawDate: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        guard let date = inputFormatter.date(from: rawDate) else {
            return rawDate
        }
        
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "MMM d"
        outputFormatter.locale = Locale(identifier: "en_US_POSIX")
        return outputFormatter.string(from: date)
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
    
    @ViewBuilder
    private func callHistoryEmptyStateView() -> some View {
        VStack {
            // CardView equivalent with wrap_content size and center positioning
            VStack(spacing: 0) {
                // "Call On Enclosure" text (initially hidden like Android visibility="gone")
                // This can be shown conditionally if needed
                
                // LinearLayout with marginTop="2dp" and horizontal orientation
                HStack(spacing: 0) {
                    Text("Press  ")
                        .font(.custom("Inter18pt-Medium", size: 14))
                        .foregroundColor(Color("TextColor"))
                    
                    Text("A - Z  ")
                        .font(.custom("Inter18pt-Medium", size: 14))
                        .foregroundColor(Color("TextColor"))
                    
                    Text("for contact")
                        .font(.custom("Inter18pt-Medium", size: 14))
                        .foregroundColor(Color("TextColor"))
                }
                .padding(.top, 2) // layout_marginTop="2dp"
            }
            .padding(12) // android:padding="12dp"
            .background(
                // Use a more contrasting background that works in both light and dark modes
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color("cardBackgroundColornew"))
                    .shadow(
                        color: Color.black.opacity(0.1), // Light shadow for elevation
                        radius: 8, // Android elevation equivalent
                        x: 0,
                        y: 4
                    )
            )
            .overlay(
                // Add a subtle border for better visibility in light mode
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // layout_centerInParent="true" equivalent
    }

    private func handleBackArrowTap() {
        if isShowingCallHistory {
            clearHistorySelection()
            return
        }
        
        withAnimation {
            isPressed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPressed = false
            handleSwipeDown()
        }
    }
    
    private func handleSwipeDown() {
        if isShowingCallHistory {
            clearHistorySelection(animated: false)
        }
        
        withAnimation(.easeInOut(duration: 0.45)) {
            isPressed = true
            isStretchedUp = false
            isMainContentVisible = true
            isTopHeaderVisible = false
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
        Button(action: handleBackArrowTap) {
            ZStack {
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
                    .foregroundColor(Color("icontintGlobal"))
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
    }
    
}

// Call history detail header - matching Android layoutName section
struct CallHistoryHeaderView: View {
    let contact: CallLogUserInfo
    let dateLabel: String
    
    var body: some View {
        HStack(spacing: 16) {
            CallLogContactCardView(image: contact.photo, themeColor: contact.themeColor)
                .padding(.leading, 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.fullName)
                    .font(.custom("Inter18pt-SemiBold", size: 18))
                    .foregroundColor(Color("TextColor"))
                    .lineLimit(1)
                
                Text(contact.mobileNo)
                    .font(.custom("Inter18pt-Medium", size: 14))
                    .foregroundColor(Color("Gray3"))
                
                if !dateLabel.isEmpty {
                    Text(dateLabel)
                        .font(.custom("Inter18pt-Medium", size: 13))
                        .foregroundColor(Color("Gray3"))
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// Call history list - matching call_history_adapter styling
struct CallHistoryListView: View {
    let entries: [CallHistoryEntry]
    let logType: CallLogViewModel.LogType
    let themeHex: String
    
    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                    CallHistoryRowView(entry: entry, logType: logType, themeHex: themeHex)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                }
            }
            .background(Color("cardBackgroundColornew"))
            .cornerRadius(20)
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 10)
    }
}

struct CallHistoryRowView: View {
    let entry: CallHistoryEntry
    let logType: CallLogViewModel.LogType
    let themeHex: String
    
    private var iconImageName: String {
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
    
    private var statusColor: Color {
        switch entry.callingFlag {
        case "0", "1":
            return Color(hex: "#0FA430")
        case "2":
            return Color(hex: "#EC0000")
        default:
            return Color("TextColor")
        }
    }
    
    private var statusText: String {
        switch entry.callingFlag {
        case "0":
            return "Outgoing"
        case "1":
            return "Incoming"
        case "2":
            return "Missed"
        default:
            return "Call"
        }
    }
    
    private var readableEndTime: String {
        let fallbackTime = entry.endTime.isEmpty ? entry.startTime : entry.endTime
        guard !fallbackTime.isEmpty else { return "--" }
        return CallHistoryFormatter.formattedTime(from: fallbackTime)
    }
    
    private var durationText: String? {
        guard entry.callingFlag != "2" else { return nil }
        return CallHistoryFormatter.durationBetween(
            start: entry.startTime,
            end: entry.endTime
        )
    }
    
    var body: some View {
        HStack(spacing: 0) {
            Image(iconImageName)
                .resizable()
                .renderingMode(.template)
                .foregroundColor(statusColor)
                .frame(width: 17, height: 15)
                .padding(.leading, 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(statusText)
                    .font(.custom("Inter18pt-Medium", size: 16))
                    .foregroundColor(Color("TextColor"))
                Text(readableEndTime)
                    .font(.custom("Inter18pt-Medium", size: 13))
                    .foregroundColor(Color("Gray3"))
            }
            .padding(.leading, 16)
            
            Spacer()
            
            if logType == .video {
                ZStack {
                    Image("videosvgnew2")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(Color(hex: themeHex))
                        .frame(width: 22, height: 15)
                    Image("polysvg")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(.white)
                        .frame(width: 5, height: 5)
                        .offset(x: 2, y: -0.5)
                }
                .padding(.trailing, durationText == nil ? 0 : 10)
            }
            
            if let durationText, !durationText.isEmpty {
                Text(durationText)
                    .font(.custom("Inter18pt-Medium", size: 13))
                    .foregroundColor(Color("Gray3"))
                    .padding(.trailing, 20)
            } else {
                Spacer()
                    .frame(width: 20)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 40)
    }
}

// Contact row view matching Android get_calling_contact_voice_row.xml
struct CallingContactRowView: View {
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
                
                // Name and call icon/button stack - matching Android LinearLayout
                HStack(spacing: 0) {
                    Text(displayName)
                        .font(.custom("Inter18pt-SemiBold", size: 16))
                        .foregroundColor(Color("TextColor"))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    HStack(spacing: isExpanded ? 0 : 6) {
                        // Call icon - matching Android callIcon with marginEnd="22dp"
                        // Call icon is clickable and triggers expansion
                        Button(action: {
                            expandCallButton()
                        }) {
                            Image("cllingnewpng")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 22, height: 22)
                                .foregroundColor(Color(hex: contact.themeColor.isEmpty ? "#00A3E9" : contact.themeColor))
                        }
                        
                        if isExpanded {
                            Button(action: {
                                // Call action - matching Android clickView onClick
                                print("📞 Calling: \(contact.fullName)")
                                // TODO: Implement actual call functionality
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
                    .padding(.trailing, isExpanded ? 0 : 22) // remove spacing when expanded so button touches edge
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
            
            CachedAsyncImage(url: URL(string: image ?? "")) { image in
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
            }
            .frame(width: 50, height: 50) // 50dp x 50dp as per Android
        }
        .frame(width: 54, height: 54) // Total FrameLayout size: 54dp x 54dp (50dp image + 2dp border on each side)
    }
}

// CallLogLongPressDialog - Matching Android voice_call_child_log_row_dialogue.xml
extension callView {
    struct CallLogLongPressDialog: View {
        let callLog: CallLogUserInfo
        let position: CGPoint
        let logType: CallLogViewModel.LogType
        @Binding var isShowing: Bool
        let onDelete: () -> Void
        
        // Calculate adjusted offset X - full width (match_parent)
        private func adjustedOffsetX(in geometry: GeometryProxy) -> CGFloat {
            return 0 // Full width, no horizontal offset
        }
        
        // Calculate adjusted offset Y
        private func adjustedOffsetY(in geometry: GeometryProxy) -> CGFloat {
            let callLogCardHeight: CGFloat = 82 // Call log card with padding
            let deleteButtonHeight: CGFloat = 83 // Button (48) + margins (10+25)
            let dialogHeight = callLogCardHeight + deleteButtonHeight // ~165
            let padding: CGFloat = 20
            let frame = geometry.frame(in: .global)
            let localY = position.y - frame.minY
            let centeredY = localY - (callLogCardHeight / 2) // Center card at touch point
            let maxY = geometry.size.height - dialogHeight - padding
            return min(max(centeredY, padding), maxY)
        }
        
        private var callStatusIconName: String {
            switch callLog.callingFlag {
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
            switch callLog.callingFlag {
            case "0", "1":
                return Color(hex: "#0FA430")
            case "2":
                return Color(hex: "#EC0000")
            default:
                return Color("TextColor")
            }
        }
        
        private var formattedTime: String {
            let rawTime = callLog.endTime.isEmpty ? callLog.startTime : callLog.endTime
            guard !rawTime.isEmpty else { return "--" }
            return CallHistoryFormatter.formattedTime(from: rawTime)
        }
        
        var body: some View {
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    // Blurred background overlay
                    Color.black.opacity(0.3)
                        .background(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .zIndex(0)
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.2)) {
                                isShowing = false
                            }
                        }
                    
                    // Dialog content
                    VStack(spacing: 0) {
                        // Call log card view (matching voice_call_child_log_row_dialogue.xml)
                        VStack(spacing: 0) {
                            // LinearLayout with marginStart="26dp" marginTop="10dp" marginEnd="24dp" marginBottom="15dp"
                            HStack(spacing: 0) {
                                // FrameLayout id="themeBorder" - profile image with border
                                // marginStart="1dp" marginEnd="16dp" padding="2dp"
                                CallLogContactCardView(image: callLog.photo, themeColor: callLog.themeColor)
                                    .padding(.leading, 1) // marginStart="1dp"
                                    .padding(.trailing, 16) // marginEnd="16dp"
                                
                                // Vertical LinearLayout for name/time
                                VStack(alignment: .leading, spacing: 0) {
                                    // TextView id="name" - Name
                                    // fontFamily="@font/inter_bold" textSize="16sp" lineHeight="18dp"
                                    Text(callLog.fullName.count > 22 ? String(callLog.fullName.prefix(22)) + "..." : callLog.fullName)
                                        .font(.custom("Inter18pt-SemiBold", size: 16))
                                        .foregroundColor(Color("TextColor"))
                                        .lineLimit(1)
                                        .frame(height: 18) // lineHeight="18dp"
                                    
                                    // Horizontal LinearLayout with marginTop="4dp"
                                    HStack(spacing: 8) {
                                        // ImageView id="calling_flag" - Call status icon
                                        // layout_weight="4" height="15dp"
                                        Image(callStatusIconName)
                                            .resizable()
                                            .renderingMode(.template)
                                            .foregroundColor(callStatusColor)
                                            .frame(width: 17, height: 15, alignment: .leading)
                                        
                                        // TextView id="endTime" - Time
                                        // layout_weight="1" textSize="13sp" fontFamily="@font/inter_medium"
                                        Text(formattedTime)
                                            .font(.custom("Inter18pt-Medium", size: 13))
                                            .foregroundColor(Color("TextColor"))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.top, 4) // layout_marginTop="4dp"
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Call icon (callIcon) - matching Android
                                // layout_weight="5" gravity="center|end"
                                Spacer()
                                
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
                                    .padding(.trailing, 22)
                                } else {
                                    Image("cllingnewpng")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 22, height: 22)
                                        .foregroundColor(Color(hex: callLog.themeColor.isEmpty ? "#00A3E9" : callLog.themeColor))
                                        .padding(.trailing, 22)
                                }
                            }
                            .padding(.leading, 26) // marginStart="26dp"
                            .padding(.top, 10) // marginTop="10dp"
                            .padding(.trailing, 24) // marginEnd="24dp"
                            .padding(.bottom, 15) // marginBottom="15dp"
                        }
                        .background(Color("BackgroundColor"))
                        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                        
                        // Delete button (deletecardview)
                        // layout_marginHorizontal="20dp" layout_marginTop="10dp" layout_marginBottom="25dp"
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                onDelete()
                            }
                        }) {
                            HStack(spacing: 0) {
                                Spacer()
                                
                                // ImageView - delete icon
                                // width="26.5dp" height="24dp" layout_marginEnd="2dp"
                                Image("baseline_delete_forever_24")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 26.5, height: 24)
                                    .foregroundColor(Color("Gray3"))
                                    .padding(.trailing, 2)
                                
                                // TextView - "Delete" text
                                // textSize="16sp" fontFamily="@font/inter" textStyle="bold"
                                Text("Delete")
                                    .font(.custom("Inter18pt-Bold", size: 16))
                                    .foregroundColor(Color("TextColor"))
                                
                                Spacer()
                            }
                            .frame(height: 48) // layout_height="48dp"
                            .frame(maxWidth: .infinity)
                            .background(Color("dxForward"))
                            .cornerRadius(20) // cardCornerRadius="20dp"
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 20) // layout_marginHorizontal="20dp"
                        .padding(.top, 10) // layout_marginTop="10dp"
                        .padding(.bottom, 25) // layout_marginBottom="25dp"
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.clear)
                    .offset(x: adjustedOffsetX(in: geometry), y: adjustedOffsetY(in: geometry))
                    .zIndex(1)
                }
            }
        }
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
