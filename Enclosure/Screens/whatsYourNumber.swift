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
    @State private var showNumberInUseDialog: Bool = false
    
    // Helper function to hide keyboard
    private func hideKeyboard() {
        isFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    Color("background_color")
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // Top content - simple VStack (no ScrollView for Android adjustPan behavior)
                        VStack(alignment: .leading, spacing: 16) {
                        Text("What's your\nnumber?")
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

                                ZStack(alignment: .leading) {
                                    // Placeholder text (only when empty and not focused)
                                    if phoneNumber.isEmpty && !isFocused {
                                        Text("Enter mobile")
                                            .foregroundColor(Color("gray"))
                                            .font(.custom("Inter18pt-Regular", size: 16))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    
                                    TextField("", text: $phoneNumber)
                                        .keyboardType(.numberPad)
                                        .font(.custom("Inter18pt-Regular", size: 16))
                                        .foregroundColor(Color("TextColor"))
                                        .frame(height: 60)
                                        .background(Color.clear)
                                        .focused($isFocused)
                                        .onChange(of: phoneNumber) { newValue in
                                            phoneError = nil
                                            // Only limit length for India (+91) to 10 digits
                                            if selectedCountryCode == "+91" && newValue.count > 10 {
                                                phoneNumber = String(newValue.prefix(10))
                                            }
                                            // For other country codes, no length limit
                                        }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

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
                                    .stroke(
                                        isFocused ? Color("TextColor") : Color("gray"),
                                        lineWidth: isFocused ? 1.5 : 1.0
                                    )
                            )
                            .animation(.easeInOut(duration: 0.2), value: isFocused)


                        }
                        .padding(.top, 39)
                    }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer()
                }
                .simultaneousGesture(
                    TapGesture().onEnded { _ in
                        hideKeyboard()
                    }
                )

                // Bottom content - absolutely positioned at bottom (Android adjustPan behavior)
                VStack(spacing: 5) {
                    HStack(spacing: 0) {
                        // Checkbox with "I agree to the " text (matching Android checkbox structure)
                        Button(action: {
                            isChecked.toggle()
                        }) {
                            HStack(spacing: 0) {
                                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                                    .resizable()
                                    .frame(width: 16, height: 16)
                                    .foregroundColor(Color("TextColor"))
                                    .padding(.leading, 10) // paddingStart="10dp"
                                    .padding(.trailing, 2) // paddingEnd="2dp"
                                
                                Text(" I agree to the ")
                                    .lineLimit(1)
                                    .font(.custom("Inter18pt-Regular", size: 12))
                                    .foregroundColor(Color("black_white_cross"))
                            }
                            .offset(x: shakeOffset)
                        }

                        // Terms & Privacy Policy in a flexible container (layout_weight=1, center_vertical gravity)
                        HStack(spacing: 0) {
                            Button(action: {
                                let urlString = "https://enclosureapp.com/terms_and_conditions"
                                if let url = URL(string: urlString) {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Text(" Terms")
                                    .font(.custom("Inter18pt-SemiBold", size: 12)) // textStyle="bold"
                                    .foregroundColor(Color("blue")) // Using blue color asset
                            }

                            Text(" & ") // Matching Android spacing
                                .font(.custom("Inter18pt-Regular", size: 12))
                                .foregroundColor(Color("black_white_cross"))

                            Button(action: {
                                let urlString = (colorScheme == .dark) ?
                                "https://enclosureapp.com/black_policy" :
                                "https://enclosureapp.com/white_policy"

                                if let url = URL(string: urlString) {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Text("Privacy Policy.")
                                    .font(.custom("Inter18pt-SemiBold", size: 12)) // textStyle="bold"
                                    .foregroundColor(Color("blue")) // Using blue color asset
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading) // layout_weight=1, start gravity
                    }
                    .frame(maxWidth: .infinity, alignment: .leading) // Start gravity for entire HStack
                    .padding(.horizontal, 20) // marginStart="20dp"
                    .padding(.top, 4) // marginTop="4dp"
                    .padding(.bottom, 4) // marginBottom="4dp"

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
                            if isChecked {
                                handlePhoneIdCheckAndSend()
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
                    .background(Color("background_color"))
                    .frame(maxWidth: .infinity)
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
                }
                .overlay(
                    ConfirmationDialogView(
                        isPresented: $showNumberInUseDialog,
                        message: "This number is in use on another device.\nLogging in will end that session.",
                        showCancel: true,
                        confirmTitle: "Sure",
                        cancelTitle: "Cancel",
                        onConfirm: {
                            performSendOtp()
                        },
                        onCancel: {}
                    )
                    .zIndex(2)
                )
            }
            .ignoresSafeArea(.keyboard)
            .simultaneousGesture(
                TapGesture().onEnded { _ in
                    hideKeyboard()
                }
            )
            .navigationBarHidden(true)
            .background(NavigationGestureEnabler())
            .onChange(of: selectedCountryShortCode) { newValue in
                print("Country short code updated in whatsYourNumber: \(newValue)")
                // Dismiss keyboard when country is selected (returning from flagScreen)
                // This prevents keyboard from opening when returning from flagScreen
                DispatchQueue.main.async {
                    isFocused = false
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
            .onChange(of: selectedCountryCode) { newValue in
                print("Country code updated in whatsYourNumber: \(newValue)")
                // Dismiss keyboard when country code is selected (returning from flagScreen)
                DispatchQueue.main.async {
                    isFocused = false
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    
    private func performSendOtp() {
        if phoneNumber.isEmpty {
            Constant.showToast(message: "Invalid number")
        } else if selectedCountryCode == "+91" && phoneNumber.count < 10 {
            Constant.showToast(message: "Invalid number")
        } else {
            viewModel.sendOTP(
                mobileNo: selectedCountryCode + phoneNumber,
                cID: selectedCountryID,
                cCode: selectedCountryCode
            )
        }
    }
    
    private func handlePhoneIdCheckAndSend() {
        let fullNumber = selectedCountryCode + phoneNumber
        print("🟠 [whatsYourNumber] checkPhoneIdMatch start - mobile: \(fullNumber)")
        viewModel.checkPhoneIdMatch(mobileNo: fullNumber) { status in
            switch status {
            case .match:
                print("🟠 [whatsYourNumber] checkPhoneIdMatch MATCH")
                performSendOtp()
            case .partialMatch:
                print("🟠 [whatsYourNumber] checkPhoneIdMatch PARTIAL - showing dialog")
                showNumberInUseDialog = true
            case .failure:
                print("🟠 [whatsYourNumber] checkPhoneIdMatch FAIL - proceeding with OTP")
                performSendOtp()
            }
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
