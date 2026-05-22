# Flutter Arabic Strategy

## Purpose

This document defines how Arabic should work in the Flutter app.

The goal is not "translate the UI into Arabic". The goal is:

- Arabic app chrome that behaves like a real RTL product
- English books that still read naturally inside that Arabic shell
- Arabic books that render correctly even when the app shell is English

In other words, app locale and reading content locale must be treated as separate concerns.

## Non-goals

This strategy does not imply:

- translating imported books
- rewriting imported metadata into the UI language
- OCR or language detection for scanned PDF/CBZ page images
- forcing all reading surfaces to mirror just because the app shell is Arabic

## Decisions

### 1. App locale and book locale are separate

The selected app locale controls:

- navigation
- settings
- labels
- dialogs
- onboarding
- empty states
- app-owned reader chrome

The book controls:

- content language
- content direction
- reader font group
- chapter/body alignment in the WebView reader
- page progression semantics when the format provides them

This means:

- Arabic app + English book is valid and must stay LTR in the reading surface.
- English app + Arabic book is valid and must stay RTL in the reading surface.

### 2. The first Arabic locale should be neutral `ar`

The first Arabic locale should be neutral Modern Standard Arabic, not a region-specific dialect.

Use:

- `app_ar.arb`

Do not start with:

- `ar_EG`
- `ar_SA`

Regional variants can come later if we need region-specific digits, wording, or formatting.

### 3. Reader direction must be content-driven

Reader direction must not be derived from the app shell locale alone.

Instead, resolve direction from the content itself using the best available signal in this order:

1. explicit manual override
2. format-level direction metadata
3. content-level language or `dir` metadata
4. stored book language
5. heuristic detection from the first meaningful text
6. default fallback

### 4. Mixed-direction strings need explicit handling

Any Arabic UI that embeds LTR data must be wrapped safely.

Examples:

- book titles
- author names
- filenames
- URLs
- version strings
- timestamps
- search queries

Use bidi-safe formatting, not raw string interpolation.

### 5. Preserve source language tags when the format provides them

When a format provides a language tag, store the full tag instead of collapsing it to a bare language code.

Examples:

- keep `en-GB` as `en-GB`
- keep `ar-SA` as `ar-SA`
- keep script-bearing tags if they appear

This keeps the door open for better typography, formatting, and regional behavior later without reimporting the library.

## Official Conventions This Strategy Follows

### Flutter

Flutter's localization delegates handle localized widgets and default text direction for supported locales. `GlobalWidgetsLocalizations.delegate` is the piece that sets widget-library text direction.

Source:

- https://docs.flutter.dev/ui/internationalization

### Bidi-safe inline strings

`intl` already provides `BidiFormatter` specifically for text inserted into opposite-direction contexts. That is the correct tool for Arabic UI containing English metadata or user content.

Source:

- https://api.flutter.dev/flutter/package-intl_intl/BidiFormatter-class.html

### HTML and bidi

W3C guidance is clear on two points that matter directly to this app's reader:

- set base direction with `dir`
- if injected text direction is unknown, use `dir="auto"` or `bdi`

Sources:

- https://www.w3.org/International/docs/bp-html-bidi/Overview
- https://www.w3.org/International/articles/inline-bidi-markup/index.en

### EPUB language and progression

EPUB 3.3 defines:

- `dc:language` as required metadata
- the first `dc:language` as the primary publication language
- publication resources do not inherit language from `dc:language`; resource language must be declared inside the resource format itself
- `page-progression-direction` as the global content flow direction

Sources:

- https://w3c.github.io/epub-specs/epub33/core/
- https://www.w3.org/TR/2021/WD-epub-rs-33-20210224/

### Number formatting

`intl`'s `NumberFormat` is locale-aware and exposes locale-specific zero-digit data. We should lean on locale formatting first, then override only if product needs differ.

Source:

- https://api.flutter.dev/flutter/package-intl_intl/NumberFormat-class.html

### Language tags

W3C's language-tag guidance follows BCP 47 for language identification. That should also be the normalization target for stored book language tags when the source format provides a valid one.

Source:

- https://www.w3.org/International/articles/language-tags/index.en

## Current Repo State

### Good news

The app already has the Flutter l10n foundation:

- [app/lib/app.dart](../app/lib/app.dart)

### Existing model support

The book model already has a language field:

- [app/lib/core/models/book.dart](../app/lib/core/models/book.dart)

The database already persists it:

- [app/lib/core/database/tables.dart](../app/lib/core/database/tables.dart)

EPUB import already reads language metadata from `dc:language`:

- [app/lib/core/epub/epub_parser.dart](../app/lib/core/epub/epub_parser.dart)
- [app/lib/core/services/epub_service.dart](../app/lib/core/services/epub_service.dart)

### Missing pieces

The content-direction model is still incomplete.

1. `Book.language` is not enough by itself.
   A book can be multilingual, or the UI can be Arabic while the actual chapter is English.

2. EPUB parsing currently extracts publication language, but not enough directionality data for the reader.
   The current parser does not surface:
   - document-level `dir`
   - chapter-level `lang`
   - `page-progression-direction`

3. HTML and TXT imports currently do not populate language at all.
   See:
   - [app/lib/core/formats/html/html_parser.dart](../app/lib/core/formats/html/html_parser.dart)
   - [app/lib/core/formats/txt/txt_parser.dart](../app/lib/core/formats/txt/txt_parser.dart)
   - [app/lib/core/services/book_service.dart](../app/lib/core/services/book_service.dart)

4. The reader WebView is still English-shaped.
   It currently:
   - injects Western font stacks
   - omits `lang` and `dir` on the generated HTML shell
   - uses physical CSS such as `border-left` and `padding-left`
   - assumes LTR-style page motion and left/right tap zones in the pagination script

   See:
   - [app/lib/features/reader/screens/reader_screen.dart](../app/lib/features/reader/screens/reader_screen.dart)
   - [app/lib/features/reader/cubit/reader_state.dart](../app/lib/features/reader/cubit/reader_state.dart)

5. The Flutter layout layer still has explicit physical-direction debt.
   A quick scan of `app/lib` on this branch found:
   - `3` uses of `Alignment.centerLeft` / `Alignment.centerRight`
   - `30` `left:` / `right:` positional usages
   - `3` `EdgeInsets.only(left/right: ...)` usages
   - `0` uses of `AlignmentDirectional`, `EdgeInsetsDirectional`, `BorderRadiusDirectional`, or `PositionedDirectional`

   That does not mean every screen is broken in RTL, but it does mean RTL behavior is still relying too much on English-shaped layout assumptions.

## Required Separation of Concerns

### App shell rules

The app shell follows the selected app locale.

If locale is Arabic:

- Flutter UI direction is RTL
- menus and settings are Arabic
- app typography should use Arabic-aware UI fonts

This is true even if the opened book is English.

### Reader content rules

The reading surface follows the book or chapter.

That means:

- content direction should be resolved per book, and ideally per chapter/resource when the format exposes it
- content font presets should be chosen based on content language/script, not app locale
- page flow semantics should respect format metadata where available

This is true even if the app chrome is Arabic.

### Metadata display rules

Book metadata should be shown as source data, not rewritten to match the app locale.

Examples:

- English title stays English in Arabic UI
- Arabic author name stays Arabic in English UI

The UI's job is to display metadata safely and legibly, not translate it.

## Recommended Reader Resolution Model

Resolve a `ReaderContentContext` before rendering a chapter.

Suggested fields:

- `appLocale`
- `bookLanguageTag`
- `resourceLanguageTag`
- `contentDirection`
- `pageProgressionDirection`
- `fontPresetGroup`
- `source`

Where `source` records how the direction was decided:

- manual override
- resource metadata
- book metadata
- heuristic
- fallback

This matters because direction bugs become much easier to debug if the reader can surface where the decision came from.

## Format-Specific Conventions

### EPUB

Use:

- first `dc:language` as the publication-level default
- chapter/resource language from the XHTML content itself when present
- `page-progression-direction` when present

Important convention:

- publication-level language is a fallback
- chapter/resource declarations win for actual rendering

That follows the EPUB spec more closely than assuming one book-wide direction forever.

### HTML / XHTML files

Use:

- root `lang`
- root `dir`
- chapter-level overrides if the content includes them

If direction is unknown for injected inline fragments, use `dir="auto"` or `bdi`.

### TXT

TXT has no reliable metadata, so it needs:

- heuristic script/direction detection
- manual override

Recommended first override options:

- Auto
- Left to right
- Right to left

### PDF

Do not try to reinterpret the page direction from rendered PDF content.

For PDF:

- keep the document rendering as-is
- localize only the surrounding reader chrome
- wrap metadata strings safely when shown in Arabic UI

### CBZ

The page images do not need text-direction logic, but the reader chrome still does.

Do not assume Arabic UI means reversed comic navigation automatically unless there is explicit product intent and format metadata to support it.

## Typography Conventions

### App chrome

Do not force the current Literata + Inter pairing onto Arabic.

For Arabic UI:

- use an Arabic-capable UI font family
- prefer a compact UI-oriented Arabic font for controls and labels

### Reader content

Do not reuse the app shell typography rules for body text.

Reader prose should have its own Arabic-friendly presets. The current reader presets are Western-only:

- `Georgia`
- `Times New Roman`
- `Helvetica Neue`
- `Arial`

See:

- [app/lib/features/reader/cubit/reader_state.dart](../app/lib/features/reader/cubit/reader_state.dart)

## Bidi and Inline Content Rules

### Use bidi-safe wrapping for user or imported strings

Whenever Arabic UI renders unknown-direction content, use `BidiFormatter`.

Typical surfaces:

- snackbar messages with book names
- delete confirmations
- selected-text previews
- annotations
- search input echoes
- sync logs

### Use markup in the WebView where possible

Inside the reader HTML:

- set `dir` on the document or container
- use `dir="auto"` or `bdi` for unknown inline fragments

If markup is not possible, use Unicode bidi formatting via `BidiFormatter.wrapWithUnicode`.

## Numerals and Formatting

We should not hardcode a digit system in v1.

Initial convention:

- use locale-aware formatting through `intl`
- verify actual Arabic rendering in screenshots
- only add regional overrides if product requirements demand them

This avoids baking one regional Arabic numeral preference into all Arabic users prematurely.

## What Should Change In Code Later

This PR is research-only, but these are the concrete code changes it points to.

### Data and parsing

- extend EPUB parsing to surface `page-progression-direction`
- extract HTML/XHTML `lang` and `dir`
- add TXT direction detection
- decide whether resolved direction should be stored or derived on open

### Reader

- generate `lang` and `dir` on the HTML shell
- replace physical CSS with logical or direction-aware CSS
- make page motion and tap-zone semantics direction-aware
- add bidi-safe metadata formatting
- add Arabic-aware font presets

### Layout

- replace physical left/right Flutter layout APIs with directional APIs where needed

### Product settings

- add a per-book reader direction override
- keep it scoped to the book or reading session, not global app locale

## Recommended Implementation Order

1. Add `app_ar.arb` and basic RTL test coverage.
2. Add the content-direction resolution layer for the reader.
3. Extend EPUB/HTML/TXT parsing to supply better language and direction signals.
4. Make the reader HTML/CSS direction-aware.
5. Make typography locale-aware.
6. Audit the remaining app shell layouts for directional APIs.
7. Run Arabic-shell + English-book and English-shell + Arabic-book smoke tests.

## Verification Matrix

At minimum, implementation should be checked against these scenarios:

### Arabic app shell

- Arabic UI + English EPUB:
  content stays LTR, metadata stays English, surrounding UI stays Arabic/RTL
- Arabic UI + Arabic EPUB:
  content is RTL, metadata is Arabic, chapter/page behavior respects book direction
- Arabic UI + English TXT:
  auto detection should resolve LTR or allow fast override
- Arabic UI + PDF:
  document rendering stays unchanged, chrome and metadata remain bidi-safe

### English app shell

- English UI + Arabic EPUB:
  content stays RTL inside an English UI shell
- English UI + Arabic HTML/XHTML:
  document `lang`/`dir` is honored
- English UI + mixed-language metadata:
  title/author snippets do not reorder surrounding UI text incorrectly

## Success Criteria

Arabic support is not done when the settings screen translates.

It is done when all of these are true:

- Arabic app chrome mirrors correctly
- English books remain comfortable to read in an Arabic UI
- Arabic books remain correct in an English UI
- imported metadata does not garble surrounding text
- number/date formatting is intentional, not accidental
- the reader chooses direction for a traceable reason
