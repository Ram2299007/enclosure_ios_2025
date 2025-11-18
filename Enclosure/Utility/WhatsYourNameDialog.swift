import SwiftUI
import UIKit

struct WhatsYourNameDialog: View {
    @Binding var isShowing: Bool
    @State private var name: String = ""
    @State private var showError: Bool = false
    @State private var isLoading: Bool = false
    @FocusState private var isNameFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var onSuccess: () -> Void
    
    var body: some View {
        Group {
            if isShowing {
                ZStack {
                    // Semi-transparent background covering full screen
                    Color.black.opacity(0.5)
                        .ignoresSafeArea(.all)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onTapGesture {
                            // Dialog is not dismissible by tapping outside (matching Android)
                        }
                    
                    // Dialog Card with shadow layer - positioned at top like alert
                    VStack(alignment: .center) {
                        ZStack {
                            // Shadow layer behind the card - stable, not affected by state changes
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.black.opacity(0.25))
                                .frame(width: 307, height: 356)
                                .offset(x: 0, y: 6)
                                .blur(radius: 12)
                                .allowsHitTesting(false) // Don't interfere with touches
                            
                            // Dialog Card container
                            VStack(alignment: .leading, spacing: 0) {
                                // Title
                                Text("What's your\nname?")
                                    .font(.custom("Inter18pt-SemiBold", size: 35))
                                    .foregroundColor(Color("TextColor"))
                                    .lineSpacing(25) // lineHeight 60dp (35sp + 25sp spacing)
                                    .padding(.leading, 14)
                                    .padding(.top, 9)
                                
                                // Subtitle
                                Text("Enter your name here")
                                    .font(.custom("Inter18pt-Regular", size: 16))
                                    .foregroundColor(Color(UIColor(red: 0.62, green: 0.65, blue: 0.73, alpha: 1.0))) // #9EA6B9
                                    .lineSpacing(8) // lineHeight 24dp (16sp + 8sp spacing)
                                    .padding(.leading, 14)
                                    .padding(.top, 2)
                                
                                // TextField
                                ZStack(alignment: .leading) {
                                    // Background and border
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(showError ? Color.red : (isNameFocused ? Color("TextColor") : Color("Gray3")), lineWidth: 1.5)
                                        .frame(height: 55)
                                    
                                    // Placeholder text (only when empty)
                                    if name.isEmpty {
                                        HStack {
                                            Text(showError ? "Enter your name here" : "Name")
                                                .font(.custom("Inter18pt-Regular", size: 16))
                                                .foregroundColor(Color("Gray3"))
                                                .padding(.leading, 29)
                                            Spacer()
                                        }
                                        .allowsHitTesting(false)
                                    }
                                    
                                    // Error icon (only when error) - using nosign for "no entry" symbol
                                    if showError {
                                        HStack {
                                            Spacer()
                                            Image(systemName: "nosign")
                                                .foregroundColor(.red)
                                                .font(.system(size: 20))
                                                .padding(.trailing, 29)
                                        }
                                        .allowsHitTesting(false)
                                    }
                                    
                                    // Actual TextField
                                    TextField("", text: $name)
                                        .font(.custom("Inter18pt-Regular", size: 16))
                                        .foregroundColor(Color("black_white_cross"))
                                        .padding(.horizontal, 29)
                                        .padding(.trailing, showError ? 50 : 29) // Extra space for error icon
                                        .focused($isNameFocused)
                                        .onChange(of: name) { _ in
                                            showError = false
                                        }
                                }
                                .frame(height: 55)
                                .padding(.horizontal, 14)
                                .padding(.top, 23)
                                
                                // Error message
                                if showError {
                                    Text("Missing name ?")
                                        .font(.custom("Inter18pt-Regular", size: 14))
                                        .foregroundColor(.red)
                                        .padding(.leading, 14)
                                        .padding(.top, 5)
                                }
                                
                                // Submit Button
                                Button(action: {
                                    if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        showError = true
                                    } else {
                                        showError = false
                                        isLoading = true
                                        submitName()
                                    }
                                }) {
                                    Text("Submit")
                                        .font(.custom("Inter18pt-SemiBold", size: 16))
                                        .foregroundColor(.white)
                                        .lineSpacing(8) // lineHeight 24dp
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 55)
                                        .background(
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(Color(UIColor(red: 0x03/255.0, green: 0x2F/255.0, blue: 0x60/255.0, alpha: 1.0))) // #032F60
                                        )
                                }
                                .padding(.horizontal, 25)
                                .padding(.top, 42)
                                .disabled(isLoading)
                                
                                if isLoading {
                                    HorizontalProgressBar()
                                        .frame(width: 40, height: 2)
                                        .padding(.top, 10)
                                }
                            }
                            .frame(width: 307, height: 356)
                            .background(Color("cardBackgroundColornew"))
                            .cornerRadius(10)
                        }
                        .drawingGroup() // Render shadow and card together for stability
                        
                        Spacer() // Push dialog to top
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 50) // Position dialog at upper area like alert box
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.all)
                .background(Color.clear) // Ensure transparent background for shadow to show
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isShowing)
                .zIndex(999) // Ensure it's on top
                .onAppear {
                    // Auto-focus TextField when dialog appears - delay to avoid affecting shadow
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isNameFocused = true
                    }
                }
            }
        }
    }
    
    private func submitName() {
        let uid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? "0"
        let fullName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let urlString = Constant.baseURL + "create_name"
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyString = "uid=\(uid)&full_name=\(fullName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        request.httpBody = bodyString.data(using: .utf8)
        
        print("📤 API: create_name")
        print("📤 Parameters: uid=\(uid), full_name=\(fullName)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    print("❌ Network Error: \(error.localizedDescription)")
                    Constant.showToast(message: "Network error. Please try again.")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid Response")
                    return
                }
                
                guard let data = data else {
                    print("❌ No data received")
                    return
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                    print("📩 Response JSON: \(json ?? [:])")
                    
                    if let errorCodeString = json?["error_code"] as? String,
                       let errorCode = Int(errorCodeString),
                       errorCode == 200 {
                        // Success - save nameSAved and full_name
                        UserDefaults.standard.set("nameSAved", forKey: "nameSAved")
                        UserDefaults.standard.set(fullName, forKey: Constant.full_name)
                        
                        print("✅ Name saved successfully")
                        isShowing = false
                        onSuccess()
                    } else {
                        let message = json?["message"] as? String ?? "Unknown error"
                        print("❌ API returned an error: \(message)")
                        Constant.showToast(message: message)
                    }
                } catch {
                    print("❌ JSON Parsing Error: \(error.localizedDescription)")
                    Constant.showToast(message: "Failed to parse response")
                }
            }
        }.resume()
    }
}

