//
//  PermissionUsageExample.swift
//  Enclosure
//
//  Example usage of original permission system
//  Shows how to use standard iOS permission requests
//

import UIKit
import AVFoundation
import UserNotifications

/// Example view controller demonstrating professional permission dialog usage
class PermissionUsageExample: UIViewController {
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Permission Examples"
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create buttons for different permission scenarios
        let singlePermissionButton = createButton(title: "Request Notification Permission", action: #selector(requestSinglePermission))
        let multiplePermissionButton = createButton(title: "Request Multiple Permissions", action: #selector(requestMultiplePermissions))
        let allPermissionsButton = createButton(title: "Show All Permissions Dialog", action: #selector(showAllPermissionsDialog))
        let contactsSyncButton = createButton(title: "Sync Contacts (with permission)", action: #selector(syncContactsWithPermission))
        
        stackView.addArrangedSubview(singlePermissionButton)
        stackView.addArrangedSubview(multiplePermissionButton)
        stackView.addArrangedSubview(allPermissionsButton)
        stackView.addArrangedSubview(contactsSyncButton)
        
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
    
    // MARK: - Permission Examples
    
    @objc private func requestSinglePermission() {
        // Example: Request notification permission using original method
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                let message = granted ? "Notification permission granted! 🎉" : "Notification permission denied."
                self.showAlert(title: "Permission Result", message: message)
            }
        }
    }
    
    @objc private func requestMultiplePermissions() {
        // Example: Request multiple permissions using original methods
        // Notifications
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { notificationGranted, _ in
            // Microphone
            AVAudioSession.sharedInstance().requestRecordPermission { microphoneGranted in
                // Camera
                AVCaptureDevice.requestAccess(for: .video) { cameraGranted in
                    DispatchQueue.main.async {
                        let message = """
                        Permission Results:
                        🔔 Notifications: \(notificationGranted ? "✅ Granted" : "❌ Denied")
                        🎤 Microphone: \(microphoneGranted ? "✅ Granted" : "❌ Denied")
                        📷 Camera: \(cameraGranted ? "✅ Granted" : "❌ Denied")
                        """
                        self.showAlert(title: "Multiple Permissions", message: message)
                    }
                }
            }
        }
    }
    
    @objc private func showAllPermissionsDialog() {
        // Example: Show permission status for all types
        DispatchQueue.main.async {
            let message = "All permissions dialog was reverted. Use individual permission requests instead."
            self.showAlert(title: "All Permissions", message: message)
        }
    }
    
    @objc private func syncContactsWithPermission() {
        // Example: Sync contacts using original method
        ContactSyncManager.shared.syncContacts { [weak self] (result: Result<Void, ContactSyncManager.SyncError>) in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.showAlert(title: "Contact Sync", message: "Contacts synced successfully! 🎉")
                case .failure(let error):
                    self.showAlert(title: "Contact Sync Failed", message: error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Integration Guide

/*
 
 ## How to Integrate Professional Permission Dialogs
 
 ### 1. Basic Usage (Single Permission)
 
 ```swift
 // In any UIViewController
 requestPermission(.notifications) { granted in
     if granted {
         // Permission granted - proceed with feature
         enableNotifications()
     } else {
         // Permission denied - show alternative or explain why needed
         showNotificationExplanation()
     }
 }
 ```
 
 ### 2. Multiple Permissions
 
 ```swift
 let permissions: [PermissionDialogManager.PermissionType] = [.notifications, .microphone, .camera]
 
 PermissionDialogManager.shared.requestMultiplePermissions(permissions, from: self) { results in
     for (type, granted) in results {
         if granted {
             enableFeature(type)
         }
     }
 }
 ```
 
 ### 3. Comprehensive Permissions Dialog
 
 ```swift
 PermissionDialogManager.shared.showAllPermissionsDialog(from: self) { results in
     // Handle all permission results
     updateUIBasedOnPermissions(results)
 }
 ```
 
 ### 4. Service Integration (Contacts, etc.)
 
 ```swift
 // Updated ContactSyncManager usage
 ContactSyncManager.shared.syncContacts(from: self) { result in
     switch result {
     case .success:
         showSuccessMessage()
     case .failure(let error):
         showErrorMessage(error.localizedDescription)
     }
 }
 ```
 
 ### 5. FirebaseManager Integration
 
 The FirebaseManager now automatically uses professional permission dialogs:
 
 ```swift
 // No changes needed - FirebaseManager.requestNotificationPermissions()
 // now uses PermissionDialogManager automatically
 ```
 
 ## Features Included:
 
 ✅ **Professional UI**: Organized cards with icons and descriptions
 ✅ **Educational Content**: Detailed rationale for each permission
 ✅ **Status Tracking**: Visual feedback for granted/denied permissions
 ✅ **Settings Integration**: Direct link to app settings for denied permissions
 ✅ **Fallback Support**: Graceful degradation if no view controller available
 ✅ **Comprehensive Dialog**: All permissions in one beautiful interface
 ✅ **Android-like Organization**: Similar to Android permission dialogs
 ✅ **Accessibility Support**: Proper labels and semantic markup
 ✅ **iOS 13+ Compatibility**: Modern UI with sheet presentations
 
 ## Permission Types Supported:
 
 - 🔔 **Notifications**: Messages, calls, updates
 - 🎤 **Microphone**: Voice messages, voice calls
 - 📷 **Camera**: Photos, videos, QR codes
 - 🖼️ **Photos**: Gallery access, media sharing
 - 👥 **Contacts**: Find friends, sync address book
 - 🗣️ **Speech**: Voice-to-text, accessibility
 - 📍 **Location**: Location sharing, nearby features
 
 ## Best Practices:
 
 1. **Request permissions in context** - Ask when the feature is needed
 2. **Explain the benefit** - Users get clear rationale for each permission
 3. **Handle gracefully** - Provide alternatives when permissions are denied
 4. **Use professional dialogs** - Consistent UI across the app
 5. **Test all scenarios** - Granted, denied, restricted, and fallback cases
 
 */
