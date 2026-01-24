//
//  ShowImageScreen.swift
//  Enclosure
//
//  Created for viewing a single image with zoom and pan capabilities
//  Matching Android show_image_Screen.java with PhotoView
//

import SwiftUI
import PhotosUI

struct ShowImageScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    let imageModel: SelectionBunchModel
    let viewHolderTypeKey: String? // Optional: "sender" or "receiver" to show menu
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showSaveMenu: Bool = false
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    
    init(imageModel: SelectionBunchModel, viewHolderTypeKey: String? = nil) {
        self.imageModel = imageModel
        self.viewHolderTypeKey = viewHolderTypeKey
    }
    
    // Helper function to hide keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    var body: some View {
        ZStack {
            // Full-screen black background (matching Android @color/black)
            Color.black
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    hideKeyboard()
                }
            
            // Image with zoom and pan (matching Android PhotoView)
            GeometryReader { geometry in
                ZStack {
                    if let imageURL = getImageURL() {
                        CachedAsyncImage(url: imageURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .scaleEffect(scale)
                                .offset(offset)
                                .gesture(
                                    SimultaneousGesture(
                                        // Pinch to zoom
                                        MagnificationGesture()
                                            .onChanged { value in
                                                let delta = value / lastScale
                                                lastScale = value
                                                scale = min(max(scale * delta, 1.0), 5.0) // Limit zoom between 1x and 5x
                                            }
                                            .onEnded { _ in
                                                lastScale = 1.0
                                                // Snap back to 1.0 if zoomed out too much
                                                if scale < 1.0 {
                                                    withAnimation {
                                                        scale = 1.0
                                                        offset = .zero
                                                    }
                                                }
                                            },
                                        // Drag to pan (only when zoomed)
                                        DragGesture()
                                            .onChanged { value in
                                                if scale > 1.0 {
                                                    offset = CGSize(
                                                        width: lastOffset.width + value.translation.width,
                                                        height: lastOffset.height + value.translation.height
                                                    )
                                                }
                                            }
                                            .onEnded { _ in
                                                lastOffset = offset
                                                // Constrain panning to image bounds
                                                constrainOffset(geometry: geometry)
                                            }
                                    )
                                )
                        } placeholder: {
                            VStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    } else {
                        VStack {
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.white.opacity(0.5))
                            Text("Image not available")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .onTapGesture(count: 2) {
                    // Double tap to zoom
                    withAnimation {
                        if scale > 1.0 {
                            scale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            scale = 2.0
                        }
                    }
                }
            }
            
            // Header overlay (matching Android header)
            VStack {
                HStack {
                    // Back button (matching Android: 35dp x 36dp, alpha 0.4, corner radius 20dp)
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        dismiss()
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.black.opacity(0.4))
                                .frame(width: 35, height: 36)
                            
                            Image("leftvector")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 25, height: 18)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.leading, 20)
                    .padding(.top, 50)
                    
                    Spacer()
                    
                    // Menu button (only show if coming from chat - matching Android logic)
                    if viewHolderTypeKey == "sender" || viewHolderTypeKey == "receiver" {
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            showSaveMenu = true
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 40, height: 40)
                                
                                // Three dots menu (matching Android menuPoint)
                                VStack(spacing: 3) {
                                    Circle()
                                        .fill(Color("menuPointColor"))
                                        .frame(width: 4, height: 4)
                                    
                                    Circle()
                                        .fill(Color(red: 0x00/255.0, green: 0xA3/255.0, blue: 0xE9/255.0)) // Theme color #00A3E9
                                        .frame(width: 4, height: 4)
                                    
                                    Circle()
                                        .fill(Color(red: 0x9E/255.0, green: 0xA6/255.0, blue: 0xB9/255.0)) // #9EA6B9
                                        .frame(width: 4, height: 4)
                                }
                            }
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 50)
                    }
                }
                
                Spacer()
            }
            .zIndex(1)
            
            // Save menu dialog (match InviteScreen refresh menu)
            if showSaveMenu {
                ZStack {
                    Color.black.opacity(0.01)
                        .background(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showSaveMenu = false
                            }
                        }
                    
                    VStack {
                        HStack {
                            Spacer()
                            
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(
                                        colorScheme == .light
                                            ? Color.black.opacity(0.25)
                                            : Color.black.opacity(0.15)
                                    )
                                    .frame(width: 130, height: 50)
                                    .offset(x: 0, y: 4)
                                    .blur(radius: colorScheme == .light ? 10 : 8)
                                    .allowsHitTesting(false)
                                
                                if colorScheme == .light {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.black.opacity(0.1))
                                        .frame(width: 130, height: 50)
                                        .offset(x: 0, y: 2)
                                        .blur(radius: 6)
                                        .allowsHitTesting(false)
                                }
                                
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showSaveMenu = false
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        saveImageToGallery()
                                    }
                                }) {
                                    Text("Save")
                                        .font(.custom("Inter18pt-SemiBold", size: 16))
                                        .foregroundColor(Color("TextColor"))
                                        .frame(width: 130, height: 50)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color("menuRect"))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.trailing, 10)
                            .padding(.top, 65)
                        }
                        
                        Spacer()
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.easeInOut(duration: 0.2), value: showSaveMenu)
                .zIndex(2)
            }
            
            // Toast message (matching Android custom toast)
            if showToast {
                VStack {
                    Spacer()
                    Text(toastMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(8)
                        .padding(.bottom, 100)
                }
                .transition(.opacity)
                .zIndex(3)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // Load image when screen appears (matching Android onResume)
            print("📸 [ShowImageScreen] Screen appeared for image: \(imageModel.fileName)")
        }
    }
    
    private func getImageURL() -> URL? {
        // Check local file first (matching Android doesFileExist logic)
        if !imageModel.fileName.isEmpty {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let imagesDir = documentsPath.appendingPathComponent("Enclosure/Media/Images", isDirectory: true)
            let localURL = imagesDir.appendingPathComponent(imageModel.fileName)
            
            if FileManager.default.fileExists(atPath: localURL.path) {
                print("✅ [ShowImageScreen] Loading from local: \(localURL.path)")
                return localURL
            }
        }
        
        // Fallback to network URL
        if !imageModel.imgUrl.isEmpty {
            if let url = URL(string: imageModel.imgUrl) {
                print("✅ [ShowImageScreen] Loading from network: \(imageModel.imgUrl)")
                return url
            }
        }
        
        return nil
    }
    
    private func constrainOffset(geometry: GeometryProxy) {
        // Constrain panning to keep image within bounds
        let maxX = (geometry.size.width * (scale - 1)) / 2
        let maxY = (geometry.size.height * (scale - 1)) / 2
        
        offset.width = min(max(offset.width, -maxX), maxX)
        offset.height = min(max(offset.height, -maxY), maxY)
        lastOffset = offset
    }
    
    private func saveImageToGallery() {
        guard let imageURL = getImageURL() else {
            showToastMessage("Image not found")
            return
        }
        
        // Load image data
        if imageURL.isFileURL {
            // Local file
            if let imageData = try? Data(contentsOf: imageURL),
               let uiImage = UIImage(data: imageData) {
                saveUIImageToGallery(uiImage)
            } else {
                showToastMessage("Failed to load image")
            }
        } else {
            // Network URL - download first
            URLSession.shared.dataTask(with: imageURL) { data, _, error in
                if let data = data, let uiImage = UIImage(data: data) {
                    DispatchQueue.main.async {
                        saveUIImageToGallery(uiImage)
                    }
                } else {
                    DispatchQueue.main.async {
                        showToastMessage("Failed to download image")
                    }
                }
            }.resume()
        }
    }
    
    private func saveUIImageToGallery(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                DispatchQueue.main.async {
                    showToastMessage("Photo library access denied")
                }
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                let creationRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
                creationRequest.creationDate = Date()
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        showToastMessage("Image saved")
                    } else {
                        showToastMessage("Failed to save image")
                    }
                }
            }
        }
    }
    
    private func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showToast = false
            }
        }
    }
}


