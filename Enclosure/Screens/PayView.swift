import SwiftUI
import SafariServices

// MARK: - SFSafariViewController wrapper

struct SubscriptionSafariView: UIViewControllerRepresentable {
    let url: URL
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onDismiss: onDismiss) }

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.delegate = context.coordinator
        vc.preferredControlTintColor = UIColor(named: "appThemeColor")
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}

    class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let onDismiss: () -> Void
        init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            onDismiss()
        }
    }
}

// MARK: - PayView

struct PayView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var isChecked = true
    @State private var themeColorHex: String = Constant.themeColor
    @State private var mainvectorTintColor: Color = Color(hex: "#01253B")

    // Premium state
    @State private var isPremiumUnlocked = false
    @State private var isExpired = false
    @State private var expiryDateString = ""

    // Payment flow
    @State private var isPaymentLoading = false
    @State private var showSubscriptionAuth = false
    @State private var subscriptionAuthURL: URL? = nil
    @State private var pendingSubscriptionId = ""
    @State private var isVerifying = false
    @State private var paymentErrorMessage: String? = nil

    private var themeColor: Color {
        Color(hex: themeColorHex.isEmpty ? Constant.themeColor : themeColorHex)
    }

    private var backgroundTintColor: Color {
        colorScheme == .light ? Color("appThemeColor") : mainvectorTintColor
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    var body: some View {
        ZStack {
            Color("BackgroundColor")
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { hideKeyboard() }

            VStack(spacing: 0) {
                // Header banner
                ZStack {
                    Image("pnglabel")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(themeColor)
                        .scaledToFill()
                        .frame(height: 50)
                        .clipped()
                    Text("Enclosure Exclusive Features")
                        .font(.custom("Inter18pt-Medium", size: 17))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                }
                .frame(height: 50)
                .padding(.top, 60)
                .padding(.horizontal, 20)

                // Features card
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Sleep Lock")
                            .font(.custom("Inter18pt-Medium", size: 14))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 25)
                            .padding(.top, 23)
                        Text("Themes")
                            .font(.custom("Inter18pt-Medium", size: 14))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 25)
                            .padding(.top, 16)
                        Spacer()
                    }
                    .frame(width: 223, height: 100, alignment: .leading)
                    .background(backgroundTintColor)
                    .cornerRadius(8)

                    VStack(spacing: 6) {
                        if isPremiumUnlocked {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 22))
                            Text("Active")
                                .font(.custom("Inter18pt-Medium", size: 11))
                                .foregroundColor(.green)
                        } else {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) { isChecked.toggle() }
                            }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(isChecked ? Color("TextColor") : Color.clear)
                                        .frame(width: 22, height: 22)
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color("TextColor"), lineWidth: 2))
                                    if isChecked {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(colorScheme == .dark ? .black : Color(red: 0xF6/255, green: 0xF7/255, blue: 0xFF/255))
                                            .font(.system(size: 12, weight: .bold))
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 14)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Expiry / renewal info
                if isPremiumUnlocked && !expiryDateString.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                            .foregroundColor(.green.opacity(0.8))
                        Text("Auto-renews on \(expiryDateString)")
                            .font(.custom("Inter18pt-Medium", size: 13))
                            .foregroundColor(.green.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }

                if isExpired {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                        Text("Subscription expired. Please renew.")
                            .font(.custom("Inter18pt-Medium", size: 13))
                            .foregroundColor(.orange)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }

                Text("Make this app more valuable & premium*")
                    .font(.custom("Inter18pt-Medium", size: 15))
                    .foregroundColor(Color("TextColor"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 20)
                    .padding(.horizontal, 20)

                // Billing note
                Text("Billed every 3 months via Cashfree AutoPay. Cancel anytime.")
                    .font(.custom("Inter18pt-Medium", size: 12))
                    .foregroundColor(Color("TextColor").opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
                    .padding(.horizontal, 20)

                if let err = paymentErrorMessage {
                    Text(err)
                        .font(.custom("Inter18pt-Medium", size: 13))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                }

                Spacer(minLength: 30)

                // Action button
                if isPremiumUnlocked {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Features Unlocked")
                            .font(.custom("Inter18pt-Medium", size: 16))
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(14)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                } else {
                    Button(action: {
                        guard !isPaymentLoading && !isVerifying else { return }
                        paymentErrorMessage = nil
                        startSubscription()
                    }) {
                        ZStack {
                            if isPaymentLoading || isVerifying {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    Text(isVerifying ? "Verifying…" : "Setting up…")
                                        .font(.custom("Inter18pt-Medium", size: 15))
                                        .foregroundColor(.white)
                                }
                            } else {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(isExpired ? "Renew ₹99 AutoPay" : "Subscribe ₹99 AutoPay")
                                        .font(.custom("Inter18pt-Medium", size: 16))
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(themeColor)
                        .cornerRadius(14)
                    }
                    .disabled(isPaymentLoading || isVerifying)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationTitle("Pay")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .background(NavigationGestureEnabler())
        // Open Cashfree mandate page in SFSafariViewController
        .fullScreenCover(isPresented: $showSubscriptionAuth) {
            if let url = subscriptionAuthURL {
                SubscriptionSafariView(url: url) {
                    // User dismissed Safari without completing — verify status anyway
                    showSubscriptionAuth = false
                    if !pendingSubscriptionId.isEmpty {
                        verifySubscription(id: pendingSubscriptionId)
                    }
                }
                .ignoresSafeArea()
            }
        }
        // Cashfree redirects to enclosure://subscription-result after mandate
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CashfreeSubscriptionResult"))) { _ in
            showSubscriptionAuth = false
            if !pendingSubscriptionId.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    verifySubscription(id: pendingSubscriptionId)
                }
            }
        }
        .onAppear {
            themeColorHex = Constant.themeColor
            mainvectorTintColor = getMainvectorTintColor(for: Constant.themeColor)
            checkPremiumStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ThemeColorUpdated"))) { _ in
            themeColorHex = Constant.themeColor
            mainvectorTintColor = getMainvectorTintColor(for: Constant.themeColor)
        }
    }

    // MARK: - Premium status check

    private func checkPremiumStatus() {
        let expiry = UserDefaults.standard.double(forKey: "premiumExpiryTimestamp")
        guard expiry > 0 else {
            isPremiumUnlocked = false
            isExpired = false
            return
        }
        let expiryDate = Date(timeIntervalSince1970: expiry)
        if Date() < expiryDate {
            isPremiumUnlocked = true
            isExpired = false
            let fmt = DateFormatter()
            fmt.dateStyle = .medium
            expiryDateString = fmt.string(from: expiryDate)
        } else {
            isPremiumUnlocked = false
            isExpired = true
            UserDefaults.standard.set(false, forKey: "premiumUnlocked")
        }
    }

    // MARK: - Subscription flow

    private func startSubscription() {
        let uid   = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        let phone = UserDefaults.standard.string(forKey: Constant.PHONE_NUMBERKEY) ?? ""
        guard !uid.isEmpty else { paymentErrorMessage = "Not logged in."; return }

        isPaymentLoading = true
        ApiService.shared.createCashfreePremiumSubscription(uid: uid, phone: phone) { success, subId, authLink in
            DispatchQueue.main.async {
                isPaymentLoading = false
                guard success, !authLink.isEmpty, let url = URL(string: authLink) else {
                    paymentErrorMessage = "Could not start subscription. Please try again."
                    return
                }
                pendingSubscriptionId = subId
                subscriptionAuthURL   = url
                showSubscriptionAuth  = true
            }
        }
    }

    private func verifySubscription(id: String) {
        isVerifying = true
        ApiService.shared.getCashfreeSubscriptionStatus(subscriptionId: id) { success, status in
            DispatchQueue.main.async {
                isVerifying = false
                let active = status == "ACTIVE" || status == "BANK_APPROVAL_PENDING"
                if active {
                    let threeMonths = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
                    UserDefaults.standard.set(threeMonths.timeIntervalSince1970, forKey: "premiumExpiryTimestamp")
                    UserDefaults.standard.set(true, forKey: "premiumUnlocked")
                    UserDefaults.standard.set(id, forKey: "cashfreeSubscriptionId")
                    NotificationCenter.default.post(name: NSNotification.Name("PremiumUnlocked"), object: nil)
                    checkPremiumStatus()
                } else {
                    paymentErrorMessage = "Subscription not yet active (status: \(status)). Try again or check UPI mandate."
                }
            }
        }
    }

    // MARK: - Theme helper

    private func getMainvectorTintColor(for themeColor: String) -> Color {
        switch themeColor.lowercased() {
        case "#ff0080": return Color(hex: "#4D0026")
        case "#00a3e9": return Color(hex: "#01253B")
        case "#7adf2a": return Color(hex: "#25430D")
        case "#ec0001": return Color(hex: "#470000")
        case "#16f3ff": return Color(hex: "#05495D")
        case "#ff8a00": return Color(hex: "#663700")
        case "#7f7f7f": return Color(hex: "#2B3137")
        case "#d9b845": return Color(hex: "#413815")
        case "#346667": return Color(hex: "#1F3D3E")
        case "#9846d9": return Color(hex: "#2d1541")
        case "#a81010": return Color(hex: "#430706")
        default:        return Color(hex: "#01253B")
        }
    }
}


#Preview {
    PayView()
}
