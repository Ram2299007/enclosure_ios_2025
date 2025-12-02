import SwiftUI

struct ChangeNumberView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isPressed = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var themeColorHex: String = Constant.themeColor
    
    // Phone number input states
    @State private var oldNumber = ""
    @State private var newNumber = ""
    @State private var countryCode = "91"
    
    // Focus states
    @FocusState private var isOldNumberFocused: Bool
    @FocusState private var isNewNumberFocused: Bool
    @FocusState private var isCountryCodeFocused: Bool
    
    // Navigation state
    @State private var navigateToManageAccount = false
    
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
                        // Old Phone Number Section
                        VStack(alignment: .leading, spacing: 0) {
                            // "Enter your old phone number" label
                            HStack {
                                Text("Enter your old phone number")
                                    .font(.custom("Inter18pt-SemiBold", size: 16))
                                    .foregroundColor(Color("TextColor"))
                                    .fontWeight(.semibold)
                                    .lineSpacing(5) // lineHeight="21dp"
                                Spacer()
                            }
                            .padding(.horizontal, 15)
                            .padding(.top, 39)
                            
                            // Old number input field
                            HStack(spacing: 0) {
                                // Country code section (+91)
                                VStack(spacing: 0) {
                                    HStack(spacing: 0) {
                                        Text("+")
                                            .font(.custom("Inter18pt-SemiBold", size: 15))
                                            .foregroundColor(Color(hex: "#9EA6B9"))
                                            .fontWeight(.semibold)
                                        
                                        Text("91")
                                            .font(.custom("Inter18pt-SemiBold", size: 15))
                                            .foregroundColor(Color("TextColor"))
                                            .fontWeight(.semibold)
                                            .padding(.leading, 10)
                                    }
                                    .frame(width: 50, alignment: .leading)
                                    
                                    // Underline for country code
                                    Rectangle()
                                        .fill(Color(hex: "#9EA6B9"))
                                        .frame(height: 1)
                                        .padding(.top, 4.5)
                                }
                                
                                // Phone number input
                                VStack(spacing: 0) {
                                    TextField("Phone Number", text: $oldNumber)
                                        .font(.custom("Inter18pt-Medium", size: 15))
                                        .foregroundColor(Color(hex: "#9EA6B9")) // Grayed out since it's disabled
                                        .fontWeight(.medium)
                                        .keyboardType(.phonePad)
                                        .disabled(true) // Matching Android enabled="false"
                                        .background(Color.clear)
                                        .focused($isOldNumberFocused)
                                    
                                    // Underline for phone number
                                    Rectangle()
                                        .fill(Color(hex: "#9EA6B9"))
                                        .frame(height: 1)
                                        .padding(.top, 4.5)
                                }
                                .padding(.leading, 27)
                            }
                            .padding(.horizontal, 15)
                            .padding(.top, 18)
                        }
                        
                        // New Phone Number Section
                        VStack(alignment: .leading, spacing: 0) {
                            // "Enter your new phone number" label
                            HStack {
                                Text("Enter your new phone number: to begin Enclosure")
                                    .font(.custom("Inter18pt-SemiBold", size: 16))
                                    .foregroundColor(Color("TextColor"))
                                    .fontWeight(.semibold)
                                    .lineSpacing(5) // lineHeight="21dp"
                                Spacer()
                            }
                            .padding(.horizontal, 15)
                            .padding(.top, 39)
                            
                            // New number input field
                            HStack(spacing: 0) {
                                // Country code section (+91)
                                VStack(spacing: 0) {
                                    HStack(spacing: 0) {
                                        Text("+")
                                            .font(.custom("Inter18pt-SemiBold", size: 15))
                                            .foregroundColor(Color(hex: "#9EA6B9"))
                                            .fontWeight(.semibold)
                                        
                                        TextField("91", text: $countryCode)
                                            .font(.custom("Inter18pt-SemiBold", size: 15))
                                            .foregroundColor(Color("TextColor"))
                                            .fontWeight(.semibold)
                                            .keyboardType(.phonePad)
                                            .frame(minWidth: 30)
                                            .background(Color.clear)
                                            .focused($isCountryCodeFocused)
                                            .padding(.leading, 10)
                                    }
                                    .frame(width: 50, alignment: .leading)
                                    
                                    // Underline for country code
                                    Rectangle()
                                        .fill(Color(hex: "#9EA6B9"))
                                        .frame(height: 1)
                                        .padding(.top, 4.5)
                                }
                                
                                // Phone number input
                                VStack(spacing: 0) {
                                    TextField("Phone Number", text: $newNumber)
                                        .font(.custom("Inter18pt-Medium", size: 15))
                                        .foregroundColor(Color("TextColor"))
                                        .fontWeight(.medium)
                                        .keyboardType(.phonePad)
                                        .background(Color.clear)
                                        .focused($isNewNumberFocused)
                                    
                                    // Underline for phone number
                                    Rectangle()
                                        .fill(Color(hex: "#9EA6B9"))
                                        .frame(height: 1)
                                        .padding(.top, 4.5)
                                }
                                .padding(.leading, 27)
                            }
                            .padding(.horizontal, 15)
                            .padding(.top, 18)
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
        .navigationBarHidden(true)
        .onAppear {
            loadThemeColor()
            loadCurrentPhoneNumber()
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") {
                if alertTitle == "Success" {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
        .navigationDestination(isPresented: $navigateToManageAccount) {
            ManageAccountView(newPhoneNumber: "+\(countryCode)\(newNumber)")
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

            Text("Change Number")
                .font(.custom("Inter18pt-Medium", size: 16))
                .foregroundColor(Color("TextColor"))
                .fontWeight(.medium)
                .lineSpacing(24)
                .padding(.leading, 15)
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
        // Validate form - matching Android validation
        guard !oldNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showAlert(title: "Error", message: "Missing old phone ?")
            return
        }
        
        guard !countryCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showAlert(title: "Error", message: "Missing country code ?")
            return
        }
        
        guard !newNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showAlert(title: "Error", message: "Missing new phone ?")
            return
        }
        
        guard newNumber.count >= 10 else {
            showAlert(title: "Error", message: "Please enter a valid phone number")
            return
        }
        
        // Navigate to ManageAccountView (matching Android navigation to deleteMyAccount)
        navigateToManageAccount = true
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
    
    private func loadCurrentPhoneNumber() {
        // Load current user's phone number from UserDefaults using the correct key
        if let currentNumber = UserDefaults.standard.string(forKey: Constant.PHONE_NUMBERKEY) {
            oldNumber = currentNumber
            print("📱 Loaded current phone number: \(currentNumber)")
        } else {
            // No current number found
            oldNumber = ""
            print("⚠️ No current phone number found in UserDefaults")
        }
    }
}

struct ChangeNumberView_Previews: PreviewProvider {
    static var previews: some View {
        ChangeNumberView()
    }
}
