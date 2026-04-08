# Swift/SwiftUI macOS Migration Plan

**Status**: Pending  
**Created**: 2026-04-07  
**Goal**: Migrate Learn New Words Chrome Extension → Native macOS app (Swift + SwiftUI)

---

## Overview

Migrate a Manifest V3 Chrome extension (~3,100 LOC, vanilla JS) to a native macOS app using Swift 5.9+ and SwiftUI. The app should preserve all existing features while leveraging native macOS capabilities.

**App type**: Menu bar app with floating quiz window (closest equivalent to Chrome overlay injection)

---

## Architecture Decision

| Concern | Chrome Extension | macOS Native |
|---------|-----------------|--------------|
| Persistence | `chrome.storage.local` | SwiftData (macOS 14+) |
| Scheduling | Chrome Alarms API | `Timer` (in-process) + `UserNotifications` |
| Quiz display | Shadow DOM overlay | Floating `NSPanel` (always-on-top window) |
| Popup UI | Popup HTML/CSS/JS | SwiftUI in `NSPopover` from menu bar |
| Background | Service Worker | `@MainActor` App + background `Task` |
| Speech | Web Speech API | `AVSpeechSynthesizer` |
| CSV import | `FileReader` API | `FileImporter` SwiftUI view modifier |

**Minimum target**: macOS 14 Sonoma (SwiftData requires it)

---

## Phases

| # | Phase | Status | Effort |
|---|-------|--------|--------|
| 1 | [Project Setup](phase-01-project-setup.md) | Pending | Small |
| 2 | [Data Models & SwiftData](phase-02-data-models.md) | Pending | Medium |
| 3 | [Core Engine (Spaced Repetition + Scheduling)](phase-03-core-engine.md) | Pending | Medium |
| 4 | [Quiz UI (Floating Window)](phase-04-quiz-ui.md) | Pending | Large |
| 5 | [Main UI (Menu Bar + Management)](phase-05-main-ui.md) | Pending | Large |
| 6 | [Feature Completion (CSV, Speech, Stats)](phase-06-features.md) | Pending | Medium |
| 7 | [Testing & Polish](phase-07-testing.md) | Pending | Medium |

---

## Key Dependencies

- Phase 2 (Data) must complete before Phase 3 (Engine)
- Phase 3 must complete before Phase 4 (Quiz UI uses engine)
- Phases 4 and 5 can run in parallel after Phase 3
- Phase 6 can run after Phase 5 shell is complete
- Phase 7 is last

---

## File Structure (Target)

```
LearnNewWords/               ← Xcode project root
├── LearnNewWords.xcodeproj
├── LearnNewWords/
│   ├── App/
│   │   ├── LearnNewWordsApp.swift       ← @main entry, menu bar setup
│   │   └── AppDelegate.swift           ← NSApplicationDelegate (optional)
│   ├── Models/
│   │   ├── Word.swift                  ← SwiftData @Model
│   │   ├── AppSettings.swift           ← SwiftData @Model for settings
│   │   └── AppStats.swift              ← SwiftData @Model for stats
│   ├── Engine/
│   │   ├── SpacedRepetitionEngine.swift ← Fibonacci scheduler logic
│   │   ├── QuizSessionBuilder.swift    ← Builds quiz sessions
│   │   └── QuizScheduler.swift         ← Timer-based scheduling
│   ├── Views/
│   │   ├── Quiz/
│   │   │   ├── QuizWindowController.swift  ← NSPanel management
│   │   │   ├── QuizView.swift              ← Main quiz SwiftUI view
│   │   │   ├── MultipleChoiceView.swift    ← 2×2 choice grid
│   │   │   └── TypingAnswerView.swift      ← Text field answer
│   │   ├── Management/
│   │   │   ├── MenuBarPopoverView.swift    ← Root popover (4 tabs)
│   │   │   ├── WordsListView.swift         ← Word management tab
│   │   │   ├── StatsView.swift             ← Statistics tab
│   │   │   └── SettingsView.swift          ← Settings tab
│   │   └── Components/
│   │       ├── ProgressBarView.swift       ← Countdown timer bar
│   │       └── WordRowView.swift           ← Word list row
│   ├── Services/
│   │   ├── CSVImportService.swift      ← CSV parsing & import
│   │   └── SpeechService.swift         ← AVSpeechSynthesizer wrapper
│   └── Resources/
│       └── sample.csv                  ← Seed vocabulary data
└── LearnNewWordsTests/
    └── SpacedRepetitionTests.swift     ← Unit tests for engine
```

---

## Out of Scope

- Web page injection (not possible in native app without Safari Extension)
- Chrome-to-macOS data migration (start fresh; user can re-import CSV)
- Windows/iOS support (macOS only)
