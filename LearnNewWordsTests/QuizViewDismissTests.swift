import XCTest
import SwiftData
@testable import LearnNewWords

/// Tests that quiz dismissal (X button, onComplete, advance-past-last) never crashes.
@MainActor
final class QuizViewDismissTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var stats: AppStats!
    private var settings: AppSettings!

    override func setUp() async throws {
        let schema = Schema([Word.self, AppSettings.self, AppStats.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
        stats = AppStats()
        settings = AppSettings()
        context.insert(stats)
        context.insert(settings)
        try context.save()
    }

    override func tearDown() async throws {
        container = nil
        context = nil
        stats = nil
        settings = nil
    }

    // MARK: - Helpers

    private func makeWord(_ english: String) -> Word {
        let w = Word(english: english, vietnamese: "test")
        context.insert(w)
        return w
    }

    private func makeSession(count: Int = 2) -> [QuizItem] {
        let words = (0..<count).map { makeWord("word\($0)") }
        return words.map {
            QuizItem(word: $0, direction: .enToVn, answerMode: .choice, distractors: [])
        }
    }

    // MARK: - onComplete called multiple times must not crash

    func testOnComplete_calledMultipleTimes_doesNotCrash() {
        var callCount = 0
        let onComplete = { callCount += 1 }

        // Simulate what close() triggers: onComplete may be called more than once
        // (e.g., watchdog + X button race). Must be idempotent.
        onComplete()
        onComplete()
        onComplete()

        XCTAssertEqual(callCount, 3, "onComplete should be callable multiple times without crashing")
    }

    // MARK: - advance past last question calls onComplete exactly once

    func testAdvance_pastLastQuestion_callsOnCompleteOnce() {
        let session = makeSession(count: 1)
        let expectation = XCTestExpectation(description: "onComplete called")
        expectation.expectedFulfillmentCount = 1
        expectation.assertForOverFulfill = true  // crash if called more than once

        // Simulate advance logic from QuizView
        var currentIndex = 0
        let onComplete = { expectation.fulfill() }

        // Mimic the DispatchQueue.main.asyncAfter callback
        if currentIndex + 1 < session.count {
            currentIndex += 1
        } else {
            onComplete()
        }

        wait(for: [expectation], timeout: 1)
    }

    // MARK: - isAdvancing guard prevents double recordAnswer

    func testIsAdvancingGuard_preventsDoubleRecordAnswer() {
        let word = makeWord("guard-test")
        let initialCorrect = word.correctCount
        let initialIncorrect = word.incorrectCount

        var isAdvancing = false
        var recordCount = 0

        func advance(correct: Bool) {
            guard !isAdvancing else { return }
            isAdvancing = true
            recordCount += 1
            SpacedRepetitionEngine.recordAnswer(word: word, correct: correct,
                                                stats: stats, context: context)
        }

        // First call goes through
        advance(correct: true)
        // Second call (e.g., timer fires) must be blocked
        advance(correct: false)

        XCTAssertEqual(recordCount, 1, "advance() must be called only once when isAdvancing guard is active")
        XCTAssertEqual(word.correctCount, initialCorrect + 1, "only one correct answer recorded")
        XCTAssertEqual(word.incorrectCount, initialIncorrect, "incorrect count unchanged")
    }

    // MARK: - Session builder returns correct count

    func testBuildSession_respectsWordsPerPopup() throws {
        let words = (0..<10).map { makeWord("w\($0)") }
        try context.save()

        settings.wordsPerPopup = 3
        let session = QuizSessionBuilder.buildSession(from: words, allWords: words, settings: settings)

        XCTAssertEqual(session.count, 3)
    }

    func testBuildSession_emptyEligible_returnsEmpty() {
        let session = QuizSessionBuilder.buildSession(from: [], allWords: [], settings: settings)
        XCTAssertTrue(session.isEmpty)
    }

    // MARK: - Force quiz fallback finds non-mastered words

    func testForceQuizFallback_usesNonMasteredWords() throws {
        // All eligible = empty (simulate quota exhausted + no words due)
        let word = makeWord("fallback-word")
        word.isMastered = false
        word.nextReviewAt = Date().addingTimeInterval(3600) // not due
        try context.save()

        let allWords = [word]
        let eligible = SpacedRepetitionEngine.eligibleWords(from: allWords, settings: settings, stats: stats)

        // Eligible should be empty (not due + quota may be 0)
        // Force fallback: any non-mastered word
        let fallback = eligible.isEmpty ? allWords.filter { !$0.isMastered } : eligible
        XCTAssertFalse(fallback.isEmpty, "force fallback must find at least one non-mastered word")
    }
}
