# System Architecture

## High-Level Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         USER BROWSER                                     │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌─────────────────┐         ┌──────────────────┐                       │
│  │  Web Page       │         │  Chrome Popup    │                       │
│  │  (HTTP/HTTPS)   │         │  (380px panel)   │                       │
│  │                 │         │                  │                       │
│  │ ┌─────────────┐ │         │  ┌────────────┐  │                       │
│  │ │ Shadow DOM  │ │         │  │ 4 Tabs:    │  │                       │
│  │ │ Quiz        │ │         │  │ - Words    │  │                       │
│  │ │ Overlay     │ │         │  │ - All Word │  │                       │
│  │ └─────────────┘ │         │  │ - Stats    │  │                       │
│  │  (injected by   │         │  │ - Settings │  │                       │
│  │  content.js)    │         │  └────────────┘  │                       │
│  └─────────────────┘         └──────────────────┘                       │
│         ↓                              ↓                                 │
│    content.js                      popup.js                             │
│  (Content Script)              (Popup Script)                           │
│                                                                           │
│    ┌──────────────────────────────────────────────────────────┐         │
│    │  chrome.runtime.sendMessage()                            │         │
│    │  (15 message types)                                      │         │
│    └───────────────────────────┬──────────────────────────────┘         │
│                                ↓                                         │
│                        ┌─────────────────┐                              │
│                        │ background.js   │                              │
│                        │ (Service Worker)│                              │
│                        │                 │                              │
│                        │ - Quiz engine   │                              │
│                        │ - Scheduling    │                              │
│                        │ - Statistics    │                              │
│                        └────────┬────────┘                              │
│                                 ↓                                        │
│                    ┌────────────────────────┐                           │
│                    │ chrome.storage.local   │                           │
│                    │ (Persistent data)      │                           │
│                    └────────────────────────┘                           │
│                                                                           │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Component Descriptions

### 1. Content Script (content.js)

**Role**: Bridge between web pages and extension service worker. Injects quiz overlay.

**Key Responsibilities**:
- Monitor quiz trigger signals (via polling for sub-minute intervals)
- Render quiz overlay using Shadow DOM
- Capture user answers and send to background
- Manage countdown timer and quiz lifecycle
- Fallback to fullscreen quiz when needed

**Lifecycle**:
```
1. Inject into web page (runs at document_idle)
   ↓
2. Setup polling if intervalSeconds > 0
   ↓
3. Every 1000ms: check if time elapsed ≥ intervalSeconds
   ↓
4. If yes: claim lastShownAt timestamp (atomic slot)
   ↓
5. Send TRIGGER_NOW to background
   ↓
6. Background responds with SHOW_WORD_SESSION message
   ↓
7. Build quiz HTML in Shadow DOM
   ↓
8. Render quiz overlay on page
   ↓
9. Wait for user answer OR timeout
   ↓
10. Send RECORD_ANSWER to background
    ↓
11. Close overlay, continue polling
```

**Polling Algorithm** (prevents duplicate triggers across tabs):
```javascript
// Timestamp-based locking mechanism:
// 1. Check if (now - lastShownAt) ≥ intervalSeconds
// 2. If yes, immediately write lastShownAt = now (atomic operation)
// 3. Other tabs see the updated timestamp and skip this interval
// 4. Only one tab per interval gets to trigger the quiz

const elapsed = now - lastShownAt;
if (elapsed >= intervalSeconds * 1000) {
  await chrome.storage.local.set({ lastShownAt: now });  // Claim slot
  chrome.runtime.sendMessage({ type: "TRIGGER_NOW" });   // Trigger
}
```

### 2. Service Worker (background.js)

**Role**: Core quiz engine, state management, scheduling.

**Key Responsibilities**:
- Build quiz sessions (select eligible words, generate questions)
- Track user statistics (streak, accuracy, mastery)
- Schedule quizzes via Chrome Alarms (≥1 min intervals)
- Persist all state to Chrome Storage
- Enforce daily new-word quota
- Handle 15 message types from popup/content

**Architecture Sections**:

#### Scheduling Engine
```javascript
// Alarms API handles ≥1 minute intervals
chrome.alarms.create("learnWord", { periodInMinutes: 10 });
chrome.alarms.onAlarm.addListener(async (alarm) => {
  if (alarm.name === "learnWord") {
    await buildAndShowSession();  // Show quiz
  }
});

// For sub-minute intervals (15s, 30s):
// Content script polling + atomic timestamp slot (see content.js)
```

#### Spaced Repetition Algorithm
```javascript
// Fibonacci scheduling: each correct answer pushes next quiz further out
const FIBONACCI = [1, 2, 3, 5, 8, 13, 21, 34, 55, 89];

function getFibInterval(correctCount) {
  // correctCount=0 → interval=1 min
  // correctCount=1 → interval=2 min
  // correctCount=7+ → interval=89 min (mastered)
  return FIBONACCI[Math.min(correctCount, FIBONACCI.length - 1)];
}

// On correct answer:
userWords[wordId].correctCount++;
userWords[wordId].nextShowAt = Date.now() + getFibInterval(...) * 60 * 1000;

// On incorrect answer:
userWords[wordId].incorrectCount++;
userWords[wordId].correctCount = 0;  // Reset mastery progress
userWords[wordId].nextShowAt = Date.now() + 1 * 60 * 1000;  // Back to 1 min
```

#### Quiz Session Building
```javascript
async function buildAndShowSession(force = false) {
  // 1. Get eligible words (apply difficulty/category filters)
  let pool = getEligibleWords(words, settings);
  
  // 2. Enforce daily quota: only X new words per day
  let todayNewWords = getTodayNewWords();
  if (todayNewWords.length >= settings.wordsPerDay && !force) {
    return;  // Daily limit reached
  }
  
  // 3. Select wordsPerPopup random words from pool
  let selected = [];
  for (let i = 0; i < settings.wordsPerPopup && pool.length > 0; i++) {
    const idx = Math.floor(Math.random() * pool.length);
    selected.push(pool[idx]);
    pool.splice(idx, 1);
  }
  
  // 4. Build quiz with random direction & answer type
  const quiz = {
    words: selected,
    direction: pickRandom(["en-to-vn", "vn-to-en"]),  // if mixed
    answerType: pickRandom(["choice", "typing"]),      // if mixed
    timeout: settings.sessionTimeoutSeconds,
  };
  
  // 5. Show quiz (either overlay or fallback)
  await showQuizOverlay(quiz);  // Try content script
}
```

#### Storage Model
```javascript
// Chunked word array (mitigates quota limits)
words_chunk_0: [{ id, english, vietnamese, difficulty, category, ... }]
words_count: 1000

// Per-word mastery tracking
userWords: {
  "word_id": {
    correctCount: 5,      // Progress toward mastery
    incorrectCount: 2,
    status: "learning",   // new | learning | mastered
    lastShownAt: timestamp,
    nextShowAt: timestamp,
  }
}

// Global statistics
stats: {
  correct: 45,          // Total correct answers (all time)
  incorrect: 12,        // Total incorrect answers
  streak: 3,            // Current streak (reset on wrong answer)
  bestStreak: 7,        // Best streak ever
}

// User preferences
settings: { ... }

// Daily quota tracking
dailyState: {
  date: "2026-04-07",
  newWordIds: ["id1", "id2", "id3"],  // 3 out of 5 shown today
}
```

### 3. Popup Script (popup.js)

**Role**: User-facing UI for managing words, settings, and statistics.

**Key Responsibilities**:
- Display word list with learning status
- Add/edit/delete words
- Import CSV files
- Configure quiz settings
- Show statistics and progress
- Trigger quiz manually ("Hiện ngay" button)

**Tab Architecture**:
```
┌─ Words Tab ("Từ vựng") ─────────────────────────┐
│ - Learning status cards (new/learning/mastered) │
│ - Search input                                   │
│ - Add word form                                  │
│ - Word list (with actions)                       │
│ - CSV import                                     │
│ - Daily quota progress                           │
└──────────────────────────────────────────────────┘

┌─ All Words Tab ("Tất cả từ") ──────────────────┐
│ - Searchable, paginated view (50 per page)      │
│ - Sort by status                                │
│ - Filter by difficulty/category                 │
│ - Read-only (edit via Words tab)                │
└──────────────────────────────────────────────────┘

┌─ Stats Tab ("Thống kê") ────────────────────────┐
│ - Today's new word quota progress bar           │
│ - Correct/Incorrect tally cards                 │
│ - Accuracy percentage                           │
│ - Streak + Best Streak                          │
│ - Reset stats button                            │
└──────────────────────────────────────────────────┘

┌─ Settings Tab ("Cài đặt") ──────────────────────┐
│ - Difficulty filter (B1/B2/C1/C2)               │
│ - Category filter                               │
│ - Session timeout (30s–3min)                    │
│ - Enable/disable toggle                         │
│ - Quiz interval (15s–60min)                     │
│ - New words per day (1–20)                      │
│ - Words per popup (1–5)                         │
│ - Question direction (EN→VN|VN→EN|mixed)       │
│ - Answer type (choice|typing|mixed)             │
│ - Danger zone (clear all, reset defaults)       │
└──────────────────────────────────────────────────┘
```

---

## Message Flow Diagrams

### Quiz Trigger Flow (≥1 minute interval)

```
┌─────────────────────────┐
│ Chrome Alarms (≥1 min)  │
│ fires every periodMins  │
└────────────┬────────────┘
             │
             ↓
    ┌────────────────────────┐
    │ background.js          │
    │ onAlarm handler        │
    │ buildAndShowSession()  │
    └────────┬───────────────┘
             │
             ↓
    ┌────────────────────────────┐
    │ Build quiz object:         │
    │ - Select eligible words    │
    │ - Enforce daily quota      │
    │ - Random direction/type    │
    └────────┬───────────────────┘
             │
             ↓
    ┌────────────────────────────────────┐
    │ chrome.tabs.query()                │
    │ Find active HTTP/HTTPS tab         │
    └────────┬───────────────────────────┘
             │
         ┌───┴─────────────┐
         │                 │
         ↓                 ↓
    Found tab         No tab found
         │                 │
         ↓                 ↓
    SHOW_WORD_SESSION  open quiz.html
    to content.js      (fullscreen)
         │
         ↓
    content.js
    renderQuiz()
    (Shadow DOM overlay)
```

### Quiz Answer Flow

```
┌──────────────┐
│ User clicks  │
│ answer       │
└──────┬───────┘
       │
       ↓
┌──────────────────────────────┐
│ content.js                   │
│ recordAnswer(wordId, answer) │
└──────┬───────────────────────┘
       │
       ↓
    RECORD_ANSWER
    to background.js
       │
       ↓
┌──────────────────────────────────┐
│ background.js                    │
│ - Validate answer                │
│ - Update stats                   │
│ - Update userWords[wordId]       │
│ - Calculate next show time       │
└──────┬───────────────────────────┘
       │
       ↓
┌──────────────────────────────────┐
│ chrome.storage.local.set()       │
│ Persist updated state            │
└──────┬───────────────────────────┘
       │
       ↓
┌──────────────────────────────────┐
│ Send response to content.js      │
│ { nextQuiz: ... }               │
└──────┬───────────────────────────┘
       │
       ↓
┌──────────────────────────────────┐
│ content.js                       │
│ Close overlay / Show next quiz   │
│ or close if last in session      │
└──────────────────────────────────┘
```

### Sub-Minute Polling Flow (15s–30s)

```
┌─────────────────────────┐
│ content.js started      │
│ setupPolling()          │
└────────────┬────────────┘
             │
             ↓
    ┌────────────────────────┐
    │ setInterval(1000ms)    │
    │ Poll every 1 second    │
    └────────┬───────────────┘
             │
    ┌────────┴─────────────────────────┐
    │ Check settings.intervalSeconds    │
    │ if not enabled → clear polling    │
    └────────┬────────────────────────┘
             │
             ↓
    ┌──────────────────────────────────┐
    │ Get lastShownAt from storage     │
    │ Calculate elapsed = now - last   │
    └────────┬──────────────────────────┘
             │
        ┌────┴─────────────────────┐
        │                          │
        ↓                          ↓
    elapsed ≥         elapsed <
    intervalSeconds   intervalSeconds
        │                      │
        ↓                      ↓
    Claim slot:        Wait 1s, check again
    set lastShownAt
        │
        ↓
    TRIGGER_NOW
    to background
        │
        ↓
    background.js
    buildAndShowSession()
```

---

## Quiz Lifecycle

### Question Generation

```javascript
// Direction: EN → VN or VN → EN
const directions = {
  "en-to-vn": {
    question: word.english,
    questionLabel: "English",
    answer: word.vietnamese,
    answerLabel: "Vietnamese",
  },
  "vn-to-en": {
    question: word.vietnamese,
    questionLabel: "Vietnamese",
    answer: word.english,
    answerLabel: "English",
  },
};

// Multiple choice: 4 options (2×2 grid)
// - Correct answer
// - 3 random distractors (different words)

// Typing input: text field with character counter
```

### Answer Validation

```javascript
// Normalize both strings (lowercase, trim, remove diacritics)
function normalize(str) {
  return str
    .toLowerCase()
    .trim()
    .normalize("NFD")           // Decompose accents
    .replace(/[\u0300-\u036f]/g, "")  // Remove diacritics
    .replace(/đ/g, "d")
    .replace(/\s+/g, " ");      // Normalize spaces
}

// Check: normalize(userInput) === normalize(correctAnswer)
const isCorrect = normalize(input) === normalize(correct);
```

### Timeout & Auto-Close

```javascript
// Animated progress bar: width shrinks from 100% to 0% over timeout seconds
// Color changes: green → orange → red as time runs out

// On timeout:
// - Auto-submit (treat as incorrect if not answered)
// - Close overlay
// - Schedule next quiz

// User can close manually: click × button (skips this quiz, no penalty)
```

---

## Spaced Repetition Algorithm

### Fibonacci Intervals

```
Correct Answer Sequence:  0 1 2 3  4  5   6   7   8  9+
Next Interval (minutes): [1 2 3 5  8 13  21  34  55 89]
Status:                [N L L L  L  L   L   M   M  M]
                       (N=new, L=learning, M=mastered at 7+)
```

### Mastery Threshold

```javascript
const MASTERED_THRESHOLD = 7;  // 7 consecutive correct answers

// When correct:
userWords[id].correctCount++;
if (userWords[id].correctCount >= MASTERED_THRESHOLD) {
  userWords[id].status = "mastered";
  userWords[id].nextShowAt = Date.now() + (89 * 60 * 1000);  // Max interval
}

// When incorrect:
userWords[id].correctCount = 0;           // Reset progress
userWords[id].status = "learning";        // Revert to learning
userWords[id].nextShowAt = Date.now() + (1 * 60 * 1000);   // Back to 1 min
userWords[id].incorrectCount++;
stats.streak = 0;  // Break streak
```

### Daily Quota

```javascript
// Configuration: wordsPerDay (default 5)
// Limit: only X new/learning words shown per day

async function getTodayNewWords() {
  const { dailyState } = await chrome.storage.local.get("dailyState");
  const today = new Date().toISOString().split("T")[0];  // YYYY-MM-DD
  
  if (dailyState?.date === today) {
    return dailyState.newWordIds || [];
  }
  
  // New day: reset quota
  return [];
}

// On quiz: add shown word ID to today's list
// Prevent showing same word twice per day
// Reset list at midnight (UTC)
```

---

## Storage Quota Management

### Chunking Strategy

```javascript
// Limit: ~5 MB per key, 10 MB total per extension

// Solution: Split word array into chunks
const WORDS_CHUNK_SIZE = 500;

// 1000 words → 2 chunks
// words_chunk_0: words[0..499]    (5 MB max)
// words_chunk_1: words[500..999]  (5 MB max)
// words_count: 1000                (bytes, stored once)

// Read: Get words_count, calculate chunk count, fetch all chunks
// Write: Split words, write chunks, remove stale chunks

// Example: reducing words from 1000 to 300
// - words_count = 300
// - words_chunk_0 = [300 words]
// - words_chunk_1 (delete) ← stale
```

### Migration from Legacy Format

```javascript
// Old: single "words" key with all 1000+ words
// New: words_chunk_0, words_chunk_1, ..., words_count

// On startup:
// 1. Check if words_count exists
// 2. If not, check for legacy "words" key
// 3. If found, read it (fallback)
// 4. On next write, auto-migrate to chunked format
// 5. Delete legacy key
```

---

## Browser Compatibility

### Chrome 125+ (Manifest V3)

**Required APIs**:
- ✅ `chrome.runtime.sendMessage()` – Message passing
- ✅ `chrome.storage.local` – Persistent storage (10 MB limit)
- ✅ `chrome.alarms` – Long-duration scheduling (≥1 min)
- ✅ `chrome.tabs` – Tab detection (for fallback logic)
- ✅ `chrome.windows` – Window management (quiz.html fullscreen)
- ✅ `chrome.scripting` – Content script injection (via manifest)

**Web APIs**:
- ✅ `SpeechSynthesis` – Text-to-speech (pronunciation)
- ✅ `Shadow DOM` – Style isolation
- ✅ `Fetch API` – Load CSV file

**Constraints**:
- ❌ No `localStorage` (use `chrome.storage.local`)
- ❌ No background pages (only service worker)
- ❌ No `setInterval` in service worker (use alarms or polling in content)
- ❌ No eval() or inline event handlers (CSP compliance)

---

## Fallback Mechanisms

### No HTTP Tabs Available

**Scenario**: User opens popup while on new-tab page (no HTTP URLs).

**Solution**: Open `quiz.html` in fullscreen window
```javascript
// quiz.html contains same UI as overlay
// Loads background.js + content.js for full functionality
// When quiz closes, background restores original window
```

### Sub-Minute Polling Failure

**Scenario**: Content script crashes, polling stops.

**Fallback**: Chrome Alarms API kicks in
```javascript
// Alarms minimum: 1 minute
// If sub-minute polling fails, quizzes still show every 1 minute
// User won't notice (difference between 10s and 1 min is small)
```

### Service Worker Unresponsive

**Scenario**: Service worker in middle of update or crash.

**Fallback**: Message sending includes `.catch()`
```javascript
chrome.runtime.sendMessage(message)
  .catch(() => {
    // Service worker not ready, fail gracefully
    // Retry on next polling cycle
  });
```

---

## Performance Characteristics

| Operation | Latency | Notes |
|-----------|---------|-------|
| Quiz overlay injection | <500ms | Shadow DOM + simple HTML |
| Word list rendering (1000 items) | <1s | Paginated (50/page) |
| CSV import (100 rows) | <1s | Validation + storage write |
| Storage read (words_count) | ~50ms | Single key lookup |
| Storage read (all words) | ~200ms | 2–3 chunk reads |
| Sub-minute polling check | <50ms CPU | 1000ms wall-clock interval |
| Stats calculation | <10ms | Simple arithmetic |
| Mastery check | <5ms | Array find operation |

---

## Error Scenarios & Recovery

| Scenario | Detection | Recovery |
|----------|-----------|----------|
| Storage quota exceeded | `chrome.storage.local.set()` error | Split into more chunks, fail gracefully |
| CSV import with 50% invalid rows | Row validation loop | Show report: "X imported, Y skipped, Z errors" |
| Service worker crash | Message timeout + `.catch()` | Retry on next polling cycle |
| Content script removed | `SHOW_WORD_SESSION` message fails | Fall back to quiz.html window |
| User closes quiz manually | Content script detects close button | No penalty, continue polling |
| Duplicate word IDs after import | `words.find(w => w.id === newId)` | Generate new unique ID, retry |

---

## Future Extensibility Points

1. **Multiple Languages**: Extend CSV to support EN-ES, EN-FR, etc.
2. **Cloud Sync**: Add Firebase/Supabase sync (optional premium)
3. **Spaced Repetition Variants**: SM-2, Leitner system options
4. **Statistics Export**: CSV export of learning history
5. **Voice Recognition**: Speech input for pronunciation practice
6. **Collaborative Lists**: Share word lists with other users
7. **Mobile App**: React Native version with sync

---

**Document Status**: Current  
**Last Updated**: 2026-04-07
