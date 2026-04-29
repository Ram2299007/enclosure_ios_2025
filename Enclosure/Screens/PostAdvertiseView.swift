import SwiftUI
import PhotosUI

struct PostAdvertiseView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var link = ""
    @State private var budget = ""
    @State private var duration = "7"
    @State private var category = "General"
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var isPosting = false
    @State private var errorMessage: String? = nil
    @State private var showSuccess = false

    private let categories = ["General", "Technology", "Fashion", "Food", "Health", "Sports", "Travel", "Business"]
    private let durations = ["1", "3", "7", "14", "30"]

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {

                    // ── Media picker ──
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("Media (photos / videos)")
                        PhotosPicker(
                            selection: $selectedPhotos,
                            maxSelectionCount: 5,
                            matching: .any(of: [.images, .videos])
                        ) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                                    .foregroundColor(Color("gray3").opacity(0.5))
                                    .frame(height: 90)
                                VStack(spacing: 6) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 26))
                                        .foregroundColor(Color(hex: Constant.themeColor))
                                    Text(selectedImages.isEmpty
                                         ? "Add photos / videos"
                                         : "\(selectedImages.count) selected")
                                        .font(.custom("Inter18pt-Regular", size: 14))
                                        .foregroundColor(Color("gray3"))
                                }
                            }
                        }
                        .onChange(of: selectedPhotos) { items in
                            selectedImages = []
                            for item in items {
                                item.loadTransferable(type: Data.self) { result in
                                    if case .success(let data) = result,
                                       let data = data,
                                       let img = UIImage(data: data) {
                                        DispatchQueue.main.async { selectedImages.append(img) }
                                    }
                                }
                            }
                        }
                        // Thumbnail strip
                        if !selectedImages.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(selectedImages.enumerated()), id: \.offset) { _, img in
                                        Image(uiImage: img)
                                            .resizable().scaledToFill()
                                            .frame(width: 70, height: 70)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                        }
                    }

                    formField("Title *", text: $title, placeholder: "e.g. Summer Sale 50% off")
                    formField("Description *", text: $description, placeholder: "What are you advertising?", multiline: true)
                    formField("Link (optional)", text: $link, placeholder: "https://yoursite.com")
                    formField("Daily Budget ($) *", text: $budget, placeholder: "e.g. 5", keyboardType: .decimalPad)

                    // Duration picker
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("Duration (days)")
                        Picker("Duration", selection: $duration) {
                            ForEach(durations, id: \.self) { Text($0 + " days").tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Category chips
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("Category")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(categories, id: \.self) { cat in
                                    Button { category = cat } label: {
                                        Text(cat)
                                            .font(.custom("Inter18pt-Medium", size: 13))
                                            .foregroundColor(category == cat ? .white : Color("TextColor"))
                                            .padding(.horizontal, 14).padding(.vertical, 7)
                                            .background(category == cat
                                                        ? Color(hex: Constant.themeColor)
                                                        : Color("gray3").opacity(0.15))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Budget summary
                    if let b = Double(budget), b > 0, let d = Int(duration), d > 0 {
                        HStack {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: Constant.themeColor))
                            Text("Total spend: $\(String(format: "%.2f", b * Double(d))) over \(d) days")
                                .font(.custom("Inter18pt-Regular", size: 13))
                                .foregroundColor(Color("gray3"))
                        }
                        .padding(.vertical, 4)
                    }

                    if let err = errorMessage {
                        Text(err)
                            .font(.custom("Inter18pt-Regular", size: 13))
                            .foregroundColor(.red)
                    }

                    // Post button
                    Button { postAd() } label: {
                        Group {
                            if isPosting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Post Advertisement")
                                    .font(.custom("Inter18pt-SemiBold", size: 16))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canPost
                                    ? Color(hex: Constant.themeColor)
                                    : Color("gray3").opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canPost || isPosting)
                }
                .padding(16)
            }
            .background(Color("BackgroundColor"))
            .navigationTitle("Promote Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color("TextColor"))
                    }
                }
            }
        }
        .alert("Ad Posted!", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your advertisement is now live and will appear to users in your country.")
        }
    }

    private var canPost: Bool {
        !title.isEmpty && !description.isEmpty && !budget.isEmpty
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.custom("Inter18pt-SemiBold", size: 15))
            .foregroundColor(Color("TextColor"))
    }

    @ViewBuilder
    private func formField(
        _ label: String,
        text: Binding<String>,
        placeholder: String,
        multiline: Bool = false,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(label)
            if multiline {
                TextEditor(text: text)
                    .font(.custom("Inter18pt-Regular", size: 15))
                    .foregroundColor(Color("TextColor"))
                    .frame(minHeight: 80, maxHeight: 120)
                    .padding(10)
                    .background(Color("gray3").opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(Color("gray3").opacity(0.3), lineWidth: 1))
            } else {
                TextField(placeholder, text: text)
                    .font(.custom("Inter18pt-Regular", size: 15))
                    .foregroundColor(Color("TextColor"))
                    .keyboardType(keyboardType)
                    .padding(12)
                    .background(Color("gray3").opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(Color("gray3").opacity(0.3), lineWidth: 1))
            }
        }
    }

    // MARK: - Post action

    private func postAd() {
        let uid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        let dialCode = UserDefaults.standard.string(forKey: Constant.country_Code) ?? "+1"
        let country = countryFromDial(dialCode)

        guard !uid.isEmpty else { errorMessage = "Not logged in."; return }
        guard !title.isEmpty, !description.isEmpty, !budget.isEmpty else {
            errorMessage = "Please fill in all required fields."
            return
        }

        isPosting = true
        errorMessage = nil

        let mediaData = selectedImages.compactMap { $0.jpegData(compressionQuality: 0.8) }

        ApiService.shared.postAdvertisement(
            uid: uid, country: country, category: category,
            title: title, description: description, link: link,
            budget: budget, duration: duration, mediaData: mediaData
        ) { success, message in
            DispatchQueue.main.async {
                isPosting = false
                if success { showSuccess = true } else { errorMessage = message }
            }
        }
    }

    private func countryFromDial(_ code: String) -> String {
        let map: [String: String] = [
            "+91": "India", "+1": "United States", "+44": "United Kingdom",
            "+61": "Australia", "+971": "UAE", "+92": "Pakistan",
            "+880": "Bangladesh", "+977": "Nepal"
        ]
        return map[code] ?? "India"
    }
}
