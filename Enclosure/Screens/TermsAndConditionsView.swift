import SwiftUI

struct TermsAndConditionsView: View {
    var body: some View {
        ZStack {
            Color("BackgroundColor")
                .ignoresSafeArea()

            WebView(url: "https://enclosureapp.com/terms_and_conditions")
                .padding(.top, 40)
        }
        .navigationTitle("Terms & Conditions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .background(NavigationGestureEnabler())
    }
}

#Preview {
    NavigationStack {
        TermsAndConditionsView()
    }
}
