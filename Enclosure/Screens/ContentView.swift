//
//  ContentView.swift
//  Enclosure
//
//  Created by Ram Lohar on 14/03/25.


import SwiftUI

struct ContentView: View {
    @State var isNavigating = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color("BackgroundColor")
                    .edgesIgnoringSafeArea(.all)
                VStack(alignment: .center, spacing: 20) {
                    // App Logo
                    Image("ec_modern")
                        .resizable()
                        .frame(width: 80, height: 80)

                    // Two Sections with Text & Circles
                    HStack(spacing: 50) {
                        InfoSection(title1: "Personal", title2: "Professional", imageName: "mail", offsetValue: -13)
                        InfoSection(title1: "Valuable for", title2: "Billion People", imageName: "q", offsetValue: 13)
                    }
                    .padding(.top, 30)

                    // Blue Banner Section
                    ZStack {
                        Image("blue_banner")
                            .resizable()
                            .frame(height: 143)
                            .cornerRadius(15)

                        Text("Your message will become\n more valuable here.")
                            .font(.custom("Inter18pt-SemiBold", size: 18))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 30)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 20)
                .multilineTextAlignment(.center)

                // Next Button (Always at Bottom)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        NavigationLink(destination: whatsYourNumber()) {
                            HStack {
                                Text("Next")
                                    .font(.custom("Inter18pt-SemiBold", size: 20))
                                    .foregroundColor(Color("TextColor"))

                                Image("next")
                                    .resizable()
                                    .renderingMode(.template)
                                    .frame(width: 21.62, height: 21.62)
                                    .foregroundColor(Color("icontintGlobal"))
                            }
                            .padding(12)
                            .cornerRadius(50)
                        }
                    }
                    .padding(20)
                }
            }
            .background(
                NavigationLink(destination: LockScreen2View(), isActive: $isNavigating) {
                    EmptyView()
                }
                .hidden()
            )
            .onAppear {
                let uid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? "0"
                if uid != "0" {
                    isNavigating = true
                }
            }
        }
    }
}

// MARK: - Reusable Component for Info Sections
struct InfoSection: View {
    var title1: String
    var title2: String
    var imageName: String
    var offsetValue: CGFloat

    var body: some View {
        VStack {
            VStack(spacing: 1) {
                Text(title1)
                    .font(.custom("Inter18pt-Medium", size: 16))
                    .foregroundColor(Color("TextColor"))

                Text(title2)
                    .font(.custom("Inter18pt-SemiBold", size: 18))
                    .foregroundColor(Color("TextColor"))
            }

            VStack(spacing: 26) {
                Circle().fill(Color(red: 47/255, green: 180/255, blue: 237/255)).frame(width: 9, height: 9)
                Circle().fill(Color(red: 20/255, green: 109/255, blue: 148/255)).frame(width: 9, height: 9)
                    .offset(x: offsetValue)
                Circle().fill(Color(red: 7/255, green: 56/255, blue: 107/255)).frame(width: 9, height: 9)
            }
            .padding(.top, 26)

            Image(imageName)
                .resizable()
                .frame(width: 60, height: 60)
                .padding(.top, 26)
        }
    }
}



#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
