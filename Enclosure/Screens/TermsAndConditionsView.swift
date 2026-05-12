import SwiftUI

struct TermsAndConditionsView: View {
    @Environment(\.colorScheme) var colorScheme

    private var textColor: Color { Color("TextColor") }
    private var subtleColor: Color { Color("TextColor").opacity(0.6) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                Text("Please read the terms and conditions carefully. This terms and conditions for Enclosure Messaging Application services is a binding legal contract between you and Enclosure.")
                    .font(.custom("Inter18pt-Medium", size: 13))
                    .foregroundColor(subtleColor)
                    .padding(.bottom, 20)

                Text("By registering for, accessing, browsing or using the Enclosure messaging app services you acknowledge and agree that you have understood, and agree to be bound by the terms contained in this agreement.")
                    .font(.custom("Inter18pt-Medium", size: 13))
                    .foregroundColor(subtleColor)
                    .padding(.bottom, 28)

                section(number: "1", title: "GENERAL", body: """
By accessing, browsing or otherwise using any part of Enclosure messaging app services, you accept without qualification or limitation, this agreement and the terms contained in this agreement. If at any time you do not agree with any of these terms contained in this agreement, you are prohibited from using Enclosure messaging app services.

If we need to contact you, we may contact you via phone number provided in your registration or by posting a notice on the app or website. You agree that this satisfies all the legal requirements in relation to written communication.

Any dispute relating to these terms or the application are governed by and must be interpreted in accordance with the laws of Indian Government.
""")

                section(number: "2", title: "CHANGES", body: """
Enclosure Messaging app reserves the right, at any time and at our sole discretion, to change or modify these terms and conditions applicable to your use of Enclosure Messaging app services or any part thereof, or to impose new terms, including but not limited to, adding fees and charges for use.

Our Business Services may be interrupted, including for maintenance, repairs, upgrades, or network or equipment failures. We reserve the right to discontinue some or all of our Business Services, in our sole discretion, including certain features and the support for certain devices and platforms. Events beyond our control may affect our Business Services, such as events in nature and other force majeure events.

You are responsible for ensuring that you are familiar with the latest terms; by continuing with the same you agree to be bound by these changes.

We may change, modify, suspend or restrict access to the website without notice.
""")

                section(number: "3", title: "ELIGIBILITY", body: """
Enclosure Messaging App services is intended for users whose minimum age is 16 years. Any registration, use or access to services by anyone under the age of 16 years requires permission from a parent or legal guardian, who must read these Terms and Conditions and Privacy Policy and agree to be bound by them on behalf of their minor child.

• Additionally, some of the content on the Enclosure messaging app service may not be appropriate for individuals under 16 years of age.
""")

                section(number: "4", title: "ACCOUNTS", body: """
Each account belongs to the user who registered upon activation of their Enclosure Messaging app account and is non-transferable.

All account holders may access the App for free or via any subscriptions.

For any account that has been dormant for 90 consecutive days on Enclosure Messaging app services, Enclosure Messaging app reserves the right to suspend or remove the user's account.
""")

                section(number: "5", title: "OUR DATA PRACTICE", body: """
You, and your service providers who manage your Enclosure communications, if any, will have access via our Business Services to personal data, such as Customer Data and Company Content that you provide to us. As part of our Business Services, Enclosure provides you with aggregated metrics relating to your messaging activity.

You understand and agree that Enclosure collects, stores, and uses: (a) information from your account and registration; (b) usage, log, and functional information generated from your use of our Business Services; (c) performance, diagnostics, and analytics information; (d) information related to your technical or other support requests; and (e) information about you from other sources such as other Enclosure users, businesses, and third-party companies.

Company agrees to the transfer and processing of information that we collect, store, and use under these Business Terms, to India and other countries globally where we have or use facilities, service providers, or partners, regardless of where you use our Business Services.

You agree that Enclosure may share your information if we have good-faith belief that it is reasonably necessary to: (a) respond pursuant to applicable law or regulations, to legal process, or government requests; (b) enforce these Business Terms; (c) detect, investigate, prevent, and address fraud and other illegal activity; or (d) protect the rights, property, and safety of our users, Enclosure or others.
""")

                section(number: "6", title: "INTELLECTUAL PROPERTY", body: """
The Enclosure Messaging app Service is owned and operated by us. All content, trademarks and other proprietary materials and/or information on Enclosure Messaging app, including without limitation, visual interfaces, graphics, design, compilation, information, software, computer code, services, text, pictures, photos, video, graphics, music, information, data, sound files, other files and the selection and arrangement thereof are protected by copyright and trademark laws, international conventions, and all other relevant intellectual property and proprietary rights, and applicable laws.
""")

                section(number: "7", title: "LEGAL", body: """
You may only use our Business Services if you have ensured that your use complies with all legal and regulatory requirements applicable to Company; it is your sole responsibility to determine your legal obligations. Company must provide all necessary data disclosures and notices and secure all necessary rights, consents, and permissions to share its customers' contact and other personal data with Enclosure.

Company must also honor and comply with all Enclosure user requests to stop or opt-out of receiving Enclosure messages. Enclosure users may block Company, mark messages as spam, or report Company actions to us. Enclosure will take appropriate action, which could result in suspending or terminating Company's use of our Business Services.
""")

                section(number: "8", title: "CODE OF CONDUCT", body: """
Privacy And Security Principles. Enclosure is created with strong privacy and security principles.

Connecting You With Other People. We provide, and always strive to improve, ways for you to communicate with other Enclosure users including through messages, voice and video calls, sending images and video, showing your status, and sharing your location with others when you choose.

Safety, Security, And Integrity. We work to protect the safety, security, and integrity of our Services. This includes appropriately dealing with abusive people and activity violating our Terms. We work to prohibit misuse of our Services including harmful conduct towards others, violations of our Terms and policies.

Ways To Improve Our Services. We analyze how you make use of Enclosure, in order to improve our Services, including helping businesses measure the effectiveness and distribution of their services and messages.
""")

                section(number: "9", title: "LICENSES", body: """
Enclosure does not claim ownership of the information that you submit for your Enclosure account or through our Services. You must have the necessary rights to such information that you submit.

In order to operate and provide our Services, you grant Enclosure a worldwide, non-exclusive, royalty-free, sublicensable, and transferable license to use, reproduce, distribute, create derivative works of, display, and perform the information that you upload, submit, store, send, or receive on or through our Services. The rights you grant in this license are for the limited purpose of operating and providing our Services.

We grant you a limited, revocable, non-exclusive, non-sublicensable, and non-transferable license to use our Services, subject to and in accordance with our Terms.
""")

                section(number: "10", title: "DISCLAIMER", body: """
Company uses our business services at its own risk and subject to the following disclaimers. Unless prohibited by applicable law, we are providing our business services on an "as is" basis without any express or implied warranties, including but not limited to, warranties of merchantability, fitness for a particular purpose, title, non-infringement, and freedom from computer virus or other harmful code.

We do not warrant that any information provided by us is accurate, complete, or useful; that our business services will be operational, error free, secure, or safe; or that our business services will function without disruptions, delays, or imperfections.
""")

                section(number: "11", title: "TERMINATION", body: """
We may modify, suspend, or terminate Company's access to or use of our Business Services at any time and for any reason, including if we determine, in our sole discretion, that Company violates these Business Terms, receives excessive negative feedback, or creates harm or risk for us, our users, or others.

Upon termination, we will remove your account profile from Enclosure, and retain data associated with your account for up to 90 days.

Upon termination, Company must promptly discontinue all use of our Business Services, and uninstall and destroy all copies of software provided by Enclosure.
""")

                section(number: "12", title: "ASSIGNMENT", body: """
All of our rights and obligations under these Business Terms are freely assignable by us to any of our affiliates or in connection with a merger, acquisition, restructuring, or sale of assets, or by operation of law or otherwise.
""")

                section(number: "13", title: "LIMITATION OF LIABILITY", body: """
The Enclosure parties will not be liable to you for any lost profits or consequential, special, punitive, indirect, or incidental damages relating to, arising out of, or in any way in connection with our terms, us, or our services, even if the Enclosure parties have been advised of the possibility of such damages.

Our aggregate liability relating to, arising out of, or in any way in connection with our terms, us, or our services will not exceed the amount you have paid us in the past twelve months.
""")

                section(number: "14", title: "INDEMNIFICATION", body: """
If anyone brings a claim against us related to your actions, information, or content on Enclosure, or any other use of our Services by you, you will, to the maximum extent permitted by applicable law, indemnify and hold the Enclosure Parties harmless from and against all liabilities, damages, losses, and expenses of any kind relating to, arising out of, or in any way in connection with: (a) your access to or use of our Services; (b) your breach of our Terms or applicable law; or (c) any misrepresentation made by you.
""")

                section(number: "15", title: "OWNERSHIP", body: """
The App design of Enclosure Messaging app is owned by Enclosure.
""")

            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .background(Color("BackgroundColor").ignoresSafeArea())
        .navigationTitle("Terms & Conditions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .background(NavigationGestureEnabler())
    }

    @ViewBuilder
    private func section(number: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(number). \(title)")
                .font(.custom("Inter18pt-Medium", size: 15))
                .fontWeight(.bold)
                .foregroundColor(textColor)
            Text(body.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(.custom("Inter18pt-Medium", size: 13))
                .foregroundColor(subtleColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 24)
    }
}

#Preview {
    NavigationStack {
        TermsAndConditionsView()
    }
}
