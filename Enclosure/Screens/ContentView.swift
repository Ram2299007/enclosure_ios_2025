//
//  ContentView.swift
//  Enclosure
//
//  Created by Ram Lohar on 14/03/25.


import SwiftUI

struct ContentView: View {
    @State var isNavigating = false
    @State var isNavigatingToMain = false
    @State var isNavigatingToOnboarding = false
    @State private var logoImageName = "ec_modern" // Default logo

    var body: some View {
        NavigationStack {
            ZStack {
                Color("BackgroundColor")
                    .edgesIgnoringSafeArea(.all)
                
                // Centered Logo (matching Android SplashScreen)
                VStack {
                    Spacer()
                   
                    Spacer()
                }
            }
            .background(
                NavigationLink(destination: LockScreen2View(), isActive: $isNavigating) {
                    EmptyView()
                }
                .hidden()
                .onChange(of: isNavigating) { newValue in
                    print("🔍 [ContentView] NavigationLink to LockScreen2View - isActive changed to: \(newValue)")
                }
            )
            .background(
                NavigationLink(destination: MainActivityOld(), isActive: $isNavigatingToMain) {
                    EmptyView()
                }
                .hidden()
                .onChange(of: isNavigatingToMain) { newValue in
                    print("🔍 [ContentView] NavigationLink to MainActivityOld - isActive changed to: \(newValue)")
                }
            )
            .background(
                NavigationLink(destination: OnboardingView(), isActive: $isNavigatingToOnboarding) {
                    EmptyView()
                }
                .hidden()
            )
            .onAppear {
                print("🔍 [ContentView] onAppear called")
                setupSplashScreen()
                startSplashThread()
            }
        }
    }
    
    // Setup splash screen logo based on theme color (matching Android)
    private func setupSplashScreen() {
        // Get theme color from UserDefaults (if available)
        // For now, using default logo. Can be extended to support theme colors
        let themeColor = Constant.themeColor
        
        // Map theme colors to logos (matching Android logic)
        switch themeColor {
        case "#ff0080":
            logoImageName = "pinklogopng"
        case "#00A3E9":
            logoImageName = "ec_modern"
        case "#7adf2a":
            logoImageName = "popatilogopng"
        case "#ec0001":
            logoImageName = "redlogopng"
        case "#16f3ff":
            logoImageName = "bluelogopng"
        case "#FF8A00":
            logoImageName = "orangelogopng"
        case "#7F7F7F":
            logoImageName = "graylogopng"
        case "#D9B845":
            logoImageName = "yellowlogopng"
        case "#346667":
            logoImageName = "greenlogoppng"
        case "#9846D9":
            logoImageName = "voiletlogopng"
        case "#A81010":
            logoImageName = "red2logopng"
        default:
            logoImageName = "ec_modern"
        }
    }
    
    // Start splash thread with 200ms delay (matching Android)
    private func startSplashThread() {
        print("🔍 [ContentView] startSplashThread() called - will call navigateToNextScreen() after 0.2s")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            print("🔍 [ContentView] Delayed navigation triggered")
            navigateToNextScreen()
        }
    }
    
    // Navigate based on UID (matching Android logic)
    private func navigateToNextScreen() {
        let uid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? "0"
        
        print("🔍 [ContentView] navigateToNextScreen() called")
        print("🔍 [ContentView] UID: \(uid)")
        
        if uid == "0" {
            // No UID - go to onboarding screen (SplashScreen2 equivalent)
            print("🔍 [ContentView] UID is '0' - Navigating to OnboardingView")
            isNavigatingToOnboarding = true
        } else {
            // Has UID - check if lock screen is set up
            let sleepKeyCheckOFF = UserDefaults.standard.string(forKey: Constant.sleepKeyCheckOFF) ?? ""
            let loggedInKey = UserDefaults.standard.string(forKey: Constant.loggedInKey) ?? ""
            
            print("🔍 [ContentView] sleepKeyCheckOFF: '\(sleepKeyCheckOFF)'")
            print("🔍 [ContentView] loggedInKey: '\(loggedInKey)'")
            print("🔍 [ContentView] Constant.loggedInKey: '\(Constant.loggedInKey)'")
            
            if loggedInKey == Constant.loggedInKey {
                print("🔍 [ContentView] loggedInKey matches - Checking sleep mode status")
                
                // Also check lockKey to understand the full state
                let lockKey = UserDefaults.standard.string(forKey: "lockKey") ?? "0"
                print("🔍 [ContentView] lockKey: '\(lockKey)'")
                
                // Matching Android logic:
                // - If sleepKeyCheckOFF == "on" (sleep mode is ON), show lock screen (LockScreen2View)
                // - If sleepKeyCheckOFF != "on" (sleep mode is OFF), go directly to MainActivityOld
                if sleepKeyCheckOFF == "on" {
                    // Sleep mode is ON - show lock screen
                    print("🔍 [ContentView] ✅ sleepKeyCheckOFF == 'on' - Navigating to LockScreen2View")
                    print("🔍 [ContentView] Setting isNavigating = true")
                    isNavigating = true
                    print("🔍 [ContentView] isNavigating set to: \(isNavigating)")
                } else {
                    // Sleep mode is OFF - go directly to MainActivityOld
                    print("🔍 [ContentView] ⚠️ sleepKeyCheckOFF != 'on' (value: '\(sleepKeyCheckOFF)') - Navigating to MainActivityOld")
                    print("🔍 [ContentView] 💡 To test lock screen: Activate sleep mode by dragging seekbar to 100% in MainActivityOld")
                    print("🔍 [ContentView] Setting isNavigatingToMain = true")
                    isNavigatingToMain = true
                    print("🔍 [ContentView] isNavigatingToMain set to: \(isNavigatingToMain)")
                }
            } else {
                // User has UID but hasn't completed registration - go to onboarding
                print("🔍 [ContentView] loggedInKey does NOT match - Navigating to OnboardingView")
                isNavigatingToOnboarding = true
            }
        }
        
        print("🔍 [ContentView] Final navigation state - isNavigating: \(isNavigating), isNavigatingToMain: \(isNavigatingToMain), isNavigatingToOnboarding: \(isNavigatingToOnboarding)")
    }
}

// Onboarding View (SplashScreen2 equivalent - the original ContentView content)
struct OnboardingView: View {
    var body: some View {
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
                        .font(.custom("Inter18pt-SemiBold", size: 18)) // inter_bold + fontWeight 600 = Bold
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
        .navigationBarHidden(true)
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
                    .font(.custom("Inter18pt-SemiBold", size: 16)) // inter_medium + fontWeight 600 = SemiBold
                    .foregroundColor(Color("TextColor"))

                Text(title2)
                    .font(.custom("Inter18pt-SemiBold", size: 18)) // inter_bold + fontWeight 600 = Bold
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
