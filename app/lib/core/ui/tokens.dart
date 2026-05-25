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
  // Desaturated from the original #6B4EFF — same violet hue but more ink-like,
  // less electric. Feels like faded bookshop signage rather than a tech product.
  static const violet    = Color(0xFF5548C8); // primary accent
  static const coral     = Color(0xFFD4703A); // warm amber-coral (toned down)

  // Light surfaces — warmer, more aged-paper than pure off-white
  static const cream      = Color(0xFFF5F0E8); // scaffold / page bg
  static const paper      = Color(0xFFFAF7F2); // card / panel bg (prev cream)
  static const paperWarm  = Color(0xFFF0EAE0); // sidebar / slightly deeper
  static const paperDim   = Color(0xFFE8E2D9); // dividers, borders

  // Light text — warm ink, not cold neutral
  static const ink        = Color(0xFF1E1A17); // primary text
  static const inkMuted   = Color(0xFF5C5652); // secondary text
  static const inkFaint   = Color(0xFFA09890); // placeholder / disabled

  // Dark surfaces — warm night tones (unchanged, already warm)
  static const nightBase  = Color(0xFF1A1816); // scaffold / page bg
  static const nightCard  = Color(0xFF252220); // card / panel bg
  static const nightPanel = Color(0xFF1F1D1B); // sidebar

  // Dark text
  static const moonlight  = Color(0xFFE8E4DF);
  static const moonMuted  = Color(0xFF8C857D);

  // Semantic
  static const successGreen = Color(0xFF2A7D4F);
  static const errorRed     = Color(0xFFB83232);
  static const warningAmber = Color(0xFFD97706);

  // Reader themes (bg / fg pairs)
  static const readerLightBg  = paper;
  static const readerLightFg  = Color(0xFF2C2520);
  static const readerDarkBg   = nightBase;
  static const readerDarkFg   = Color(0xFFD5D0CA);
  static const readerSepiaBg  = Color(0xFFF4ECD8);
  static const readerSepiaFg  = Color(0xFF5B4636);
}

// ── Spacing ───────────────────────────────────────────────────────────────────
/// 4-pt base grid.

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
  static const double pagePadding   = s6;
  static const double panelPadding  = s4;
  static const double cardPadding   = s3;
  static const double tileVPadding  = s2;
  static const double sectionGap    = s6;
  static const double itemGap       = s2;
}

// ── Border radius ─────────────────────────────────────────────────────────────

class MokuRadius {
  MokuRadius._();

  static const double xs  =  4;
  static const double sm  =  6;
  static const double md  =  8;  // Tighter than before — less bubbly
  static const double lg  = 12;
  static const double xl  = 16;
  static const double pill = 999;

  static BorderRadius get xsAll  => BorderRadius.circular(xs);
  static BorderRadius get smAll  => BorderRadius.circular(sm);
  static BorderRadius get mdAll  => BorderRadius.circular(md);
  static BorderRadius get lgAll  => BorderRadius.circular(lg);
  static BorderRadius get xlAll  => BorderRadius.circular(xl);
}

// ── Type scale ────────────────────────────────────────────────────────────────

class MokuTypeSize {
  MokuTypeSize._();

  static const double micro  = 10;
  static const double tiny   = 11;
  static const double small  = 12;
  static const double body   = 13;
  static const double bodyM  = 14;
  static const double title  = 16;
  static const double h3     = 20;  // Was 18 — larger contrast
  static const double h2     = 26;  // Was 22 — larger contrast
  static const double h1     = 34;  // Was 28 — for hero stats
}

// ── Elevation / shadow ────────────────────────────────────────────────────────

class MokuShadow {
  MokuShadow._();

  static List<BoxShadow> get card => [
    BoxShadow(
      color: MokuColors.ink.withValues(alpha: 0.05),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get panel => [
    BoxShadow(
      color: MokuColors.ink.withValues(alpha: 0.03),
      blurRadius: 3,
      offset: const Offset(0, 1),
    ),
  ];
}
