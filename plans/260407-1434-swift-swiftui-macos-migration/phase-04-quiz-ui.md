# Phase 4: Quiz UI (Floating Window)

**Status**: Pending  
**Priority**: P0  
**Effort**: Large (3-4 days)  
**Depends on**: Phase 3

---

## Context Links
- [Plan Overview](plan.md)
- [content.js](../../content.js) — overlay rendering, quiz lifecycle, countdown timer
- [popup.css](../../popup.css) — quiz styles reference

---

## Overview

Replace the Shadow DOM quiz overlay (content.js) with a native floating `NSPanel` that appears on top of all windows periodically. Implements multiple choice (2×2 grid) and typing answer modes with animated countdown timer.

---

## Architecture

```
QuizScheduler.onTrigger
    → AppDelegate.showQuizWindow()
        → QuizWindowController.show(session: [QuizItem])
            → QuizView (SwiftUI)
                ├── QuizProgressBar (countdown timer)
                ├── MultipleChoiceView  OR  TypingAnswerView
                └── on answer → SpacedRepetitionEngine.recordAnswer()
```

---

## Implementation Steps

### 1. QuizWindowController.swift

```swift
import AppKit
import SwiftUI
import SwiftData

/// Manages the floating NSPanel quiz window
@MainActor
class QuizWindowController {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<AnyView>?

    func show(session: [QuizItem], context: ModelContext, stats: AppStats) {
        guard !session.isEmpty else { return }
        close()

        let quizView = QuizView(
            session: session,
            context: context,
            stats: stats,
            onComplete: { [weak self] in self?.close() }
        )

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 340),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Learn New Words"
        panel.level = .floating            // Always on top
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.center()

        let hosting = NSHostingView(rootView: quizView)
        panel.contentView = hosting

        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
        self.hostingView = hosting
    }

    func close() {
        panel?.close()
        panel = nil
    }
}
```

### 2. QuizView.swift

```swift
import SwiftUI
import SwiftData

struct QuizView: View {
    let session: [QuizItem]
    let context: ModelContext
    let stats: AppStats
    let onComplete: () -> Void

    @State private var currentIndex = 0
    @State private var showFeedback = false
    @State private var lastCorrect = false

    var currentItem: QuizItem { session[currentIndex] }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("\(currentIndex + 1) / \(session.count)")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(action: onComplete) {
                    Image(systemName: "xmark").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Question
            VStack(spacing: 8) {
                Text(currentItem.direction == .enToVn ? currentItem.word.english : currentItem.word.vietnamese)
                    .font(.title2).bold().multilineTextAlignment(.center)
                Text(currentItem.direction == .enToVn ? "→ Vietnamese?" : "→ English?")
                    .font(.caption).foregroundStyle(.secondary)
            }

            // Countdown timer
            if let timeout = appSettings?.sessionTimeoutSeconds {
                QuizProgressBarView(totalSeconds: timeout, onExpire: { advance(correct: false) })
            }

            // Answer area
            if currentItem.answerMode == .choice {
                MultipleChoiceView(item: currentItem, onAnswer: advance)
            } else {
                TypingAnswerView(item: currentItem, onAnswer: advance)
            }

            // Feedback
            if showFeedback {
                Text(lastCorrect ? "✓ Correct!" : "✗ Wrong")
                    .foregroundStyle(lastCorrect ? .green : .red)
                    .font(.headline)
            }
        }
        .padding(20)
        .frame(width: 440, height: 340)
    }

    private func advance(correct: Bool) {
        SpacedRepetitionEngine.recordAnswer(word: currentItem.word, correct: correct, stats: stats, context: context)
        lastCorrect = correct
        showFeedback = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showFeedback = false
            if currentIndex + 1 < session.count {
                currentIndex += 1
            } else {
                onComplete()
            }
        }
    }

    @Query private var settingsQuery: [AppSettings]
    private var appSettings: AppSettings? { settingsQuery.first }
}
```

### 3. MultipleChoiceView.swift

```swift
import SwiftUI

struct MultipleChoiceView: View {
    let item: QuizItem
    let onAnswer: (Bool) -> Void

    @State private var selected: String? = nil

    // Correct answer + 3 distractors, shuffled once
    private var options: [String] {
        let correct = item.direction == .enToVn ? item.word.vietnamese : item.word.english
        return ([correct] + item.distractors).shuffled()
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(options, id: \.self) { option in
                Button(action: { pick(option) }) {
                    Text(option)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .multilineTextAlignment(.center)
                        .padding(8)
                        .background(backgroundColor(for: option))
                        .cornerRadius(8)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .disabled(selected != nil)
            }
        }
    }

    private func pick(_ option: String) {
        selected = option
        let correct = item.direction == .enToVn ? item.word.vietnamese : item.word.english
        onAnswer(option == correct)
    }

    private func backgroundColor(for option: String) -> Color {
        guard let sel = selected else { return Color.secondary.opacity(0.15) }
        let correct = item.direction == .enToVn ? item.word.vietnamese : item.word.english
        if option == correct { return .green.opacity(0.3) }
        if option == sel { return .red.opacity(0.3) }
        return Color.secondary.opacity(0.1)
    }
}
```

### 4. TypingAnswerView.swift

```swift
import SwiftUI

struct TypingAnswerView: View {
    let item: QuizItem
    let onAnswer: (Bool) -> Void

    @State private var input = ""
    @State private var submitted = false
    @FocusState private var focused: Bool

    var correctAnswer: String {
        item.direction == .enToVn ? item.word.vietnamese : item.word.english
    }

    var body: some View {
        VStack(spacing: 12) {
            TextField("Type your answer…", text: $input)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .disabled(submitted)
                .onSubmit(submit)

            Button("Check", action: submit)
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || submitted)
                .keyboardShortcut(.return)

            if submitted {
                Text("Answer: \(correctAnswer)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .onAppear { focused = true }
    }

    private func submit() {
        guard !submitted else { return }
        submitted = true
        let isCorrect = input.trimmingCharacters(in: .whitespaces)
            .lowercased() == correctAnswer.lowercased()
        onAnswer(isCorrect)
    }
}
```

### 5. QuizProgressBarView.swift

```swift
import SwiftUI

struct QuizProgressBarView: View {
    let totalSeconds: Int
    let onExpire: () -> Void

    @State private var remaining: Double = 1.0  // 1.0 = full
    @State private var timer: Timer?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.2))
                RoundedRectangle(cornerRadius: 3)
                    .fill(remaining > 0.3 ? Color.accentColor : .red)
                    .frame(width: geo.size.width * remaining)
                    .animation(.linear(duration: 1), value: remaining)
            }
        }
        .frame(height: 6)
        .onAppear { startCountdown() }
        .onDisappear { timer?.invalidate() }
    }

    private func startCountdown() {
        remaining = 1.0
        var elapsed = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            elapsed += 1
            remaining = max(0, 1.0 - Double(elapsed) / Double(totalSeconds))
            if elapsed >= totalSeconds {
                t.invalidate()
                onExpire()
            }
        }
    }
}
```

### 6. Wire in AppDelegate

```swift
// AppDelegate.swift additions
var quizWindowController = QuizWindowController()

func triggerQuiz() {
    let context = modelContainer!.mainContext
    guard let settings = try? context.fetch(FetchDescriptor<AppSettings>()).first,
          settings.isEnabled else { return }
    guard let stats = try? context.fetch(FetchDescriptor<AppStats>()).first else { return }
    let words = (try? context.fetch(FetchDescriptor<Word>())) ?? []
    let eligible = SpacedRepetitionEngine.eligibleWords(from: words, settings: settings, stats: stats)
    let session = QuizSessionBuilder.buildSession(from: eligible, allWords: words, settings: settings)
    guard !session.isEmpty else { return }

    // Update new-word count
    let newShown = session.filter { $0.word.correctCount == 0 && $0.word.incorrectCount == 0 }
    stats.dailyNewWordsToday += newShown.count
    try? context.save()

    quizWindowController.show(session: session, context: context, stats: stats)
}
```

---

## Todo

- [ ] Create `Views/Quiz/QuizWindowController.swift`
- [ ] Create `Views/Quiz/QuizView.swift`
- [ ] Create `Views/Quiz/MultipleChoiceView.swift`
- [ ] Create `Views/Quiz/TypingAnswerView.swift`
- [ ] Create `Views/Components/QuizProgressBarView.swift`
- [ ] Wire `QuizScheduler.onTrigger → AppDelegate.triggerQuiz()`
- [ ] Wire `SpeechService.speak(word.english)` on quiz display (Phase 6)
- [ ] Test: quiz window appears above all other windows
- [ ] Test: 2×2 grid color feedback correct/wrong
- [ ] Test: timeout fires `onExpire`

---

## Success Criteria

- Floating window appears on top of all apps at scheduled interval
- Multiple choice shows 4 options in 2×2 grid; green/red feedback
- Typing mode accepts Enter key to submit
- Countdown bar animates to zero, then auto-dismisses
- Answer recorded correctly in SwiftData

---

## Security Notes

- No network calls in quiz
- Input is compared locally, never transmitted
