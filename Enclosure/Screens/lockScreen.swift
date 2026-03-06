import SwiftUI
import CoreHaptics

struct LockScreenView: View {
    @State private var progress: CGFloat = 0.0
    @State private var hapticEngine: CHHapticEngine?
    @State private var isTapped = false
    @State private var isDropdownVisible = false
    @State private var selectedValue = "0°" // Default value
    @State private var isPressed = false
    @Environment(\.dismiss) var dismiss
    let dropdownOptions = ["0°", "90°", "180°", "360°"]

    // Helper function to hide keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    var body: some View {
        ZStack {
            Color("BackgroundColor")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Back button row at the top
                HStack {
                    Button(action: handleBackTap) {
                        Image("leftvector")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 18)
                            .foregroundColor(Color("icontintGlobal"))
                    }
                    .frame(width: 40, height: 40)
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Spacer()

                // Main content
                VStack(spacing: 40) {
                    ZStack {
                        CircularSeekBars(
                            progress: $progress,
                            hapticEngine: hapticEngine
                        )
                        .frame(width: 250, height: 250)

                        Image("elipse")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(Color(hex: Constant.themeColor))
                            .frame(width: 190, height: 190)

                        Text("\(Int(progress))°")
                            .font(.custom("Inter18pt-SemiBold", size: 45))
                            .foregroundColor(
                                isTapped ? Color("cs_circle_color") : .white
                            )
                            .scaleEffect(isTapped ? 1.05 : 1.0)
                            .animation(
                                .easeOut(duration: 0.2),
                                value: isTapped
                            )
                            .onTapGesture {
                                if progress < 360 {
                                    progress += 1
                                    simpleSuccess()
                                    isTapped = true
                                    DispatchQueue.main
                                        .asyncAfter(
                                            deadline: .now() + 0.2
                                        ) {
                                            isTapped = false
                                        }
                                }
                            }
                    }

                    Text("Set Lock Screen")
                        .font(.custom("Inter18pt-Medium", size: 16))
                        .foregroundColor(Color(hex: Constant.themeColor))

                    // Dropdown Button using Menu
                    Menu {
                        ForEach(dropdownOptions, id: \.self) { option in
                            Button(option) {
                                selectedValue = option
                                if let value = Int(option.replacingOccurrences(of: "°", with: "")) {
                                    progress = CGFloat(value)
                                }
                            }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: Constant.themeColor))
                                .frame(width: 77, height: 77)
                                .overlay(
                                    Circle()
                                        .stroke(Color(hex: Constant.themeColor), lineWidth: 2)
                                )

                            HStack(spacing: 4) {
                                Text(selectedValue)
                                    .font(
                                        .custom(
                                            "Inter18pt-SemiBold",
                                            size: 16
                                        )
                                    )
                                    .foregroundColor(.white)

                                Image("downvector")
                                    .resizable()
                                    .renderingMode(.template)
                                    .frame(width: 12, height: 12)
                                    .foregroundColor(.white)
                                    .padding(.leading, 2)
                            }
                        }
                    }

                    // Tick Button
                    Button(
                        action: {
                            if Int(progress) == 0 {
                                Constant
                                    .showToast(
                                        message: "Please set degree first"
                                    )
                            } else {
                                UserDefaults.standard
                                    .set(
                                        "off",
                                        forKey: Constant.sleepKeyCheckOFF
                                    )
                                let UID_KEY = UserDefaults.standard.string(
                                    forKey: Constant.UID_KEY
                                )

                                ApiService.shared
                                    .lockScreen(
                                        uid: UID_KEY ?? "0",
                                        lockScreen: "1",
                                        lockScreenPin: "\(Int(progress))",
                                        lock3: "") { success, msg in
                                            if success {
                                                Constant.showToast(message: msg)
                                                dismiss()
                                            } else {
                                                Constant.showToast(message: msg)
                                            }
                                        }
                            }
                        },
                        label: {
                            ZStack {
                                Circle()
                                    .fill(Color("cs_circle_color"))
                                    .frame(width: 77, height: 77)

                                Image("tick")
                                    .resizable()
                                    .renderingMode(.template)
                                    .frame(width: 45, height: 45)
                                    .foregroundColor(Color("TextColor"))
                            }
                        })
                }

                Spacer()
            }
        }
        .onTapGesture {
            hideKeyboard()
        }
        .onAppear {
            prepareHaptics()
        }
        .navigationBarBackButtonHidden(true)
        .background(NavigationGestureEnabler())
    }
    
    private func handleBackTap() {
        withAnimation {
            isPressed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            dismiss()
            isPressed = false
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
        guard let engine = hapticEngine, CHHapticEngine
            .capabilitiesForHardware().supportsHaptics else { return }

        let intensity = CHHapticEventParameter(
            parameterID: .hapticIntensity,
            value: 1
        )
        let sharpness = CHHapticEventParameter(
            parameterID: .hapticSharpness,
            value: 1
        )
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [intensity, sharpness],
            relativeTime: 0
        )

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play haptic: \(error.localizedDescription)")
        }
    }
}

struct CircularSeekBars: View {
    @Binding var progress: CGFloat
    @State private var previousProgress: Int = 0
    var hapticEngine: CHHapticEngine?

    private let circleSize: CGFloat = 210
    private let thumbRadius: CGFloat = 108

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            ZStack {
                Circle()
                    .stroke(Color("cs_circle_color").opacity(0.3), lineWidth: 18)
                    .frame(width: circleSize, height: circleSize)

                Circle()
                    .trim(from: 0.0, to: progress / 360)
                    .stroke(
                        Color(hex: Constant.themeColor),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .frame(width: circleSize, height: circleSize)
                    .rotationEffect(.degrees(-90))

                Circle()
                    .fill(Color(red: 0xF6/255, green: 0xF7/255, blue: 0xFF/255))
                    .frame(width: 24, height: 24)
                    .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 4)
                    .offset(
                        x: thumbRadius * cos((progress - 90).toRadianss()),
                        y: thumbRadius * sin((progress - 90).toRadianss())
                    )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Circle().scale(1.2))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let dx = value.location.x - center.x
                        let dy = value.location.y - center.y
                        var newAngle = atan2(dy, dx) * 180 / .pi
                        if newAngle < 0 {
                            newAngle += 360
                        }
                        let roundedProgress = Int(newAngle)
                        if roundedProgress != previousProgress {
                            simpleSuccess()
                            previousProgress = roundedProgress
                        }
                        progress = newAngle
                    }
            )
        }
    }

    private func simpleSuccess() {
        guard let engine = hapticEngine, CHHapticEngine
            .capabilitiesForHardware().supportsHaptics else { return }

        let intensity = CHHapticEventParameter(
            parameterID: .hapticIntensity,
            value: 1
        )
        let sharpness = CHHapticEventParameter(
            parameterID: .hapticSharpness,
            value: 1
        )
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [intensity, sharpness],
            relativeTime: 0
        )

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play haptic: \(error.localizedDescription)")
        }
    }
}

extension CGFloat {
    func toRadianss() -> CGFloat {
        return self * .pi / 180
    }
}

struct LockScreenView_Previews: PreviewProvider {
    static var previews: some View {
        LockScreenView()
    }
}
