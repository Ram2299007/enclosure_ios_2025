//
//  OrientationLockModifier.swift
//  Enclosure
//
//  View modifier to lock screen orientation to portrait
//

import SwiftUI

struct PortraitOrientationModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                // Lock to portrait orientation
                if #available(iOS 16.0, *) {
                    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
                    windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
                } else {
                    // For iOS 15 and below, use UIDevice
                    UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
                }
            }
    }
}

extension View {
    /// Locks the view to portrait orientation
    func lockOrientationToPortrait() -> some View {
        modifier(PortraitOrientationModifier())
    }
}

