import SwiftUI
import PhotosUI

struct EditmyProfile: View {

    @Environment(\.dismiss) var dismiss
    @State private var isPressed = false
    @State private var profile: GetProfileModel?
    @State private var name: String = ""
    @State private var caption: String = ""

    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?

    @State private var showImagePickerStatus = false
    @State private var selectedImageStatus: [UIImage] = []

    @State private var showDialog = false
    @State private var themeColorHex: String = Constant.themeColor
    

    @Environment(\.presentationMode) var presentationMode
    @FocusState private var isFullNameFocused: Bool
    @StateObject private var viewModel = EditProfileViewModel()
    @StateObject private var viewModelList = EditProfileViewModel()

    @State private var showAlert = false
    @State private var selectedImageID: String? // To track the tapped image


    var body: some View {
        NavigationStack {
            ZStack{
                // Background color to match the theme
                Color("background_color")
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
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

                            Text("for visible")
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


                        HStack{
                            Spacer()
                            ThemedProfileImageView(
                                selectedImage: selectedImage,
                                imageURL: profile?.photo,
                                themeColorHex: themeColorHex
                            )
                            .padding(.top, 16)
                        }
                        .padding(.trailing, 16)


                        HStack(spacing: 30) {
                            // Delete Button

                            Button(action: {
                                ApiService.delete_user_profile_image(uid:Constant.SenderIdMy)
                                { success, message in
                                    if success {
                                        print("Image uploaded successfully: \(message)")
                                        profile = nil

                                    } else {
                                        print("Failed to upload image: \(message)")
                                    }
                                }

                            }){
                                HStack(spacing: 10) {
                                    Text("Delete")
                                        .font(.custom("Inter18pt-Medium", size: 16))
                                        .foregroundColor(Color.red)
                                        .lineSpacing(4)

                                    Image("minus") // Assumes you added "minus" asset in Assets.xcassets
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                }
                                .padding(6)
                            }


                            // Add Button

                            Button(action: {
                                showImagePicker = true
                            }){
                                HStack(spacing: 10) {
                                    Text("Add")
                                        .font(.custom("Inter18pt-Medium", size: 16))
                                        .foregroundColor(Color("TextColor")) // Define in Assets if needed
                                        .lineSpacing(4)

                                    Image("plus")
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                }
                                .padding(6)
                            }

                            .sheet(isPresented: $showImagePicker) {
                                ImagePicker(selectedImage: $selectedImage)
                            }





                        }
                        .padding(.top, 20)
                        .padding(.trailing, 16)
                        .frame(maxWidth: .infinity, alignment: .trailing)


                        HStack(alignment: .center, spacing: 0) {
                            Spacer()

                            HStack(spacing: 15) {
                                let count = viewModelList.listImages.count
                                let imageRepeatCount = max(0, 4 - count)

                                ForEach(0..<Swift.max(0, imageRepeatCount), id: \.self) { _ in
                                    ThemeBorderStatusImage(imageURL: nil)
                                }
                            }



                            //  MultiDemoView(selectedImages: $selectedImageStatus)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 15) {
                                    ForEach(viewModelList.listImages, id: \.id) { imageData in
                                        ThemeBorderStatusImage(imageURL: imageData.photo)
                                        .onLongPressGesture {
                                            selectedImageID = imageData.id
                                            showAlert = true
                                        }
                                    }
                                }
                                .padding(.horizontal, 10)
                            }
                            .fixedSize()
                            .allowsHitTesting(true)
                            .padding(.trailing, 5)






                            Button(action: {
                                showImagePickerStatus = true
                            }) {
                                Image("plus")
                                    .resizable()
                                    .frame(width: 20, height: 20)

                            }
                            .frame(width: 40, height: 40)
                            .sheet(isPresented: $showImagePickerStatus) {
                                ImagePicker(
                                    selectedImage: Binding<UIImage?>(
                                        get: { nil
                                        },
                                        set: { newImage in
                                            if let newImage = newImage {
                                                // Check if image already exists in the array by comparing data
                                                if let newImageData = newImage.jpegData(compressionQuality: 0.7),
                                                   !selectedImageStatus.contains(where: { existingImage in
                                                       guard let existingData = existingImage.jpegData(compressionQuality: 0.7) else { return false }
                                                       return existingData == newImageData
                                                   }) {

                                                    if selectedImageStatus.count < 4 {
                                                        selectedImageStatus.append(newImage)
                                                    } else {
                                                        selectedImageStatus.removeFirst()
                                                        selectedImageStatus.append(newImage)
                                                    }

                                                    // ✅ Upload only the new image
                                                    ApiService.upload_user_profile_images(
                                                        uid: Constant.SenderIdMy,
                                                        photo: newImageData
                                                    ) { success, message in
                                                        if success {
                                                            print("Image uploaded successfully: \(message)")
                                                            viewModelList.fetch_user_profile_images_EditProfile(uid: Constant.SenderIdMy)
                                                        } else {
                                                            print("Failed to upload image: \(message)")
                                                        }
                                                    }
                                                } else {
                                                    print("Duplicate image not added or uploaded.")
                                                }
                                            }
                                        }

                                    )
                                )


                            }
                        }
                        .padding(.top, 34)
                        .padding(.trailing, 10)



                        VStack(spacing: 0) {
                            // Name Label + Input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Name")
                                    .font(.custom("Inter18pt-Medium", size: 12))
                                    .foregroundColor(Color("gray"))

                                TextField("Enter your name", text: $name)
                                    .padding(.horizontal, 13)
                                    .frame(height: 49)
                                    .background(Color("background_color")) // Use themed background color
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color("gray"))
                                    )
                                    .font(.custom("Inter18pt-Medium", size: 15))
                                    .foregroundColor(Color("TextColor"))
                                    .focused($isFullNameFocused) // Bind focus state



                            }
                            .padding(.horizontal, 20)

                            // Caption Label + Input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Caption")
                                    .font(.custom("Inter18pt-Medium", size: 12))
                                    .foregroundColor(Color("gray"))

                                AutoResizingTextEditor(
                                    text: $caption,
                                    placeholder: "Enter your caption here...",
                                    maxCharacters: 300
                                )
                            }
                            .padding(.horizontal, 20)
                            .padding(.top,34)



                            Button(action: {
                                // Sample data (replace with actual values from your view/model)
                                let uid = Constant.SenderIdMy
                                let fullName = $name.wrappedValue
                                let caption = $caption.wrappedValue

                                if(fullName.isEmpty){
                                    Constant.showToast(message: "Full name is required.")
                                    isFullNameFocused = true

                                }else{

                                    let image = selectedImage
                                    let imageData = image?.jpegData(compressionQuality: 0.7) // Adjust the compression as needed

                                    ApiService.profile_update(uid: uid, full_name: fullName, caption: caption, photo: imageData) { success, message in
                                        if success {
                                            print("Profile updated successfully: \(message)")
                                            Constant.showToast(message: "Profile changed")
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {

                                                self.presentationMode.wrappedValue.dismiss()
                                            }
                                        } else {
                                            print("Profile update failed: \(message)")
                                        }
                                    }


                                }



                            }) {
                                Image("tick_new_dvg")
                                    .resizable()
                                    .renderingMode(.template)
                                    .scaledToFit()
                                    .frame(width: 52, height: 52)
                                    .foregroundColor(Color("TextColor"))
                                    .padding()
                            }
                            .frame(width: 52, height: 52)
                            .buttonStyle(CircularRippleStyle())
                            .padding(.top, 34)



                        }
                        .padding(.top, 34)
                        .padding(.bottom, 10)




                        Spacer()
                    }
                    .onAppear{
                        viewModel.fetch_profile_EditProfile(uid: Constant.SenderIdMy)
                        viewModelList.fetch_user_profile_images_EditProfile(uid: Constant.SenderIdMy)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { // Delay for API response
                            if let fetchedProfile = viewModel.list.first {
                                profile = fetchedProfile
                                caption = profile?.caption ?? ""
                                name = profile?.full_name ?? ""
                                /// for set data default
                                UserDefaults.standard.set(profile?.photo , forKey: Constant.profilePic)
                                UserDefaults.standard.set(profile?.full_name, forKey: Constant.full_name)
                                if let newThemeColor = fetchedProfile.themeColor, !newThemeColor.isEmpty {
                                    themeColorHex = newThemeColor
                                    UserDefaults.standard.set(newThemeColor, forKey: Constant.ThemeColorKey)
                                }
                            } else {
                                print("No profile data available or list is empty")
                            }
                            selectedImageStatus = viewModelList.list
                                .compactMap { viewModel in
                                    guard let image = UIImage(contentsOfFile: viewModel.photo) else {
                                        return nil
                                    }
                                    return image
                                }
                        }
                    }




                }

                // Custom Alert
                if showAlert {
                    ImageDialogView(
                        isPresented: $showAlert,
                        selectedImageID: $selectedImageID,
                        viewModelList: viewModelList
                    )
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
struct MultiDemoView: View {
    @Binding var selectedImages: [UIImage]

    var body: some View {
        HStack(spacing: 15) {
            // Display 4 slots, mapping directly to array indices
            ForEach(0..<4, id: \.self) { index in
                if index < selectedImages.count {
                    // Show the image at this index
                    ProfileCardView(image: selectedImages[index], onDelete: {
                        selectedImages.remove(at: index)
                    })
                } else {
                    // Show a placeholder if no image is selected for this slot
                    ProfileCardView(image: nil, onDelete: {})
                }
            }
        }
    }
}

struct ProfileCardView: View {
    @State private var showDeleteConfirmation = false
    var image: UIImage? // Optional image to display
    var onDelete: () -> Void // Closure to handle deletion

    var body: some View {
        VStack(spacing: 5) {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            } else {
                Image("inviteimg")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
        }
        .onTapGesture {
            if image != nil {
                showDeleteConfirmation.toggle()
            }
        }
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("Delete Image"),
                message: Text("Are you sure you want to delete this image?"),
                primaryButton: .destructive(Text("Delete")) {
                    onDelete()
                },
                secondaryButton: .cancel()
            )
        }
    }
}
// Note: CircularRippleStyle is now defined in Utility/ButtonStyles.swift



struct ImageDialogView: View {
    @Binding var isPresented: Bool
    @Binding var selectedImageID: String?
    @ObservedObject var viewModelList: EditProfileViewModel

    var body: some View {
        ZStack {
            // Blurred background
            Color.black.opacity(0.0)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut) {
                        isPresented = false
                        selectedImageID = nil
                    }
                }

            // Top-aligned dialog content
            VStack {
                // Dialog box
                VStack(spacing: 20) {
                    // Image preview
                    if let imageID = selectedImageID,
                       let imageData = viewModelList.listImages.first(where: { $0.id == imageID }) {
                        CachedAsyncImage(url: URL(string: imageData.photo)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 250, height: 250)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                        } placeholder: {
                            Image("inviteimg")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 250, height: 250)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                    } else {
                        Image("inviteimg")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 250, height: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }

                    // Delete Button


                    Button(
                        action:{
                            if let unwrappedImageID = selectedImageID {
                                ApiService.delete_user_single_status_image(uid: Constant.SenderIdMy, id: unwrappedImageID) { success, msg in
                                    if success {
                                        // Handle success

                                        if let index = viewModelList.listImages.firstIndex(where: { $0.id == selectedImageID }) {
                                                                               viewModelList.listImages.remove(at: index)
                                                                           }
                                                                           // Close the dialog
                                                                           withAnimation(.easeOut) {
                                                                               isPresented = false
                                                                               selectedImageID = nil
                                                                           }


                                    } else {
                                        print("Failed to delete: \(msg)")
                                    }
                                }
                            } else {
                                print("No image selected")
                            }


                        }){
                            HStack {
                                Spacer()
                                Image("baseline_delete_forever_24")
                                    .frame(width: 24, height: 24)
                                    .padding(.trailing, 2)

                                Text("Delete")
                                    .font(.custom("Inter18pt-SemiBold", size: 16))
                                    .foregroundColor(Color("TextColor"))
                                Spacer()
                            }
                            .frame(height: 48)
                            .background(Color("dxForward"))
                            .cornerRadius(15)
                            .padding(.horizontal, 20)
                        }
                }
                .padding(.top, 60) // Adjust distance from top here

                Spacer() // Pushes the content to the top
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct ThemedProfileImageView: View {
    var selectedImage: UIImage?
    var imageURL: String?
    var themeColorHex: String
    
    private let imageSize: CGFloat = 107
    private let borderPadding: CGFloat = 4.0
    
    private var borderColor: Color {
        Color(hex: themeColorHex.isEmpty ? Constant.themeColor : themeColorHex)
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(borderColor, lineWidth: 1.5)
                .frame(width: imageSize + borderPadding * 2, height: imageSize + borderPadding * 2)
                .overlay(
                    Circle()
                        .fill(Color("BackgroundColor"))
                        .frame(width: imageSize + borderPadding * 2, height: imageSize + borderPadding * 2)
                )
            
            if let selectedImage = selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: imageSize, height: imageSize)
                    .clipShape(Circle())
            } else if let imageURL = imageURL, !imageURL.isEmpty {
                CachedAsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: imageSize, height: imageSize)
                        .clipShape(Circle())
                } placeholder: {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .frame(width: imageSize + borderPadding * 2, height: imageSize + borderPadding * 2)
    }
    
    private var placeholder: some View {
        Image("inviteimg")
            .resizable()
            .scaledToFill()
            .frame(width: imageSize, height: imageSize)
            .clipShape(Circle())
    }
}





// Auto-resizing TextEditor component
struct AutoResizingTextEditor: View {
    @Binding var text: String
    let placeholder: String
    let maxCharacters: Int
    @State private var textEditorHeight: CGFloat = 100
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background
            RoundedRectangle(cornerRadius: 8)
                .fill(Color("background_color"))
                .frame(height: max(100, textEditorHeight + 32)) // Min height 100, dynamic based on content
            
            // TextEditor
            TextEditor(text: $text)
                .padding(8)
                .padding(.bottom, 16)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .font(.custom("Inter18pt-Medium", size: 15))
                .lineSpacing(6)
                .foregroundColor(Color("TextColor"))
                .frame(height: max(100, textEditorHeight + 32))
                .onChange(of: text) { newValue in
                    // Limit characters
                    if text.count > maxCharacters {
                        text = String(text.prefix(maxCharacters))
                    }
                    
                    // Calculate height based on content
                    DispatchQueue.main.async {
                        let font = UIFont(name: "Inter18pt-Medium", size: 15) ?? UIFont.systemFont(ofSize: 15)
                        let attributes = [NSAttributedString.Key.font: font]
                        let size = (text as NSString).boundingRect(
                            with: CGSize(width: UIScreen.main.bounds.width - 56, height: .greatestFiniteMagnitude),
                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                            attributes: attributes,
                            context: nil
                        )
                        textEditorHeight = max(68, size.height) // Min content height
                    }
                }
            
            // Placeholder text
            if text.isEmpty {
                Text(placeholder)
                    .font(.custom("Inter18pt-Medium", size: 15))
                    .foregroundColor(Color("gray"))
                    .padding(12)
                    .allowsHitTesting(false)
            }
            
            // Border overlay
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color("gray"))
                .frame(height: max(100, textEditorHeight + 32))
        }
        .overlay(
            // Character count
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("\(text.count)/\(maxCharacters)")
                        .font(.custom("Inter18pt-Medium", size: 12))
                        .foregroundColor(text.count >= maxCharacters ? .red : Color("gray"))
                        .padding(.trailing, 8)
                        .padding(.bottom, 8)
                }
            },
            alignment: .bottomTrailing
        )
        .onAppear {
            // Initial height calculation
            if !text.isEmpty {
                let font = UIFont(name: "Inter18pt-Medium", size: 15) ?? UIFont.systemFont(ofSize: 15)
                let attributes = [NSAttributedString.Key.font: font]
                let size = (text as NSString).boundingRect(
                    with: CGSize(width: UIScreen.main.bounds.width - 56, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                )
                textEditorHeight = max(68, size.height)
            }
        }
    }
}

#Preview {
    EditmyProfile()
        .environment(
            \.managedObjectContext,
             PersistenceController.preview.container.viewContext
        )
}
