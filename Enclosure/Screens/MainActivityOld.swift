import SwiftUI

import Combine

struct MainActivityOld: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var isCallEnabled = true
    @State private var isVideoCallEnabled = true
    @State private var isTapped = false
    @State private var isVStackVisible = false
    @State private var isTopHeaderVisible = false
    @State private var isMainContentVisible = true
    @State private var showNameDialog = false
    @State private var showInviteScreen = false
    @State private var currentBackgroundImage = "bg"
    @State private var currentBackgroundSizeHeight = 140
    @State private var opacity = 0.1
    @State private var viewValue = Constant.chatView
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @State private var showNetworkLoader = false
    
    // Chat long press dialog state
    @State private var selectedChatForDialog: UserActiveContactModel? = nil
    @State private var chatDialogPosition: CGPoint = .zero
    @State private var showChatLongPressDialog = false
    
    // Call log long press dialog state (voice)
    @State private var selectedCallLogForDialog: CallLogUserInfo? = nil
    @State private var callLogDialogPosition: CGPoint = .zero
    @State private var showCallLogDialog = false
    
    // Video call log long press dialog state
    @State private var selectedVideoCallLogForDialog: CallLogUserInfo? = nil
    @State private var videoCallLogDialogPosition: CGPoint = .zero
    @State private var showVideoCallLogDialog = false
    
    // Group message long press dialog state
    @State private var selectedGroupForDialog: GroupModel? = nil
    @State private var groupDialogPosition: CGPoint = .zero
    @State private var showGroupDialog = false
    
    // Clear log dialog state (voice calls)
    @State private var showClearLogDialog = false
    
    // Clear video call log dialog state
    @State private var showClearVideoCallLogDialog = false
    
    // Menu dialog state
    @State private var showMenu = false
    @State private var navigateToLockScreen = false
    @State private var navigateToPayView = false
    @State private var navigateToSettings = false
    @State private var navigateToThemeView = false
    @State private var logoImageName: String = "ec_modern" // Dynamic logo based on theme color
    @State private var switchTrackImage: String = "blue_radio_btn" // Dynamic switch track based on theme color
    @State private var bgRectTintColor: Color = Color(hex: Constant.themeColor) // Dynamic bg_rect tint color
    @State private var mainvectorTintColor: Color = Color(hex: "#01253B") // Dynamic mainvector background tint color (darker theme color)
    @State private var sleepImageName: String = "sleep" // Dynamic sleep seekbar image based on theme color
    @State private var isMenuButtonPressed = false // Track menu button press state
    @State private var initialFadeInOpacity: Double = 0.0 // Start at 0 for smooth fade-in
    
    // Computed property for background tint: appThemeColor in light mode, darker tint in dark mode
    private var backgroundTintColor: Color {
        if colorScheme == .light {
            return Color("appThemeColor") // Use appThemeColor in light mode
        } else {
            return mainvectorTintColor // Use darker tint in dark mode
        }
    }




    enum SelectedOption {
        case none, call,videoCall, groupMessage,messageLimit, you;
    }

    @State private var selected: SelectedOption = .none
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing:0) {

                if(isMainContentVisible){
                    HStack{
                        Button(action: {
                            withAnimation {
                                showInviteScreen = true
                            }
                        }) {
                            Image(logoImageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 55, height: 55)
                        }
                        .frame(width: 70, height: 70)
                        .padding(.leading, 25)

                        Spacer()

                        HStack {
                            if viewValue == Constant.chatView {
                                if isSearchActive {
                                    HStack {
                                        Rectangle()
                                            .fill(bgRectTintColor) // Dynamic theme color instead of hardcoded blue
                                            .frame(width: 1, height: 19.24)
                                            .padding(.leading, 13)

                                        TextField("Search Name", text: $searchText)
                                            .font(.custom("Inter18pt-Regular", size: 15))
                                            .foregroundColor(Color("TextColor"))
                                            .padding(.leading, 13)
                                            .textFieldStyle(PlainTextFieldStyle())
                                    }
                                    .transition(
                                        .move(edge: .trailing).combined(with: .opacity)
                                    )
                                }

                                Button(action: {
                                    withAnimation {
                                        isSearchActive.toggle()
                                        if !isSearchActive {
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
                                .buttonStyle(CircularRippleStyle())
                            }

                            // Menu button - using simpler approach for better tap responsiveness
                            ZStack {
                                // Background circle for visual feedback
                                if isMenuButtonPressed {
                                    Circle()
                                        .fill(Color("circlebtnhover").opacity(0.3))
                                        .frame(width: 44, height: 44)
                                        .transition(.opacity)
                                }
                                
                                VStack(spacing: 3) {
                                    Circle()
                                        .fill(Color("menuPointColor"))
                                        .frame(width: 4, height: 4)
                                    Circle()
                                        .fill(Color(hex: Constant.themeColor))
                                        .frame(width: 4, height: 4)
                                    Circle()
                                        .fill(Color(red: 0x9E/255, green: 0xA6/255, blue: 0xB9/255))
                                        .frame(width: 4, height: 4)
                                }
                            }
                            .frame(width: 44, height: 44) // Standard iOS touch target size
                            .contentShape(Rectangle()) // Ensure entire area is tappable
                            .onTapGesture {
                                // Add haptic feedback for better UX
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                                
                                // Visual feedback
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    isMenuButtonPressed = true
                                }
                                
                                // Smooth animation when opening menu
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showMenu = true
                                }
                                
                                // Reset pressed state
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        isMenuButtonPressed = false
                                    }
                                }
                            }
                            .padding(.trailing,8)
                        }
                    }





                    // main container
                    VStack (spacing:0){
                        /// 1

                        HStack {
                            Spacer()
                            Button(action: {
                                // Capture current state before toggling
                                let wasExpanded = isVStackVisible
                                
                                withAnimation(.easeInOut(duration: 0.45)) {
                                    isVStackVisible.toggle()
                                    // Use the captured state to determine which image to show
                                    currentBackgroundImage = !wasExpanded ? "mainvector" : "bg"
                                    currentBackgroundSizeHeight = !wasExpanded ? 400 : 140
                                    if !wasExpanded {
                                        // Expanding - Don't set viewValue immediately - wait for animation to complete
                                        // viewValue will be set after animation completes (see below)


                                        // Delay opacity to 1 when showing
                                        withAnimation(.easeInOut(duration: 0.45)){
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                                                isTopHeaderVisible = true
                                            }

                                        }



                                    }else{
                                        // Collapsing - animate smoothly to bg
                                        viewValue = Constant.chatView
                                        isTopHeaderVisible = false


                                    }
                                }

                                if isVStackVisible {
                                    //isTopHeaderVisible = true
                                    selected = .call

                                    // Delay opacity to 1 when showing and set viewValue after expansion completes
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                                        withAnimation {
                                            opacity = 1
                                        }
                                        // Set viewValue only after expansion animation completes
                                        viewValue = Constant.callView
                                    }


                                } else {

                                    // Immediately reduce opacity when hiding
                                    withAnimation(.easeInOut(duration: 0.45)) {
                                        opacity = 0.0
                                    }

                                

                                }



                            }) {
                                VStack{
                                    Image("downarrowslide")
                                        .resizable()
                                        .frame(width: 24, height: 24)
                                }
                                .frame(width: 40, height: 40)

                            }
                            .padding(.trailing , 16)
                            .buttonStyle(CircularRippleStyle())
                        }
                        .padding(.top, 69)



                        if isVStackVisible{

                            /// 2
                            VStack{


                                // #1
                                HStack(alignment: .center) {
                                    // Left side: Audio call switch


                                    HStack(spacing: 8) {
                                        Text("Audio call")
                                            .font(.custom("Inter18pt-Medium", size: 15))
                                            .fontWeight(.heavy)
                                            .foregroundColor(.white)
                                            .lineLimit(1)

                                        CustomImageToggle(
                                            isOn: $isCallEnabled,
                                            trackEnabledImage: switchTrackImage,      // Dynamic theme-based track image
                                            trackDisabledImage: "offradiograynew",    // Image from Assets
                                            thumbEnabledImage: "phone.fill",    // SF Symbol or nil
                                            thumbDisabledImage: "xmark"         // SF Symbol or nil
                                        )
                                        .id(switchTrackImage) // Force refresh when track image changes
                                    }
                                    .padding(.leading, 16)

                                    Spacer()

                                    VStack{

                                        HStack(spacing: 12) {
                                            Spacer()
                                            Text("Call")
                                                .font(.custom("Inter18pt-Medium", size: 15).weight(.bold))
                                                .foregroundColor(selected == .call ? .white : Color("maincontenttextcolor"))
                                                .fontWeight(.heavy)


                                            Image("call") // Make sure this is in your Assets
                                                .resizable()
                                                .frame(width: 24, height: 24)


                                        }
                                        .padding(.trailing,22)

                                    }
                                    .frame(width: 200,height:40)
                                    .background(
                                        selected == .call ? AnyView(
                                            Image("bg_rect")
                                                .renderingMode(.template)
                                                .resizable()
                                                .foregroundColor(bgRectTintColor)
                                        ) : AnyView(Color.clear)
                                    )
                                    .onTapGesture {
                                        selected = .call
                                        viewValue = Constant.callView

                                    }

                                }
                                .padding(.top, 5)


                                // #2
                                HStack(alignment: .center) {
                                    // Left side: Audio call switch


                                    HStack(spacing: 8) {
                                        Text("Video call")
                                            .font(.custom("Inter18pt-Medium", size: 15))
                                            .fontWeight(.heavy)
                                            .foregroundColor(.white)
                                            .lineLimit(1)

                                        CustomImageToggle(
                                            isOn: $isVideoCallEnabled,
                                            trackEnabledImage: switchTrackImage,      // Dynamic theme-based track image
                                            trackDisabledImage: "offradiograynew",    // Image from Assets
                                            thumbEnabledImage: "phone.fill",    // SF Symbol or nil
                                            thumbDisabledImage: "xmark"         // SF Symbol or nil
                                        )
                                        .id(switchTrackImage) // Force refresh when track image changes
                                    }
                                    .padding(.leading, 16)

                                    Spacer()

                                    VStack{

                                        HStack(spacing: 12) {
                                            Spacer()
                                            Text("Video Call")
                                                .font(.custom("Inter18pt-Medium", size: 15).weight(.bold))
                                                .foregroundColor(selected == .videoCall ? .white : Color("maincontenttextcolor"))
                                                .fontWeight(.heavy)


                                            ZStack {
                                                Image("videosvgnew2")
                                                .resizable()
                                                    .renderingMode(.template)
                                                    .foregroundColor(.white) // Camera body stays white
                                                    .scaledToFit()
                                                .frame(width: 24, height: 16)
                                                
                                                Image("polysvg")
                                                    .resizable()
                                                    .renderingMode(.template)
                                                    .foregroundColor(bgRectTintColor) // Play button always uses theme color for visibility
                                                    .scaledToFit()
                                                    .frame(width: 5, height: 5)
                                                    .offset(x: 2, y: -0.5) // Position the play button overlay
                                            }


                                        }
                                        .padding(.trailing,22)

                                    }
                                    .frame(width: 200,height:40)
                                    .background(
                                        selected == .videoCall ? AnyView(
                                            Image("bg_rect")
                                                .renderingMode(.template)
                                                .resizable()
                                                .foregroundColor(bgRectTintColor)
                                        ) : AnyView(Color.clear)
                                    )
                                    .onTapGesture {
                                        selected = .videoCall
                                        viewValue = Constant.videoCallView

                                    }

                                }
                                .padding(.top, 5)

                                // #3
                                HStack(alignment: .center) {
                                    // Left side: Audio call switch



                                    Spacer()

                                    VStack{

                                        HStack(spacing: 12) {
                                            Spacer()
                                            Text("Group message")
                                                .font(.custom("Inter18pt-Medium", size: 15).weight(.bold))
                                                .foregroundColor(selected == .groupMessage ? .white : Color("maincontenttextcolor"))
                                                .fontWeight(.heavy)


                                            Image("group_new_svg") // Make sure this is in your Assets
                                                .resizable()
                                                .frame(width: 24, height: 24)


                                        }
                                        .padding(.trailing,22)

                                    }
                                    .frame(width: 200,height:40)
                                    .background(
                                        selected == .groupMessage ? AnyView(
                                            Image("bg_rect")
                                                .renderingMode(.template)
                                                .resizable()
                                                .foregroundColor(bgRectTintColor)
                                        ) : AnyView(Color.clear)
                                    )
                                    .onTapGesture {
                                        selected = .groupMessage
                                        viewValue = Constant.groupMsgView
                                    }

                                }
                                .padding(.top, 5)

                                // #4
                                HStack(alignment: .center) {
                                    // Left side: Audio call switch



                                    Spacer()

                                    VStack{

                                        HStack(spacing: 12) {
                                            Spacer()
                                            Text("Message Limit")
                                                .font(.custom("Inter18pt-Medium", size: 15).weight(.bold))
                                                .foregroundColor(selected == .messageLimit ? .white : Color("maincontenttextcolor"))
                                                .fontWeight(.heavy)


                                            Image("limit") // Make sure this is in your Assets
                                                .resizable()
                                                .frame(width: 24, height: 24)


                                        }
                                        .padding(.trailing,22)

                                    }
                                    .frame(width: 200,height:40)
                                    .background(
                                        selected == .messageLimit ? AnyView(
                                            Image("bg_rect")
                                                .renderingMode(.template)
                                                .resizable()
                                                .foregroundColor(bgRectTintColor)
                                        ) : AnyView(Color.clear)
                                    )
                                    .onTapGesture {
                                        selected = .messageLimit
                                        viewValue = Constant.messageLmtView
                                    }

                                }
                                .padding(.top, 5)


                                // #5
                                HStack(alignment: .center) {
                                    // Left side: Audio call switch

                                    Spacer()

                                    VStack{

                                        HStack(spacing: 12) {
                                            Spacer()
                                            Text("You")
                                                .font(.custom("Inter18pt-Medium", size: 15).weight(.bold))
                                                .foregroundColor(selected == .you ? .white : Color("maincontenttextcolor"))
                                                .fontWeight(.heavy)


                                            Image("you") // Make sure this is in your Assets
                                                .resizable()
                                                .frame(width: 18, height: 24)


                                        }
                                        .padding(.trailing,24)

                                    }
                                    .frame(width: 200,height:40)
                                    .background(
                                        selected == .you ? AnyView(
                                            Image("bg_rect")
                                                .renderingMode(.template)
                                                .resizable()
                                                .foregroundColor(bgRectTintColor)
                                        ) : AnyView(Color.clear)
                                    )
                                    .onTapGesture {
                                        selected = .you
                                        viewValue = Constant.youView

                                    }
                                }
                                .padding(.top, 5)
                            }
                            .padding(.top,13)
                            .opacity(isVStackVisible ? opacity : opacity)


                        }



                        Spacer()

                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: CGFloat(currentBackgroundSizeHeight))
                    .background(
                        Group {
                            if currentBackgroundImage == "mainvector" {
                                // Apply tint to mainvector: appThemeColor in light mode, darker tint in dark mode
                                Image("mainvector")
                                    .renderingMode(.template)
                                    .resizable()
                                    .foregroundColor(backgroundTintColor)
                            } else if currentBackgroundImage == "bg" {
                                // Apply tint to bg: appThemeColor in light mode, darker tint in dark mode
                                Image("bg")
                                    .renderingMode(.template)
                                    .resizable()
                                    .foregroundColor(backgroundTintColor)
                            } else {
                        Image(currentBackgroundImage)
                            .resizable()
                            }
                        }
                            .id(currentBackgroundImage)
                    )
                    .clipped()
                    
                    
                    
                    
                    
                   if showNetworkLoader {
                        NetworkLoaderBar()
                            .frame(height: 3)
                            .transition(.opacity)
                    }


                }
                



                // TODO:  Children are styarting from here

                VStack(spacing:0){

                    if(viewValue == Constant.chatView){

                        chatView(
                            searchText: searchText,
                            selectedChatForDialog: $selectedChatForDialog,
                            dialogPosition: $chatDialogPosition,
                            showLongPressDialog: $showChatLongPressDialog
                        )


                    }else if(viewValue == Constant.callView){

                        callView(
                            isMainContentVisible: $isMainContentVisible,
                            isTopHeaderVisible: $isTopHeaderVisible,
                            selectedCallLogForDialog: $selectedCallLogForDialog,
                            callDialogPosition: $callLogDialogPosition,
                            showCallLogDialog: $showCallLogDialog,
                            showClearLogDialog: $showClearLogDialog
                        )

                    }else if(viewValue == Constant.videoCallView){

                        videoCallView(
                            isMainContentVisible: $isMainContentVisible,
                            isTopHeaderVisible: $isTopHeaderVisible,
                            selectedCallLogForDialog: $selectedVideoCallLogForDialog,
                            callDialogPosition: $videoCallLogDialogPosition,
                            showCallLogDialog: $showVideoCallLogDialog,
                            showClearVideoCallLogDialog: $showClearVideoCallLogDialog
                        )

                    }else if(viewValue == Constant.groupMsgView){

                        groupMessageView(
                            isMainContentVisible: $isMainContentVisible,
                            isTopHeaderVisible: $isTopHeaderVisible,
                            selectedGroupForDialog: $selectedGroupForDialog,
                            groupDialogPosition: $groupDialogPosition,
                            showGroupDialog: $showGroupDialog
                        )
                    }else if(viewValue == Constant.messageLmtView){

                        messageLmtView(
                            isMainContentVisible: $isMainContentVisible,
                            isTopHeaderVisible: $isTopHeaderVisible
                        )



                    }else if(viewValue == Constant.youView){

                        youView(
                            isMainContentVisible: $isMainContentVisible,
                            isTopHeaderVisible: $isTopHeaderVisible
                        )
                    }
                }

                if showNetworkLoader && !isMainContentVisible {
                    NetworkLoaderBar()
                        .frame(height: 3)
                        .transition(.opacity)
                }

                }
                .background(Color("background_color"))
                .overlay(alignment: .top) {
                    if isTopHeaderVisible {
                        VStack { }
                            .frame(maxWidth: .infinity)
                            .frame(height: 10)
                            .background(backgroundTintColor) // Use appThemeColor in light mode, darker tint in dark mode
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                
                // Custom Alert
                if showNameDialog {
                    WhatsYourNameDialog(isPresented: $showNameDialog)
                }
                
                // Chat Long Press Dialog - shown on top of everything
                if showChatLongPressDialog, let selectedChat = selectedChatForDialog {
                    chatView.ChatLongPressDialog(
                        chat: selectedChat,
                        position: chatDialogPosition,
                        isShowing: $showChatLongPressDialog,
                        onDelete: {
                            deleteChatItem(selectedChat)
                        }
                    )
                    .zIndex(999) // Ensure it's on top of everything
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                // Call Log Long Press Dialog (Voice) - shown on top of everything
                if showCallLogDialog, let selectedCallLog = selectedCallLogForDialog {
                    callView.CallLogLongPressDialog(
                        callLog: selectedCallLog,
                        position: callLogDialogPosition,
                        logType: .voice,
                        isShowing: $showCallLogDialog,
                        onDelete: {
                            deleteCallLogItem(selectedCallLog, callType: "1")
                        }
                    )
                    .zIndex(999) // Ensure it's on top of everything
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                // Video Call Log Long Press Dialog - shown on top of everything
                if showVideoCallLogDialog, let selectedVideoCallLog = selectedVideoCallLogForDialog {
                    videoCallView.VideoCallLogLongPressDialog(
                        callLog: selectedVideoCallLog,
                        position: videoCallLogDialogPosition,
                        logType: .video,
                        isShowing: $showVideoCallLogDialog,
                        onDelete: {
                            deleteVideoCallLogItem(selectedVideoCallLog)
                        }
                    )
                    .zIndex(999) // Ensure it's on top of everything
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                // Group Message Long Press Dialog - shown on top of everything
                if showGroupDialog, let selectedGroup = selectedGroupForDialog {
                    groupMessageView.GroupLongPressDialog(
                        group: selectedGroup,
                        position: groupDialogPosition,
                        isShowing: $showGroupDialog,
                        onDelete: {
                            deleteGroupItem(selectedGroup)
                        }
                    )
                    .zIndex(999) // Ensure it's on top of everything
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                // Clear Log Dialog - shown centered on screen (voice calls)
                if showClearLogDialog {
                    ClearLogDialog(
                        isShowing: $showClearLogDialog,
                        onClearLog: {
                            handleClearVoiceLog()
                        }
                    )
                    .zIndex(999) // Ensure it's on top of everything
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                // Clear Video Call Log Dialog - shown centered on screen
                if showClearVideoCallLogDialog {
                    ClearVideoCallLogDialog(
                        isShowing: $showClearVideoCallLogDialog,
                        onClearLog: {
                            handleClearVideoLog()
                        }
                    )
                    .zIndex(999) // Ensure it's on top of everything
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                // Menu Dialog - shown at top-right position
                if showMenu {
                    UpperLayoutDialog(
                        isPresented: $showMenu,
                        shouldNavigateToLockScreen: $navigateToLockScreen,
                        shouldNavigateToPayView: $navigateToPayView,
                        shouldNavigateToSettings: $navigateToSettings,
                        shouldNavigateToThemeView: $navigateToThemeView
                    )
                        .zIndex(999) // Ensure it's on top of everything
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .opacity(initialFadeInOpacity)
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showInviteScreen) {
                InviteScreen()
            }
            .navigationDestination(isPresented: $navigateToLockScreen) {
                LockScreenView()
            }
            .navigationDestination(isPresented: $navigateToPayView) {
                PayView()
            }
            .navigationDestination(isPresented: $navigateToSettings) {
                SettingsView()
            }
            .navigationDestination(isPresented: $navigateToThemeView) {
                ThemeView()
            }
        }
        .onAppear {
            showNetworkLoader = !networkMonitor.isConnected
            updateLogoBasedOnTheme()
            
            // Smooth fade-in animation when view appears
            withAnimation(.easeInOut(duration: 0.3)) {
                initialFadeInOpacity = 1.0
            }
            
            // Check if name dialog should be shown (matching Android logic)
            let nameSaved = UserDefaults.standard.string(forKey: "nameSAved") ?? "0"
            if nameSaved != "nameSAved" {
                // Show dialog on first visit
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showNameDialog = true
                }
            }
        }
        .onReceive(networkMonitor.$isConnected) { isConnected in
            withAnimation(.easeInOut(duration: 0.2)) {
                showNetworkLoader = !isConnected
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ThemeColorUpdated"))) { notification in
            updateLogoBasedOnTheme()
        }
    }
    
    // MARK: - Logo Helper Functions
    // Update logo based on theme color (matching Android MainActivityOld.java)
    private func updateLogoBasedOnTheme() {
        let themeColor = Constant.themeColor
        print("🎨 [MainActivityOld] Updating theme - Color: \(themeColor)")
        logoImageName = getLogoImage(for: themeColor)
        switchTrackImage = getSwitchTrackImage(for: themeColor)
        sleepImageName = getSleepImage(for: themeColor) // Update sleep seekbar image
        bgRectTintColor = Color(hex: themeColor) // Update bg_rect tint color
        mainvectorTintColor = getMainvectorTintColor(for: themeColor) // Update mainvector background tint color
        print("🎨 [MainActivityOld] Logo: \(logoImageName), Switch Track: \(switchTrackImage), Sleep: \(sleepImageName)")
    }
    
    // Get mainvector background tint color (matching Android linearMain.setBackgroundTintList)
    // Android uses darker tint colors for the background
    private func getMainvectorTintColor(for themeColor: String) -> Color {
        // Use case-insensitive comparison to handle mixed case theme colors
        let colorKey = themeColor.lowercased()
        switch colorKey {
        case "#ff0080":
            return Color(hex: "#4D0026")
        case "#00a3e9":
            return Color(hex: "#01253B")
        case "#7adf2a":
            return Color(hex: "#25430D")
        case "#ec0001":
            return Color(hex: "#470000")
        case "#16f3ff":
            return Color(hex: "#05495D")
        case "#ff8a00":
            return Color(hex: "#663700")
        case "#7f7f7f":
            return Color(hex: "#2B3137")
        case "#d9b845":
            return Color(hex: "#413815")
        case "#346667":
            return Color(hex: "#1F3D3E")
        case "#9846d9":
            return Color(hex: "#2d1541")
        case "#a81010":
            return Color(hex: "#430706")
        default:
            return Color(hex: "#01253B")
        }
    }
    
    // Get logo image name based on theme color (matching Android logic)
    private func getLogoImage(for themeColor: String) -> String {
        switch themeColor {
        case "#ff0080":
            return "pinklogopng"
        case "#00A3E9":
            return "ec_modern"
        case "#7adf2a":
            return "popatilogopng"
        case "#ec0001":
            return "redlogopng"
        case "#16f3ff":
            return "bluelogopng"
        case "#FF8A00":
            return "orangelogopng"
        case "#7F7F7F":
            return "graylogopng"
        case "#D9B845":
            return "yellowlogopng"
        case "#346667":
            return "greenlogoppng"
        case "#9846D9":
            return "voiletlogopng"
        case "#A81010":
            return "red2logopng"
        default:
            return "ec_modern"
        }
    }
    
    // Get switch track image name based on theme color (matching Android MainActivityOld.java)
    // Android uses: bg_track_pink, bg_track, bg_track_popati, bg_track_redone, etc.
    private func getSwitchTrackImage(for themeColor: String) -> String {
        // Use case-insensitive comparison to handle mixed case theme colors
        let colorKey = themeColor.lowercased()
        switch colorKey {
        case "#ff0080":
            return "bg_track_pink"
        case "#00a3e9":
            return "blue_radio_btn" // Android: bg_track
        case "#7adf2a":
            return "bg_track_popati"
        case "#ec0001":
            return "bg_track_redone"
        case "#16f3ff":
            return "bg_track_blue"
        case "#ff8a00":
            return "bg_track_orange"
        case "#7f7f7f":
            return "bg_track_gray"
        case "#d9b845":
            return "bg_track_yelloe"
        case "#346667":
            return "bg_track_green"
        case "#9846d9":
            return "bg_track_voilet"
        case "#a81010":
            return "bg_track_redtwo"
        default:
            print("⚠️ [MainActivityOld] Unknown theme color: \(themeColor), using default blue_radio_btn")
            return "blue_radio_btn" // Android: bg_track
        }
    }
    
    // Get sleep seekbar image name based on theme color (matching Android MainActivityOld.java)
    // Android uses: pinksleep, sleep, popatisleep, redonesleep, bluesleep, orangesleep, graysleep, yellowsleep, greensleep, voiletsleep, redtwonewsleep
    private func getSleepImage(for themeColor: String) -> String {
        // Use case-insensitive comparison to handle mixed case theme colors
        let colorKey = themeColor.lowercased()
        switch colorKey {
        case "#ff0080":
            return "pinksleep"
        case "#00a3e9":
            return "sleep" // Default sleep image
        case "#7adf2a":
            return "popatisleep"
        case "#ec0001":
            return "redonesleep"
        case "#16f3ff":
            return "bluesleep"
        case "#ff8a00":
            return "orangesleep"
        case "#7f7f7f":
            return "graysleep"
        case "#d9b845":
            return "yellowsleep"
        case "#346667":
            return "greensleep"
        case "#9846d9":
            return "voiletsleep"
        case "#a81010":
            return "redtwonewsleep"
        default:
            return "sleep"
        }
    }
    
    // Delete chat functionality
    private func deleteChatItem(_ chat: UserActiveContactModel) {
        print("🔴 [MainActivityOld] Deleting chat for uid: \(chat.uid)")
        
        // Immediately close dialog
        showChatLongPressDialog = false
        
        // Post notification for immediate UI update
        NotificationCenter.default.post(
            name: NSNotification.Name("DeleteChatImmediately"),
            object: nil,
            userInfo: ["uid": chat.uid]
        )
        
        // Call API in background
        ApiService.delete_individual_user_chatting(uid: Constant.SenderIdMy, friendId: chat.uid) { success, message in
            DispatchQueue.main.async {
                if success {
                    print("🔴 [MainActivityOld] Delete SUCCESS")
                } else {
                    print("🔴 [MainActivityOld] Delete FAILED - message: \(message)")
                }
            }
        }
    }
    
    private func deleteCallLogItem(_ callLog: CallLogUserInfo, callType: String) {
        print("🟢 [MainActivityOld] Deleting voice call log with id: \(callLog.id), friendId: \(callLog.friendId)")
        
        // Immediately close dialog
        showCallLogDialog = false
        
        // Post notification for immediate UI update - pass the specific entry ID
        NotificationCenter.default.post(
            name: NSNotification.Name("DeleteCallLogImmediately"),
            object: nil,
            userInfo: ["id": callLog.id]
        )
        
        // Call API in background (API deletes all entries by friendId, but we only remove one from UI)
        ApiService.delete_voice_call_log(uid: Constant.SenderIdMy, friendId: callLog.friendId, callType: callType) { success, message in
            DispatchQueue.main.async {
                if success {
                    print("🟢 [MainActivityOld] Delete voice call log SUCCESS")
                } else {
                    print("🟢 [MainActivityOld] Delete voice call log FAILED - message: \(message)")
                }
            }
        }
    }
    
    private func deleteVideoCallLogItem(_ callLog: CallLogUserInfo) {
        print("🔵 [MainActivityOld] Deleting video call log with id: \(callLog.id), friendId: \(callLog.friendId)")
        
        // Immediately close dialog
        showVideoCallLogDialog = false
        
        // Post notification for immediate UI update - pass the specific entry ID
        NotificationCenter.default.post(
            name: NSNotification.Name("DeleteVideoCallLogImmediately"),
            object: nil,
            userInfo: ["id": callLog.id]
        )
        
        // Call API in background (API deletes all entries by friendId, but we only remove one from UI)
        ApiService.delete_video_call_log(uid: Constant.SenderIdMy, friendId: callLog.friendId, callType: "2") { success, message in
            DispatchQueue.main.async {
                if success {
                    print("🔵 [MainActivityOld] Delete video call log SUCCESS")
                } else {
                    print("🔵 [MainActivityOld] Delete video call log FAILED - message: \(message)")
                }
            }
        }
    }
    
    private func deleteGroupItem(_ group: GroupModel) {
        print("👥 [MainActivityOld] Deleting group with groupId: \(group.groupId), name: \(group.name)")
        
        // Immediately close dialog
        showGroupDialog = false
        
        // Post notification for immediate UI update
        NotificationCenter.default.post(
            name: NSNotification.Name("DeleteGroupImmediately"),
            object: nil,
            userInfo: ["groupId": group.groupId]
        )
        
        // Call API in background
        ApiService.delete_groupp(groupId: group.groupId) { success, message in
            DispatchQueue.main.async {
                if success {
                    print("👥 [MainActivityOld] Delete group SUCCESS")
                } else {
                    print("👥 [MainActivityOld] Delete group FAILED - message: \(message)")
                }
            }
        }
    }
    
    private func handleClearVoiceLog() {
        print("🟣 [MainActivityOld] Clearing all voice call logs")
        showClearLogDialog = false
        
        ApiService.clear_voice_calling_list(uid: Constant.SenderIdMy, callType: "1") { success, message in
            DispatchQueue.main.async {
                if success {
                    print("🟣 [MainActivityOld] Clear Voice Call Log SUCCESS")
                    // Post notification to clear all logs from view
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ClearAllVoiceCallLogs"),
                        object: nil
                    )
                } else {
                    print("🟣 [MainActivityOld] Clear Voice Call Log FAILED - message: \(message)")
                }
            }
        }
    }
    
    private func handleClearVideoLog() {
        print("🔵 [MainActivityOld] Clearing all video call logs")
        showClearVideoCallLogDialog = false
        
        ApiService.clear_video_calling_list(uid: Constant.SenderIdMy, callType: "2") { success, message in
            DispatchQueue.main.async {
                if success {
                    print("🔵 [MainActivityOld] Clear Video Call Log SUCCESS")
                    // Post notification to clear all logs from view
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ClearAllVideoCallLogs"),
                        object: nil
                    )
                } else {
                    print("🔵 [MainActivityOld] Clear Video Call Log FAILED - message: \(message)")
                }
            }
        }
    }
}

// MARK: - ClearLogDialog
// Simple centered dialog for clearing call logs
struct ClearLogDialog: View {
    @Binding var isShowing: Bool
    let onClearLog: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Semi-transparent background with ultra thin material blur to dismiss on tap outside
            Color.black.opacity(0.01)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowing = false
                    }
                }
            
            // Centered Clear Log button
            ZStack {
                // Enhanced shadow layer for CardView effect (elevation 5dp equivalent)
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        colorScheme == .light 
                            ? Color.black.opacity(0.25) 
                            : Color.black.opacity(0.15)
                    )
                    .frame(width: 130, height: 50)
                    .offset(x: 0, y: 4)
                    .blur(radius: colorScheme == .light ? 10 : 8)
                    .allowsHitTesting(false)
                
                // Additional subtle shadow for depth in light mode
                if colorScheme == .light {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.1))
                        .frame(width: 130, height: 50)
                        .offset(x: 0, y: 2)
                        .blur(radius: 6)
                        .allowsHitTesting(false)
                }
                
                // Button card - matches Android: 130dp width, 50dp height, 10dp corner radius
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowing = false
                    }
                    // Small delay to allow dismiss animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        onClearLog()
                    }
                }) {
                    Text("Clear Log")
                        .font(.custom("Inter18pt-Bold", size: 16))
                        .foregroundColor(Color("TextColor"))
                        .frame(width: 130, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color("menuRect"))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(.easeInOut(duration: 0.2), value: isShowing)
    }
}

// MARK: - ClearVideoCallLogDialog
// Simple centered dialog for clearing video call logs
struct ClearVideoCallLogDialog: View {
    @Binding var isShowing: Bool
    let onClearLog: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Semi-transparent background with ultra thin material blur to dismiss on tap outside
            Color.black.opacity(0.01)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowing = false
                    }
                }
            
            // Centered Clear Log button
            ZStack {
                // Enhanced shadow layer for CardView effect (elevation 5dp equivalent)
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        colorScheme == .light 
                            ? Color.black.opacity(0.25) 
                            : Color.black.opacity(0.15)
                    )
                    .frame(width: 130, height: 50)
                    .offset(x: 0, y: 4)
                    .blur(radius: colorScheme == .light ? 10 : 8)
                    .allowsHitTesting(false)
                
                // Additional subtle shadow for depth in light mode
                if colorScheme == .light {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.1))
                        .frame(width: 130, height: 50)
                        .offset(x: 0, y: 2)
                        .blur(radius: 6)
                        .allowsHitTesting(false)
                }
                
                // Button card - matches Android: 130dp width, 50dp height, 10dp corner radius
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowing = false
                    }
                    // Small delay to allow dismiss animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        onClearLog()
                    }
                }) {
                    Text("Clear Log")
                        .font(.custom("Inter18pt-Bold", size: 16))
                        .foregroundColor(Color("TextColor"))
                        .frame(width: 130, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color("menuRect"))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(.easeInOut(duration: 0.2), value: isShowing)
    }
}

// MARK: - UpperLayoutDialog
// Menu popup positioned at top-right, exactly matching Android upper_layout.xml
struct UpperLayoutDialog: View {
    @Binding var isPresented: Bool
    @Binding var shouldNavigateToLockScreen: Bool
    @Binding var shouldNavigateToPayView: Bool
    @Binding var shouldNavigateToSettings: Bool
    @Binding var shouldNavigateToThemeView: Bool
    @Environment(\.colorScheme) var colorScheme
    @State private var sliderValue: Double = 0.0
    @State private var pressedItem: String? = nil
    @State private var selectedItem: String? = nil
    @State private var hasTriggeredSleepMode: Bool = false // Prevent multiple calls when slider reaches 100%
    
    // Dynamic bg_rect tint color based on theme
    private var bgRectTintColor: Color {
        Color(hex: Constant.themeColor)
    }
    
    // Get sleep seekbar image name based on theme color (matching Android MainActivityOld.java)
    private var sleepImageName: String {
        getSleepImageName(for: Constant.themeColor)
    }
    
    // Helper function to get sleep image name based on theme color
    private func getSleepImageName(for themeColor: String) -> String {
        let colorKey = themeColor.lowercased()
        switch colorKey {
        case "#ff0080":
            return "pinksleep"
        case "#00a3e9":
            return "sleep" // Default sleep image
        case "#7adf2a":
            return "popatisleep"
        case "#ec0001":
            return "redonesleep"
        case "#16f3ff":
            return "bluesleep"
        case "#ff8a00":
            return "orangesleep"
        case "#7f7f7f":
            return "graysleep"
        case "#d9b845":
            return "yellowsleep"
        case "#346667":
            return "greensleep"
        case "#9846d9":
            return "voiletsleep"
        case "#a81010":
            return "redtwonewsleep"
        default:
            return "sleep"
        }
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Transparent background to dismiss on tap outside
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPresented = false
                    }
                }
            
            // Android RelativeLayout equivalent - positioned at top-right
            // Android: RelativeLayout padding="10dp", layout_alignParentEnd="true", layout_alignParentTop="true"
            VStack {
                HStack {
                    // Custom slider with sleep.png as thumb
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Custom thumb with sleep image (dynamic based on theme color)
                            Image(sleepImageName)
                                .resizable()
                                .frame(width: 100, height: 45)
                                .offset(x: (geometry.size.width - 100) * CGFloat(sliderValue))
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            let newValue = min(max(0, value.location.x / geometry.size.width), 1)
                                            sliderValue = newValue
                                            
                                            // Check if slider reached 100% (matching Android onProgressChanged)
                                            if newValue >= 1.0 && !hasTriggeredSleepMode {
                                                hasTriggeredSleepMode = true
                                                handleSleepSeekbarComplete()
                                            }
                                        }
                                        .onEnded { _ in
                                            // Reset slider when user stops tracking (matching Android onStopTrackingTouch)
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                sliderValue = 0.0
                                                hasTriggeredSleepMode = false // Reset flag for next drag
                                            }
                                        }
                                )
                        }
                    }
                    .frame(height: 24)
                  
                }
                .padding(.horizontal, 16)
                .padding(.top, 17)
                
                // Sleep Lock section - equivalent to Android upper_layout.xml LinearLayout
                HStack {
                    Spacer()
                    
                    // Lock Screen Rectangle - equivalent to lockScreenRect LinearLayout
                    HStack {
                        Spacer()
                        Text("Sleep Lock")
                            .font(.custom("Inter18pt-SemiBold", size: 16))
                            .foregroundColor((pressedItem == "sleepLock" || selectedItem == "sleepLock") ? .white : Color(red: 0x9E/255, green: 0xA6/255, blue: 0xB9/255))
                        
                        Image("unlock")
                            .resizable()
                            .frame(width: 23, height: 23)
                            .foregroundColor((pressedItem == "sleepLock" || selectedItem == "sleepLock") ? .white : Color(red: 0x9E/255, green: 0xA6/255, blue: 0xB9/255))
                            .padding(.leading, 12)
                            .padding(.trailing, 24)
                    }
                    .frame(width: 180, height: 40)
                    .background(
                        (pressedItem == "sleepLock" || selectedItem == "sleepLock") ? 
                        Image("bg_rect")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFill()
                            .foregroundColor(bgRectTintColor) : nil
                    )
                    .cornerRadius(8)
                    .onTapGesture {
                        // Handle Sleep Lock tap - matching Android logic
                        selectedItem = "sleepLock"
                        
                        // Dismiss the dialog and navigate to lock screen
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isPresented = false
                        }
                        
                        // Navigate to lock screen after dialog dismisses
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            shouldNavigateToLockScreen = true
                        }
                    }
                    .scaleEffect(pressedItem == "sleepLock" ? 0.95 : 1.0)
                    .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            pressedItem = pressing ? "sleepLock" : nil
                        }
                    }, perform: {})
                }
                .padding(.top, 25)
                
                // Themes section
                HStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        Text("Themes")
                            .font(.custom("Inter18pt-SemiBold", size: 16))
                            .foregroundColor((pressedItem == "themes" || selectedItem == "themes") ? .white : Color(red: 0x9E/255, green: 0xA6/255, blue: 0xB9/255))
                        
                        Image("theme")
                            .resizable()
                            .frame(width: 25, height: 25)
                            .foregroundColor((pressedItem == "themes" || selectedItem == "themes") ? .white : Color(red: 0x9E/255, green: 0xA6/255, blue: 0xB9/255))
                            .padding(.leading, 12)
                            .padding(.trailing, 24)
                    }
                    .frame(width: 180, height: 40)
                    .background(
                        (pressedItem == "themes" || selectedItem == "themes") ? 
                        Image("bg_rect")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFill()
                            .foregroundColor(bgRectTintColor) : nil
                    )
                    .cornerRadius(8)
                    .onTapGesture {
                        // Handle Themes tap - matching Android logic
                        selectedItem = "themes"
                        
                        // Dismiss the dialog and navigate to theme view
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isPresented = false
                        }
                        
                        // Navigate to theme view after dialog dismisses
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            shouldNavigateToThemeView = true
                        }
                    }
                    .scaleEffect(pressedItem == "themes" ? 0.95 : 1.0)
                    .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            pressedItem = pressing ? "themes" : nil
                        }
                    }, perform: {})
                }
                .padding(.top, 10)
                
                // Pay section
                HStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        Text("Pay")
                            .font(.custom("Inter18pt-SemiBold", size: 16))
                            .foregroundColor(pressedItem == "pay" ? .white : Color(red: 0x9E/255, green: 0xA6/255, blue: 0xB9/255))
                        
                        Image("ex_pay")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 18.5)
                            .foregroundColor(pressedItem == "pay" ? .white : Color(red: 0x9E/255, green: 0xA6/255, blue: 0xB9/255))
                            .padding(.leading, 12)
                            .padding(.trailing, 25)
                    }
                    .frame(width: 180, height: 40)
                    .background(
                        pressedItem == "pay" ? 
                        Image("bg_rect")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFill()
                            .foregroundColor(bgRectTintColor) : nil
                    )
                    .cornerRadius(8)
                    .onTapGesture {
                        // Handle Pay tap - matching Android logic
                        selectedItem = "pay"
                        
                        // Dismiss the dialog and navigate to pay view
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isPresented = false
                        }
                        
                        // Navigate to pay view after dialog dismisses
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            shouldNavigateToPayView = true
                        }
                    }
                    .scaleEffect(pressedItem == "pay" ? 0.95 : 1.0)
                    .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            pressedItem = pressing ? "pay" : nil
                        }
                    }, perform: {})
                }
                .padding(.top, 10)
                
                // Settings section
                HStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        Text("Settings")
                            .font(.custom("Inter18pt-SemiBold", size: 16))
                            .foregroundColor(pressedItem == "settings" ? .white : Color(red: 0x9E/255, green: 0xA6/255, blue: 0xB9/255))
                        
                        Image("setting")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(pressedItem == "settings" ? .white : Color(red: 0x9E/255, green: 0xA6/255, blue: 0xB9/255))
                            .padding(.leading, 12)
                            .padding(.trailing, 24)
                    }
                    .frame(width: 180, height: 40)
                    .background(
                        pressedItem == "settings" ? 
                        Image("bg_rect")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFill()
                            .foregroundColor(bgRectTintColor) : nil
                    )
                    .cornerRadius(8)
                    .onTapGesture {
                        // Handle Settings tap - matching Android logic
                        selectedItem = "settings"
                        
                        // Dismiss the dialog and navigate to settings
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isPresented = false
                        }
                        
                        // Navigate to settings after dialog dismisses
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            shouldNavigateToSettings = true
                        }
                    }
                    .scaleEffect(pressedItem == "settings" ? 0.95 : 1.0)
                    .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            pressedItem = pressing ? "settings" : nil
                        }
                    }, perform: {})
                }
                .padding(.top, 10)
            }
            .frame(width: 241, height: 304, alignment: .topLeading)
            .background(Color("sleepBox"))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        colorScheme == .light ? Color(red: 0xF6/255, green: 0xF7/255, blue: 0xFF/255) : Color("sleepBox").opacity(0),
                        lineWidth: 1
                    )
            )
            .cornerRadius(8)
            .padding(.top, 16)
            .padding(.trailing, 10)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(.easeInOut(duration: 0.2), value: isPresented)
    }
    
    // Handle sleep seekbar completion (matching Android sb.setOnSeekBarChangeListener)
    private func handleSleepSeekbarComplete() {
        // Prevent multiple calls
        guard sliderValue >= 1.0 else { return }
        
        // Get lockKey from UserDefaults (matching Android Constant.getSF.getString("lockKey", String.valueOf(0)))
        let lockKey = UserDefaults.standard.string(forKey: "lockKey") ?? "0"
        let uid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? "0"
        
        print("🔒 [UpperLayoutDialog] Sleep seekbar completed - lockKey: \(lockKey), UID: \(uid)")
        
        var finalLockKey: String
        if lockKey == "0" {
            // If lockKey is "0", set it to "360" (matching Android)
            finalLockKey = "360"
            UserDefaults.standard.set("360", forKey: "lockKey")
        } else {
            // Use existing lockKey
            finalLockKey = lockKey
            UserDefaults.standard.set(lockKey, forKey: "lockKey")
        }
        
        // Set sleepKeyCheckOFF to "on" (matching Android)
        UserDefaults.standard.set("on", forKey: Constant.sleepKeyCheckOFF)
        print("🔒 [UpperLayoutDialog] Set sleepKeyCheckOFF to 'on'")
        
        // Set sleepKey (matching Android)
        UserDefaults.standard.set(Constant.sleepKey, forKey: Constant.sleepKey)
        print("🔒 [UpperLayoutDialog] Set sleepKey to '\(Constant.sleepKey)'")
        
        // Call lock_screen API (matching Android Webservice.lock_screenDummy or lock_screen)
        ApiService.shared.lockScreen(
            uid: uid,
            lockScreen: "1",
            lockScreenPin: finalLockKey,
            lock3: ""
        ) { success, message in
            DispatchQueue.main.async {
                if success {
                    // Show toast (matching Android Constant.showCustomToast("Sleep Mode - ON"))
                    Constant.showToast(message: "Sleep Mode - ON")
                    
                    // Dismiss dialog (matching Android upper_layout.dismiss())
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPresented = false
                    }
                    
                    // Finish app immediately after showing toast (matching Android finishAndRemoveTask() and finishAffinity())
                    // Android shows countdown timer then finishes, but user wants immediate finish
                    // Small delay to ensure toast is visible before app closes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        print("🔒 [UpperLayoutDialog] Finishing app immediately after sleep mode activation")
                        exit(0) // Terminate app immediately (matching Android finishAndRemoveTask() and finishAffinity())
                    }
                } else {
                    Constant.showToast(message: message.isEmpty ? "Failed to activate sleep mode" : message)
                }
            }
        }
    }
}




// MARK: - UpperMenuDrawable
// Exact equivalent of Android @drawable/upper_menu
struct UpperMenuDrawable: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {

            RoundedRectangle(cornerRadius: 8) // Android corners radius="8dp"
                .fill(
                    colorScheme == .light 
                        ? Color.black.opacity(0.2) 
                        : Color.black.opacity(0.3)
                )
                .offset(x: 0, y: 2) // Android elevation shadow offset
                .blur(radius: 4) // Android elevation blur
                .allowsHitTesting(false)
            
            // Main drawable background
            RoundedRectangle(cornerRadius: 8) // Android corners radius="8dp"
                .fill(Color("sleepBox")) // Android solid color="@color/menuRect"
                .overlay(
                    // Android stroke (if needed)
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            colorScheme == .light 
                                ? Color.black.opacity(0.1) 
                                : Color(red: 0xF6/255, green: 0xF7/255, blue: 0xFF/255).opacity(0.1), 
                            lineWidth: 0.5
                        )
                )
        }
    }
}

struct MainActivityOld_Previews: PreviewProvider {
    static var previews: some View {
        MainActivityOld()
    }
}

struct NetworkLoaderBar: View {
    @State private var themeColorHex: String = Constant.themeColor
    
    var body: some View {
        HorizontalProgressBar(
            trackColor: trackColors.track.opacity(0.35),
            indicatorColors: [trackColors.primary, trackColors.secondary]
        )
        .frame(height: 4)
        .frame(maxWidth: .infinity)
        .background(Color("background_color"))
        .onAppear {
            themeColorHex = Constant.themeColor
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            themeColorHex = Constant.themeColor
        }
    }
    
    private var trackColors: (track: Color, primary: Color, secondary: Color) {
        let key = themeColorHex.lowercased()
        switch key {
        case "#ff0080":
            return (colorFromHex("#FF0080"), colorFromHex("#FF6D00"), colorFromHex("#FFA726"))
        case "#00a3e9":
            return (colorFromHex(Constant.themeColor), colorFromHex("#00BFA5"), colorFromHex("#0088FF"))
        case "#7adf2a":
            return (colorFromHex("#7ADF2A"), colorFromHex("#00C853"), colorFromHex("#66BB6A"))
        case "#ec0001":
            return (colorFromHex("#EC0001"), colorFromHex("#EC7500"), colorFromHex("#FF7043"))
        case "#16f3ff":
            return (colorFromHex("#16F3FF"), colorFromHex("#00F365"), colorFromHex("#00BCD4"))
        case "#ff8a00":
            return (colorFromHex("#FF8A00"), colorFromHex("#FFAB00"), colorFromHex("#FF7043"))
        case "#7f7f7f":
            return (colorFromHex("#7F7F7F"), colorFromHex("#314E6D"), colorFromHex("#546E7A"))
        case "#d9b845":
            return (colorFromHex("#D9B845"), colorFromHex("#B0D945"), colorFromHex("#8BC34A"))
        case "#346667":
            return (colorFromHex("#346667"), colorFromHex("#729412"), colorFromHex("#26A69A"))
        case "#9846d9":
            return (colorFromHex("#9846D9"), colorFromHex("#D946D1"), colorFromHex("#7E57C2"))
        case "#a81010":
            return (colorFromHex("#A81010"), colorFromHex("#D85D01"), colorFromHex("#E53935"))
        default:
            return (colorFromHex(Constant.themeColor), colorFromHex("#00BFA5"), colorFromHex("#0088FF"))
        }
    }
    
    private func colorFromHex(_ hex: String) -> Color {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleaned.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 163, 233)
        }
        return Color(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
