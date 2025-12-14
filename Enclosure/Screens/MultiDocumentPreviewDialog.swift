//
//  MultiDocumentPreviewDialog.swift
//  Enclosure
//
//  Created by Ram Lohar on 30/04/25.
//

import SwiftUI
import UniformTypeIdentifiers
import QuickLook

struct MultiDocumentPreviewDialog: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    let selectedDocuments: [URL]
    @Binding var caption: String
    let onSend: (String) -> Void
    let onDismiss: () -> Void
    
    @State private var currentIndex: Int = 0
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isCaptionFocused: Bool
    
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
    
    var body: some View {
        ZStack {
            // Full-screen background (matching Android transparent background)
            Color.black
                .ignoresSafeArea()
            
            if selectedDocuments.isEmpty {
                // Show loading or error if no documents
                VStack {
                    Text("No documents selected")
                        .foregroundColor(.white)
                }
            } else {
                VStack(spacing: 0) {
                    // Top bar with back button and document count (matching Android header)
                    HStack {
                        // Back button
                        Button(action: {
                            // Light haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            onDismiss()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                
                                Image("leftvector")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 25, height: 18)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.leading, 16)
                        
                        Spacer()
                        
                        // Document count indicator (matching Android counter) - always show
                        Text("\(currentIndex + 1) / \(selectedDocuments.count)")
                            .font(.custom("Inter18pt-Medium", size: 16))
                            .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Spacer to balance layout (send button is in bottom caption bar)
                    Spacer()
                        .frame(width: 40)
                }
                .frame(height: 60)
                .background(Color.black.opacity(0.3))
                
                // Document preview area (matching Android document preview)
                GeometryReader { geometry in
                    TabView(selection: $currentIndex) {
                        ForEach(Array(selectedDocuments.enumerated()), id: \.element) { index, documentURL in
                            DocumentPreviewItem(documentURL: documentURL)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                }
                
                // Spacing between document and caption area (5px)
                Spacer()
                    .frame(height: 5)
                
                // Bottom caption input area (matching WhatsAppLikeImagePicker captionBarView design)
                HStack(spacing: 0) {
                    // Caption input container (matching messageBox design from WhatsAppLikeImagePicker)
                    HStack(spacing: 0) {
                        // Message input field container - layout_weight="1"
                        VStack(alignment: .leading, spacing: 0) {
                            ZStack(alignment: .leading) {
                                // Placeholder text (matching Android textColorHint="#9EA6B9")
                                if caption.isEmpty {
                                    Text("Add Caption")
                                        .font(.custom("Inter18pt-Medium", size: 17))
                                        .foregroundColor(Color(hex: "#9EA6B9"))
                                        .padding(.leading, 15)
                                        .padding(.trailing, 20)
                                        .padding(.top, 5)
                                        .padding(.bottom, 5)
                                }
                                
                                // TextField (matching Android EditText properties)
                                TextField("", text: $caption, axis: .vertical)
                                    .font(.custom("Inter18pt-Medium", size: 17)) // textSize="17sp", textFontWeight="500"
                                    .foregroundColor(.white) // textColor="@color/white"
                                    .lineLimit(4) // maxLines="4"
                                    .lineSpacing(4) // lineHeight="21dp" (21 - 17 = 4dp spacing)
                                    .frame(maxWidth: 180, alignment: .leading) // maxWidth="180dp"
                                    .padding(.leading, 15) // paddingStart="15dp"
                                    .padding(.trailing, 20) // paddingEnd="20dp"
                                    .padding(.top, 5) // paddingTop="5dp"
                                    .padding(.bottom, 5) // paddingBottom="5dp"
                                    .background(Color.clear) // background="#00000000"
                                    .focused($isCaptionFocused)
                                    .accentColor(Color("black_white_crossEmoji")) // textColorHighlight
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 50) // Match send button height (50dp)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(hex: "#1B1C1C")) // Use specified color for caption message box
                    )
                    .padding(.leading, 10)
                    .padding(.trailing, 5)
                    
                    // Send button group (matching sendGrpLyt from WhatsAppLikeImagePicker)
                    VStack(spacing: 0) {
                        Button(action: {
                            // Light haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            onSend(caption.trimmingCharacters(in: .whitespacesAndNewlines))
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: Constant.themeColor))
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
                    }
                    .padding(.horizontal, 5)
                }
                .padding(.bottom, keyboardHeight > 0 ? keyboardHeight - 20 : 10)
                .background(Color.black)
                }
            }
        }
        .onAppear {
            print("MultiDocumentPreviewDialog: onAppear - documents count: \(selectedDocuments.count)")
            print("MultiDocumentPreviewDialog: documents: \(selectedDocuments.map { $0.lastPathComponent })")
            setupKeyboardObservers()
        }
        .onDisappear {
            removeKeyboardObservers()
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded { value in
                    // Handle swipe down to dismiss (optional)
                    if value.translation.height > 100 {
                        onDismiss()
                    }
                }
        )
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            keyboardHeight = 0
        }
    }
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Document Preview Item (matching Android item_document_preview.xml)
struct DocumentPreviewItem: View {
    let documentURL: URL
    
    @State private var fileSize: String = ""
    @State private var fileName: String = ""
    @State private var fileIcon: String = "documentsvg"
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Document Name (matching Android documentName TextView)
                Text(fileName)
                    .font(.custom("Inter18pt-Medium", size: 22))
                    .foregroundColor(Color("gray3"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .lineLimit(3)
                
                // Size Label (matching Android "size" TextView)
                Text("size")
                    .font(.custom("Inter18pt-Medium", size: 17))
                    .foregroundColor(Color("gray3"))
                    .padding(.horizontal, 30)
                    .padding(.top, 5)
                    .padding(.vertical, 10)
                
                // Document Size (matching Android documentSize TextView)
                Text(fileSize)
                    .font(.custom("Inter18pt-Medium", size: 17))
                    .foregroundColor(Color("gray3"))
                    .padding(.horizontal, 30)
                    .padding(.top, 5)
                    .padding(.bottom, 10)
                
                // Document Icon (matching Android documentIcon ImageView)
                Image(fileIcon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(Color("gray3"))
                    .padding(.top, 5)
                
                Spacer()
            }
        }
        .onAppear {
            loadDocumentInfo()
        }
    }
    
    private func loadDocumentInfo() {
        // Get file name
        fileName = documentURL.lastPathComponent
        
        // Get file size
        if let attributes = try? FileManager.default.attributesOfItem(atPath: documentURL.path),
           let size = attributes[.size] as? Int64 {
            fileSize = formatFileSize(size)
        } else {
            fileSize = "Unknown"
        }
        
        // Determine icon based on file type
        fileIcon = getFileIcon(for: documentURL)
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func getFileIcon(for url: URL) -> String {
        let pathExtension = url.pathExtension.lowercased()
        
        // Check if it's an image
        if ["jpg", "jpeg", "png", "gif", "heic", "heif", "webp"].contains(pathExtension) {
            return "gallery"
        }
        
        // Check if it's a video
        if ["mp4", "mov", "avi", "m4v", "mkv"].contains(pathExtension) {
            return "videopng"
        }
        
        // Check if it's a PDF
        if pathExtension == "pdf" {
            return "documentsvg"
        }
        
        // Check if it's audio
        if ["mp3", "wav", "m4a", "aac"].contains(pathExtension) {
            return "mikesvg" // Use mic icon for audio
        }
        
        // Default to document icon
        return "documentsvg"
    }
}

