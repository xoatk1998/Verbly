import Foundation
import SwiftData

/// CSV import service. Ports parseCSVRow() and loadSeedWords() from background.js.
/// Handles quoted fields containing commas (RFC 4180 subset).
enum CSVImportService {

    // MARK: - Public types

    struct ImportResult {
        let imported: Int
        let skipped: Int
        let errors: [String]
    }

    // MARK: - Public API

    /// Imports words from a user-selected file URL (requires security-scoped access).
    @discardableResult
    static func importFrom(url: URL, context: ModelContext) -> ImportResult {
        guard url.startAccessingSecurityScopedResource() else {
            return ImportResult(imported: 0, skipped: 0, errors: ["Permission denied for: \(url.lastPathComponent)"])
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return ImportResult(imported: 0, skipped: 0, errors: ["Cannot read file: \(url.lastPathComponent)"])
        }
        return parseAndInsert(csvContent: content, context: context)
    }

    /// Loads seed words from the bundled sample.csv on first launch.
    static func loadSeedWords(context: ModelContext) {
        guard let url = Bundle.main.url(forResource: "sample", withExtension: "csv"),
              let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        parseAndInsert(csvContent: content, context: context)
    }

    // MARK: - Internal (testable) overload

    /// Parses raw CSV string directly — used by unit tests.
    @discardableResult
    static func importFrom(csvContent: String, context: ModelContext) -> ImportResult {
        parseAndInsert(csvContent: csvContent, context: context)
    }

    // MARK: - Private

    @discardableResult
    private static func parseAndInsert(csvContent: String, context: ModelContext) -> ImportResult {
        // Build existing-word set for duplicate detection (case-insensitive)
        let existing = Set(
            ((try? context.fetch(FetchDescriptor<Word>())) ?? [])
                .map { $0.english.lowercased() }
        )

        var lines = csvContent.components(separatedBy: "\n")

        // Skip header row when present
        if let first = lines.first,
           first.lowercased().contains("english") {
            lines.removeFirst()
        }

        var imported = 0
        var skipped  = 0
        var errors: [String] = []
        let validDifficulties = Set(["B1", "B2", "C1", "C2"])

        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            guard let fields = parseCSVRow(trimmed), fields.count >= 2 else {
                errors.append("Line \(i + 1): invalid format")
                continue
            }

            // CSV columns: english, vietnamese, exampleSentence, englishMeaning, difficulty, category
            let english         = fields[0].trimmingCharacters(in: .whitespaces)
            let vietnamese      = fields[1].trimmingCharacters(in: .whitespaces)
            let exampleSentence = fields.count > 2 ? fields[2].trimmingCharacters(in: .whitespaces) : ""
            let difficulty      = fields.count > 4 ? fields[4].trimmingCharacters(in: .whitespaces) : "B1"
            let category        = fields.count > 5 ? fields[5].trimmingCharacters(in: .whitespaces) : ""

            guard !english.isEmpty, !vietnamese.isEmpty else {
                errors.append("Line \(i + 1): empty english or vietnamese field")
                continue
            }

            // Skip duplicates silently
            if existing.contains(english.lowercased()) {
                skipped += 1
                continue
            }

            let finalDifficulty = validDifficulties.contains(difficulty) ? difficulty : "B1"
            context.insert(Word(english: english, vietnamese: vietnamese,
                                difficulty: finalDifficulty, category: category,
                                exampleSentence: exampleSentence.isEmpty ? nil : exampleSentence))
            imported += 1
        }

        try? context.save()
        return ImportResult(imported: imported, skipped: skipped, errors: errors)
    }

    /// Parses one CSV row, respecting double-quoted fields that may contain commas.
    /// Ports background.js parseCSVRow().
    private static func parseCSVRow(_ line: String) -> [String]? {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for ch in line {
            switch ch {
            case "\"":
                inQuotes.toggle()
            case "," where !inQuotes:
                fields.append(current)
                current = ""
            default:
                current.append(ch)
            }
        }
        fields.append(current)
        return fields.count >= 2 ? fields : nil
    }
}
