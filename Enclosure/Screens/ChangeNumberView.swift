import SwiftUI

struct ChangeNumberView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isPressed = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var themeColorHex: String = UserDefaults.standard.string(forKey: Constant.ThemeColorKey) ?? "#00A3E9"
    
    var body: some View {
        ZStack {
            Color("background_color")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Toolbar
                androidToolbar
                
                // Content - matching Android XML layout
                ScrollView {
                    VStack(spacing: 0) {
                        // SIM Card Transfer Animation (matching Android layout with theme color)
                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                // SIM 1 (Old Number) - using theme color
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(hex: themeColorHex.isEmpty ? "#00A3E9" : themeColorHex))
                                        .frame(width: 32, height: 43)
                                    
                                    // SIM card cutout
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color("background_color"))
                                        .frame(width: 28, height: 39)
                                        .offset(y: 2)
                                }
                                
                                // Connecting dots - using theme color
                                HStack(spacing: 2.5) {
                                    ForEach(0..<3, id: \.self) { _ in
                                        Circle()
                                            .fill(Color(hex: themeColorHex.isEmpty ? "#00A3E9" : themeColorHex).opacity(0.8))
                                            .frame(width: 4, height: 4)
                                    }
                                }
                                .padding(.horizontal, 2.5)
                                
                                // SIM 2 (New Number) - using theme color
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(hex: themeColorHex.isEmpty ? "#00A3E9" : themeColorHex))
                                        .frame(width: 32, height: 43)
                                    
                                    // SIM card cutout
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color("background_color"))
                                        .frame(width: 28, height: 39)
                                        .offset(y: 2)
                                }
                            }
                        }
                        .padding(.top, 25)
                        
                        // Question Text (matching Android XML)
                        VStack(alignment: .leading, spacing: 30) {
                            Text("Are you changing your phone number ?")
                                .font(.custom("Inter18pt-SemiBold", size: 16))
                                .foregroundColor(Color("TextColor"))
                                .fontWeight(.semibold)
                                .lineSpacing(5) // lineHeight="21dp"
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.top, 53)
                            
                            Text("All your current data frome here-\nwill transfer on your new number.")
                                .font(.custom("Inter18pt-Medium", size: 16))
                                .foregroundColor(Color("TextColor"))
                                .fontWeight(.medium)
                                .lineSpacing(2) // lineHeight="18dp"
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                            
                            Text("Make sure, your new number is active.")
                                .font(.custom("Inter18pt-Medium", size: 16))
                                .foregroundColor(Color("TextColor"))
                                .fontWeight(.medium)
                                .lineSpacing(2) // lineHeight="18dp"
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
                
                // Bottom Next Button (matching Android layout)
                VStack {
                    Spacer()
                    
                    Button(action: handleNext) {
                        Text("Next")
                            .font(.custom("Inter18pt-Medium", size: 16))
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                            .lineSpacing(8) // lineHeight="24dp"
                    }
                    .frame(width: 157, height: 49)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: themeColorHex.isEmpty ? "#00A3E9" : themeColorHex)) // Using theme color
                    )
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationBarHidden(true)
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") {
                if alertTitle == "Success" {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Toolbar
    private var androidToolbar: some View {
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

            Text("Change number")
                .font(.custom("Inter18pt-Medium", size: 16))
                .foregroundColor(Color("TextColor"))
                .fontWeight(.medium)
                .lineSpacing(24)
                .padding(.leading, 6)
            Spacer()
        }
        .padding(.top, 0)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
    
    // MARK: - Functions
    private func handleBackTap() {
        withAnimation {
            isPressed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            dismiss()
            isPressed = false
        }
    }
    
    private func handleNext() {
        // Navigate to the actual number change form
        showAlert(title: "Change Number", message: "This will navigate to the number change form where you can enter your current and new phone numbers.")
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

struct ChangeNumberView_Previews: PreviewProvider {
    static var previews: some View {
        ChangeNumberView()
    }
}
