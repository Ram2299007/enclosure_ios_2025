import SwiftUI
import Photos

// MARK: - Night Wind Particle Effect
private struct NightWindParticlesView: View {
    var body: some View {
        ZStack {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                Canvas { context, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    for i in 0..<60 {
                        let fi = Double(i)
                        let speed = 0.048 + (fi * 0.0171).truncatingRemainder(dividingBy: 0.072)
                        let phase = (t * speed + fi * 0.16667).truncatingRemainder(dividingBy: 1.0)
                        let x = phase * (size.width + 60) - 30 + sin(t * 0.28 + fi * 0.73) * 14
                        let yBase = (fi * 0.16667).truncatingRemainder(dividingBy: 1.0) * size.height
                        let y = yBase + sin(t * 0.14 + fi * 1.41) * 20
                        let edgeFade = min(phase / 0.07, 1.0) * min((1.0 - phase) / 0.07, 1.0)
                        let radius = 0.8 + (fi * 0.52).truncatingRemainder(dividingBy: 1.6)
                        let twinkleFreq = 1.0 + (fi * 0.29).truncatingRemainder(dividingBy: 1.6)
                        let twinkle = 0.5 + 0.5 * sin(t * twinkleFreq + fi * 2.71)
                        let baseOpacity = 0.10 + (fi * 0.06).truncatingRemainder(dividingBy: 0.14)
                        let opacity = edgeFade * baseOpacity * (0.5 + twinkle * 0.5)
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

    func typingUIFont(scale: CGFloat = 1.0) -> UIFont {
        let size = max(12, baseTypingSize * scale)
        if let name = customFontName {
            return UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size)
        }
        let uiWeight: UIFont.Weight = {
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
        if italic {
            descriptor = descriptor.withSymbolicTraits(.traitItalic) ?? descriptor
        }
        return UIFont(descriptor: descriptor, size: size)
    }
}

// MARK: - Centered-Caret UITextView
private class CenteredCaretTextView: UITextView {
    override func caretRect(for position: UITextPosition) -> CGRect {
        var rect = super.caretRect(for: position)
        if (text ?? "").isEmpty {
            let insetWidth = bounds.width - textContainerInset.left - textContainerInset.right
            rect.origin.x = textContainerInset.left + (insetWidth - rect.width) / 2
        }
        return rect
    }
}

// MARK: - Link-Detecting Story Text View
private struct StoryTextView: UIViewRepresentable {
    @Binding var text: String
    var uiFont: UIFont
    var textColor: UIColor
    var isEditing: Bool
    var onEditingChanged: (Bool) -> Void

    private static let linkDetector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue
    )

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UITextView {
        let tv = CenteredCaretTextView()
        tv.backgroundColor = .clear
        tv.textColor = textColor
        tv.textAlignment = .center
        tv.isScrollEnabled = false
        tv.delegate = context.coordinator
        tv.autocorrectionType = .no
        tv.autocapitalizationType = .none
        tv.tintColor = cursorTint(for: textColor)
        // Horizontal padding lives here so the view always fills full width
        // and center alignment reliably places the cursor at screen center
        tv.textContainerInset = UIEdgeInsets(top: 4, left: 28, bottom: 4, right: 28)
        tv.textContainer.lineFragmentPadding = 0
        tv.font = uiFont
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self

        // Sync text
        if !context.coordinator.isUpdating && uiView.text != text {
            context.coordinator.isUpdating = true
            uiView.text = text
            context.coordinator.applyLinkStyling(to: uiView)
            context.coordinator.isUpdating = false
        }

        // Update text color + cursor tint
        if uiView.textColor != textColor {
            uiView.textColor = textColor
            uiView.tintColor = cursorTint(for: textColor)
            context.coordinator.applyLinkStyling(to: uiView)
        }

        // Smooth font cross-dissolve
        context.coordinator.updateFont(in: uiView, to: uiFont)

        // Focus
        if isEditing && !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isEditing && uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    // Wrap-content sizing: always fill full proposed width, wrap height
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let w = proposal.width ?? UIScreen.main.bounds.width
        let fitting = uiView.sizeThatFits(CGSize(width: w, height: .greatestFiniteMagnitude))
        return CGSize(width: w, height: max(fitting.height, 44))
    }

    private func cursorTint(for color: UIColor) -> UIColor {
        color == .black
            ? UIColor.darkGray
            : UIColor(red: 1.0, green: 0.89, blue: 0.36, alpha: 1.0)
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

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            let current = textView.text ?? ""
            let newText = (current as NSString).replacingCharacters(in: range, with: text)
            if newText.components(separatedBy: "\n").count > 11 {
                if !current.hasSuffix("...") {
                    isUpdating = true
                    let withDots = current + "..."
                    textView.text = withDots
                    parent.text = withDots
                    applyLinkStyling(to: textView)
                    isUpdating = false
                }
                return false
            }
            return true
        }

        func textViewDidBeginEditing(_ textView: UITextView) { parent.onEditingChanged(true) }
        func textViewDidEndEditing(_ textView: UITextView)   { parent.onEditingChanged(false) }

        func applyLinkStyling(to textView: UITextView) {
            let fullText = textView.text ?? ""
            let savedRange = textView.selectedRange
            let currentFont = textView.font ?? UIFont.systemFont(ofSize: 17)
            let baseColor = textView.textColor ?? .white
            let isLight = (baseColor == .black)
            let linkColor: UIColor = isLight
                ? .systemBlue
                : UIColor(red: 0.65, green: 0.88, blue: 1.0, alpha: 1.0)

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            let baseAttrs: [NSAttributedString.Key: Any] = [
                .font: currentFont,
                .foregroundColor: baseColor,
                .paragraphStyle: paragraphStyle
            ]
            let attrStr = NSMutableAttributedString(string: fullText, attributes: baseAttrs)
            if !fullText.isEmpty {
                let nsRange = NSRange(fullText.startIndex..., in: fullText)
                StoryTextView.linkDetector?
                    .matches(in: fullText, options: [], range: nsRange)
                    .forEach { match in
                        attrStr.addAttributes([
                            .underlineStyle: NSUnderlineStyle.single.rawValue,
                            .underlineColor: linkColor,
                            .foregroundColor: linkColor
                        ], range: match.range)
                    }
            }
            textView.attributedText = attrStr
            textView.selectedRange = savedRange
            textView.typingAttributes = [
                .font: currentFont,
                .foregroundColor: baseColor,
                .paragraphStyle: paragraphStyle
            ]
        }
    }
}

// MARK: - Background Selection
private enum BgSelection: Equatable {
    case gradient(Int)
    case solid(Int)
    var isSolid: Bool { if case .solid = self { return true }; return false }
}

// MARK: - Bottom Picker Tab
private enum BottomPickerTab: CaseIterable {
    case color, font
    var icon: String {
        switch self {
        case .color: return "paintpalette.fill"
        case .font:  return "textformat.size"
        }
    }
}

// MARK: - Story Text Editor
struct StoryTextEditorView: View {
    var onPost: (([PHAsset], String) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var bgSelection: BgSelection = .gradient(0)
    @State private var selectedFont = 0
    @State private var bottomTab: BottomPickerTab = .color
    @State private var isTextEditing: Bool = false
    @State private var showPreview = false
    @State private var capturedAssets: [PHAsset] = []
    @State private var glowPulse = false

    // MARK: - 15 Rich Gradients
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

    // MARK: - Solid Colors
    private let solidColors: [(name: String, color: Color)] = [
        ("Black",   .black),
        ("Red",     Color(hex: "#D32F2F")),
        ("Orange",  Color(hex: "#F57C00")),
        ("Amber",   Color(hex: "#FFC107")),
        ("Green",   Color(hex: "#388E3C")),
        ("Teal",    Color(hex: "#00796B")),
        ("Blue",    Color(hex: "#1976D2")),
        ("Indigo",  Color(hex: "#303F9F")),
        ("Purple",  Color(hex: "#7B1FA2")),
        ("Pink",    Color(hex: "#C2185B")),
        ("Brown",   Color(hex: "#5D4037")),
        ("Grey",    Color(hex: "#455A64")),
        ("Navy",    Color(hex: "#0A1929"))
    ]

    // MARK: - 15 Royal Fonts
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

    // MARK: - Computed Properties
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
        royalFonts[selectedFont].typingFont(scale: fontSizeMultiplier)
    }

    private var activeTypingUIFont: UIFont {
        royalFonts[selectedFont].typingUIFont(scale: fontSizeMultiplier)
    }

    // Light backgrounds need dark text + cursor
    private var isLightBackground: Bool {
        if case .solid(let i) = bgSelection {
            return i == 3 // Amber
        }
        return false
    }

    private var contentColor: Color {
        isLightBackground ? .black : .white
    }

    private var contentUIColor: UIColor {
        isLightBackground ? .black : .white
    }

    @ViewBuilder
    private var activeBackgroundView: some View {
        switch bgSelection {
        case .gradient(let i):
            LinearGradient(colors: gradients[i].colors,
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case .solid(let i):
            solidColors[i].color
        }
    }

    private var isPostEnabled: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            // Background — tapping anywhere outside text dismisses keyboard
            activeBackgroundView
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { isTextEditing = false }
                .animation(.easeInOut(duration: 0.45), value: bgSelection)

            // Night wind particles — only for gradient backgrounds
            if !bgSelection.isSolid {
                NightWindParticlesView()
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 20)
                textInputArea
                Spacer(minLength: 20)
                bottomControls
            }
        }
        .animation(.easeInOut(duration: 0.3), value: bgSelection.isSolid)
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
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
            }
            .buttonStyle(.plain)

            Spacer()
            pickerToggle
            Spacer()

            Button(action: handlePost) {
                Image("baseline_keyboard_double_arrow_right_24")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color(hex: Constant.themeColor), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .disabled(!isPostEnabled)
            .opacity(isPostEnabled ? 1.0 : 0.35)
            .animation(.easeInOut(duration: 0.2), value: isPostEnabled)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Color / Font Toggle (glass capsule)
    private var pickerToggle: some View {
        HStack(spacing: 4) {
            ForEach(BottomPickerTab.allCases, id: \.self) { tab in
                let isActive = bottomTab == tab
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) { bottomTab = tab }
                } label: {
                    Group {
                        if tab == .color {
                            Image(systemName: tab.icon)
                                .symbolRenderingMode(.multicolor)
                        } else {
                            Image(systemName: tab.icon)
                                .foregroundColor(.cyan)
                        }
                    }
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 48, height: 40)
                    .background(
                        isActive
                            ? AnyShapeStyle(Color.white.opacity(0.15))
                            : AnyShapeStyle(Color.clear)
                    )
                    .clipShape(Capsule())
                    .opacity(isActive ? 1.0 : 0.4)
                    .scaleEffect(isActive ? 1.05 : 1.0)
                }
                .buttonStyle(.plain)
                .animation(.spring(response: 0.28, dampingFraction: 0.62), value: isActive)
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
    }

    // MARK: - Text Input Area
    private var textInputArea: some View {
        ZStack(alignment: .center) {
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

            // Placeholder — centered, matches text view position
            if text.isEmpty {
                Text("Start typing\u{2026}")
                    .font(activeTypingFont)
                    .foregroundColor(contentColor.opacity(0.38))
                    .multilineTextAlignment(.center)
                    .allowsHitTesting(false)
            }

            // UITextView — fills full width; horizontal insets set inside UITextView
            StoryTextView(
                text: $text,
                uiFont: activeTypingUIFont,
                textColor: contentUIColor,
                isEditing: isTextEditing,
                onEditingChanged: { isTextEditing = $0 }
            )
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bottom Controls (glass background)
    private var bottomControls: some View {
        VStack(spacing: 0) {
            Group {
                if bottomTab == .color {
                    colorPicker
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                } else {
                    fontPicker
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: bottomTab)
        }
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }

    // MARK: - Color Picker (gradients + solids)
    private var colorPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(gradients.indices, id: \.self) { i in gradientCircle(i) }

                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 1.5, height: 26)

                ForEach(solidColors.indices, id: \.self) { i in solidCircle(i) }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(height: 60)
    }

    // MARK: - Font Picker (transparent)
    private var fontPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(royalFonts.indices, id: \.self) { i in fontTile(i) }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(height: 60)
    }

    // MARK: - Gradient Circle
    @ViewBuilder
    private func gradientCircle(_ i: Int) -> some View {
        let isActive = bgSelection == .gradient(i)
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.68)) { bgSelection = .gradient(i) }
        } label: {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: gradients[i].colors,
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 32, height: 32)
                    .shadow(color: isActive ? Color.white.opacity(0.5) : .clear, radius: 8)
                if isActive {
                    Circle().stroke(Color.white, lineWidth: 2.5).frame(width: 40, height: 40)
                    Circle().fill(Color.white).frame(width: 5, height: 5)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .scaleEffect(isActive ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.62), value: isActive)
    }

    // MARK: - Solid Color Circle
    @ViewBuilder
    private func solidCircle(_ i: Int) -> some View {
        let isActive = bgSelection == .solid(i)
        let color = solidColors[i].color
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.68)) { bgSelection = .solid(i) }
        } label: {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                            .frame(width: 32, height: 32)
                    )
                    .shadow(color: isActive ? Color.white.opacity(0.5) : .clear, radius: 8)
                if isActive {
                    Circle().stroke(Color.white, lineWidth: 2.5).frame(width: 40, height: 40)
                    Circle().fill(Color.white).frame(width: 5, height: 5)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .scaleEffect(isActive ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.62), value: isActive)
    }

    // MARK: - Font Tile
    @ViewBuilder
    private func fontTile(_ i: Int) -> some View {
        let isActive = selectedFont == i
        Button {
            withAnimation(.easeInOut(duration: 0.22)) { selectedFont = i }
        } label: {
            VStack(spacing: 4) {
                Text("Aa")
                    .font(royalFonts[i].previewFont)
                    .foregroundColor(isActive ? .white : .white.opacity(0.4))
                Circle()
                    .fill(isActive ? Color.white : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(width: 48, height: 50)
            .contentShape(Rectangle())
            .scaleEffect(isActive ? 1.12 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.62), value: isActive)
    }

    // MARK: - Post: Render -> Save -> Preview
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
            activeBackgroundView
            Text(text)
                .font(activeTypingFont)
                .foregroundColor(contentColor)
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
