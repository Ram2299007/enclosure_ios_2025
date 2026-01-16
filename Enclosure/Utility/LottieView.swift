//
//  LottieView.swift
//  Enclosure
//
//  Created for typing indicator functionality
//

import SwiftUI

#if canImport(Lottie)
import Lottie
struct LottieView: UIViewRepresentable {
    let animationName: String
    var loopMode: LottieLoopMode
    var speed: CGFloat = 1.0
    
    init(animationName: String, loopMode: LottieLoopMode = .loop, speed: CGFloat = 1.0) {
        self.animationName = animationName
        self.loopMode = loopMode
        self.speed = speed
    }
    
    func makeUIView(context: Context) -> UIView {
        print("🎬 [LottieView] makeUIView called for animation: \(animationName)")
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        
        let animationView = LottieAnimationView()
        animationView.backgroundColor = .clear
        
        var animationLoaded = false
        
        // Try multiple methods to load the animation
        // Method 1: Try loading from Lottie subdirectory
        if let url = Bundle.main.url(forResource: animationName, withExtension: "json", subdirectory: "Lottie") {
            animationView.animation = LottieAnimation.filepath(url.path)
            if animationView.animation != nil {
                animationLoaded = true
                print("✅ [LottieView] Loaded animation from Lottie subdirectory: \(animationName)")
            }
        }
        
        // Method 2: Try loading from main bundle root
        if !animationLoaded, let animation = LottieAnimation.named(animationName) {
            animationView.animation = animation
            animationLoaded = true
            print("✅ [LottieView] Loaded animation from main bundle: \(animationName)")
        }
        
        // Method 3: Try loading with full path
        if !animationLoaded {
            if let path = Bundle.main.path(forResource: animationName, ofType: "json", inDirectory: "Lottie") {
                animationView.animation = LottieAnimation.filepath(path)
                if animationView.animation != nil {
                    animationLoaded = true
                    print("✅ [LottieView] Loaded animation from path: \(path)")
                }
            }
        }
        
        // Method 4: Try loading from Enclosure/Lottie path
        if !animationLoaded {
            let possiblePaths = [
                Bundle.main.path(forResource: animationName, ofType: "json", inDirectory: "Enclosure/Lottie"),
                Bundle.main.path(forResource: animationName, ofType: "json")
            ]
            
            for path in possiblePaths.compactMap({ $0 }) {
                if let animation = LottieAnimation.filepath(path) {
                    animationView.animation = animation
                    animationLoaded = true
                    print("✅ [LottieView] Loaded animation from alternative path: \(path)")
                    break
                }
            }
        }
        
        if !animationLoaded {
            print("🚫 [LottieView] Failed to load animation: \(animationName)")
            print("   Searched in: Lottie subdirectory, main bundle, and alternative paths")
            
            // Debug: List all JSON files in bundle
            if let resourcePath = Bundle.main.resourcePath {
                print("   Bundle resource path: \(resourcePath)")
                let fileManager = FileManager.default
                if let enumerator = fileManager.enumerator(atPath: resourcePath) {
                    var jsonFiles: [String] = []
                    while let file = enumerator.nextObject() as? String {
                        if file.hasSuffix(".json") && file.contains("modern") {
                            jsonFiles.append(file)
                        }
                    }
                    if !jsonFiles.isEmpty {
                        print("   Found JSON files in bundle: \(jsonFiles)")
                    } else {
                        print("   ⚠️ No modern JSON files found in bundle!")
                    }
                }
            }
            
            // Add a placeholder view so something is visible
            let placeholderView = UIView(frame: .zero)
            placeholderView.backgroundColor = UIColor.systemGray.withAlphaComponent(0.3)
            placeholderView.layer.cornerRadius = 25
            placeholderView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(placeholderView)
            NSLayoutConstraint.activate([
                placeholderView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                placeholderView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                placeholderView.widthAnchor.constraint(equalToConstant: 50),
                placeholderView.heightAnchor.constraint(equalToConstant: 50)
            ])
            return view
        }
        
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = loopMode
        animationView.animationSpeed = speed
        
        // Set background to clear
        animationView.backgroundColor = .clear
        
        animationView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(animationView)
        
        NSLayoutConstraint.activate([
            animationView.topAnchor.constraint(equalTo: view.topAnchor),
            animationView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            animationView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Ensure the view has a proper frame
        view.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        
        // Start playing the animation with completion handler
        animationView.play { finished in
            if finished {
                print("✅ [LottieView] Animation finished playing")
            }
        }
        
        // Also ensure it's playing
        if !animationView.isAnimationPlaying {
            animationView.play()
        }
        
        print("✅ [LottieView] Animation view configured - isPlaying: \(animationView.isAnimationPlaying), hasAnimation: \(animationView.animation != nil)")
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Find the LottieAnimationView and ensure it's playing
        for subview in uiView.subviews {
            if let animationView = subview as? LottieAnimationView {
                if animationView.animation != nil {
                    if !animationView.isAnimationPlaying {
                        print("🔄 [LottieView] Restarting animation in updateUIView")
                        animationView.play()
                    }
                } else {
                    print("⚠️ [LottieView] Animation is nil in updateUIView")
                }
                return
            }
        }
    }
}
#else
// Fallback view when Lottie is not available
struct LottieView: UIViewRepresentable {
    let animationName: String
    var loopMode: Int // Placeholder - will be LottieLoopMode when package is added
    var speed: CGFloat = 1.0
    
    init(animationName: String, loopMode: Int = 0, speed: CGFloat = 1.0) {
        self.animationName = animationName
        self.loopMode = loopMode
        self.speed = speed
    }
    
    func makeUIView(context: Context) -> UIView {
        print("⚠️ [LottieView] FALLBACK VIEW - Lottie package not available!")
        print("   Animation name requested: \(animationName)")
        print("   To fix: File → Add Package Dependencies → https://github.com/airbnb/lottie-ios.git")
        
        // Create a visible placeholder so user knows something should be there
        let view = UIView(frame: .zero)
        view.backgroundColor = UIColor.systemGray.withAlphaComponent(0.2)
        view.layer.cornerRadius = 25
        
        // Add a label to indicate Lottie is missing
        let label = UILabel()
        label.text = "⋯"
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textColor = UIColor.systemGray
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            view.widthAnchor.constraint(equalToConstant: 50),
            view.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update if needed
    }
}
#endif

// Helper function to get Lottie animation name based on theme color
func getTypingIndicatorAnimationName(for themeColor: String) -> String {
    switch themeColor {
    case "#ff0080":
        return "pink_modern"
    case "#00A3E9":
        return "ec_modern"
    case "#7adf2a":
        return "popati_modern"
    case "#ec0001":
        return "red_modern"
    case "#16f3ff":
        return "blue_light_modern"
    case "#FF8A00":
        return "orange_modern"
    case "#7F7F7F":
        return "gray_modern"
    case "#D9B845":
        return "yellow_modern"
    case "#346667":
        return "richgreen_modern"
    case "#9846D9":
        return "ec_modern"
    case "#A81010":
        return "voilet_modern"
    default:
        return "red2_modern"
    }
}

