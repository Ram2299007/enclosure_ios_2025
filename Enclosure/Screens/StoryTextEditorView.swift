import SwiftUI
import Photos

// MARK: - Text Style (B / Normal / I)
private enum StoryTextStyle: CaseIterable {
    case normal, bold, italic
    var label: String {
        switch self { case .normal: return "N"; case .bold: return "B"; case .italic: return "I" }
    }
}

// MARK: - Steam / Fog Overlay (slow wispy smoke rising through gradient)
private struct DustOverlayView: View {
    var body: some View {
        ZStack {
            // Layer 1 — large slow fog blobs (primary smoke)
            TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { timeline in
                Canvas { context, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    for i in 0..<12 {
                        let fi = Double(i)
                        let speed = 0.005 + sin(fi * 2.9) * 0.002
                        let phase = (t * speed + fi * 0.13).truncatingRemainder(dividingBy: 1.6)
                        let rawY = 1.0 - (phase / 1.6)
                        let y = rawY * size.height
                        let x = (0.15 + sin(t * 0.018 + fi * 1.3) * 0.7) * size.width
                        let fade = min(1.0, phase / 0.2) * max(0.0, 1.0 - (phase - 1.2) / 0.4)
                        let opacity = fade * (0.08 + sin(fi * 2.1) * 0.03)
                        let w = 90.0 + sin(fi * 3.7) * 40.0
                        let h = 45.0 + sin(fi * 1.9) * 20.0
                        context.opacity = max(0, opacity)
                        context.fill(
                            Path(ellipseIn: CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h)),
                            with: .color(.white)
                        )
                    }
                }
            }
            .blur(radius: 30)
            .blendMode(.screen)

            // Layer 2 — smaller mid-speed wisps (detail)
            TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { timeline in
                Canvas { context, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    for i in 0..<18 {
                        let fi = Double(i)
                        let speed = 0.008 + sin(fi * 4.1) * 0.003
                        let phase = (t * speed + fi * 0.08).truncatingRemainder(dividingBy: 1.3)
                        let rawY = 1.0 - (phase / 1.3)
                        let y = rawY * size.height
                        let x = (0.5 + sin(t * 0.025 + fi * 1.7) * 0.42) * size.width
                        let fade = min(1.0, phase / 0.15) * max(0.0, 1.0 - (phase - 1.0) / 0.3)
                        let opacity = fade * (0.06 + abs(sin(fi * 3.3)) * 0.03)
                        let w = 40.0 + sin(fi * 5.1) * 18.0
                        let h = 20.0 + sin(fi * 2.3) * 10.0
                        context.opacity = max(0, opacity)
                        context.fill(
                            Path(ellipseIn: CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h)),
                            with: .color(.white)
                        )
                    }
                }
            }
            .blur(radius: 14)
            .blendMode(.softLight)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Royal Font Model
private struct RoyalFont {
    let baseTypingSize: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    let italic: Bool
    let previewSize: CGFloat
    let previewWeight: Font.Weight
    let previewDesign: Font.Design
    var customFontName: String? = nil

    func typingFont(scale: CGFloat = 1.0) -> Font {
        if let name = customFontName {
            return Font.custom(name, size: max(12, baseTypingSize * scale))
        }
        let f = Font.system(size: max(12, baseTypingSize * scale), weight: weight, design: design)
        return italic ? f.italic() : f
    }
    var previewFont: Font {
        if let name = customFontName {
            return Font.custom(name, size: previewSize)
        }
        return Font.system(size: previewSize, weight: previewWeight, design: previewDesign)
    }
}

// MARK: - Story Text Editor
struct StoryTextEditorView: View {
    var onPost: (([PHAsset], String) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var selectedGradient = 0
    @State private var selectedFont = 0
    @State private var textStyle: StoryTextStyle = .normal
    @FocusState private var isTextFocused: Bool
    @State private var showPreview = false
    @State private var capturedAssets: [PHAsset] = []
    @State private var glowPulse = false

    // MARK: - 15 Rich Royal Gradients (3-stop deep colors)
    private let gradients: [(name: String, colors: [Color])] = [
        ("Royal",    [Color(hex: "#0D1B40"), Color(hex: "#1A3A6E"), Color(hex: "#C9972A")]),
        ("Emerald",  [Color(hex: "#062215"), Color(hex: "#0B6E38"), Color(hex: "#1FCA6A")]),
        ("Burgundy", [Color(hex: "#3B0020"), Color(hex: "#8B1A4A"), Color(hex: "#E8A0A0")]),
        ("Sapphire", [Color(hex: "#020524"), Color(hex: "#0A2472"), Color(hex: "#1565C0")]),
        ("Amethyst", [Color(hex: "#1A0533"), Color(hex: "#7B1FA2"), Color(hex: "#E040FB")]),
        ("Obsidian", [Color(hex: "#1C1C2E"), Color(hex: "#16213E"), Color(hex: "#0F3460")]),
        ("Crimson",  [Color(hex: "#1A0000"), Color(hex: "#8B0000"), Color(hex: "#C62828")]),
        ("Jade",     [Color(hex: "#002828"), Color(hex: "#00695C"), Color(hex: "#00BFA5")]),
        ("Gilded",   [Color(hex: "#1C1008"), Color(hex: "#7D5A00"), Color(hex: "#F5C518")]),
        ("Slate",    [Color(hex: "#0F172A"), Color(hex: "#1E3A5F"), Color(hex: "#2196F3")]),
        ("Copper",   [Color(hex: "#2C1204"), Color(hex: "#8B4513"), Color(hex: "#D2691E")]),
        ("Aurora",   [Color(hex: "#001020"), Color(hex: "#006050"), Color(hex: "#00E5CC")]),
        ("Dusk",     [Color(hex: "#1A0A00"), Color(hex: "#C0392B"), Color(hex: "#F39C12")]),
        ("Void",     [Color(hex: "#050505"), Color(hex: "#0D0D1A"), Color(hex: "#1A1A2E")]),
        ("Rose",     [Color(hex: "#2D0A1F"), Color(hex: "#8B2252"), Color(hex: "#FFB6C1")])
    ]

    // MARK: - 15 Royal Fonts (system → supports Devanagari/Marathi/Hindi/all scripts)
    private let royalFonts: [RoyalFont] = [
        RoyalFont(baseTypingSize: 32, weight: .regular,   design: .serif,      italic: false,
                  previewSize: 19, previewWeight: .regular,   previewDesign: .serif),
        RoyalFont(baseTypingSize: 30, weight: .bold,      design: .serif,      italic: false,
                  previewSize: 18, previewWeight: .bold,      previewDesign: .serif),
        RoyalFont(baseTypingSize: 36, weight: .light,     design: .serif,      italic: false,
                  previewSize: 22, previewWeight: .light,     previewDesign: .serif),
        RoyalFont(baseTypingSize: 30, weight: .heavy,     design: .default,    italic: false,
                  previewSize: 17, previewWeight: .heavy,     previewDesign: .default),
        RoyalFont(baseTypingSize: 32, weight: .semibold,  design: .rounded,    italic: false,
                  previewSize: 19, previewWeight: .semibold,  previewDesign: .rounded),
        RoyalFont(baseTypingSize: 32, weight: .medium,    design: .serif,      italic: true,
                  previewSize: 20, previewWeight: .medium,    previewDesign: .serif),
        RoyalFont(baseTypingSize: 28, weight: .black,     design: .default,    italic: false,
                  previewSize: 16, previewWeight: .black,     previewDesign: .default),
        RoyalFont(baseTypingSize: 31, weight: .semibold,  design: .serif,      italic: false,
                  previewSize: 18, previewWeight: .semibold,  previewDesign: .serif),
        RoyalFont(baseTypingSize: 31, weight: .bold,      design: .rounded,    italic: false,
                  previewSize: 18, previewWeight: .bold,      previewDesign: .rounded),
        RoyalFont(baseTypingSize: 38, weight: .ultraLight,design: .serif,      italic: false,
                  previewSize: 23, previewWeight: .ultraLight,previewDesign: .serif),
        RoyalFont(baseTypingSize: 28, weight: .regular,   design: .monospaced, italic: false,
                  previewSize: 16, previewWeight: .regular,   previewDesign: .monospaced),
        RoyalFont(baseTypingSize: 28, weight: .black,     design: .serif,      italic: false,
                  previewSize: 16, previewWeight: .black,     previewDesign: .serif),
        RoyalFont(baseTypingSize: 36, weight: .ultraLight,design: .rounded,    italic: false,
                  previewSize: 22, previewWeight: .ultraLight,previewDesign: .rounded),
        RoyalFont(baseTypingSize: 32, weight: .regular,    design: .serif,      italic: false,
                  previewSize: 20, previewWeight: .regular,   previewDesign: .serif,
                  customFontName: "KohinoorDevanagari-Regular"),
        RoyalFont(baseTypingSize: 38, weight: .thin,      design: .default,    italic: false,
                  previewSize: 24, previewWeight: .thin,      previewDesign: .default)
    ]

    // MARK: - Dynamic font scale (shrinks as text grows)
    private var fontSizeMultiplier: CGFloat {
        let newlineLines = text.components(separatedBy: "\n").count
        let wrapEstimate = max(0, text.count / 24)
        let totalLines = max(newlineLines, wrapEstimate)
        switch totalLines {
        case 0...4:  return 1.00
        case 5...7:  return 0.78
        case 8...10: return 0.62
        default:     return 0.50
        }
    }

    private var activeTypingFont: Font {
        let base = royalFonts[selectedFont].typingFont(scale: fontSizeMultiplier)
        switch textStyle {
        case .normal: return base
        case .bold:   return base.bold()
        case .italic: return base.italic()
        }
    }

    private var activeGradient: LinearGradient {
        LinearGradient(colors: gradients[selectedGradient].colors,
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var isPostEnabled: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            // Background gradient — tap anywhere outside text area to dismiss keyboard
            activeGradient
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: selectedGradient)
                .contentShape(Rectangle())
                .onTapGesture { isTextFocused = false }

            // Floating dust-wind particle shimmer
            DustOverlayView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()
                textInputArea
                Spacer()
                bottomControls
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { isTextFocused = true }
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { glowPulse = true }
        }
        .fullScreenCover(isPresented: $showPreview) {
            StoryPreviewView(assets: capturedAssets) { assets, caption in
                onPost?(assets, caption)
                dismiss()
            }
        }
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack(spacing: 10) {
            Button(action: { dismiss() }) {
                ZStack {
                    Circle().fill(Color.black.opacity(0.35)).frame(width: 42, height: 42)
                    Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)

            Spacer()
            styleToggle
            Spacer()

            Button(action: handlePost) {
                ZStack {
                    Circle().fill(Color(hex: Constant.themeColor)).frame(width: 46, height: 46)
                    Image("baseline_keyboard_double_arrow_right_24")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.white)
                        .padding(.top, 3)
                        .padding(.bottom, 6)
                }
            }
            .buttonStyle(.plain)
            .disabled(!isPostEnabled)
            .opacity(isPostEnabled ? 1.0 : 0.35)
            .animation(.easeInOut(duration: 0.2), value: isPostEnabled)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var styleToggle: some View {
        HStack(spacing: 0) {
            ForEach(StoryTextStyle.allCases, id: \.self) { style in
                let isActive = textStyle == style
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) { textStyle = style }
                } label: {
                    Text(style.label)
                        .font(styleButtonFont(style))
                        .foregroundColor(isActive ? Color.black : Color.white.opacity(0.85))
                        .frame(width: 40, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isActive ? Color.white : Color.clear)
                                .animation(.spring(response: 0.28, dampingFraction: 0.62), value: isActive)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 13).fill(Color.black.opacity(0.35)))
    }

    private func styleButtonFont(_ style: StoryTextStyle) -> Font {
        switch style {
        case .normal: return .system(size: 15, weight: .medium)
        case .bold:   return .system(size: 15, weight: .black)
        case .italic: return Font.system(size: 16, weight: .medium).italic()
        }
    }

    // MARK: - Text Input Area
    private var textInputArea: some View {
        ZStack {
            // Pulsing glow halo when focused
            if isTextFocused {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(glowPulse ? 0.18 : 0.0), Color.clear],
                            center: .center, startRadius: 0, endRadius: 180
                        )
                    )
                    .frame(maxWidth: .infinity).frame(height: 200)
                    .blur(radius: 18)
                    .animation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true), value: glowPulse)
                    .allowsHitTesting(false)
            }

            // Placeholder
            if text.isEmpty {
                Text("Start typing…")
                    .font(activeTypingFont)
                    .foregroundColor(.white.opacity(0.38))
                    .multilineTextAlignment(.center)
                    .allowsHitTesting(false)
            }

            // TextField — white text, cursor snaps to tap position naturally
            TextField("", text: $text, axis: .vertical)
                .font(activeTypingFont)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(1...20)
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .tint(Color(hex: "#FFE35C"))
                .focused($isTextFocused)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .animation(.spring(response: 0.35, dampingFraction: 0.72), value: fontSizeMultiplier)
                .animation(.spring(response: 0.3,  dampingFraction: 0.7),  value: selectedFont)
                .animation(.spring(response: 0.25, dampingFraction: 0.65), value: textStyle)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { isTextFocused = true }
    }

    // MARK: - Bottom Controls
    private var bottomControls: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 0.5)

            // Font tiles (no name, just "Aa") — extra vertical padding fixes shadow clipping
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(royalFonts.indices, id: \.self) { i in fontTile(i) }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)   // 14pt breathing room above & below for shadow + scale
            }
            .frame(height: 80)

            // Subtle separator between rows
            Rectangle().fill(Color.white.opacity(0.07)).frame(height: 0.5).padding(.horizontal, 20)

            // Gradient circles
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(gradients.indices, id: \.self) { i in gradientCircle(i) }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .frame(height: 56)

            Spacer().frame(height: 10)
        }
        .background(.ultraThinMaterial)
    }

    // Font tile — no name label, 50×50, shadow has room to breathe
    @ViewBuilder
    private func fontTile(_ i: Int) -> some View {
        let isActive = selectedFont == i
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) { selectedFont = i }
        } label: {
            Text("Aa")
                .font(royalFonts[i].previewFont)
                .foregroundColor(isActive ? Color.black : Color.white.opacity(0.82))
                .frame(width: 50, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isActive ? Color.white : Color.black.opacity(0.28))
                        // Shadow is drawn outside the tile bounds — parent padding keeps it visible
                        .shadow(color: isActive ? Color.white.opacity(0.70) : .clear,
                                radius: 10, x: 0, y: 0)
                )
                .scaleEffect(isActive ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.62), value: isActive)
    }

    // Gradient circle
    @ViewBuilder
    private func gradientCircle(_ i: Int) -> some View {
        let isActive = selectedGradient == i
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.68)) { selectedGradient = i }
        } label: {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: gradients[i].colors,
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 32, height: 32)
                    .shadow(color: isActive ? Color.white.opacity(0.5) : .clear, radius: 8, x: 0, y: 0)
                if isActive {
                    Circle().stroke(Color.white, lineWidth: 2.5).frame(width: 40, height: 40)
                    Circle().fill(Color.white).frame(width: 5, height: 5)
                }
            }
            .frame(width: 40, height: 40)
            .scaleEffect(isActive ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.62), value: isActive)
    }

    // MARK: - Post: Render → Save → Preview
    private func handlePost() {
        isTextFocused = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { renderAndSave() }
    }

    private func renderAndSave() {
        let renderer = ImageRenderer(content: renderCanvas)
        renderer.scale = UIScreen.main.scale
        guard let image = renderer.uiImage else { return }
        saveToPhotoLibrary(image: image)
    }

    @ViewBuilder
    private var renderCanvas: some View {
        ZStack {
            LinearGradient(colors: gradients[selectedGradient].colors,
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(text)
                .font(activeTypingFont)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(40)
        }
        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
    }

    private func saveToPhotoLibrary(image: UIImage) {
        let doSave = {
            var placeholder: PHObjectPlaceholder?
            PHPhotoLibrary.shared().performChanges({
                let req = PHAssetChangeRequest.creationRequestForAsset(from: image)
                placeholder = req.placeholderForCreatedAsset
            }) { success, _ in
                guard success, let id = placeholder?.localIdentifier else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let result = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
                    if let asset = result.firstObject {
                        capturedAssets = [asset]
                        showPreview = true
                    }
                }
            }
        }
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited: doSave()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { s in
                if s == .authorized || s == .limited { doSave() }
            }
        default: doSave()
        }
    }
}
