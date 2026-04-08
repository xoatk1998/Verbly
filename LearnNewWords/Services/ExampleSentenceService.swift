import Foundation

/// Fetches an example sentence for an English word from the Free Dictionary API.
/// Endpoint: https://api.dictionaryapi.dev/api/v2/entries/en/{word}
/// No API key required. Results are cached for the session to avoid repeat calls.
enum ExampleSentenceService {

    // MARK: - Decodable stubs (minimal — only fields we use)

    private struct Entry: Decodable {
        let meanings: [Meaning]
    }
    private struct Meaning: Decodable {
        let definitions: [Definition]
    }
    private struct Definition: Decodable {
        let example: String?
    }

    // MARK: - Public API

    /// Returns the first available example sentence for `word`, or nil if none found.
    static func fetch(for word: String) async -> String? {
        let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? word
        guard let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(encoded)") else {
            return nil
        }

        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else {
            return nil
        }

        guard let entries = try? JSONDecoder().decode([Entry].self, from: data) else {
            return nil
        }

        // Walk meanings → definitions to find the first non-empty example
        for entry in entries {
            for meaning in entry.meanings {
                for definition in meaning.definitions {
                    if let ex = definition.example, !ex.isEmpty {
                        return ex
                    }
                }
            }
        }
        return nil
    }
}
