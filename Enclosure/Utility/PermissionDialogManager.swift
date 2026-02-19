//
//  PermissionDialogManager.swift
//  Enclosure
//
//  Professional Permission Dialog Manager
//  Organized dialogue boxes for each permission type similar to Android
//

import Foundation
import UIKit
import UserNotifications
import AVFoundation
import Photos
import Contacts
import Speech
import CoreLocation

/// Professional permission dialog manager with organized UI for each permission type
@available(iOS 13.0, *)
class PermissionDialogManager: NSObject {
    
    static let shared = PermissionDialogManager()
    
    private var currentViewController: UIViewController?
    private var permissionCompletionHandlers: [PermissionType: (Bool) -> Void] = [:]
    
    private override init() {
        super.init()
    }
    
    // MARK: - Permission Types
    
    enum PermissionType: String, CaseIterable {
        case notifications = "Notifications"
        case microphone = "Microphone"
        case camera = "Camera"
        case photos = "Photos"
        case contacts = "Contacts"
        case speech = "Speech"
        case location = "Location"
        
        var icon: String {
            switch self {
            case .notifications: return "🔔"
            case .microphone: return "🎤"
            case .camera: return "📷"
            case .photos: return "🖼️"
            case .contacts: return "👥"
            case .speech: return "🗣️"
            case .location: return "📍"
            }
        }
        
        var systemIconName: String {
            switch self {
            case .notifications: return "bell.fill"
            case .microphone: return "mic.fill"
            case .camera: return "camera.fill"
            case .photos: return "photo.fill"
            case .contacts: return "person.2.fill"
            case .speech: return "waveform.and.mic.fill"
            case .location: return "location.fill"
            }
        }
        
        var title: String {
            switch self {
            case .notifications: return "Notifications"
            case .microphone: return "Microphone Access"
            case .camera: return "Camera Access"
            case .photos: return "Photo Library Access"
            case .contacts: return "Contact Access"
            case .speech: return "Speech Recognition"
            case .location: return "Location Access"
            }
        }
        
        var description: String {
            switch self {
            case .notifications: return "Receive messages, calls, and important updates"
            case .microphone: return "Send voice messages and make voice calls"
            case .camera: return "Take photos and videos to share"
            case .photos: return "Access your photo library to share images and videos"
            case .contacts: return "Find friends who are already using Enclosure"
            case .speech: return "Convert speech to text for messaging"
            case .location: return "Share your location with contacts"
            }
        }
        
        var rationale: String {
            switch self {
            case .notifications:
                return """
                • Get instant alerts for new messages
                • Never miss important calls
                • Stay updated with friend activities
                • Receive delivery confirmations
                """
            case .microphone:
                return """
                • Send voice messages to friends
                • Make crystal-clear voice calls
                • Record audio notes
                • Use voice-to-text features
                """
            case .camera:
                return """
                • Capture photos to share instantly
                • Record videos for friends
                • Scan QR codes
                • Take profile pictures
                """
            case .photos:
                return """
                • Share memories from your gallery
                • Save received photos and videos
                • Create custom media albums
                • Backup important images
                """
            case .contacts:
                return """
                • Find friends already on Enclosure
                • Sync your address book automatically
                • Suggest contacts to connect with
                • Import contact information
                """
            case .speech:
                return """
                • Convert voice messages to text
                • Dictate messages hands-free
                • Voice-controlled navigation
                • Accessibility support
                """
            case .location:
                return """
                • Share your live location
                • Find nearby friends
                • Location-based features
                • Emergency location sharing
                """
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Set the current view controller for presenting dialogs
    func setViewController(_ viewController: UIViewController) {
        self.currentViewController = viewController
    }
    
    /// Request a specific permission with professional dialog
    func requestPermission(
        _ type: PermissionType,
        from viewController: UIViewController? = nil,
        completion: @escaping (Bool) -> Void
    ) {
        let presentingVC = viewController ?? currentViewController ?? UIApplication.shared.windows.first?.rootViewController
        
        guard let vc = presentingVC else {
            print("🚫 [PermissionDialog] No view controller available to present dialog")
            completion(false)
            return
        }
        
        permissionCompletionHandlers[type] = completion
        
        // Check current status first
        checkPermissionStatus(type) { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("✅ [PermissionDialog] \(type.rawValue) already authorized")
                    completion(true)
                case .denied:
                    PermissionDialogManager.shared.showPermissionDeniedDialog(type: type, from: vc)
                case .notDetermined:
                    PermissionDialogManager.shared.showPermissionRequestDialog(type: type, from: vc)
                @unknown default:
                    PermissionDialogManager.shared.showPermissionRequestDialog(type: type, from: vc)
                }
            }
        }
    }
    
    /// Request multiple permissions in sequence
    func requestMultiplePermissions(
        _ types: [PermissionType],
        from viewController: UIViewController? = nil,
        completion: @escaping ([PermissionType: Bool]) -> Void
    ) {
        var results: [PermissionType: Bool] = [:]
        var remainingTypes = types
        var currentIndex = 0
        
        func requestNext() {
            guard currentIndex < remainingTypes.count else {
                completion(results)
                return
            }
            
            let type = remainingTypes[currentIndex]
            currentIndex += 1
            
            requestPermission(type, from: viewController) { [weak self] granted in
                results[type] = granted
                requestNext()
            }
        }
        
        requestNext()
    }
    
    /// Show all permissions in a comprehensive dialog
    func showAllPermissionsDialog(
        from viewController: UIViewController? = nil,
        completion: @escaping ([PermissionType: Bool]) -> Void
    ) {
        let presentingVC = viewController ?? currentViewController ?? UIApplication.shared.windows.first?.rootViewController
        
        guard let vc = presentingVC else {
            print("🚫 [PermissionDialog] No view controller available")
            completion([:])
            return
        }
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let permissionsVC = storyboard.instantiateViewController(withIdentifier: "PermissionsViewController") as? PermissionsViewController {
            permissionsVC.completion = completion
            permissionsVC.modalPresentationStyle = .pageSheet
            
            // Customize for iOS 13+ with modern presentation
            if #available(iOS 15.0, *) {
                permissionsVC.sheetPresentationController?.detents = [.large(), .medium()]
                permissionsVC.sheetPresentationController?.prefersGrabberVisible = true
            }
            
            vc.present(permissionsVC, animated: true)
        } else {
            // Fallback: create permissions dialog programmatically
            createProgrammaticPermissionsDialog(from: vc, completion: completion)
        }
    }
    
    // MARK: - Private Methods
    
    private func checkPermissionStatus(_ type: PermissionType, completion: @escaping (UNAuthorizationStatus) -> Void) {
        switch type {
        case .notifications:
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                completion(settings.authorizationStatus)
            }
        default:
            // For other permissions, we'll use a simplified status check
            completion(.notDetermined)
        }
    }
    
    private func showPermissionRequestDialog(type: PermissionType, from viewController: UIViewController) {
        let alert = createPermissionRequestAlert(type: type)
        viewController.present(alert, animated: true)
    }
    
    private func showPermissionDeniedDialog(type: PermissionType, from viewController: UIViewController) {
        let alert = createPermissionDeniedAlert(type: type)
        viewController.present(alert, animated: true)
    }
    
    private func showPermissionRestrictedDialog(type: PermissionType, from viewController: UIViewController) {
        let alert = createPermissionRestrictedAlert(type: type)
        viewController.present(alert, animated: true)
    }
    
    private func createPermissionRequestAlert(type: PermissionType) -> UIAlertController {
        let alert = UIAlertController(
            title: "\(type.icon) \(type.title)",
            message: createPermissionMessage(type: type),
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(
            title: "Continue",
            style: .default,
            handler: { [weak self] _ in
                self?.actuallyRequestPermission(type)
            }
        ))
        
        alert.addAction(UIAlertAction(
            title: "Not Now",
            style: .cancel,
            handler: { [weak self] _ in
                self?.permissionCompletionHandlers[type]?(false)
                self?.permissionCompletionHandlers.removeValue(forKey: type)
            }
        ))
        
        // Add "Learn More" action for detailed rationale
        alert.addAction(UIAlertAction(
            title: "Learn More",
            style: .default,
            handler: { [weak self] _ in
                self?.showDetailedRationale(type: type)
            }
        ))
        
        return alert
    }
    
    private func createPermissionDeniedAlert(type: PermissionType) -> UIAlertController {
        let alert = UIAlertController(
            title: "\(type.icon) Permission Required",
            message: "\(type.title) permission was previously denied. To enable this feature, please go to Settings and allow access.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(
            title: "Open Settings",
            style: .default,
            handler: { _ in
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
        ))
        
        alert.addAction(UIAlertAction(
            title: "Cancel",
            style: .cancel,
            handler: { [weak self] _ in
                self?.permissionCompletionHandlers[type]?(false)
                self?.permissionCompletionHandlers.removeValue(forKey: type)
            }
        ))
        
        return alert
    }
    
    private func createPermissionRestrictedAlert(type: PermissionType) -> UIAlertController {
        let alert = UIAlertController(
            title: "\(type.icon) Permission Restricted",
            message: "\(type.title) access is restricted by your device settings. This feature cannot be enabled without changing system-level restrictions.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(
            title: "OK",
            style: .default,
            handler: { [weak self] _ in
                self?.permissionCompletionHandlers[type]?(false)
                self?.permissionCompletionHandlers.removeValue(forKey: type)
            }
        ))
        
        return alert
    }
    
    private func createPermissionMessage(type: PermissionType) -> String {
        return """
        \(type.description)
        
        This permission allows us to:
        \(type.rationale)
        """
    }
    
    private func showDetailedRationale(type: PermissionType) {
        let alert = UIAlertController(
            title: "\(type.icon) Why We Need \(type.title)",
            message: type.rationale,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(
            title: "Got it",
            style: .default,
            handler: { [weak self] _ in
                // Show the original permission dialog again
                if let vc = self?.currentViewController {
                    let permissionAlert = self?.createPermissionRequestAlert(type: type)
                    vc.present(permissionAlert!, animated: true)
                }
            }
        ))
        
        currentViewController?.present(alert, animated: true)
    }
    
    private func actuallyRequestPermission(_ type: PermissionType) {
        switch type {
        case .notifications:
            requestNotificationPermission()
        case .microphone:
            requestMicrophonePermission()
        case .camera:
            requestCameraPermission()
        case .photos:
            requestPhotosPermission()
        case .contacts:
            requestContactsPermission()
        case .speech:
            requestSpeechPermission()
        case .location:
            requestLocationPermission()
        }
    }
    
    // MARK: - Individual Permission Requests
    
    private func requestNotificationPermission() {
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { [weak self] granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("🚫 [PermissionDialog] Notification permission error: \(error.localizedDescription)")
                }
                
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                
                self?.permissionCompletionHandlers[.notifications]?(granted)
                self?.permissionCompletionHandlers.removeValue(forKey: .notifications)
            }
        }
    }
    
    private func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.permissionCompletionHandlers[.microphone]?(granted)
                self?.permissionCompletionHandlers.removeValue(forKey: .microphone)
            }
        }
    }
    
    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.permissionCompletionHandlers[.camera]?(granted)
                self?.permissionCompletionHandlers.removeValue(forKey: .camera)
            }
        }
    }
    
    private func requestPhotosPermission() {
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                let granted = status == .authorized
                self?.permissionCompletionHandlers[.photos]?(granted)
                self?.permissionCompletionHandlers.removeValue(forKey: .photos)
            }
        }
    }
    
    private func requestContactsPermission() {
        CNContactStore().requestAccess(for: .contacts) { [weak self] granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("🚫 [PermissionDialog] Contacts permission error: \(error.localizedDescription)")
                }
                self?.permissionCompletionHandlers[.contacts]?(granted)
                self?.permissionCompletionHandlers.removeValue(forKey: .contacts)
            }
        }
    }
    
    private func requestSpeechPermission() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                let granted = status == .authorized
                self?.permissionCompletionHandlers[.speech]?(granted)
                self?.permissionCompletionHandlers.removeValue(forKey: .speech)
            }
        }
    }
    
    private func requestLocationPermission() {
        // This would need to be implemented based on specific location needs
        // For now, just return false as location isn't currently used
        permissionCompletionHandlers[.location]?(false)
        permissionCompletionHandlers.removeValue(forKey: .location)
    }
    
    private func createProgrammaticPermissionsDialog(
        from viewController: UIViewController,
        completion: @escaping ([PermissionType: Bool]) -> Void
    ) {
        let containerVC = UIViewController()
        containerVC.modalPresentationStyle = .pageSheet
        
        // Create scroll view with all permissions
        let scrollView = UIScrollView()
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.distribution = .fill
        
        scrollView.addSubview(stackView)
        containerVC.view.addSubview(scrollView)
        
        // Setup constraints
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: containerVC.view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: containerVC.view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerVC.view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerVC.view.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
        
        // Add title
        let titleLabel = UILabel()
        titleLabel.text = "Permissions Required"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textAlignment = .center
        stackView.addArrangedSubview(titleLabel)
        
        // Add permission cards
        var results: [PermissionType: Bool] = [:]
        
        for type in PermissionType.allCases {
            let permissionCard = createPermissionCard(type: type) { granted in
                results[type] = granted
                if results.count == PermissionType.allCases.count {
                    completion(results)
                }
            }
            stackView.addArrangedSubview(permissionCard)
        }
        
        // Add close button
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Done", for: .normal)
        closeButton.backgroundColor = .systemBlue
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.layer.cornerRadius = 8
        closeButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        
        closeButton.addAction(UIAction { _ in
            completion(results)
            containerVC.dismiss(animated: true)
        }, for: .touchUpInside)
        
        stackView.addArrangedSubview(closeButton)
        
        viewController.present(containerVC, animated: true)
    }
    
    private func createPermissionCard(type: PermissionType, completion: @escaping (Bool) -> Void) -> UIView {
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 12
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.systemGray4.cgColor
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Header
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.spacing = 12
        headerStack.alignment = .center
        
        let iconLabel = UILabel()
        iconLabel.text = type.icon
        iconLabel.font = UIFont.systemFont(ofSize: 24)
        
        let titleLabel = UILabel()
        titleLabel.text = type.title
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        let statusLabel = UILabel()
        statusLabel.text = "Not Requested"
        statusLabel.font = UIFont.systemFont(ofSize: 14)
        statusLabel.textColor = .systemGray
        statusLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        headerStack.addArrangedSubview(iconLabel)
        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(statusLabel)
        
        // Description
        let descLabel = UILabel()
        descLabel.text = type.description
        descLabel.font = UIFont.systemFont(ofSize: 14)
        descLabel.textColor = .systemGray
        descLabel.numberOfLines = 0
        
        // Request button
        let requestButton = UIButton(type: .system)
        requestButton.setTitle("Request Permission", for: .normal)
        requestButton.backgroundColor = .systemBlue
        requestButton.setTitleColor(.white, for: .normal)
        requestButton.layer.cornerRadius = 6
        requestButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
        
        requestButton.addAction(UIAction { [weak self] _ in
            requestButton.isEnabled = false
            requestButton.setTitle("Requesting...", for: .normal)
            
            self?.requestPermission(type) { granted in
                DispatchQueue.main.async {
                    requestButton.isEnabled = true
                    requestButton.setTitle(granted ? "Granted ✓" : "Denied ✗", for: .normal)
                    requestButton.backgroundColor = granted ? .systemGreen : .systemRed
                    statusLabel.text = granted ? "Granted" : "Denied"
                    statusLabel.textColor = granted ? .systemGreen : .systemRed
                    completion(granted)
                }
            }
        }, for: .touchUpInside)
        
        stackView.addArrangedSubview(headerStack)
        stackView.addArrangedSubview(descLabel)
        stackView.addArrangedSubview(requestButton)
        
        card.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        
        return card
    }
}

// MARK: - Permission Status Enum

extension PermissionDialogManager {
    enum PermissionStatus {
        case authorized
        case denied
        case notDetermined
        case restricted
    }
}

// MARK: - UIViewController Extension

extension UIViewController {
    func requestPermission(_ type: PermissionDialogManager.PermissionType, completion: @escaping (Bool) -> Void) {
        PermissionDialogManager.shared.setViewController(self)
        PermissionDialogManager.shared.requestPermission(type, completion: completion)
    }
}
