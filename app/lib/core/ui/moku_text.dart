/// MokuText — canonical text styles for the entire app.
///
/// Rules:
///   • Instrument Serif → book/chapter titles, page & section headings,
///                        hero numbers. Matches the website identity.
///   • DM Sans          → all UI chrome: labels, captions, body, buttons,
///                        metadata.
///
/// Use these helpers instead of calling GoogleFonts directly in widgets.
/// No widget should call GoogleFonts outside of this file and app_theme.dart.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tokens.dart';

class MokuText {
  MokuText._();

  // ── Serif (Instrument Serif) ─────────────────────────────────────────────

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

  /// Hero/display title — 34 px.  Onboarding welcome, landing-style moments.
  static TextStyle displayHeading({Color? color}) => _serif(
        fontSize: MokuTypeSize.display,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.6,
        height: 1.05,
        color: color,
      );

  /// Page/screen heading — 28 px.  AppBar titles, stats, section starters.
  static TextStyle pageHeading({Color? color}) => _serif(
        fontSize: MokuTypeSize.h1,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.4,
        height: 1.05,
        color: color,
      );

  /// Section heading inside a content pane — 22 px.
  static TextStyle sectionHeading({Color? color}) => _serif(
        fontSize: MokuTypeSize.h2,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.2,
        color: color,
      );

  /// Large book title — library detail pane hero, reader toolbar — 22 px.
  static TextStyle bookTitle({Color? color}) => _serif(
        fontSize: MokuTypeSize.h2,
        fontWeight: FontWeight.w400,
        height: 1.15,
        letterSpacing: -0.3,
        color: color,
      );

  /// Numeric display at an arbitrary serif size — stat tiles, streak numbers.
  static TextStyle serifNum(double fontSize,
          {Color? color, FontWeight weight = FontWeight.w400}) =>
      _serif(
        fontSize: fontSize,
        fontWeight: weight,
        height: 1.0,
        color: color,
      );

  // ── Sans (DM Sans) ───────────────────────────────────────────────────────

  static TextStyle _sans({
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
    Color? color,
  }) =>
      GoogleFonts.dmSans(
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        letterSpacing: letterSpacing,
        color: color,
      );

  /// Lead subtitle — 17 px, for onboarding slide subtitles.
  static TextStyle lead({Color? color, FontWeight weight = FontWeight.w400}) =>
      _sans(
        fontSize: MokuTypeSize.lead,
        fontWeight: weight,
        height: 1.4,
        color: color,
      );

  /// Compact book title — sidebar list items — 13 px DM Sans w600.
  static TextStyle bookTitleSmall({Color? color}) => _sans(
        fontSize: MokuTypeSize.body,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: color,
      );

  /// Primary body text in UI lists and cards — 14 px.
  static TextStyle body({Color? color, FontWeight weight = FontWeight.w400}) =>
      _sans(
        fontSize: MokuTypeSize.bodyM,
        fontWeight: weight,
        height: 1.5,
        color: color,
      );

  /// Smaller body — metadata, subtitles — 13 px.
  static TextStyle bodySmall(
          {Color? color, FontWeight weight = FontWeight.w400}) =>
      _sans(
        fontSize: MokuTypeSize.body,
        fontWeight: weight,
        height: 1.45,
        color: color,
      );

  /// Sidebar / panel item label — 14 px.
  static TextStyle panelItem({Color? color, bool selected = false}) => _sans(
        fontSize: MokuTypeSize.bodyM,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        height: 1.3,
        color: color,
      );

  /// Small label above a group (all-caps / tracked) — 12 px.
  static TextStyle sectionLabel({Color? color}) => _sans(
        fontSize: MokuTypeSize.small,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.7,
        color: color,
      );

  /// Caption / metadata — author names, dates, counts — 11 px.
  static TextStyle caption(
          {Color? color, FontWeight weight = FontWeight.w400}) =>
      _sans(
        fontSize: MokuTypeSize.tiny,
        fontWeight: weight,
        height: 1.3,
        color: color,
      );

  /// Micro label — badge counts, format chips — 10 px.
  static TextStyle micro({Color? color, FontWeight weight = FontWeight.w600}) =>
      _sans(
        fontSize: MokuTypeSize.micro,
        fontWeight: weight,
        letterSpacing: 0.4,
        color: color,
      );

  /// Button text — 13 px w600.
  static TextStyle button({Color? color}) => _sans(
        fontSize: MokuTypeSize.body,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: color,
      );
}
