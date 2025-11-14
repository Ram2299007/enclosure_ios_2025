import SwiftUI
import CoreHaptics

struct LockScreen2View: View {
    @State private var progress: CGFloat = 0.0 // Progress in degrees (0 - 360)
    @State private var hapticEngine: CHHapticEngine?
    @State private var isTapped = false
    @State private var isRippleActive = false
    @State private var showDialog = false
    @State  var isNavigating = false
    var body: some View {
        NavigationStack{
            ZStack {
                Color("BackgroundColor")
                    .ignoresSafeArea()

                VStack {
                    Spacer()

                    VStack(spacing: 20) {
                        ZStack {
                            CircularSeekBar(progress: $progress, hapticEngine: hapticEngine)
                                .frame(width: 250, height: 250)
                                .padding(12.5)

                            Image("elipse")
                                .resizable()
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
                            .foregroundColor(Color("blue"))
                            .padding(.top, 20)
                    }

                    Spacer()

                    VStack(spacing: 20) {
                        Button(
                            action: {
                                // Unlock Enclosure action

                                let UID_KEY = UserDefaults.standard.string(forKey: Constant.UID_KEY)

                                print("🥰 UID_KEY : \(UID_KEY ?? "0")")

                                ApiService
                                    .shared.lockScreen(
                                        uid: UID_KEY ?? "0",
                                        lockScreen: "0", /// default value of loxk screen
                                        lockScreenPin: "\(Int(progress))",
                                        lock3: ""
                                    ) { success, msg in

                                        if success {
                                            print("lockScreen Success: \(msg)")
                                            Constant.showToast(message: msg)
                                        } else {
                                            print("lockScreen Failed: \(msg)")
                                            Constant.showToast(message: msg)
                                        }
                                    }


                            }) {
                                Text("Unlock Enclosure")
                                    .font(.custom("Inter18pt-Medium", size: 14))
                                    .foregroundColor((Color.white))
                                    .padding()
                                    .background(Color("blue"))
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
                                .foregroundColor(Color("blue"))
                        }




                    }

                    .padding(.bottom, 90)
                }


                NavigationLink(
                    destination: MainActivityOld(),
                    isActive: $isNavigating
                ) {
                    EmptyView()
                }
                .hidden()

            }

            .onAppear {
                let sleepkey = UserDefaults.standard.string(forKey: Constant.sleepKey)
                let uid = UserDefaults.standard.string(forKey: Constant.UID_KEY)
                let sleepKeyCheckOFF = UserDefaults.standard.string(forKey: Constant.sleepKeyCheckOFF) ?? ""
                let loggedInKey = UserDefaults.standard.string(forKey: Constant.loggedInKey) ?? ""
                
                // Only auto-navigate if:
                // 1. Lock screen is not set up yet (sleepKeyCheckOFF != "on")
                // 2. User has completed registration (has UID and loggedInKey)
                // This prevents navigation when user is in the middle of registration
                if sleepKeyCheckOFF != "on" && 
                   uid != nil && uid != "0" && 
                   loggedInKey == Constant.loggedInKey {
                    self.isNavigating = true
                }

                prepareHaptics()
            }
        }
        .overlay(
            ForgotLockScreenDialog(isShowing: $showDialog)
        )
        .navigationBarHidden(true)
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
                .stroke(Color("blue"), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .frame(width: 210, height: 210)
                .rotationEffect(.degrees(-90))

            Circle()
                .fill(Color.white)
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
