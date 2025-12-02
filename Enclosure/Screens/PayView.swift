import SwiftUI

struct PayView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var isPressed = false
    @State private var isChecked = true
    @State private var themeColorHex: String = Constant.themeColor
    
    
    // Computed property for theme color matching iOS patterns
    private var themeColor: Color {
        Color(hex: themeColorHex.isEmpty ? Constant.themeColor : themeColorHex)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("BackgroundColor")
                    .ignoresSafeArea()
                
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
                                    .background(Color("buttonColorTheme"))
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
        }
        .navigationBarHidden(true)
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
}


#Preview {
    PayView()
}
