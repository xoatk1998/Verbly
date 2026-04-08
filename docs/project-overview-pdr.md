# Learn New Words – Product Overview & PDR

## Product Vision

Enable busy professionals to build English vocabulary passively through brief, spaced-repetition quizzes during their daily web browsing. Leverage micro-learning (2–5 min sessions every 10 min) to achieve better retention with minimal friction.

## Target Users

- **Primary**: Vietnamese speakers (English learners, B1–C2 levels)
- **Age**: 18–50 professionals, students
- **Context**: Daily web browsers (news, work, social media)
- **Motivation**: Convenient vocabulary expansion without dedicated study time

## Core Requirements

### Functional Requirements

**FR1: Word Management**
- Import up to 1000+ words via CSV
- Add, edit, delete words in popup UI
- Organize words by difficulty (B1–C2) and category (user-defined tags)
- Search/filter words by text, difficulty, category

**FR2: Spaced Repetition Engine**
- Fibonacci-based scheduling: correct answers trigger [1, 2, 3, 5, 8, 13, 21, 34, 55, 89 min] intervals
- Track mastery: 7+ consecutive correct answers → "Mastered" state
- Daily quota: 5 new words/day (configurable, 1–20)
- Sub-minute intervals (15s, 30s): content script polling; ≥1 min: Chrome Alarms API

**FR3: Quiz UI**
- Overlay quiz: Shadow DOM injected into web pages (non-intrusive)
- Fallback fullscreen quiz (quiz.html) when no HTTP tabs available
- Question directions: EN→VN, VN→EN, or random mix
- Answer modes: multiple choice (4 options, 2×2 grid) OR typing input
- 30s–3 min timeout with animated progress bar (configurable)
- Auto-close on timeout
- Speech synthesis: automatic English pronunciation on quiz display

**FR4: Statistics & Progress**
- Accuracy % (correct ÷ total answers)
- Streak counter (current, best)
- Correct/incorrect tallies
- Daily new-word quota progress
- Per-word mastery status (new, learning, mastered)

**FR5: Settings**
- Enable/disable learning (global toggle)
- Quiz interval (15s–60min, or custom)
- Daily new-word quota (1–20)
- Words per popup (1–5, default 2)
- Question direction (EN→VN, VN→EN, mixed)
- Answer type (multiple choice, typing, mixed)
- Session timeout (30s–3min, or off)
- Difficulty filter (select 0+ from B1–C2)
- Category filter (select 0+ from available tags)

**FR6: Data Persistence**
- All data in Chrome Storage API (`chrome.storage.local`)
- Chunked word storage (500 words per chunk to avoid quota limits)
- Automatic backup on every state change

### Non-Functional Requirements

**NFR1: Performance**
- Quiz overlay injection < 500ms latency
- Word list rendering < 1s for 1000 words
- Sub-minute polling interval < 50ms CPU per check
- No page-load delays (async content script injection)

**NFR2: Reliability**
- Graceful fallback to fullscreen quiz if web page unavailable
- Survive browser restart (data persists in storage)
- Handle CSV import errors (validate all rows before import)
- Chunk storage to prevent quota-exceeded errors

**NFR3: Security**
- No external API calls (data stays local)
- No third-party libraries (vanilla JS only)
- Content Security Policy: inline styles/scripts allowed in Shadow DOM
- Storage: unencrypted (Chrome handles OS-level encryption)

**NFR4: Compatibility**
- Chrome 125+ (Manifest V3 required)
- Edge 125+, other Chromium browsers
- All screen sizes (responsive popup)

**NFR5: Maintainability**
- Vanilla JavaScript (zero production npm dependencies)
- Modular code: background (service worker), content (overlay), popup (UI)
- Message-based async communication (no shared state)
- Clear naming: message types (GET_ALL_WORDS, RECORD_ANSWER, etc.)

## Feature List

| # | Feature | Status | Priority | Description |
|---|---------|--------|----------|-------------|
| 1 | CSV Import | Complete | P0 | Bulk word import with validation |
| 2 | Spaced Repetition | Complete | P0 | Fibonacci scheduling engine |
| 3 | Overlay Quiz | Complete | P0 | Shadow DOM injection + fallback |
| 4 | Statistics | Complete | P0 | Accuracy, streak, mastery tracking |
| 5 | Settings UI | Complete | P0 | Configurable intervals, filters, quiz types |
| 6 | Speech Synthesis | Complete | P1 | Auto-play English pronunciation |
| 7 | Word Management | Complete | P1 | Add, edit, delete words in popup |
| 8 | Daily Quota | Complete | P1 | Limit new words per day |
| 9 | Difficulty Badges | Complete | P2 | B1–C2 visual labels |
| 10 | Category Tags | Complete | P2 | User-defined topic organization |

## Out of Scope

- **Multi-language support beyond EN-VN**
- **Cloud sync / multi-device persistence**
- **User accounts / authentication**
- **Spaced repetition variants (SM-2, Leitner, etc.)**
- **Pronunciation training (speech recognition)**
- **Collaborative word lists**
- **Mobile apps** (Chrome extension only)
- **Dark mode** (follows system theme via CSS)
- **Premium/paid tiers** (open-source, free forever)
- **Analytics / telemetry** (no data collection)

## Success Metrics

- **User Retention**: >60% 7-day retention (install → use within week)
- **Daily Active Usage**: ≥5 quiz sessions/day per active user
- **Vocabulary Growth**: Average user learns 50+ words within 4 weeks
- **Accuracy**: >70% average quiz accuracy after first week
- **Performance**: Overlay shows in <500ms; no page slowdown

## Technical Constraints

1. **Zero npm production dependencies** – Webpack/CLI only, shipped code is vanilla JS
2. **Chrome Storage quota**: 10 MB per extension (mitigated by chunking)
3. **Manifest V3**: No background scripts (service worker only), async messaging required
4. **Content script isolation**: Cross-origin restrictions require message passing
5. **Shadow DOM**: Necessary for style isolation but limits parent-page interaction

## Dependencies & Integrations

- **No external APIs** – all data stored locally
- **Chrome Runtime API** – for service worker messaging
- **Chrome Storage API** – for data persistence
- **Chrome Alarms API** – for long-duration scheduling (≥1 min)
- **Web Speech API** – for text-to-speech (browser-native, optional)
- **Chrome Tabs API** – for tab detection (fullscreen fallback logic)

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-04 | Initial release: spaced repetition, CSV import, overlay quizzes, statistics |

---

**Document Status**: Current  
**Last Updated**: 2026-04-07
