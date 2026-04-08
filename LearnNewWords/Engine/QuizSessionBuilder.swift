import Foundation

// MARK: - Quiz value types

/// Direction of a quiz question.
enum QuizDirection {
    case enToVn   // Show English, answer Vietnamese
    case vnToEn   // Show Vietnamese, answer English
}

/// Answer input mode for a quiz question.
enum AnswerMode {
    case choice   // 2×2 multiple choice grid
    case typing   // Free-text input field
}

/// A single question within a quiz session.
struct QuizItem {
    let word: Word
    let direction: QuizDirection
    let answerMode: AnswerMode
    /// Three distractor answers (wrong options) for multiple choice mode.
    let distractors: [String]
}

// MARK: - Builder

/// Builds quiz sessions from eligible words. Stateless.
/// Ports buildAndShowSession() logic from background.js.
enum QuizSessionBuilder {

    /// Builds a shuffled quiz session from the eligible word pool.
    /// - Parameters:
    ///   - eligible: Pre-filtered, sorted words from SpacedRepetitionEngine.eligibleWords
    ///   - allWords: Full word list used to pick distractors
    ///   - settings: User settings for wordsPerPopup, answerType, questionDirection
    static func buildSession(
        from eligible: [Word],
        allWords: [Word],
        settings: AppSettings
    ) -> [QuizItem] {
        let count = min(settings.wordsPerPopup, eligible.count)
        guard count > 0 else { return [] }

        let selected = Array(eligible.shuffled().prefix(count))

        return selected.map { word in
            let direction = resolveDirection(settings.questionDirection)
            // Bug 2-1: EN→VN is concept-heavy; typing mode not supported for that direction.
            // VN→EN (recall) can still use typing.
            let mode: AnswerMode = direction == .enToVn ? .choice : resolveMode(settings.answerType)
            let distractors = pickDistractors(for: word, from: allWords, direction: direction)
            return QuizItem(word: word, direction: direction, answerMode: mode, distractors: distractors)
        }
    }

    // MARK: - Private helpers

    private static func resolveDirection(_ setting: String) -> QuizDirection {
        switch setting {
        case "en-to-vn": return .enToVn
        case "vn-to-en": return .vnToEn
        default:         return Bool.random() ? .enToVn : .vnToEn
        }
    }

    private static func resolveMode(_ setting: String) -> AnswerMode {
        switch setting {
        case "typing": return .typing
        case "choice": return .choice
        default:       return Bool.random() ? .choice : .typing
        }
    }

    /// Picks 3 unique distractors from other words. Falls back to fewer if pool is too small.
    private static func pickDistractors(
        for word: Word,
        from all: [Word],
        direction: QuizDirection
    ) -> [String] {
        let others = all
            .filter { $0.id != word.id }
            .shuffled()
            .prefix(3)
        return others.map { direction == .enToVn ? $0.vietnamese : $0.english }
    }
}
