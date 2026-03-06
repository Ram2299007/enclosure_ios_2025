import SwiftUI

// MARK: - Liquid Glass Download Progress View
// Modern iOS 26 liquid glass style circular progress indicator
struct LiquidGlassProgressView: View {
    let progress: Double // 0-100
    var size: CGFloat = 60
    var themeColorHex: String = Constant.themeColor // App theme color
    
    private var themeColor: Color {
        Color(hex: themeColorHex)
    }
    
    private var normalizedProgress: CGFloat {
        CGFloat(min(max(progress, 0), 100)) / 100.0
    }
    
    private var ringLineWidth: CGFloat {
        size * 0.06 // Proportional ring thickness
    }
    
    private var fontSize: CGFloat {
        size * 0.25
    }
    
    var body: some View {
        ZStack {
            // LAYER 1: Outer glow (uses theme color)
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            themeColor.opacity(0.15),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: size * 0.35,
                        endRadius: size * 0.55
                    )
                )
                .frame(width: size + 10, height: size + 10)
            
            // LAYER 2: Track ring (background)
            Circle()
                .stroke(themeColor.opacity(0.2), lineWidth: ringLineWidth)
                .frame(width: size - 2, height: size - 2)
            
            // LAYER 3: Progress ring (solid theme color, no rainbow)
            Circle()
                .trim(from: 0, to: normalizedProgress)
                .stroke(
                    themeColor,
                    style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round)
                )
                .frame(width: size - 2, height: size - 2)
                .rotationEffect(.degrees(-90))
                .shadow(color: themeColor.opacity(0.4), radius: 4, x: 0, y: 0)
            
            // LAYER 4: Glass background circle
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: size - ringLineWidth * 2 - 4, height: size - ringLineWidth * 2 - 4)
                .overlay(
                    // Glass gradient sheen
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.25),
                                    Color.white.opacity(0.05),
                                    Color.clear
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    // Subtle glass border
                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                )
                .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
            
            // LAYER 5: Percentage text
            Text("\(Int(progress))%")
                .font(.custom("Inter18pt-Bold", size: fontSize))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
        }
        .frame(width: size + 10, height: size + 10)
    }
}
