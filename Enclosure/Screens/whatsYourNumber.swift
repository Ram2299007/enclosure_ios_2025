//
//  whatsYourNumber.swift
//  Enclosure
//
//  Created by Ram Lohar on 16/03/25.
//

import SwiftUI

struct whatsYourNumber: View {
    @State private var phoneNumber: String = ""
    @State private var isChecked: Bool = false
    @StateObject private var viewModel = SendOTPViewModel()
    @Environment(\.colorScheme) var colorScheme
    // 🏳️ Selected Country Details
    @State private var selectedCountryCode: String = "+1"
    @State private var selectedCountryShortCode: String = "US"
    @State private var selectedCountryID: String = "502"
    @State private var shakeOffset: CGFloat = 0
    @State private var phoneError: String? = nil  // Error message for phone number
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("What’s your\nnumber?")
                            .font(.custom("Inter18pt-SemiBold", size: 40))
                            .foregroundColor(Color("TextColor"))
                            .padding(.top, 35)

                        Text("We’ll send you a code to verify your number")
                            .font(.custom("Inter18pt-Medium", size: 16))
                            .foregroundColor(Color("TextColor"))

                        VStack(spacing: 0) {
                            HStack {
                                Text(selectedCountryCode)
                                    .font(.custom("Inter18pt-Regular", size: 16))
                                    .foregroundColor(Color("TextColor"))
                                    .padding(.leading, 15)

                                TextField("", text: $phoneNumber)
                                    .keyboardType(.numberPad)
                                    .font(.custom("Inter18pt-Regular", size: 16))
                                    .foregroundColor(Color("TextColor"))
                                    .frame(height: 60)
                                    .background(Color.clear)
                                    .overlay(
                                        ZStack(alignment: .leading) {
                                            if phoneNumber.isEmpty {
                                                Text("Enter mobile")
                                                    .foregroundColor(Color("gray"))
                                                    .font(.custom("Inter18pt-Regular", size: 16))
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                        }
                                    )
                                    .onChange(of: phoneNumber) { newValue in
                                        phoneError = nil
                                        if selectedCountryCode == "+91" && phoneNumber.count > 10 {
                                            phoneNumber = String(phoneNumber.prefix(10))
                                        }
                                    }
                                    .focused($isFocused)

                                NavigationLink(destination: flagScreen(
                                    selectedCountryCode: $selectedCountryCode,
                                    selectedCountryShortCode: $selectedCountryShortCode,
                                    selectedCountryID: $selectedCountryID
                                )) {
                                    HStack {
                                        Image("downvector")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 10, height: 10)
                                            .padding(.trailing, 5)

                                        Text(selectedCountryShortCode)
                                            .font(.custom("Inter18pt-SemiBold", size: 15))
                                            .foregroundColor(Color("TextColor"))
                                            .padding(.trailing, 20)
                                    }
                                }
                            }
                            .frame(height: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(isFocused ? Color("TextColor") : Color("gray"), lineWidth: 1)
                                    .animation(.easeInOut, value: isFocused)
                            )


                        }
                        .padding(.top, 39)

                    }
                    .padding(.horizontal, 20)
                }

                VStack(spacing: 10) {
                    HStack(spacing: 5) {
                        Button(action: {
                            isChecked.toggle()
                        }) {
                            Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                                .resizable()
                                .frame(width: 16, height: 16)
                                .foregroundColor(Color("TextColor"))
                                .padding(.trailing, 2)
                                .offset(x: shakeOffset)
                        }

                        Text("I have read and agree to the")
                            .lineLimit(1)
                            .font(.custom("Inter18pt-Regular", size: 12))
                            .foregroundColor(Color("TextColor"))

                        Button(action: {
                            let urlString = (colorScheme == .dark) ?
                            "https://enclosureapp.com/black_policy" :
                            "https://enclosureapp.com/white_policy"

                            if let url = URL(string: urlString) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text("Privacy Policy")
                                .font(.custom("Inter18pt-Regular", size: 12))
                                .foregroundColor(Color("blue"))
                                .underline()
                        }

                        Text("&")
                            .font(.custom("Inter18pt-Regular", size: 12))
                            .foregroundColor(Color("TextColor"))

                        Button(action: {
                            let urlString = "https://enclosureapp.com/terms_and_conditions"
                            if let url = URL(string: urlString) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text("Terms of Service")
                                .font(.custom("Inter18pt-Regular", size: 12))
                                .foregroundColor(Color("blue"))
                                .underline()
                        }
                    }

                    NavigationLink(
                        destination: whatsTheCode(
                            uid: viewModel.uid,
                            c_id: viewModel.c_id,
                            mobile_no: viewModel.mobile_no,
                            country_Code: viewModel.country_Code
                        ),
                        isActive: $viewModel.isNavigating
                    ) {
                        EmptyView() // Hidden Navigation Link
                    }

                    Button(
                        action: {
                            if phoneNumber.isEmpty {
                                Constant.showToast(message: "Invalid number") // Show toast
                            } else if selectedCountryCode == "+91" && phoneNumber.count < 10 {
                                Constant.showToast(message: "Invalid number") // Show toast
                            } else {
                                if isChecked {
                                    viewModel
                                        .sendOTP(
                                            mobileNo: selectedCountryCode + phoneNumber,
                                            cID: selectedCountryID,
                                            cCode: selectedCountryCode
                                        )
                                } else {
                                    withAnimation {
                                        shakeOffset = 10
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        withAnimation {
                                            shakeOffset = -10
                                        }
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        withAnimation {
                                            shakeOffset = 0
                                        }
                                    }
                                }
                            }
                        }) {
                            Text(viewModel.isLoading ? "Sending..." : "Send code")
                                .font(.custom("Inter18pt-Medium", size: 16))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, minHeight: 55)
                                .background(RoundedRectangle(cornerRadius: 15).fill(Color("btn_color")))
                        }
                        .disabled(viewModel.isLoading)
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 80)
            }
            .navigationBarHidden(true)
        }
    }
}


#Preview {
    whatsYourNumber()
        .environment(
            \.managedObjectContext,
             PersistenceController.preview.container.viewContext
        )
}
