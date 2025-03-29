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

    // Bindings to update the selected country details
    @Binding var selectedCountryCode: String
    @Binding var selectedCountryShortCode: String
    @Binding var selectedCountryID: String

    var body: some View {

        NavigationStack{
            VStack(spacing: 0) {

                // Back Arrow Above Title
                HStack(alignment: .center) {
                    Button(action: {
                        withAnimation {
                            isPressed = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { // Delay for ra
                            dismiss() // Go back to the previous screen, NOT the first screen
                        }
                    }) {
                        ZStack {
                            if isPressed {
                                Circle()
                                    .fill(Color.gray.opacity(0.3)) // Ripple effect color
                                    .frame(width: 40, height: 40)
                                    .scaleEffect(isPressed ? 1.2 : 1.0) // Slight scale effect
                                    .animation(.easeOut(duration: 0.3), value: isPressed)
                            }

                            Image("leftvector")
                                .renderingMode(.template) // Enables tinting
                                .resizable()
                                .scaledToFit()
                                .frame(width: 25, height: 18)
                                .foregroundColor(Color("icontintGlobal")) // Tint applied here
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

                    Spacer() // Pushes content to the right
                }
                .padding(.leading, 10) // Adds left padding for better spacing


                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Rectangle()
                            .frame(width: 1, height: 30)
                            .foregroundColor(Color("blue"))
                            .padding(.leading, 5)

                        VStack(spacing: 3) {
                            TextField("Search Country", text: $viewModel.searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.custom("Inter18pt-Medium", size: 16))
                                .foregroundColor(Color("TextColor"))
                                .padding(.leading, 5)
                                .background(Color.clear)

                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(Color(UIColor(red: 0.894, green: 0.894, blue: 0.925, alpha: 1.0)))
                        }

                        Spacer()

                        Image("search")
                            .resizable()
                            .frame(width: 20, height: 20)
                    }
                    .padding(10)
                    .padding(.horizontal, 10)
                }
                .padding(.top, 23)
                .padding(.bottom, 10)

                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    List(viewModel.filteredFlags) { flag in
                        Button(action: {
                            selectedCountryCode = "+\(flag.country_c_code)"
                            selectedCountryShortCode = flag.country_code
                            selectedCountryID = flag.c_id
                            dismiss() // Close flagScreen after selection


                        }) {
                            FlagRowView(model: flag)
                                .padding(0) // Removes extra padding inside the row
                                .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)) // Ensures no extra spacing
                                .frame(height: 40)
                                .pressEffect() // Custom press effect (without blue border)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden) // Removes default background styling
                    .listRowSeparator(.hidden) // Removes separators if needed

                }
            }
            .background(Color("BackgroundColor"))
            .edgesIgnoringSafeArea(.bottom)
        }
        .navigationBarHidden(true)
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


