import SwiftUI
import UIKit

struct DummyChattingScreen: View {
    @State private var isPressed = false
    @Environment(\.presentationMode) var presentationMode
    @State private var showSearch: Bool = false
    @State private var searchText: String = ""
    @State private var messageText: String = ""
    @FocusState private var isSearchFieldFocused: Bool
    @FocusState private var isMessageFieldFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    // Computed property to get current time in "11:00 am" format
    private var currentTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: Date())
    }
    
    // Get theme color and logo based on theme
    private var themeConfig: (color: Color, logo: String) {
        let themeColor = Constant.themeColor
        switch themeColor {
        case "#ff0080":
            return (Color(hex: themeColor), "pinklogopng")
        case "#00A3E9":
            return (Color(hex: themeColor), "ec_modern")
        case "#7adf2a":
            return (Color(hex: themeColor), "popatilogopng")
        case "#ec0001":
            return (Color(hex: themeColor), "redlogopng")
        case "#16f3ff":
            return (Color(hex: themeColor), "bluelogopng")
        case "#FF8A00":
            return (Color(hex: themeColor), "orangelogopng")
        case "#7F7F7F":
            return (Color(hex: themeColor), "graylogopng")
        case "#D9B845":
            return (Color(hex: themeColor), "yellowlogopng")
        case "#346667":
            return (Color(hex: themeColor), "greenlogoppng")
        case "#9846D9":
            return (Color(hex: themeColor), "voiletlogopng")
        case "#A81010":
            return (Color(hex: themeColor), "red2logopng")
        default:
            return (Color(hex: themeColor), "red2logopng")
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Messages List
            messagesListView
            
            // Bottom Input Area
            bottomInputView
        }
        .background(Color("BackgroundColor"))
        .navigationBarHidden(true)
        .onAppear {
            // Set notification key when screen appears
            UserDefaults.standard.set("notiKey", forKey: "notiKey")
        }
    }
    
    private var messagesListView: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                // Welcome message with progress bar
                welcomeMessageWithProgressView
            }
            .padding(.horizontal, 8)
            .padding(.top, 8) // Add top margin like original MessageBubbleView
        }
    }
    
    private var welcomeMessageWithProgressView: some View {
        HStack(spacing: 0) {
            // Receiver message positioned at top like original MessageBubbleView
            VStack(alignment: .leading, spacing: 0) {
                // Message content using exact MessageBubbleView text design
                HStack {
                    Group {
                        // Text message styling matching MessageBubbleView receiver text
                        Text("Welcome to Enclosure Messaging World !\n\nEnclosure is a creation by founder who has written most number of Best Quotes in world for billion people. \n\nYou will be surprised to know. Find it on @powerfulnext")
                            .font(.custom("Inter18pt-Regular", size: 15)) // textSize="15sp" (matching Android)
                            .fontWeight(.light) // textFontWeight="200" (matching Android)
                            .foregroundColor(Color("TextColor"))
                            .lineSpacing(7) // lineHeight="22dp" (22 - 15 = 7dp spacing)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true) // allow wrapping
                            .padding(.horizontal, 12) // layout_marginHorizontal="12dp"
                            .padding(.top, 5) // paddingTop="5dp"
                            .padding(.bottom, 6) // paddingBottom="6dp"
                            .background(
                                getReceiverGlassBackground(cornerRadius: 20) // matching Android corner radius
                            )
                    }
                    Spacer(minLength: 0) // Don't expand beyond content
                }
                .frame(maxWidth: 250) // maxWidth constraint - wrap content up to max
                
                // Time row with progress indicator (matching MessageBubbleView timeRowView)
                timeRowView
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // Time row view - matching MessageBubbleView timeRowView
    private var timeRowView: some View {
        // Time row with progress indicator beside time (matching Android placement)
        HStack(spacing: 6) {
            Text(currentTime)
                .font(.custom("Inter18pt-Regular", size: 10))
                .foregroundColor(Color("gray3"))
            progressIndicatorView(isSender: false)
        }
        .padding(.top, 5)
        .padding(.bottom, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // Progress indicator view - matching MessageBubbleView progressIndicatorView
    private func progressIndicatorView(isSender: Bool) -> some View {
        let themeColor = Color(hex: Constant.themeColor)
        // Both sender and receiver use themeColor for progress indicator line (matching ThemeColorKey)
        let indicatorColor = themeColor
        let trackColor = themeColor
        let cornerRadius: CGFloat = isSender ? 20 : 10
        
        // Show static indicator for sent messages (matching Android default behavior)
        // Using the same as original MessageBubbleView for non-pending messages
        return AnyView(
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(trackColor)
                    .frame(width: 20, height: 1)
                Capsule()
                    .fill(indicatorColor)
                    .frame(width: 20, height: 1)
            }
            .frame(width: 20, height: 1)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        )
    }
    
    private var welcomeMessageView: some View {
        HStack(spacing: 0) {
            // Receiver message positioned at top like original MessageBubbleView
            VStack(alignment: .leading, spacing: 0) {
                // Message content using exact MessageBubbleView text design (no profile name above)
                HStack {
                    Group {
                        // Text message styling matching MessageBubbleView receiver text
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Welcome to Enclosure Messaging World !\n\nEnclosure is a creation by founder who has written most number of Best Quotes in world for billion people. \n\nYou will be surprised to know. Find it on @powerfulnext")
                                .font(.custom("Inter18pt-Regular", size: 15)) // textSize="15sp" (matching Android)
                                .fontWeight(.light) // textFontWeight="200" (matching Android)
                                .foregroundColor(Color("TextColor"))
                                .lineSpacing(7) // lineHeight="22dp" (22 - 15 = 7dp spacing)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true) // allow wrapping
                                .padding(.horizontal, 12) // layout_marginHorizontal="12dp"
                                .padding(.top, 5) // paddingTop="5dp"
                                .padding(.bottom, 6) // paddingBottom="6dp"
                        }
                        .background(
                            getReceiverGlassBackground(cornerRadius: 20) // matching Android corner radius
                        )
                    }
                    Spacer(minLength: 0) // Don't expand beyond content
                }
                .frame(maxWidth: 250) // maxWidth constraint - wrap content up to max
                
                // Time stamp (matching MessageBubbleView timeRowView)
                HStack {
                    Text(currentTime)
                        .font(.custom("Inter18pt-Regular", size: 10))
                        .foregroundColor(Color("gray3"))
                    
                    Spacer()
                }
                .padding(.top, 4)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // Exact glass background from ChattingScreen.swift
    @ViewBuilder
    private func getReceiverGlassBackground(cornerRadius: CGFloat) -> some View {
        // Linear gradient at 135 degrees with glass colors
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        getReceiverGlassBgStart(),
                        getReceiverGlassBgCenter(),
                        getReceiverGlassBgEnd()
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                // Subtle border for glass effect (0.5dp, matching Android stroke)
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(getReceiverGlassBorder(), lineWidth: 0.5)
            )
    }
    
    // Get glass background start color (matching Android glass_bg_start)
    private func getReceiverGlassBgStart() -> Color {
        // Light mode: #80FFFFFF (50% opacity white)
        // Dark mode: #4D1B1B1B (semi-transparent dark)
        return colorScheme == .dark ? Color(hex: "#4D1B1B1B") : Color(hex: "#80FFFFFF")
    }
    
    // Get glass background center color (matching Android glass_bg_center)
    private func getReceiverGlassBgCenter() -> Color {
        // Light mode: #66FFFFFF (40% opacity white)
        // Dark mode: #331B1B1B (more transparent)
        return colorScheme == .dark ? Color(hex: "#331B1B1B") : Color(hex: "#66FFFFFF")
    }
    
    // Get glass background end color (matching Android glass_bg_end)
    private func getReceiverGlassBgEnd() -> Color {
        // Light mode: #4DFFFFFF (30% opacity white)
        // Dark mode: #1A1B1B1B (even more transparent)
        return colorScheme == .dark ? Color(hex: "#1A1B1B1B") : Color(hex: "#4DFFFFFF")
    }
    
    // Get glass border color (matching Android glass_border)
    private func getReceiverGlassBorder() -> Color {
        // Light mode: #80000000 (50% opacity black)
        // Dark mode: #40FFFFFF (25% opacity white) - matching Android values-night/colors.xml
        return colorScheme == .dark ? Color(hex: "#40FFFFFF") : Color(hex: "#80000000")
    }
    
    private var headerView: some View {
        VStack(spacing: 0) {
            // Main header card (always show normal header)
                headerCardView
        }
    }
    
    private var headerCardView: some View {
        VStack(spacing: 0) {
            // Header card matching Android header1Cardview
            HStack(spacing: 0) {
                // Back button
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
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
                            .foregroundColor(Color("TextColor"))
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
                .padding(.leading, 10)
                .padding(.trailing, 12)  // Add more space before profile
                
                // Search field (full width when active - matching Android binding.searchlyt.setVisibility(View.VISIBLE))
                if showSearch {
                    HStack {
                        Rectangle()
                            .fill(Color(hex: Constant.themeColor)) // Use original theme color in both light and dark mode
                            .frame(width: 1, height: 19.24)
                            .padding(.leading, 13)
                        
                        TextField("Search...", text: $searchText)
                            .font(.custom("Inter18pt-Medium", size: 16))
                            .foregroundColor(Color("TextColor"))
                            .padding(.leading, 13)
                            .textFieldStyle(PlainTextFieldStyle())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .focused($isSearchFieldFocused)
                            .onAppear {
                                // Focus search field (matching Android binding.searchEt.requestFocus())
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isSearchFieldFocused = true
                                }
                            }
                            .onChange(of: searchText) { newValue in
                                // Handle search text changes (matching Android TextWatcher)
                                print("Search text changed: \(newValue)")
                            }
                    }
                    .padding(.trailing, 10)
                } else {
                    // Profile section (hidden when search is active - matching Android binding.name.setVisibility(View.GONE))
                    HStack(spacing: 8) {
                        // Profile image using ec_modern icon like chatView
                        Image("ec_modern") // Using ec_modern icon like chatView
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32) // Reduced size on both sides
                        .padding(.leading, 1)
                        .padding(.trailing, 16)
                        
                        // Name
                        Text("@Enclosureforworld")
                            .font(.custom("Inter18pt-Medium", size: 16))
                            .foregroundColor(Color("TextColor"))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Menu button (three dots) - hidden when search is active (matching Android binding.menu2.setVisibility(View.GONE))
                    Button(action: {
                        // Do nothing - don't show menu overlay
                        print("Menu button tapped - no action")
                    }) {
                        VStack(spacing: 3) {
                            Circle()
                                .fill(Color("menuPointColor"))
                                .frame(width: 4, height: 4)
                            Circle()
                                .fill(Color(hex: Constant.themeColor))
                                .frame(width: 4, height: 4)
                            Circle()
                                .fill(Color("gray3"))
                                .frame(width: 4, height: 4)
                        }
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color("circlebtnhover").opacity(0.1))
                        )
                    }
                    .padding(.trailing, 10)
                }
            }
            .frame(height: 50)
            .background(Color("BackgroundColor"))
        }
    }
    
    private var bottomInputView: some View {
        VStack(spacing: 0) {
            // Message input container (messageboxContainer)
            messageInputContainer
        }
        .background(Color("edittextBg"))
    }
    
    private var messageInputContainer: some View {
        // Outer vertical container (messageboxContainer) - orientation="vertical"
        VStack(spacing: 0) {
            // Inner horizontal container - padding="2dp"
            HStack(alignment: .bottom, spacing: 0) {
                AnyView(messageInputStack)
                    .frame(maxWidth: .infinity) // layout_weight="1"
                    .contentShape(Rectangle()) // Ensure clear hit testing boundary
                
                // Send button (sendGrpLyt) - layout_gravity="center_vertical|bottom"
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 0) {
                        Button(action: {
                            // Handle send button click
                            print("Send button tapped")
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: Constant.themeColor)) // theme color like Android
                                    .frame(width: 50, height: 50)
                                
                                // Show mic icon when text is empty, send icon when text is present
                                if messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Image("mikesvg")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 22, height: 22)
                                        .foregroundColor(.white)
                                        .padding(.top, 4)
                                        .padding(.bottom, 8)
                                } else {
                                    // Send icon (keyboard double arrow right) - same as Android
                                    Image("baseline_keyboard_double_arrow_right_24")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 26, height: 26)
                                        .foregroundColor(.white)
                                        .padding(.top, 4)
                                        .padding(.bottom, 8)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 5)
            }
            .padding(2) // Inner horizontal container padding="2dp"
            .contentShape(Rectangle()) // Clear boundary for message input area to prevent gesture interference
            .background(Color("edittextBg")) // Ensure solid background to prevent visual overlap
        }
    }
    
    private var messageInputStack: some View {
        VStack(spacing: 0) {
            messageInputRow
        }
    }
    
    private var messageInputRow: some View {
        // Main input layout (editLyt) - marginStart="2dp" marginEnd="2dp"
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                // Attach button (gallary) - marginStart="5dp"
                Button(action: {
                    // Handle attachment button click
                    print("Attachment button tapped")
                }) {
                    ZStack {
                        Circle()
                            .fill(Color("chattingMessageBox"))
                            .frame(width: 40, height: 40)
                        
                        Image("attachsvg")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundColor(Color("chtbtncolor"))
                    }
                }
                .padding(.leading, 5)
                
                // Message input field container - layout_weight="1"
                VStack(alignment: .leading, spacing: 0) {
                    TextField("Message on Ec", text: $messageText, axis: .vertical)
                        .font(.custom("Inter18pt-Regular", size: 16))
                        .foregroundColor(Color("black_white_cross"))
                        .lineLimit(1...4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 0)
                        .padding(.trailing, 20)
                        .padding(.top, 5)
                        .padding(.bottom, 5)
                        .background(Color.clear)
                        .focused($isMessageFieldFocused)
                        .onChange(of: messageText) { newValue in
                            // Handle message text changes
                            print("Message text changed: \(newValue)")
                        }
                }
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Emoji button (emoji) - marginEnd="5dp"
                Button(action: {
                    // Handle emoji button click
                    print("Emoji button tapped")
                }) {
                    ZStack {
                        Circle()
                            .fill(Color("chattingMessageBox"))
                            .frame(width: 40, height: 40)
                        
                        Image("emojisvg")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                    }
                }
                .padding(.trailing, 5)
            }
            .frame(minHeight: 44, alignment: .center) // Allow wrap_content height
            .padding(.horizontal, 7) // Inner padding matching reply layout inner margin="7dp"
        }
        .padding(.horizontal, 2) // Outer margin matching reply layout marginStart/End="2dp" for width alignment
        .background(
            // Use native uneven corners to avoid UIBezierPath issues
            UnevenRoundedRectangle(
                cornerRadii: .init(
                    topLeading: 20,
                    bottomLeading: 20,
                    bottomTrailing: 20,
                    topTrailing: 20
                )
            )
            .fill(Color("message_box_bg"))
        )
        .zIndex(1) // Ensure TextField area has higher z-index than gallery picker
    }
}

// Helper ContainerCardView component
struct ContainerCardView<Content: View>: View {
    let backgroundColor: Color
    let content: Content
    
    init(backgroundColor: Color, @ViewBuilder content: () -> Content) {
        self.backgroundColor = backgroundColor
        self.content = content()
    }
    
    var body: some View {
        content
            .background(backgroundColor)
            .cornerRadius(0)
    }
}

// Extension for text font weight
extension View {
    func textFontWeight(_ weight: Font.Weight) -> some View {
        self.fontWeight(weight)
    }
}

struct DummyChattingScreen_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DummyChattingScreen()
        }
    }
}
