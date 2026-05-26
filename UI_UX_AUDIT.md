# Moku — UI/UX Audit & Desktop Identity Plan

> Date: 2026-05-25  •  Scope: Flutter app (`app/`), all platforms, with a
> particular focus on Linux/macOS/Windows desktop.

## 1. Audit findings

### 1.1 The app reads as "generic Material 3"

Walking through the live Linux build today, the surface area that most
strongly screams *Flutter* is the **decorative chrome**, not the layout:

| Symptom                              | Where it shows up                                                   |
| ------------------------------------ | ------------------------------------------------------------------- |
| Purple `primaryContainer` pill on every selection      | Sidebar rows, nav rail items, settings list, ToC, search results    |
| 20–24 px card radius                 | Library cards, dialogs, bottom sheets, panels                       |
| Pill-shaped 16 px fully-rounded `TextField` | Library search, discover search, settings inputs                    |
| Big "tonal" FilledButton with 14 px radius + 14 px vertical pad | Import button, Open Book, every primary action     |
| `FloatingActionButton.extended`      | Reader UI                                                            |
| `NavigationBar` / `NavigationRail` defaults | Mobile + tablet shells                                          |
| `Material 3` ripple + state-layer animations everywhere | Touch feedback on hover-only surfaces                  |
| `Literata` + `Inter`                 | App-wide                                                            |

Meanwhile the **marketing website** (`website/index.html`) already
established a much more distinctive identity:

* Fonts: **Instrument Serif** + **DM Sans** (+ Crimson Pro for blockquote)
* Palette: warm ink `#1a1612`, paper `#f7f3ec`, **rust** `#c4653a`, **teal**
  `#2a6f6a`, plus the existing violet and coral.
* Hairline rules at `rgba(26,22,18,0.08)`.
* 6 px corner radii, dense type, ink-on-paper aesthetic.

So the app is paying for a brand it isn't wearing. This PR fixes that.

### 1.2 Desktop layout reads as "phone in a window"

Issues specific to the ≥1000 px breakpoint:

* **Icon rail** is 72 px wide with 12 px-rounded purple pills — closer to
  Material You phone NavigationRail than to Finder / Linear / Things / Mail.
* **Sidebar selection** uses `primaryContainer` (translucent violet) — desktop
  apps universally use a neutral grey or subdued accent for row selection.
* **Search fields** are fully rounded — desktop search fields are square
  with a 4–6 px radius and a hairline border.
* **Buttons** are 28 px-tall colorful pills — desktop apps lean on small,
  outlined or text-style buttons with 4–6 px radii.
* **Cards** have 20 px radii and inset margins — desktops tend toward
  panel-flat surfaces with hairline rules.
* **AppBar / scaffold** still applies mobile padding and `centerTitle: false`
  with 22 px serif headings — fine for phones, oversized on a 1440 px window.
* **Welcome / detail pane** centers a 560-wide column inside a multi-thousand
  pixel pane, leaving acres of unused space.

### 1.3 What we keep

* The 3-pane shell (icon rail / context sidebar / main pane) is correct.
* Existing design-system primitives (`MokuPanelHeader`, `MokuPanelItem`,
  `MokuSpacing`, `MokuRadius`) are a good base — we tighten them, we don't
  replace them.
* `MokuText` API is good; just swap the underlying fonts.

## 2. Identity direction

Synthesize from the website so the brand reads as **one product**:

* **Type**: Instrument Serif (display/book titles), DM Sans (UI body).
* **Palette**:
  - Ink `#1A1612`  •  Paper `#F7F3EC`  •  Paper-warm `#EFE8DC`
  - Accent rust `#C4653A` (primary action / selection accent)
  - Accent teal `#2A6F6A` (secondary, progress)
  - Violet `#6B4EFF` kept as legacy brand mark only (logo / hero gradient)
  - Coral `#FF8A65` as a warm highlight
  - Hairline rule: `ink @ 8 %` light / `paper @ 12 %` dark
* **Geometry**: 6 px is the new "default" radius. Pills only for badges.
* **Density**: desktop rail 56 px, row height 26–28 px, search field 26 px tall.

## 3. Plan

### 3.1 Core token refresh (cross-platform)
* `core/ui/tokens.dart` — refresh palette, replace radii with desktop-friendly
  steps (xs 3, sm 5, md 7, lg 10, xl 14), add `MokuColors.rust`/`teal` etc.
* `core/ui/moku_text.dart` — swap `literata → instrumentSerif`, `inter → dmSans`.
* `core/theme/app_theme.dart` — re-derive ColorScheme from new tokens; tighten
  card / button / input / dialog radii; replace `primaryContainer` selection
  highlight with neutral `surfaceContainerHigh`.

### 3.2 Desktop overrides
* New `core/platform/moku_platform.dart` exposing `isDesktop`, `isMobile`,
  `useDesktopChrome(context)` (= native desktop OR width ≥ 1000).
* `app_theme.dart` adds `desktopOverrides(ThemeData base)` that tightens
  paddings, font sizes, button heights, input borders for desktop.
* Wired in `app.dart`.

### 3.3 Component refits
* `app_shell.dart`
  - Icon rail: 56 px wide, 32 px items, 5 px radius, neutral selection
    (`surfaceContainerHigh` + ink) with a 2 px rust accent bar on the left.
  - Sidebar width 240, full-width row selection.
* `core/ui/components/panel_components.dart`
  - `MokuPanelHeader`: no caps when used as a *page* header; thin rule;
    correct height.
  - `MokuPanelItem`: full-bleed selection rectangle (5 px radius, neutral
    bg, rust accent text), tighter vertical padding, 26 px row height.
* `library_sidebar.dart` — square search, sort menu in header, tighter rows.
* `library_detail_pane.dart` — desktop-aware padding; replace tonal pill
  with text-style buttons; rust accent for "Continue reading"; format badge
  as a hairline chip not a tonal pill.
* `settings_sidebar.dart` / `settings_detail_pane.dart` — match new style.

### 3.4 Verification
* Static analyzer clean.
* Linux desktop build screenshot pass: shell, empty state, populated state,
  settings, reader.
* Quick sanity run on Android emulator to confirm mobile shell still looks
  cohesive (nothing should break visually because the identity refresh also
  improves mobile).

## 4. Out of scope (follow-ups)
* Reader UI deep redesign (toolbar, ToC, dialogs) — separate PR.
* Replacing every screen's M3 `Card`/`Dialog`/`Snackbar` chrome — done through
  theme defaults only, not by widget rewrites, in this PR.
* macOS native app already uses the right vibe; minor color sync only if time.
