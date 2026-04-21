# Moku Feature Roadmap

> Prioritized from internet research across competitor apps (KOReader, Readest, Moon+ Reader, justRead, FolioReaderKit, Bookly, StoryGraph, Leaf, Readmaze, Bookie) and open-source issue trackers.

---

## Tier 1 — High Impact

### 1. 📊 Reading Statistics & Streak Tracking
- [ ] Reading streak: consecutive days with reading activity (flame icon, streak count)
- [ ] Session tracking: pages read per session, time spent, average reading speed
- [ ] Aggregated stats: books finished, total pages read, total time, average session length
- [ ] Activity heatmap: calendar-style grid showing daily reading activity
- [ ] Book completion percentage on library cards
- [ ] Data model: `ReadingSession` (SwiftData), computed stats
- [ ] New "Stats" tab/sheet in library, accessible from sidebar
- **Platforms:** Both (macOS + Flutter)
- **Impact:** ⭐⭐⭐⭐⭐ | **Effort:** Medium

### 2. 📖 Inline Dictionary Lookup
- [ ] When user selects a word, show a small popover with the definition
- [ ] Use Apple Dictionary Services API (`DCSCopyTextDefinition`) on macOS — zero bloat, uses system dictionaries
- [ ] Use `UIReferenceLibraryViewController` on iOS — same, zero bloat
- [ ] Flutter: platform channels to native dictionary, or embed lightweight WordNet (~3MB compressed)
- [ ] "Look Up" context menu item on selected text
- [ ] Lookup history (recent words) accessible from reader menu
- **Platforms:** Both
- **Impact:** ⭐⭐⭐⭐⭐ | **Effort:** Medium
- **Notes:** Embedded in-app experience, no external app launch. System dictionaries = zero bundle bloat. Fallback to online Wiktionary API if no system dictionary available.

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