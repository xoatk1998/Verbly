import SwiftData
import Foundation

/// Mastery level derived from correctCount and isMastered flag.
enum MasteryLevel: String {
    case new = "New"
    case learning = "Learning"
    case mastered = "Mastered"
}

/// Vocabulary word with spaced repetition metadata.
/// Mirrors the JS word object in background.js (correctCount, nextReviewAt, isMastered, etc.).
@Model
final class Word {
    var id: String
    var english: String
    var vietnamese: String
    var difficulty: String       // "B1" | "B2" | "C1" | "C2"
    var category: String
    var correctCount: Int
    var incorrectCount: Int
    var nextReviewAt: Date?      // nil = due immediately (never reviewed)
    var addedAt: Date
    var isMastered: Bool

    init(english: String, vietnamese: String, difficulty: String = "B1", category: String = "") {
        self.id = UUID().uuidString
        self.english = english
        self.vietnamese = vietnamese
        self.difficulty = difficulty
        self.category = category
        self.correctCount = 0
        self.incorrectCount = 0
        self.nextReviewAt = nil
        self.addedAt = Date()
        self.isMastered = false
    }

    /// Accuracy as a value from 0.0 to 1.0.
    var accuracy: Double {
        let total = correctCount + incorrectCount
        return total == 0 ? 0 : Double(correctCount) / Double(total)
    }

    /// Derived mastery state.
    var masteryLevel: MasteryLevel {
        if isMastered { return .mastered }
        if correctCount > 0 || incorrectCount > 0 { return .learning }
        return .new
    }

    /// True when the word is due for review (nextReviewAt in the past or nil).
    var isDueForReview: Bool {
        guard let next = nextReviewAt else { return true }
        return Date() >= next
    }
}
