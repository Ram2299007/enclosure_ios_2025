//
//  WhatsAppLikeImagePicker.swift
//  Enclosure
//
//  Created by Ram Lohar on 30/04/25.
//

import SwiftUI
import Photos
import PhotosUI
import UIKit

struct WhatsAppLikeImagePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    let maxSelection: Int
    let onImagesSelected: ([PHAsset], String) -> Void
    
    @State private var photoAssets: [PHAsset] = []
    @State private var selectedAssetIds: Set<String> = []
    @State private var captionText: String = ""
    @State private var isLoading: Bool = true
    @State private var showPermissionText: Bool = false
    @State private var isMessageBoxFocused: Bool = false
    @State private var isPressed: Bool = false
    @FocusState private var isCaptionFocused: Bool
    
    private let imageManager = PHCachingImageManager()
    
    // Typography (match Android messageBox sizing prefs)
    private var messageInputFont: Font {
        let pref = UserDefaults.standard.string(forKey: "Font_Size") ?? "medium"
        let size: CGFloat
        switch pref {
        case "small":
            size = 13
        case "large":
            size = 19
        default:
            size = 16
        }
        return .custom("Inter18pt-Regular", size: size)
    }
    
    init(maxSelection: Int = 30, onImagesSelected: @escaping ([PHAsset], String) -> Void) {
        self.maxSelection = maxSelection
        self.onImagesSelected = onImagesSelected
    }
    
    // Helper function to hide keyboard
    private func hideKeyboard() {
        isCaptionFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    var body: some View {
        ZStack {
            // Background matching Android bottom_sheet_background
            Color("chattingMessageBox")
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    hideKeyboard()
                }
            
            VStack(spacing: 0) {
                // Cancel button - top left (matching Android cancelButton and CameraGalleryView)
                HStack {
                    Button(action: {
                        handleCancel()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color("circlebtnhover").opacity(0.1))
                                .frame(width: 40, height: 40)
                            
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
                                .foregroundColor(Color("TextColor"))
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
                    .padding(.leading, 16)
                    .padding(.top, 20)
                    
                    Spacer()
                }
                
                // Permission text (matching Android managePermissionText)
                if showPermissionText {
                    HStack(spacing: 0) {
                        Text("Limited access selected. All photos not visible here on Enclosure. ")
                            .font(.custom("Inter18pt-Medium", size: 13))
                            .foregroundColor(Color("chtbtncolor"))
                        
                        Button(action: {
                            openAppSettings()
                        }) {
                            Text("Select.")
                                .font(.custom("Inter18pt-Medium", size: 13))
                                .foregroundColor(Color(hex: Constant.themeColor))
                                .underline()
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Image Grid (matching Android GridView with layout_marginTop="60dp" and layout_weight="1")
                if isLoading {
                    ProgressView()
                        .progressViewStyle(LinearProgressViewStyle(tint: Color("TextColor")))
                        .frame(height: 4)
                        .padding()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 2) {
                            ForEach(photoAssets, id: \.localIdentifier) { asset in
                                GalleryAssetThumbnail(
                                    asset: asset,
                                    imageManager: imageManager,
                                    isSelected: selectedAssetIds.contains(asset.localIdentifier)
                                )
                                .padding(.top, 10)
                                .overlay(alignment: .topTrailing) {
                                    if selectedAssetIds.contains(asset.localIdentifier) {
                                        Image("multitick")
                                            .resizable()
                                            .frame(width: 20, height: 20)
                                            .padding(10) // padding 10px for multitick
                                    }
                                }
                                .overlay {
                                    // Disabled overlay for max selection
                                    if !selectedAssetIds.contains(asset.localIdentifier) && selectedAssetIds.count >= maxSelection {
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color.black.opacity(0.6))
                                    }
                                }
                                .onTapGesture {
                                    toggleSelection(for: asset)
                                }
                            }
                        }
                        .padding(.top, 10)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)
                    }
                    .padding(.top, 20) // layout_marginTop="60dp" matching Android
                }
                
                Spacer(minLength: 0) // Allow grid to expand (matching layout_weight="1")
                
                // Caption bar + Done button (matching Android captionlyt)
                captionBarView
                    .padding(.bottom, 10)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .navigationBarHidden(true)
        .background(NavigationGestureEnabler())
        .ignoresSafeArea(.keyboard)
        .simultaneousGesture(
            TapGesture().onEnded { _ in
                hideKeyboard()
            }
        )
        .onAppear {
            requestPhotosAndLoad()
        }
        .onDisappear {
        }
    }
    
    // MARK: - Caption Bar View (matching CameraGalleryView design)
    private var captionBarView: some View {
        HStack(spacing: 0) {
            // Caption input container (matching messageBox design from CameraGalleryView)
            HStack(spacing: 0) {
                // Message input field container - layout_weight="1"
                VStack(alignment: .leading, spacing: 0) {
                    TextField("Add Caption", text: $captionText, axis: .vertical)
                        .font(messageInputFont)
                        .foregroundColor(Color("black_white_cross"))
                        .lineLimit(4)
                        .frame(maxWidth: 180, alignment: .leading)
                        .padding(.leading, 10) // start padding 10px
                        .padding(.trailing, 20)
                        .padding(.top, 5)
                        .padding(.bottom, 5)
                        .background(Color.clear)
                        .focused($isCaptionFocused)
                        .onChange(of: isCaptionFocused) { focused in
                            isMessageBoxFocused = focused
                        }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 50) // Match send button height (50dp)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color("circlebtnhover")) // match Android backgroundTint on message_box_bg
            )
            .padding(.leading, 10)
            .padding(.trailing, 5)
            
            // Send button group (matching sendGrpLyt from CameraGalleryView)
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    Button(action: {
                        handleDone()
                    }) {
                        ZStack {
                            Circle()
                                .fill(selectedAssetIds.count > 0 ? Color(hex: Constant.themeColor) : Color(hex: Constant.themeColor))
                                .frame(width: 50, height: 50)
                            
                            // Send icon (keyboard double arrow right) - same as Android
                            Image("baseline_keyboard_double_arrow_right_24")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 26, height: 26)
                                .foregroundColor(.white)
                                .padding(.top, 4)
                                .padding(.bottom, 8)
                        }
                    }
                    .disabled(selectedAssetIds.count == 0)
                    .opacity(selectedAssetIds.count > 0 ? 1.0 : 0.5)
                }
                
                // Small counter badge (Android multiSelectSmallCounterText)
                if selectedAssetIds.count > 0 {
                    Text("\(selectedAssetIds.count)")
                        .font(.custom("Inter18pt-Bold", size: 12))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(Color(hex: Constant.themeColor)) // match Android counter tint
                        )
                        .offset(x: -13, y: -30) // lift badge above send button with extra right margin
                }
            }
            .padding(.horizontal, 5)
        }
    }
    
    // MARK: - Helper Functions
    private func toggleSelection(for asset: PHAsset) {
        let id = asset.localIdentifier
        if selectedAssetIds.contains(id) {
            selectedAssetIds.remove(id)
        } else {
            guard selectedAssetIds.count < maxSelection else { return }
            selectedAssetIds.insert(id)
        }
    }
    
    private func handleDone() {
        guard !selectedAssetIds.isEmpty else { return }
        
        let selectedAssets = photoAssets.filter { selectedAssetIds.contains($0.localIdentifier) }
        onImagesSelected(selectedAssets, captionText.trimmingCharacters(in: .whitespacesAndNewlines))
        dismiss()
    }
    
    private func handleCancel() {
        // Matching Android handleBackPress: if messageBox is focused, clear focus; otherwise dismiss
        if isMessageBoxFocused || isCaptionFocused {
            // Clear focus and hide keyboard
            isCaptionFocused = false
            isMessageBoxFocused = false
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        } else {
            // Dismiss with animation matching CameraGalleryView
            withAnimation {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                dismiss()
                isPressed = false
            }
        }
    }
    
    private func requestPhotosAndLoad() {
        // Custom permission dialog first, then system (when user opens photo picker)
        AndroidStylePermissionManager.shared.requestPermissionWithDialogFromTopVC(for: .photos) { granted in
            DispatchQueue.main.async {
                if granted {
                    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                    self.showPermissionText = (status == .limited)
                    self.loadAllPhotos()
                } else {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadAllPhotos() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            options.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared, .typeiTunesSynced]
            
            let fetched = PHAsset.fetchAssets(with: .image, options: options)
            
            var assets: [PHAsset] = []
            fetched.enumerateObjects { asset, _, _ in
                assets.append(asset)
            }
            
            DispatchQueue.main.async {
                print("📸 [WhatsAppImagePicker] Loaded \(assets.count) photos")
                self.photoAssets = assets
                self.isLoading = false
            }
        }
    }
    
    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

