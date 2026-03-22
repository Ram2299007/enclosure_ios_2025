import SwiftUI
import Photos

// MARK: - Text Style (B / Normal / I)
private enum StoryTextStyle: CaseIterable {
    case normal, bold, italic
    var label: String {
        switch self { case .normal: return "N"; case .bold: return "B"; case .italic: return "I" }
    }
}

// MARK: - Night Wind Particle Effect
private struct NightWindParticlesView: View {
    var body: some View {
        ZStack {
            // Layer 1 — small sharp particles drifting with the wind (main effect)
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                Canvas { context, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    for i in 0..<60 {
                        let fi = Double(i)

                        // Speed varies per particle: fast foreground, slow background
                        let speed = 0.048 + (fi * 0.0171).truncatingRemainder(dividingBy: 0.072)

                        // Phase 0→1 = particle sweeps left to right
                        let phase = (t * speed + fi * 0.16667).truncatingRemainder(dividingBy: 1.0)

                        // X: crosses full width + slight sine wobble (turbulence)
                        let x = phase * (size.width + 60) - 30 + sin(t * 0.28 + fi * 0.73) * 14

                        // Y: evenly distributed rows, gentle up-down drift
                        let yBase = (fi * 0.16667).truncatingRemainder(dividingBy: 1.0) * size.height
                        let y = yBase + sin(t * 0.14 + fi * 1.41) * 20

                        // Fade in/out at horizontal edges
                        let edgeFade = min(phase / 0.07, 1.0) * min((1.0 - phase) / 0.07, 1.0)

                        // Radius: 0.8 – 2.4 pt (small sharp dots)
                        let radius = 0.8 + (fi * 0.52).truncatingRemainder(dividingBy: 1.6)

                        // Twinkle: each particle shimmers at its own frequency
                        let twinkleFreq = 1.0 + (fi * 0.29).truncatingRemainder(dividingBy: 1.6)
                        let twinkle = 0.5 + 0.5 * sin(t * twinkleFreq + fi * 2.71)

                        // Base opacity — kept subtle so content stays in focus
                        let baseOpacity = 0.10 + (fi * 0.06).truncatingRemainder(dividingBy: 0.14)
                        let opacity = edgeFade * baseOpacity * (0.5 + twinkle * 0.5)

                        // Most white, occasional ice-blue for cool night feel
                        let color: Color = (i % 7 == 0)
                            ? Color(red: 0.6, green: 0.85, blue: 1.0)
                            : Color.white

                        context.opacity = max(0, min(1, opacity))
                        context.fill(
                            Path(ellipseIn: CGRect(x: x - radius, y: y - radius,
                                                   width: radius * 2, height: radius * 2)),
                            with: .color(color)
                        )
                    }
                }
            }

            // Layer 2 — faint soft glow orbs for atmospheric depth
            TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { timeline in
                Canvas { context, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    for i in 0..<10 {
                        let fi = Double(i)
                        let speed = 0.011 + (fi * 0.008).truncatingRemainder(dividingBy: 0.016)
                        let phase = (t * speed + fi * 0.1).truncatingRemainder(dividingBy: 1.0)
                        let x = phase * size.width + sin(t * 0.07 + fi * 1.2) * 35
                        let y = (0.08 + (fi * 0.085).truncatingRemainder(dividingBy: 0.84)) * size.height
                                + sin(t * 0.055 + fi * 0.94) * 45
                        let edgeFade = min(phase / 0.12, 1.0) * min((1.0 - phase) / 0.12, 1.0)
                        let w = 55.0 + sin(fi * 3.1) * 28
                        let h = 28.0 + sin(fi * 2.2) * 13
                        context.opacity = max(0, edgeFade * 0.030)
                        context.fill(
                            Path(ellipseIn: CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h)),
                            with: .color(.white)
                        )
                    }
                }
            }
            .blur(radius: 22)
            .blendMode(.screen)
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

    func typingUIFont(scale: CGFloat = 1.0, bold: Bool = false, forcedItalic: Bool = false) -> UIFont {
        let size = max(12, baseTypingSize * scale)
        if let name = customFontName {
            return UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size)
        }
        let uiWeight: UIFont.Weight = bold ? .bold : {
            switch weight {
            case .ultraLight: return .ultraLight
            case .thin:       return .thin
            case .light:      return .light
            case .medium:     return .medium
            case .semibold:   return .semibold
            case .bold:       return .bold
            case .heavy:      return .heavy
            case .black:      return .black
            default:          return .regular
            }
        }()
        let systemDesign: UIFontDescriptor.SystemDesign = {
            switch design {
            case .serif:      return .serif
            case .rounded:    return .rounded
            case .monospaced: return .monospaced
            default:          return .default
            }
        }()
        let base = UIFont.systemFont(ofSize: size, weight: uiWeight)
        var descriptor = base.fontDescriptor
        if let designed = descriptor.withDesign(systemDesign) { descriptor = designed }
        if italic || forcedItalic {
            descriptor = descriptor.withSymbolicTraits(.traitItalic) ?? descriptor
        }
        return UIFont(descriptor: descriptor, size: size)
    }
}

// MARK: - Link-Detecting Story Text View
private struct StoryTextView: UIViewRepresentable {
    @Binding var text: String
    var uiFont: UIFont
    var isEditing: Bool
    var onEditingChanged: (Bool) -> Void

    private static let linkDetector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue
    )

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.backgroundColor = .clear
        tv.textColor = .white
        tv.textAlignment = .center
        tv.isScrollEnabled = false
        tv.delegate = context.coordinator
        tv.autocorrectionType = .no
        tv.autocapitalizationType = .none
        tv.tintColor = UIColor(red: 1.0, green: 0.89, blue: 0.36, alpha: 1.0)
        tv.textContainerInset = UIEdgeInsets(top: 16, left: 24, bottom: 16, right: 24)
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if !context.coordinator.isUpdating && uiView.text != text {
            context.coordinator.isUpdating = true
            uiView.text = text
            context.coordinator.applyLinkStyling(to: uiView)
            context.coordinator.isUpdating = false
        }
        context.coordinator.updateFont(in: uiView, to: uiFont)
        if isEditing && !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isEditing && uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: StoryTextView
        var isUpdating = false
        private var lastFont: UIFont?

        init(parent: StoryTextView) { self.parent = parent }

        func updateFont(in textView: UITextView, to newFont: UIFont) {
            guard lastFont != newFont else { return }
            lastFont = newFont
            UIView.transition(with: textView, duration: 0.22,
                              options: [.transitionCrossDissolve, .allowUserInteraction]) {
                textView.font = newFont
                self.applyLinkStyling(to: textView)
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isUpdating else { return }
            isUpdating = true
            parent.text = textView.text
            applyLinkStyling(to: textView)
            isUpdating = false
        }

        func textViewDidBeginEditing(_ textView: UITextView) { parent.onEditingChanged(true) }
        func textViewDidEndEditing(_ textView: UITextView)   { parent.onEditingChanged(false) }

        func applyLinkStyling(to textView: UITextView) {
            let fullText = textView.text ?? ""
            let savedRange = textView.selectedRange
            let currentFont = textView.font ?? UIFont.systemFont(ofSize: 17)
            let baseAttrs: [NSAttributedString.Key: Any] = [
                .font: currentFont,
                .foregroundColor: UIColor.white
            ]
            let attrStr = NSMutableAttributedString(string: fullText, attributes: baseAttrs)
            let nsRange = NSRange(fullText.startIndex..., in: fullText)
            StoryTextView.linkDetector?
                .matches(in: fullText, options: [], range: nsRange)
                .forEach { match in
                    attrStr.addAttributes([
                        .underlineStyle: NSUnderlineStyle.single.rawValue,
                        .underlineColor: UIColor(red: 0.65, green: 0.88, blue: 1.0, alpha: 1.0),
                        .foregroundColor: UIColor(red: 0.65, green: 0.88, blue: 1.0, alpha: 1.0)
                    ], range: match.range)
                }
            textView.attributedText = attrStr
            textView.selectedRange = savedRange
            textView.typingAttributes = [
                .font: currentFont,
                .foregroundColor: UIColor.white
            ]
        }
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
    @State private var isTextEditing: Bool = false
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
        RoyalFont(baseTypingSize: 30, weight: .regular,   design: .serif,      italic: false,
                  previewSize: 18, previewWeight: .regular,   previewDesign: .serif,
                  customFontName: "Gotu-Regular"),
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

    private var activeTypingUIFont: UIFont {
        royalFonts[selectedFont].typingUIFont(
            scale: fontSizeMultiplier,
            bold: textStyle == .bold,
            forcedItalic: textStyle == .italic
        )
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
                .onTapGesture { isTextEditing = false }

            // Night wind particle shimmer
            NightWindParticlesView()
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { isTextEditing = true }
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
            if isTextEditing {
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

            // UITextView — smooth font transitions + auto URL underline
            StoryTextView(
                text: $text,
                uiFont: activeTypingUIFont,
                isEditing: isTextEditing,
                onEditingChanged: { isTextEditing = $0 }
            )
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { isTextEditing = true }
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
        isTextEditing = false
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
