//
//  flagScreen.swift
//  Enclosure
//
//  Created by Ram Lohar on 16/03/25.
//



import SwiftUI

struct flagScreen: View {
    @StateObject private var viewModel = FlagViewModel()
    @Environment(\.dismiss) var dismiss
    @FocusState private var isSearchFocused: Bool
    @State private var isSearchActive = false

    // Bindings to update the selected country details
    @Binding var selectedCountryCode: String
    @Binding var selectedCountryShortCode: String
    @Binding var selectedCountryID: String

    // Helper function to hide keyboard
    private func hideKeyboard() {
        isSearchFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color("background_color")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Content Section
                if viewModel.isLoading {
                    ZStack {
                        Color("background_color")
                        HorizontalProgressBar()
                            .frame(width: 40, height: 2)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            let _ = print("📊 Total flags to display: \(viewModel.filteredFlags.count)")

                            ForEach(viewModel.filteredFlags) { flag in
                                FlagRowView(model: flag)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        print("🔵 Row tapped for country: \(flag.country_name)")

                                        isSearchFocused = false

                                        selectedCountryCode = "+\(flag.country_c_code)"
                                        selectedCountryShortCode = flag.country_code
                                        selectedCountryID = flag.c_id

                                        print("✅ Selected country: \(flag.country_code), Code: +\(flag.country_c_code), ID: \(flag.c_id)")

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
            .contentShape(Rectangle())
            .onTapGesture {
                hideKeyboard()
            }
        }
        .navigationTitle(isSearchActive ? "" : "Select Country")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isSearchActive)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if isSearchActive {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isSearchActive = false
                        viewModel.searchText = ""
                        isSearchFocused = false
                        hideKeyboard()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                ToolbarItem(placement: .principal) {
                    TextField("Search Country", text: $viewModel.searchText)
                        .font(.custom("Inter18pt-Medium", size: 16))
                        .foregroundColor(Color("TextColor"))
                        .focused($isSearchFocused)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
            } else {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isSearchActive = true
                    } label: {
                        Image("search")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                    }
                }
            }
        }
        .background(NavigationGestureEnabler())
        .onChange(of: isSearchActive) { active in
            if active {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isSearchFocused = true
                }
            }
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


