# Phase 5: Main UI (Menu Bar + Management)

**Status**: Pending  
**Priority**: P1  
**Effort**: Large (3-4 days)  
**Depends on**: Phase 2

---

## Context Links
- [Plan Overview](plan.md)
- [popup.html](../../popup.html) — 4-tab layout reference
- [popup.js](../../popup.js) — word list, stats, settings logic
- [popup.css](../../popup.css) — visual design reference

---

## Overview

Replace the Chrome popup (popup.html/js/css) with a native NSPopover attached to a menu bar status item. Contains 4 tabs matching the extension: Words, All Words, Stats, Settings.

---

## Architecture

```
NSStatusItem (menu bar icon + click)
    → NSPopover
        → MenuBarPopoverView (SwiftUI root)
            ├── Tab: WordsListView      (today's words + search)
            ├── Tab: AllWordsView       (full list, CRUD)
            ├── Tab: StatsView          (accuracy, streak, mastery)
            └── Tab: SettingsView       (all settings)
```

---

## Implementation Steps

### 1. Menu Bar Setup in AppDelegate

```swift
func setupMenuBar() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    if let button = statusItem?.button {
        button.image = NSImage(systemSymbolName: "book.fill", accessibilityDescription: "Learn New Words")
        button.action = #selector(togglePopover)
        button.target = self
    }

    popover = NSPopover()
    popover?.contentSize = NSSize(width: 380, height: 520)
    popover?.behavior = .transient  // closes when clicking outside

    let context = modelContainer!.mainContext
    popover?.contentViewController = NSHostingController(
        rootView: MenuBarPopoverView()
            .modelContainer(modelContainer!)
    )
}

@objc func togglePopover() {
    guard let button = statusItem?.button else { return }
    if popover?.isShown == true {
        popover?.performClose(nil)
    } else {
        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
}
```

### 2. MenuBarPopoverView.swift

```swift
import SwiftUI

struct MenuBarPopoverView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("", selection: $selectedTab) {
                Text("Words").tag(0)
                Text("All Words").tag(1)
                Text("Stats").tag(2)
                Text("Settings").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(10)

            Divider()

            // Tab content
            Group {
                switch selectedTab {
                case 0: WordsListView()
                case 1: AllWordsView()
                case 2: StatsView()
                case 3: SettingsView()
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 380, height: 520)
    }
}
```

### 3. WordsListView.swift (Today's words tab)

```swift
import SwiftUI
import SwiftData

struct WordsListView: View {
    @Query(sort: \Word.addedAt, order: .reverse) private var words: [Word]
    @Query private var stats: [AppStats]
    @State private var searchText = ""

    private var todayWords: [Word] {
        let filtered = searchText.isEmpty ? words : words.filter {
            $0.english.localizedCaseInsensitiveContains(searchText) ||
            $0.vietnamese.localizedCaseInsensitiveContains(searchText)
        }
        // Show words due for review or recently added
        return Array(filtered.filter { !$0.isMastered }.prefix(20))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Daily progress
            if let stat = stats.first {
                HStack {
                    Text("Today: \(stat.dailyNewWordsToday) new words")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("Streak: \(stat.streak) 🔥")
                        .font(.caption).foregroundStyle(.orange)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                Divider()
            }

            // Search
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search…", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            .padding(10)

            // List
            List(todayWords, id: \.id) { word in
                WordRowView(word: word)
            }
            .listStyle(.plain)
        }
    }
}
```

### 4. AllWordsView.swift (Full word management)

```swift
import SwiftUI
import SwiftData

struct AllWordsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Word.english) private var words: [Word]
    @State private var searchText = ""
    @State private var showAddSheet = false
    @State private var showImportSheet = false
    @State private var filterDifficulty = ""

    private var filtered: [Word] {
        var result = words
        if !searchText.isEmpty {
            result = result.filter {
                $0.english.localizedCaseInsensitiveContains(searchText) ||
                $0.vietnamese.localizedCaseInsensitiveContains(searchText)
            }
        }
        if !filterDifficulty.isEmpty {
            result = result.filter { $0.difficulty == filterDifficulty }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                TextField("Search…", text: $searchText).textFieldStyle(.roundedBorder)
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                }
                Button(action: { showImportSheet = true }) {
                    Image(systemName: "square.and.arrow.down")
                }
            }
            .padding(10)

            // Difficulty filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(["", "B1", "B2", "C1", "C2"], id: \.self) { diff in
                        Text(diff.isEmpty ? "All" : diff)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(filterDifficulty == diff ? Color.accentColor : Color.secondary.opacity(0.15))
                            .foregroundStyle(filterDifficulty == diff ? .white : .primary)
                            .cornerRadius(12)
                            .onTapGesture { filterDifficulty = diff }
                    }
                }
                .padding(.horizontal, 10)
            }

            Divider()

            List {
                ForEach(filtered, id: \.id) { word in
                    WordRowView(word: word, showActions: true)
                }
                .onDelete { indices in
                    indices.map { filtered[$0] }.forEach { context.delete($0) }
                    try? context.save()
                }
            }
            .listStyle(.plain)

            // Footer count
            Text("\(filtered.count) / \(words.count) words")
                .font(.caption).foregroundStyle(.secondary).padding(6)
        }
        .sheet(isPresented: $showAddSheet) { AddWordView() }
        .fileImporter(
            isPresented: $showImportSheet,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            // Handled in Phase 6 — CSVImportService
            if case .success(let urls) = result, let url = urls.first {
                CSVImportService.importFrom(url: url, context: context)
            }
        }
    }
}
```

### 5. WordRowView.swift

```swift
import SwiftUI

struct WordRowView: View {
    let word: Word
    var showActions: Bool = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(word.english).font(.body).bold()
                Text(word.vietnamese).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(word.difficulty)
                    .font(.caption2)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(difficultyColor(word.difficulty).opacity(0.2))
                    .cornerRadius(4)
                Text(word.masteryLevel.rawValue)
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func difficultyColor(_ d: String) -> Color {
        switch d {
        case "B1": return .green
        case "B2": return .blue
        case "C1": return .orange
        case "C2": return .red
        default: return .gray
        }
    }
}
```

### 6. StatsView.swift

```swift
import SwiftUI
import SwiftData

struct StatsView: View {
    @Query private var stats: [AppStats]
    @Query private var words: [Word]

    private var stat: AppStats? { stats.first }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Accuracy ring (simple text for now)
                VStack {
                    Text("\(Int((stat?.accuracy ?? 0) * 100))%")
                        .font(.system(size: 48, weight: .bold))
                    Text("Accuracy").foregroundStyle(.secondary)
                }
                .padding(.top, 20)

                Divider()

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(title: "Correct", value: "\(stat?.correct ?? 0)", color: .green)
                    StatCard(title: "Incorrect", value: "\(stat?.incorrect ?? 0)", color: .red)
                    StatCard(title: "Streak", value: "\(stat?.streak ?? 0) 🔥", color: .orange)
                    StatCard(title: "Best Streak", value: "\(stat?.bestStreak ?? 0)", color: .purple)
                }

                Divider()

                // Mastery breakdown
                let mastered = words.filter { $0.isMastered }.count
                let learning = words.filter { !$0.isMastered && ($0.correctCount > 0 || $0.incorrectCount > 0) }.count
                let newWords = words.filter { $0.correctCount == 0 && $0.incorrectCount == 0 }.count

                VStack(alignment: .leading, spacing: 8) {
                    Text("Word Status").font(.headline)
                    MasteryBar(label: "Mastered", count: mastered, total: words.count, color: .green)
                    MasteryBar(label: "Learning", count: learning, total: words.count, color: .blue)
                    MasteryBar(label: "New", count: newWords, total: words.count, color: .gray)
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }
}

struct StatCard: View {
    let title: String; let value: String; let color: Color
    var body: some View {
        VStack {
            Text(value).font(.title2).bold().foregroundStyle(color)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(12)
        .background(color.opacity(0.1)).cornerRadius(10)
    }
}

struct MasteryBar: View {
    let label: String; let count: Int; let total: Int; let color: Color
    var body: some View {
        HStack {
            Text(label).frame(width: 70, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4).fill(color)
                        .frame(width: total > 0 ? geo.size.width * CGFloat(count) / CGFloat(total) : 0)
                }
            }.frame(height: 12)
            Text("\(count)").frame(width: 35, alignment: .trailing).font(.caption)
        }
    }
}
```

### 7. SettingsView.swift

```swift
import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsQuery: [AppSettings]
    private var settings: AppSettings? { settingsQuery.first }

    var body: some View {
        Form {
            if let s = settings {
                Section("Quiz") {
                    Toggle("Enable Learning", isOn: Binding(
                        get: { s.isEnabled },
                        set: { s.isEnabled = $0; save() }
                    ))

                    Picker("Interval", selection: Binding(
                        get: { s.intervalMinutes },
                        set: { s.intervalMinutes = $0; s.intervalSeconds = nil; save(); reschedule() }
                    )) {
                        Text("1 min").tag(1)
                        Text("5 min").tag(5)
                        Text("10 min").tag(10)
                        Text("15 min").tag(15)
                        Text("30 min").tag(30)
                        Text("60 min").tag(60)
                    }

                    Stepper("Words per session: \(s.wordsPerPopup)", value: Binding(
                        get: { s.wordsPerPopup },
                        set: { s.wordsPerPopup = $0; save() }
                    ), in: 1...5)
                }

                Section("Answer Style") {
                    Picker("Answer Type", selection: Binding(
                        get: { s.answerType },
                        set: { s.answerType = $0; save() }
                    )) {
                        Text("Multiple Choice").tag("choice")
                        Text("Typing").tag("typing")
                        Text("Mixed").tag("mixed")
                    }

                    Picker("Direction", selection: Binding(
                        get: { s.questionDirection },
                        set: { s.questionDirection = $0; save() }
                    )) {
                        Text("EN → VN").tag("en-to-vn")
                        Text("VN → EN").tag("vn-to-en")
                        Text("Mixed").tag("mixed")
                    }
                }

                Section("Daily Quota") {
                    Stepper("New words/day: \(s.wordsPerDay)", value: Binding(
                        get: { s.wordsPerDay },
                        set: { s.wordsPerDay = $0; save() }
                    ), in: 1...20)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func save() { try? context.save() }

    private func reschedule() {
        guard let s = settings else { return }
        QuizScheduler.shared.updateInterval(s.effectiveIntervalSeconds)
    }
}
```

### 8. AddWordView.swift (sheet for adding words)

```swift
import SwiftUI
import SwiftData

struct AddWordView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var english = ""
    @State private var vietnamese = ""
    @State private var difficulty = "B1"
    @State private var category = ""

    var body: some View {
        Form {
            TextField("English", text: $english)
            TextField("Vietnamese", text: $vietnamese)
            Picker("Difficulty", selection: $difficulty) {
                ForEach(["B1","B2","C1","C2"], id: \.self) { Text($0).tag($0) }
            }
            TextField("Category (optional)", text: $category)
        }
        .formStyle(.grouped)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    let word = Word(english: english, vietnamese: vietnamese, difficulty: difficulty, category: category)
                    context.insert(word)
                    try? context.save()
                    dismiss()
                }
                .disabled(english.isEmpty || vietnamese.isEmpty)
            }
        }
        .frame(width: 300, height: 260)
    }
}
```

---

## Todo

- [ ] Create `App/AppDelegate.swift` with menu bar setup
- [ ] Create `Views/Management/MenuBarPopoverView.swift`
- [ ] Create `Views/Management/WordsListView.swift`
- [ ] Create `Views/Management/AllWordsView.swift`
- [ ] Create `Views/Components/WordRowView.swift`
- [ ] Create `Views/Management/StatsView.swift`
- [ ] Create `Views/Management/SettingsView.swift`
- [ ] Create `Views/Management/AddWordView.swift`
- [ ] Test: clicking menu bar icon opens popover
- [ ] Test: tab switching works correctly
- [ ] Test: word add/delete persists

---

## Success Criteria

- Menu bar icon visible (no Dock icon)
- Clicking icon opens 380×520 popover
- All 4 tabs render without crash
- Word CRUD operations persist to SwiftData
- Settings changes immediately reflected
- Stats show accurate counts
