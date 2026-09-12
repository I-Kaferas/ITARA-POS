import 'package:flutter/material.dart';

class AppPalette {
  const AppPalette({
    required this.brand50,
    required this.brand100,
    required this.brand200,
    required this.brandInk,
    required this.canvas,
    required this.surface,
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
  });

  final Color brand50;
  final Color brand100;
  final Color brand200;
  /// Readable brand color for prices / emphasis on the current surface.
  final Color brandInk;
  final Color canvas;
  final Color surface;
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

  static const light = AppPalette(
    brand50: Color(0xFFF3F6F8),
    brand100: Color(0xFFE4EDF2),
    brand200: Color(0xFFC5D4DF),
    brandInk: Color(0xFF3D5C73),
    canvas: Color(0xFFF4F6F8),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFE4E8EC),
    borderStrong: Color(0xFFCFD6DC),
    successBg: Color(0xFFECFDF5),
    warningBg: Color(0xFFF8EFDC),
    dangerBg: Color(0xFFFEF2F2),
    infoBg: Color(0xFFF3F6F8),
    accentSoft: Color(0xFFF8EFDC),
    textPrimary: Color(0xFF1C2830),
    textSecondary: Color(0xFF64748B),
    textMuted: Color(0xFF94A3B8),
    fieldFill: Color(0xFFF8FAFB),
  );

  static const dark = AppPalette(
    brand50: Color(0xFF1C2832),
    brand100: Color(0xFF243440),
    brand200: Color(0xFF3A5164),
    brandInk: Color(0xFF9BB4C5),
    canvas: Color(0xFF10161C),
    surface: Color(0xFF1A222B),
    border: Color(0xFF2C3844),
    borderStrong: Color(0xFF3D4C5A),
    successBg: Color(0xFF123128),
    warningBg: Color(0xFF3A2C16),
    dangerBg: Color(0xFF3A1C1C),
    infoBg: Color(0xFF1C2832),
    accentSoft: Color(0xFF3A2C16),
    textPrimary: Color(0xFFE8EEF3),
    textSecondary: Color(0xFFB0BCC8),
    textMuted: Color(0xFF8B98A6),
    fieldFill: Color(0xFF151C24),
  );
}

/// Design tokens aligned with the web admin (`frontend/src/style.css`).
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

  static const sidebar = Color(0xFF141C24);
  static const sidebarPanel = Color(0xFF1A2630);
  static const sidebarBorder = Color(0x38E39B2B);
  static const sidebarHover = Color(0x474A6D86);
  static const sidebarActive = Color(0xFF4A6D86);
  static const sidebarText = Color(0xB8E8EEF3);

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

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brand700, brand600],
  );

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF12181E), Color(0xFF1A2630), brand700],
  );
}
