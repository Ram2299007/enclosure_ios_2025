import SwiftUI
import CoreHaptics

struct LockScreenView: View {
    @State private var progress: CGFloat = 0.0 // Progress in degrees (0 - 360)
    @State private var hapticEngine: CHHapticEngine?
    @State private var isTapped = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color("BackgroundColor")
                    .ignoresSafeArea()

                VStack {


                    VStack(spacing: 40) {
                        ZStack {
                            CircularSeekBars(progress: $progress, hapticEngine: hapticEngine)
                                .frame(width: 250, height: 250)

                            Image("elipse")
                                .resizable()
                                .frame(width: 190, height: 190)

                            Text("\(Int(progress))°")
                                .font(.custom("Inter18pt-SemiBold", size: 45))
                                .foregroundColor(isTapped ? Color("cs_circle_color") : .white)
                                .scaleEffect(isTapped ? 1.05 : 1.0)
                                .animation(.easeOut(duration: 0.2), value: isTapped)
                                .onTapGesture {
                                    if progress < 360 {
                                        progress += 1
                                        simpleSuccess()
                                        isTapped = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                            isTapped = false
                                        }
                                    }
                                }
                        }

                        Text("Set Lock Screen")
                            .font(.custom("Inter18pt-Medium", size: 16))
                            .foregroundColor(Color("blue"))



                        // First Circular Button
                        ZStack {
                            Circle()
                                .fill(Color("blue"))
                                .frame(width: 77, height: 77)
                                .overlay(
                                    Circle()
                                        .stroke(Color("blue"), lineWidth: 2) // Equivalent to lockcircle drawable
                                )

                            HStack(spacing: 4) {
                                Text("360°")
                                    .font(.custom("Inter18pt-SemiBold", size: 16))
                                    .foregroundColor(.white)


                                Image("downvector") // Replace with actual SF Symbol or asset
                                    .resizable()
                                    .renderingMode(.template)
                                    .frame(width: 12, height: 12)
                                    .foregroundColor(.white)
                                    .padding(.leading,2)



                            }
                        }

                        // Second Circular Button
                        ZStack {
                            Circle()
                                .fill(Color("cs_circle_color")) // Use Color Set in Assets
                                .frame(width: 77, height: 77)

                            Image("tick") // Replace with actual SF Symbol or asset
                                .resizable()
                                .renderingMode(.template)
                                .frame(width: 45, height: 45)
                                .foregroundColor(Color("TextColor"))
                        }


                    }

                }
            }
            .onAppear {
                prepareHaptics()
            }
        }
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

        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)

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
        let center = CGPoint(x: 125, y: 125)
        let dx = location.x - center.x
        let dy = location.y - center.y
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

    private func simpleSuccess() {
        guard let engine = hapticEngine, CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)

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
