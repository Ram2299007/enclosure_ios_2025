//
//  SnackbarView.swift
//  Enclosure
//
//  Created by Ram Lohar on 19/03/25.
//


import SwiftUI

struct SnackbarView: View {
    var message: String
    var backgroundColor: Color = Color.black

    var body: some View {
        Text(message)
            .foregroundColor(.white)
            .padding()
            .background(backgroundColor)
            .cornerRadius(10)
            .shadow(radius: 10)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
    }
}
