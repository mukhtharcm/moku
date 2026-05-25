/// MokuAppColors — ThemeExtension that carries all semantic colours for the
/// Moku UI. Modelled directly after Sidemesh's AppColors pattern.
///
/// Access anywhere with: `final colors = context.colors;`
/// Never call `colors.textSecondary` in
/// widgets — use `colors.textSecondary` instead.
library;

import 'package:flutter/material.dart';
import '../../../core/ui/ui.dart';

@immutable
class MokuAppColors extends ThemeExtension<MokuAppColors> {
  const MokuAppColors({
    // Surfaces
    required this.canvas,          // page / scaffold background
    required this.surface,         // card / panel background
    required this.surfaceElevated, // slightly raised surface (hover, etc.)
    required this.surfaceMuted,    // dim surface, sidebars
    // Borders
    required this.border,          // subtle divider / outline
    required this.borderStrong,    // visible border for inputs / groups
    // Text
    required this.textPrimary,     // headings, body, active items
    required this.textSecondary,   // supporting labels, metadata
    required this.textTertiary,    // placeholders, very muted captions
    // Accent
    required this.accent,          // primary action / selection colour
    required this.accentMuted,     // tinted accent background for chips, etc.
    required this.accentOn,        // text on top of accent colour
    // Status
    required this.success,
    required this.successMuted,
    required this.danger,
    required this.dangerMuted,
    required this.warning,
    required this.warningMuted,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceMuted;

  final Color border;
  final Color borderStrong;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  final Color accent;
  final Color accentMuted;
  final Color accentOn;

  final Color success;
  final Color successMuted;
  final Color danger;
  final Color dangerMuted;
  final Color warning;
  final Color warningMuted;

  @override
  MokuAppColors copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceMuted,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? accentMuted,
    Color? accentOn,
    Color? success,
    Color? successMuted,
    Color? danger,
    Color? dangerMuted,
    Color? warning,
    Color? warningMuted,
  }) {
    return MokuAppColors(
      canvas:          canvas          ?? this.canvas,
      surface:         surface         ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceMuted:    surfaceMuted    ?? this.surfaceMuted,
      border:          border          ?? this.border,
      borderStrong:    borderStrong    ?? this.borderStrong,
      textPrimary:     textPrimary     ?? this.textPrimary,
      textSecondary:   textSecondary   ?? this.textSecondary,
      textTertiary:    textTertiary    ?? this.textTertiary,
      accent:          accent          ?? this.accent,
      accentMuted:     accentMuted     ?? this.accentMuted,
      accentOn:        accentOn        ?? this.accentOn,
      success:         success         ?? this.success,
      successMuted:    successMuted    ?? this.successMuted,
      danger:          danger          ?? this.danger,
      dangerMuted:     dangerMuted     ?? this.dangerMuted,
      warning:         warning         ?? this.warning,
      warningMuted:    warningMuted    ?? this.warningMuted,
    );
  }

  @override
  MokuAppColors lerp(ThemeExtension<MokuAppColors>? other, double t) {
    if (other is! MokuAppColors) return this;
    return MokuAppColors(
      canvas:          Color.lerp(canvas,          other.canvas,          t)!,
      surface:         Color.lerp(surface,         other.surface,         t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceMuted:    Color.lerp(surfaceMuted,     other.surfaceMuted,     t)!,
      border:          Color.lerp(border,           other.border,           t)!,
      borderStrong:    Color.lerp(borderStrong,     other.borderStrong,     t)!,
      textPrimary:     Color.lerp(textPrimary,      other.textPrimary,      t)!,
      textSecondary:   Color.lerp(textSecondary,    other.textSecondary,    t)!,
      textTertiary:    Color.lerp(textTertiary,     other.textTertiary,     t)!,
      accent:          Color.lerp(accent,           other.accent,           t)!,
      accentMuted:     Color.lerp(accentMuted,      other.accentMuted,      t)!,
      accentOn:        Color.lerp(accentOn,         other.accentOn,         t)!,
      success:         Color.lerp(success,          other.success,          t)!,
      successMuted:    Color.lerp(successMuted,     other.successMuted,     t)!,
      danger:          Color.lerp(danger,           other.danger,           t)!,
      dangerMuted:     Color.lerp(dangerMuted,      other.dangerMuted,      t)!,
      warning:         Color.lerp(warning,          other.warning,          t)!,
      warningMuted:    Color.lerp(warningMuted,     other.warningMuted,     t)!,
    );
  }
}

// ── Palettes ──────────────────────────────────────────────────────────────────

/// Warm aged-paper light palette.
const kMokuLight = MokuAppColors(
  canvas:          Color(0xFFF5F0E8), // scaffold — warm cream
  surface:         Color(0xFFFAF7F2), // card / panel — lighter paper
  surfaceElevated: Color(0xFFFEFBF7), // hover / focus surface
  surfaceMuted:    Color(0xFFEDE7DC), // sidebar / dim panel
  border:          Color(0xFFE0D8CC), // subtle divider
  borderStrong:    Color(0xFFC8BFB0), // input outline, group borders
  textPrimary:     Color(0xFF1E1A17), // warm ink
  textSecondary:   Color(0xFF5C5652), // supporting text
  textTertiary:    Color(0xFFA09890), // placeholders, very muted
  accent:          Color(0xFF5548C8), // inked violet
  accentMuted:     Color(0xFFEBE9F8), // tinted accent bg
  accentOn:        Color(0xFFFFFFFF),
  success:         Color(0xFF2A7D4F),
  successMuted:    Color(0xFFD8EFE2),
  danger:          Color(0xFFB83232),
  dangerMuted:     Color(0xFFF8DADA),
  warning:         Color(0xFFD97706),
  warningMuted:    Color(0xFFFBEAC0),
);

/// Warm candlelight dark palette.
const kMokuDark = MokuAppColors(
  canvas:          Color(0xFF1A1816), // nightBase
  surface:         Color(0xFF242220), // nightCard
  surfaceElevated: Color(0xFF2C2926), // slightly lighter panel
  surfaceMuted:    Color(0xFF1F1D1B), // dim panel / sidebar
  border:          Color(0xFF332E2A), // subtle divider
  borderStrong:    Color(0xFF453E39), // visible border
  textPrimary:     Color(0xFFE8E4DF), // moonlight
  textSecondary:   Color(0xFF8C857D), // moonMuted
  textTertiary:    Color(0xFF5C5652), // very muted
  accent:          Color(0xFF8B82E0), // lighter violet on dark (same hue, more luminous)
  accentMuted:     Color(0xFF2A2848), // dark violet tint
  accentOn:        Color(0xFFFFFFFF),
  success:         Color(0xFF3FB950),
  successMuted:    Color(0xFF1A3828),
  danger:          Color(0xFFF85149),
  dangerMuted:     Color(0xFF3B1418),
  warning:         Color(0xFFD29922),
  warningMuted:    Color(0xFF3A2E10),
);

// ── Extension on BuildContext ─────────────────────────────────────────────────

extension MokuColorsX on BuildContext {
  /// Returns the active [MokuAppColors] from the theme.
  /// Falls back to the light palette if the extension isn't registered.
  MokuAppColors get colors =>
      Theme.of(this).extension<MokuAppColors>() ?? kMokuLight;
}
