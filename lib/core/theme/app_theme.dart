import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/enums.dart';

/// SportGroups Theme — "Atardecer" warm community palette.
/// Migrated from the previous indigo Material 3 theme to a coral + plum
/// system with friendlier rounded type (Bricolage Grotesque + DM Sans).
class AppTheme {
  // ── Brand colours (Atardecer palette) ──────────────────────────────────────
  static const Color primary       = Color(0xFFE2693F); // coral
  static const Color primarySoft   = Color(0xFFFADBCC);
  static const Color primaryInk    = Color(0xFF95371F);

  static const Color accent        = Color(0xFF8868B8); // ciruela
  static const Color accentSoft    = Color(0xFFECE2F1);
  static const Color accentInk     = Color(0xFF553F86);

  static const Color good          = Color(0xFF2DA67D);
  static const Color goodSoft      = Color(0xFFD9F1E5);
  static const Color goodInk       = Color(0xFF1F7A5A);

  static const Color danger        = Color(0xFFDA4A2C);
  static const Color dangerSoft    = Color(0xFFFCD9D0);
  static const Color dangerInk     = Color(0xFF8C2A14);

  static const Color warning       = Color(0xFFF59E0B); // amber — pending / in-review
  static const Color warningSoft   = Color(0xFFFEF3C7);
  static const Color warningInk    = Color(0xFF92400E);

  static const Color info          = Color(0xFF3B82F6); // blue — in-progress / validating
  static const Color infoSoft      = Color(0xFFDBEAFE);
  static const Color infoInk       = Color(0xFF1D4ED8);

  static const Color surface       = Colors.white;
  static const Color surfaceAlt    = Color(0xFFF1ECE7);
  static const Color background    = Color(0xFFF8F5F3); // cream

  static const Color text          = Color(0xFF2A211E);
  static const Color textMuted     = Color(0xFF756864);
  static const Color border        = Color(0xFFE8E2DD);
  static const Color borderStrong  = Color(0xFFD6CFC8);

  // ── Role colours ──────────────────────────────────────────────────────────
  static const Color roleAdmin      = primary;     // coral
  static const Color roleModerador  = info;         // blue
  static const Color roleTesorero   = accent;       // plum
  static const Color roleDelegado   = warning;      // amber
  static const Color roleMiembro    = textMuted;    // warm muted

  static Color roleColor(RolMiembro rol) {
    switch (rol) {
      case RolMiembro.administrador: return roleAdmin;
      case RolMiembro.moderador:     return roleModerador;
      case RolMiembro.tesorero:      return roleTesorero;
      case RolMiembro.delegado:      return roleDelegado;
      case RolMiembro.miembro:       return roleMiembro;
    }
  }

  // ── Overlay helper ─────────────────────────────────────────────────────────
  static Color overlay(BuildContext ctx, {double opacity = 0.08}) =>
      isDark(ctx)
          ? Colors.white.withValues(alpha: opacity)
          : Colors.black.withValues(alpha: opacity);

  // Aliases kept for backwards compatibility with screens that imported
  // AppTheme.secondary / .tertiary / .error from the old theme.
  static const Color secondary     = accent;
  static const Color tertiary      = good;
  static const Color error         = danger;

  // ── Dark palette ───────────────────────────────────────────────────────────
  // Warm dark equivalents of the light palette (same hue family, dark values)
  static const Color darkBackground  = Color(0xFF1A1512); // deep warm black
  static const Color darkSurface     = Color(0xFF26201C); // dark warm brown
  static const Color darkSurfaceAlt  = Color(0xFF302822); // slightly lighter
  static const Color darkText        = Color(0xFFF2EDE9); // off-white
  static const Color darkTextMuted   = Color(0xFF9E908A); // warm muted
  static const Color darkBorder      = Color(0xFF3A302A); // dark border
  static const Color darkBorderStrong= Color(0xFF4A3E36); // stronger border
  static const Color darkGoodSoft    = Color(0xFF0F2E21); // dark green bg
  static const Color darkDangerSoft  = Color(0xFF2E1210); // dark red bg

  // ── Layout constants ──────────────────────────────────────────────────────
  static const double kResponsiveBreakpoint = 900;
  static const double kBottomNavPadding     = 100;

  // ── Context-aware colour helpers ───────────────────────────────────────────
  // Use these in widgets to support both light and dark mode automatically.
  static bool isDark(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark;

  static Color bg(BuildContext ctx) =>
      isDark(ctx) ? darkBackground : background;
  static Color surf(BuildContext ctx) =>
      isDark(ctx) ? darkSurface : surface;
  static Color surfAlt(BuildContext ctx) =>
      isDark(ctx) ? darkSurfaceAlt : surfaceAlt;
  static Color txt(BuildContext ctx) =>
      isDark(ctx) ? darkText : text;
  static Color txtMuted(BuildContext ctx) =>
      isDark(ctx) ? darkTextMuted : textMuted;
  static Color brd(BuildContext ctx) =>
      isDark(ctx) ? darkBorder : border;
  static Color brdStrong(BuildContext ctx) =>
      isDark(ctx) ? darkBorderStrong : borderStrong;
  static Color goodSoftDyn(BuildContext ctx) =>
      isDark(ctx) ? darkGoodSoft : goodSoft;
  static Color dangerSoftDyn(BuildContext ctx) =>
      isDark(ctx) ? darkDangerSoft : dangerSoft;

  // ── Dark theme ─────────────────────────────────────────────────────────────
  static ThemeData get dark {
    const Color dPrimary = Color(0xFFF07B52); // slightly lighter coral for dark

    const base = ColorScheme(
      brightness: Brightness.dark,
      primary: dPrimary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF6B2B12),
      onPrimaryContainer: Color(0xFFFFCDB9),
      secondary: accent,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFF4B3468),
      onSecondaryContainer: Color(0xFFE8D7FF),
      tertiary: good,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFF0A3D2B),
      onTertiaryContainer: Color(0xFFB8F0D8),
      error: danger,
      onError: Colors.white,
      errorContainer: Color(0xFF6B1608),
      onErrorContainer: Color(0xFFFFCDC4),
      surface: darkSurface,
      onSurface: darkText,
      surfaceContainerHighest: darkSurfaceAlt,
      outline: darkBorderStrong,
      outlineVariant: darkBorder,
    );

    final body    = GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme);
    final display = GoogleFonts.bricolageGrotesqueTextTheme(ThemeData.dark().textTheme);

    final textTheme = body.copyWith(
      displayLarge:   display.displayLarge?.copyWith(color: darkText, fontWeight: FontWeight.w700, letterSpacing: -0.8),
      displayMedium:  display.displayMedium?.copyWith(color: darkText, fontWeight: FontWeight.w700, letterSpacing: -0.6),
      displaySmall:   display.displaySmall?.copyWith(color: darkText, fontWeight: FontWeight.w700, letterSpacing: -0.4),
      headlineLarge:  display.headlineLarge?.copyWith(color: darkText, fontWeight: FontWeight.w700, letterSpacing: -0.4),
      headlineMedium: display.headlineMedium?.copyWith(color: darkText, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      headlineSmall:  display.headlineSmall?.copyWith(color: darkText, fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleLarge:     display.titleLarge?.copyWith(color: darkText, fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleMedium:    body.titleMedium?.copyWith(color: darkText, fontWeight: FontWeight.w700),
      titleSmall:     body.titleSmall?.copyWith(color: darkText, fontWeight: FontWeight.w600),
      bodyLarge:      body.bodyLarge?.copyWith(color: darkText),
      bodyMedium:     body.bodyMedium?.copyWith(color: darkText),
      bodySmall:      body.bodySmall?.copyWith(color: darkTextMuted),
      labelLarge:     body.labelLarge?.copyWith(color: darkText, fontWeight: FontWeight.w600),
      labelMedium:    body.labelMedium?.copyWith(color: darkTextMuted, fontWeight: FontWeight.w600),
      labelSmall:     body.labelSmall?.copyWith(color: darkTextMuted, fontWeight: FontWeight.w600, letterSpacing: 0.5),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: darkBackground,
      textTheme: textTheme,
      primaryTextTheme: textTheme,

      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: darkText,
        titleTextStyle: display.titleLarge?.copyWith(
          color: darkText,
          fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: darkText),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: dPrimary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: const TextStyle(color: darkTextMuted),
        hintStyle: const TextStyle(color: darkTextMuted),
        prefixIconColor: darkTextMuted,
        suffixIconColor: darkTextMuted,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: dPrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          textStyle: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2),
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: dPrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          textStyle: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          foregroundColor: darkText,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          side: const BorderSide(color: darkBorder),
          textStyle: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: dPrimary,
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
        ),
      ),

      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide.none,
        backgroundColor: darkSurfaceAlt,
        selectedColor: const Color(0xFF6B2B12),
        labelStyle: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: darkText),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
        dragHandleColor: darkBorderStrong,
        dragHandleSize: Size(40, 4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: GoogleFonts.bricolageGrotesque(
            color: darkText, fontSize: 18, fontWeight: FontWeight.w700),
        contentTextStyle: GoogleFonts.dmSans(color: darkText, fontSize: 14),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: dPrimary,
        unselectedLabelColor: darkTextMuted,
        indicatorColor: dPrimary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w500),
        dividerColor: darkBorder,
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: dPrimary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(28)),
        ),
      ),

      dividerTheme: const DividerThemeData(color: darkBorder, space: 1, thickness: 1),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: darkTextMuted,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkSurface,
        contentTextStyle: GoogleFonts.dmSans(color: darkText, fontWeight: FontWeight.w500),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? dPrimary : Colors.transparent),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: darkBorderStrong, width: 2),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? dPrimary : darkBorderStrong),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? dPrimary.withValues(alpha: 0.35)
                : darkSurfaceAlt),
      ),
    );
  }

  // ── Light theme ────────────────────────────────────────────────────────────
  static ThemeData get light {
    final base = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      onPrimary: Colors.white,
      secondary: accent,
      onSecondary: Colors.white,
      tertiary: good,
      error: danger,
      surface: surface,
      brightness: Brightness.light,
    ).copyWith(
      primaryContainer: primarySoft,
      onPrimaryContainer: primaryInk,
      secondaryContainer: accentSoft,
      onSecondaryContainer: accentInk,
      surfaceContainerHighest: surfaceAlt,
      outline: borderStrong,
      outlineVariant: border,
    );

    // Type system — Bricolage Grotesque for display/titles, DM Sans for body.
    final body = GoogleFonts.dmSansTextTheme();
    final display = GoogleFonts.bricolageGrotesqueTextTheme();

    final textTheme = body.copyWith(
      displayLarge:   display.displayLarge?.copyWith(color: text, fontWeight: FontWeight.w700, letterSpacing: -0.8),
      displayMedium:  display.displayMedium?.copyWith(color: text, fontWeight: FontWeight.w700, letterSpacing: -0.6),
      displaySmall:   display.displaySmall?.copyWith(color: text, fontWeight: FontWeight.w700, letterSpacing: -0.4),
      headlineLarge:  display.headlineLarge?.copyWith(color: text, fontWeight: FontWeight.w700, letterSpacing: -0.4),
      headlineMedium: display.headlineMedium?.copyWith(color: text, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      headlineSmall:  display.headlineSmall?.copyWith(color: text, fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleLarge:     display.titleLarge?.copyWith(color: text, fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleMedium:    body.titleMedium?.copyWith(color: text, fontWeight: FontWeight.w700),
      titleSmall:     body.titleSmall?.copyWith(color: text, fontWeight: FontWeight.w600),
      bodyLarge:      body.bodyLarge?.copyWith(color: text),
      bodyMedium:     body.bodyMedium?.copyWith(color: text),
      bodySmall:      body.bodySmall?.copyWith(color: textMuted),
      labelLarge:     body.labelLarge?.copyWith(color: text, fontWeight: FontWeight.w600),
      labelMedium:    body.labelMedium?.copyWith(color: textMuted, fontWeight: FontWeight.w600),
      labelSmall:     body.labelSmall?.copyWith(color: textMuted, fontWeight: FontWeight.w600, letterSpacing: 0.5),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      primaryTextTheme: textTheme,

      // ── AppBar ────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: text,
        titleTextStyle: display.titleLarge?.copyWith(
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: text),
      ),

      // ── Cards ─────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Inputs ────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: const TextStyle(color: textMuted),
        hintStyle: const TextStyle(color: textMuted),
        prefixIconColor: textMuted,
        suffixIconColor: textMuted,
      ),

      // ── Buttons ───────────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          textStyle: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2),
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          textStyle: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          foregroundColor: text,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          side: const BorderSide(color: border),
          textStyle: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
        ),
      ),

      // ── Chips ─────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide.none,
        backgroundColor: surfaceAlt,
        selectedColor: primarySoft,
        labelStyle: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: text),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      // ── Bottom sheets / dialogs ──────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
        dragHandleColor: borderStrong,
        dragHandleSize: Size(40, 4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),

      // ── Tabs ──────────────────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: textMuted,
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w500),
        dividerColor: border,
      ),

      // ── FAB ───────────────────────────────────────────────────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(28)),
        ),
      ),

      // ── Misc ──────────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(color: border, space: 1, thickness: 1),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: textMuted,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: text,
        contentTextStyle: GoogleFonts.dmSans(color: surface, fontWeight: FontWeight.w500),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
