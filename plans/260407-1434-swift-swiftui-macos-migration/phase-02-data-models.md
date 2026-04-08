# Phase 2: Data Models & SwiftData

**Status**: Pending  
**Priority**: P0 (blocker for engine + UI)  
**Effort**: Medium (2-3 days)  
**Depends on**: Phase 1

---

## Context Links
- [Plan Overview](plan.md)
- [background.js lines 1-200](../../background.js) — constants, defaults, storage structure

---

## Overview

Define SwiftData `@Model` classes that mirror the Chrome extension's `chrome.storage.local` data structure. No chunking needed (SwiftData handles large datasets natively).

---

## Data Model Mapping

### Word (from background.js)

```javascript
// JS structure
{
  id: "timestamp-string",
  english: "word",
  vietnamese: "nghĩa",
  difficulty: "B1",      // B1 | B2 | C1 | C2
  category: "tag",
  correctCount: 0,
  incorrectCount: 0,
  nextReviewAt: null,    // ISO timestamp or null
  addedAt: "ISO",
  isMastered: false
}
```

```swift
// Swift equivalent
@Model
final class Word {
    var id: String
    var english: String
    var vietnamese: String
    var difficulty: String        // "B1" | "B2" | "C1" | "C2"
    var category: String
    var correctCount: Int
    var incorrectCount: Int
    var nextReviewAt: Date?
    var addedAt: Date
    var isMastered: Bool
    
    // Computed
    var accuracy: Double { ... }
    var masteryLevel: MasteryLevel { ... }
}

enum MasteryLevel { case new, learning, mastered }
```

### AppSettings

```javascript
// JS defaults
DEFAULT_SETTINGS = {
  intervalMinutes: 10,
  intervalSeconds: null,
  enabled: true,
  wordsPerDay: 5,
  wordsPerPopup: 2,
  answerType: "choice",          // choice | typing | mixed
  questionDirection: "mixed",    // en-to-vn | vn-to-en | mixed
  selectedDifficulties: [],
  selectedCategories: [],
  sessionTimeoutSeconds: 90
}
```

```swift
@Model
final class AppSettings {
    var intervalMinutes: Int          // 1–60, 0 = use seconds
    var intervalSeconds: Int?         // 15 | 30 | nil
    var isEnabled: Bool
    var wordsPerDay: Int              // 1–20
    var wordsPerPopup: Int            // 1–5
    var answerType: String            // "choice" | "typing" | "mixed"
    var questionDirection: String     // "en-to-vn" | "vn-to-en" | "mixed"
    var selectedDifficulties: [String]
    var selectedCategories: [String]
    var sessionTimeoutSeconds: Int?   // 30–180, nil = no timeout
}
```

### AppStats

```swift
@Model
final class AppStats {
    var correct: Int
    var incorrect: Int
    var streak: Int
    var bestStreak: Int
    var dailyNewWordsToday: Int       // count of new words shown today
    var dailyResetDate: Date          // date when dailyNewWordsToday was last reset
    
    // Computed
    var accuracy: Double { correct == 0 && incorrect == 0 ? 0 : Double(correct) / Double(correct + incorrect) }
}
```

---

## Implementation Steps

### 1. Create Word.swift

```swift
import SwiftData
import Foundation

@Model
final class Word {
    var id: String = UUID().uuidString
    var english: String = ""
    var vietnamese: String = ""
    var difficulty: String = "B1"
    var category: String = ""
    var correctCount: Int = 0
    var incorrectCount: Int = 0
    var nextReviewAt: Date? = nil
    var addedAt: Date = Date()
    var isMastered: Bool = false
    
    init(english: String, vietnamese: String, difficulty: String = "B1", category: String = "") {
        self.id = UUID().uuidString
        self.english = english
        self.vietnamese = vietnamese
        self.difficulty = difficulty
        self.category = category
        self.addedAt = Date()
    }
    
    var accuracy: Double {
        let total = correctCount + incorrectCount
        return total == 0 ? 0 : Double(correctCount) / Double(total)
    }
    
    var masteryLevel: MasteryLevel {
        if isMastered { return .mastered }
        if correctCount > 0 || incorrectCount > 0 { return .learning }
        return .new
    }
    
    var isDueForReview: Bool {
        guard let next = nextReviewAt else { return true }
        return Date() >= next
    }
}

enum MasteryLevel: String {
    case new = "New"
    case learning = "Learning"
    case mastered = "Mastered"
}
```

### 2. Create AppSettings.swift

```swift
import SwiftData
import Foundation

@Model
final class AppSettings {
    var intervalMinutes: Int = 10
    var intervalSeconds: Int? = nil
    var isEnabled: Bool = true
    var wordsPerDay: Int = 5
    var wordsPerPopup: Int = 2
    var answerType: String = "choice"
    var questionDirection: String = "mixed"
    var selectedDifficulties: [String] = []
    var selectedCategories: [String] = []
    var sessionTimeoutSeconds: Int? = 90
    
    // Effective interval in seconds
    var effectiveIntervalSeconds: Int {
        if let secs = intervalSeconds { return secs }
        return intervalMinutes * 60
    }
}
```

### 3. Create AppStats.swift

```swift
import SwiftData
import Foundation

@Model
final class AppStats {
    var correct: Int = 0
    var incorrect: Int = 0
    var streak: Int = 0
    var bestStreak: Int = 0
    var dailyNewWordsToday: Int = 0
    var dailyResetDate: Date = Date()
    
    var accuracy: Double {
        let total = correct + incorrect
        return total == 0 ? 0 : Double(correct) / Double(total)
    }
    
    var isNewDay: Bool {
        !Calendar.current.isDateInToday(dailyResetDate)
    }
}
```

### 4. ModelContainer Setup in AppDelegate

```swift
func setupModelContainer() {
    let schema = Schema([Word.self, AppSettings.self, AppStats.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    do {
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        seedDefaultDataIfNeeded()
    } catch {
        fatalError("Cannot create ModelContainer: \(error)")
    }
}

private func seedDefaultDataIfNeeded() {
    let context = modelContainer!.mainContext
    // Check if settings exist; if not, create defaults
    let settingsCount = (try? context.fetchCount(FetchDescriptor<AppSettings>())) ?? 0
    if settingsCount == 0 {
        context.insert(AppSettings())
        context.insert(AppStats())
        // CSVImportService will handle seed words (Phase 6)
    }
    try? context.save()
}
```

---

## Todo

- [ ] Create `Models/Word.swift` with `@Model`
- [ ] Create `Models/AppSettings.swift` with `@Model`
- [ ] Create `Models/AppStats.swift` with `@Model`
- [ ] Add `ModelContainer` setup to `AppDelegate`
- [ ] Add seed data initialization logic
- [ ] Verify models compile without errors

---

## Success Criteria

- All three `@Model` classes compile
- `ModelContainer` initializes without crash
- `AppSettings` and `AppStats` singletons created on first launch
- Xcode previews can use in-memory container for testing
