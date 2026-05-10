import SwiftUI

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
    @State private var remainingDays: Int = 0

    // Payment flow
    @State private var isPaymentLoading = false
    @State private var showNativePayment = false
    @State private var pendingSessionId = ""
    @State private var pendingOrderId = ""
    @State private var paymentErrorMessage: String? = nil

    // Locale-based gateway selection
    private var localeCurrencyCode: String {
        Locale.current.currency?.identifier ?? "INR"
    }
    private var isINRUser: Bool { localeCurrencyCode == "INR" }
    private var priceLabel: String { isINRUser ? "₹99" : "$1.99" }
    private var billingInfo: String {
        isINRUser
            ? "₹99 one-time. Unlocks premium for 3 months."
            : "$1.99 one-time. Unlocks premium for 3 months."
    }

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

                Spacer()

                // Features card — centered on screen
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
                        Spacer()
                        if isPremiumUnlocked {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 22))
                            Text("Active")
                                .font(.custom("Inter18pt-Medium", size: 11))
                                .foregroundColor(.green)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color("TextColor"))
                                    .frame(width: 22, height: 22)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color("TextColor"), lineWidth: 2))
                                Image(systemName: "checkmark")
                                    .foregroundColor(colorScheme == .dark ? .black : Color(red: 0xF6/255, green: 0xF7/255, blue: 0xFF/255))
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .padding(.leading, 14)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                }
                .padding(.horizontal, 20)

                // Expiry / renewal info
                if isPremiumUnlocked && !expiryDateString.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                                .foregroundColor(.green.opacity(0.8))
                            Text("Premium active until \(expiryDateString)")
                                .font(.custom("Inter18pt-Medium", size: 13))
                                .foregroundColor(.green.opacity(0.8))
                        }
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                                .foregroundColor(.green.opacity(0.6))
                            Text("\(remainingDays) day\(remainingDays == 1 ? "" : "s") remaining")
                                .font(.custom("Inter18pt-Medium", size: 12))
                                .foregroundColor(.green.opacity(0.6))
                        }
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

                Spacer()

                // Texts just above the button
                Text("Make this app more valuable & premium*")
                    .font(.custom("Inter18pt-Medium", size: 15))
                    .foregroundColor(Color("TextColor"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                Text(billingInfo)
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

                Spacer(minLength: 16)

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
                        guard !isPaymentLoading else { return }
                        paymentErrorMessage = nil
                        startPayment()
                    }) {
                        ZStack {
                            if isPaymentLoading {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    Text("Setting up…")
                                        .font(.custom("Inter18pt-Medium", size: 15))
                                        .foregroundColor(.white)
                                }
                            } else {
                                Text(isExpired ? "Renew \(priceLabel)" : "Subscribe \(priceLabel)")
                                    .font(.custom("Inter18pt-Medium", size: 16))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(themeColor)
                        .cornerRadius(14)
                    }
                    .disabled(isPaymentLoading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationTitle("Pay")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .background(NavigationGestureEnabler())
        // Native Cashfree payment sheet
        .fullScreenCover(isPresented: $showNativePayment) {
            CashfreePaymentScreen(
                sessionId: pendingSessionId,
                orderId: pendingOrderId,
                totalAmount: isINRUser ? 99.0 : 1.99,
                currencySymbol: isINRUser ? "₹" : "$"
            ) { success in
                if success {
                    let threeMonths = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
                    UserDefaults.standard.set(threeMonths.timeIntervalSince1970, forKey: "premiumExpiryTimestamp")
                    UserDefaults.standard.set(true, forKey: "premiumUnlocked")
                    UserDefaults.standard.set(pendingOrderId, forKey: "cashfreeOrderId")
                    NotificationCenter.default.post(name: NSNotification.Name("PremiumUnlocked"), object: nil)
                    checkPremiumStatus()
                } else {
                    paymentErrorMessage = "Payment not confirmed. Please try again or contact support."
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
            remainingDays = Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day ?? 0
        } else {
            isPremiumUnlocked = false
            isExpired = true
            UserDefaults.standard.set(false, forKey: "premiumUnlocked")
        }
    }

    // MARK: - Payment flow

    private func startPayment() {
        let uid   = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        let phone = UserDefaults.standard.string(forKey: Constant.PHONE_NUMBERKEY) ?? ""
        guard !uid.isEmpty else { paymentErrorMessage = "Not logged in."; return }

        isPaymentLoading = true

        let onResult: (Bool, String, String) -> Void = { success, sessionId, orderId in
            DispatchQueue.main.async {
                self.isPaymentLoading = false
                guard success, !sessionId.isEmpty else {
                    self.paymentErrorMessage = "Could not start payment. Please try again."
                    return
                }
                self.pendingOrderId   = orderId
                self.pendingSessionId = sessionId
                self.showNativePayment = true
            }
        }

        if isINRUser {
            ApiService.shared.createCashfreeOrder(
                uid: uid, amount: 99.0, currency: "INR",
                customerPhone: phone, completion: onResult)
        } else {
            let email = "\(uid)@enclosure.app"
            ApiService.shared.createCashfreeIPGOrder(
                uid: uid, amount: 1.99, currency: "USD",
                customerPhone: phone, customerEmail: email, completion: onResult)
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
