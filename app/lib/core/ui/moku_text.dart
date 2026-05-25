/// MokuText — canonical text styles for the entire app.
///
/// Rules:
///   • Instrument Serif → book/chapter titles, page & section headings,
///                        hero numbers. Matches the website identity.
///   • DM Sans          → all UI chrome: labels, captions, body, buttons,
///                        metadata.
///
/// Use these helpers instead of calling GoogleFonts directly in widgets.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tokens.dart';

class MokuText {
  MokuText._();

  // ── Serif (display / bookish) ────────────────────────────────────────────

  static TextStyle _serif({
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
    Color? color,
  }) =>
      GoogleFonts.instrumentSerif(
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        letterSpacing: letterSpacing,
        color: color,
      );

  /// Large book title — library detail pane hero, reader toolbar.
  static TextStyle bookTitle({Color? color}) => _serif(
        fontSize: MokuTypeSize.h2,
        fontWeight: FontWeight.w400,
        height: 1.15,
        letterSpacing: -0.3,
        color: color,
      );

  /// Compact book title — sidebar list items.
  static TextStyle bookTitleSmall({Color? color}) => GoogleFonts.dmSans(
        fontSize: MokuTypeSize.body,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: color,
      );

  /// Page/screen heading — "Library", "Settings", stats title.
  static TextStyle pageHeading({Color? color}) => _serif(
        fontSize: MokuTypeSize.h1,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.4,
        height: 1.05,
        color: color,
      );

  /// Section heading inside a content pane.
  static TextStyle sectionHeading({Color? color}) => _serif(
        fontSize: MokuTypeSize.h3 + 4,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.2,
        color: color,
      );

  // ── Sans (DM Sans / UI) ──────────────────────────────────────────────────

  /// Primary body text in UI lists and cards.
  static TextStyle body({Color? color, FontWeight weight = FontWeight.w400}) =>
      GoogleFonts.dmSans(
        fontSize: MokuTypeSize.bodyM,
        fontWeight: weight,
        height: 1.5,
        color: color,
      );

  /// Smaller body — metadata, subtitles.
  static TextStyle bodySmall({Color? color, FontWeight weight = FontWeight.w400}) =>
      GoogleFonts.dmSans(
        fontSize: MokuTypeSize.body,
        fontWeight: weight,
        height: 1.45,
        color: color,
      );

  /// Sidebar / panel item label.
  static TextStyle panelItem({Color? color, bool selected = false}) =>
      GoogleFonts.dmSans(
        fontSize: MokuTypeSize.bodyM,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        height: 1.3,
        color: color,
      );

  /// Small label above a group (all-caps / tracked).
  static TextStyle sectionLabel({Color? color}) => GoogleFonts.dmSans(
        fontSize: MokuTypeSize.small,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.7,
        color: color,
      );

  /// Caption / metadata — author names, dates, counts.
  static TextStyle caption({Color? color}) => GoogleFonts.dmSans(
        fontSize: MokuTypeSize.tiny,
        fontWeight: FontWeight.w400,
        height: 1.3,
        color: color,
      );

  /// Micro label — badge counts, format chips.
  static TextStyle micro({Color? color, FontWeight weight = FontWeight.w600}) =>
      GoogleFonts.dmSans(
        fontSize: MokuTypeSize.micro,
        fontWeight: weight,
        letterSpacing: 0.4,
        color: color,
      );

  /// Button text.
  static TextStyle button({Color? color}) => GoogleFonts.dmSans(
        fontSize: MokuTypeSize.body,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: color,
      );
}
