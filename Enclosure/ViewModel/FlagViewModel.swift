import SwiftUI
import Combine

class FlagViewModel: ObservableObject {
    @Published var flags: [FlagModel] = []
    @Published var isLoading = false
    @Published var searchText = ""

    let apiURL = Constant.baseURL + "get_country_list"

    init() {
        fetchCountryList()
    }

    func fetchCountryList() {
        isLoading = true
        guard let url = URL(string: apiURL) else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let data = data {
                    do {
                        let jsonString = String(data: data, encoding: .utf8)
                        print("API Response JSON: \(jsonString ?? "Invalid Data")") // JSON तपासा

                        let decodedResponse = try JSONDecoder().decode(CountryResponse.self, from: data)
                        self.flags = decodedResponse.data
                    } catch {
                        print("Decoding error: \(error.localizedDescription)")
                    }
                } else if let error = error {
                    print("Error fetching data: \(error.localizedDescription)")
                }
            }
        }.resume()
    }

    var filteredFlags: [FlagModel] {
        if searchText.isEmpty {
            return flags
        } else {
            let searchTextLower = searchText.lowercased()
            // Android filtering logic: first character must match, then contains check
            if searchTextLower.count >= 1 {
                return flags.filter { flag in
                    let nameLower = flag.country_name.lowercased()
                    if nameLower.count >= 1 && nameLower.prefix(1) == searchTextLower.prefix(1) {
                        return nameLower.contains(searchTextLower)
                    }
                    return false
                }
            }
            return []
        }
    }
}



// ✅ `Int` आणि `String` दोन्ही डिकोड करण्यासाठी कस्टम प्रकार
enum StringOrInt: Codable {
    case string(String)
    case int(Int)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.typeMismatch(StringOrInt.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String or Int"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let stringValue):
            try container.encode(stringValue)
        case .int(let intValue):
            try container.encode(intValue)
        }
    }
}


