//
//  ButtonStyles.swift
//  Enclosure
//
//  Shared button styles used across the app
//

import SwiftUI

struct CircularRippleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                ZStack {
                    if configuration.isPressed {
                        Circle()
                            .fill(Color("circlebtnhover").opacity(0.3))
                            .frame(width: 44, height: 44)
                            .scaleEffect(configuration.isPressed ? 1.0 : 0.8)
                            .opacity(configuration.isPressed ? 1.0 : 0.0)
                    }
                }
            )
            .scaleEffect(configuration.isPressed ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

