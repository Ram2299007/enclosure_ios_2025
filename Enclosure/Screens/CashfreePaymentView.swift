import SwiftUI
import UIKit
import CashfreePG
import CashfreePGCoreSDK
import CashfreePGUISDK

// MARK: - Cashfree Payment Service (Singleton coordinator)

final class CashfreePaymentService: NSObject, CFResponseDelegate {

    static let shared = CashfreePaymentService()
    private override init() {}

    private var onComplete: ((Bool, String) -> Void)?

    /// Launch Cashfree Web Checkout from any view context
    func startPayment(sessionId: String,
                      orderId: String,
                      from viewController: UIViewController,
                      completion: @escaping (_ success: Bool, _ orderId: String) -> Void) {
        onComplete = completion

        do {
            // SANDBOX for testing — switch to .PRODUCTION once Cashfree approves your account
            let cfSession = try CFSession.CFSessionBuilder()
                .setOrderID(orderId)
                .setPaymentSessionId(sessionId)
                .setEnvironment(.SANDBOX)
                .build()

            let cfTheme = try CFTheme.CFThemeBuilder()
                .setNavigationBarBackgroundColor("#1C1C1E")
                .setNavigationBarTextColor("#FFFFFF")
                .setButtonBackgroundColor(Constant.themeColor)
                .setButtonTextColor("#FFFFFF")
                .setPrimaryTextColor("#FFFFFF")
                .setSecondaryTextColor("#8E8E93")
                .build()

            let payment = try CFWebCheckoutPayment.CFWebCheckoutPaymentBuilder()
                .setSession(cfSession)
                .build()

            payment.setTheme(cfTheme)

            CFPaymentGatewayService.getInstance().setCallback(self)
            try CFPaymentGatewayService.getInstance().doPayment(payment, viewController: viewController)

        } catch {
            completion(false, orderId)
        }
    }

    // MARK: - CFResponseDelegate

    func verifyPayment(order_id: String) {
        ApiService.shared.verifyCashfreePayment(orderId: order_id) { [weak self] verified in
            DispatchQueue.main.async {
                self?.onComplete?(verified, order_id)
                self?.onComplete = nil
            }
        }
    }

    
    
    func onError(_ error: CFErrorResponse, order_id: String) {
        DispatchQueue.main.async { [weak self] in
            self?.onComplete?(false, order_id)
            self?.onComplete = nil
        }
    }
}

// MARK: - SwiftUI Bridge (UIViewControllerRepresentable)

struct CashfreePaymentLauncher: UIViewControllerRepresentable {
    let sessionId: String
    let orderId: String
    let onResult: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard !sessionId.isEmpty, !orderId.isEmpty else { return }
        // Only launch once — guard ensures no re-trigger on SwiftUI re-renders
        if uiViewController.view.tag == 0 {
            uiViewController.view.tag = 1
            CashfreePaymentService.shared.startPayment(
                sessionId: sessionId,
                orderId: orderId,
                from: uiViewController
            ) { success, _ in
                onResult(success)
            }
        }
    }
}

// MARK: - SwiftUI Payment Screen

struct CashfreePaymentScreen: View {
    let sessionId: String
    let orderId: String
    let totalAmount: Double
    let currencySymbol: String
    let onResult: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CashfreePaymentLauncher(
                sessionId: sessionId,
                orderId: orderId,
                onResult: { success in
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onResult(success)
                    }
                }
            )
            .ignoresSafeArea()

            // Loading indicator while Cashfree UI is loading
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.4)
                Text("Setting up payment…")
                    .font(.custom("Inter18pt-Regular", size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .preferredColorScheme(.dark)
    }
}
