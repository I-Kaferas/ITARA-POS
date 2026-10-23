import 'package:flutter/material.dart';

class AppPalette {
  const AppPalette({
    required this.brand50,
    required this.brand100,
    required this.brand200,
    required this.brandInk,
    required this.canvas,
    required this.surface,
    required this.surfaceVariant,
    required this.border,
    required this.borderStrong,
    required this.successBg,
    required this.warningBg,
    required this.dangerBg,
    required this.infoBg,
    required this.accentSoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.fieldFill,
    required this.shadow,
  });

  final Color brand50;
  final Color brand100;
  final Color brand200;
  /// Readable brand color for prices / emphasis on the current surface.
  final Color brandInk;
  final Color canvas;
  final Color surface;
  final Color surfaceVariant;
  final Color border;
  final Color borderStrong;
  final Color successBg;
  final Color warningBg;
  final Color dangerBg;
  final Color infoBg;
  final Color accentSoft;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color fieldFill;
  final Color shadow;

  static const light = AppPalette(
    brand50: Color(0xFFF1F2F3),
    brand100: Color(0xFFE3E5E8),
    brand200: Color(0xFFBDC2C8),
    brandInk: Color(0xFF12243C),
    canvas: Color(0xFFF4F6F8),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF7F8FA),
    border: Color(0xFFE3E7EB),
    borderStrong: Color(0xFFD0D6DC),
    successBg: Color(0xFFE8F6EF),
    warningBg: Color(0xFFFBF3E4),
    dangerBg: Color.fromARGB(255, 251, 237, 236),
    infoBg: Color(0xFFE8F1F7),
    accentSoft: Color(0xFFFBF4E6),
    textPrimary: Color(0xFF14202B),
    textSecondary: Color(0xFF3A4C5C),
    textMuted: Color(0xFF5C6D7C),
    fieldFill: Color(0xFFF3F5F7),
    shadow: Color(0x0F14202B),
  );

  /// Aligned with PosUi desk night (navy), not slate-gray Material dark.
  static const dark = AppPalette(
    brand50: Color(0xFF1B2536),
    brand100: Color(0xFF243044),
    brand200: Color(0xFF2C3A50),
    brandInk: Color(0xFFD7E4F4),
    canvas: Color(0xFF0C1422),
    surface: Color(0xFF182233),
    surfaceVariant: Color(0xFF121A2B),
    border: Color(0xFF2C3A50),
    borderStrong: Color(0xFF3A4B63),
    successBg: Color(0xFF143528),
    warningBg: Color(0xFF3A2E1A),
    dangerBg: Color(0xFF3A2422),
    infoBg: Color(0xFF1A2A38),
    accentSoft: Color(0xFF3A2F18),
    textPrimary: Color(0xFFF4F7FB),
    textSecondary: Color(0xFF9AABBE),
    textMuted: Color(0xFF7E90A4),
    fieldFill: Color(0xFF101828),
    shadow: Color(0x66000000),
  );
}

/// Design tokens — primary navy #12243C.
abstract final class AppColors {
  static AppPalette _palette = AppPalette.light;

  static void bind(AppPalette palette) => _palette = palette;

  static const brand300 = Color(0xFF848D9A);
  static const brand400 = Color(0xFF465467);
  static const brand500 = Color(0xFF25364C);
  static const brand600 = Color(0xFF12243C);
  static const brand700 = Color(0xFF0F1F34);
  static const brand800 = Color(0xFF0D1A2B);
  static const brand900 = Color(0xFF0A1523);

  /// Primary action fill — web brand-700. Headings use brand-600.
  static const cashierBlue = brand700;
  static const cashierNavy = brand600;

  static const accent = Color(0xFFE39B2B);
  /// Gold sampled from the ITARA logo circuits.
  static const logoGold = Color(0xFFF0A010);
  static const violet500 = accent;
  static const violet600 = Color(0xFFB86E09);

  static const sidebarLight = Color(0xFF12243C);
  static const sidebarPanelLight = Color(0xFF0F2036);
  static const sidebarBorderLight = Color(0xFF2A4060);
  static const sidebarHoverLight = Color(0xFF1A3050);
  static const sidebarActiveLight = Color(0xFF0D1C32);
  static const sidebarTopLight = Color(0xFF162B45);
  static const sidebarBottomLight = Color(0xFF0C1828);

  static const sidebarDark = Color(0xFF2A3A50);
  static const sidebarPanelDark = Color(0xFF27364A);
  static const sidebarBorderDark = Color(0xFF3F5370);
  static const sidebarHoverDark = Color(0xFF314562);
  static const sidebarActiveDark = Color(0xFF253347);
  static const sidebarTopDark = Color(0xFF314562);
  static const sidebarBottomDark = Color(0xFF243244);

  static bool get _darkPalette => identical(_palette, AppPalette.dark);

  static Color get sidebar => _darkPalette ? sidebarDark : sidebarLight;
  static Color get sidebarPanel => _darkPalette ? sidebarPanelDark : sidebarPanelLight;
  static Color get sidebarBorder => _darkPalette ? sidebarBorderDark : sidebarBorderLight;
  static Color get sidebarHover => _darkPalette ? sidebarHoverDark : sidebarHoverLight;
  static Color get sidebarActive => _darkPalette ? sidebarActiveDark : sidebarActiveLight;
  static Color get sidebarTop => _darkPalette ? sidebarTopDark : sidebarTopLight;
  static Color get sidebarBottom => _darkPalette ? sidebarBottomDark : sidebarBottomLight;
  static const sidebarText = Color(0xFFE8EEF8);

  static const success = Color(0xFF0F7A4D);
  static const warning = Color(0xFFB86E09);
  static const danger = Color(0xFFC2413A);
  static const info = Color(0xFF2F6F9A);

  static Color get brand50 => _palette.brand50;
  static Color get brand100 => _palette.brand100;
  static Color get brand200 => _palette.brand200;
  static Color get brandInk => _palette.brandInk;
  static Color get canvas => _palette.canvas;
  static Color get surface => _palette.surface;
  static Color get surfaceVariant => _palette.surfaceVariant;
  static Color get border => _palette.border;
  static Color get borderStrong => _palette.borderStrong;
  static Color get successBg => _palette.successBg;
  static Color get warningBg => _palette.warningBg;
  static Color get dangerBg => _palette.dangerBg;
  static Color get infoBg => _palette.infoBg;
  static Color get accentSoft => _palette.accentSoft;
  static Color get textPrimary => _palette.textPrimary;
  static Color get textSecondary => _palette.textSecondary;
  static Color get textMuted => _palette.textMuted;
  static Color get fieldFill => _palette.fieldFill;
  static Color get shadow => _palette.shadow;

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brand700, brand600],
  );

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10161C), Color(0xFF18232D), brand700],
  );

  static List<BoxShadow> get elevationSm => [
        BoxShadow(color: shadow, blurRadius: 8, offset: const Offset(0, 2)),
      ];

  static List<BoxShadow> get elevationMd => [
        BoxShadow(color: shadow, blurRadius: 16, offset: const Offset(0, 6)),
      ];
}
