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

### 2. 📖 Inline Dictionary Lookup (Downloadable Dictionaries)

**Approach: No bundled dictionaries. Users download in-app from a curated catalog.**

#### Dictionary Format: StarDict (.ifo + .idx + .dict/.dict.dz)
- Industry standard for e-readers (KOReader, Foliate, GoldenDict, ColorDict all use it)
- Well-documented binary format: `.ifo` (metadata), `.idx` (sorted word index), `.dict` (definitions)
- Supports HTML-formatted definitions for rich display
- Tons of free dictionaries available (Wiktionary, FreeDict, WikDict)

#### Dictionary Catalog (built into app)
- [ ] Curated list of free dictionaries sourced from:
  - **reader-dict/monolingual** — daily Wiktionary dumps in StarDict format (20+ languages)
  - **WikDict** — free bilingual StarDict dictionaries
  - **FreeDict** — public domain English dictionaries (Webster's 1913, etc.)
- [ ] Catalog JSON hosted on Moku server or GitHub (lightweight, ~10KB)
- [ ] Each entry: language, name, description, download URL, size, license
- [ ] UI: "Dictionaries" section in Settings — browse by language, tap to download, shows installed/available

#### StarDict Parser (needs to be written — no Swift/Dart libs exist)
- [ ] macOS: Write `StarDictParser.swift` — reads .ifo metadata, loads .idx into memory for binary search, seeks into .dict for definitions
- [ ] Flutter: Write `stardict_parser.dart` — same logic in Dart
- [ ] Support compressed .dict.dz (dictzip/zlib decompression)
- [ ] Support HTML entries (sanitize and render in WKWebView/WebView)
- [ ] Support plain-text entries (render as formatted Text)

#### Dictionary Lookup UX
- [ ] Select a word in reader → show small definition popover
- [ ] Render HTML definitions in a small WKWebView (macOS) or WebView (Flutter)
- [ ] If multiple dictionaries match, show tabs/arrows to switch between them
- [ ] "Look Up" context menu action on selected text
- [ ] Lookup history (recent words) accessible from reader menu
- [ ] "No dictionary installed" state → prompt user to download one from Settings

#### Custom Dictionary Import
- [ ] Drag & drop or file picker to import custom StarDict .tar.bz2 / .zip files
- [ ] Also support importing from OPDS feeds that provide dictionaries

#### Fallback: System Dictionary (macOS only, zero-effort)
- [ ] macOS: Additionally offer `DCSCopyTextDefinition()` as a fallback when no StarDict dict is installed
- [ ] This gives instant definitions on macOS without any download, but limited to system languages

**Platforms:** Both | **Impact:** ⭐⭐⭐⭐⭐ | **Effort:** Medium-High
**Notes:** Zero bloat on install. Users only download what they need. StarDict is the e-reader standard. KOReader does this exact approach with great success.

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