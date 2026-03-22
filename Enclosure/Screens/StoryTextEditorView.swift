import SwiftUI
import Photos

// MARK: - Text Style (B / Normal / I)
private enum StoryTextStyle: CaseIterable {
    case normal, bold, italic
    var label: String {
        switch self { case .normal: return "N"; case .bold: return "B"; case .italic: return "I" }
    }
}

// MARK: - Royal Font Model
private struct RoyalFont {
    let name: String
    let typingFont: Font   // large, used while typing
    let previewFont: Font  // smaller, shown inside tile
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

    // MARK: - 10 Rich Royal Gradients
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
        ("Slate",    [Color(hex: "#0F172A"), Color(hex: "#1E3A5F"), Color(hex: "#2196F3")])
    ]

    // MARK: - 10 Royal Fonts (all system → support Devanagari / Marathi / Hindi / all scripts)
    private let royalFonts: [RoyalFont] = [
        RoyalFont(name: "Classique",
                  typingFont: .system(size: 32, weight: .regular, design: .serif),
                  previewFont: .system(size: 20, weight: .regular, design: .serif)),
        RoyalFont(name: "Prestige",
                  typingFont: .system(size: 30, weight: .bold, design: .serif),
                  previewFont: .system(size: 19, weight: .bold, design: .serif)),
        RoyalFont(name: "Noble",
                  typingFont: .system(size: 36, weight: .light, design: .serif),
                  previewFont: .system(size: 22, weight: .light, design: .serif)),
        RoyalFont(name: "Imperial",
                  typingFont: .system(size: 30, weight: .heavy),
                  previewFont: .system(size: 18, weight: .heavy)),
        RoyalFont(name: "Velvet",
                  typingFont: .system(size: 32, weight: .semibold, design: .rounded),
                  previewFont: .system(size: 20, weight: .semibold, design: .rounded)),
        RoyalFont(name: "Luxe",
                  typingFont: Font.system(size: 32, weight: .medium, design: .serif).italic(),
                  previewFont: Font.system(size: 20, weight: .medium, design: .serif).italic()),
        RoyalFont(name: "Grand",
                  typingFont: .system(size: 28, weight: .black),
                  previewFont: .system(size: 17, weight: .black)),
        RoyalFont(name: "Regal",
                  typingFont: .system(size: 31, weight: .semibold, design: .serif),
                  previewFont: .system(size: 19, weight: .semibold, design: .serif)),
        RoyalFont(name: "Crown",
                  typingFont: .system(size: 31, weight: .bold, design: .rounded),
                  previewFont: .system(size: 19, weight: .bold, design: .rounded)),
        RoyalFont(name: "Elite",
                  typingFont: .system(size: 38, weight: .ultraLight, design: .serif),
                  previewFont: .system(size: 23, weight: .ultraLight, design: .serif))
    ]

    // MARK: - Computed active font (base + B/I modifier)
    private var activeTypingFont: Font {
        let base = royalFonts[selectedFont].typingFont
        switch textStyle {
        case .normal: return base
        case .bold:   return base.bold()
        case .italic: return base.italic()
        }
    }

    private var activeGradient: LinearGradient {
        LinearGradient(
            colors: gradients[selectedGradient].colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var isPostEnabled: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            activeGradient
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: selectedGradient)

            VStack(spacing: 0) {
                topBar
                Spacer()
                textInputArea
                Spacer()
                bottomControls
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isTextFocused = true
            }
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
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
            // Close
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.35))
                        .frame(width: 42, height: 42)
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // B / N / I style toggle (pill segmented control)
            styleToggle

            Spacer()

            // Send button — same as StoryPreviewView
            Button(action: handlePost) {
                ZStack {
                    Circle()
                        .fill(Color(hex: Constant.themeColor))
                        .frame(width: 46, height: 46)
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

    // B / Normal / I segmented pill
    private var styleToggle: some View {
        HStack(spacing: 0) {
            ForEach(StoryTextStyle.allCases, id: \.self) { style in
                let isActive = textStyle == style
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) {
                        textStyle = style
                    }
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
        .background(
            RoundedRectangle(cornerRadius: 13)
                .fill(Color.black.opacity(0.35))
        )
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
                            colors: [
                                Color.white.opacity(glowPulse ? 0.18 : 0.0),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 180
                        )
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .blur(radius: 18)
                    .animation(
                        .easeInOut(duration: 1.3).repeatForever(autoreverses: true),
                        value: glowPulse
                    )
            }

            // Placeholder
            if text.isEmpty {
                Text("Start typing…")
                    .font(activeTypingFont)
                    .foregroundColor(.white.opacity(0.38))
                    .multilineTextAlignment(.center)
                    .allowsHitTesting(false)
            }

            // Text field — bright yellow cursor for visibility (highlight symbol)
            TextField("", text: $text, axis: .vertical)
                .font(activeTypingFont)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(1...9)
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .tint(Color(hex: "#FFE35C"))
                .focused($isTextFocused)
                .animation(
                    .spring(response: 0.3, dampingFraction: 0.7),
                    value: selectedFont
                )
                .animation(
                    .spring(response: 0.25, dampingFraction: 0.65),
                    value: textStyle
                )
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { isTextFocused = true }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 0) {
            // Glass separator
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 0.5)

            VStack(spacing: 12) {
                // Active font name
                Text(royalFonts[selectedFont].name.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.65))
                    .kerning(2.0)
                    .padding(.top, 14)
                    .animation(.easeInOut(duration: 0.2), value: selectedFont)

                // ── Royal Font Picker ──
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(royalFonts.indices, id: \.self) { i in
                            fontTile(i)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }

                // ── Gradient Picker ──
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 11) {
                        ForEach(gradients.indices, id: \.self) { i in
                            gradientCircle(i)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }

                Spacer().frame(height: 10)
            }
        }
        .background(.ultraThinMaterial)
    }

    // Individual royal font tile
    @ViewBuilder
    private func fontTile(_ i: Int) -> some View {
        let isActive = selectedFont == i
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) {
                selectedFont = i
            }
        } label: {
            VStack(spacing: 5) {
                Text("Aa")
                    .font(royalFonts[i].previewFont)
                    .foregroundColor(isActive ? Color.black : Color.white.opacity(0.82))
                    .frame(height: 38)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(royalFonts[i].name)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(isActive ? Color.black.opacity(0.7) : Color.white.opacity(0.5))
                    .kerning(0.5)
                    .lineLimit(1)
            }
            .frame(width: 66, height: 66)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isActive ? Color.white : Color.black.opacity(0.28))
                    .shadow(
                        color: isActive ? Color.white.opacity(0.55) : .clear,
                        radius: 10, x: 0, y: 0
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isActive ? Color.white : Color.white.opacity(0.12),
                        lineWidth: isActive ? 0 : 1
                    )
            )
            .scaleEffect(isActive ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.62), value: isActive)
    }

    // Individual gradient circle
    @ViewBuilder
    private func gradientCircle(_ i: Int) -> some View {
        let isActive = selectedGradient == i
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.68)) {
                selectedGradient = i
            }
        } label: {
            ZStack {
                // Inner gradient disc
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradients[i].colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                    .shadow(
                        color: isActive ? Color.white.opacity(0.5) : .clear,
                        radius: 8, x: 0, y: 0
                    )

                // Active ring
                if isActive {
                    Circle()
                        .stroke(Color.white, lineWidth: 2.5)
                        .frame(width: 44, height: 44)
                }

                // Active center dot
                if isActive {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 44, height: 44)
            .scaleEffect(isActive ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.62), value: isActive)
    }

    // MARK: - Post: Render → Save → Preview

    private func handlePost() {
        isTextFocused = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            renderAndSave()
        }
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
            LinearGradient(
                colors: gradients[selectedGradient].colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
