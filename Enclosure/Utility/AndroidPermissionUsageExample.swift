//
//  AndroidPermissionUsageExample.swift
//  Enclosure
//
//  Usage examples for Android-style permission dialogs
//  Exact match to Android global_permission_popup.xml structure
//

import UIKit

/// Example view controller demonstrating Android-style permission dialog usage
class AndroidPermissionUsageExample: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Android-Style Permissions"
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create buttons for each permission type (matching Android structure)
        let photosButton = createButton(title: "Photos & Videos Permission", action: #selector(showPhotosPermission))
        let notificationsButton = createButton(title: "Notifications Permission", action: #selector(showNotificationsPermission))
        let microphoneButton = createButton(title: "Microphone Permission", action: #selector(showMicrophonePermission))
        let cameraButton = createButton(title: "Camera Permission", action: #selector(showCameraPermission))
        let contactsButton = createButton(title: "Contacts Permission", action: #selector(showContactsPermission))
        let speechButton = createButton(title: "Speech Permission", action: #selector(showSpeechPermission))
        let locationButton = createButton(title: "Location Permission", action: #selector(showLocationPermission))
        
        stackView.addArrangedSubview(photosButton)
        stackView.addArrangedSubview(notificationsButton)
        stackView.addArrangedSubview(microphoneButton)
        stackView.addArrangedSubview(cameraButton)
        stackView.addArrangedSubview(contactsButton)
        stackView.addArrangedSubview(speechButton)
        stackView.addArrangedSubview(locationButton)
        
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    private func createButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
    
    // MARK: - Permission Actions (matching Android structure)
    
    @objc private func showPhotosPermission() {
        // "To send photos, media & files - allow Enclosure to access your device."
        // "Tap Settings > Permission,\nTurn on : Photos & Videos."
        requestPermissionWithAndroidDialog(for: .photos) { granted in
            print("Photos permission result: \(granted)")
        }
    }
    
    @objc private func showNotificationsPermission() {
        // "To receive messages & calls - allow Enclosure to send you notifications."
        // "Tap Settings > Permission,\nTurn on : Notifications."
        requestPermissionWithAndroidDialog(for: .notifications) { granted in
            print("Notifications permission result: \(granted)")
        }
    }
    
    @objc private func showMicrophonePermission() {
        // "To send voice messages & make calls - allow Enclosure to access your microphone."
        // "Tap Settings > Permission,\nTurn on : Microphone."
        requestPermissionWithAndroidDialog(for: .microphone) { granted in
            print("Microphone permission result: \(granted)")
        }
    }
    
    @objc private func showCameraPermission() {
        // "To take photos & videos - allow Enclosure to access your camera."
        // "Tap Settings > Permission,\nTurn on : Camera."
        requestPermissionWithAndroidDialog(for: .camera) { granted in
            print("Camera permission result: \(granted)")
        }
    }
    
    @objc private func showContactsPermission() {
        // "To find your friends - allow Enclosure to access your contacts."
        // "Tap Settings > Permission,\nTurn on : Contacts."
        requestPermissionWithAndroidDialog(for: .contacts) { granted in
            print("Contacts permission result: \(granted)")
        }
    }
    
    @objc private func showSpeechPermission() {
        // "For voice-to-text features - allow Enclosure to access speech recognition."
        // "Tap Settings > Permission,\nTurn on : Speech."
        requestPermissionWithAndroidDialog(for: .speech) { granted in
            print("Speech permission result: \(granted)")
        }
    }
    
    @objc private func showLocationPermission() {
        // "To share your location - allow Enclosure to access your location."
        // "Tap Settings > Permission,\nTurn on : Location."
        requestPermissionWithAndroidDialog(for: .location) { granted in
            print("Location permission result: \(granted)")
        }
    }
}

// MARK: - Integration Guide

/*
 
 ## Android-Style Permission Dialog Integration
 
 ### Exact Match to Android global_permission_popup.xml Structure
 
 The iOS implementation follows the exact same structure as the Android layout:
 
 ```xml
 <!-- Android Structure -->
 <LinearLayout padding="50dp">
     <CardView cornerRadius="20dp">
         <LinearLayout padding="24dp" gravity="center_horizontal">
             <ImageView (60dp x 60dp, 16dp margin bottom) />
             <TextView title (15sp, 3dp line spacing) />
             <TextView subtitle (14sp, 2dp line spacing, 10dp margin top) />
             <LinearLayout buttons (24dp margin top, horizontal)>
                 <Button "Not now" (transparent) />
                 <Button "Settings" (30dp margin start) />
             </LinearLayout>
         </LinearLayout>
     </CardView>
 </LinearLayout>
 ```
 
 ### iOS Implementation Matches Android:
 
 ✅ **50dp padding** around container
 ✅ **20dp corner radius** on card
 ✅ **24dp padding** inside card
 ✅ **60dp x 60dp icon** with 16dp margin bottom
 ✅ **15sp title** with 3dp line spacing, center aligned
 ✅ **14sp subtitle** with 2dp line spacing, 10dp margin top
 ✅ **24dp margin** before buttons
 ✅ **36dp button height** with 30dp spacing
 ✅ **Transparent "Not now" button**
 ✅ **Blue "Settings" button** with white text
 
 ### Usage Examples:
 
 #### 1. Show Permission Dialog (for denied permissions)
 ```swift
 // Shows exact Android-style dialog
 showAndroidPermissionDialog(for: .photos) { granted in
     if granted {
         // User tapped "Settings" - they went to settings
         print("User went to settings")
     } else {
         // User tapped "Not now"
         print("User dismissed")
     }
 }
 ```
 
 #### 2. Request Permission with Dialog (smart flow)
 ```swift
 // Checks status first, shows dialog only if needed
 requestPermissionWithAndroidDialog(for: .notifications) { granted in
     if granted {
         // Permission granted or user went to settings
         enableNotifications()
     } else {
         // Permission denied or user dismissed
         showAlternativeNotificationMethod()
     }
 }
 ```
 
 ### Permission Types with Exact Android Text:
 
 | Permission | Icon | Title Text | Subtitle Text |
 |------------|------|------------|---------------|
 | **Photos** | folder | "To send photos, media & files - allow Enclosure to access your device." | "Tap Settings > Permission,\nTurn on : Photos & Videos." |
 | **Notifications** | bell | "To receive messages & calls - allow Enclosure to send you notifications." | "Tap Settings > Permission,\nTurn on : Notifications." |
 | **Microphone** | mic | "To send voice messages & make calls - allow Enclosure to access your microphone." | "Tap Settings > Permission,\nTurn on : Microphone." |
 | **Camera** | camera | "To take photos & videos - allow Enclosure to access your camera." | "Tap Settings > Permission,\nTurn on : Camera." |
 | **Contacts** | person.2 | "To find your friends - allow Enclosure to access your contacts." | "Tap Settings > Permission,\nTurn on : Contacts." |
 | **Speech** | waveform.and.mic | "For voice-to-text features - allow Enclosure to access speech recognition." | "Tap Settings > Permission,\nTurn on : Speech." |
 | **Location** | location | "To share your location - allow Enclosure to access your location." | "Tap Settings > Permission,\nTurn on : Location." |
 
 ### Visual Match to Android:
 
 - **Same card design** with rounded corners
 - **Same icon size and positioning** (60dp, centered)
 - **Same typography** (15sp title, 14sp subtitle)
 - **Same button layout** (horizontal, "Not now" left, "Settings" right)
 - **Same colors** (transparent "Not now", blue "Settings")
 - **Same spacing** (exact dp to point conversions)
 
 ### Integration in Existing Code:
 
 Replace existing permission requests with Android-style dialogs:
 
 ```swift
 // Old way
 UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, error in
     // Handle result
 }
 
 // New Android-style way
 requestPermissionWithAndroidDialog(for: .notifications) { granted in
     // Handles system request + settings dialog automatically
 }
 ```
 
 This provides a **perfect match** to the Android permission popup experience while being native to iOS.
 
 */
