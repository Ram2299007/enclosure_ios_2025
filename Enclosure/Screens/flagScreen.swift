//
//  flagScreen.swift
//  Enclosure
//
//  Created by Ram Lohar on 16/03/25.
//



import SwiftUI

struct flagScreen: View {
    @StateObject private var viewModel = FlagViewModel()
    @State private var isPressed = false
    @Environment(\.dismiss) var dismiss
    @FocusState private var isSearchFocused: Bool

    // Bindings to update the selected country details
    @Binding var selectedCountryCode: String
    @Binding var selectedCountryShortCode: String
    @Binding var selectedCountryID: String

    var body: some View {
        VStack(spacing: 0) {
                // Back Arrow Above Title
                HStack(alignment: .center) {
                    Button(action: handleBackTap) {
                        ZStack {
                            if isPressed {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 40, height: 40)
                                    .scaleEffect(isPressed ? 1.2 : 1.0)
                                    .animation(.easeOut(duration: 0.3), value: isPressed)
                            }

                            Image("leftvector")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 25, height: 18)
                                .foregroundColor(Color("icontintGlobal"))
                        }
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { _ in
                                withAnimation {
                                    isPressed = false
                                }
                            }
                    )
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.leading, 10)

                // Search Bar Section - matching Android layout
                VStack(spacing: 0) {
                    HStack(alignment: .center, spacing: 0) {
                        // Blue vertical line - smaller height
                        Rectangle()
                            .frame(width: 1, height: 20)
                            .foregroundColor(Color("blue"))
                            .padding(.leading, 5)
                        
                        // Search TextField - wrap_content height
                        VStack(spacing: 0) {
                            TextField("Search Country", text: $viewModel.searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.custom("Inter18pt-Medium", size: 16))
                                .foregroundColor(Color("TextColor"))
                                .padding(.leading, 5)
                                .background(Color.clear)
                                .focused($isSearchFocused)
                                .frame(minHeight: 22) // Natural height for 16pt font
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 10)
                        
                        // Search Icon - match_parent height (matches TextField container height)
                        Image("search")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20)
                            .frame(minHeight: 22) // Matches TextField height
                            .padding(.trailing, 10)
                    }
                    .padding(10)
                }
                .padding(.top, 0)
                .padding(.bottom, 10)

                // Content Section
                if viewModel.isLoading {
                    ZStack {
                        Color("BackgroundColor")
                        HorizontalProgressBar()
                            .frame(width: 40, height: 2) // Custom size: width 40, height 3
                            .frame(maxWidth: .infinity, maxHeight: .infinity) // Center in parent
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Debug: Print count of flags
                            let _ = print("📊 Total flags to display: \(viewModel.filteredFlags.count)")
                            
                            ForEach(viewModel.filteredFlags) { flag in
                                FlagRowView(model: flag)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        print("🔵 Row tapped for country: \(flag.country_name)")
                                        
                                        // Dismiss keyboard first (like Android does when activity finishes)
                                        isSearchFocused = false
                                        
                                        // Update selected country details (matching Android: countrycode, flagFinal, c_id)
                                        selectedCountryCode = "+\(flag.country_c_code)"
                                        selectedCountryShortCode = flag.country_code  // Short code like "IN", "US"
                                        selectedCountryID = flag.c_id
                                        
                                        // Print for debugging
                                        print("✅ Selected country: \(flag.country_code), Code: +\(flag.country_c_code), ID: \(flag.c_id)")
                                        
                                        // Dismiss keyboard and wait before navigating back
                                        // This ensures keyboard is fully dismissed before returning to whatsYourNumber
                                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                        
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                            dismiss()
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 10)
                    }
                }
            }
            .background(Color("BackgroundColor"))
            .onAppear {
                // Auto-focus search field and show keyboard (matching Android behavior)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSearchFocused = true
                }
            }
            .navigationBarHidden(true)
    }
    
    private func handleBackTap() {
        // Dismiss keyboard first (like Android does on back press)
        isSearchFocused = false
        
        withAnimation {
            isPressed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            dismiss()
            isPressed = false
        }
    }
}

#Preview {
    flagScreen(
        selectedCountryCode: .constant("+1"),
        selectedCountryShortCode: .constant("US"),
        selectedCountryID: .constant("1")
    )
    .environment(
        \.managedObjectContext,
         PersistenceController.preview.container.viewContext
    )
}


extension View {
    func pressEffect() -> some View {
        self.modifier(PressEffectModifier())
    }
}

struct PressEffectModifier: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0) // Only scale effect
            .animation(.easeInOut(duration: 0.2), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

// Custom horizontal progress bar matching Android design
struct HorizontalProgressBar: View {
    var trackColor: Color = Color("TextColor").opacity(0.25)
    var indicatorColors: [Color] = [Color("TextColor"), Color("TextColor")]
    @State private var isAnimating = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: geometry.size.height / 2)
                    .fill(trackColor)
                
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: indicatorColors[0].opacity(0.0), location: 0.0),
                        .init(color: indicatorColors[0].opacity(0.35), location: 0.2),
                        .init(color: indicatorColors[0], location: 0.4),
                        .init(color: indicatorColors[1], location: 0.6),
                        .init(color: indicatorColors[1].opacity(0.35), location: 0.8),
                        .init(color: indicatorColors[1].opacity(0.0), location: 1.0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
                .offset(x: isAnimating ? geometry.size.width : -geometry.size.width)
                .animation(
                    Animation.linear(duration: 1.8)
                        .repeatForever(autoreverses: false),
                    value: isAnimating
                )
            }
        }
        .onAppear {
            isAnimating = true
        }
        .onDisappear {
            isAnimating = false
        }
    }
}


