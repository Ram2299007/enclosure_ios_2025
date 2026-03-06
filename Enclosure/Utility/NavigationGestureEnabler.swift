//
//  NavigationGestureEnabler.swift
//  Enclosure
//
//  Created for enabling interactive pop gesture across all screens
//

import SwiftUI
import UIKit

// Helper to enable interactive pop gesture - matches PopGestureRecognizerSwiftUI approach
struct NavigationGestureEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        // Configure immediately when view controller is created
        DispatchQueue.main.async {
            configureGestures(for: controller)
        }
        
        // Set up periodic checks to ensure gesture stays enabled
        setupPeriodicGestureCheck(controller: controller)
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Only update if view controller's view is loaded and visible
        guard uiViewController.isViewLoaded, uiViewController.view.window != nil else { return }
        
        // Configure immediately and also with a slight delay to catch ScrollViews that load later
        DispatchQueue.main.async {
            configureGestures(for: uiViewController)
        }
        
        // Also configure after a short delay to ensure ScrollViews are fully loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            configureGestures(for: uiViewController)
        }
        
        // Configure again after a longer delay to catch any late changes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            configureGestures(for: uiViewController)
        }
    }
    
    private func setupPeriodicGestureCheck(controller: UIViewController) {
        // Use a timer to periodically check and re-enable the gesture
        // This ensures the gesture stays enabled even after navigation changes
        var checkCount = 0
        let maxChecks = 20 // Check for 2 seconds (20 * 0.1s)
        
        func periodicCheck() {
            guard checkCount < maxChecks else { return }
            checkCount += 1
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                configureGestures(for: controller)
                periodicCheck()
            }
        }
        
        // Start periodic checks
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            periodicCheck()
        }
    }
    
    private func configureGestures(for controller: UIViewController) {
        // Find navigation controller closest to this view
        guard let navController = getCurrentNavigationController(startingAt: controller) else { return }
        
        // Safety check: Ensure navigation controller is still valid
        guard navController.view.window != nil else { return }
        
        // Enable interactive pop gesture
        guard let popGesture = navController.interactivePopGestureRecognizer else { return }
        popGesture.isEnabled = true
        popGesture.delegate = nil
        
        // Configure ScrollView gestures if needed
        guard let topVC = navController.topViewController else { return }
        guard topVC.isViewLoaded, topVC.view.window != nil else { return }
        
        configureScrollViewGestures(in: topVC.view, popGesture: popGesture)
    }
    
    private func getCurrentNavigationController(startingAt controller: UIViewController) -> UINavigationController? {
        if let nav = findNavigationControllerInParents(of: controller) {
            return nav
        }
        
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        
        return findNavigationController(viewController: keyWindow?.rootViewController)
    }
    
    private func findNavigationControllerInParents(of controller: UIViewController) -> UINavigationController? {
        if let nav = controller.navigationController {
            return nav
        }
        
        var currentParent = controller.parent
        while let parent = currentParent {
            if let nav = parent as? UINavigationController {
                return nav
            }
            if let nav = parent.navigationController {
                return nav
            }
            currentParent = parent.parent
        }
        
        return nil
    }
    
    private func findNavigationController(viewController: UIViewController?) -> UINavigationController? {
        guard let viewController = viewController else { return nil }
        
        if let splitViewController = viewController as? UISplitViewController {
            for vc in splitViewController.viewControllers {
                if let navigationController = findNavigationController(viewController: vc) {
                    return navigationController
                }
            }
        }
        
        if let tabBarController = viewController as? UITabBarController {
            if let tabBarViewController = tabBarController.selectedViewController {
                if let navigationController = findNavigationController(viewController: tabBarViewController) {
                    return navigationController
                }
            }
        }
        
        if let presentedViewController = viewController.presentedViewController {
            if let navigationController = findNavigationController(viewController: presentedViewController) {
                return navigationController
            }
        }
        
        for childViewController in viewController.children {
            if let navigationController = findNavigationController(viewController: childViewController) {
                return navigationController
            }
        }
        
        if let navigationController = viewController as? UINavigationController {
            return navigationController
        }
        
        if let navigationController = viewController.navigationController {
            return navigationController
        }
        
        return nil
    }
    
    private func configureScrollViewGestures(in view: UIView, popGesture: UIGestureRecognizer, depth: Int = 0) {
        // Limit recursion depth to prevent stack overflow (max 20 levels)
        guard depth < 20 else { return }
        
        // Safety check: Ensure view is still in hierarchy and not being deallocated
        guard view.window != nil, !view.isHidden, view.superview != nil || depth == 0 else { return }
        
        if let scrollView = view as? UIScrollView {
            // Safety check: Ensure scrollView is still valid
            guard scrollView.window != nil else { return }
            let panGesture = scrollView.panGestureRecognizer
            
            // Only configure if gesture recognizers are valid and attached to views
            if panGesture.view != nil && popGesture.view != nil {
                // Make sure pop gesture is enabled first
                popGesture.isEnabled = true
                // Configure ScrollView to require pop gesture to fail
                panGesture.require(toFail: popGesture)
            }
        }
        
        // Recursively configure subviews with safety check
        // Use a copy of subviews array to avoid issues if subviews change during iteration
        let subviews = view.subviews
        for subview in subviews {
            // Only process subviews that are still in the hierarchy
            if subview.window != nil && !subview.isHidden && subview.superview == view {
                configureScrollViewGestures(in: subview, popGesture: popGesture, depth: depth + 1)
            }
        }
    }
}
