import SwiftData
import Foundation

/// Persisted statistics. Singleton — only one row ever exists.
/// Mirrors DEFAULT_STATS from background.js.
@Model
final class AppStats {
    var correct: Int
    var incorrect: Int
    var streak: Int
    var bestStreak: Int
    var dailyNewWordsToday: Int     // count of new words shown today
    var dailyResetDate: Date        // date when dailyNewWordsToday was last reset to 0
    /// Pipe-separated English words pinned for today's quiz list.
    /// Optional for SwiftData lightweight migration compatibility.
    var todayWordEnglish: String?
    /// "yyyy-MM-dd" when todayWordEnglish was last set — nil forces recomputation.
    var todayDateString: String?

    init() {
        self.correct = 0
        self.incorrect = 0
        self.streak = 0
        self.bestStreak = 0
        self.dailyNewWordsToday = 0
        self.dailyResetDate = Date()
        self.todayWordEnglish = nil
        self.todayDateString = nil
    }

    /// Overall accuracy as 0.0–1.0.
    var accuracy: Double {
        let total = correct + incorrect
        return total == 0 ? 0 : Double(correct) / Double(total)
    }

    /// True if the calendar day has rolled over since last reset.
    var isNewDay: Bool {
        !Calendar.current.isDateInToday(dailyResetDate)
    }
}
