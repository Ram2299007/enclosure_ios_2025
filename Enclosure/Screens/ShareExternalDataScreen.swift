//
//  ShareExternalDataScreen.swift
//  Enclosure
//
//  Created by Ram Lohar on 30/04/25.
//

import SwiftUI
import AVKit
import UniformTypeIdentifiers

struct ShareExternalDataScreen: View {
    // Shared content data
    let sharedContent: SharedContent
    @State private var caption: String = ""
    @State private var navigateToContactPicker: Bool = false
    @Environment(\.presentationMode) var presentationMode
    
    // Video player state
    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var resizeMode: Int = 0 // 0: FIT, 1: FILL, 2: ZOOM
    
    // Helper function to hide keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Black background (matching Android android:background="@color/black")
                Color.black
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        hideKeyboard()
                    }
                
                // Content based on type
                switch sharedContent.type {
                case .image:
                    imagePreviewView
                case .video:
                    videoPreviewView
                case .document:
                    documentPreviewView
                case .text:
                    textPreviewView
                case .contact:
                    contactPreviewView
                }
                
                // Bottom section with caption and send button (matching Android bottom LinearLayout)
                VStack {
                    Spacer()
                    bottomSection
                }
                
                // Back button (matching Android arrowback LinearLayout)
                VStack {
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
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
                    }
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .background(NavigationGestureEnabler())
            .navigationDestination(isPresented: $navigateToContactPicker) {
                ShareExternalDataContactScreen(
                    sharedContent: sharedContent,
                    caption: caption
                )
            }
        }
    }
    
    // MARK: - Image Preview View
    private var imagePreviewView: some View {
        GeometryReader { geometry in
            if let imageUrl = sharedContent.imageUrls.first {
                CachedAsyncImage(
                    url: imageUrl,
                    content: { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    },
                    placeholder: {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                )
            }
        }
    }
    
    // MARK: - Video Preview View
    private var videoPreviewView: some View {
        GeometryReader { geometry in
            if let videoUrl = sharedContent.videoUrls.first, let player = player {
                VideoPlayer(player: player)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .onAppear {
                        setupVideoPlayer(url: videoUrl)
                    }
            } else if let videoUrl = sharedContent.videoUrls.first {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        setupVideoPlayer(url: videoUrl)
                    }
            }
        }
    }
    
    // MARK: - Document Preview View
    private var documentPreviewView: some View {
        VStack(spacing: 5) {
            // Document name (matching Android docName TextView)
            if let documentName = sharedContent.documentName {
                Text(documentName)
                    .font(.custom("Inter18pt-Medium", size: 22))
                    .foregroundColor(Color("gray3"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            
            // Size text (matching Android size TextView)
            if let documentSize = sharedContent.documentSize {
                Text(documentSize)
                    .font(.custom("Inter18pt-Medium", size: 17))
                    .foregroundColor(Color("gray3"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            
            // Document icon (matching Android document_24 drawable)
            Image("document_24")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .padding(.top, 5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Text Preview View
    private var textPreviewView: some View {
        VStack(spacing: 5) {
            // Text data (matching Android textLinkData TextView)
            if let textData = sharedContent.textData {
                Text(textData)
                    .font(.custom("Inter18pt-Medium", size: 22))
                    .foregroundColor(Color("gray3"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            
            // Text name (matching Android textName TextView)
            if let textName = sharedContent.textName {
                Text(textName)
                    .font(.custom("Inter18pt-Bold", size: 17))
                    .foregroundColor(Color("gray"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .padding(.top, 5)
            }
            
            // Text icon (matching Android textformat drawable)
            Image("textformat")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundColor(Color("gray3"))
                .padding(.top, 15)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Contact Preview View
    private var contactPreviewView: some View {
        VStack {
            if let contact = sharedContent.contact {
                // Contact card (matching Android stroke_contact_row background)
                HStack(spacing: 7) {
                    // Contact avatar circle (matching Android contact_gradient_cirlce)
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(hex: Constant.themeColor),
                                        Color(hex: Constant.themeColor).opacity(0.8)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 55, height: 55)
                        
                        // First letter (matching Android firstText TextView)
                        Text(String(contact.name.prefix(1)).uppercased())
                            .font(.custom("Inter18pt-Regular", size: 16))
                            .foregroundColor(.white)
                    }
                    
                    // Contact name and phone (matching Android cnamenamelyt LinearLayout)
                    VStack(alignment: .leading, spacing: 1) {
                        // Contact name (matching Android cName TextView)
                        Text(contact.name)
                            .font(.custom("Inter18pt-Medium", size: 18))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .frame(maxWidth: 250, alignment: .leading)
                        
                        // Contact phone (matching Android cPhone TextView)
                        Text(contact.phoneNumber)
                            .font(.custom("Inter18pt-Medium", size: 15))
                            .foregroundColor(Color("gray"))
                            .lineLimit(1)
                            .frame(maxWidth: 250, alignment: .leading)
                    }
                    
                    Spacer()
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color("gray3"), lineWidth: 1)
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Bottom Section
    private var bottomSection: some View {
        HStack(spacing: 17) {
            // Caption input (matching Android editLyt LinearLayout and messageBoxMy EditText)
            HStack(spacing: 12) {
                TextField("Add Caption", text: $caption)
                    .font(.custom("Inter18pt-Medium", size: 16))
                    .foregroundColor(Color(hex: "#9EA6B9"))
                    .accentColor(Color(hex: "#9EA6B9"))
                    .lineLimit(4)
                    .frame(maxWidth: 180)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 45)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "#232A2B"))
            )
            .padding(.leading, 10)
            
            // Send button (matching Android sendGrp LinearLayout)
            Button(action: {
                navigateToContactPicker = true
            }) {
                ZStack {
                    Circle()
                        .fill(Color(hex: Constant.themeColor))
                        .frame(width: 50, height: 50)
                    
                    Image("baseline_keyboard_double_arrow_right_24")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.white)
                }
            }
            .padding(.trailing, 10)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 30)
    }
    
    // MARK: - Helper Functions
    private func setupVideoPlayer(url: URL) {
        player = AVPlayer(url: url)
        // Add observer for duration
        if let player = player {
            let timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), queue: .main) { time in
                currentTime = time.seconds
            }
            
            // Get duration
            if let duration = player.currentItem?.asset.duration {
                self.duration = CMTimeGetSeconds(duration)
            }
        }
    }
}

// MARK: - Shared Content Model
struct SharedContent {
    enum ContentType {
        case image
        case video
        case document
        case text
        case contact
    }
    
    var type: ContentType
    var imageUrls: [URL] = []
    var videoUrls: [URL] = []
    var documentUrl: URL?
    var documentName: String?
    var documentSize: String?
    var textData: String?
    var textName: String?
    var contact: ContactInfo?
    
    struct ContactInfo {
        let name: String
        let phoneNumber: String
        let email: String?
    }
}
