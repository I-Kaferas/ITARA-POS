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
    brand50: Color(0xFFF2F6F9),
    brand100: Color(0xFFE3ECF2),
    brand200: Color(0xFFC2D3DF),
    brandInk: Color(0xFF3D5C73),
    canvas: Color(0xFFF3F5F7),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF8FAFB),
    border: Color(0xFFE2E8EE),
    borderStrong: Color(0xFFCBD5DE),
    successBg: Color(0xFFECFDF5),
    warningBg: Color(0xFFF8F1E4),
    dangerBg: Color(0xFFFEF2F2),
    infoBg: Color(0xFFF2F6F9),
    accentSoft: Color(0xFFF8F1E4),
    textPrimary: Color(0xFF172029),
    textSecondary: Color(0xFF5B6B7C),
    textMuted: Color(0xFF8B9AAB),
    fieldFill: Color(0xFFF7F9FA),
    shadow: Color(0x14172029),
  );

  static const dark = AppPalette(
    brand50: Color(0xFF1A242E),
    brand100: Color(0xFF22303C),
    brand200: Color(0xFF3A5164),
    brandInk: Color(0xFFA8C0D0),
    canvas: Color(0xFF0E1419),
    surface: Color(0xFF171F27),
    surfaceVariant: Color(0xFF1C2630),
    border: Color(0xFF2A3642),
    borderStrong: Color(0xFF3D4C5A),
    successBg: Color(0xFF123128),
    warningBg: Color(0xFF3A2C16),
    dangerBg: Color(0xFF3A1C1C),
    infoBg: Color(0xFF1A242E),
    accentSoft: Color(0xFF3A2C16),
    textPrimary: Color(0xFFE8EEF3),
    textSecondary: Color(0xFFA8B6C4),
    textMuted: Color(0xFF7E8E9E),
    fieldFill: Color(0xFF121920),
    shadow: Color(0x66000000),
  );
}

/// Design tokens — refined brand kept (#4A6D86) for enterprise POS identity.
abstract final class AppColors {
  static AppPalette _palette = AppPalette.light;

  static void bind(AppPalette palette) => _palette = palette;

  static const brand400 = Color(0xFF7D9AAF);
  static const brand500 = Color(0xFF5C7F96);
  static const brand600 = Color(0xFF4A6D86);
  static const brand700 = Color(0xFF3D5C73);
  static const brand900 = Color(0xFF1A2833);

  static const accent = Color(0xFFE39B2B);
  static const violet500 = accent;
  static const violet600 = Color(0xFFC4841D);

  static const sidebar = Color(0xFF121A22);
  static const sidebarPanel = Color(0xFF18232D);
  static const sidebarBorder = Color(0x1AE39B2B);
  static const sidebarHover = Color(0x334A6D86);
  static const sidebarActive = Color(0xFF4A6D86);
  static const sidebarText = Color(0xB3E8EEF3);

  static const success = Color(0xFF059669);
  static const warning = Color(0xFFC4841D);
  static const danger = Color(0xFFDC2626);
  static const info = Color(0xFF4A6D86);

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
