/// Moku design tokens — single source of truth for every colour, spacing
/// step, border radius, and type size used across the app.
///
/// Import this file (and nothing else) when you need a raw value.
/// For Flutter ThemeData use MokuTheme; for text styles use MokuText.
library;

import 'package:flutter/material.dart';

// ── Palette ──────────────────────────────────────────────────────────────────
//
// Moku's identity is **warm ink on warm paper**, lifted by rust + teal
// accents and a residual violet brand mark. These are the exact tokens
// used on the marketing site (`website/index.html`), so the product and
// the brand read as the same thing.

class MokuColors {
  MokuColors._();

  // Brand marks (kept for hero / app icon)
  static const violet    = Color(0xFF6B4EFF);
  static const coral     = Color(0xFFFF8A65);

  // Primary accents (active UI)
  static const rust      = Color(0xFFC4653A); // primary action, selection text
  static const rustDeep  = Color(0xFFA8542E); // hover / pressed
  static const teal      = Color(0xFF2A6F6A); // secondary accent, progress
  static const tealDeep  = Color(0xFF1F5450);

  // Light surfaces (ink-on-paper)
  static const paper      = Color(0xFFF7F3EC); // scaffold / page bg
  static const paperWarm  = Color(0xFFEFE8DC); // raised surface / sidebar
  static const paperDim   = Color(0xFFE5DDCE); // pressed / hover
  static const paperWhite = Color(0xFFFFFCF6); // card / detail surface

  // Light text
  static const ink        = Color(0xFF1A1612); // body text
  static const inkMuted   = Color(0xFF6A625A); // secondary text
  static const inkFaint   = Color(0xFF9A918A); // placeholder / disabled
  static const inkRule    = Color(0x141A1612); // hairline rule (8 %)

  // Dark surfaces
  static const nightBase  = Color(0xFF14110E); // scaffold / page bg
  static const nightPanel = Color(0xFF1B1814); // sidebar / secondary panel
  static const nightCard  = Color(0xFF221E18); // card / detail surface
  static const nightRaise = Color(0xFF2A251E); // selection / hover

  // Dark text
  static const moonlight  = Color(0xFFEDE6DA); // body text (dark)
  static const moonMuted  = Color(0xFF9C9388); // secondary text (dark)
  static const moonRule   = Color(0x1EEDE6DA); // hairline rule (12 %)

  // Semantic
  static const successGreen = Color(0xFF3F8F5C);
  static const errorRed     = Color(0xFFC0392B);
  static const warningAmber = Color(0xFFD18E2C);
  static const infoBlue     = Color(0xFF3B82F6);  // sync info / connected

  // Stats accent palette — icon badge tints
  static const statBlue   = Color(0xFF3B82F6);
  static const statGreen  = Color(0xFF22C55E);
  static const statPurple = Color(0xFFA855F7);
  static const statFire   = Color(0xFFE6621E);  // current streak
  static const statGold   = Color(0xFFD4A017);  // longest streak

  // Reader themes (bg / fg pairs)
  static const readerLightBg  = paperWhite;
  static const readerLightFg  = Color(0xFF1A1612);
  static const readerDarkBg   = nightBase;
  static const readerDarkFg   = Color(0xFFD5D0CA);
  static const readerSepiaBg  = Color(0xFFF4ECD8);
  static const readerSepiaFg  = Color(0xFF5B4636);
}

// ── Spacing ───────────────────────────────────────────────────────────────────
/// 4-pt base grid. Use these instead of naked numbers.

class MokuSpacing {
  MokuSpacing._();

  static const double s1  =  4;
  static const double s2  =  8;
  static const double s3  = 12;
  static const double s4  = 16;
  static const double s5  = 20;
  static const double s6  = 24;
  static const double s8  = 32;
  static const double s10 = 40;
  static const double s12 = 48;

  // Semantic aliases
  static const double pagePadding   = s6;   // main content horizontal inset
  static const double panelPadding  = s3;   // sidebar / panel inset (was s4)
  static const double cardPadding   = s3;   // inside a card
  static const double tileVPadding  = s2;   // list tile vertical
  static const double sectionGap    = s6;   // between major sections
  static const double itemGap       = s2;   // between adjacent items
}

// ── Border radius ─────────────────────────────────────────────────────────────
//
// Tightened to a desktop-friendly scale. Pills only for badges.

class MokuRadius {
  MokuRadius._();

  static const double xs  =  3;
  static const double sm  =  5;
  static const double md  =  7;
  static const double lg  = 10;
  static const double xl  = 14;
  static const double pill = 999;

  static BorderRadius get xsAll  => BorderRadius.circular(xs);
  static BorderRadius get smAll  => BorderRadius.circular(sm);
  static BorderRadius get mdAll  => BorderRadius.circular(md);
  static BorderRadius get lgAll  => BorderRadius.circular(lg);
  static BorderRadius get xlAll  => BorderRadius.circular(xl);
}

// ── Type scale ────────────────────────────────────────────────────────────────
/// Font sizes only. For full TextStyle use MokuText.

class MokuTypeSize {
  MokuTypeSize._();

  static const double micro   = 10;
  static const double tiny    = 11;
  static const double small   = 12;
  static const double body    = 13;
  static const double bodyM   = 14;
  static const double lead    = 17;  // onboarding subtitles
  static const double title   = 16;
  static const double h3      = 18;
  static const double h2      = 22;
  static const double h1      = 28;
  static const double display = 34;  // hero moments
}

// ── Elevation / shadow ────────────────────────────────────────────────────────

class MokuShadow {
  MokuShadow._();

  static List<BoxShadow> get card => [
    BoxShadow(
      color: MokuColors.ink.withValues(alpha: 0.06),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get panel => [
    BoxShadow(
      color: MokuColors.ink.withValues(alpha: 0.04),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];
}

// ── Motion ────────────────────────────────────────────────────────────────────
/// Standard animation durations. Use these instead of naked millisecond values.
class MokuMotion {
  MokuMotion._();

  /// Micro-interaction — selection highlight, toggle. 120 ms.
  static const Duration instant = Duration(milliseconds: 120);

  /// UI state transition — panel appear/hide, chip select. 200 ms.
  static const Duration fast = Duration(milliseconds: 200);

  /// Page element entrance — card slide, icon swap. 300 ms.
  static const Duration normal = Duration(milliseconds: 300);

  /// Screen-level transition — page push/pop, sheet reveal. 400 ms.
  static const Duration slow = Duration(milliseconds: 400);

  /// Long animation — onboarding carousel, splash fade. 600 ms.
  static const Duration xslow = Duration(milliseconds: 600);
}
