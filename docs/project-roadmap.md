# Project Roadmap & Future Phases

## Current State (v1.0)

**Status**: Complete & Stable  
**Release Date**: 2026-04-07  
**Stability**: Production-ready

### Implemented Features

| Feature | Status | Quality | Notes |
|---------|--------|---------|-------|
| Spaced repetition engine | ✅ | Stable | Fibonacci scheduling with mastery threshold |
| Multiple quiz types | ✅ | Stable | EN→VN, VN→EN, mixed directions |
| Answer modes | ✅ | Stable | Multiple choice (2×2) + typing input |
| CSV import/export | ✅ | Stable | Validation, error reporting, batch import |
| Word management | ✅ | Stable | Add, edit, delete, search, filter |
| Statistics tracking | ✅ | Stable | Accuracy, streak, per-word mastery |
| Popup UI | ✅ | Stable | 4 tabs, responsive 380px layout |
| Settings | ✅ | Stable | Interval, difficulty, category, timeout |
| Shadow DOM overlay | ✅ | Stable | Non-intrusive, style-isolated quizzes |
| Sub-minute intervals | ✅ | Stable | Content script polling + atomic locking |
| Daily quota | ✅ | Stable | New words per day limit |
| Speech synthesis | ✅ | Stable | Auto-play English pronunciation |
| Storage chunking | ✅ | Stable | Handles 1000+ words without quota errors |
| Fullscreen fallback | ✅ | Stable | quiz.html window when no HTTP tabs |
| State persistence | ✅ | Stable | All data survives browser restart |

### Known Limitations (v1.0)

1. **Single Language Pair**: Only EN↔VN (no ES, FR, DE, etc.)
2. **No Cloud Sync**: Data stored locally; not synced across devices
3. **No User Accounts**: Browser profile-specific storage only
4. **No Mobile**: Chrome extension only (no iOS/Android apps)
5. **No Voice Recognition**: Text-to-speech only (no speech-to-text)
6. **No Pronunciation Guides**: IPA/Phonetic transcriptions not included
7. **No Collaborative Features**: Word lists can't be shared or collaborated on
8. **No Analytics**: No learning insights beyond basic stats
9. **No Dark Mode**: Follows system theme (toggle in future)
10. **Single Spaced Repetition Algorithm**: Only Fibonacci (SM-2, Leitner available as options later)

---

## Proposed Future Phases

### Phase 1: Enhanced Analytics (Q2 2026)

**Goal**: Provide learners with deeper insights into their learning patterns.

**Features**:
- Time-of-day heatmap (when do I learn best?)
- Category mastery progress (% completion per category)
- Difficulty progression chart (B1 → B2 → C1 → C2 advancement)
- Word retention rates (% still correct after X days)
- Session history (dates, quiz counts, accuracy trends)
- Projected mastery date (when will I master all words?)

**Implementation**:
- Add `sessionLog` storage table
- Each quiz records: timestamp, wordId, correct, direction, answerType
- Aggregate stats in popup Stats tab
- Export logs as CSV

**Effort**: 2–3 weeks  
**Priority**: P1 (high demand)  
**Dependencies**: None

---

### Phase 2: Multiple Language Support (Q3 2026)

**Goal**: Expand to other language pairs (EN-ES, EN-FR, EN-DE, etc.).

**Features**:
- Language pair selector (EN-VN, EN-ES, EN-FR, EN-DE, EN-JA, EN-ZH)
- Separate word lists per language pair
- Separate statistics per language
- Multi-language CSV import with language column

**CSV Format**:
```csv
language,english,vietnamese,exampleSentence,difficulty,category
EN-VN,question,câu hỏi,...,B1,Daily Communication
EN-ES,question,pregunta,...,B1,Daily Communication
```

**Implementation**:
- Add `language` field to word object
- Parameterize storage keys: `words_chunk_0_{lang}`
- Add language selector to popup
- Filter eligible words by language + difficulty + category

**Effort**: 3–4 weeks  
**Priority**: P1 (high demand)  
**Dependencies**: None

---

### Phase 3: Alternative Spaced Repetition Algorithms (Q3 2026)

**Goal**: Offer users choice in scheduling algorithm (SuperMemo 2, Leitner system).

**Options**:

**A) Fibonacci (Current)**
- Intervals: 1, 2, 3, 5, 8, 13, 21, 34, 55, 89 minutes
- Mastery at 7 correct answers
- Reset to 1 min on incorrect

**B) SuperMemo 2 (SM-2)**
- Interval factor: 2.5 (adjustable per user)
- Quality score: 0–5 (adjust factor based on quality)
- Formula: nextInterval = previousInterval * easeFactor
- Easiness: 4.0 - (5 - quality) * (0.08 + (5 - quality) * 0.02)

**C) Leitner System**
- 5 bins (very easy, easy, medium, hard, very hard)
- Review frequency: 1 day, 3 days, 1 week, 2 weeks, 1 month
- Move up on correct, down on incorrect
- Mastery: stay in bin 5 for 2 weeks

**Implementation**:
- Add `algorithm` setting (default: fibonacci)
- Per-word metadata: `easeFactor`, `bin`, `reviewDate`
- Calculate next show time based on algorithm
- Settings tab selector

**Effort**: 2–3 weeks  
**Priority**: P2 (nice-to-have)  
**Dependencies**: Phase 1 (analytics) might benefit from comparison data

---

### Phase 4: Cloud Sync & User Accounts (Q4 2026)

**Goal**: Sync data across devices, enable cloud backup.

**Features**:
- User authentication (Google OAuth, simple email signup)
- Cloud storage (Firebase, Supabase, custom backend)
- Device sync (conflict resolution for overlapping edits)
- Cloud backup & restore
- Word list sharing (read-only or collaborative)
- Leaderboards (optional: anonymized global stats)

**Implementation**:
- Add authentication popup
- Wrap `chrome.storage.local` calls with cloud sync
- Implement differential sync (send only changed words)
- Handle offline mode (queue updates, sync on reconnect)

**Effort**: 6–8 weeks  
**Priority**: P2 (medium demand)  
**Dependencies**: Phase 1, 2 (analytics, multi-language needed first)

---

### Phase 5: Mobile Apps (2027)

**Goal**: Bring Learn New Words to iOS and Android.

**Options**:

**A) React Native App**
- Code sharing with Expo
- iOS & Android parity
- Sync with web extension via cloud

**B) Native Apps**
- Swift (iOS) + Kotlin (Android)
- Better performance, native UX

**Implementation**:
- Extract core logic to shared module
- Build mobile UI from scratch
- Integrate with cloud backend (Phase 4)

**Effort**: 12–16 weeks (large project)  
**Priority**: P3 (lower priority, large scope)  
**Dependencies**: Phase 4 (cloud sync needed)

---

### Phase 6: Voice Recognition (2027)

**Goal**: Enable speech-to-text for pronunciation practice.

**Features**:
- Voice input for answers (instead of typing)
- Speech quality scoring (pronunciation accuracy)
- Vietnamese accent detection
- Phonetic comparison

**Technologies**:
- Web Speech API (Chrome native)
- Google Cloud Speech-to-Text (optional, paid)
- Phonetic distance algorithm (Levenshtein, Soundex)

**Implementation**:
- Add "Voice" answer mode (alternative to typing/choice)
- Record user speech → compare with expected answer
- Show feedback: phonetic match %, suggested pronunciation

**Effort**: 3–4 weeks  
**Priority**: P3 (lower demand, complex NLP)  
**Dependencies**: None (but Phase 2 recommended first)

---

### Phase 7: Collaborative Learning (2027)

**Goal**: Enable teachers and learners to create and share word lists.

**Features**:
- Public word lists (teachers publish, students subscribe)
- Word list forking (copy list, customize for yourself)
- Collaborative editing (real-time or turn-based)
- Teacher dashboard (track student progress)
- Class management (assign word lists, set deadlines)

**Implementation**:
- Word list ownership model (user-specific storage)
- Sharing mechanism (public URL, access codes, email invites)
- Real-time sync (WebSocket or Firebase Realtime DB)
- Teacher UI (progress views, assignment grading)

**Effort**: 8–10 weeks  
**Priority**: P3 (niche use case)  
**Dependencies**: Phase 4 (cloud sync + accounts)

---

## Timeline Summary

```
2026-04 (NOW)
  └─ v1.0 Release ✅

2026-Q2
  ├─ Phase 1: Enhanced Analytics
  └─ [Start Phase 2: Multi-Language]

2026-Q3
  ├─ Phase 2: Multiple Languages (complete)
  ├─ Phase 3: Alternative Algorithms
  └─ [Start Phase 4: Cloud Sync]

2026-Q4
  ├─ Phase 4: Cloud Sync (in progress)
  └─ [Planning: Mobile Apps]

2027-Q1+
  ├─ Phase 4: Cloud Sync (complete)
  ├─ Phase 5: Mobile Apps (start)
  ├─ Phase 6: Voice Recognition
  └─ Phase 7: Collaborative Learning
```

---

## Success Metrics

### Current (v1.0)

- **Retention**: >60% 7-day retention (install → use within week)
- **Engagement**: ≥5 quiz sessions/day per active user
- **Vocabulary Growth**: Avg 50+ words learned within 4 weeks
- **Accuracy**: >70% average quiz accuracy after 1st week
- **Performance**: Overlay <500ms; no page slowdown

### Post-Phase 1 (Analytics)

- **Insight Value**: >80% of users check learning heatmaps
- **Engagement**: +20% increase in session duration
- **Retention**: >70% 30-day retention

### Post-Phase 2 (Multi-Language)

- **Language Adoption**: ≥20% users try non-VN languages
- **User Growth**: +50% new user sign-ups (multi-language appeal)
- **DAU Growth**: +30% daily active users

### Post-Phase 4 (Cloud Sync)

- **Cross-Device Usage**: >40% users sync data across 2+ devices
- **Data Retention**: >95% users never lose data (cloud backup confidence)
- **Churn Reduction**: -30% uninstall rate

---

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|-----------|
| Cloud sync conflicts | Medium | High | Implement differential sync, conflict resolution strategy |
| Speech recognition accuracy | Medium | Medium | Use multiple providers, fallback to typing |
| Storage quota exceeded (many languages) | Low | High | Implement user-based quota increases |
| Browser compatibility (new Web APIs) | Low | Medium | Feature detection, graceful degradation |

### Market Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|-----------|
| User growth plateau | Medium | Medium | Phase 2 (multi-language) to expand market |
| Competitor extensions | Medium | Medium | Differentiate via superior UX, spaced rep algorithm |
| Chrome policy changes | Low | High | Monitor Chrome Web Store policy, maintain compliance |

### Resource Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|-----------|
| Scope creep (Phases 5–7) | High | High | Strict prioritization, MVP focus |
| Maintainability (growing codebase) | Medium | Medium | Refactor into modules, improve test coverage |
| API rate limits (cloud services) | Low | Medium | Cache, batch requests, use webhooks |

---

## Maintenance Plan (v1.0)

### Bug Fixes & Hotfixes

**Response Time**:
- Critical (data loss, security): 24 hours
- High (major feature broken): 1 week
- Medium (minor UI bug): 2 weeks
- Low (cosmetic): backlog

**Process**:
1. Report via GitHub Issues
2. Triage & priority assignment
3. Fix + test in branch
4. Submit PR, code review
5. Merge + build → Chrome Web Store update

### Minor Updates (1–2 weeks)

- Spelling/grammar fixes in UI
- CSV format improvements
- Performance optimizations
- Style refinements

### Major Updates (Monthly+)

- Phase milestones (Analytics, Multi-Language, etc.)
- New features + architecture changes
- Breaking changes (documented in changelog)

### Deprecation Policy

When removing features:
1. Announce in popup notice (1 month notice)
2. Provide migration path (export data, etc.)
3. Remove in next major version

---

## Open Questions & Decisions

1. **Phase 4 (Cloud)**: Firebase vs Supabase vs custom backend?
   - Trade-off: ease vs control/cost
   - Decision: TBD (Supabase likely, open-source PostgreSQL)

2. **Phase 5 (Mobile)**: React Native or native?
   - Trade-off: code sharing vs performance
   - Decision: React Native (faster MVP)

3. **Phase 6 (Voice)**: Web Speech API vs Cloud Speech-to-Text?
   - Trade-off: privacy/free vs accuracy/cost
   - Decision: Try Web Speech API first, upgrade if needed

4. **Monetization**: Free forever or premium tier?
   - Options: Ads, premium features, subscription
   - Decision: TBD (likely stay free, optional cloud upgrade paid)

5. **Community**: Open-source or proprietary?
   - Decision: Open-source on GitHub (to encourage contributions)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-04-07 | Initial release: spaced repetition, CSV import, overlays, stats |
| 0.9.0 | 2026-03-28 | Beta testing, refinements |
| 0.8.0 | 2026-03-15 | Feature complete, internal testing |
| 0.1.0 | 2026-01-20 | Proof of concept, basic spaced rep |

---

**Document Status**: Current  
**Last Updated**: 2026-04-07  
**Next Review**: 2026-07-07 (post-Phase 1)
