//
//  FlagRowView.swift
//  Enclosure
//
//  Created by Ram Lohar on 18/03/25.
//


import SwiftUI

struct FlagRowView: View {
    let model: FlagModel

    var body: some View {
        VStack {
            HStack(spacing: 10) { // 🔹 `spacing` कमी केला
                Text(model.country_code)
                    .font(.custom("Inter18pt-SemiBold", size: 15))
                    .frame(width: 50)
                    .foregroundColor(Color("TextColor"))
                    .multilineTextAlignment(.center)

                Text(model.country_name)
                    .font(.custom("Inter18pt-Medium", size: 15))
                    .frame(maxWidth: .infinity)
                    .foregroundColor(Color("TextColor"))
                    .multilineTextAlignment(.center)



                Text("( +\(model.country_c_code) )")
                    .font(.custom("Inter18pt-Medium", size: 15))
                    .frame(width: 80)
                    .foregroundColor(Color("TextColor"))
                    .multilineTextAlignment(.center)

            }
            .padding()
                   .background(
                       RoundedRectangle(cornerRadius: 2)
                           .fill(Color("BackgroundColor"))
                           .overlay(
                               RoundedRectangle(cornerRadius: 2)
                                   .stroke(Color("gray"), lineWidth: 1)
                           )
                   )

        }
    }
}
