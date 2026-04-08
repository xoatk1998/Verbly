# Phase 6: Feature Completion (CSV, Speech, Seed Data)

**Status**: Pending  
**Priority**: P1  
**Effort**: Medium (2 days)  
**Depends on**: Phase 5 (AllWordsView fileImporter hook)

---

## Context Links
- [Plan Overview](plan.md)
- [background.js:parseCSVRow, loadSeedWords](../../background.js) — CSV parsing logic
- [sample.csv](../../sample.csv) — seed vocabulary

---

## Overview

Three self-contained services: CSV import (replaces `IMPORT_WORDS_CSV` message handler), speech synthesis (replaces Web Speech API), and seed data loading on first launch.

---

## Implementation Steps

### 1. CSVImportService.swift

Port `parseCSVRow()` and `loadSeedWords()` from background.js.

CSV format: `english,vietnamese,difficulty,category` (same as existing sample.csv)

```swift
import Foundation
import SwiftData

enum CSVImportService {
    struct ImportResult {
        let imported: Int
        let skipped: Int
        let errors: [String]
    }

    /// Import words from a user-selected CSV file URL
    @discardableResult
    static func importFrom(url: URL, context: ModelContext) -> ImportResult {
        guard url.startAccessingSecurityScopedResource() else {
            return ImportResult(imported: 0, skipped: 0, errors: ["Permission denied"])
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return ImportResult(imported: 0, skipped: 0, errors: ["Cannot read file"])
        }

        return parseAndInsert(csvContent: content, context: context)
    }

    /// Load seed words from bundled sample.csv
    static func loadSeedWords(context: ModelContext) {
        guard let url = Bundle.main.url(forResource: "sample", withExtension: "csv") else { return }
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        parseAndInsert(csvContent: content, context: context)
    }

    @discardableResult
    private static func parseAndInsert(csvContent: String, context: ModelContext) -> ImportResult {
        let existingEnglish = (try? context.fetch(FetchDescriptor<Word>()))?.map { $0.english.lowercased() } ?? []
        let existingSet = Set(existingEnglish)

        var lines = csvContent.components(separatedBy: "\n")
        // Skip header row if present
        if let first = lines.first, first.lowercased().contains("english") {
            lines.removeFirst()
        }

        var imported = 0
        var skipped = 0
        var errors: [String] = []

        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            guard let fields = parseCSVRow(trimmed), fields.count >= 2 else {
                errors.append("Line \(i + 1): invalid format")
                continue
            }

            let english = fields[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let vietnamese = fields[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let difficulty = fields.count > 2 ? fields[2].trimmingCharacters(in: .whitespacesAndNewlines) : "B1"
            let category = fields.count > 3 ? fields[3].trimmingCharacters(in: .whitespacesAndNewlines) : ""

            guard !english.isEmpty, !vietnamese.isEmpty else {
                errors.append("Line \(i + 1): empty english or vietnamese")
                continue
            }

            // Skip duplicates
            if existingSet.contains(english.lowercased()) {
                skipped += 1
                continue
            }

            let validDifficulties = ["B1", "B2", "C1", "C2"]
            let finalDifficulty = validDifficulties.contains(difficulty) ? difficulty : "B1"

            let word = Word(english: english, vietnamese: vietnamese, difficulty: finalDifficulty, category: category)
            context.insert(word)
            imported += 1
        }

        try? context.save()
        return ImportResult(imported: imported, skipped: skipped, errors: errors)
    }

    /// Port of background.js parseCSVRow — handles quoted fields with commas inside
    private static func parseCSVRow(_ line: String) -> [String]? {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var chars = line.unicodeScalars.makeIterator()

        while let ch = chars.next() {
            switch ch {
            case "\"":
                inQuotes.toggle()
            case ",":
                if inQuotes {
                    current.append(Character(ch))
                } else {
                    fields.append(current)
                    current = ""
                }
            default:
                current.append(Character(ch))
            }
        }
        fields.append(current)
        return fields.count >= 2 ? fields : nil
    }
}
```

### 2. SpeechService.swift

Replace Web Speech API (`speechSynthesis.speak()`).

```swift
import AVFoundation

final class SpeechService {
    static let shared = SpeechService()
    private let synthesizer = AVSpeechSynthesizer()

    /// Speak English word aloud (called when quiz displays)
    func speak(_ text: String, language: String = "en-US") {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = 0.45       // slightly slower than default for clarity
        utterance.volume = 0.9
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
```

Wire into `QuizView.swift` — add `.onAppear` to speak the English word:

```swift
// In QuizView, add to body:
.onAppear {
    if currentItem.direction == .enToVn {
        SpeechService.shared.speak(currentItem.word.english)
    }
}
.onChange(of: currentIndex) { _, _ in
    if currentItem.direction == .enToVn {
        SpeechService.shared.speak(currentItem.word.english)
    }
}
```

### 3. Seed Data on First Launch

Wire `CSVImportService.loadSeedWords()` into `AppDelegate.seedDefaultDataIfNeeded()`:

```swift
// In AppDelegate.seedDefaultDataIfNeeded(), after inserting AppSettings/AppStats:
let wordCount = (try? context.fetchCount(FetchDescriptor<Word>())) ?? 0
if wordCount == 0 {
    CSVImportService.loadSeedWords(context: context)
}
```

### 4. Import Result Feedback in AllWordsView

Show a toast/alert after CSV import completes:

```swift
// In AllWordsView, add state:
@State private var importResult: CSVImportService.ImportResult?
@State private var showImportResult = false

// In fileImporter completion:
let result = CSVImportService.importFrom(url: url, context: context)
importResult = result
showImportResult = true

// Add alert:
.alert("Import Complete", isPresented: $showImportResult) {
    Button("OK") {}
} message: {
    if let r = importResult {
        Text("Imported: \(r.imported)\nSkipped: \(r.skipped)\nErrors: \(r.errors.count)")
    }
}
```

---

## Todo

- [ ] Create `Services/CSVImportService.swift`
- [ ] Create `Services/SpeechService.swift`
- [ ] Wire `CSVImportService.loadSeedWords()` in AppDelegate first-launch check
- [ ] Wire `SpeechService.shared.speak()` in QuizView `.onAppear` / `.onChange`
- [ ] Wire import result alert in `AllWordsView`
- [ ] Test: import sample.csv populates words correctly
- [ ] Test: duplicate detection skips existing words
- [ ] Test: speech plays English word on quiz display
- [ ] Test: quoted CSV fields with commas parsed correctly

---

## Success Criteria

- First launch: ~100 seed words loaded from sample.csv
- CSV import: valid rows added, duplicates skipped, errors reported
- English word spoken aloud when EN→VN quiz appears
- Import result alert shows correct counts
