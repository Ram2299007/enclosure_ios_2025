import SwiftUI
import Photos

// MARK: - Font style model
private struct StoryFontStyle {
    let name: String
    let font: Font        // used while typing (large)
    let previewFont: Font // shown in picker cell
}

// MARK: - Story Text Editor
// Full-screen text story creator — gradient backgrounds + font picker + smooth typing.
struct StoryTextEditorView: View {
    var onPost: (([PHAsset], String) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var selectedGradientIndex = 0
    @State private var selectedFontIndex = 0
    @State private var textAlignment: TextAlignment = .center
    @FocusState private var isTextFocused: Bool
    @State private var showPreview = false
    @State private var capturedAssets: [PHAsset] = []
    @State private var cursorPulse = false

    // MARK: - 10 Gradient Backgrounds
    // Each tuple: (display name, gradient colors)
    private let gradients: [(String, [Color])] = [
        ("Sunset",   [Color(hex: "#FF6B6B"), Color(hex: "#FEE140")]),
        ("Ocean",    [Color(hex: "#005C97"), Color(hex: "#363795")]),
        ("Purple",   [Color(hex: "#7B2FBE"), Color(hex: "#E040FB")]),
        ("Forest",   [Color(hex: "#134E5E"), Color(hex: "#71B280")]),
        ("Gold",     [Color(hex: "#F7971E"), Color(hex: "#FFD200")]),
        ("Flamingo", [Color(hex: "#f857a6"), Color(hex: "#ff5858")]),
        ("Night",    [Color(hex: "#0F0C29"), Color(hex: "#302B63")]),
        ("Rose",     [Color(hex: "#FF9A9E"), Color(hex: "#A18CD1")]),
        ("Mint",     [Color(hex: "#00B09B"), Color(hex: "#96C93D")]),
        ("Cosmic",   [Color(hex: "#4776E6"), Color(hex: "#8E54E9")])
    ]

    // MARK: - 10 Font Styles
    // All use system fonts → automatically support Devanagari (Marathi/Hindi) and all scripts.
    private let fontStyles: [StoryFontStyle] = [
        StoryFontStyle(
            name: "Classic",
            font: .system(size: 32, weight: .regular),
            previewFont: .system(size: 19, weight: .regular)
        ),
        StoryFontStyle(
            name: "Bold",
            font: .system(size: 32, weight: .bold),
            previewFont: .system(size: 19, weight: .bold)
        ),
        StoryFontStyle(
            name: "Rounded",
            font: .system(size: 32, weight: .semibold, design: .rounded),
            previewFont: .system(size: 19, weight: .semibold, design: .rounded)
        ),
        StoryFontStyle(
            name: "Serif",
            font: .system(size: 32, weight: .regular, design: .serif),
            previewFont: .system(size: 19, weight: .regular, design: .serif)
        ),
        StoryFontStyle(
            name: "Mono",
            font: .system(size: 28, weight: .regular, design: .monospaced),
            previewFont: .system(size: 17, weight: .regular, design: .monospaced)
        ),
        StoryFontStyle(
            name: "Light",
            font: .system(size: 36, weight: .light),
            previewFont: .system(size: 21, weight: .light)
        ),
        StoryFontStyle(
            name: "Heavy",
            font: .system(size: 30, weight: .heavy),
            previewFont: .system(size: 18, weight: .heavy)
        ),
        StoryFontStyle(
            name: "Thin",
            font: .system(size: 38, weight: .thin),
            previewFont: .system(size: 22, weight: .thin)
        ),
        StoryFontStyle(
            name: "Black",
            font: .system(size: 28, weight: .black),
            previewFont: .system(size: 17, weight: .black)
        ),
        StoryFontStyle(
            name: "Italic",
            font: Font.system(size: 32, weight: .medium).italic(),
            previewFont: Font.system(size: 19, weight: .medium).italic()
        ),
    ]

    // MARK: - Computed

    private var activeGradient: LinearGradient {
        LinearGradient(
            colors: gradients[selectedGradientIndex].1,
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
            // Gradient background (animates when changed)
            activeGradient
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.45), value: selectedGradientIndex)

            VStack(spacing: 0) {
                topBar

                Spacer()

                textInputArea

                Spacer()

                bottomControls
            }
        }
        .onAppear {
            // Auto-focus after slight delay so keyboard animates in nicely
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isTextFocused = true
            }
            // Start cursor pulse animation
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                cursorPulse = true
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
        HStack(spacing: 12) {
            // Close
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.32))
                        .frame(width: 42, height: 42)
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Alignment cycle
            Button(action: cycleAlignment) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.32))
                        .frame(width: 42, height: 42)
                    Image(systemName: alignmentIcon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.2), value: textAlignment)

            // Post button
            Button(action: handlePost) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 17))
                    Text("Post")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.32))
                )
            }
            .buttonStyle(.plain)
            .disabled(!isPostEnabled)
            .opacity(isPostEnabled ? 1 : 0.4)
            .animation(.easeInOut(duration: 0.2), value: isPostEnabled)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Text Input Area

    private var textInputArea: some View {
        ZStack {
            // Pulsing glow ring when typing
            if isTextFocused {
                RoundedRectangle(cornerRadius: 22)
                    .stroke(
                        Color.white.opacity(cursorPulse ? 0.5 : 0.0),
                        lineWidth: 1.5
                    )
                    .blur(radius: cursorPulse ? 5 : 0)
                    .padding(.horizontal, 12)
                    .animation(
                        .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                        value: cursorPulse
                    )
            }

            // Placeholder text
            if text.isEmpty {
                Text("Tap to type…")
                    .font(fontStyles[selectedFontIndex].font)
                    .foregroundColor(.white.opacity(0.45))
                    .multilineTextAlignment(textAlignment)
                    .allowsHitTesting(false)
            }

            // Actual TextField
            TextField("", text: $text, axis: .vertical)
                .font(fontStyles[selectedFontIndex].font)
                .foregroundColor(.white)
                .multilineTextAlignment(textAlignment)
                .lineLimit(1...10)
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                // Bright yellow cursor — stands out as a highlight symbol on any gradient
                .tint(Color(hex: "#FFE35C"))
                .focused($isTextFocused)
                .animation(.easeInOut(duration: 0.25), value: selectedFontIndex)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { isTextFocused = true }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 0) {
            // Thin separator line
            Divider()
                .background(Color.white.opacity(0.25))

            VStack(spacing: 14) {
                // Active font name label
                Text(fontStyles[selectedFontIndex].name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))
                    .kerning(1.2)
                    .textCase(.uppercase)
                    .animation(.easeInOut(duration: 0.2), value: selectedFontIndex)
                    .padding(.top, 12)

                // ── Font Picker ──
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(fontStyles.indices, id: \.self) { i in
                            let isActive = selectedFontIndex == i
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                                    selectedFontIndex = i
                                }
                            } label: {
                                Text("Aa")
                                    .font(fontStyles[i].previewFont)
                                    .foregroundColor(isActive ? .white : .white.opacity(0.5))
                                    .frame(width: 58, height: 58)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(
                                                isActive
                                                    ? Color.white.opacity(0.28)
                                                    : Color.black.opacity(0.22)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14)
                                                    .stroke(
                                                        isActive ? Color.white.opacity(0.9) : Color.clear,
                                                        lineWidth: 2
                                                    )
                                            )
                                    )
                                    .scaleEffect(isActive ? 1.1 : 1.0)
                                    .shadow(
                                        color: isActive ? Color.white.opacity(0.3) : .clear,
                                        radius: 8, x: 0, y: 0
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // ── Gradient Picker ──
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(gradients.indices, id: \.self) { i in
                            let isActive = selectedGradientIndex == i
                            Button {
                                withAnimation(.easeInOut(duration: 0.35)) {
                                    selectedGradientIndex = i
                                }
                            } label: {
                                ZStack {
                                    // Gradient circle
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: gradients[i].1,
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 38, height: 38)

                                    // Active ring
                                    if isActive {
                                        Circle()
                                            .stroke(Color.white, lineWidth: 3)
                                            .frame(width: 46, height: 46)
                                    }
                                }
                                .frame(width: 46, height: 46)
                                .shadow(
                                    color: isActive ? Color.white.opacity(0.4) : .clear,
                                    radius: 6, x: 0, y: 0
                                )
                                .scaleEffect(isActive ? 1.08 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.65), value: selectedGradientIndex)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }

                // Bottom safe area spacer
                Spacer().frame(height: 8)
            }
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Alignment Helpers

    private var alignmentIcon: String {
        switch textAlignment {
        case .leading:  return "text.alignleft"
        case .center:   return "text.aligncenter"
        case .trailing: return "text.alignright"
        @unknown default: return "text.aligncenter"
        }
    }

    private func cycleAlignment() {
        switch textAlignment {
        case .leading:  textAlignment = .center
        case .center:   textAlignment = .trailing
        case .trailing: textAlignment = .leading
        @unknown default: textAlignment = .center
        }
    }

    // MARK: - Post: Render → Save → Preview

    private func handlePost() {
        // Dismiss keyboard first
        isTextFocused = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            renderAndSave()
        }
    }

    private func renderAndSave() {
        // Build canvas that matches screen dimensions
        let canvas = renderCanvas
        let renderer = ImageRenderer(content: canvas)
        renderer.scale = UIScreen.main.scale
        guard let image = renderer.uiImage else { return }
        saveToPhotoLibrary(image: image)
    }

    // The rendered canvas (no UI chrome — just gradient + text)
    @ViewBuilder
    private var renderCanvas: some View {
        ZStack {
            LinearGradient(
                colors: gradients[selectedGradientIndex].1,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(text)
                .font(fontStyles[selectedFontIndex].font)
                .foregroundColor(.white)
                .multilineTextAlignment(textAlignment)
                .padding(40)
        }
        .frame(
            width: UIScreen.main.bounds.width,
            height: UIScreen.main.bounds.height
        )
    }

    private func saveToPhotoLibrary(image: UIImage) {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
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

        switch status {
        case .authorized, .limited:
            doSave()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { s in
                if s == .authorized || s == .limited { doSave() }
            }
        default:
            doSave()
        }
    }
}
