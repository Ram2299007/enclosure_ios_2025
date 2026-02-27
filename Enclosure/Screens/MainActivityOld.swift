import SwiftUI
import Combine
import FirebaseDatabase
import FirebaseAuth

struct MainActivityOld: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase
    @State private var searchText = ""
    @State private var isSearchActive = false
    @FocusState private var isSearchFieldFocused: Bool
    @State private var isCallEnabled = true
    @State private var isVideoCallEnabled = true
    @State private var isTapped = false
    @State private var isVStackVisible = false
    @State private var isTopHeaderVisible = false
    @State private var isMainContentVisible = true
    @State private var showNameDialog = false
    @State private var showInviteScreen = false
    /// Expand: mainvector. Collapse: bg only (shutter up) — keep collapse as is.
    @State private var currentBackgroundImage = "bg"
    /// Header height: collapsed 128pt (room for top), expanded 400pt — driven by ValueAnimator-style driver
    @State private var currentBackgroundSizeHeight: CGFloat = 128
    /// Android ValueAnimator: 450ms — single progress 0...1 for stability (one state update per frame)
    @State private var heightAnimStartTime: Date?
    @State private var heightAnimProgress: Double? = nil // nil = idle, 0...1 = in progress
    @State private var heightAnimFrom: CGFloat = 128
    @State private var heightAnimTo: CGFloat = 128
    @State private var heightAnimFromOpacity: Double = 0.1
    @State private var heightAnimToOpacity: Double = 1
    @State private var heightAnimIsCollapse = false
    @State private var opacity = 0.1
    @State private var viewValue = Constant.chatView
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @State private var showNetworkLoader = false
    
    // Chat long press dialog state
    @State private var selectedChatForDialog: UserActiveContactModel? = nil
    @State private var chatDialogPosition: CGPoint = .zero
    @State private var showChatLongPressDialog = false
    
    // Navigation to chatting screen
    @State private var selectedChatForNavigation: UserActiveContactModel? = nil
    @State private var navigateToChattingScreen: Bool = false
    
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
    
    // Incoming call on/off toast (matching Android incomingonoffLyt CardView)
    @State private var showIncomingOnOffToast = false
    @State private var incomingOnOffText = ""
    
    // Shared content handling (for Share Extension)
    @State private var showShareExternalDataContactScreen: Bool = false
    @State private var sharedContentToShow: SharedContent?
    @State private var sharedCaption: String = ""
    
    // Incoming voice call from CallKit
    @State private var incomingVoiceCallPayload: VoiceCallPayload?

    // Incoming video call from CallKit
    @State private var incomingVideoCallPayload: VideoCallPayload?

    // Reliable pending call observer (survives background/lockscreen transitions)
    @ObservedObject private var pendingCallManager = PendingCallManager.shared
    
    // Active call banner (WhatsApp-like) — observe ActiveCallManager for ongoing call
    @ObservedObject private var activeCallManager = ActiveCallManager.shared
    @State private var showActiveCallScreen = false
    @State private var showVideoCallFromPiP = false
    
    // DEBUG: Test button to verify screen presentation works
    #if DEBUG
    @State private var showTestShareScreen: Bool = false
    #endif
    
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

    /// Derived from single progress for stable animation (no dual state updates per frame)
    private var effectiveHeaderHeight: CGFloat {
        guard let p = heightAnimProgress else { return currentBackgroundSizeHeight }
        return heightAnimFrom + (heightAnimTo - heightAnimFrom) * CGFloat(p)
    }
    private var effectiveHeaderOpacity: Double {
        guard let p = heightAnimProgress else { return opacity }
        return heightAnimFromOpacity + (heightAnimToOpacity - heightAnimFromOpacity) * p
    }

    // Helper function to hide keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Android ValueAnimator: 450ms, AccelerateDecelerate — height + opacity in sync
                ValueAnimatorHeightDriver(
                    startTime: $heightAnimStartTime,
                    progress: $heightAnimProgress,
                    from: heightAnimFrom,
                    to: heightAnimTo,
                    duration: 0.55,
                    height: $currentBackgroundSizeHeight,
                    fromOpacity: heightAnimFromOpacity,
                    toOpacity: heightAnimToOpacity,
                    opacity: $opacity,
                    onComplete: heightAnimIsCollapse ? { isVStackVisible = false; opacity = 0 } : nil
                )
                Color("BackgroundColor")
                    .ignoresSafeArea()
                
                VStack(spacing:0) {

                // MARK: - WhatsApp-like Active Call Banner
                // Shows at top when user presses back on call screen (call still running)
                #if !targetEnvironment(simulator)
                if let session = activeCallManager.activeSession,
                   !session.shouldDismiss,
                   incomingVoiceCallPayload == nil {
                    ActiveCallBannerView(session: session) {
                        // Tap → re-open call screen
                        showActiveCallScreen = true
                    }
                }
                #endif

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
                        .frame(width: 70, height: activeCallManager.hasActiveCall ? 58 : 70)
                        .padding(.leading, 25)

                        Spacer()

                        HStack {
                            if viewValue == Constant.chatView {
                                Group {
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
                                                .focused($isSearchFieldFocused)
                                        }
                                        .transition(
                                            .move(edge: .trailing).combined(with: .opacity)
                                        )
                                    }

                                    Button(action: {
                                        withAnimation {
                                            if isSearchActive {
                                                if isSearchFieldFocused {
                                                    isSearchActive = false
                                                    searchText = ""
                                                    isSearchFieldFocused = false
                                                    hideKeyboard()
                                                } else {
                                                    isSearchFieldFocused = true
                                                }
                                            } else {
                                                isSearchActive = true
                                                isSearchFieldFocused = true
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
                                .opacity(isVStackVisible ? 0 : 1)
                                .animation(.easeInOut(duration: 0.35), value: isVStackVisible)
                                .allowsHitTesting(!isVStackVisible)
                            }

                            // Menu button - ripple effect + haptics
                            Button(action: {
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
                            }) {
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
                            }
                            .buttonStyle(CircularRippleStyle())
                            .padding(.trailing,8)
                        }
                    }





                    // main container — ZStack so background and content share same clip (inner stays inside bg/mainvector)
                    ZStack(alignment: .top) {
                        // 1) Background fills entire header so content never spills outside
                        Group {
                            if currentBackgroundImage == "mainvector" {
                                Image("mainvector")
                                    .renderingMode(.template)
                                    .resizable()
                                    .foregroundColor(backgroundTintColor)
                            } else {
                                Image("bg")
                                    .renderingMode(.template)
                                    .resizable()
                                    .foregroundColor(backgroundTintColor)
                            }
                        }
                        .animation(nil, value: currentBackgroundImage)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        // 2) Content on top — top padding so upper area isn’t cut when expanded
                        VStack (spacing:0){
                        /// 1

                        // HStack {
                        //     Spacer()
                        //     Button(action: {
                        //         let wasExpanded = isVStackVisible
                        //         let duration: TimeInterval = 0.55 // Slightly faster
                        //         let expandedHeight: CGFloat = 400
                        //         let collapsedHeight: CGFloat = 128

                        //         if !wasExpanded {
                        //             currentBackgroundImage = "mainvector"
                        //             isVStackVisible = true
                        //             isTopHeaderVisible = true
                        //             selected = .call
                        //             viewValue = Constant.callView
                        //             heightAnimFrom = currentBackgroundSizeHeight
                        //             heightAnimTo = expandedHeight
                        //             heightAnimFromOpacity = opacity
                        //             heightAnimToOpacity = 1
                        //             heightAnimIsCollapse = false
                        //             heightAnimStartTime = Date()
                        //         } else {
                        //             // Collapse: hide inner content immediately — only animate header height (smooth shutter, no mixing)
                        //             currentBackgroundImage = "bg"
                        //             isVStackVisible = false
                        //             viewValue = Constant.chatView
                        //             isTopHeaderVisible = false
                        //             opacity = 0
                        //             heightAnimFrom = currentBackgroundSizeHeight
                        //             heightAnimTo = collapsedHeight
                        //             heightAnimFromOpacity = 0
                        //             heightAnimToOpacity = 0
                        //             heightAnimIsCollapse = true
                        //             heightAnimStartTime = Date()
                        //         }
                        //     }) {
                        //         VStack{
                        //             Image("downarrowslide")
                        //                 .resizable()
                        //                 .frame(width: 24, height: 24)
                        //         }
                        //         .frame(width: 40, height: 40)

                        //     }
                        //     .padding(.trailing , 16)
                        //     .buttonStyle(CircularRippleStyle())
                        // }
                        // .padding(.top, 0)

                        VStack {
    Spacer()   // 👈 Top space

    HStack {
        Spacer()
        Button(action: {
            let wasExpanded = isVStackVisible
            let expandedHeight: CGFloat = 400
            let collapsedHeight: CGFloat = 128

            if !wasExpanded {
                currentBackgroundImage = "mainvector"
                isVStackVisible = true
                isTopHeaderVisible = true
                selected = .call
                viewValue = Constant.callView
                heightAnimFrom = currentBackgroundSizeHeight
                heightAnimTo = expandedHeight
                heightAnimFromOpacity = opacity
                heightAnimToOpacity = 1
                heightAnimIsCollapse = false
                heightAnimStartTime = Date()
            } else {
                currentBackgroundImage = "bg"
                isVStackVisible = false
                viewValue = Constant.chatView
                isTopHeaderVisible = false
                opacity = 0
                heightAnimFrom = currentBackgroundSizeHeight
                heightAnimTo = collapsedHeight
                heightAnimFromOpacity = 0
                heightAnimToOpacity = 0
                heightAnimIsCollapse = true
                heightAnimStartTime = Date()
            }
        }) {
            VStack{
                Image("downarrowslide")
                    .resizable()
                    .frame(width: 24, height: 24)
            }
            .frame(width: 40, height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(CircularRippleStyle())
        .padding(.trailing, 16)
    }

    Spacer()   // 👈 Bottom space
}.padding(.top, 30)




                        if isVStackVisible{
                            /// 2 — identity so inner content is present from frame 1; only height + opacity animate (smooth expand)
                            VStack{


                                // #1
                                HStack(alignment: .center) {
                                    // Left side: Audio call switch


                                    HStack(spacing: 8) {
                                        Text("Audio call")
                                            .font(.custom("Inter18pt-Medium", size: 15))
                                            .fontWeight(.heavy)
                                            .foregroundColor(isCallEnabled ? .white : Color(hex: "#9EA6B9"))
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
                                            .foregroundColor(isVideoCallEnabled ? .white : Color(hex: "#9EA6B9"))
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
                            .opacity(isVStackVisible ? effectiveHeaderOpacity : effectiveHeaderOpacity)
                            .transition(.identity) // No insertion transition — content present from frame 1; height + opacity drive smooth expand


                        }



                        Spacer()

                    }
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)
                    .padding(.top, 10)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: effectiveHeaderHeight)
                    .drawingGroup()
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
                            showLongPressDialog: $showChatLongPressDialog,
                            selectedChatForNavigation: $selectedChatForNavigation
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
                
                // Incoming call on/off toast (matching Android incomingonoffLyt CardView)
                if showIncomingOnOffToast {
                    VStack {
                        Text(incomingOnOffText)
                            .font(.custom("Inter18pt-Medium", size: 17))
                            .foregroundColor(Color("TextColor"))
                            .padding(.horizontal, 22)
                            .padding(.vertical, 8)
                            .background(Color("cardBackgroundColornew"))
                            .cornerRadius(10)
                            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 146)
                    .zIndex(1000)
                    .transition(.opacity)
                }
            }
            .opacity(initialFadeInOpacity)
            .navigationBarHidden(true)
            .background(NavigationGestureEnabler())
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
            .navigationDestination(isPresented: $navigateToChattingScreen) {
                if let chat = selectedChatForNavigation {
                    ChattingScreen(contact: chat)
                } else {
                    EmptyView()
                }
            }
            .onChange(of: selectedChatForNavigation) { newValue in
                if let contact = newValue {
                    print("✅ [MainActivityOld] selectedChatForNavigation changed - navigating to ChattingScreen")
                    print("📱 [MainActivityOld] Contact: \(contact.fullName) (\(contact.uid))")
                    
                    // Clear notification count for this chat
                    if contact.notification > 0 {
                        print("📱 [MainActivityOld] Clearing notification count: \(contact.notification) for user: \(contact.uid)")
                        
                        // Clear in Firebase and decrement badge
                        BadgeManager.shared.clearNotificationCount(
                            forUserUid: contact.uid,
                            currentUserUid: Constant.SenderIdMy,
                            previousCount: contact.notification
                        )
                    }
                    
                    navigateToChattingScreen = true
                } else {
                    print("📱 [MainActivityOld] selectedChatForNavigation cleared")
                    navigateToChattingScreen = false
                }
            }
            .onChange(of: navigateToChattingScreen) { isPresented in
                if !isPresented {
                    // Reset selected chat when navigation is dismissed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        selectedChatForNavigation = nil
                    }
                }
            }
            .fullScreenCover(isPresented: $showShareExternalDataContactScreen) {
                Group {
                    if let content = sharedContentToShow {
                        ShareExternalDataContactScreen(
                            sharedContent: content,
                            caption: sharedCaption,
                            onNavigateToChat: { contact in
                                // Navigate to ChattingScreen for single contact (matching Android behavior)
                                selectedChatForNavigation = contact
                                showShareExternalDataContactScreen = false
                            }
                        )
                        .onAppear {
                            print("✅ [MainActivityOld] ShareExternalDataContactScreen appeared!")
                        }
                    } else {
                        VStack {
                            Text("Error: No shared content")
                                .foregroundColor(.red)
                            Button("Close") {
                                showShareExternalDataContactScreen = false
                            }
                        }
                        .onAppear {
                            print("🚫 [MainActivityOld] ShareExternalDataContactScreen appeared but sharedContentToShow is nil!")
                        }
                    }
                }
            }
            .fullScreenCover(item: $incomingVoiceCallPayload) { payload in
                VoiceCallScreen(payload: payload)
                    .onAppear {
                        NSLog("✅✅✅ [MainActivityOld] ========================================")
                        NSLog("✅ [MainActivityOld] VoiceCallScreen APPEARED!")
                        NSLog("✅ [MainActivityOld] Payload: \(payload.id)")
                        NSLog("✅ [MainActivityOld] Caller: \(payload.receiverName)")
                        NSLog("✅ [MainActivityOld] Room: \(payload.roomId ?? "nil")")
                        NSLog("✅✅✅ [MainActivityOld] ========================================")
                        print("✅✅✅ [MainActivityOld] VoiceCallScreen DISPLAYED!")
                    }
                    .onDisappear {
                        NSLog("📞 [MainActivityOld] VoiceCallScreen dismissed")
                        print("📞 [MainActivityOld] Voice call ended")
                        // Reset payload
                        incomingVoiceCallPayload = nil
                    }
            }
            .fullScreenCover(isPresented: $showActiveCallScreen) {
                // Re-present call screen from active call banner
                if let payload = activeCallManager.activePayload {
                    VoiceCallScreen(payload: payload)
                        .onDisappear {
                            showActiveCallScreen = false
                            NSLog("📞 [MainActivityOld] Call screen re-dismissed from banner")
                        }
                }
            }
            .fullScreenCover(item: $incomingVideoCallPayload) { payload in
                VideoCallScreen(payload: payload)
                    .onDisappear {
                        NSLog("📞 [MainActivityOld] VideoCallScreen dismissed")
                        print("📞 [MainActivityOld] Video call ended")
                        // Only clear payload if NOT entering PiP
                        if !ActiveCallManager.shared.isInPiPMode {
                            incomingVideoCallPayload = nil
                        }
                    }
            }
            .fullScreenCover(isPresented: $showVideoCallFromPiP) {
                if let payload = activeCallManager.activeVideoPayload {
                    VideoCallScreen(payload: payload)
                        .onDisappear {
                            NSLog("📞 [MainActivityOld] VideoCallScreen re-dismissed from PiP")
                            if !ActiveCallManager.shared.isInPiPMode {
                                showVideoCallFromPiP = false
                            }
                        }
                }
            }
            .overlay(alignment: .topTrailing) {
                // PiP floating overlay
                #if !targetEnvironment(simulator)
                if activeCallManager.isInPiPMode, let session = activeCallManager.activeVideoSession {
                    VideoCallPiPView(session: session, callManager: activeCallManager)
                }
                #endif
            }
            .background {
                // Persistent invisible source view for system background PiP.
                // Must stay in hierarchy even when full-screen video call is dismissed.
                #if !targetEnvironment(simulator)
                if activeCallManager.activeVideoSession != nil {
                    PiPSourceViewBridge { sourceView in
                        activeCallManager.activeVideoSession?.setupSystemPiP(sourceView: sourceView)
                    }
                }
                #endif
            }
            .onChange(of: activeCallManager.isInPiPMode) { isPiP in
                #if !targetEnvironment(simulator)
                if !isPiP && activeCallManager.activeVideoSession != nil {
                    // User tapped PiP → re-open full screen
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showVideoCallFromPiP = true
                    }
                }
                #endif
            }
            .onChange(of: incomingVoiceCallPayload) { newValue in
                if let payload = newValue {
                    NSLog("🔄 [MainActivityOld] incomingVoiceCallPayload CHANGED to: \(payload.id)")
                    NSLog("🔄 [MainActivityOld] fullScreenCover should trigger now")
                    print("🔄 [MainActivityOld] Payload changed - fullScreenCover should show")
                } else {
                    NSLog("🔄 [MainActivityOld] incomingVoiceCallPayload cleared")
                    print("🔄 [MainActivityOld] Payload cleared")
                }
            }
            .onChange(of: showShareExternalDataContactScreen) { newValue in
                print("📤 [MainActivityOld] showShareExternalDataContactScreen changed to: \(newValue)")
            }
            .onChange(of: sharedContentToShow != nil) { hasContent in
                print("📤 [MainActivityOld] sharedContentToShow changed: \(hasContent)")
            }
            .onChange(of: isCallEnabled) { newValue in
                // Matching Android switchcall.setOnCheckedChangeListener
                let sharedDefaults = UserDefaults(suiteName: "group.com.enclosure.data")
                if newValue {
                    UserDefaults.standard.set(Constant.voiceRadioKey, forKey: Constant.voiceRadioKey)
                    sharedDefaults?.set(true, forKey: Constant.voiceRadioKey)
                    showIncomingOnOffToastMessage("Incoming Calls : ON")
                } else {
                    UserDefaults.standard.set("", forKey: Constant.voiceRadioKey)
                    sharedDefaults?.set(false, forKey: Constant.voiceRadioKey)
                    showIncomingOnOffToastMessage("Incoming Calls : OFF")
                }
            }
            .onChange(of: isVideoCallEnabled) { newValue in
                // Matching Android switchVideocall.setOnCheckedChangeListener
                let sharedDefaults = UserDefaults(suiteName: "group.com.enclosure.data")
                if newValue {
                    UserDefaults.standard.set(Constant.videoRadioKey, forKey: Constant.videoRadioKey)
                    sharedDefaults?.set(true, forKey: Constant.videoRadioKey)
                    showIncomingOnOffToastMessage("Incoming Video Calls : ON")
                } else {
                    UserDefaults.standard.set("", forKey: Constant.videoRadioKey)
                    sharedDefaults?.set(false, forKey: Constant.videoRadioKey)
                    showIncomingOnOffToastMessage("Incoming Video Calls : OFF")
                }
            }
        }
        .onAppear {
            showNetworkLoader = !networkMonitor.isConnected
            updateLogoBasedOnTheme()
            
            // Load saved toggle state from UserDefaults (matching Android onResume voiceRadioKey/videoRadioKey check)
            let voiceRadio = UserDefaults.standard.string(forKey: Constant.voiceRadioKey) ?? "turnedOn"
            let videoRadio = UserDefaults.standard.string(forKey: Constant.videoRadioKey) ?? "turnedOn"
            isCallEnabled = (voiceRadio == Constant.voiceRadioKey || voiceRadio == "turnedOn")
            isVideoCallEnabled = (videoRadio == Constant.videoRadioKey || videoRadio == "turnedOn")
            
            // Sync to shared App Group UserDefaults so NSE can suppress call notifications
            let sharedDefaults = UserDefaults(suiteName: "group.com.enclosure.data")
            sharedDefaults?.set(isCallEnabled, forKey: Constant.voiceRadioKey)
            sharedDefaults?.set(isVideoCallEnabled, forKey: Constant.videoRadioKey)
            
            // Smooth fade-in animation when view appears
            withAnimation(.easeInOut(duration: 0.3)) {
                initialFadeInOpacity = 1.0
            }
            
            // Authenticate as anonymous user
            authenticateAnonymousUser()
            
            // Check if name dialog should be shown (matching Android logic)
            let nameSaved = UserDefaults.standard.string(forKey: "nameSAved") ?? "0"
            if nameSaved != "nameSAved" {
                // Show dialog on first visit
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showNameDialog = true
                }
            }
            
            // Don't check for shared content in onAppear - only check when notification is received
            // The Share Extension opens the app via URL scheme, which triggers AppDelegate
            // AppDelegate posts a notification, which we handle below
            
            // Request notification permission every time until user accepts (custom dialog first, then system)
            requestNotificationPermissionIfNeeded()
        }
        .onReceive(networkMonitor.$isConnected) { isConnected in
            withAnimation(.easeInOut(duration: 0.2)) {
                showNetworkLoader = !isConnected
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ThemeColorUpdated"))) { notification in
            updateLogoBasedOnTheme()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // Request notification permission until accepted (every time we become active if not granted)
                requestNotificationPermissionIfNeeded()
                print("📤 [MainActivityOld] App became active - checking for shared content...")
                // Wait 1.5s to ensure Share Extension has finished saving and data is synced across processes
                // This is important because Share Extension opens app via URL scheme, but if app is already running,
                // iOS might not call application(_:open:options:) immediately
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    print("📤 [MainActivityOld] ⏰ Checking for shared content after becoming active...")
                    checkForSharedContent()
                }

                // Check for pending calls (background / lock screen answer)
                // NotificationCenter might have missed the AnswerIncomingCall notification
                // PendingCallManager is the reliable fallback
                checkAndConsumePendingCalls()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HandleSharedContent"))) { notification in
            NSLog("📤📤📤 [MainActivityOld] ====== Received HandleSharedContent notification ======")
            print("📤 [MainActivityOld] Received HandleSharedContent notification")
            NSLog("📤 [MainActivityOld] Notification object: \(notification.object ?? "nil")")
            print("📤 [MainActivityOld] Notification object: \(notification.object ?? "nil")")
            
            if let url = notification.object as? URL {
                NSLog("📤 [MainActivityOld] Notification contains URL: \(url)")
                print("📤 [MainActivityOld] Notification contains URL: \(url)")
                handleSharedContent(from: url)
            } else {
                // Notification without URL - check UserDefaults directly
                // File container is fast - check immediately
                NSLog("📤 [MainActivityOld] Notification without URL - checking file container immediately...")
                print("📤 [MainActivityOld] Notification without URL - checking file container immediately...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    NSLog("📤📤📤 [MainActivityOld] ⏰⏰⏰ DELAY COMPLETE - Calling checkForSharedContent NOW ⏰⏰⏰")
                    print("📤 [MainActivityOld] ⏰ Checking for shared content after notification...")
                    self.checkForSharedContent()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenChatFromNotification"))) { notification in
            // Open ChattingScreen when user taps chat notification (matching Android PendingIntent to chattingScreen with friendUidKey, nameKey, etc.)
            print("📱 [MainActivityOld] OpenChatFromNotification received")
            
            guard let userInfo = notification.userInfo as? [String: Any] else {
                print("🚫 [MainActivityOld] OpenChatFromNotification: userInfo is nil or invalid type")
                return
            }
            
            print("📱 [MainActivityOld] OpenChatFromNotification: userInfo contains \(userInfo.count) keys")
            print("📱 [MainActivityOld] OpenChatFromNotification: keys: \(userInfo.keys.joined(separator: ", "))")
            
            guard let contact = UserActiveContactModel.fromChatNotification(userInfo: userInfo) else {
                print("🚫 [MainActivityOld] OpenChatFromNotification: failed to create contact from userInfo")
                print("🚫 [MainActivityOld] OpenChatFromNotification: friendUidKey = \(userInfo["friendUidKey"] as? String ?? "nil")")
                return
            }
            
            print("✅ [MainActivityOld] OpenChatFromNotification: Successfully created contact")
            print("📱 [MainActivityOld] OpenChatFromNotification: navigating to chat with \(contact.fullName) (\(contact.uid))")
            print("📱 [MainActivityOld] OpenChatFromNotification: deviceType = \(contact.deviceType)")
            print("📱 [MainActivityOld] OpenChatFromNotification: photo = \(contact.photo.isEmpty ? "nil" : "set")")
            
            // Navigate to ChattingScreen (matching Android Intent to chattingScreen)
            selectedChatForNavigation = contact
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AnswerIncomingCall"))) { notification in
            // Handle incoming call answered via CallKit
            NSLog("📞📞📞 [MainActivityOld] ========================================")
            NSLog("📞 [MainActivityOld] AnswerIncomingCall notification RECEIVED!")
            NSLog("📞 [MainActivityOld] App State: \(UIApplication.shared.applicationState.rawValue)")
            NSLog("📞 [MainActivityOld] Scene Phase: \(scenePhase)")
            NSLog("📞 [MainActivityOld] ========================================")
            print("📞📞📞 [MainActivityOld] AnswerIncomingCall RECEIVED!")
            
            guard let userInfo = notification.userInfo as? [String: String] else {
                NSLog("❌ [MainActivityOld] AnswerIncomingCall: userInfo is nil or invalid type")
                print("❌ [MainActivityOld] AnswerIncomingCall: userInfo missing")
                return
            }
            
            NSLog("📞 [MainActivityOld] AnswerIncomingCall userInfo keys: \(userInfo.keys.joined(separator: ", "))")
            NSLog("📞 [MainActivityOld] Full userInfo: \(userInfo)")
            print("📞 [MainActivityOld] UserInfo keys: \(userInfo.keys.joined(separator: ", "))")
            
            // Extract call data
            let roomId = userInfo["roomId"] ?? ""
            let receiverId = userInfo["receiverId"] ?? ""
            let receiverPhone = userInfo["receiverPhone"] ?? ""
            let callerName = userInfo["callerName"] ?? "Unknown"
            let callerPhoto = userInfo["callerPhoto"] ?? ""
            let isVideoCall = (userInfo["isVideoCall"] ?? "0") == "1"
            
            NSLog("📞 [MainActivityOld] Extracted: roomId=\(roomId), receiverId=\(receiverId), caller=\(callerName)")
            
            guard !roomId.isEmpty, !receiverId.isEmpty else {
                NSLog("❌ [MainActivityOld] AnswerIncomingCall: Missing required data")
                NSLog("❌ [MainActivityOld] roomId='\(roomId)', receiverId='\(receiverId)'")
                print("❌ [MainActivityOld] AnswerIncomingCall: Invalid data")
                return
            }
            
            NSLog("📞 [MainActivityOld] ✅ Data validation passed")
            if isVideoCall {
                NSLog("📞 [MainActivityOld] Creating VideoCallPayload...")
                print("📞 [MainActivityOld] Creating video call payload for \(callerName)")

                let payload = VideoCallPayload(
                    receiverId: receiverId,
                    receiverName: callerName,
                    receiverPhoto: callerPhoto,
                    receiverToken: "",
                    receiverDeviceType: "",
                    receiverPhone: receiverPhone,
                    roomId: roomId,
                    isSender: false
                )

                incomingVideoCallPayload = payload
                incomingVoiceCallPayload = nil
                pendingCallManager.clearAll()
                print("✅✅✅ [MainActivityOld] VideoCallScreen ACTIVE")
            } else {
                NSLog("📞 [MainActivityOld] Creating VoiceCallPayload...")
                print("📞 [MainActivityOld] Creating voice call payload for \(callerName)")
                
                let payload = VoiceCallPayload(
                    receiverId: receiverId,
                    receiverName: callerName,
                    receiverPhoto: callerPhoto,
                    receiverToken: "", // Will be fetched in VoiceCallSession if needed
                    receiverDeviceType: "", // Not needed for incoming calls
                    receiverPhone: receiverPhone,
                    roomId: roomId,
                    isSender: false // We're receiving the call
                )
                
                incomingVoiceCallPayload = payload
                incomingVideoCallPayload = nil
                // Clear PendingCallManager since we handled it via NotificationCenter
                pendingCallManager.clearAll()
                print("✅✅✅ [MainActivityOld] VoiceCallScreen ACTIVE")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("InitiateCallFromRecents"))) { notification in
            // User tapped a recent Enclosure call in the native Phone app → initiate outgoing call
            guard let userInfo = notification.userInfo as? [String: String] else {
                NSLog("⚠️ [MainActivityOld] InitiateCallFromRecents: userInfo missing")
                return
            }
            
            let friendId = userInfo["friendId"] ?? ""
            var fullName = userInfo["fullName"] ?? "Unknown"
            var photo = userInfo["photo"] ?? ""
            var fToken = userInfo["fToken"] ?? ""
            var voipToken = userInfo["voipToken"] ?? ""
            var deviceType = userInfo["deviceType"] ?? ""
            var mobileNo = userInfo["mobileNo"] ?? ""
            let isVideoCall = userInfo["isVideoCall"] == "1"
            
            NSLog("📞 [MainActivityOld] InitiateCallFromRecents: \(fullName) (id=\(friendId), video=\(isVideoCall))")
            
            guard !friendId.isEmpty else {
                NSLog("⚠️ [MainActivityOld] InitiateCallFromRecents: Missing friendId, cannot call")
                Constant.showToast(message: "Unable to call — contact info unavailable.")
                return
            }
            
            // If fToken is empty, try to look up from cached calling contacts
            if fToken.isEmpty {
                NSLog("📞 [MainActivityOld] InitiateCallFromRecents: fToken empty, looking up cached contacts...")
                CallCacheManager.shared.fetchContacts { cachedContacts in
                    if let cached = cachedContacts.first(where: { $0.uid == friendId }) {
                        NSLog("✅ [MainActivityOld] Found contact in cache: \(cached.fullName)")
                        fToken = cached.fToken
                        voipToken = cached.voipToken
                        deviceType = cached.deviceType
                        mobileNo = cached.mobileNo.isEmpty ? mobileNo : cached.mobileNo
                        if fullName == "Unknown" || fullName.isEmpty { fullName = cached.fullName }
                        if photo.isEmpty { photo = cached.photo }
                        // Re-save with complete data
                        RecentCallContactStore.shared.saveFromOutgoingCall(
                            friendId: friendId, fullName: fullName, photo: photo,
                            fToken: fToken, voipToken: voipToken, deviceType: deviceType,
                            mobileNo: mobileNo, isVideoCall: isVideoCall
                        )
                        self.initiateCallFromRecents(
                            friendId: friendId, fullName: fullName, photo: photo,
                            fToken: fToken, voipToken: voipToken, deviceType: deviceType,
                            mobileNo: mobileNo, isVideoCall: isVideoCall
                        )
                    } else {
                        NSLog("⚠️ [MainActivityOld] No cached contact found — cannot call")
                        Constant.showToast(message: "Unable to call — open the app first to sync contacts.")
                    }
                }
                return
            }
            
            // Don't start a new call if one is already active
            guard incomingVoiceCallPayload == nil, incomingVideoCallPayload == nil,
                  !activeCallManager.hasActiveCall else {
                NSLog("⚠️ [MainActivityOld] InitiateCallFromRecents: A call is already active, ignoring")
                return
            }
            
            initiateCallFromRecents(
                friendId: friendId, fullName: fullName, photo: photo,
                fToken: fToken, voipToken: voipToken, deviceType: deviceType,
                mobileNo: mobileNo, isVideoCall: isVideoCall
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("IncomingCallCancelled"))) { notification in
            let roomId = (notification.userInfo as? [String: String])?["roomId"] ?? ""
            NSLog("📞 [MainActivityOld] IncomingCallCancelled received. roomId=\(roomId)")
            print("📞 [MainActivityOld] IncomingCallCancelled received. roomId=\(roomId)")
            
            // Voice call: Do NOT dismiss if VoiceCallScreen is already active.
            // Once CallKit is dismissed and call is connected, the JS endCall →
            // VoiceCallSession.endCall() → shouldDismiss handles dismissal.
            // Clearing here kills the active call due to stale/late Firebase cancel signals.
            if incomingVoiceCallPayload != nil {
                NSLog("📞 [MainActivityOld] IncomingCallCancelled - VoiceCallScreen ACTIVE, not dismissing (session manages lifecycle)")
            } else {
                NSLog("📞 [MainActivityOld] IncomingCallCancelled - No active voice call, safe to clear")
            }
            
            // Video call: Same protection — do NOT dismiss if VideoCallScreen is already active.
            if incomingVideoCallPayload != nil {
                NSLog("📞 [MainActivityOld] IncomingCallCancelled - VideoCallScreen ACTIVE, not dismissing (session manages lifecycle)")
            } else {
                NSLog("📞 [MainActivityOld] IncomingCallCancelled - No active video call, safe to clear")
            }
        }
    }
    
    // MARK: - Initiate Call From Phone App Recents
    /// Handles both voice and video calls initiated from iPhone's native Phone app Recents.
    private func initiateCallFromRecents(
        friendId: String, fullName: String, photo: String,
        fToken: String, voipToken: String, deviceType: String,
        mobileNo: String, isVideoCall: Bool
    ) {
        guard !fToken.isEmpty else {
            NSLog("⚠️ [MainActivityOld] initiateCallFromRecents: fToken still empty, cannot call")
            Constant.showToast(message: "Unable to call — open the app first to sync contacts.")
            return
        }
        
        // Don't start a new call if one is already active
        guard incomingVoiceCallPayload == nil, incomingVideoCallPayload == nil,
              !activeCallManager.hasActiveCall else {
            NSLog("⚠️ [MainActivityOld] initiateCallFromRecents: A call is already active, ignoring")
            return
        }
        
        let roomId = "\(Int(Date().timeIntervalSince1970 * 1000))\(Int.random(in: 1000...9999))"
        
        if isVideoCall {
            let payload = VideoCallPayload(
                receiverId: friendId,
                receiverName: fullName,
                receiverPhoto: photo,
                receiverToken: fToken,
                receiverDeviceType: deviceType,
                receiverPhone: mobileNo,
                roomId: roomId,
                isSender: true
            )
            incomingVideoCallPayload = payload
            incomingVoiceCallPayload = nil
            
            MessageUploadService.shared.sendVideoCallNotification(
                receiverToken: fToken,
                receiverDeviceType: deviceType,
                receiverId: friendId,
                receiverPhone: mobileNo,
                roomId: roomId,
                voipToken: voipToken
            )
            NSLog("✅ [MainActivityOld] InitiateCallFromRecents: VIDEO call initiated to \(fullName)")
        } else {
            let payload = VoiceCallPayload(
                receiverId: friendId,
                receiverName: fullName,
                receiverPhoto: photo,
                receiverToken: fToken,
                receiverDeviceType: deviceType,
                receiverPhone: mobileNo,
                roomId: roomId,
                isSender: true
            )
            incomingVoiceCallPayload = payload
            incomingVideoCallPayload = nil
            
            MessageUploadService.shared.sendVoiceCallNotification(
                receiverToken: fToken,
                receiverDeviceType: deviceType,
                receiverId: friendId,
                receiverPhone: mobileNo,
                roomId: roomId,
                voipToken: voipToken
            )
            NSLog("✅ [MainActivityOld] InitiateCallFromRecents: VOICE call initiated to \(fullName)")
        }
    }
    
    // MARK: - Pending Call Check (Background / Lock Screen Fallback)
    /// Called when scenePhase becomes .active to pick up calls answered from background/lockscreen.
    /// PendingCallManager is the reliable source — NotificationCenter may have missed the notification.
    private func checkAndConsumePendingCalls() {
        // Don't consume if a call screen is already active
        guard incomingVoiceCallPayload == nil, incomingVideoCallPayload == nil else {
            NSLog("📞 [MainActivityOld] checkAndConsumePendingCalls: call screen already active, skipping")
            return
        }

        if let voicePayload = pendingCallManager.consumePendingVoiceCall() {
            NSLog("📞 [MainActivityOld] ✅ Consumed pending VOICE call from PendingCallManager")
            incomingVoiceCallPayload = voicePayload
            incomingVideoCallPayload = nil
        } else if let videoPayload = pendingCallManager.consumePendingVideoCall() {
            NSLog("📞 [MainActivityOld] ✅ Consumed pending VIDEO call from PendingCallManager")
            incomingVideoCallPayload = videoPayload
            incomingVoiceCallPayload = nil
        }
    }

    // MARK: - Incoming Call On/Off Toast (matching Android incomingonoffLyt)
    // Shows a floating card with fade-in then auto fade-out, matching Android fade_in2 + fade_outnew animations
    private func showIncomingOnOffToastMessage(_ message: String) {
        incomingOnOffText = message
        withAnimation(.easeIn(duration: 0.3)) {
            showIncomingOnOffToast = true
        }
        // Auto-dismiss after animation (matching Android onAnimationEnd -> fade_outnew)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.5)) {
                showIncomingOnOffToast = false
            }
        }
    }
    
    /// Request notification permission (custom dialog first, then system) every time until user accepts.
    private func requestNotificationPermissionIfNeeded() {
        AndroidStylePermissionManager.shared.requestPermissionWithDialogFromTopVC(for: .notifications) { granted in
            if granted {
                FirebaseManager.shared.requestNotificationPermissions()
            }
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
    
    // MARK: - Firebase Authentication
    
    /// Authenticate as anonymous user (always called when view appears)
    private func authenticateAnonymousUser() {
        // Check if user is already authenticated - reuse existing session
        if let currentUser = Auth.auth().currentUser {
            print("✅ [MainActivityOld] User already authenticated, reusing session - UID: \(currentUser.uid)")
            return
        }
        
        // Only sign in anonymously if no user is authenticated
        print("🔐 [MainActivityOld] No existing session, signing in as guest...")
        Auth.auth().signInAnonymously { authResult, error in
            if let error = error {
                print("🚫 [MainActivityOld] Guest authentication error: \(error.localizedDescription)")
                return
            }
            
            if let user = authResult?.user {
                print("✅ [MainActivityOld] Guest authentication successful - UID: \(user.uid)")
            } else {
                print("🚫 [MainActivityOld] Guest authentication failed - no user returned")
            }
        }
    }
    
    // MARK: - Shared Content Handling (for Share Extension)
    private func checkForSharedContent(maxRetries: Int = 10, currentRetry: Int = 0) {
        // Check immediately - delay is handled by callers
        DispatchQueue.main.async {
            NSLog("📤📤📤 [MainActivityOld] ====== CHECKING FOR SHARED CONTENT ======")
            print("📤 [MainActivityOld] ====== CHECKING FOR SHARED CONTENT ======")
            NSLog("📤 [MainActivityOld] Attempt \(currentRetry + 1)/\(maxRetries)")
            print("📤 [MainActivityOld] Attempt \(currentRetry + 1)/\(maxRetries)")
            
            // First, try reading from shared file container (more reliable)
            var contentType: String?
            var imageUrls: [String] = []
            var videoUrls: [String] = []
            var documentUrl: String?
            var documentName: String?
            var textData: String?
            
            NSLog("📤 [MainActivityOld] Step 1: Checking file container...")
            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.enclosure.data") {
                NSLog("📤 [MainActivityOld] ✅ File container accessible: \(containerURL.path)")
                let sharedFileURL = containerURL.appendingPathComponent("sharedContent.json")
                NSLog("📤 [MainActivityOld] Looking for file at: \(sharedFileURL.path)")
                
                if FileManager.default.fileExists(atPath: sharedFileURL.path) {
                    NSLog("📤📤📤 [MainActivityOld] ✅✅✅ FOUND FILE IN CONTAINER ✅✅✅")
                    print("📤 [MainActivityOld] Found shared content file: \(sharedFileURL.path)")
                    
                    do {
                        let fileData = try Data(contentsOf: sharedFileURL)
                        NSLog("📤 [MainActivityOld] File size: \(fileData.count) bytes")
                        if let json = try JSONSerialization.jsonObject(with: fileData) as? [String: Any] {
                            contentType = json["sharedContentType"] as? String
                            imageUrls = json["sharedImageUrls"] as? [String] ?? []
                            videoUrls = json["sharedVideoUrls"] as? [String] ?? []
                            documentUrl = json["sharedDocumentUrl"] as? String
                            documentName = json["sharedDocumentName"] as? String
                            textData = json["sharedTextData"] as? String
                            
                            NSLog("📤📤📤 [MainActivityOld] ✅✅✅ Successfully read from file container ✅✅✅")
                            print("📤 [MainActivityOld] ✅ Successfully read from file container")
                            NSLog("📤 [MainActivityOld] Content type from file: \(contentType ?? "nil")")
                            print("📤 [MainActivityOld] Content type from file: \(contentType ?? "nil")")
                            
                            // Delete file after reading
                            try? FileManager.default.removeItem(at: sharedFileURL)
                            NSLog("📤 [MainActivityOld] Deleted shared content file after reading")
                            print("📤 [MainActivityOld] Deleted shared content file after reading")
                        }
                    } catch {
                        NSLog("🚫 [MainActivityOld] Failed to read shared content file: \(error.localizedDescription)")
                        print("🚫 [MainActivityOld] Failed to read shared content file: \(error.localizedDescription)")
                    }
                } else {
                    NSLog("📤 [MainActivityOld] Shared content file does not exist at: \(sharedFileURL.path)")
                    print("📤 [MainActivityOld] Shared content file does not exist yet")
                }
            } else {
                NSLog("📤 [MainActivityOld] ⚠️ File container not accessible - App Group may not be configured")
            }
            
            NSLog("📤 [MainActivityOld] Step 2: Checking UserDefaults...")
            NSLog("📤 [MainActivityOld] Current contentType before UserDefaults check: \(contentType ?? "nil")")
            // Always check UserDefaults (primary method since file container might not be accessible)
            let sharedDefaults = UserDefaults(suiteName: "group.com.enclosure.data")
            
            if sharedDefaults == nil {
                NSLog("🔴🔴🔴 [MainActivityOld] CRITICAL: App Group UserDefaults is nil!")
                print("🔴 [MainActivityOld] CRITICAL: App Group UserDefaults is nil!")
                if currentRetry < maxRetries - 1 {
                    NSLog("📤 [MainActivityOld] Retrying in 0.5s... (attempt \(currentRetry + 1)/\(maxRetries))")
                    print("📤 [MainActivityOld] Retrying in 0.5s... (attempt \(currentRetry + 1)/\(maxRetries))")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.checkForSharedContent(maxRetries: maxRetries, currentRetry: currentRetry + 1)
                    }
                } else {
                    NSLog("🚫 [MainActivityOld] Failed after \(maxRetries) attempts - App Group not accessible")
                    print("🚫 [MainActivityOld] Failed after \(maxRetries) attempts - App Group not accessible")
                }
                return
            }
            
            NSLog("📤 [MainActivityOld] ✅ UserDefaults accessible")
            // Debug: List all keys in UserDefaults to see what's there
            if currentRetry == 0 {
                let allKeys = sharedDefaults!.dictionaryRepresentation().keys
                let sharedKeys = Array(allKeys).filter { $0.hasPrefix("shared") }
                NSLog("📤📤📤 [MainActivityOld] All UserDefaults keys with 'shared' prefix: \(sharedKeys)")
                print("📤 [MainActivityOld] All UserDefaults keys: \(sharedKeys)")
            }
            
            // Use UserDefaults data if file data wasn't found, or if file container isn't accessible
            NSLog("📤 [MainActivityOld] Step 3: Checking if contentType is nil...")
            NSLog("📤 [MainActivityOld] contentType value: \(contentType ?? "nil")")
            if contentType == nil {
                NSLog("📤 [MainActivityOld] File container data not found - checking UserDefaults...")
                print("📤 [MainActivityOld] File container data not found - checking UserDefaults...")
                contentType = sharedDefaults!.string(forKey: "sharedContentType")
                imageUrls = (sharedDefaults!.array(forKey: "sharedImageUrls") as? [String]) ?? []
                videoUrls = (sharedDefaults!.array(forKey: "sharedVideoUrls") as? [String]) ?? []
                documentUrl = sharedDefaults!.string(forKey: "sharedDocumentUrl")
                documentName = sharedDefaults!.string(forKey: "sharedDocumentName")
                textData = sharedDefaults!.string(forKey: "sharedTextData")
                
                // ALSO check CFPreferences as fallback (more reliable for App Groups)
                if contentType == nil {
                    NSLog("📤 [MainActivityOld] UserDefaults empty - checking CFPreferences...")
                    let appGroupID = "group.com.enclosure.data" as CFString
                    // Force synchronize CFPreferences first
                    CFPreferencesSynchronize(appGroupID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
                    NSLog("📤 [MainActivityOld] CFPreferences synchronized, checking for keys...")
                    
                    if let cfContentType = CFPreferencesCopyAppValue("sharedContentType" as CFString, appGroupID) as? String {
                        contentType = cfContentType
                        NSLog("📤📤📤 [MainActivityOld] ✅✅✅ FOUND IN CFPREFERENCES: \(cfContentType) ✅✅✅")
                    } else {
                        NSLog("📤 [MainActivityOld] CFPreferences returned nil for sharedContentType")
                    }
                    if let cfTextData = CFPreferencesCopyAppValue("sharedTextData" as CFString, appGroupID) as? String {
                        textData = cfTextData
                        NSLog("📤📤📤 [MainActivityOld] ✅✅✅ Found textData via CFPreferences: \(cfTextData.count) chars ✅✅✅")
                    } else {
                        NSLog("📤 [MainActivityOld] CFPreferences returned nil for sharedTextData")
                    }
                }
                
                // Debug: Print what we found
                NSLog("📤 [MainActivityOld] UserDefaults check results:")
                print("📤 [MainActivityOld] UserDefaults check results:")
                NSLog("   - sharedContentType: \(contentType ?? "nil")")
                print("   - sharedContentType: \(contentType ?? "nil")")
                NSLog("   - sharedTextData: \(textData != nil ? "\(textData!.count) chars" : "nil")")
                print("   - sharedTextData: \(textData != nil ? "\(textData!.count) chars" : "nil")")
                NSLog("   - sharedImageUrls: \(imageUrls.count) items")
                print("   - sharedImageUrls: \(imageUrls.count) items")
                NSLog("   - sharedVideoUrls: \(videoUrls.count) items")
                print("   - sharedVideoUrls: \(videoUrls.count) items")
                
                if contentType != nil {
                    NSLog("📤📤📤 [MainActivityOld] ✅✅✅ FOUND CONTENT IN USERDEFAULTS ✅✅✅")
                    print("📤 [MainActivityOld] ✅ Found content in UserDefaults")
                    NSLog("📤 [MainActivityOld] Content type: \(contentType ?? "nil")")
                    print("📤 [MainActivityOld] Content type from UserDefaults: \(contentType ?? "nil")")
                    NSLog("📤 [MainActivityOld] Text data: \(textData?.prefix(50) ?? "nil")...")
                    print("📤 [MainActivityOld] Text data from UserDefaults: \(textData?.prefix(50) ?? "nil")...")
                } else {
                    NSLog("📤 [MainActivityOld] ⚠️ No content found in UserDefaults yet")
                    print("📤 [MainActivityOld] ⚠️ No content found in UserDefaults yet")
                    // Force synchronize to ensure we have latest data
                    sharedDefaults!.synchronize()
                    NSLog("📤 [MainActivityOld] Called synchronize() - retrying read...")
                    print("📤 [MainActivityOld] Called synchronize() - retrying read...")
                    contentType = sharedDefaults!.string(forKey: "sharedContentType")
                    textData = sharedDefaults!.string(forKey: "sharedTextData")
                    if contentType != nil {
                        NSLog("📤📤📤 [MainActivityOld] ✅✅✅ FOUND CONTENT AFTER SYNCHRONIZE() ✅✅✅")
                        print("📤 [MainActivityOld] ✅ Found content after synchronize()!")
                    } else {
                        NSLog("📤 [MainActivityOld] ❌ Still no content after synchronize()")
                        print("📤 [MainActivityOld] ❌ Still no content after synchronize()")
                    }
                }
            } else {
                print("📤 [MainActivityOld] ✅ Using data from file container")
            }
            
            guard let contentType = contentType else {
                // Retry if we haven't exceeded max retries
                NSLog("📤📤📤 [MainActivityOld] ❌❌❌ contentType is NIL - will retry or give up ❌❌❌")
                print("📤 [MainActivityOld] ❌ contentType is nil")
                if currentRetry < maxRetries - 1 {
                    NSLog("📤 [MainActivityOld] Retrying in 0.2s... (attempt \(currentRetry + 1)/\(maxRetries))")
                    print("📤 [MainActivityOld] No shared content found - retrying in 0.2s... (attempt \(currentRetry + 1)/\(maxRetries))")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.checkForSharedContent(maxRetries: maxRetries, currentRetry: currentRetry + 1)
                    }
                    return
                } else {
                    NSLog("📤📤📤 [MainActivityOld] ❌❌❌ NO CONTENT FOUND AFTER \(maxRetries) ATTEMPTS ❌❌❌")
                    print("📤 [MainActivityOld] No shared content found after \(maxRetries) attempts")
                    print("📤 [MainActivityOld] This might mean:")
                    print("   1. Share Extension hasn't saved data yet")
                    print("   2. Share Extension failed to save data")
                    print("   3. App Group is not shared between Extension and App")
                    return
                }
            }
            
            NSLog("📤📤📤 [MainActivityOld] ✅✅✅ FOUND CONTENT TYPE: \(contentType) ✅✅✅")
            print("📤 [MainActivityOld] Found shared content type: \(contentType)")
        
        var sharedContent: SharedContent
        
        switch contentType {
        case "image":
            let urls = imageUrls.compactMap { URL(fileURLWithPath: $0) }
            sharedContent = SharedContent(type: .image)
            sharedContent.imageUrls = urls
            print("📤 [MainActivityOld] Found \(urls.count) images")
            
        case "video":
            let urls = videoUrls.compactMap { URL(fileURLWithPath: $0) }
            sharedContent = SharedContent(type: .video)
            sharedContent.videoUrls = urls
            print("📤 [MainActivityOld] Found \(urls.count) videos")
            
        case "document":
            let docUrl = documentUrl ?? ""
            let docName = documentName ?? ""
            let documentUrlPath = URL(fileURLWithPath: docUrl)
            sharedContent = SharedContent(type: .document)
            sharedContent.documentUrl = documentUrlPath
            sharedContent.documentName = docName
            print("📤 [MainActivityOld] Found document: \(docName)")
            
        case "contact":
            let docUrl = documentUrl ?? ""
            let documentUrlPath = URL(fileURLWithPath: docUrl)
            // Parse contact from vCard file
            if let contactInfo = parseContactFromVCard(url: documentUrlPath) {
                sharedContent = SharedContent(type: .contact)
                sharedContent.contact = contactInfo
                print("📤 [MainActivityOld] Found contact: \(contactInfo.name)")
            } else {
                print("🚫 [MainActivityOld] Failed to parse contact")
                return
            }
            
        case "text":
            let text = textData ?? ""
            sharedContent = SharedContent(type: .text)
            sharedContent.textData = text
            print("📤 [MainActivityOld] Found text: \(text.prefix(50))...")
            // Even if text is empty, still show contact screen (user might want to add caption)
            // This handles cases where URLs or other text might be empty initially
            
        default:
            print("⚠️ [MainActivityOld] Unknown content type: \(contentType)")
            // Don't return - still show contact screen even for unknown types
            // Create a text type as fallback
            let text = textData ?? ""
            sharedContent = SharedContent(type: .text)
            sharedContent.textData = text
            print("📤 [MainActivityOld] Fallback: Created text content with: \(text.prefix(50))...")
        }
        
        // Clear shared content from UserDefaults (if it exists)
        if let sharedDefaults = UserDefaults(suiteName: "group.com.enclosure.data") {
            sharedDefaults.removeObject(forKey: "sharedContentType")
            sharedDefaults.removeObject(forKey: "sharedImageUrls")
            sharedDefaults.removeObject(forKey: "sharedVideoUrls")
            sharedDefaults.removeObject(forKey: "sharedDocumentUrl")
            sharedDefaults.removeObject(forKey: "sharedDocumentName")
            sharedDefaults.removeObject(forKey: "sharedTextData")
            sharedDefaults.synchronize()
        }
        
        // Show contact selection screen directly (matching Android shareExternalDataCONTACTScreen)
        NSLog("📤📤📤 [MainActivityOld] ====== SHARED CONTENT READY ======")
        print("📤 [MainActivityOld] ====== SHARED CONTENT READY ======")
        NSLog("📤 [MainActivityOld] Content type: \(sharedContent.type)")
        print("📤 [MainActivityOld] Content type: \(sharedContent.type)")
        NSLog("📤 [MainActivityOld] Setting sharedContentToShow...")
        print("📤 [MainActivityOld] Setting sharedContentToShow...")
        
        // Set on main thread to ensure UI updates
        DispatchQueue.main.async {
            NSLog("📤📤📤 [MainActivityOld] ⏰⏰⏰ INSIDE DISPATCHQUEUE.MAIN.ASYNC ⏰⏰⏰")
            self.sharedContentToShow = sharedContent
            self.sharedCaption = "" // Initialize with empty caption
            NSLog("📤 [MainActivityOld] sharedContentToShow set: \(self.sharedContentToShow != nil)")
            print("📤 [MainActivityOld] sharedContentToShow set: \(self.sharedContentToShow != nil)")
            NSLog("📤 [MainActivityOld] Setting showShareExternalDataContactScreen = true...")
            print("📤 [MainActivityOld] Setting showShareExternalDataContactScreen = true...")
            self.showShareExternalDataContactScreen = true
            NSLog("📤📤📤 [MainActivityOld] ✅✅✅ showShareExternalDataContactScreen: \(self.showShareExternalDataContactScreen) ✅✅✅")
            print("📤 [MainActivityOld] ✅ showShareExternalDataContactScreen: \(self.showShareExternalDataContactScreen)")
            NSLog("📤📤📤 [MainActivityOld] ====== CONTACT SCREEN SHOULD APPEAR NOW ======")
            print("📤 [MainActivityOld] ====== CONTACT SCREEN SHOULD APPEAR NOW ======")
            
            // Force UI update
            if self.showShareExternalDataContactScreen {
                NSLog("📤 [MainActivityOld] ✅ State confirmed: showShareExternalDataContactScreen is TRUE")
                print("📤 [MainActivityOld] ✅ State confirmed: showShareExternalDataContactScreen is TRUE")
            } else {
                NSLog("🚫 [MainActivityOld] ❌ ERROR: showShareExternalDataContactScreen is FALSE after setting!")
                print("🚫 [MainActivityOld] ❌ ERROR: showShareExternalDataContactScreen is FALSE after setting!")
            }
        }
        }
    }
    
    private func handleSharedContent(from url: URL) {
        // Handle URL scheme from Share Extension
        if url.scheme == "enclosure" && url.host == "share" {
            print("📤 [MainActivityOld] ✅ Received share URL scheme: \(url)")
            print("📤 [MainActivityOld] Share Extension should have saved data by now")
            // File container is fast - check immediately
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                print("📤 [MainActivityOld] ⏰ Delay complete - checking for shared content now...")
                checkForSharedContent()
            }
        } else {
            print("📤 [MainActivityOld] ⚠️ URL scheme does not match: scheme=\(url.scheme ?? "nil"), host=\(url.host ?? "nil")")
        }
    }
    
    private func parseContactFromVCard(url: URL) -> SharedContent.ContactInfo? {
        guard let data = try? Data(contentsOf: url) else {
            print("🚫 [MainActivityOld] Failed to read vCard file")
            return nil
        }
        
        guard let vCardString = String(data: data, encoding: .utf8) else {
            print("🚫 [MainActivityOld] Failed to decode vCard data")
            return nil
        }
        
        var name = ""
        var phone = ""
        var email = ""
        
        let lines = vCardString.components(separatedBy: .newlines)
        for line in lines {
            if line.hasPrefix("FN:") {
                name = String(line.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if line.hasPrefix("TEL") {
                let components = line.components(separatedBy: ":")
                if components.count > 1 {
                    phone = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } else if line.hasPrefix("EMAIL") {
                let components = line.components(separatedBy: ":")
                if components.count > 1 {
                    email = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        guard !name.isEmpty else {
            print("🚫 [MainActivityOld] Contact name is empty")
            return nil
        }
        
        return SharedContent.ContactInfo(name: name, phoneNumber: phone, email: email.isEmpty ? nil : email)
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

// MARK: - Android ValueAnimator: single progress update per frame for stable expand/collapse
private struct ValueAnimatorHeightDriver: View {
    @Binding var startTime: Date?
    @Binding var progress: Double?
    let from: CGFloat
    let to: CGFloat
    let duration: TimeInterval
    @Binding var height: CGFloat
    let fromOpacity: Double
    let toOpacity: Double
    @Binding var opacity: Double
    var onComplete: (() -> Void)?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/60)) { context in
            Color.clear
                .frame(width: 0, height: 0)
                .onChange(of: context.date) { newDate in
                    guard let start = startTime else { return }
                    let elapsed = newDate.timeIntervalSince(start)
                    let t = min(1, elapsed / duration)
                    let prog = (cos((t + 1) * .pi) + 1) / 2
                    progress = prog
                    if t >= 1 {
                        progress = nil
                        height = to
                        opacity = toOpacity
                        startTime = nil
                        onComplete?()
                    }
                }
        }
        .allowsHitTesting(false)
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
