//
//  MultipleImageScreen.swift
//  Enclosure
//
//  Created for viewing multiple images in a full-screen vertically scrollable view
//  Matching Android multiple_show_image_screen.java with VERTICAL LinearLayoutManager
//

import SwiftUI

struct MultipleImageScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    let images: [SelectionBunchModel]
    @State private var currentIndex: Int
    @State private var navigateToShowImage: Bool = false
    @State private var selectedImageForShow: SelectionBunchModel?
    
    init(images: [SelectionBunchModel], currentIndex: Int = 0) {
        self.images = images
        self._currentIndex = State(initialValue: currentIndex)
    }
    
    // Helper function to hide keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    var body: some View {
        ZStack {
            // Full-screen background (matching Android @color/modetheme2)
            Color("BackgroundColor")
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    hideKeyboard()
                }
            
            // Vertical scrolling images (matching Android RecyclerView with VERTICAL LinearLayoutManager)
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(images.enumerated()), id: \.offset) { index, imageModel in
                            // Image container (matching Android item_multiple_image.xml)
                            // layout_marginBottom="8dp" for spacing between images
                            VStack(spacing: 0) {
                                ZStack {
                                    // Background matching Android rounded_corner_background
                                    RoundedRectangle(cornerRadius: 0)
                                        .fill(Color("light_gray"))
                                    
                                    // Use CachedAsyncImage for better loading (matching Android MultipleImageAdapter)
                                    Group {
                                        if let imageURL = getImageURL(for: imageModel) {
                                            CachedAsyncImage(
                                                url: imageURL,
                                                content: { image in
                                                    print("✅ [MultipleImageScreen] Image \(index) loaded successfully from: \(imageURL.absoluteString)")
                                                    return image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill) // centerCrop equivalent
                                                        .frame(maxWidth: .infinity)
                                                        .clipped()
                                                },
                                                placeholder: {
                                                    print("⏳ [MultipleImageScreen] Image \(index) loading from: \(imageURL.absoluteString)")
                                                    return VStack {
                                                        ProgressView()
                                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                            .scaleEffect(1.5)
                                                    }
                                                    .frame(maxWidth: .infinity)
                                                    .frame(height: 300) // Placeholder height
                                                }
                                            )
                                        } else {
                                            // Fallback if URL is invalid
                                            VStack {
                                                Image(systemName: "photo")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 100, height: 100)
                                                    .foregroundColor(.white.opacity(0.5))
                                                Text("Image not available")
                                                    .foregroundColor(.white.opacity(0.7))
                                                    .font(.caption)
                                                Text("fileName: \(imageModel.fileName)")
                                                    .foregroundColor(.white.opacity(0.5))
                                                    .font(.caption2)
                                                Text("imgUrl: \(imageModel.imgUrl.isEmpty ? "empty" : String(imageModel.imgUrl.prefix(50)))")
                                                    .foregroundColor(.white.opacity(0.5))
                                                    .font(.caption2)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 300)
                                        }
                                    }
                                }
                                .onAppear {
                                    // Update current index when image appears (for tracking scroll position)
                                    currentIndex = index
                                    let imageURL = getImageURL(for: imageModel)
                                    print("📸 [MultipleImageScreen] Image \(index) appeared - URL result: \(imageURL?.absoluteString ?? "nil")")
                                    if imageURL == nil {
                                        print("❌ [MultipleImageScreen] Image \(index) - No valid URL found. fileName: '\(imageModel.fileName)', imgUrl: '\(imageModel.imgUrl)'")
                                    }
                                }
                            }
                            .id(index) // ID for ScrollViewReader
                            .padding(.bottom, 8) // layout_marginBottom="8dp" - spacing between images
                            .onTapGesture {
                                // Tap to open full-screen image view (matching Android openIndividualImage)
                                selectedImageForShow = imageModel
                                navigateToShowImage = true
                            }
                        }
                    }
                    .padding(.top, 0) // No top padding
                }
                .onAppear {
                    // Scroll to current position when screen appears (matching Android recyclerView.scrollToPosition)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if currentIndex >= 0 && currentIndex < images.count {
                            print("📸 [MultipleImageScreen] Scrolling to position \(currentIndex)")
                            withAnimation {
                                proxy.scrollTo(currentIndex, anchor: .top)
                            }
                        }
                    }
                }
            }
            
            // Header overlay on top (matching Android header with marginTop="50dp")
            // This must be after ScrollView in ZStack to appear on top
            VStack {
                HStack {
                    // Back button (matching Android: 35dp x 36dp, alpha 0.4, corner radius 20dp)
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        dismiss()
                    }) {
                        ZStack {
                            // Black background with corner radius 20dp (matching Android black_background_hover)
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.black.opacity(0.4)) // alpha 0.4
                                .frame(width: 35, height: 36) // 35dp x 36dp
                            
                            Image("leftvector")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 25, height: 18) // 25dp x 18dp
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.leading, 20) // marginStart="20dp"
                    .padding(.top, 50) // marginTop="50dp" for header
                    
                    Spacer()
                }
                
                Spacer()
            }
            .allowsHitTesting(true) // Ensure button is tappable
            .zIndex(1) // Ensure header appears above ScrollView
        }
        .background(
            // Hidden NavigationLink for programmatic navigation to ShowImageScreen
            NavigationLink(
                destination: Group {
                    if let selectedImage = selectedImageForShow {
                        ShowImageScreen(
                            imageModel: selectedImage,
                            viewHolderTypeKey: nil // Not from chat, so no menu
                        )
                    } else {
                        EmptyView()
                    }
                },
                isActive: $navigateToShowImage
            ) {
                EmptyView()
            }
            .hidden()
        )
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            print("📸 [MultipleImageScreen] ========== SCREEN APPEARED ==========")
            print("📸 [MultipleImageScreen] Total images: \(images.count)")
            print("📸 [MultipleImageScreen] Current index: \(currentIndex)")
            
            if images.isEmpty {
                print("❌ [MultipleImageScreen] ERROR: images array is EMPTY!")
            } else {
                for (index, imageModel) in images.enumerated() {
                    print("📸 [MultipleImageScreen] --- Image \(index) ---")
                    print("📸 [MultipleImageScreen]   fileName: '\(imageModel.fileName)'")
                    print("📸 [MultipleImageScreen]   imgUrl: '\(imageModel.imgUrl.isEmpty ? "EMPTY" : imageModel.imgUrl)'")
                    print("📸 [MultipleImageScreen]   imgUrl length: \(imageModel.imgUrl.count)")
                    
                    // Test URL resolution immediately
                    let testURL = getImageURL(for: imageModel)
                    print("📸 [MultipleImageScreen]   Resolved URL: \(testURL?.absoluteString ?? "nil")")
                }
            }
            print("📸 [MultipleImageScreen] ======================================")
        }
    }
    
    private func getImageURL(for imageModel: SelectionBunchModel) -> URL? {
        print("🔍 [MultipleImageScreen] getImageURL called - fileName: '\(imageModel.fileName)', imgUrl: '\(imageModel.imgUrl.isEmpty ? "empty" : imageModel.imgUrl)'")
        
        // Check local file first (matching Android doesFileExist logic)
        if !imageModel.fileName.isEmpty {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let imagesDir = documentsPath.appendingPathComponent("Enclosure/Media/Images", isDirectory: true)
            let localURL = imagesDir.appendingPathComponent(imageModel.fileName)
            
            print("📁 [MultipleImageScreen] Checking local file at: \(localURL.path)")
            
            // Check if directory exists
            var isDirectory: ObjCBool = false
            let dirExists = FileManager.default.fileExists(atPath: imagesDir.path, isDirectory: &isDirectory)
            print("📁 [MultipleImageScreen] Images directory exists: \(dirExists), isDirectory: \(isDirectory.boolValue)")
            
            if FileManager.default.fileExists(atPath: localURL.path) {
                print("✅ [MultipleImageScreen] Local file FOUND: \(localURL.path)")
                return localURL
            } else {
                print("❌ [MultipleImageScreen] Local file NOT FOUND: \(localURL.path)")
                // List files in directory for debugging
                if let files = try? FileManager.default.contentsOfDirectory(atPath: imagesDir.path) {
                    print("📁 [MultipleImageScreen] Files in directory: \(files.prefix(10))")
                }
            }
        } else {
            print("⚠️ [MultipleImageScreen] fileName is empty")
        }
        
        // Fallback to online URL (matching Android network URL loading)
        if !imageModel.imgUrl.isEmpty {
            print("🌐 [MultipleImageScreen] Checking network URL: \(imageModel.imgUrl)")
            if let url = URL(string: imageModel.imgUrl) {
                print("✅ [MultipleImageScreen] Valid network URL created: \(url.absoluteString)")
                return url
            } else {
                print("❌ [MultipleImageScreen] Invalid network URL format: \(imageModel.imgUrl)")
            }
        } else {
            print("⚠️ [MultipleImageScreen] imgUrl is empty for fileName: \(imageModel.fileName)")
        }
        
        print("❌ [MultipleImageScreen] No valid URL found for image")
        return nil
    }
}
