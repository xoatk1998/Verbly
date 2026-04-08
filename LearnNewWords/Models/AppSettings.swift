import SwiftData
import Foundation

/// Persisted user settings. Singleton — only one row ever exists.
/// Mirrors DEFAULT_SETTINGS from background.js.
@Model
final class AppSettings {
    var intervalMinutes: Int        // 1–60; ignored when intervalSeconds is set
    var intervalSeconds: Int?       // 15 | 30 | nil (sub-minute intervals)
    var isEnabled: Bool
    var wordsPerDay: Int            // 1–20 new words allowed per day
    var wordsPerPopup: Int          // 1–5 words per quiz session
    var answerType: String          // "choice" | "typing" | "mixed"
    var questionDirection: String   // "en-to-vn" | "vn-to-en" | "mixed"
    var selectedDifficulties: [String]  // [] = all; subset of ["B1","B2","C1","C2"]
    var selectedCategories: [String]    // [] = all available categories
    var sessionTimeoutSeconds: Int?     // 30–180 | nil = no timeout

    init() {
        self.intervalMinutes = 10
        self.intervalSeconds = nil
        self.isEnabled = true
        self.wordsPerDay = 5
        self.wordsPerPopup = 2
        self.answerType = "choice"
        self.questionDirection = "mixed"
        self.selectedDifficulties = []
        self.selectedCategories = []
        self.sessionTimeoutSeconds = 90
    }

    /// Effective scheduling interval in seconds (combines minutes + seconds settings).
    var effectiveIntervalSeconds: Int {
        if let secs = intervalSeconds { return secs }
        return intervalMinutes * 60
    }
}
