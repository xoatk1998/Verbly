import Foundation
import SwiftData

/// CSV export service. Produces a plain CSV string for display / clipboard copy.
/// Column order: english, vietnamese, exampleSentence, englishMeaning, difficulty, category
enum CSVExportService {

    static func csvString(from words: [Word]) -> String {
        words.map { word in
            [
                escape(word.english),
                escape(word.vietnamese),
                escape(word.exampleSentence ?? ""),
                "",  // englishMeaning — not stored in model
                escape(word.difficulty),
                escape(word.category),
            ].joined(separator: ",")
        }.joined(separator: "\n")
    }

    // MARK: - Private

    private static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
