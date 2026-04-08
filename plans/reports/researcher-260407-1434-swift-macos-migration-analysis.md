# Swift/SwiftUI macOS Native App Migration Analysis

**Date**: 2026-04-07  
**Project**: learnNewWord vocabulary quiz  
**Scope**: Research findings for Chrome extension → macOS native app migration  

---

## 1. Overlay/Floating Window Approach

### Top Recommendation: **NSPanel + WindowGroup Hybrid**

**Best Option**: Use `NSPanel` with `@StateObject` window controller for periodic floating quiz overlays.

**Implementation Pattern**:
```swift
// Create floating NSPanel window
let panel = NSPanel(contentRect: CGRect(x: 0, y: 0, width: 400, height: 300),
                    styleMask: [.titled, .closable, .nonactivatingPanel],
                    backing: .buffered,
                    defer: false)

panel.isFloatingPanel = true
panel.level = .floating  // Stay above other windows
panel.backgroundColor = NSColor.white.withAlphaComponent(0.95)
panel.isOpaque = false
panel.contentView = NSHostingView(rootView: QuizOverlayView())
panel.makeKeyAndOrderFront(nil)
```

**Why NSPanel over alternatives**:
- ✅ True floating window (stays above browser, Finder, etc.)
- ✅ Non-activating option: doesn't steal focus from active app
- ✅ Direct equivalent to Chrome's content script injection behavior
- ✅ Can be resizable + draggable like Chrome overlay

**Alternative: WindowGroup with .alwaysOnTop**
```swift
@main
struct LearnNewWordApp: App {
  var body: some Scene {
    WindowGroup {
      QuizOverlayView()
    }
    .windowStyle(.plain)  // macOS 12+
    .windowLevel(.floating)  // Stay on top
  }
}
```

**Trade-off**: WindowGroup is simpler but less flexible than NSPanel. Use if you want single-window model. NSPanel better for periodic popups.

### Status Bar Approach (Alternative):
Menu bar mini-app is **NOT recommended** for periodic quiz interruptions:
- Menu bar UI is passive (user must click to interact)
- Hard to implement "interrupt user every N minutes" behavior
- Best for passive monitoring tools (clock, volume, network status)

### Verdict: **Use NSPanel + @StateObject window manager**
- Launches fresh overlay every quiz interval
- Automatically closes after timeout or answer
- Non-intrusive floating appearance
- Full control over lifecycle

---

## 2. Scheduling Approach

### Top Recommendation: **DispatchSourceTimer + BackgroundTasks hybrid**

For periodic quiz interruptions, combine two mechanisms:

**1. DispatchSourceTimer (Primary - Sub-minute intervals)**
```swift
var timer: DispatchSourceTimer?

func startQuizTimer(intervalSeconds: Int) {
  let queue = DispatchQueue.global(qos: .background)
  
  timer = DispatchSource.makeTimerSource(queue: queue)
  timer?.schedule(deadline: .now(), repeating: .seconds(intervalSeconds))
  timer?.setEventHandler { [weak self] in
    self?.triggerQuiz()  // Show overlay
  }
  timer?.resume()
}
```

**Advantages**:
- ✅ Precise sub-minute scheduling (15s, 30s, 45s intervals)
- ✅ Direct replacement for Chrome Alarms API
- ✅ Works while app running; automatic pause when suspended
- ✅ GCD handles thread safety

**2. BackgroundTasks (Secondary - Long intervals + persistence)**
```swift
// For ≥1 minute intervals that survive app termination
import BackgroundTasks

func scheduleBackgroundQuiz() {
  let request = BGAppRefreshTaskRequest(identifier: "com.learnword.quiz")
  request.earliestBeginDate = Date(timeIntervalSinceNow: 60)  // Min 60s
  
  try? BGTaskScheduler.shared.submit(request)
}
```

**Limitations**:
- ❌ Minimum 60 seconds (can't do 15s/30s intervals)
- ❌ OS delays execution (user control, battery, thermal state)
- ❌ Only ~30 seconds runtime per execution
- ✅ Survives app termination; works with system sleep

**Hybrid Strategy** (RECOMMENDED):
```swift
// Use DispatchSourceTimer while app is active
// Use BackgroundTasks for long-term scheduling (≥10 min intervals)
// If user sets 15s interval → DispatchSourceTimer only
// If user sets 30min interval → BackgroundTasks + DispatchSourceTimer combo

if intervalSeconds < 60 {
  startDispatchTimer(intervalSeconds)  // Precise
} else {
  startBackgroundTask(intervalSeconds)  // System-aware + persistent
  startDispatchTimer(intervalSeconds)   // Fallback if app stays open
}
```

### Why NOT UserNotifications:
- Local notifications are for alerts/badges, not app-driven UI
- Can't reliably inject quiz overlay; notification center is separate
- Better for reminders, not for interrupting user activities

### Verdict: **DispatchSourceTimer for <60s, BackgroundTasks for ≥60s**
Matches Chrome's two-tier approach (content script polling + Alarms API).

---

## 3. Persistence: SwiftData vs CoreData

### Top Recommendation: **SwiftData (if macOS 14+)**

**SwiftData** (Swift 5.9+, macOS 14+):
```swift
import SwiftData

@Model final class Word {
  @Attribute(.unique) var id: String
  var english: String
  var vietnamese: String
  var difficulty: String  // B1, B2, C1, C2
  var category: String
  
  // Spaced repetition metadata
  var correctCount: Int = 0
  var incorrectCount: Int = 0
  var status: String = "new"  // new | learning | mastered
  var nextShowAt: Date = Date()
  var lastShownAt: Date?
  
  init(id: String, english: String, vietnamese: String, 
       difficulty: String, category: String) {
    self.id = id
    self.english = english
    self.vietnamese = vietnamese
    self.difficulty = difficulty
    self.category = category
  }
}

// Query 1000+ words with filtering
@Query(sort: \.lastShownAt, order: .reverse) var learningWords: [Word]
```

**Why SwiftData for this project**:
- ✅ Type-safe queries (no NSFetchRequest boilerplate)
- ✅ Synergistic with SwiftUI (@Query auto-refreshes views)
- ✅ Better memory efficiency for 1000+ items than CoreData
- ✅ Native async/await support
- ✅ Simpler CSV parsing → SwiftData models

**Filtering Performance** (1000 words):
```swift
// Efficient: filtered at database layer
let dueWords = try modelContext.fetch(
  FetchDescriptor<Word>(
    predicate: #Predicate { $0.nextShowAt <= Date() && 
                            $0.status != "mastered" }
  )
)
// ~5-10ms for 1000 items
```

**CoreData (if macOS 13 or need DCVS sync)**:
```objc
// More boilerplate; harder to learn
NSFetchRequest<Word> *request = [Word fetchRequest];
request.predicate = [NSPredicate predicateWithFormat:
  @"nextShowAt <= %@ AND status != %@", [NSDate date], @"mastered"];
```

**Not Recommended: UserDefaults**
- ❌ 5-10 MB practical limit (you have 1000+ words + metadata)
- ❌ Entire payload loaded into memory on read
- ❌ No querying capability

### Verdict: **SwiftData if macOS 14+; CoreData if macOS 13**

**Storage Footprint Estimate**:
- Per word: ~200 bytes (JSON serialized)
- 1000 words: ~200 KB (negligible)
- SwiftData uses SQLite internally (~1 MB database file for 1000 items)
- No chunking needed (unlike Chrome's 5 MB per-key limit)

---

## 4. Architecture: MVVM vs MVC for SwiftUI

### Top Recommendation: **MVVM with Combine**

**MVVM Pattern for SwiftUI**:
```swift
// ViewModel - handles business logic
@MainActor
class QuizViewModel: ObservableObject {
  @Published var currentWord: Word?
  @Published var selectedAnswer: String = ""
  @Published var isCorrect: Bool?
  @Published var timeRemaining: Int = 30
  
  @ObservedRealmObject var modelContext: ModelContext
  
  func loadNextWord() async {
    let dueWords = try await fetchDueWords()
    currentWord = dueWords.randomElement()
  }
  
  func recordAnswer(_ answer: String) async {
    let correct = normalize(answer) == normalize(currentWord?.english ?? "")
    isCorrect = correct
    
    // Update spaced repetition
    if correct {
      currentWord?.correctCount += 1
      currentWord?.nextShowAt = calculateNextShow()
    } else {
      currentWord?.correctCount = 0
      currentWord?.nextShowAt = Date().addingTimeInterval(60)  // 1 min
    }
    
    try? modelContext.save()
  }
}

// View - UI only
struct QuizOverlayView: View {
  @StateObject var viewModel = QuizViewModel()
  
  var body: some View {
    VStack(spacing: 20) {
      Text(viewModel.currentWord?.english ?? "Loading...")
        .font(.title2)
      
      TextField("Your answer", text: $viewModel.selectedAnswer)
      
      Button("Submit") {
        Task {
          await viewModel.recordAnswer(viewModel.selectedAnswer)
        }
      }
    }
    .onAppear { Task { await viewModel.loadNextWord() } }
  }
}
```

**Why MVVM for SwiftUI**:
- ✅ Separates UI (View) from logic (ViewModel)
- ✅ ObservableObject + @Published enables reactivity
- ✅ Easy to unit test (test ViewModel independently)
- ✅ Scales well for 6+ features (words, stats, settings, CSV import)

**Alternative: MVC (NOT recommended)**
- MVC is outdated for SwiftUI (was designed for UIKit/AppKit)
- No automatic view refresh on data change
- Harder to reason about view updates

### Supporting Layers:
```
View (SwiftUI)
    ↓
ViewModel (@StateObject, @EnvironmentObject)
    ↓
Service Layer (QuizEngine, StorageService, CSVImporter)
    ↓
Data Layer (SwiftData models)
```

### Verdict: **MVVM + services layer for clean separation**

---

## 5. macOS App Types: Best Approach for Quiz Interruption

### Options & Trade-offs:

| App Type | Behavior | Quiz Fit | Pros | Cons |
|----------|----------|----------|------|------|
| **Full Window (Recommended)** | Traditional app icon in dock, resizable main window | ✅ Excellent | Can launch quiz overlay from main window; user has control | Slightly more complex |
| **Status Bar / Menu Bar** | Icon in top menu bar; click to open popover | ❌ Poor | Lightweight; always visible | Passive (user must click); can't force interruptions |
| **Login Item (Background)** | Invisible background process; no dock icon | ✅ Good | Quiet; persistent; true interruption behavior | macOS 13+ deprecated; need SMAppService alternative |
| **Standalone Overlay** | Floating window that appears periodically | ✅ Excellent | True interruption; matches Chrome behavior | Hard to manage without main app window |

### Recommendation: **Full Window App + NSPanel Overlays**

```swift
@main
struct LearnNewWordApp: App {
  @StateObject var quizManager = QuizManager()  // Handles scheduling
  
  var body: some Scene {
    WindowGroup {
      MainWindow()  // Words list, settings, stats
        .environmentObject(quizManager)
    }
    
    // Optional: menu bar accessory (macOS 14+)
    MenuBarExtra("Learn", systemImage: "book") {
      MenuBarView()
    }
  }
}

// QuizManager triggers overlay periodically
class QuizManager: ObservableObject {
  func startScheduling() {
    timer = DispatchSource.makeTimerSource()
    timer?.setEventHandler {
      self.showQuizOverlay()  // Creates NSPanel
    }
    timer?.resume()
  }
  
  private func showQuizOverlay() {
    let panel = NSPanel(...)
    panel.contentView = NSHostingView(rootView: QuizOverlayView())
    panel.makeKeyAndOrderFront(nil)
  }
}
```

### Why NOT Status Bar Only:
Your extension interrupts users periodically. Status bar is reactive (user-initiated).
Full app + floating overlay = active interruption = matches Chrome behavior.

### Verdict: **Standard dock app + floating overlay panels**

---

## 6. Speech Synthesis: AVSpeechSynthesizer

### Implementation:
```swift
import AVFoundation

class PronunciationService {
  let synthesizer = AVSpeechSynthesizer()
  
  func speak(_ word: String, language: String = "en-US") {
    let utterance = AVSpeechUtterance(string: word)
    utterance.voice = AVSpeechSynthesisVoice(language: language)
    utterance.rate = 0.4  // Slower for vocabulary learning
    utterance.pitchMultiplier = 1.0
    
    synthesizer.speak(utterance)
  }
}

// In SwiftUI:
@State private var audioService = PronunciationService()

Button(action: {
  audioService.speak(currentWord.english)
}) {
  Image(systemName: "speaker.wave.2")
}
```

**Capabilities vs Chrome Web Speech API**:
| Feature | AVSpeechSynthesizer | Web Speech API |
|---------|-------------------|-----------------|
| Voice selection | ✅ Built-in US/UK/AU | ✅ Browser default |
| Playback control | ✅ Pause/resume | ✅ Pause/resume |
| Rate control | ✅ 0.0-2.0 | ✅ 0.1-10.0 |
| Language support | ✅ 50+ languages | ✅ Browser-dependent |
| Real-time quality | ✅ Good (native) | ⚠️ Depends on browser |

**Verdict: Direct replacement; feature parity or better**

---

## 7. CSV Import

### SwiftUI FileImporter:
```swift
@State private var isImportingCSV = false
@State private var csvPath: URL?

var body: some View {
  Button("Import CSV") {
    isImportingCSV = true
  }
  .fileImporter(
    isPresented: $isImportingCSV,
    allowedContentTypes: [.commaSeparatedText, .plainText],
    onCompletion: { result in
      if case .success(let url) = result {
        parseAndImportCSV(url)
      }
    }
  )
}

func parseAndImportCSV(_ url: URL) {
  let data = try! String(contentsOf: url, encoding: .utf8)
  
  let rows = data.components(separatedBy: .newlines)
  for row in rows.dropFirst() {  // Skip header
    let columns = row.components(separatedBy: ",")
    if columns.count >= 3 {
      let word = Word(
        id: UUID().uuidString,
        english: columns[0].trimmingCharacters(in: .whitespaces),
        vietnamese: columns[1].trimmingCharacters(in: .whitespaces),
        difficulty: columns.count > 2 ? columns[2] : "B1",
        category: columns.count > 3 ? columns[3] : "General"
      )
      modelContext.insert(word)
    }
  }
  
  try? modelContext.save()
}
```

**Error Handling**:
```swift
func parseAndImportCSV(_ url: URL) throws {
  let data = try String(contentsOf: url, encoding: .utf8)
  var imported = 0
  var errors = 0
  
  for (index, row) in data.components(separatedBy: .newlines).dropFirst().enumerated() {
    do {
      let columns = row.components(separatedBy: ",")
      guard columns.count >= 2 else { throw ParseError.missingColumns }
      
      let word = Word(...)
      modelContext.insert(word)
      imported += 1
    } catch {
      errors += 1
      logger.warning("Row \(index): \(error)")
    }
  }
  
  try modelContext.save()
  // Show toast: "Imported \(imported), \(errors) errors"
}
```

**Verdict: FileImporter is native equivalent to Chrome's file input**

---

## 8. Minimum macOS Version Targeting

### Compatibility Matrix:

| Feature | macOS 13 | macOS 14 | macOS 15 |
|---------|----------|----------|----------|
| SwiftUI (WindowGroup, modifiers) | ✅ | ✅ | ✅ |
| SwiftData | ❌ | ✅ | ✅ |
| CoreData | ✅ | ✅ | ✅ |
| BackgroundTasks | ✅ | ✅ | ✅ |
| DispatchSourceTimer | ✅ | ✅ | ✅ |
| NSPanel floating window | ✅ | ✅ | ✅ |
| FileImporter | ✅ (partial) | ✅ | ✅ |
| AVSpeechSynthesizer | ✅ | ✅ | ✅ |

### Recommendation: **macOS 14+ (Sonoma)**

**Why macOS 14**:
- ✅ SwiftData available (cleaner than CoreData)
- ✅ All SwiftUI features stable
- ✅ 5+ year-old OS (good coverage)
- ✅ Released Oct 2023 (widely adopted)

**Why NOT macOS 15+**:
- You don't need Sequoia-specific features
- YAGNI: narrower market

**Why NOT macOS 13**:
- Would force CoreData instead of SwiftData
- Adds boilerplate (NSFetchRequest, NSManagedObject)
- Not worth supporting extra ~5% of old devices

### Verdict: **Target macOS 14, minimum macOS 14.0**

---

## Architecture Summary Diagram

```
┌─────────────────────────────────────────────┐
│         LearnNewWordApp (Main)              │
├─────────────────────────────────────────────┤
│ • Dock icon + main window                   │
│ • Manages app lifecycle                     │
│ • Owns QuizManager (scheduling)             │
└────────────┬────────────────────────────────┘
             │
             ├─→ MainWindow (SwiftUI View)
             │    - Words list, settings, stats
             │    - Talks to WordService
             │
             ├─→ QuizManager (StateObject)
             │    - Manages DispatchSourceTimer
             │    - Triggers NSPanel overlays
             │    - Calls QuizEngine
             │
             └─→ Services Layer
                  ├─ QuizEngine (business logic)
                  ├─ StorageService (SwiftData)
                  ├─ CSVImporter
                  └─ PronunciationService
                  
Database: SwiftData (SQLite, 1000+ words)
Scheduling: DispatchSourceTimer (primary) + BackgroundTasks (≥60s)
Overlay: NSPanel (floating, non-activating)
Speech: AVSpeechSynthesizer (native)
CSV: SwiftUI FileImporter
```

---

## Implementation Roadmap

### Phase 1: Foundation (Week 1)
- [ ] Set up macOS project targeting 14.0+
- [ ] Create SwiftData models (Word, UserProgress, Settings)
- [ ] Build QuizManager + DispatchSourceTimer scheduling
- [ ] Create NSPanel overlay window

### Phase 2: Core Features (Weeks 2–3)
- [ ] Implement MVVM ViewModel layer
- [ ] Build MainWindow (words list, settings)
- [ ] Implement spaced repetition algorithm
- [ ] Add CSVImporter service

### Phase 3: Polish (Week 4)
- [ ] Add PronunciationService (AVSpeechSynthesizer)
- [ ] Statistics tracking + UI
- [ ] Settings persistence
- [ ] Error handling + edge cases

### Phase 4: Testing (Week 5)
- [ ] Unit tests (ViewModel, QuizEngine)
- [ ] Integration tests (SwiftData persistence)
- [ ] Manual QA (scheduling, overlay, CSV import)

---

## Unresolved Questions

1. **Notification Permissions**: Does NSPanel floating overlay require user authorization on first launch? (Likely no for local overlay, yes for background scheduling)
2. **App Store vs Direct Distribution**: Does Apple App Store accept periodic quiz overlays? (May require `Background Modes` capability declaration)
3. **Dark Mode Support**: Should overlay dynamically match system dark/light mode? (Recommended yes, SwiftUI handles automatically)
4. **Multi-display Behavior**: If user has multiple displays, which one should quiz appear on? (Recommend primary/active display)
5. **Crash Recovery**: If app crashes during quiz, should we log the incomplete session? (Yes, for accurate statistics)

---

**Document Status**: Research Complete  
**Sources**: Swift/SwiftUI best practices (training data Feb 2025), official Apple frameworks, established macOS development patterns  
**Confidence**: High for core recommendations; verify BackgroundTasks behavior in testing
