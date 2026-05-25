/// MokuText — canonical text styles for the entire app.
///
/// Rules:
///   • Literata → book/chapter titles, section headings, hero numbers
///   • Inter    → all UI chrome: labels, captions, body, buttons, metadata
///
/// Use these helpers instead of calling GoogleFonts directly in widgets.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tokens.dart';

class MokuText {
  MokuText._();

  // ── Literata (serif / bookish) ───────────────────────────────────────────

  /// Large book title — library detail pane hero, reader toolbar.
  static TextStyle bookTitle({Color? color}) => GoogleFonts.literata(
        fontSize: MokuTypeSize.title,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: -0.2,
        color: color,
      );

  /// Compact book title — sidebar list items.
  static TextStyle bookTitleSmall({Color? color}) => GoogleFonts.literata(
        fontSize: MokuTypeSize.small,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: color,
      );

  /// Page/screen heading — "Library", "Settings", stats title.
  static TextStyle pageHeading({Color? color}) => GoogleFonts.literata(
        fontSize: MokuTypeSize.h2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: color,
      );

  /// Section heading inside a content pane.
  static TextStyle sectionHeading({Color? color}) => GoogleFonts.literata(
        fontSize: MokuTypeSize.h3,
        fontWeight: FontWeight.w600,
        color: color,
      );

  // ── Inter (sans / UI) ────────────────────────────────────────────────────

  /// Primary body text in UI lists and cards.
  static TextStyle body({Color? color, FontWeight weight = FontWeight.w400}) =>
      GoogleFonts.inter(
        fontSize: MokuTypeSize.bodyM,
        fontWeight: weight,
        height: 1.5,
        color: color,
      );

  /// Smaller body — metadata, subtitles.
  static TextStyle bodySmall({Color? color, FontWeight weight = FontWeight.w400}) =>
      GoogleFonts.inter(
        fontSize: MokuTypeSize.body,
        fontWeight: weight,
        height: 1.45,
        color: color,
      );

  /// Sidebar / panel item label.
  static TextStyle panelItem({Color? color, bool selected = false}) =>
      GoogleFonts.inter(
        fontSize: MokuTypeSize.body,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        height: 1.3,
        color: color,
      );

  /// Small label above a group (all-caps / tracked).
  static TextStyle sectionLabel({Color? color}) => GoogleFonts.inter(
        fontSize: MokuTypeSize.tiny,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.7,
        color: color,
      );

  /// Caption / metadata — author names, dates, counts.
  static TextStyle caption({Color? color}) => GoogleFonts.inter(
        fontSize: MokuTypeSize.tiny,
        fontWeight: FontWeight.w400,
        height: 1.3,
        color: color,
      );

  /// Micro label — badge counts, format chips.
  static TextStyle micro({Color? color, FontWeight weight = FontWeight.w600}) =>
      GoogleFonts.inter(
        fontSize: MokuTypeSize.micro,
        fontWeight: weight,
        letterSpacing: 0.3,
        color: color,
      );

  /// Button text.
  static TextStyle button({Color? color}) => GoogleFonts.inter(
        fontSize: MokuTypeSize.bodyM,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: color,
      );
}
