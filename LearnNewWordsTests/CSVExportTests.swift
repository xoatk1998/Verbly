import XCTest
import SwiftData
@testable import LearnNewWords

@MainActor
final class CSVExportTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        let schema = Schema([Word.self, AppSettings.self, AppStats.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
    }

    override func tearDown() async throws {
        container = nil
        context = nil
    }

    // MARK: - csvString

    func testCsvString_header_isFirstLine() {
        let csv = CSVExportService.csvString(from: [])
        let firstLine = csv.components(separatedBy: "\n").first
        XCTAssertEqual(firstLine, "english,vietnamese,exampleSentence,englishMeaning,difficulty,category")
    }

    func testCsvString_emptyWords_onlyHeader() {
        let csv = CSVExportService.csvString(from: [])
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 1, "Only header row expected")
    }

    func testCsvString_singleWord_correctColumns() {
        let word = Word(english: "hello", vietnamese: "xin chào", difficulty: "B1", category: "greeting")
        context.insert(word)

        let csv = CSVExportService.csvString(from: [word])
        let lines = csv.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 2)

        let row = lines[1].components(separatedBy: ",")
        XCTAssertEqual(row[0], "hello")
        XCTAssertEqual(row[1], "xin chào")
        XCTAssertEqual(row[4], "B1")
        XCTAssertEqual(row[5], "greeting")
    }

    func testCsvString_wordWithExampleSentence_includedInColumn2() {
        let word = Word(english: "run", vietnamese: "chạy", exampleSentence: "I run every day.")
        context.insert(word)

        let csv = CSVExportService.csvString(from: [word])
        XCTAssertTrue(csv.contains("I run every day."), "Example sentence should appear in CSV")
    }

    func testCsvString_nilExampleSentence_emptyColumn() {
        let word = Word(english: "walk", vietnamese: "đi bộ")
        context.insert(word)

        let csv = CSVExportService.csvString(from: [word])
        let dataLine = csv.components(separatedBy: "\n")[1]
        // Column 2 (index 2) should be empty: "walk,đi bộ,,,"
        let cols = dataLine.components(separatedBy: ",")
        XCTAssertEqual(cols[2], "", "Nil exampleSentence should produce empty column")
    }

    func testCsvString_fieldWithComma_isQuoted() {
        let word = Word(english: "hi, there", vietnamese: "xin chào")
        context.insert(word)

        let csv = CSVExportService.csvString(from: [word])
        XCTAssertTrue(csv.contains("\"hi, there\""), "Field containing comma must be quoted")
    }

    func testCsvString_fieldWithQuote_isEscaped() {
        let word = Word(english: "it\"s", vietnamese: "nó là")
        context.insert(word)

        let csv = CSVExportService.csvString(from: [word])
        XCTAssertTrue(csv.contains("\"it\"\"s\""), "Embedded quote must be escaped as double-quote")
    }

    func testCsvString_multipleWords_correctRowCount() {
        let words = ["apple", "banana", "cherry"].map { Word(english: $0, vietnamese: "test") }
        words.forEach { context.insert($0) }

        let csv = CSVExportService.csvString(from: words)
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 4, "Header + 3 data rows")
    }

    // MARK: - Round-trip: export → import

    func testRoundTrip_exportThenImport_recoversAllWords() throws {
        // Insert words
        let words = [
            Word(english: "apple", vietnamese: "táo", difficulty: "B1", category: "food"),
            Word(english: "run", vietnamese: "chạy", difficulty: "B2", category: "verb",
                 exampleSentence: "I run fast."),
            Word(english: "smart, clever", vietnamese: "thông minh"),
        ]
        words.forEach { context.insert($0) }
        try context.save()

        // Export to CSV string
        let csv = CSVExportService.csvString(from: words)

        // Clear DB
        words.forEach { context.delete($0) }
        try context.save()
        let afterDelete = try context.fetch(FetchDescriptor<Word>())
        XCTAssertEqual(afterDelete.count, 0)

        // Re-import
        let result = CSVImportService.importFrom(csvContent: csv, context: context)

        XCTAssertEqual(result.imported, 3, "All 3 words should re-import: \(result.errors)")
        XCTAssertEqual(result.errors.count, 0, "No import errors expected: \(result.errors)")

        let imported = try context.fetch(FetchDescriptor<Word>())
        let englishSet = Set(imported.map { $0.english })
        XCTAssertTrue(englishSet.contains("apple"))
        XCTAssertTrue(englishSet.contains("run"))
        XCTAssertTrue(englishSet.contains("smart, clever"))
    }
}
