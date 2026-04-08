import XCTest
import SwiftData
@testable import LearnNewWords

@MainActor
final class CSVImportTests: XCTestCase {

    func testBasicImport_twoRows() throws {
        let context = try makeContext()
        let csv = """
        english,vietnamese,difficulty,category
        hello,xin chào,B1,greeting
        world,thế giới,B2,noun
        """

        let result = CSVImportService.importFrom(csvContent: csv, context: context)

        XCTAssertEqual(result.imported, 2)
        XCTAssertEqual(result.skipped, 0)
        XCTAssertEqual(result.errors.count, 0)
    }

    func testDuplicateEnglish_isSkipped() throws {
        let context = try makeContext()
        context.insert(Word(english: "hello", vietnamese: "xin chào"))
        let csv = "hello,xin chào,B1,"

        let result = CSVImportService.importFrom(csvContent: csv, context: context)

        XCTAssertEqual(result.imported, 0)
        XCTAssertEqual(result.skipped, 1)
    }

    func testQuotedFieldWithComma_parsedCorrectly() throws {
        let context = try makeContext()
        let csv = "\"hello, world\",xin chào,B1,"

        let result = CSVImportService.importFrom(csvContent: csv, context: context)

        XCTAssertEqual(result.imported, 1)
        let words = try context.fetch(FetchDescriptor<Word>())
        XCTAssertEqual(words.first?.english, "hello, world")
    }

    func testInvalidDifficulty_defaultsToB1() throws {
        let context = try makeContext()
        let csv = "hello,xin chào,Z9,"

        CSVImportService.importFrom(csvContent: csv, context: context)

        let words = try context.fetch(FetchDescriptor<Word>())
        XCTAssertEqual(words.first?.difficulty, "B1")
    }

    func testEmptyLines_areSkipped() throws {
        let context = try makeContext()
        let csv = "\nhello,xin chào,B1,\n\nworld,thế giới,B2,\n"

        let result = CSVImportService.importFrom(csvContent: csv, context: context)

        XCTAssertEqual(result.imported, 2)
    }

    // MARK: - Helper

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Word.self, AppSettings.self, AppStats.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return container.mainContext
    }
}
