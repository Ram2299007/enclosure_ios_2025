import SwiftUI
import CoreHaptics

struct LockScreen2View: View {
    @State private var progress: CGFloat = 0.0 // Progress in degrees (0 - 360)
    @State private var hapticEngine: CHHapticEngine?
    @State private var isTapped = false
    @State private var isRippleActive = false
    @State private var showDialog = false
    @State private var shouldNavigateToMain: Bool = false
    
    init() {
        print("🔍 [LockScreen2View] init() called - View is being created")
    }
    
    // Helper function to hide keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    var body: some View {
                NavigationStack {
                    ZStack {
                        Color("BackgroundColor")
                            .ignoresSafeArea()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                hideKeyboard()
                            }
            
                        VStack {
                            Spacer()
            
                            VStack(spacing: 20) {
                                ZStack {
                                    CircularSeekBar(progress: $progress, hapticEngine: hapticEngine)
                                        .frame(width: 250, height: 250)
                                        .padding(12.5)
            
                                    Image("elipse")
                                        .resizable()
                                        .renderingMode(.template)
                                        .foregroundColor(Color(hex: Constant.themeColor)) // Apply theme color tint
                                        .frame(width: 190, height: 190)
            
                                    // Display the progress (0° to 360°)
                                    Text("\(Int(progress))°")
                                        .font(.custom("Inter18pt-SemiBold", size: 45))
                                        .foregroundColor(isTapped ? Color("cs_circle_color") : .white) // Change color while pressed
                                        .scaleEffect(isTapped ? 1.05 : 1.0) // Scale effect
                                        .animation(.easeOut(duration: 0.2), value: isTapped)
                                        .onTapGesture {
                                            if progress < 360 {
                                                progress += 1
                                                simpleSuccess()
                                                isTapped = true // Change color to gray and scale
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                    isTapped = false // Reset after delay
                                                }
                                            }
                                        }
                                }
            
                                Text("Turn into Enclosure")
                                    .font(.custom("Inter18pt-Medium", size: 20))
                                    .foregroundColor(Color(hex: Constant.themeColor)) // Use dynamic theme color
                                    .padding(.top, 20)
                            }
            
                            Spacer()
            
                            VStack(spacing: 20) {
                                Button(
                                    action: {
                                        // Unlock Enclosure action
            
                                        let UID_KEY = UserDefaults.standard.string(forKey: Constant.UID_KEY)
            
                                        print("🔓 [LockScreen2View] Unlock button clicked - UID_KEY: \(UID_KEY ?? "0"), Progress: \(Int(progress))")
            
                                        ApiService
                                            .shared.lockScreen(
                                                uid: UID_KEY ?? "0",
                                                lockScreen: "0", /// default value of lock screen
                                                lockScreenPin: "\(Int(progress))",
                                                lock3: ""
                                            ) { success, msg in
                                                DispatchQueue.main.async {
                                                if success {
                                                        print("🔓 [LockScreen2View] lockScreen Success: \(msg)")
                                                    Constant.showToast(message: msg)
                                                        
                                                        // Check if unlock was successful (matching Android logic)
                                                        if msg == "Screen unlocked !" || msg.contains("unlocked") {
                                                            print("🔓 [LockScreen2View] Screen unlocked successfully - Navigating to MainActivityOld")
                                                            
                                                            // Clear sleep mode if it was set (matching Android)
                                                            if let sleepKey = UserDefaults.standard.string(forKey: Constant.sleepKey), sleepKey == Constant.sleepKey {
                                                                UserDefaults.standard.set("", forKey: Constant.sleepKey)
                                                                UserDefaults.standard.set("", forKey: Constant.sleepKeyCheckOFF)
                                                                print("🔓 [LockScreen2View] Cleared sleep mode keys")
                                                            }
                                                            
                                                            // Navigate to MainActivityOld (matching Android Intent to MainActivityOld)
                                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                                shouldNavigateToMain = true
                                                                print("🔓 [LockScreen2View] Setting shouldNavigateToMain = true")
                                                            }
                                                        }
                                                } else {
                                                        print("🔓 [LockScreen2View] lockScreen Failed: \(msg)")
                                                    Constant.showToast(message: msg)
                                                    }
                                                }
                                            }
                                    }) {
                                        Text("Unlock Enclosure")
                                            .font(.custom("Inter18pt-Medium", size: 14))
                                            .foregroundColor((Color(red: 0xF6/255, green: 0xF7/255, blue: 0xFF/255)))
                                            .padding()
                                            .background(Color(hex: Constant.themeColor)) // Use dynamic theme color
                                            .cornerRadius(8)
                                    }
            
            
                                Button(action: {
            
                                    print("Forget Lock Key clicked")
                                    let UID_KEY = UserDefaults.standard.string(forKey: Constant.UID_KEY)
                                    print("🥰 UID_KEY after clicking Forget Lock Key: \(UID_KEY ?? "null")")
                                    showDialog = true
            
                                }){
                                    Text("Forget Lock Key?")
                                        .underline(true)
                                        .font(.custom("Inter18pt-Medium", size: 14))
                                        .foregroundColor(Color(hex: Constant.themeColor)) // Use dynamic theme color
                                }
                            }
            
                            .padding(.bottom, 90)
                        }
                    }
                    .overlay(
                        ForgotLockScreenDialog(isShowing: $showDialog)
                    )
                    .onAppear {
                        print("🔍 [LockScreen2View] onAppear called")
                        prepareHaptics()
                        // Re-check sleepKeyCheckOFF when view appears (matching Android onStart())
                        checkSleepModeStatus()
                    }
                    .navigationBarHidden(true)
                    .background(NavigationGestureEnabler())
                    .background(
                        NavigationLink(destination: MainActivityOld(), isActive: $shouldNavigateToMain) {
                            EmptyView()
                }
                        .hidden()
                        .onChange(of: shouldNavigateToMain) { newValue in
                            print("🔍 [LockScreen2View] NavigationLink to MainActivityOld - isActive changed to: \(newValue)")
            }
                    )
        }
    }

    private func prepareHaptics() {
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Haptic engine error: \(error.localizedDescription)")
        }
    }

    private func simpleSuccess() {
        guard let engine = hapticEngine, CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        var events = [CHHapticEvent]()
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        events.append(event)

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play haptic: \(error.localizedDescription)")
        }
    }
    
    // Check sleep mode status (matching Android onStart() logic)
    private func checkSleepModeStatus() {
        let sleepKeyCheckOFF = UserDefaults.standard.string(forKey: Constant.sleepKeyCheckOFF) ?? ""
        let uid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        
        print("🔍 [LockScreen2View] checkSleepModeStatus() called")
        print("🔍 [LockScreen2View] sleepKeyCheckOFF: '\(sleepKeyCheckOFF)'")
        print("🔍 [LockScreen2View] uid: '\(uid)'")
        
        // Android: if (sleepKeyCheckOFF.equals("on")) { stay on lock screen } 
        //          else { navigate to MainActivityOld }
        // If sleepKeyCheckOFF != "on" AND user is logged in, navigate to MainActivityOld
        if sleepKeyCheckOFF != "on" && !uid.isEmpty && uid != "0" {
            print("🔍 [LockScreen2View] Condition met: sleepKeyCheckOFF != 'on' AND uid is valid")
            print("🔍 [LockScreen2View] Will navigate to MainActivityOld in 0.1s")
            // Navigate to MainActivityOld (matching Android SmoothNavigationHelper.startActivity)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("🔍 [LockScreen2View] Setting shouldNavigateToMain = true")
                shouldNavigateToMain = true
                print("🔍 [LockScreen2View] shouldNavigateToMain set to: \(shouldNavigateToMain)")
            }
        } else {
            print("🔍 [LockScreen2View] Condition NOT met - staying on lock screen")
            print("🔍 [LockScreen2View] sleepKeyCheckOFF == 'on': \(sleepKeyCheckOFF == "on")")
            print("🔍 [LockScreen2View] uid.isEmpty: \(uid.isEmpty)")
            print("🔍 [LockScreen2View] uid == '0': \(uid == "0")")
        }
    }
}


struct CircularSeekBar: View {
    @Binding var progress: CGFloat
    @State private var previousProgress: Int = 0
    var hapticEngine: CHHapticEngine?

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color("cs_circle_color").opacity(0.3), lineWidth: 18)
                .frame(width: 210, height: 210)

            Circle()
                .trim(from: 0.0, to: progress / 360)
                .stroke(Color(hex: Constant.themeColor), style: StrokeStyle(lineWidth: 18, lineCap: .round)) // Use dynamic theme color
                .frame(width: 210, height: 210)
                .rotationEffect(.degrees(-90))

            Circle()
                .fill(Color(red: 0xF6/255, green: 0xF7/255, blue: 0xFF/255))
                .frame(width: 24, height: 24)
                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 4)
                .offset(x: 108 * cos((progress - 90).toRadians()), y: 108 * sin((progress - 90).toRadians()))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            updateProgress(from: value.location)
                        }
                )
        }
    }

    private func updateProgress(from location: CGPoint) {
        let center = CGPoint(x: 108, y: 108)
        let dx = location.x - center.x
        let dy = location.y - center.y
        var newAngle = atan2(dy, dx) * 180 / .pi

        if newAngle < 0 {
            newAngle += 361
        }

        let roundedProgress = Int(newAngle)
        if roundedProgress != previousProgress {
            simpleSuccess()
            previousProgress = roundedProgress
        }
        progress = newAngle
    }

    private func simpleSuccess() {
        guard let engine = hapticEngine, CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        var events = [CHHapticEvent]()
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        events.append(event)

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play haptic: \(error.localizedDescription)")
        }
    }
}


extension CGFloat {
    func toRadians() -> CGFloat {
        return self * .pi / 180
    }
}

struct LockScreen2View_Previews: PreviewProvider {
    static var previews: some View {
        LockScreen2View()
    }
}
