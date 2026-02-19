//
//  PermissionsViewController.swift
//  Enclosure
//
//  Professional Permissions View Controller
//  Organized permission management interface similar to Android
//

import UIKit
import UserNotifications
import AVFoundation
import Photos
import Contacts
import Speech
import CoreLocation

/// Professional permissions view controller with organized UI for each permission type
@available(iOS 13.0, *)
class PermissionsViewController: UIViewController {
    
    // MARK: - Properties
    
    var completion: (([PermissionDialogManager.PermissionType: Bool]) -> Void)?
    private var permissionResults: [PermissionDialogManager.PermissionType: Bool] = [:]
    private var permissionCards: [PermissionDialogManager.PermissionType: PermissionCardView] = [:]
    
    // MARK: - UI Components
    
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()
    
    private lazy var contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var mainStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var headerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 16
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 8
        view.layer.shadowOpacity = 0.1
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Permissions Required"
        label.font = UIFont.boldSystemFont(ofSize: 28)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Enclosure needs these permissions to provide the best experience"
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .systemGray
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var permissionsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var actionButtonsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var requestAllButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Request All Permissions", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        button.addTarget(self, action: #selector(requestAllPermissionsTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var continueButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Continue", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.backgroundColor = .systemGray5
        button.setTitleColor(.systemBlue, for: .normal)
        button.layer.cornerRadius = 12
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        button.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupPermissionCards()
        updateContinueButtonState()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Animate cards appearing
        animateCardsAppearance()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        title = "Permissions"
        
        // Add close button for navigation
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeTapped)
        )
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(mainStackView)
        
        // Setup header
        headerView.addSubview(titleLabel)
        headerView.addSubview(subtitleLabel)
        mainStackView.addArrangedSubview(headerView)
        
        // Add permissions section
        mainStackView.addArrangedSubview(permissionsStackView)
        
        // Add action buttons
        actionButtonsStackView.addArrangedSubview(requestAllButton)
        actionButtonsStackView.addArrangedSubview(continueButton)
        mainStackView.addArrangedSubview(actionButtonsStackView)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            mainStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            mainStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            mainStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            mainStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            subtitleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -24)
        ])
    }
    
    private func setupPermissionCards() {
        for permissionType in PermissionDialogManager.PermissionType.allCases {
            let card = PermissionCardView(permissionType: permissionType)
            card.delegate = self
            permissionCards[permissionType] = card
            permissionsStackView.addArrangedSubview(card)
        }
    }
    
    private func animateCardsAppearance() {
        for (index, card) in permissionCards.values.enumerated() {
            card.alpha = 0
            card.transform = CGAffineTransform(translationX: 0, y: 50)
            
            UIView.animate(
                withDuration: 0.6,
                delay: Double(index) * 0.1,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0,
                options: .curveEaseOut,
                animations: {
                    card.alpha = 1
                    card.transform = .identity
                }
            )
        }
    }
    
    // MARK: - Actions
    
    @objc private func requestAllPermissionsTapped() {
        requestAllButton.isEnabled = false
        requestAllButton.setTitle("Requesting...", for: .normal)
        
        PermissionDialogManager.shared.requestMultiplePermissions(
            PermissionDialogManager.PermissionType.allCases,
            from: self
        ) { [weak self] results in
            DispatchQueue.main.async {
                self?.handlePermissionResults(results)
            }
        }
    }
    
    @objc private func continueTapped() {
        completion?(permissionResults)
        dismiss(animated: true)
    }
    
    @objc private func closeTapped() {
        completion?(permissionResults)
        dismiss(animated: true)
    }
    
    // MARK: - Helper Methods
    
    private func handlePermissionResults(_ results: [PermissionDialogManager.PermissionType: Bool]) {
        permissionResults = results
        
        // Update UI with results
        for (type, granted) in results {
            if let card = permissionCards[type] {
                card.updateStatus(granted: granted)
            }
        }
        
        // Reset button
        requestAllButton.isEnabled = true
        requestAllButton.setTitle("Request All Permissions", for: .normal)
        
        // Update continue button
        updateContinueButtonState()
        
        // Show summary
        showPermissionSummary(results)
    }
    
    private func updateContinueButtonState() {
        let hasAnyPermission = permissionResults.values.contains(true)
        continueButton.backgroundColor = hasAnyPermission ? .systemBlue : .systemGray5
        continueButton.setTitleColor(hasAnyPermission ? .white : .systemBlue, for: .normal)
    }
    
    private func showPermissionResults(_ results: [PermissionDialogManager.PermissionType: Bool]) {
        permissionResults = results
        
        for (type, granted) in results {
            if let card = permissionCards[type] {
                card.updateStatus(granted: granted)
            }
        }
        
        updateContinueButtonState()
    }
    
    private func showPermissionSummary(_ results: [PermissionDialogManager.PermissionType: Bool]) {
        let grantedCount = results.values.filter { $0 }.count
        let totalCount = results.count
        
        let alert = UIAlertController(
            title: "Permissions Summary",
            message: "You've granted \(grantedCount) out of \(totalCount) permissions. You can always change these in Settings later.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - PermissionCardViewDelegate

extension PermissionsViewController: PermissionCardViewDelegate {
    func permissionCard(_ card: PermissionCardView, didRequestPermission type: PermissionDialogManager.PermissionType) {
        PermissionDialogManager.shared.requestPermission(type, from: self) { [weak self] granted in
            DispatchQueue.main.async {
                self?.permissionResults[type] = granted
                card.updateStatus(granted: granted)
                self?.updateContinueButtonState()
            }
        }
    }
}

// MARK: - PermissionCardView

class PermissionCardView: UIView {
    
    // MARK: - Properties
    
    let permissionType: PermissionDialogManager.PermissionType
    weak var delegate: PermissionCardViewDelegate?
    
    private let iconLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 32)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 18)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .systemGray
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let requestButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Request", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.heightAnchor.constraint(equalToConstant: 32).isActive = true
        button.widthAnchor.constraint(equalToConstant: 80).isActive = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let headerStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let mainStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // MARK: - Initialization
    
    init(permissionType: PermissionDialogManager.PermissionType) {
        self.permissionType = permissionType
        super.init(frame: .zero)
        setupUI()
        setupInitialState()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        backgroundColor = .systemBackground
        layer.cornerRadius = 16
        layer.borderWidth = 1
        layer.borderColor = UIColor.systemGray5.cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        layer.shadowOpacity = 0.05
        
        // Setup header
        headerStackView.addArrangedSubview(iconLabel)
        headerStackView.addArrangedSubview(titleLabel)
        headerStackView.addArrangedSubview(UIView()) // Spacer
        headerStackView.addArrangedSubview(statusLabel)
        
        // Setup main stack
        mainStackView.addArrangedSubview(headerStackView)
        mainStackView.addArrangedSubview(descriptionLabel)
        mainStackView.addArrangedSubview(requestButton)
        
        addSubview(mainStackView)
        
        NSLayoutConstraint.activate([
            mainStackView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            mainStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            mainStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            mainStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
        
        // Setup button action
        requestButton.addAction(UIAction { [weak self] _ in
            self?.requestButtonTapped()
        }, for: .touchUpInside)
    }
    
    private func setupInitialState() {
        iconLabel.text = permissionType.icon
        titleLabel.text = permissionType.title
        descriptionLabel.text = permissionType.description
        statusLabel.text = "Not Requested"
        statusLabel.textColor = .systemGray
    }
    
    // MARK: - Actions
    
    private func requestButtonTapped() {
        requestButton.isEnabled = false
        requestButton.setTitle("Requesting...", for: .normal)
        
        delegate?.permissionCard(self, didRequestPermission: permissionType)
    }
    
    // MARK: - Public Methods
    
    func updateStatus(granted: Bool) {
        requestButton.isEnabled = true
        
        if granted {
            requestButton.setTitle("Granted ✓", for: .normal)
            requestButton.backgroundColor = .systemGreen
            statusLabel.text = "Granted"
            statusLabel.textColor = .systemGreen
        } else {
            requestButton.setTitle("Denied ✗", for: .normal)
            requestButton.backgroundColor = .systemRed
            statusLabel.text = "Denied"
            statusLabel.textColor = .systemRed
        }
    }
}

// MARK: - PermissionCardViewDelegate Protocol

protocol PermissionCardViewDelegate: AnyObject {
    func permissionCard(_ card: PermissionCardView, didRequestPermission type: PermissionDialogManager.PermissionType)
}
