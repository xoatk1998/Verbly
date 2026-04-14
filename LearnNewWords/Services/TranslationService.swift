import Foundation

/// Translates text using the MyMemory API (no API key required, email bumps quota to 500/day).
/// Endpoint: https://api.mymemory.translated.net/get?q={text}&langpair=en|vi&de={email}
enum TranslationService {

    private static let email = "nguyenducthien021998@gmail.com"

    /// Returns Vietnamese translation for an English word/phrase, or nil on failure/rate-limit.
    static func translateToVietnamese(_ text: String) async -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.mymemory.translated.net/get?q=\(encoded)&langpair=en|vi&de=\(email)")
        else { return nil }

        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

        struct MyMemoryResponse: Decodable {
            struct ResponseData: Decodable { let translatedText: String }
            let responseData: ResponseData
        }

        guard let result = try? JSONDecoder().decode(MyMemoryResponse.self, from: data) else { return nil }

        let translated = result.responseData.translatedText
        // Rate-limit response starts with "MYMEMORY WARNING"
        guard !translated.uppercased().hasPrefix("MYMEMORY") else { return nil }
        return translated
    }
}
