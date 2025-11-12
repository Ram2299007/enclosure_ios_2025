//
//  OpacityModifier.swift
//  Enclosure
//
//  Created by Ram Lohar on 30/04/25.
//

import SwiftUI


struct OpacityModifier: ViewModifier {
    var opacity: Double = 0.5  

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
    }
}
