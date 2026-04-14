import Foundation
import SwiftData

/// Pure spaced repetition logic. Stateless — all mutations go through SwiftData context.
/// Ports the Fibonacci scheduling algorithm from background.js.
enum SpacedRepetitionEngine {

    // MARK: - Constants

    /// Fibonacci sequence in minutes — used for short-term reinforcement (correctCount 1–3).
    static let fibonacciMinutes = [1, 2, 3, 5, 8, 13, 21, 34, 55, 89]

    /// Day-based intervals for long-term retention (correctCount ≥ 3).
    /// After a word is learned in short-term sessions, it graduates to daily spacing.
    static let dayIntervals = [1, 3, 7, 14, 30]   // days

    /// correctCount at which scheduling switches from minutes → days.
    static let longTermThreshold = 3

    /// Correct answers needed to mark a word as mastered — mirrors `MASTERED_THRESHOLD`.
    static let masteredThreshold = 7

    // MARK: - Scheduling

    /// Returns the next review Date after `correctCount` consecutive correct answers.
    ///
    /// Two-tier scheduling:
    /// - correctCount 1–2 (short-term): Fibonacci minutes for same/next-session reinforcement.
    /// - correctCount ≥ 3 (long-term): Day-based ladder so words resurface across days/weeks.
    static func nextReviewDate(correctCount: Int) -> Date {
        if correctCount < longTermThreshold {
            // Short-term: minute-based Fibonacci
            let idx = min(correctCount, fibonacciMinutes.count - 1)
            let minutes = fibonacciMinutes[idx]
            return Date().addingTimeInterval(Double(minutes) * 60)
        } else {
            // Long-term: day-based ladder (0-indexed from longTermThreshold)
            let dayIdx = min(correctCount - longTermThreshold, dayIntervals.count - 1)
            let days = dayIntervals[dayIdx]
            return Date().addingTimeInterval(Double(days) * 24 * 60 * 60)
        }
    }

    // MARK: - Answer Recording

    /// Records a quiz answer, updates the word's spaced repetition state and session stats,
    /// then saves the context. Mirrors the RECORD_ANSWER message handler in background.js.
    static func recordAnswer(
        word: Word,
        correct: Bool,
        stats: AppStats,
        context: ModelContext
    ) {
        if correct {
            word.correctCount += 1
            word.nextReviewAt = nextReviewDate(correctCount: word.correctCount)
            if word.correctCount >= masteredThreshold {
                word.isMastered = true
            }
            stats.correct += 1
            stats.streak += 1
            if stats.streak > stats.bestStreak {
                stats.bestStreak = stats.streak
            }
        } else {
            word.incorrectCount += 1
            word.correctCount = 0   // streak reset — same as JS
            word.nextReviewAt = nextReviewDate(correctCount: 0)
            stats.incorrect += 1
            stats.streak = 0
        }
        try? context.save()
    }

    // MARK: - Eligibility

    /// Returns words eligible for the next quiz session, sorted by urgency.
    /// Mirrors `getEligibleWords()` + daily quota logic in background.js.
    static func eligibleWords(
        from words: [Word],
        settings: AppSettings,
        stats: AppStats
    ) -> [Word] {
        // Reset daily new-word counter when the calendar day rolls over
        if stats.isNewDay {
            stats.dailyNewWordsToday = 0
            stats.dailyResetDate = Date()
        }

        // Base pool: not mastered and due for review
        var pool = words.filter { !$0.isMastered && $0.isDueForReview }

        // Difficulty filter — fallback to full pool if filter yields nothing
        if !settings.selectedDifficulties.isEmpty {
            let filtered = pool.filter { settings.selectedDifficulties.contains($0.difficulty) }
            if !filtered.isEmpty { pool = filtered }
        }

        // Category filter — same fallback behaviour
        if !settings.selectedCategories.isEmpty {
            let filtered = pool.filter { settings.selectedCategories.contains($0.category) }
            if !filtered.isEmpty { pool = filtered }
        }

        // Split new vs review words and apply daily new-word quota
        let newWords = pool.filter { $0.correctCount == 0 && $0.incorrectCount == 0 }
        let reviewWords = pool.filter { $0.correctCount > 0 || $0.incorrectCount > 0 }
        let newBudget = max(0, settings.wordsPerDay - stats.dailyNewWordsToday)
        let allowedNew = Array(newWords.shuffled().prefix(newBudget))  // shuffle so different words appear each session

        // Sort: most overdue first (nil nextReviewAt = overdue since forever)
        return (allowedNew + reviewWords).sorted {
            ($0.nextReviewAt ?? .distantPast) < ($1.nextReviewAt ?? .distantPast)
        }
    }
}
