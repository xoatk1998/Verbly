# Phase 3: Core Engine (Spaced Repetition + Scheduling)

**Status**: Pending  
**Priority**: P0  
**Effort**: Medium (2-3 days)  
**Depends on**: Phase 2

---

## Context Links
- [Plan Overview](plan.md)
- [background.js lines 200-530](../../background.js) — scheduling engine, quiz session builder, word eligibility

---

## Overview

Port the spaced repetition algorithm and scheduling logic from `background.js` to Swift. Three focused classes: engine (algorithm), session builder (quiz setup), scheduler (timer management).

---

## Key Algorithms to Port

### Fibonacci Scheduling (background.js:1-10)
```javascript
const FIBONACCI = [1, 2, 3, 5, 8, 13, 21, 34, 55, 89]; // minutes
const MASTERED_THRESHOLD = 7;

function getFibInterval(correctCount) {
  const idx = Math.min(correctCount, FIBONACCI.length - 1);
  return FIBONACCI[idx] * 60 * 1000; // ms
}
```

### Word Eligibility (background.js:203-212)
```javascript
function getEligibleWords(words, settings) {
  // filter by difficulty + category
  // fallback to all words if filters yield nothing
  // exclude mastered words
  // sort by nextReviewAt (due first)
}
```

### Answer Recording (background.js RECORD_ANSWER handler)
```javascript
if (correct) {
  word.correctCount++;
  const interval = getFibInterval(word.correctCount);
  word.nextReviewAt = Date.now() + interval;
  if (word.correctCount >= MASTERED_THRESHOLD) word.isMastered = true;
  stats.streak++; stats.bestStreak = max(streak, bestStreak);
} else {
  word.incorrectCount++;
  word.correctCount = 0;  // reset streak
  word.nextReviewAt = Date.now() + getFibInterval(0); // back to 1 min
  stats.streak = 0;
}
```

---

## Implementation Steps

### 1. SpacedRepetitionEngine.swift

```swift
import Foundation
import SwiftData

struct SpacedRepetitionEngine {
    static let fibonacci = [1, 2, 3, 5, 8, 13, 21, 34, 55, 89] // minutes
    static let masteredThreshold = 7

    /// Returns next review Date after a correct answer
    static func nextReviewDate(correctCount: Int) -> Date {
        let idx = min(correctCount, fibonacci.count - 1)
        let minutes = fibonacci[idx]
        return Date().addingTimeInterval(Double(minutes) * 60)
    }

    /// Record answer and update word + stats in context
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
            word.correctCount = 0
            word.nextReviewAt = nextReviewDate(correctCount: 0)
            stats.incorrect += 1
            stats.streak = 0
        }
        try? context.save()
    }

    /// Select eligible words for a quiz session
    static func eligibleWords(
        from words: [Word],
        settings: AppSettings,
        stats: AppStats
    ) -> [Word] {
        // Reset daily new-word count if new day
        if stats.isNewDay {
            stats.dailyNewWordsToday = 0
            stats.dailyResetDate = Date()
        }

        var pool = words.filter { !$0.isMastered && $0.isDueForReview }

        // Apply difficulty filter
        if !settings.selectedDifficulties.isEmpty {
            let filtered = pool.filter { settings.selectedDifficulties.contains($0.difficulty) }
            if !filtered.isEmpty { pool = filtered }
        }

        // Apply category filter
        if !settings.selectedCategories.isEmpty {
            let filtered = pool.filter { settings.selectedCategories.contains($0.category) }
            if !filtered.isEmpty { pool = filtered }
        }

        // Limit new words per day
        let newWords = pool.filter { $0.correctCount == 0 && $0.incorrectCount == 0 }
        let reviewWords = pool.filter { $0.correctCount > 0 || $0.incorrectCount > 0 }
        let newBudget = max(0, settings.wordsPerDay - stats.dailyNewWordsToday)
        let allowedNew = Array(newWords.prefix(newBudget))

        return (allowedNew + reviewWords).sorted {
            ($0.nextReviewAt ?? .distantPast) < ($1.nextReviewAt ?? .distantPast)
        }
    }
}
```

### 2. QuizSessionBuilder.swift

```swift
import Foundation

struct QuizItem {
    let word: Word
    let direction: QuizDirection   // enToVn | vnToEn
    let answerMode: AnswerMode     // choice | typing
    let distractors: [String]      // 3 wrong answers for multiple choice
}

enum QuizDirection { case enToVn, vnToEn }
enum AnswerMode { case choice, typing }

struct QuizSessionBuilder {
    static func buildSession(
        from eligible: [Word],
        allWords: [Word],
        settings: AppSettings
    ) -> [QuizItem] {
        let count = min(settings.wordsPerPopup, eligible.count)
        let selected = Array(eligible.shuffled().prefix(count))

        return selected.map { word in
            let direction = resolveDirection(settings.questionDirection)
            let mode = resolveMode(settings.answerType)
            let distractors = pickDistractors(for: word, from: allWords, direction: direction)
            return QuizItem(word: word, direction: direction, answerMode: mode, distractors: distractors)
        }
    }

    private static func resolveDirection(_ setting: String) -> QuizDirection {
        switch setting {
        case "en-to-vn": return .enToVn
        case "vn-to-en": return .vnToEn
        default: return Bool.random() ? .enToVn : .vnToEn
        }
    }

    private static func resolveMode(_ setting: String) -> AnswerMode {
        switch setting {
        case "typing": return .typing
        case "choice": return .choice
        default: return Bool.random() ? .choice : .typing
        }
    }

    private static func pickDistractors(for word: Word, from all: [Word], direction: QuizDirection) -> [String] {
        let others = all.filter { $0.id != word.id }.shuffled().prefix(3)
        return others.map { direction == .enToVn ? $0.vietnamese : $0.english }
    }
}
```

### 3. QuizScheduler.swift

```swift
import Foundation
import SwiftData

/// Replaces Chrome Alarms API. Fires periodic quiz triggers.
@MainActor
class QuizScheduler: ObservableObject {
    static let shared = QuizScheduler()

    private var timer: Timer?
    private var lastFiredAt: Date = .distantPast
    var onTrigger: (() -> Void)?

    func start(intervalSeconds: Int) {
        stop()
        guard intervalSeconds > 0 else { return }
        // Poll every second for sub-minute intervals; use interval directly for ≥60s
        let pollInterval: TimeInterval = intervalSeconds < 60 ? 1.0 : Double(intervalSeconds)
        let target = TimeInterval(intervalSeconds)

        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                let elapsed = Date().timeIntervalSince(self.lastFiredAt)
                if elapsed >= target {
                    self.lastFiredAt = Date()
                    self.onTrigger?()
                }
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func updateInterval(_ seconds: Int) {
        start(intervalSeconds: seconds)
    }
}
```

---

## Todo

- [ ] Create `Engine/SpacedRepetitionEngine.swift`
- [ ] Create `Engine/QuizSessionBuilder.swift`
- [ ] Create `Engine/QuizScheduler.swift`
- [ ] Wire `QuizScheduler.onTrigger` in AppDelegate (Phase 4)
- [ ] Unit test `SpacedRepetitionEngine` (Phase 7)

---

## Success Criteria

- `SpacedRepetitionEngine.recordAnswer` correctly updates word + stats
- `nextReviewDate` matches Fibonacci values from JS
- `QuizScheduler` fires callback at correct interval
- No crashes with empty word list
