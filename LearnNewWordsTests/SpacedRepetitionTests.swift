import XCTest
import SwiftData
@testable import LearnNewWords

@MainActor
final class SpacedRepetitionTests: XCTestCase {

    // MARK: - Fibonacci interval

    func testInterval_correctCount0_is1min() {
        let date = SpacedRepetitionEngine.nextReviewDate(correctCount: 0)
        XCTAssertEqual(date.timeIntervalSinceNow, 60, accuracy: 2)
    }

    func testInterval_correctCount1_is2min() {
        let date = SpacedRepetitionEngine.nextReviewDate(correctCount: 1)
        XCTAssertEqual(date.timeIntervalSinceNow, 120, accuracy: 2)
    }

    func testInterval_clampsAtMax() {
        // correctCount beyond array length → last fibonacci value (89 min)
        let date = SpacedRepetitionEngine.nextReviewDate(correctCount: 999)
        XCTAssertEqual(date.timeIntervalSinceNow, 89 * 60, accuracy: 2)
    }

    // MARK: - recordAnswer — correct

    func testRecordCorrect_incrementsCountsAndStreak() throws {
        let (word, stats, context) = try makeFixture()

        SpacedRepetitionEngine.recordAnswer(word: word, correct: true, stats: stats, context: context)

        XCTAssertEqual(word.correctCount, 1)
        XCTAssertEqual(word.incorrectCount, 0)
        XCTAssertEqual(stats.correct, 1)
        XCTAssertEqual(stats.streak, 1)
        XCTAssertNotNil(word.nextReviewAt)
    }

    func testRecordCorrect_updatesBestStreak() throws {
        let (word, stats, context) = try makeFixture()
        stats.streak = 4
        stats.bestStreak = 4

        SpacedRepetitionEngine.recordAnswer(word: word, correct: true, stats: stats, context: context)

        XCTAssertEqual(stats.streak, 5)
        XCTAssertEqual(stats.bestStreak, 5)
    }

    func testRecordCorrect_atThreshold_setsMastered() throws {
        let (word, stats, context) = try makeFixture()
        word.correctCount = SpacedRepetitionEngine.masteredThreshold - 1

        SpacedRepetitionEngine.recordAnswer(word: word, correct: true, stats: stats, context: context)

        XCTAssertTrue(word.isMastered)
    }

    // MARK: - recordAnswer — wrong

    func testRecordWrong_resetsCorrectCountAndStreak() throws {
        let (word, stats, context) = try makeFixture()
        word.correctCount = 5
        stats.streak = 5

        SpacedRepetitionEngine.recordAnswer(word: word, correct: false, stats: stats, context: context)

        XCTAssertEqual(word.correctCount, 0)
        XCTAssertEqual(word.incorrectCount, 1)
        XCTAssertEqual(stats.streak, 0)
        XCTAssertEqual(stats.incorrect, 1)
    }

    // MARK: - eligibleWords

    func testEligibleWords_excludesMastered() throws {
        let container = try makeContainer()
        _container = container
        let context = container.mainContext
        let settings = AppSettings()
        let stats = AppStats()
        let mastered = Word(english: "mastered", vietnamese: "đã thuộc")
        mastered.isMastered = true
        let active = Word(english: "active", vietnamese: "đang học")
        context.insert(settings)
        context.insert(stats)
        context.insert(mastered)
        context.insert(active)

        let eligible = SpacedRepetitionEngine.eligibleWords(
            from: [mastered, active], settings: settings, stats: stats)

        XCTAssertFalse(eligible.contains { $0.english == "mastered" })
        XCTAssertTrue(eligible.contains { $0.english == "active" })
    }

    func testEligibleWords_respectsDailyQuota() throws {
        let container = try makeContainer()
        _container = container
        let context = container.mainContext
        let settings = AppSettings()
        settings.wordsPerDay = 2
        let stats = AppStats()
        stats.dailyNewWordsToday = 2   // quota exhausted
        let newWord = Word(english: "new", vietnamese: "mới")
        context.insert(settings)
        context.insert(stats)
        context.insert(newWord)

        let eligible = SpacedRepetitionEngine.eligibleWords(
            from: [newWord], settings: settings, stats: stats)

        XCTAssertTrue(eligible.isEmpty, "No new words should appear when daily quota is exhausted")
    }

    // MARK: - Helpers

    /// Holds a strong reference to the container so SwiftData models stay valid.
    private var _container: ModelContainer?

    private func makeFixture() throws -> (Word, AppStats, ModelContext) {
        let container = try makeContainer()
        _container = container
        let context = container.mainContext
        let word = Word(english: "hello", vietnamese: "xin chào")
        let stats = AppStats()
        context.insert(word)
        context.insert(stats)
        return (word, stats, context)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Word.self, AppSettings.self, AppStats.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
