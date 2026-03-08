import SwiftUI

struct AccountView: View {
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var themeColorHex: String = Constant.themeColor
    
    // Navigation states
    @State private var navigateToChangeNumber = false
    
    // Helper function to hide keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    var body: some View {
        ZStack {
            // Background color matching Android design
            Color("background_color")
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    hideKeyboard()
                }
            
            VStack(spacing: 0) {
                // Content - matching Android XML layout
                ScrollView {
                    VStack(spacing: 0) {
                        // SIM Card Transfer Animation (matching Android layout with theme color)
                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                // SIM 1 (Old Number) - using theme color
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(hex: themeColorHex.isEmpty ? Constant.themeColor : themeColorHex))
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
                                            .fill(Color(hex: themeColorHex.isEmpty ? Constant.themeColor : themeColorHex).opacity(0.8))
                                            .frame(width: 4, height: 4)
                                    }
                                }
                                .padding(.horizontal, 2.5)
                                
                                // SIM 2 (New Number) - using theme color
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(hex: themeColorHex.isEmpty ? Constant.themeColor : themeColorHex))
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
                            .fill(Color(hex: themeColorHex.isEmpty ? Constant.themeColor : themeColorHex)) // Using theme color
                    )
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .background(NavigationGestureEnabler())
        .onAppear {
            loadThemeColor()
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .navigationDestination(isPresented: $navigateToChangeNumber) {
            ChangeNumberView()
        }
    }
    
    // MARK: - Functions
    private func handleNext() {
        // Navigate to change number screen
        navigateToChangeNumber = true
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
    
    private func loadThemeColor() {
        if let savedThemeColor = UserDefaults.standard.string(forKey: Constant.ThemeColorKey), !savedThemeColor.isEmpty {
            themeColorHex = savedThemeColor
        }
    }
}


struct AccountView_Previews: PreviewProvider {
    static var previews: some View {
        AccountView()
    }
}
