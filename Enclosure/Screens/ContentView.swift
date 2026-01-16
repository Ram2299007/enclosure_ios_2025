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
        ZStack {
            NavigationStack {
                ZStack {
                    Color("BackgroundColor")
                        .edgesIgnoringSafeArea(.all)
                    
                    // Centered Logo (matching Android SplashScreen)
                    VStack {
                        Spacer()
                        
                        // Theme-based logo (matching Launch Screen size: 110x110)
                        Image(logoImageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 110, height: 110)
                        
                        Spacer()
                    }
                }
                .navigationDestination(isPresented: $isNavigating) {
                    LockScreen2View()
                }
                .navigationDestination(isPresented: $isNavigatingToOnboarding) {
                    OnboardingView()
                }
                .onAppear {
                    print("🔍 [ContentView] onAppear called")
                    setupSplashScreen()
                    startSplashThread()
                    
                    // Check for shared content from Share Extension when app opens
                    checkForSharedContentOnLaunch()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ThemeColorUpdated"))) { notification in
                    setupSplashScreen()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HandleSharedContent"))) { notification in
                    print("📤 [ContentView] Received HandleSharedContent notification")
                    // Ensure we navigate to MainActivityOld if not already there
                    let uid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? "0"
                    if uid != "0" {
                        let sleepKeyCheckOFF = UserDefaults.standard.string(forKey: Constant.sleepKeyCheckOFF) ?? ""
                        let loggedInKey = UserDefaults.standard.string(forKey: Constant.loggedInKey) ?? ""
                        if loggedInKey == Constant.loggedInKey && sleepKeyCheckOFF != "on" {
                            isNavigatingToMain = true
                        }
                    }
                }
            }
            
            // Show MainActivityOld directly with smooth fade-in transition
            if isNavigatingToMain {
                MainActivityOld()
                    .transition(.opacity)
                    .zIndex(1)
                    .animation(.easeInOut(duration: 0.3), value: isNavigatingToMain)
            }
        }
    }
    
    // Setup splash screen logo based on theme color (matching Android and MainActivityOld)
    private func setupSplashScreen() {
        let themeColor = Constant.themeColor
        logoImageName = getLogoImage(for: themeColor)
        print("🎨 [ContentView] Splash screen logo set to: \(logoImageName) (theme: \(themeColor))")
    }
    
    // Get logo image name based on theme color (matching MainActivityOld logic)
    private func getLogoImage(for themeColor: String) -> String {
        switch themeColor {
        case "#ff0080":
            return "pinklogopng"
        case "#00A3E9":
            return "ec_modern"
        case "#7adf2a":
            return "popatilogopng"
        case "#ec0001":
            return "redlogopng"
        case "#16f3ff":
            return "bluelogopng"
        case "#FF8A00":
            return "orangelogopng"
        case "#7F7F7F":
            return "graylogopng"
        case "#D9B845":
            return "yellowlogopng"
        case "#346667":
            return "greenlogoppng"
        case "#9846D9":
            return "voiletlogopng"
        case "#A81010":
            return "red2logopng"
        default:
            return "ec_modern"
        }
    }
    
    // Start splash thread with 0 delay
    private func startSplashThread() {
        print("🔍 [ContentView] startSplashThread() called - will call navigateToNextScreen() immediately")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.0) {
            print("🔍 [ContentView] Navigation triggered")
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
    
    // Check for shared content when app launches (from Share Extension)
    private func checkForSharedContentOnLaunch() {
        // Add delay to ensure Share Extension has finished saving to UserDefaults
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let sharedDefaults = UserDefaults(suiteName: "group.com.enclosure")
            
            if let contentType = sharedDefaults?.string(forKey: "sharedContentType") {
                print("📤 [ContentView] Found shared content on launch: \(contentType)")
                // Post notification so MainActivityOld can handle it
                NotificationCenter.default.post(name: NSNotification.Name("HandleSharedContent"), object: nil)
            } else {
                print("📤 [ContentView] No shared content found on launch")
            }
        }
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
