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
        HStack(spacing: 0) {
            // Country Code (like "+91") - 80dp width matching Android
            Text("+\(model.country_c_code)")
                .font(.custom("Inter18pt-Medium", size: 14))
                .frame(width: 80, alignment: .leading)
                .foregroundColor(Color("TextColor"))
                .padding(.leading, 10)
            
            // Country Name - takes remaining space
            Text(model.country_name)
                .font(.custom("Inter18pt-Medium", size: 15))
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(Color("TextColor"))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 5)
    }
}
