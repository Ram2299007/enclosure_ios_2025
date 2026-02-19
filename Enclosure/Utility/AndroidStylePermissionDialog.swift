//
//  AndroidStylePermissionDialog.swift
//  Enclosure
//
//  Android-style Permission Dialog matching exact layout structure
//  Follows global_permission_popup.xml design pattern
//

import UIKit
import UserNotifications
import AVFoundation
import Photos
import Contacts
import Speech
import CoreLocation

/// Android-style permission dialog matching exact layout structure from global_permission_popup.xml
@available(iOS 13.0, *)
class AndroidStylePermissionDialog: UIViewController {
    
    // MARK: - Permission Types with Android-matching data
    
    enum PermissionType: String, CaseIterable {
        case photos = "Photos & Videos"
        case notifications = "Notifications"
        case microphone = "Microphone"
        case camera = "Camera"
        case contacts = "Contacts"
        case speech = "Speech"
        case location = "Location"
        
        var icon: String {
            switch self {
            case .photos: return "folder"
            case .notifications: return "notifications"
            case .microphone: return "mic"
            case .camera: return "camera"
            case .speech: return "speech"
            case .location: return "location"
            case .contacts: return "contacts"
            }
        }
        
        var systemIconName: String {
            switch self {
            case .photos: return "photo.on.rectangle"
            case .notifications: return "bell"
            case .microphone: return "mic"
            case .camera: return "camera"
            case .speech: return "waveform.and.mic"
            case .location: return "location"
            case .contacts: return "person.2"
            }
        }
        
        var title: String {
            switch self {
            case .photos: return "To send photos, media & files - allow Enclosure to access your device."
            case .notifications: return "To receive messages & calls - allow Enclosure to send you notifications."
            case .microphone: return "To send voice messages & make calls - allow Enclosure to access your microphone."
            case .camera: return "To take photos & videos - allow Enclosure to access your camera."
            case .contacts: return "To find your friends - allow Enclosure to access your contacts."
            case .speech: return "For voice-to-text features - allow Enclosure to access speech recognition."
            case .location: return "To share your location - allow Enclosure to access your location."
            }
        }
        
        var subtitle: String {
            switch self {
            case .photos: return "Tap Settings > Permission,\nTurn on : Photos & Videos."
            case .notifications: return "Tap Settings > Permission,\nTurn on : Notifications."
            case .microphone: return "Tap Settings > Permission,\nTurn on : Microphone."
            case .camera: return "Tap Settings > Permission,\nTurn on : Camera."
            case .contacts: return "Tap Settings > Permission,\nTurn on : Contacts."
            case .speech: return "Tap Settings > Permission,\nTurn on : Speech."
            case .location: return "Tap Settings > Permission,\nTurn on : Location."
            }
        }
        
        var settingsPath: String {
            switch self {
            case .photos: return "Photos & Videos"
            case .notifications: return "Notifications"
            case .microphone: return "Microphone"
            case .camera: return "Camera"
            case .contacts: return "Contacts"
            case .speech: return "Speech"
            case .location: return "Location"
            }
        }
    }
    
    // MARK: - Properties
    
    private let permissionType: PermissionType
    private let completion: (Bool) -> Void
    /// When user taps primary button: "Allow" triggers system permission; "Settings" opens app settings. Called after dialog dismisses.
    private let onPrimaryTapped: () -> Void
    private let primaryButtonTitle: String
    
    // MARK: - UI Components (matching Android layout structure)
    
    private lazy var containerStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.distribution = .fill
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    /// Card background matches Android app:cardBackgroundColor="@color/cardBackgroundColornew"
    private lazy var cardView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(named: "cardBackgroundColornew") ?? UIColor.systemBackground
        view.layer.cornerRadius = 20 // 20dp equivalent
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 0)
        view.layer.shadowRadius = 0
        view.layer.shadowOpacity = 0
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var cardStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.distribution = .fill
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // Folder Icon (60dp x 60dp like Android)
    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = UIColor(red: 0.012, green: 0.184, blue: 0.376, alpha: 1.0) // #032F60 equivalent
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // Title (15sp, lineSpacingExtra 3dp - like Android)
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        label.textColor = UIColor(named: "TextColor") ?? UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 3.6
        paragraphStyle.alignment = .center
        let textColor = UIColor(named: "TextColor") ?? UIColor.label
        
        label.attributedText = NSAttributedString(
            string: permissionType.title,
            attributes: [
                .paragraphStyle: paragraphStyle,
                .font: UIFont.systemFont(ofSize: 15, weight: .medium),
                .foregroundColor: textColor
            ]
        )
        
        return label
    }()
    
    // Subtitle / Hint (14sp, lineSpacingExtra 2dp, marginTop 10dp - like Android subtext)
    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor(named: "TextColor") ?? UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 2.4
        paragraphStyle.alignment = .center
        let textColor = UIColor(named: "TextColor") ?? UIColor.label
        
        label.attributedText = NSAttributedString(
            string: permissionType.subtitle,
            attributes: [
                .paragraphStyle: paragraphStyle,
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: textColor
            ]
        )
        
        return label
    }()
    
    // Buttons Row (horizontal, 24dp margin top)
    private lazy var buttonsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fill
        stack.spacing = 30 // 30dp margin start equivalent
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // Not Now Button (36dp height, transparent background, 15sp) - TextColor like Android
    private lazy var notNowButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Not now", for: .normal)
        button.setTitleColor(UIColor(named: "TextColor") ?? UIColor.label, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15)
        button.backgroundColor = UIColor.clear
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(notNowTapped), for: .touchUpInside)
        return button
    }()
    
    // Primary action button (36dp height) - "Allow" or "Settings"; background matches Android button_hover4 / btn_color
    private lazy var primaryButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(primaryButtonTitle, for: .normal)
        button.setTitleColor(UIColor.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15)
        button.backgroundColor = UIColor(named: "btn_color") ?? UIColor.systemBlue
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(primaryTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Initialization
    
    /// - Parameters:
    ///   - permissionType: Type of permission (title/subtitle/icon).
    ///   - primaryButtonTitle: "Allow" (then show system alert) or "Settings" (then open app settings).
    ///   - onPrimaryTapped: Called after dialog dismisses; use to trigger system permission or open Settings.
    init(permissionType: PermissionType, primaryButtonTitle: String, onPrimaryTapped: @escaping () -> Void, completion: @escaping (Bool) -> Void) {
        self.permissionType = permissionType
        self.primaryButtonTitle = primaryButtonTitle
        self.onPrimaryTapped = onPrimaryTapped
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
        setupModalPresentation()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        updateIcon()
    }
    
    // MARK: - Setup
    
    private func setupModalPresentation() {
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
    }
    
    private func setupUI() {
        view.addSubview(containerStackView)
        
        // Add card to container
        containerStackView.addArrangedSubview(cardView)
        cardView.addSubview(cardStackView)
        
        // Add components - exact Android margins: icon 60dp, marginBottom 16dp, title, marginTop 10dp, subtext, marginTop 24dp, buttons 36dp
        cardStackView.addArrangedSubview(iconImageView)
        cardStackView.setCustomSpacing(16, after: iconImageView)
        
        cardStackView.addArrangedSubview(titleLabel)
        cardStackView.setCustomSpacing(10, after: titleLabel)
        
        cardStackView.addArrangedSubview(subtitleLabel)
        cardStackView.setCustomSpacing(24, after: subtitleLabel)
        
        cardStackView.addArrangedSubview(buttonsStackView)
        
        // Add buttons to buttons stack
        buttonsStackView.addArrangedSubview(notNowButton)
        buttonsStackView.addArrangedSubview(primaryButton)
    }
    
    private func setupConstraints() {
        let cardHeight: CGFloat = 300
        // Container: fixed height 100pt; horizontal padding 50pt; centered
        NSLayoutConstraint.activate([
            containerStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 50),
            containerStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -50),
            containerStackView.heightAnchor.constraint(equalToConstant: cardHeight)
        ])
        
        // Card: fills container (so card is 50pt tall)
        let cardPadding: CGFloat = 24
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: containerStackView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: containerStackView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: containerStackView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: containerStackView.bottomAnchor)
        ])
        
        // Card inner: full padding so content fits in 50pt (will clip if too tall)
        NSLayoutConstraint.activate([
            cardStackView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: cardPadding),
            cardStackView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: cardPadding),
            cardStackView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -cardPadding),
            cardStackView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -cardPadding)
        ])
        
        // Icon 60dp x 60dp (Android)
        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 60),
            iconImageView.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        // Buttons 36dp height (Android)
        NSLayoutConstraint.activate([
            notNowButton.heightAnchor.constraint(equalToConstant: 36),
            primaryButton.heightAnchor.constraint(equalToConstant: 36),
            primaryButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])
    }
    
    private func updateIcon() {
        let config = UIImage.SymbolConfiguration(pointSize: 30, weight: .medium)
        iconImageView.image = UIImage(systemName: permissionType.systemIconName, withConfiguration: config)
    }
    
    // MARK: - Actions
    
    @objc private func notNowTapped() {
        completion(false)
        dismiss(animated: true)
    }
    
    /// Primary button: "Allow" → show real permission alert; "Settings" → open app settings. Dismiss first, then run action.
    @objc private func primaryTapped() {
        dismiss(animated: true) { [onPrimaryTapped] in
            onPrimaryTapped()
        }
    }
}

// MARK: - Android Style Permission Manager

@available(iOS 13.0, *)
class AndroidStylePermissionManager {

    static let shared = AndroidStylePermissionManager()

    private init() {}
    
    /// Show Android-style custom dialog first; when user taps primary button, then show real permission alert or open Settings.
    func showPermissionDialog(
        for type: AndroidStylePermissionDialog.PermissionType,
        primaryButtonTitle: String,
        from viewController: UIViewController,
        onPrimaryTapped: @escaping () -> Void,
        completion: @escaping (Bool) -> Void
    ) {
        let permissionDialog = AndroidStylePermissionDialog(
            permissionType: type,
            primaryButtonTitle: primaryButtonTitle,
            onPrimaryTapped: onPrimaryTapped,
            completion: completion
        )
        viewController.present(permissionDialog, animated: true)
    }
    
    /// Custom dialog first; when user taps "Allow", then show real system permission alert. When denied, primary is "Settings".
    func requestPermissionWithDialog(
        for type: AndroidStylePermissionDialog.PermissionType,
        from viewController: UIViewController,
        completion: @escaping (Bool) -> Void
    ) {
        checkPermissionStatus(for: type) { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    completion(true)
                case .denied:
                    self.showPermissionDialog(
                        for: type,
                        primaryButtonTitle: "Settings",
                        from: viewController,
                        onPrimaryTapped: {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                            completion(true)
                        },
                        completion: completion
                    )
                case .notDetermined:
                    self.showPermissionDialog(
                        for: type,
                        primaryButtonTitle: "Allow",
                        from: viewController,
                        onPrimaryTapped: {
                            self.requestSystemPermission(for: type, completion: completion)
                        },
                        completion: completion
                    )
                @unknown default:
                    self.showPermissionDialog(
                        for: type,
                        primaryButtonTitle: "Settings",
                        from: viewController,
                        onPrimaryTapped: {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                            completion(true)
                        },
                        completion: completion
                    )
                }
            }
        }
    }
    
    /// Request permission with custom dialog first (uses top view controller). Call from SwiftUI when no VC available.
    func requestPermissionWithDialogFromTopVC(
        for type: AndroidStylePermissionDialog.PermissionType,
        completion: @escaping (Bool) -> Void
    ) {
        guard let vc = Self.topViewController() else {
            completion(false)
            return
        }
        requestPermissionWithDialog(for: type, from: vc, completion: completion)
    }
    
    /// Top-most view controller for presenting dialogs from SwiftUI.
    static func topViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let root = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?.rootViewController
        }
        return topViewController(from: root)
    }
    
    private static func topViewController(from vc: UIViewController) -> UIViewController {
        if let presented = vc.presentedViewController {
            return topViewController(from: presented)
        }
        if let nav = vc as? UINavigationController, let top = nav.visibleViewController {
            return topViewController(from: top)
        }
        if let tab = vc as? UITabBarController, let sel = tab.selectedViewController {
            return topViewController(from: sel)
        }
        return vc
    }
    
    // MARK: - Permission Status Checking
    
    private func checkPermissionStatus(for type: AndroidStylePermissionDialog.PermissionType, completion: @escaping (UNAuthorizationStatus) -> Void) {
        switch type {
        case .notifications:
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                completion(settings.authorizationStatus)
            }
        case .photos:
            let status = PHPhotoLibrary.authorizationStatus()
            let authStatus: UNAuthorizationStatus
            switch status {
            case .authorized: authStatus = .authorized
            case .denied: authStatus = .denied
            case .limited: authStatus = .authorized
            case .notDetermined: authStatus = .notDetermined
            @unknown default: authStatus = .notDetermined
            }
            completion(authStatus)
        case .microphone:
            let status = AVAudioSession.sharedInstance().recordPermission
            let authStatus: UNAuthorizationStatus
            switch status {
            case .granted: authStatus = .authorized
            case .denied: authStatus = .denied
            @unknown default: authStatus = .notDetermined
            }
            completion(authStatus)
        case .camera:
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            let authStatus: UNAuthorizationStatus
            switch status {
            case .authorized: authStatus = .authorized
            case .denied: authStatus = .denied
            case .notDetermined: authStatus = .notDetermined
            @unknown default: authStatus = .notDetermined
            }
            completion(authStatus)
        case .contacts:
            let status = CNContactStore.authorizationStatus(for: .contacts)
            let authStatus: UNAuthorizationStatus
            switch status {
            case .authorized: authStatus = .authorized
            case .denied: authStatus = .denied
            case .notDetermined: authStatus = .notDetermined
            @unknown default: authStatus = .notDetermined
            }
            completion(authStatus)
        case .speech:
            // Speech permission doesn't have a direct status check, assume not determined
            completion(.notDetermined)
        case .location:
            // Location permission would need CLLocationManager
            completion(.notDetermined)
        }
    }
    
    private func requestSystemPermission(for type: AndroidStylePermissionDialog.PermissionType, completion: @escaping (Bool) -> Void) {
        switch type {
        case .notifications:
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, _ in
                if granted {
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
                completion(granted)
            }
        case .photos:
            PHPhotoLibrary.requestAuthorization { status in
                completion(status == .authorized)
            }
        case .microphone:
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                completion(granted)
            }
        case .camera:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted)
            }
        case .contacts:
            CNContactStore().requestAccess(for: .contacts) { granted, _ in
                completion(granted)
            }
        case .speech:
            SFSpeechRecognizer.requestAuthorization { status in
                completion(status == .authorized)
            }
        case .location:
            // Location permission would need CLLocationManager
            completion(false)
        }
    }
}

// MARK: - UIViewController Extension

extension UIViewController {
    
    /// Request permission: show Android-style custom dialog first; on "Allow" show real system permission alert.
    func requestPermissionWithAndroidDialog(
        for type: AndroidStylePermissionDialog.PermissionType,
        completion: @escaping (Bool) -> Void
    ) {
        AndroidStylePermissionManager.shared.requestPermissionWithDialog(for: type, from: self, completion: completion)
    }
}
