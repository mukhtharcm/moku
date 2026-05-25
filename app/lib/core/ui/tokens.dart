/// Moku design tokens — single source of truth for every colour, spacing
/// step, border radius, and type size used across the app.
///
/// Import this file (and nothing else) when you need a raw value.
/// For Flutter ThemeData use MokuTheme; for text styles use MokuText.
library;

import 'package:flutter/material.dart';

// ── Palette ──────────────────────────────────────────────────────────────────

class MokuColors {
  MokuColors._();

  // Brand
  static const violet    = Color(0xFF6B4EFF); // primary accent
  static const coral     = Color(0xFFFF8A65); // warm secondary

  // Light surfaces
  static const cream      = Color(0xFFFAF7F2); // scaffold / page bg
  static const paper      = Color(0xFFFFFBF7); // card / panel bg
  static const paperDim   = Color(0xFFF5F1EB); // slightly darker panel

  // Light text
  static const ink        = Color(0xFF1C1917); // body text
  static const inkMuted   = Color(0xFF6B6460); // secondary text
  static const inkFaint   = Color(0xFFB0A99E); // placeholder / disabled

  // Dark surfaces
  static const nightBase  = Color(0xFF1A1816); // scaffold / page bg
  static const nightCard  = Color(0xFF252220); // card / panel bg
  static const nightPanel = Color(0xFF1F1D1B); // sidebar / secondary panel

  // Dark text
  static const moonlight  = Color(0xFFE8E4DF); // body text (dark)
  static const moonMuted  = Color(0xFF8C857D); // secondary (dark)

  // Semantic (light)
  static const successGreen = Color(0xFF22C55E);
  static const errorRed     = Color(0xFFEF4444);
  static const warningAmber = Color(0xFFF59E0B);

  // Reader themes (bg / fg pairs)
  static const readerLightBg  = paper;
  static const readerLightFg  = Color(0xFF2C2520);
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
  static const double panelPadding  = s4;   // sidebar / panel inset
  static const double cardPadding   = s3;   // inside a card
  static const double tileVPadding  = s2;   // list tile vertical
  static const double sectionGap    = s6;   // between major sections
  static const double itemGap       = s2;   // between adjacent items
}

// ── Border radius ─────────────────────────────────────────────────────────────

class MokuRadius {
  MokuRadius._();

  static const double xs  =  4;
  static const double sm  =  6;
  static const double md  = 10;
  static const double lg  = 14;
  static const double xl  = 20;
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

  static const double micro  = 10;
  static const double tiny   = 11;
  static const double small  = 12;
  static const double body   = 13;
  static const double bodyM  = 14;
  static const double title  = 16;
  static const double h3     = 18;
  static const double h2     = 22;
  static const double h1     = 28;
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
