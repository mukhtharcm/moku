# Changelog

All notable changes to Moku macOS app will be documented in this file.

## [1.1.0] — 2026-04-21

### Added
- **5-format reading** — EPUB, PDF, CBZ, TXT, and HTML files all supported
- **Font family selection** — Choose from Georgia, Literata, Merriweather, Lora, or System font
- **Horizontal margin control** — Adjust side margins from 16px to 96px
- **Highlight with note** — Add notes to highlights directly from the selection toolbar
- **Edit highlight notes** — Right-click any highlight in Annotations to add or edit a note
- **Collection detail view** — Tap a shelf to see its books, add/remove books, delete the shelf
- **Add books to collections** — Multi-select sheet to add library books to any shelf
- **Whole-book progress scrubber** — Drag across the entire book, not just within a chapter
- **Precise highlight navigation** — Tapping a highlight in Annotations scrolls to its exact position
- **Precise bookmark navigation** — Tapping a bookmark navigates to the exact chapter position
- **Scroll-to-highlight in WebView** — JavaScript `scrollToHighlightText()` for exact repositioning
- **Fragment-based navigation** — Support for `startPosition` (fraction/fragment) in the reader JS
- **OPDS catalog discovery** — Search Project Gutenberg and Open Library, add custom OPDS catalogs
- **Download books from catalog** — One-click download and import from discover results

### Fixed
- Version string in Settings now correctly shows 1.1.0 (was stale at 1.0.0)
- Collection cards now navigate to a detail view instead of being non-interactive

### Changed
- Reader settings sheet expanded to accommodate font family and margin controls
- Bottom bar now shows whole-book progress (% and chapter title) instead of chapter-only slider
- Annotations context menu for highlights includes "Edit Note" option

## [1.0.0] — 2026-04-19

### Added
- EPUB reading with paginated WebView renderer
- Library with grid/list views, drag-and-drop import
- Reader with multiple themes (light, dark, sepia)
- Font customization (size, line height)
- Highlights and bookmarks
- Shelves/Collections for organizing books
- Open Library book discovery
- Separate reader windows (open multiple books)
- Keyboard shortcuts (⌘O import, arrow keys for navigation)
- Warm bookish design language
- PocketBase sync support (optional)
- Onboarding flow