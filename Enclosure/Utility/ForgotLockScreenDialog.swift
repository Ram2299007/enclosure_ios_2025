//
//  ForgotLockScreenDialog.swift
//  Enclosure
//
//  Created by Ram Lohar on 29/03/25.
//

import SwiftUI
struct ForgotLockScreenDialog: View {
    @Binding var isShowing: Bool  // Dialog visibility control
    @State private var isActive = false


    var body: some View {
        ZStack {
            if isShowing {
                Color.black.opacity(0.4) // Background blur effect
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        isShowing = false  // Click outside to dismiss
                    }

                VStack(spacing: 20) {
                    HStack {
                        Spacer()
                        Button(action: {
                            isShowing = false
                        }) {
                            Image("crossbtn")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.gray)
                        }
                        .padding(.trailing, 0)
                    }

                    Text("Forgot Lock Screen")
                        .font(.custom("Inter18pt-SemiBold", size: 16))
                        .foregroundColor(Color("TextColor"))

                    Text("Press 'OK' to show password. After FEW weeks, it will be shown only on registered number or mail.")
                        .font(.custom("Inter18pt-Medium", size: 12))
                        .foregroundColor(Color("TextColor"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    Button(
                        action: {
                            isShowing = false  // Handle OK button action
                            UserDefaults.standard.string(forKey: Constant.PHONE_NUMBERKEY)
                            UserDefaults.standard.string(forKey: Constant.UID_KEY)
                            UserDefaults.standard.string(forKey: Constant.country_Code)

                            print("XXXXXXXXXXXXXXXXXXX \( UserDefaults.standard.string(forKey: Constant.country_Code))  : ")

                            ApiService.shared
                                .reSendOtpForget(mobile_no: UserDefaults.standard.string(forKey: Constant.PHONE_NUMBERKEY) ?? "0") { success, msg in
                                    if success
                                    {
                                          Constant.showToast(message: msg)
                                        self.isActive = true;

                                    }else{
                                        Constant.showToast(message: "Failed"+msg)
                                    }
                                }



                        }) {
                            Text("OK")
                                .frame(width: 66, height: 33)
                                .background(Color("appThemeColor"))
                                .font(.custom("Inter18pt-Medium",size: 14))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }


                    //
                    NavigationLink(
                        destination: forgetScreenOtp(
                            uid:  UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? "",
                            mobile_no:  UserDefaults.standard.string(forKey: Constant.PHONE_NUMBERKEY) ?? "",
                            country_Code: UserDefaults.standard.string(forKey: Constant.country_Code) ?? ""
                        ),
                        isActive: $isActive
                    ) {
                        EmptyView() // Hidden Navigation Link
                    }
                }
                .padding(10)
                .background(Color("cardBackgroundColornew"))
                .cornerRadius(20)
                .frame(width: 268, height: 224)
                .shadow(radius: 10)
            }
        }
    }
}
