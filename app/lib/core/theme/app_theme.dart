import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../ui/tokens.dart';

/// Moku theme — ink-on-paper, warm, with rust + teal accents.
///
/// Public API:
///   • [MokuTheme.lightTheme] / [MokuTheme.darkTheme] return the base theme.
///   • [MokuTheme.desktopify] returns a tightened variant for desktop chrome
///     (smaller paddings, smaller radii, neutral selection, hairline borders).
///   • [MokuTheme.adaptForTextDirection] kept for RTL flow.
class MokuTheme {
  // Legacy brand mark, kept for any place that still references it.
  static const Color primarySeed = MokuColors.rust;

  // ── Text theme ─────────────────────────────────────────────────────────

  static TextTheme _buildTextTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? ThemeData(brightness: Brightness.dark).textTheme
        : ThemeData(brightness: Brightness.light).textTheme;

    final headingTheme = GoogleFonts.instrumentSerifTextTheme(base);
    final bodyTheme = GoogleFonts.dmSansTextTheme(base);

    return bodyTheme.copyWith(
      displayLarge: headingTheme.displayLarge,
      displayMedium: headingTheme.displayMedium,
      displaySmall: headingTheme.displaySmall,
      headlineLarge: headingTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w400,
        letterSpacing: -0.5,
      ),
      headlineMedium: headingTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w400,
        letterSpacing: -0.3,
      ),
      headlineSmall: headingTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w400,
      ),
      titleLarge: headingTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w400,
        letterSpacing: -0.2,
      ),
      titleMedium: bodyTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      titleSmall: bodyTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    );
  }

  // ── Light theme ────────────────────────────────────────────────────────

  static ThemeData lightTheme() {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: MokuColors.rust,
      onPrimary: MokuColors.paperWhite,
      primaryContainer: MokuColors.paperWarm,
      onPrimaryContainer: MokuColors.rustDeep,
      secondary: MokuColors.teal,
      onSecondary: MokuColors.paperWhite,
      secondaryContainer: MokuColors.paperWarm,
      onSecondaryContainer: MokuColors.tealDeep,
      tertiary: MokuColors.violet,
      onTertiary: MokuColors.paperWhite,
      error: MokuColors.errorRed,
      onError: MokuColors.paperWhite,
      surface: MokuColors.paper,
      onSurface: MokuColors.ink,
      onSurfaceVariant: MokuColors.inkMuted,
      surfaceContainerLowest: MokuColors.paperWhite,
      surfaceContainerLow: MokuColors.paper,
      surfaceContainer: MokuColors.paperWarm,
      surfaceContainerHigh: MokuColors.paperWarm,
      surfaceContainerHighest: MokuColors.paperDim,
      outline: MokuColors.inkRule,
      outlineVariant: MokuColors.inkRule,
      shadow: MokuColors.ink,
      inverseSurface: MokuColors.ink,
      onInverseSurface: MokuColors.paper,
      inversePrimary: MokuColors.coral,
    );

    return _baseTheme(
      colorScheme: colorScheme,
      scaffoldBackground: MokuColors.paper,
      cardColor: MokuColors.paperWhite,
      navBg: MokuColors.paperWarm,
      ruleColor: MokuColors.inkRule,
      brightness: Brightness.light,
    );
  }

  // ── Dark theme ─────────────────────────────────────────────────────────

  static ThemeData darkTheme() {
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: const Color(0xFFE08A5C), // rust lifted for dark
      onPrimary: MokuColors.nightBase,
      primaryContainer: MokuColors.nightRaise,
      onPrimaryContainer: const Color(0xFFE08A5C),
      secondary: const Color(0xFF5FB0A8), // teal lifted for dark
      onSecondary: MokuColors.nightBase,
      secondaryContainer: MokuColors.nightRaise,
      onSecondaryContainer: const Color(0xFF5FB0A8),
      tertiary: MokuColors.violet,
      onTertiary: MokuColors.moonlight,
      error: const Color(0xFFE07B6E),
      onError: MokuColors.nightBase,
      surface: MokuColors.nightBase,
      onSurface: MokuColors.moonlight,
      onSurfaceVariant: MokuColors.moonMuted,
      surfaceContainerLowest: MokuColors.nightPanel,
      surfaceContainerLow: MokuColors.nightPanel,
      surfaceContainer: MokuColors.nightCard,
      surfaceContainerHigh: MokuColors.nightRaise,
      surfaceContainerHighest: MokuColors.nightRaise,
      outline: MokuColors.moonRule,
      outlineVariant: MokuColors.moonRule,
      shadow: const Color(0xFF000000),
      inverseSurface: MokuColors.moonlight,
      onInverseSurface: MokuColors.nightBase,
      inversePrimary: MokuColors.rust,
    );

    return _baseTheme(
      colorScheme: colorScheme,
      scaffoldBackground: MokuColors.nightBase,
      cardColor: MokuColors.nightCard,
      navBg: MokuColors.nightPanel,
      ruleColor: MokuColors.moonRule,
      brightness: Brightness.dark,
    );
  }

  // ── Shared theme body ──────────────────────────────────────────────────

  static ThemeData _baseTheme({
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    required Color cardColor,
    required Color navBg,
    required Color ruleColor,
    required Brightness brightness,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      canvasColor: scaffoldBackground,
      splashFactory: InkSparkle.splashFactory,
      textTheme: _buildTextTheme(brightness),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scaffoldBackground,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.instrumentSerif(
          fontSize: 24,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurface,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: MokuRadius.lgAll,
          side: BorderSide(color: ruleColor),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light
            ? MokuColors.paperWhite
            : MokuColors.nightPanel,
        hintStyle: GoogleFonts.dmSans(
          fontSize: MokuTypeSize.bodyM,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        border: OutlineInputBorder(
          borderRadius: MokuRadius.smAll,
          borderSide: BorderSide(color: ruleColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: MokuRadius.smAll,
          borderSide: BorderSide(color: ruleColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: MokuRadius.smAll,
          borderSide: BorderSide(color: colorScheme.primary, width: 1.2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: MokuRadius.lgAll),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navBg,
        surfaceTintColor: Colors.transparent,
        indicatorColor: brightness == Brightness.light
            ? MokuColors.paperDim
            : MokuColors.nightRaise,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 64,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.primary, size: 22);
          }
          return IconThemeData(
              color: colorScheme.onSurfaceVariant, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.dmSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            );
          }
          return GoogleFonts.dmSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: navBg,
        indicatorColor: brightness == Brightness.light
            ? MokuColors.paperDim
            : MokuColors.nightRaise,
        selectedIconTheme:
            IconThemeData(color: colorScheme.primary, size: 22),
        unselectedIconTheme: IconThemeData(
          color: colorScheme.onSurfaceVariant,
          size: 22,
        ),
        selectedLabelTextStyle: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
        unselectedLabelTextStyle: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: MokuRadius.smAll),
        side: BorderSide(color: ruleColor),
        backgroundColor: Colors.transparent,
        labelStyle: GoogleFonts.dmSans(
          fontSize: MokuTypeSize.small,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: MokuRadius.lgAll),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: GoogleFonts.dmSans(
          fontSize: MokuTypeSize.body,
          color: colorScheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: MokuRadius.smAll),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: MokuRadius.smAll),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: GoogleFonts.dmSans(
            fontSize: MokuTypeSize.bodyM,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: ruleColor),
          shape: RoundedRectangleBorder(borderRadius: MokuRadius.smAll),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: GoogleFonts.dmSans(
            fontSize: MokuTypeSize.bodyM,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: MokuRadius.smAll),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: GoogleFonts.dmSans(
            fontSize: MokuTypeSize.bodyM,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: MokuRadius.smAll),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: ruleColor,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: MokuRadius.smAll),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        minVerticalPadding: 6,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: MokuRadius.smAll,
          side: BorderSide(color: ruleColor),
        ),
        textStyle: GoogleFonts.dmSans(
          fontSize: MokuTypeSize.bodyM,
          color: colorScheme.onSurface,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface.withValues(alpha: 0.95),
          borderRadius: MokuRadius.xsAll,
        ),
        textStyle: GoogleFonts.dmSans(
          fontSize: MokuTypeSize.small,
          color: colorScheme.onInverseSurface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        waitDuration: const Duration(milliseconds: 400),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  // ── Desktop overrides ──────────────────────────────────────────────────
  //
  // Take a base ThemeData and tighten it for desktop chrome: smaller paddings,
  // smaller fonts on buttons, denser list tiles, hairline rules.

  static ThemeData desktopify(ThemeData base) {
    // Desktop overrides: use the same visual density as the platform default
    // (Flutter already maps to compact on macOS/Linux/Windows via adaptivePlatformDensity)
    // but keep button/listTile sizes intentionally roomy — desktop ≠ cramped.
    final ruleColor = base.dividerTheme.color ?? base.colorScheme.outlineVariant;
    final cs = base.colorScheme;
    return base.copyWith(
      // Let Flutter's default density handle platform conventions; don't force compact.
      visualDensity: VisualDensity.standard,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: MokuRadius.smAll),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          minimumSize: const Size(0, 34),
          textStyle: GoogleFonts.dmSans(
            fontSize: MokuTypeSize.bodyM,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.onSurface,
          side: BorderSide(color: ruleColor),
          shape: RoundedRectangleBorder(borderRadius: MokuRadius.smAll),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          minimumSize: const Size(0, 34),
          textStyle: GoogleFonts.dmSans(
            fontSize: MokuTypeSize.bodyM,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          shape: RoundedRectangleBorder(borderRadius: MokuRadius.smAll),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          minimumSize: const Size(0, 32),
          textStyle: GoogleFonts.dmSans(
            fontSize: MokuTypeSize.bodyM,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        hintStyle: GoogleFonts.dmSans(
          fontSize: MokuTypeSize.bodyM,
          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),
      cardTheme: base.cardTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: MokuRadius.mdAll,
          side: BorderSide(color: ruleColor),
        ),
      ),
      dialogTheme: base.dialogTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: MokuRadius.mdAll),
      ),
      listTileTheme: base.listTileTheme.copyWith(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        minVerticalPadding: 6,
        dense: false,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        toolbarHeight: 48,
        titleTextStyle: GoogleFonts.instrumentSerif(
          fontSize: 22,
          fontWeight: FontWeight.w400,
          color: cs.onSurface,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  // ── RTL adaptation ─────────────────────────────────────────────────────

  static ThemeData adaptForTextDirection(
    ThemeData baseTheme,
    TextDirection textDirection,
  ) {
    if (textDirection != TextDirection.rtl) {
      return baseTheme;
    }

    final colorScheme = baseTheme.colorScheme;
    final systemTextTheme = ThemeData(
      useMaterial3: true,
      brightness: baseTheme.brightness,
      colorScheme: colorScheme,
    ).textTheme.apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    final titleStyle = systemTextTheme.titleLarge?.copyWith(
      fontSize: 22,
      fontWeight: FontWeight.w700,
    );

    return baseTheme.copyWith(
      textTheme: systemTextTheme,
      appBarTheme: baseTheme.appBarTheme.copyWith(titleTextStyle: titleStyle),
      navigationBarTheme: baseTheme.navigationBarTheme.copyWith(
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            );
          }
          return TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          );
        }),
      ),
    );
  }
}

/// Reader-specific theme settings
class ReaderTheme {
  final Color backgroundColor;
  final Color textColor;

  const ReaderTheme({
    required this.backgroundColor,
    required this.textColor,
  });

  static const light = ReaderTheme(
    backgroundColor: MokuColors.readerLightBg,
    textColor: MokuColors.readerLightFg,
  );

  static const dark = ReaderTheme(
    backgroundColor: MokuColors.readerDarkBg,
    textColor: MokuColors.readerDarkFg,
  );

  static const sepia = ReaderTheme(
    backgroundColor: MokuColors.readerSepiaBg,
    textColor: MokuColors.readerSepiaFg,
  );

  static const values = [light, dark, sepia];
}
