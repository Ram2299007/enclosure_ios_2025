import SwiftUI

struct PayView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var isPressed = false
    @State private var isChecked = true
    @State private var themeColorHex: String = Constant.themeColor
    @State private var mainvectorTintColor: Color = Color(hex: "#01253B") // Dynamic background tint color (darker theme color)
    
    // Computed property for theme color matching iOS patterns
    private var themeColor: Color {
        Color(hex: themeColorHex.isEmpty ? Constant.themeColor : themeColorHex)
    }
    
    // Computed property for background tint: appThemeColor in light mode, darker tint in dark mode
    private var backgroundTintColor: Color {
        if colorScheme == .light {
            return Color("appThemeColor") // Use appThemeColor in light mode
        } else {
            return mainvectorTintColor // Use darker tint in dark mode
        }
    }
    
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
                
                // Back arrow positioned at top-left
                VStack {
                    HStack {
                        Button(action: handleBackTap) {
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
                        
                        Spacer()
                    }
                    .padding(.top, 10)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
                .zIndex(1)
                
                VStack(spacing: 0) {
                    // Main content
                    VStack(spacing: 0) {
                            // Enclosure Exclusive Features label - matching Android pnglabel
                            ZStack {
                                Image("pnglabel")
                                    .resizable()
                                    .renderingMode(.template)
                                    .foregroundColor(themeColor) // Apply theme color tint
                                    .scaledToFill()
                                    .frame(height: 50)
                                    .clipped()
                                
                                Text("Enclosure Exclusive Features")
                                    .font(.custom("Inter18pt-Medium", size: 17))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                            }
                            .frame(height: 50)
                            .padding(.top, 60)
                            .padding(.horizontal, 20)
                            
                            // Main features card - centered using ZStack
                            ZStack {
                                HStack(alignment: .top, spacing: 0) {
                                    // Features list card - 223dp width
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text("Sleep Lock")
                                            .font(.custom("Inter18pt-Medium", size: 14))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.leading, 25)
                                            .padding(.top, 23)
                                        
                                        Text("Themes")
                                            .font(.custom("Inter18pt-Medium", size: 14))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.leading, 25)
                                            .padding(.top, 16)
                                        
                                        Text("Message Limit")
                                            .font(.custom("Inter18pt-Medium", size: 14))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.leading, 25)
                                            .padding(.top, 16)
                                        
                                        Spacer()
                                    }
                                    .frame(width: 223, height: 141, alignment: .leading)
                                    .background(backgroundTintColor) // Use appThemeColor in light mode, darker tint in dark mode (like bg and mainvector)
                                    .cornerRadius(8)
                                    
                                    // Right side - Free Now and checkbox
                                    VStack {
                                        Text("Free Now")
                                            .font(.custom("Inter18pt-Medium", size: 16))
                                            .fontWeight(.semibold)
                                            .foregroundColor(Color("TextColor"))
                                            .padding(.bottom, 10)
                                        
                                        // Checkbox - interactive iOS style with black and white only
                                        Button(action: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                isChecked.toggle()
                                            }
                                        }) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(isChecked ? Color("TextColor") : Color.clear)
                                                    .frame(width: 22, height: 22)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 6)
                                                            .stroke(Color("TextColor"), lineWidth: 2)
                                                    )
                                                
                                                if isChecked {
                                                    Image(systemName: "checkmark")
                                                        .foregroundColor(colorScheme == .dark ? Color.black : Color(red: 0xF6/255, green: 0xF7/255, blue: 0xFF/255))
                                                        .font(.system(size: 12, weight: .bold))
                                                        .transition(.scale.combined(with: .opacity))
                                                }
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.leading, 14)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 141)
                                }
                                .padding(.horizontal, 20)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.clear)
                            
                            // Bottom text
                            Text("Make this app more valuable & premium*")
                                .font(.custom("Inter18pt-Medium", size: 15))
                                .foregroundColor(Color("TextColor"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 30)
                                .padding(.horizontal, 20)
                            
                            
                            Spacer(minLength: 80)
                        }
                }
            }
        .navigationBarBackButtonHidden(true)
        .background(NavigationGestureEnabler())
        .onAppear {
            themeColorHex = Constant.themeColor // Initialize theme color
            mainvectorTintColor = getMainvectorTintColor(for: Constant.themeColor) // Initialize tint color
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ThemeColorUpdated"))) { _ in
            themeColorHex = Constant.themeColor // Update theme color when it changes
            mainvectorTintColor = getMainvectorTintColor(for: Constant.themeColor) // Update tint color when theme changes
        }
    }
    
    private func handleBackTap() {
        withAnimation {
            isPressed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            dismiss()
            isPressed = false
        }
    }
    
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
}


#Preview {
    PayView()
}
