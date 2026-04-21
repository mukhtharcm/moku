# Moku Feature Roadmap

> Prioritized from internet research across competitor apps (KOReader, Readest, Moon+ Reader, justRead, FolioReaderKit, Bookly, StoryGraph, Leaf, Readmaze, Bookie) and open-source issue trackers.

---

## Tier 1 — High Impact

### 1. 📊 Reading Statistics & Streak Tracking

**Cross-platform plan — all 3 components must land together:**

#### Server (PocketBase migration)
- [ ] Create `reading_sessions` collection (migration `1749000008`)
  - Fields: `book` (rel → books), `user` (rel → users), `started_at` (date), `ended_at` (date, optional), `start_chapter` (number), `end_chapter` (number), `start_page` (number), `end_page` (number), `pages_read` (number), `duration_seconds` (number)
  - Auth rules: user can only CRUD own sessions
  - Index on `(book, user)` and `(user, started_at)` for efficient queries
- [ ] Create `reading_goals` collection (migration `1749000009`)
  - Fields: `user` (rel → users), `year` (number), `books_goal` (number), `pages_per_day_goal` (number)
  - Auth rules: user can only CRUD own goals

#### macOS (Swift/SwiftData)
- [ ] Add `ReadingSession` model to `Models.swift`
  - Fields: id, book (relationship), startedAt, endedAt (optional), startChapter, endChapter, startPage, endPage, pagesRead, duration, bookTitle (denormalized), remoteId
- [ ] Add `ReadingGoal` model to `Models.swift`
  - Fields: id, year, booksGoal, pagesPerDayGoal, remoteId
- [ ] Wire session lifecycle in `ReaderView.swift`:
  - Create session on `onAppear`, finalize on `onDisappear`
  - Update `endPage`/`endChapter` on every page change (via `saveProgress`)
- [ ] Add `StatsViewModel` — computes streak, totals, activity from sessions
- [ ] Add `StatsView` — streak card, heatmap, stats summary, recent activity
- [ ] Add `ActivityHeatmapView` — 12-month GitHub-style calendar grid
- [ ] Add `ReadingStreakView` — flame icon + streak count + longest streak
- [ ] Add "Stats" tab to `ContentView.swift` sidebar navigation
- [ ] Register `ReadingSession` + `ReadingGoal` in `MokuApp.swift` SwiftData schema
- [ ] Add `syncReadingSessions()` + `syncReadingGoals()` to `SyncEngine.swift`
- [ ] Show pages read / time on book detail cards in library

#### Flutter (Dart/Drift)
- [ ] Add `ReadingSessions` + `ReadingGoals` tables to `tables.dart`
- [ ] Generate Drift migration, add DAO methods
- [ ] Create `ReadingSessionCubit` or extend `ReaderCubit` to track session start/end
- [ ] Create `StatsPage` widget — streak, heatmap, summary, activity list
- [ ] Add Stats tab to `AppShell` bottom nav (or accessible from library)
- [ ] Add sync methods to `SyncEngine` for sessions + goals
- [ ] Show reading time / streak badge on library cards

**Platforms:** Both (macOS + Flutter) | **Impact:** ⭐⭐⭐⭐⭐ | **Effort:** Medium

---

### 2. 📖 Inline Dictionary Lookup
- [ ] When user selects a word, show a small popover with the definition
- [ ] macOS: Use Apple Dictionary Services API (`DCSCopyTextDefinition`) — renders returned HTML in a small WKWebView popover. Zero bloat, uses system dictionaries.
- [ ] iOS (Flutter): Platform channel to `UIReferenceLibraryViewController` — shows native iOS definition card
- [ ] Android (Flutter): Embed lightweight WordNet (~3MB) as fallback, with option for online Wiktionary API
- [ ] "Look Up" context menu action on selected text in reader
- [ ] Lookup history (recent words) — optional, can be modeled as a separate feature
- **Platforms:** Both
- **Impact:** ⭐⭐⭐⭐⭐ | **Effort:** Medium
- **Notes:** Embedded in-app experience, no external app launch. System dictionaries = zero bundle bloat. Online Wiktionary API as fallback when no system dictionary available.

### 3. 🔊 Text-to-Speech
- [ ] Play/pause TTS controls in reader bottom bar
- [ ] Speed control (0.5x–2x)
- [ ] Voice selection (system voices)
- [ ] Skip forward/back by sentence
- [ ] Highlight current word as spoken (AVSpeechSynthesizerDelegate)
- [ ] Auto-page-turn when TTS reaches end of visible page
- **Platforms:** Both
- **Impact:** ⭐⭐⭐⭐ | **Effort:** Medium
- **Notes:** macOS/iOS have high-quality neural voices built in. Flutter uses `flutter_tts` or platform channels.

### 4. 🔍 Full-Text Search Within a Book
- [ ] Search bar in reader (⌘F shortcut)
- [ ] Extract chapter text, build in-memory search index on first search
- [ ] Show results with chapter title + snippet + page reference
- [ ] Tap result → navigate to passage (reuse existing fragment navigation)
- [ ] PDF: use PDFKit's `PDFDocument.findString()`
- [ ] "Skim" bar to browse results without closing reader
- **Platforms:** Both
- **Impact:** ⭐⭐⭐⭐ | **Effort:** Medium

### 5. 📝 Export Highlights & Notes
- [ ] Export formats: Markdown, Plain Text, CSV, PDF
- [ ] Group by chapter with page references
- [ ] Share via NSSharingServicePicker / system share sheet
- [ ] Export single book or all books
- **Platforms:** Both
- **Impact:** ⭐⭐⭐⭐ | **Effort:** Low

---

## Tier 2 — Medium Impact

### 6. 🎯 Reading Goals & Milestones
- [ ] Yearly book goal (e.g., "Read 24 books in 2025")
- [ ] Daily page goal (e.g., "30 pages/day")
- [ ] Progress rings/bars on home screen
- [ ] Celebration on milestone completion
- [ ] Gentle optional notifications
- **Impact:** ⭐⭐⭐ | **Effort:** Low

### 7. 🌙 Enhanced Reading Themes
- [ ] Custom theme creator (pick any background + text color)
- [ ] Line spacing fine control (visible slider)
- [ ] Paragraph spacing control
- [ ] Text alignment (justify/left/center/right)
- [ ] Per-book settings persistence (novel = Literata 20px, textbook = System 16px)
- **Impact:** ⭐⭐⭐ | **Effort:** Low

### 8. 📱 Home Screen Widgets
- [ ] "Currently Reading" widget showing book cover + progress
- [ ] Lock screen widget (iOS)
- [ ] Menu bar item (macOS) showing current book
- **Impact:** ⭐⭐⭐ | **Effort:** Medium

### 9. 📚 OPDS Catalog Improvements
- [ ] One-tap download + auto-import from catalog
- [ ] Search within OPDS feeds
- [ ] Personal recommendations based on reading history
- **Impact:** ⭐⭐⭐ | **Effort:** Low

### 10. 🔖 Vocabulary Builder / Spaced Repetition
- [ ] Auto-save dictionary lookups to `VocabularyWord` model
- [ ] Review mode: show word → tap to reveal definition
- [ ] Spaced-repetition scheduling (Anki-style intervals)
- [ ] Import/export to Anki CSV
- [ ] Context sentence from the book where word was looked up
- **Impact:** ⭐⭐⭐ | **Effort:** Medium
- **Depends on:** Feature #2 (Dictionary Lookup)

---

## Tier 3 — Nice-to-Have

### 11. 🔄 Auto-Scroll / Continuous Scroll Mode
- [ ] Vertical scrolling as alternative to column pagination
- [ ] Speed-configurable auto-scroll
- **Impact:** ⭐⭐ | **Effort:** Medium

### 12. ⌨️ Keyboard Shortcuts Reference
- [ ] ⌘⇧/ overlay showing all reader shortcuts
- [ ] Searchable command palette
- **Impact:** ⭐ | **Effort:** Low

---

## Technical Backlog (from previous review)

- [ ] Unit/integration tests for macOS app (0% coverage)
- [ ] Accessibility semantics on key widgets
- [ ] Localization / i18n (all strings hardcoded English)
- [ ] Sync error handling (retry with backoff, surface failures)
- [ ] Split `ReaderView.swift` into smaller components (~800+ lines)
- [ ] Server-side validation for bookmarks, highlights, collections
- [ ] CSP/sandboxing for WebView HTML content