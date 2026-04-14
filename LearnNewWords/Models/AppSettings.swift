import SwiftData
import Foundation
import SwiftUI

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
    /// Hex color string (e.g. "1A2B3C") for the popover background. nil = system material.
    var backgroundColorHex: String?

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
        self.backgroundColorHex = nil
    }

    /// Effective scheduling interval in seconds (combines minutes + seconds settings).
    var effectiveIntervalSeconds: Int {
        if let secs = intervalSeconds { return secs }
        return intervalMinutes * 60
    }

    /// Returns a SwiftUI Color from backgroundColorHex, or nil if not set.
    var backgroundColor: Color? {
        guard let hex = backgroundColorHex else { return nil }
        return Color(hex: hex)
    }
}

// MARK: - Color ↔ hex helpers

extension Color {
    init?(hex: String) {
        let h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        guard h.count == 6, let n = UInt64(h, radix: 16) else { return nil }
        self.init(
            red:   Double((n >> 16) & 0xFF) / 255,
            green: Double((n >>  8) & 0xFF) / 255,
            blue:  Double( n        & 0xFF) / 255
        )
    }

    /// Converts to a 6-char uppercase hex string via NSColor (macOS only).
    func toHex() -> String? {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        return String(format: "%02X%02X%02X",
                      Int(c.redComponent   * 255),
                      Int(c.greenComponent * 255),
                      Int(c.blueComponent  * 255))
    }
}
