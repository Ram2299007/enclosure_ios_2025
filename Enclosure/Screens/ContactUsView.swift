import SwiftUI

struct ContactUsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isPressed = false
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var message: String = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    
    @FocusState private var isNameFocused: Bool
    @FocusState private var isEmailFocused: Bool
    @FocusState private var isMessageFocused: Bool
    
    var body: some View {
        ZStack {
            // Background color matching the design
            Color("background_color")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Android-style toolbar
                androidToolbar
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // "Get in Touch!" title
                        HStack {
                            Text("Get in Touch!")
                                .font(.custom("Inter18pt-SemiBold", size: 24))
                                .foregroundColor(Color("TextColor"))
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Form Fields
                        VStack(spacing: 20) {
                            // Your Name Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Your Name")
                                    .font(.custom("Inter18pt-Medium", size: 16))
                                    .foregroundColor(Color("TextColor"))
                                
                                TextField("", text: $name)
                                    .padding(.horizontal, 16)
                                    .frame(height: 56)
                                    .background(Color("background_color"))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color("TextColor").opacity(0.2), lineWidth: 1)
                                    )
                                    .font(.custom("Inter18pt-Regular", size: 16))
                                    .foregroundColor(Color("TextColor"))
                                    .focused($isNameFocused)
                            }
                            
                            // Email Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.custom("Inter18pt-Medium", size: 16))
                                    .foregroundColor(Color("TextColor"))
                                
                                TextField("", text: $email)
                                    .padding(.horizontal, 16)
                                    .frame(height: 56)
                                    .background(Color("background_color"))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color("TextColor").opacity(0.2), lineWidth: 1)
                                    )
                                    .font(.custom("Inter18pt-Regular", size: 16))
                                    .foregroundColor(Color("TextColor"))
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .focused($isEmailFocused)
                            }
                            
                            // Your message Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Your message")
                                    .font(.custom("Inter18pt-Medium", size: 16))
                                    .foregroundColor(Color("TextColor"))
                                
                                AutoResizingMessageEditor(
                                    text: $message,
                                    placeholder: "",
                                    maxCharacters: 500
                                )
                                .focused($isMessageFocused)
                            }
                            
                            // Send message Button
                            Button(action: handleSendMessage) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Text("Send message")
                                            .font(.custom("Inter18pt-SemiBold", size: 16))
                                            .foregroundColor(.white)
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(hex: Constant.themeColor)) // Use dynamic theme color
                                )
                            }
                            .disabled(isLoading || name.isEmpty || email.isEmpty || message.isEmpty)
                            .opacity((name.isEmpty || email.isEmpty || message.isEmpty) ? 0.6 : 1.0)
                            .padding(.top, 10)
                        }
                        .padding(.horizontal, 20)
                        
                        // Bottom spacing
                        Spacer(minLength: 50)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onTapGesture {
            // Dismiss keyboard when tapping outside
            hideKeyboard()
        }
    }
    
    // MARK: - Android-style Toolbar (same as editmyProfile.swift)
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

            Text("Contact us")
                .font(.custom("Inter18pt-Medium", size: 16))
                .foregroundColor(Color("TextColor"))
                .fontWeight(.medium)
                .lineSpacing(24) // Equivalent to lineHeight
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
    
    private func handleSendMessage() {
        // Validate inputs
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showAlert(title: "Error", message: "Please enter your name")
            isNameFocused = true
            return
        }
        
        guard isValidEmail(email) else {
            showAlert(title: "Error", message: "Please enter a valid email address")
            isEmailFocused = true
            return
        }
        
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showAlert(title: "Error", message: "Please enter your message")
            isMessageFocused = true
            return
        }
        
        // Start loading
        isLoading = true
        hideKeyboard()
        
        // Simulate API call (replace with actual API implementation)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isLoading = false
            
            // Success - clear form and show success message
            name = ""
            email = ""
            message = ""
            
            showAlert(title: "Success", message: "Your message has been sent successfully! We'll get back to you soon.")
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
    
    private func hideKeyboard() {
        isNameFocused = false
        isEmailFocused = false
        isMessageFocused = false
    }
}

// Auto-resizing TextEditor for message input
struct AutoResizingMessageEditor: View {
    @Binding var text: String
    let placeholder: String
    let maxCharacters: Int
    @State private var textEditorHeight: CGFloat = 120
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("background_color"))
                .frame(height: max(120, textEditorHeight + 32))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color("TextColor").opacity(0.2), lineWidth: 1)
                )
            
            // TextEditor
            TextEditor(text: $text)
                .padding(16)
                .padding(.bottom, 16)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .font(.custom("Inter18pt-Regular", size: 16))
                .lineSpacing(4)
                .foregroundColor(Color("TextColor"))
                .frame(height: max(120, textEditorHeight + 32))
                .onChange(of: text) { newValue in
                    // Limit characters
                    if text.count > maxCharacters {
                        text = String(text.prefix(maxCharacters))
                    }
                    
                    // Calculate height based on content
                    DispatchQueue.main.async {
                        let font = UIFont(name: "Inter18pt-Regular", size: 16) ?? UIFont.systemFont(ofSize: 16)
                        let attributes = [NSAttributedString.Key.font: font]
                        let size = (text as NSString).boundingRect(
                            with: CGSize(width: UIScreen.main.bounds.width - 72, height: .greatestFiniteMagnitude),
                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                            attributes: attributes,
                            context: nil
                        )
                        textEditorHeight = max(88, size.height)
                    }
                }
            
            // Placeholder text
            if text.isEmpty {
                Text(placeholder)
                    .font(.custom("Inter18pt-Regular", size: 16))
                    .foregroundColor(Color("TextColor").opacity(0.5))
                    .padding(20)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            // Initial height calculation
            if !text.isEmpty {
                let font = UIFont(name: "Inter18pt-Regular", size: 16) ?? UIFont.systemFont(ofSize: 16)
                let attributes = [NSAttributedString.Key.font: font]
                let size = (text as NSString).boundingRect(
                    with: CGSize(width: UIScreen.main.bounds.width - 72, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                )
                textEditorHeight = max(88, size.height)
            }
        }
    }
}

struct ContactUsView_Previews: PreviewProvider {
    static var previews: some View {
        ContactUsView()
    }
}
