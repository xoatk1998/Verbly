# Phase 7: Testing & Polish

**Status**: Pending  
**Priority**: P2  
**Effort**: Medium (2 days)  
**Depends on**: Phases 1–6

---

## Context Links
- [Plan Overview](plan.md)

---

## Overview

Unit tests for the spaced repetition engine (pure logic, no UI), plus manual QA checklist for UI flows. Polish items from end-to-end testing.

---

## Unit Tests

### SpacedRepetitionTests.swift

```swift
import XCTest
import SwiftData
@testable import LearnNewWords

final class SpacedRepetitionTests: XCTestCase {

    // MARK: - Fibonacci intervals

    func testFibonacciInterval_correctCount0_returns1min() {
        let date = SpacedRepetitionEngine.nextReviewDate(correctCount: 0)
        let interval = date.timeIntervalSinceNow
        XCTAssertEqual(interval, 60, accuracy: 2)
    }

    func testFibonacciInterval_correctCount1_returns2min() {
        let date = SpacedRepetitionEngine.nextReviewDate(correctCount: 1)
        XCTAssertEqual(date.timeIntervalSinceNow, 120, accuracy: 2)
    }

    func testFibonacciInterval_clampsBeyondArray() {
        // correctCount=99 should use last fibonacci value (89 min)
        let date = SpacedRepetitionEngine.nextReviewDate(correctCount: 99)
        XCTAssertEqual(date.timeIntervalSinceNow, 89 * 60, accuracy: 2)
    }

    // MARK: - recordAnswer

    func testRecordCorrectAnswer_incrementsCorrectCount() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let word = Word(english: "hello", vietnamese: "xin chào")
        let stats = AppStats()
        context.insert(word); context.insert(stats)

        SpacedRepetitionEngine.recordAnswer(word: word, correct: true, stats: stats, context: context)

        XCTAssertEqual(word.correctCount, 1)
        XCTAssertEqual(word.incorrectCount, 0)
        XCTAssertEqual(stats.correct, 1)
        XCTAssertEqual(stats.streak, 1)
        XCTAssertNotNil(word.nextReviewAt)
    }

    func testRecordWrongAnswer_resetsCorrectCount() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let word = Word(english: "hello", vietnamese: "xin chào")
        word.correctCount = 5
        let stats = AppStats()
        stats.streak = 5
        context.insert(word); context.insert(stats)

        SpacedRepetitionEngine.recordAnswer(word: word, correct: false, stats: stats, context: context)

        XCTAssertEqual(word.correctCount, 0)   // reset
        XCTAssertEqual(word.incorrectCount, 1)
        XCTAssertEqual(stats.streak, 0)        // reset
        XCTAssertEqual(stats.incorrect, 1)
    }

    func testMasteryThreshold_setsMastered() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let word = Word(english: "hello", vietnamese: "xin chào")
        word.correctCount = 6  // one below threshold
        let stats = AppStats()
        context.insert(word); context.insert(stats)

        SpacedRepetitionEngine.recordAnswer(word: word, correct: true, stats: stats, context: context)

        XCTAssertTrue(word.isMastered)
        XCTAssertEqual(word.correctCount, 7)
    }

    func testBestStreak_updatesWhenExceeded() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let word = Word(english: "test", vietnamese: "thử nghiệm")
        let stats = AppStats()
        stats.streak = 3
        stats.bestStreak = 3
        context.insert(word); context.insert(stats)

        SpacedRepetitionEngine.recordAnswer(word: word, correct: true, stats: stats, context: context)

        XCTAssertEqual(stats.streak, 4)
        XCTAssertEqual(stats.bestStreak, 4)
    }

    // MARK: - eligibleWords

    func testEligibleWords_excludesMastered() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let settings = AppSettings()
        let stats = AppStats()
        let mastered = Word(english: "a", vietnamese: "a"); mastered.isMastered = true
        let active = Word(english: "b", vietnamese: "b")
        context.insert(settings); context.insert(stats)
        context.insert(mastered); context.insert(active)

        let eligible = SpacedRepetitionEngine.eligibleWords(from: [mastered, active], settings: settings, stats: stats)

        XCTAssertFalse(eligible.contains { $0.english == "a" })
        XCTAssertTrue(eligible.contains { $0.english == "b" })
    }

    func testEligibleWords_respectsDailyQuota() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let settings = AppSettings()
        settings.wordsPerDay = 2
        let stats = AppStats()
        stats.dailyNewWordsToday = 2  // quota exhausted
        let newWord = Word(english: "c", vietnamese: "c")  // brand new
        context.insert(settings); context.insert(stats); context.insert(newWord)

        let eligible = SpacedRepetitionEngine.eligibleWords(from: [newWord], settings: settings, stats: stats)

        XCTAssertTrue(eligible.isEmpty, "New words should not appear when daily quota is exhausted")
    }

    // MARK: - Helper

    private func makeTestContainer() throws -> ModelContainer {
        let schema = Schema([Word.self, AppSettings.self, AppStats.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
```

### CSVImportTests.swift

```swift
import XCTest
import SwiftData
@testable import LearnNewWords

final class CSVImportTests: XCTestCase {

    func testBasicImport() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let csv = "english,vietnamese,difficulty,category\nhello,xin chào,B1,greeting\nworld,thế giới,B2,noun"

        let result = CSVImportService.importFrom(csvContent: csv, context: context)

        XCTAssertEqual(result.imported, 2)
        XCTAssertEqual(result.skipped, 0)
        XCTAssertEqual(result.errors.count, 0)
    }

    func testDuplicateSkipped() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let existing = Word(english: "hello", vietnamese: "xin chào")
        context.insert(existing)
        let csv = "hello,xin chào,B1,"

        let result = CSVImportService.importFrom(csvContent: csv, context: context)

        XCTAssertEqual(result.imported, 0)
        XCTAssertEqual(result.skipped, 1)
    }

    func testQuotedFieldWithComma() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let csv = "\"hello, world\",xin chào,B1,"

        let result = CSVImportService.importFrom(csvContent: csv, context: context)

        XCTAssertEqual(result.imported, 1)
        let words = try context.fetch(FetchDescriptor<Word>())
        XCTAssertEqual(words.first?.english, "hello, world")
    }

    private func makeTestContainer() throws -> ModelContainer {
        let schema = Schema([Word.self, AppSettings.self, AppStats.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
```

> Note: `CSVImportService.importFrom(csvContent:context:)` is an internal overload for testing that accepts raw string instead of URL. Add it as `internal` alongside the public `importFrom(url:context:)`.

---

## Manual QA Checklist

### First Launch
- [ ] App appears in menu bar, NOT in Dock
- [ ] ~100 seed words loaded automatically
- [ ] Settings default to: 10 min interval, 2 words/session, choice mode

### Quiz Flow
- [ ] Quiz window appears after configured interval
- [ ] Window floats above all other apps
- [ ] Multiple choice: 4 options in 2×2 grid
- [ ] Correct answer highlights green, wrong highlights red
- [ ] Typing mode: Enter submits answer
- [ ] Countdown bar animates, quiz closes on timeout
- [ ] English word is spoken aloud for EN→VN questions
- [ ] After all words answered, window closes automatically

### Word Management
- [ ] Add word: appears in list immediately
- [ ] Delete word: removed from list, confirmed gone after restart
- [ ] Search: filters both English and Vietnamese fields
- [ ] Difficulty filter chips work correctly
- [ ] CSV import: sample.csv imports, duplicates skipped, alert shown

### Statistics
- [ ] Correct/incorrect counts update after each quiz
- [ ] Streak increments on correct, resets on wrong
- [ ] Best streak preserved after reset
- [ ] Mastered word appears in mastered count

### Settings
- [ ] Toggling "Enable Learning" stops/starts quiz scheduler
- [ ] Changing interval: next quiz fires at new interval
- [ ] Words per session: quiz shows correct number of words

---

## Polish Items

- App icon: design or source an appropriate icon for Dock (even if LSUIElement hides it, Spotlight/Finder still show it)
- Menu bar icon: use `graduationcap.fill` or `textformat.abc` SF Symbol
- Empty state: show "No words due" message when no eligible words
- Onboarding: first-launch tooltip explaining the app

---

## Todo

- [ ] Create `LearnNewWordsTests/SpacedRepetitionTests.swift`
- [ ] Create `LearnNewWordsTests/CSVImportTests.swift`
- [ ] Add `internal` CSV string overload to `CSVImportService`
- [ ] Run all unit tests — must pass before shipping
- [ ] Complete manual QA checklist

---

## Success Criteria

- All unit tests pass (`⌘U` in Xcode)
- No crashes across all manual QA scenarios
- Memory: no obvious leaks (check Instruments → Leaks)
