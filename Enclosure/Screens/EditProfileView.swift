import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    
    // Profile fields
    @State private var name = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var bio = ""
    @State private var profileImage: UIImage?
    @State private var showImagePicker = false
    
    // Original values for comparison
    @State private var originalName = ""
    @State private var originalEmail = ""
    @State private var originalBio = ""
    
    // Helper function to hide keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color("background_color")
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        hideKeyboard()
                    }
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Profile Image Section
                        profileImageSection
                        
                        // Form Fields
                        formFieldsSection
                        
                        // Save Button
                        saveButtonSection
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                
                if isLoading {
                    EditProfileLoadingOverlay()
                }
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(Color("blue"))
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveProfile()
                }
                .foregroundColor(hasChanges ? Color("blue") : Color("blue").opacity(0.5))
                .disabled(!hasChanges || isLoading)
            }
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
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $profileImage)
        }
        .onAppear {
            loadProfile()
        }
    }
    
    // MARK: - Profile Image Section
    private var profileImageSection: some View {
        VStack(spacing: 15) {
            Button(action: {
                showImagePicker = true
            }) {
                ZStack {
                    if let profileImage = profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color("blue").opacity(0.1))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(Color("blue"))
                            )
                    }
                    
                    // Camera icon overlay
                    Circle()
                        .fill(Color("blue"))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        )
                        .offset(x: 40, y: 40)
                }
            }
            .buttonStyle(.plain)
            
            Text("Tap to change profile picture")
                .font(.custom("Inter18pt-Regular", size: 14))
                .foregroundColor(Color("TextColor").opacity(0.7))
        }
    }
    
    // MARK: - Form Fields Section
    private var formFieldsSection: some View {
        VStack(spacing: 20) {
            // Name Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Full Name")
                    .font(.custom("Inter18pt-Medium", size: 16))
                    .foregroundColor(Color("TextColor"))
                
                TextField("Enter your full name", text: $name)
                    .font(.custom("Inter18pt-Regular", size: 16))
                    .foregroundColor(Color("TextColor"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color("menuRect"))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color("blue").opacity(0.3), lineWidth: 1)
                    )
            }
            
            // Email Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email Address")
                    .font(.custom("Inter18pt-Medium", size: 16))
                    .foregroundColor(Color("TextColor"))
                
                TextField("Enter your email", text: $email)
                    .font(.custom("Inter18pt-Regular", size: 16))
                    .foregroundColor(Color("TextColor"))
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color("menuRect"))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color("blue").opacity(0.3), lineWidth: 1)
                    )
            }
            
            // Phone Number Field (Read-only)
            VStack(alignment: .leading, spacing: 8) {
                Text("Phone Number")
                    .font(.custom("Inter18pt-Medium", size: 16))
                    .foregroundColor(Color("TextColor"))
                
                TextField("Phone number", text: $phoneNumber)
                    .font(.custom("Inter18pt-Regular", size: 16))
                    .foregroundColor(Color("TextColor").opacity(0.6))
                    .disabled(true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color("menuRect").opacity(0.5))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color("blue").opacity(0.2), lineWidth: 1)
                    )
                
                Text("Phone number cannot be changed")
                    .font(.custom("Inter18pt-Regular", size: 12))
                    .foregroundColor(Color("TextColor").opacity(0.5))
            }
            
            // Bio Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Bio")
                    .font(.custom("Inter18pt-Medium", size: 16))
                    .foregroundColor(Color("TextColor"))
                
                TextField("Tell us about yourself", text: $bio, axis: .vertical)
                    .font(.custom("Inter18pt-Regular", size: 16))
                    .foregroundColor(Color("TextColor"))
                    .lineLimit(3...6)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color("menuRect"))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color("blue").opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }
    
    // MARK: - Save Button Section
    private var saveButtonSection: some View {
        Button(action: {
            saveProfile()
        }) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text("Save Changes")
                        .font(.custom("Inter18pt-SemiBold", size: 16))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                hasChanges ? Color("blue") : Color("blue").opacity(0.5)
            )
            .cornerRadius(12)
        }
        .disabled(!hasChanges || isLoading)
        .buttonStyle(.plain)
    }
    
    // MARK: - Computed Properties
    private var hasChanges: Bool {
        return name != originalName || 
               email != originalEmail || 
               bio != originalBio ||
               profileImage != nil
    }
    
    // MARK: - Functions
    private func loadProfile() {
        isLoading = true
        
        ApiService.get_profile(uid: Constant.SenderIdMy) { success, response, message in
            DispatchQueue.main.async {
                isLoading = false
                if success, let profile = response {
                    name = profile.full_name
                    email = "" // Email not available in current model
                    phoneNumber = profile.mobile_no
                    bio = profile.caption
                    // Only save device_type when it matches get_user_active_chat_list format ("1" or "2"), not UUID
                    if !profile.device_type.isEmpty, (profile.device_type == "1" || profile.device_type == "2") {
                        UserDefaults.standard.set(profile.device_type, forKey: Constant.DEVICE_TYPE_KEY)
                    }
                    // Store original values
                    originalName = profile.full_name
                    originalEmail = ""
                    originalBio = profile.caption
                } else {
                    showAlert(title: "Error", message: message)
                }
            }
        }
    }
    
    private func saveProfile() {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showAlert(title: "Error", message: "Name cannot be empty")
            return
        }
        
        // Email validation removed since email is not used in current model
        
        isLoading = true
        
        // Create update profile request
        let updateData: [String: Any] = [
            "uid": Constant.SenderIdMy,
            "full_name": name.trimmingCharacters(in: .whitespacesAndNewlines),
            "caption": bio.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        
        // Call API to update profile
        ApiService.update_profile(data: updateData) { success, message in
            DispatchQueue.main.async {
                isLoading = false
                if success {
                    showAlert(title: "Success", message: "Profile updated successfully")
                    
                    // Update original values
                    originalName = name
                    originalEmail = email
                    originalBio = bio
                } else {
                    showAlert(title: "Error", message: message)
                }
            }
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
}

struct EditProfileLoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: Color("blue")))
                
                Text("Loading...")
                    .font(.custom("Inter18pt-Medium", size: 16))
                    .foregroundColor(Color("TextColor"))
            }
            .padding(30)
            .background(Color("menuRect"))
            .cornerRadius(15)
        }
    }
}

struct EditProfileView_Previews: PreviewProvider {
    static var previews: some View {
        EditProfileView()
    }
}
