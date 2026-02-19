//
//  CustomToggle.swift
//  Enclosure
//
//  Created by Ram Lohar on 29/04/25.
//


import SwiftUI

struct CustomImageToggle: View {
    @Binding var isOn: Bool
    var trackEnabledImage: String
    var trackDisabledImage: String
    var thumbEnabledImage: String?
    var thumbDisabledImage: String?

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            // 🖼️ Track image changes based on isOn
            Image(isOn ? trackEnabledImage : trackDisabledImage)
                .resizable()
                .frame(width: 44, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            // ⚪ Thumb with optional state-specific image
            ZStack {
                Circle()
                    .fill(Color(red: 0xF6/255, green: 0xF7/255, blue: 0xFF/255))
                    .frame(width: 20, height: 20)
                    .shadow(radius: 1)

//                if let imageName = isOn ? thumbEnabledImage : thumbDisabledImage {
//                    Image(systemName: imageName)
//                        .resizable()
//                        .scaledToFit()
//                        .frame(width: 12, height: 12)
//                        .foregroundColor(.black)
//                }
            }
        }
        .scaleEffect(1.3)
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .onTapGesture {
            withAnimation(.easeInOut) {
                isOn.toggle()
            }
        }
    }
}


