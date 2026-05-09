import SwiftUI

struct PayView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var isChecked = true
    @State private var themeColorHex: String = Constant.themeColor
    @State private var mainvectorTintColor: Color = Color(hex: "#01253B")

    // Payment states
    @State private var isPaymentLoading = false
    @State private var showPayment = false
    @State private var cashfreeSessionId = ""
    @State private var cashfreeOrderId = ""
    @State private var isPremiumUnlocked = UserDefaults.standard.bool(forKey: "premiumUnlocked")
    @State private var showUnlockedBanner = false
    @State private var paymentErrorMessage: String? = nil

    private let unlockAmount: Double = 99.0
    private let unlockCurrency = "INR"

    private var themeColor: Color {
        Color(hex: themeColorHex.isEmpty ? Constant.themeColor : themeColorHex)
    }

    private var backgroundTintColor: Color {
        if colorScheme == .light {
            return Color("appThemeColor")
        } else {
            return mainvectorTintColor
        }
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
                    ZStack {
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

                            // Right side — checkbox or unlocked badge
                            VStack {
                                if isPremiumUnlocked {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 22))
                                        .padding(.top, 8)
                                    Text("Unlocked")
                                        .font(.custom("Inter18pt-Medium", size: 11))
                                        .foregroundColor(.green)
                                } else {
                                    Text("Free Now")
                                        .font(.custom("Inter18pt-Medium", size: 16))
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color("TextColor"))
                                        .padding(.bottom, 10)

                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            isChecked.toggle()
                                        }
                                    }) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(isChecked ? Color("TextColor") : Color.clear)
                                                .frame(width: 22, height: 22)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .stroke(Color("TextColor"), lineWidth: 2)
                                                )

                                            if isChecked {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(colorScheme == .dark ? Color.black : Color(red: 0xF6/255, green: 0xF7/255, blue: 0xFF/255))
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
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.clear)

                    // Subtitle
                    Text("Make this app more valuable & premium*")
                        .font(.custom("Inter18pt-Medium", size: 15))
                        .foregroundColor(Color("TextColor"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 30)
                        .padding(.horizontal, 20)

                    // Error message
                    if let err = paymentErrorMessage {
                        Text(err)
                            .font(.custom("Inter18pt-Medium", size: 13))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                    }

                    Spacer(minLength: 30)

                    // Pay / Unlocked button
                    if isPremiumUnlocked {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.open.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 15, weight: .semibold))
                            Text("Features Unlocked")
                                .font(.custom("Inter18pt-Medium", size: 16))
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
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
                            initiatePremiumPayment()
                        }) {
                            ZStack {
                                if isPaymentLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    HStack(spacing: 6) {
                                        Image(systemName: "lock.open.fill")
                                            .font(.system(size: 14, weight: .semibold))
                                        Text("Pay ₹99 & Unlock")
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
                        .disabled(isPaymentLoading)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                    }
                }
            }
        }
        .navigationTitle("Pay")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .background(NavigationGestureEnabler())
        .fullScreenCover(isPresented: $showPayment) {
            CashfreePaymentScreen(
                sessionId: cashfreeSessionId,
                orderId: cashfreeOrderId,
                totalAmount: unlockAmount,
                currencySymbol: "₹"
            ) { success in
                handlePremiumPaymentResult(success)
            }
        }
        .onAppear {
            themeColorHex = Constant.themeColor
            mainvectorTintColor = getMainvectorTintColor(for: Constant.themeColor)
            isPremiumUnlocked = UserDefaults.standard.bool(forKey: "premiumUnlocked")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ThemeColorUpdated"))) { _ in
            themeColorHex = Constant.themeColor
            mainvectorTintColor = getMainvectorTintColor(for: Constant.themeColor)
        }
    }

    private func initiatePremiumPayment() {
        let uid   = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        let phone = UserDefaults.standard.string(forKey: Constant.PHONE_NUMBERKEY) ?? ""
        guard !uid.isEmpty else { paymentErrorMessage = "Not logged in."; return }

        isPaymentLoading = true
        ApiService.shared.createCashfreeOrder(
            uid: uid,
            amount: unlockAmount,
            currency: unlockCurrency,
            customerPhone: phone
        ) { success, sessionId, orderId in
            DispatchQueue.main.async {
                isPaymentLoading = false
                if success && !sessionId.isEmpty {
                    cashfreeSessionId = sessionId
                    cashfreeOrderId   = orderId
                    showPayment       = true
                } else {
                    paymentErrorMessage = "Payment setup failed. Please try again."
                }
            }
        }
    }

    private func handlePremiumPaymentResult(_ success: Bool) {
        if success {
            UserDefaults.standard.set(true, forKey: "premiumUnlocked")
            isPremiumUnlocked = true
            NotificationCenter.default.post(name: NSNotification.Name("PremiumUnlocked"), object: nil)
        } else {
            paymentErrorMessage = "Payment failed or cancelled. Please try again."
        }
    }

    private func getMainvectorTintColor(for themeColor: String) -> Color {
        let colorKey = themeColor.lowercased()
        switch colorKey {
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
