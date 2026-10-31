// lib/theme/app_theme.dart
//
// ValetFusion design tokens for the app, v3 "control room" (plan §2.8 / C5) - the same values
// as the portal's theme/tokens.ts so web and phone read as one product: Barlow for text, Barlow
// Condensed for numbers read at a glance, IBM Plex Mono for plates and tickets; ink surfaces;
// a brass accent by default and the venue's own colour after login (plan B2); status colours
// that never change. Light and dark themes; driver and desk screens use the always-dark one.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Neutral surfaces and the fixed palette. Pages use these names, never raw hex values.
class AppColors {
  // light surfaces
  static const Color page = Color(0xFFEEF0F3);
  static const Color card = Color(0xFFFFFFFF);
  static const Color card2 = Color(0xFFF6F7F9);
  static const Color line = Color(0xFFD9DEE5);
  static const Color lineStrong = Color(0xFFC3CAD4);
  static const Color textPrimary = Color(0xFF141A22);
  static const Color textBody = Color(0xFF2B3440);
  static const Color textSecondary = Color(0xFF5B6672);
  // dark / ops surfaces
  static const Color ink = Color(0xFF0B0F14);
  static const Color inkPage = Color(0xFF0F1319);
  static const Color inkCard = Color(0xFF171C24);
  static const Color inkCard2 = Color(0xFF1E242E);
  static const Color inkLine = Color(0xFF2A323D);
  static const Color inkLineStrong = Color(0xFF3A4452);
  static const Color inkText = Color(0xFFEDF0F4);
  static const Color inkTextBody = Color(0xFFD2D8E0);
  static const Color inkTextSecondary = Color(0xFF94A0AE);
  // brand
  static const Color brass = Color(0xFFA8781F);
  static const Color brassOnDark = Color(0xFFD9A441);
  // status (light / dark)
  static const Color success = Color(0xFF1B8F63);
  static const Color successOnDark = Color(0xFF3CC48E);
  static const Color warning = Color(0xFFC97B06);
  static const Color warningOnDark = Color(0xFFE8A33A);
  static const Color danger = Color(0xFFC8403B);
  static const Color dangerOnDark = Color(0xFFEF6B66);
  static const Color live = Color(0xFF1C8DA8);
  static const Color liveOnDark = Color(0xFF4CC3DD);
  // soft backgrounds for chips, banners and tinted cards (light surfaces)
  static const Color successSoft = Color(0xFFDDF3E9);
  static const Color warningSoft = Color(0xFFFBEBD0);
  static const Color dangerSoft = Color(0xFFF9DEDC);
  static const Color infoSoft = Color(0xFFD9EEF4);
  static const Color accentSoft = Color(0xFFF3E9D2);
  // the same tints for dark surfaces (readable under the *OnDark status colours)
  static const Color successSoftDark = Color(0xFF15372A);
  static const Color warningSoftDark = Color(0xFF3D2C10);
  static const Color dangerSoftDark = Color(0xFF3F1E1D);
  static const Color infoSoftDark = Color(0xFF12323C);
  static const Color accentSoftDark = Color(0xFF392C14);
  // plates
  static const Color plateBg = Color(0xFFFFFFFF);
  static const Color plateFg = Color(0xFF111111);
  static const Color plateTag = Color(0xFFC8403B);

  // Kept for older screens that still reference them (same meaning, new values).
  static const Color primary = brass;
  static const Color primaryDark = Color(0xFF8F651A);
  static const Color driver = success;
  static const Color admin = live;
  static const Color surface = page;
  static const Color surfaceCard = card;
}

/// The venue's accent after login (plan B2); brass until then. Rebuilds the theme when set.
class BrandController {
  BrandController._();
  static final ValueNotifier<Color?> accent = ValueNotifier<Color?>(null);
  static final ValueNotifier<String?> logoUrl = ValueNotifier<String?>(null);

  static void apply({String? accentHex, String? logo}) {
    accent.value = parseHex(accentHex);
    logoUrl.value = logo == null || logo.isEmpty ? null : logo;
  }

  static void clear() {
    accent.value = null;
    logoUrl.value = null;
  }

  static Color? parseHex(String? hex) {
    if (hex == null) return null;
    final m = RegExp(r'^#?([0-9A-Fa-f]{6})$').firstMatch(hex.trim());
    if (m == null) return null;
    return Color(int.parse('FF${m.group(1)}', radix: 16));
  }
}

class AppTheme {
  static Color contrastOn(Color c) => c.computeLuminance() > 0.45 ? AppColors.ink : Colors.white;

  static TextTheme _text(Color primary, Color secondary) {
    final base = GoogleFonts.barlowTextTheme();
    return base.copyWith(
      displayLarge: GoogleFonts.barlowCondensed(fontWeight: FontWeight.w700, fontSize: 44, color: primary, height: 1.0),
      displayMedium: GoogleFonts.barlowCondensed(fontWeight: FontWeight.w700, fontSize: 34, color: primary, height: 1.0),
      displaySmall: GoogleFonts.barlowCondensed(fontWeight: FontWeight.w700, fontSize: 28, color: primary, height: 1.05),
      headlineMedium: GoogleFonts.barlowCondensed(fontWeight: FontWeight.w600, fontSize: 24, color: primary, height: 1.1),
      titleLarge: GoogleFonts.barlow(fontWeight: FontWeight.w700, fontSize: 20, color: primary),
      titleMedium: GoogleFonts.barlow(fontWeight: FontWeight.w600, fontSize: 16, color: primary),
      titleSmall: GoogleFonts.barlow(fontWeight: FontWeight.w600, fontSize: 14, color: primary),
      bodyLarge: GoogleFonts.barlow(fontSize: 15, color: primary),
      bodyMedium: GoogleFonts.barlow(fontSize: 13.5, color: secondary),
      bodySmall: GoogleFonts.barlow(fontSize: 12, color: secondary),
      labelLarge: GoogleFonts.barlow(fontWeight: FontWeight.w700, fontSize: 14),
      labelMedium: GoogleFonts.barlow(fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 0.6),
      labelSmall: GoogleFonts.barlow(fontWeight: FontWeight.w700, fontSize: 10.5, letterSpacing: 1.2, color: secondary),
    );
  }

  /// Monospace for plates, ticket numbers, money and times.
  static TextStyle mono({double size = 13, FontWeight weight = FontWeight.w600, Color? color}) =>
      GoogleFonts.ibmPlexMono(fontSize: size, fontWeight: weight, color: color, fontFeatures: const [FontFeature.tabularFigures()]);

  /// Condensed numerals for timers and counts.
  static TextStyle numeral({double size = 28, FontWeight weight = FontWeight.w700, Color? color}) =>
      GoogleFonts.barlowCondensed(fontSize: size, fontWeight: weight, color: color, height: 1.0, fontFeatures: const [FontFeature.tabularFigures()]);

  static ThemeData _build({required Brightness brightness, Color? accent}) {
    final dark = brightness == Brightness.dark;
    final primary = accent ?? (dark ? AppColors.brassOnDark : AppColors.brass);
    final onPrimary = contrastOn(primary);
    final page = dark ? AppColors.inkPage : AppColors.page;
    final card = dark ? AppColors.inkCard : AppColors.card;
    final card2 = dark ? AppColors.inkCard2 : AppColors.card2;
    final line = dark ? AppColors.inkLine : AppColors.line;
    final lineStrong = dark ? AppColors.inkLineStrong : AppColors.lineStrong;
    final text = dark ? AppColors.inkText : AppColors.textPrimary;
    final textSecondary = dark ? AppColors.inkTextSecondary : AppColors.textSecondary;
    final textTheme = _text(text, textSecondary);

    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primary.withValues(alpha: dark ? 0.18 : 0.12),
      onPrimaryContainer: primary,
      secondary: dark ? AppColors.liveOnDark : AppColors.live,
      onSecondary: Colors.white,
      error: dark ? AppColors.dangerOnDark : AppColors.danger,
      onError: Colors.white,
      surface: card,
      onSurface: text,
      surfaceContainerHighest: card2,
      onSurfaceVariant: textSecondary,
      outline: lineStrong,
      outlineVariant: line,
      tertiary: dark ? AppColors.successOnDark : AppColors.success,
      onTertiary: Colors.white,
    );

    OutlineInputBorder border(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c, width: w));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: page,
      canvasColor: page,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: textSecondary, size: 22),
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: card,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: Border(bottom: BorderSide(color: line)),
        iconTheme: IconThemeData(color: text),
        titleTextStyle: GoogleFonts.barlow(color: text, fontSize: 17, fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: line)),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          minimumSize: const Size(48, 48), // thumb-sized (plan §2.5)
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.barlow(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.barlow(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: BorderSide(color: lineStrong, width: 1.2),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.barlow(fontWeight: FontWeight.w600, fontSize: 14.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.barlow(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF12171E) : AppColors.card,
        border: border(line),
        enabledBorder: border(line),
        focusedBorder: border(primary, 1.6),
        errorBorder: border(scheme.error),
        focusedErrorBorder: border(scheme.error, 1.6),
        labelStyle: GoogleFonts.barlow(color: textSecondary, fontSize: 14),
        hintStyle: GoogleFonts.barlow(color: textSecondary.withValues(alpha: 0.8), fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card2,
        labelStyle: GoogleFonts.barlow(fontWeight: FontWeight.w600, fontSize: 12, color: text),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      listTileTheme: ListTileThemeData(iconColor: textSecondary, textColor: text, dense: true),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: card,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        selectedLabelStyle: GoogleFonts.barlow(fontWeight: FontWeight.w700, fontSize: 11.5),
        unselectedLabelStyle: GoogleFonts.barlow(fontWeight: FontWeight.w600, fontSize: 11.5),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: primary.withValues(alpha: 0.16),
        labelTextStyle: WidgetStatePropertyAll(GoogleFonts.barlow(fontWeight: FontWeight.w600, fontSize: 11.5, color: text)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? AppColors.inkCard2 : AppColors.textPrimary,
        contentTextStyle: GoogleFonts.barlow(color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titleTextStyle: GoogleFonts.barlow(fontWeight: FontWeight.w700, fontSize: 18, color: text),
        contentTextStyle: GoogleFonts.barlow(fontSize: 14.5, color: textSecondary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
        showDragHandle: true,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: text,
        unselectedLabelColor: textSecondary,
        indicatorColor: primary,
        labelStyle: GoogleFonts.barlow(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: GoogleFonts.barlow(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      switchTheme: SwitchThemeData(thumbColor: WidgetStatePropertyAll(card), trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary : lineStrong)),
    );
  }

  static ThemeData light({Color? accent}) => _build(brightness: Brightness.light, accent: accent);
  static ThemeData dark({Color? accent}) => _build(brightness: Brightness.dark, accent: accent);

  /// Driver and desk screens: always dark, whatever the phone's setting (plan §2.8).
  static ThemeData get ops => _build(brightness: Brightness.dark);

  /// Kept for older call sites.
  static ThemeData get lightDefault => light();
}

/// Semantic colour for a ticket state (plan §2.8), for the current brightness.
Color ticketStateColor(String status, Brightness b) {
  final dark = b == Brightness.dark;
  switch (status) {
    case 'RECEIVED': return dark ? AppColors.liveOnDark : AppColors.live;
    case 'REQUESTED':
    case 'VALIDATED': return dark ? AppColors.warningOnDark : AppColors.warning;
    case 'ONTHEWAY': return dark ? AppColors.brassOnDark : AppColors.brass;
    case 'ARRIVED':
    case 'DELIVERED': return dark ? AppColors.successOnDark : AppColors.success;
    default: return dark ? AppColors.inkTextSecondary : AppColors.textSecondary;
  }
}

/// Wait-time band colour: green under 10 min, amber under 20, red after (plan §2.8).
Color waitBandColor(Duration waited, Brightness b) {
  final dark = b == Brightness.dark;
  if (waited.inMinutes >= 20) return dark ? AppColors.dangerOnDark : AppColors.danger;
  if (waited.inMinutes >= 10) return dark ? AppColors.warningOnDark : AppColors.warning;
  return dark ? AppColors.successOnDark : AppColors.success;
}

/// Surface, text, line and status colours for the brightness of the theme in force where the
/// widget sits, so one screen reads right in the light theme, the dark theme (phone setting) and
/// under [AppTheme.ops]. Use `context.vf.card` etc. instead of the fixed light [AppColors] tokens.
/// Status colours (success/warning/danger/live) and their soft tints are tuned per brightness.
class VfColors {
  final bool dark;
  const VfColors._(this.dark);
  static const VfColors lightSet = VfColors._(false);
  static const VfColors darkSet = VfColors._(true);
  static VfColors of(Brightness b) => b == Brightness.dark ? darkSet : lightSet;

  // surfaces
  Color get page => dark ? AppColors.inkPage : AppColors.page;
  Color get card => dark ? AppColors.inkCard : AppColors.card;
  Color get card2 => dark ? AppColors.inkCard2 : AppColors.card2;
  Color get line => dark ? AppColors.inkLine : AppColors.line;
  Color get lineStrong => dark ? AppColors.inkLineStrong : AppColors.lineStrong;
  // text
  Color get textPrimary => dark ? AppColors.inkText : AppColors.textPrimary;
  Color get textBody => dark ? AppColors.inkTextBody : AppColors.textBody;
  Color get textSecondary => dark ? AppColors.inkTextSecondary : AppColors.textSecondary;
  /// Text/icons on a coloured (status or accent) fill - white in both modes.
  Color get onColor => Colors.white;
  /// Strongest contrast against the page: black in light mode, white in dark mode.
  Color get contrast => dark ? Colors.white : Colors.black;
  // brand
  Color get brass => dark ? AppColors.brassOnDark : AppColors.brass;
  // status
  Color get success => dark ? AppColors.successOnDark : AppColors.success;
  Color get warning => dark ? AppColors.warningOnDark : AppColors.warning;
  Color get danger => dark ? AppColors.dangerOnDark : AppColors.danger;
  Color get live => dark ? AppColors.liveOnDark : AppColors.live;
  // soft tints behind status text/icons
  Color get successSoft => dark ? AppColors.successSoftDark : AppColors.successSoft;
  Color get warningSoft => dark ? AppColors.warningSoftDark : AppColors.warningSoft;
  Color get dangerSoft => dark ? AppColors.dangerSoftDark : AppColors.dangerSoft;
  Color get infoSoft => dark ? AppColors.infoSoftDark : AppColors.infoSoft;
  Color get accentSoft => dark ? AppColors.accentSoftDark : AppColors.accentSoft;
  /// Dim backdrop for overlays/scrims.
  Color get scrim => Colors.black.withValues(alpha: dark ? 0.6 : 0.4);
}

extension VfColorsContext on BuildContext {
  /// The colour tokens for the active theme's brightness (see [VfColors]).
  VfColors get vf => VfColors.of(Theme.of(this).brightness);
}
