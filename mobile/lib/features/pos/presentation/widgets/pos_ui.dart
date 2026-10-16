import 'package:flutter/material.dart';

import '../../../../core/layout/android_form_factor.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_controller.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

/// Spacing / radius tokens for the POS caisse surface.
abstract final class PosUi {
  static const double spaceXs = AppSpace.xs;
  static const double spaceSm = AppSpace.sm;
  static const double spaceMd = AppSpace.md;
  static const double spaceLg = AppSpace.lg;
  static const double spaceXl = AppSpace.xl;

  static const double radiusSm = AppRadius.sm;
  static const double radiusMd = AppRadius.lg;
  static const double radiusLg = 14;
  static const double radiusXl = AppRadius.xl;

  static const double touchMin = 44;
  static const double ctaHeight = 48;

  /// Desk 3-pane layout (aligned with app shell wide ≥900).
  static const double deskBreakpoint = AndroidLayout.tabletMax;
  static const double wideBreakpoint = AndroidLayout.tabletMax;
  /// Ultra-wide Windows POS desk (≥1280).
  static const double windowsDeskBreakpoint = 1280;
  static const double tabletBreakpoint = 720;
  static const double phoneBreakpoint = AndroidLayout.phoneMax;

  static const double categoryWidth = 208;
  static const double categoryWidthWindows = 220;
  static const double cartWidth = 340;
  static const double cartWidthWindows = 420;

  /// Cashier surface. Dark desk at night, the light canvas when the app is in light mode.
  static bool get isDarkDesk => ThemeController.instance.isDark;

  static const Color deskInk = Color(0xFF12243C);
  static const Color deskAccent = Color(0xFFE39B2B);
  static const Color deskPay = Color(0xFF1FA971);

  static Color get deskNight => isDarkDesk ? const Color(0xFF0C1422) : AppColors.canvas;
  static Color get deskPanel => isDarkDesk ? const Color(0xFF121A2B) : AppColors.surface;
  static Color get deskCard => isDarkDesk ? const Color(0xFF182233) : AppColors.surface;
  static Color get deskField => isDarkDesk ? const Color(0xFF101828) : AppColors.fieldFill;
  static Color get deskLine => isDarkDesk ? const Color(0xFF2C3A50) : AppColors.border;
  static Color get deskText => isDarkDesk ? const Color(0xFFF4F7FB) : AppColors.textPrimary;
  static Color get deskMuted => isDarkDesk ? const Color(0xFF9AABBE) : AppColors.textSecondary;
  static Color get deskStock => isDarkDesk ? const Color(0xFF3DDC97) : AppColors.success;
  static Color get deskPhoto => isDarkDesk ? const Color(0xFFE8EDF2) : const Color(0xFFE7EBEF);
  static Color get deskRaised => isDarkDesk ? const Color(0xFF243044) : AppColors.brand100;
  static Color get deskSoft => isDarkDesk ? const Color(0xFF1B2536) : AppColors.fieldFill;
  static Color get deskSuccessBg => isDarkDesk ? const Color(0xFF143528) : AppColors.successBg;

  static bool isWindowsDesk(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= windowsDeskBreakpoint;

  static Color get deskCanvas => AppColors.canvas;
  static Color get productsCanvas => AppColors.surfaceVariant;
  static Color get cartCanvas => AppColors.surface;

  static bool isDesk(BuildContext context) =>
      AndroidLayout.of(context).isDesk;

  static bool isWide(BuildContext context) => isDesk(context);

  static bool isDesktop(BuildContext context) => isDesk(context);

  static bool isPhone(BuildContext context) =>
      AndroidLayout.of(context).isPhone;

  static bool isTablet(BuildContext context) =>
      AndroidLayout.of(context).isTablet;

  /// §18 tablette : Sidebar + Product Grid + Cart.
  static bool usePosThreePane(BuildContext context) =>
      AndroidLayout.of(context).usePosThreePane;

  static EdgeInsets pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= deskBreakpoint) {
      return const EdgeInsets.fromLTRB(24, 18, 24, 24);
    }
    if (width >= tabletBreakpoint) {
      return const EdgeInsets.fromLTRB(18, 14, 18, 20);
    }
    return const EdgeInsets.fromLTRB(14, 12, 14, 18);
  }

  static double contentMaxWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= deskBreakpoint ? 980 : width;
  }

  static TextStyle sectionLabel({Color? color}) => AppTypography.plex(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        color: color ?? AppColors.textMuted,
      );

  static TextStyle cardTitle({Color? color}) => AppTypography.plex(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle body({Color? color, FontWeight weight = FontWeight.w500}) =>
      AppTypography.plex(
        fontSize: 13,
        fontWeight: weight,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle caption({Color? color}) => AppTypography.caption(color: color);

  static TextStyle money({
    double size = 14,
    FontWeight weight = FontWeight.w600,
    Color? color,
  }) =>
      AppTypography.money(size: size, weight: weight, color: color);

  static TextStyle totalCaption() => AppTypography.plex(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppColors.textSecondary,
      );

  static TextStyle totalAmount({double size = 28, Color? color}) =>
      AppTypography.money(
        size: size,
        weight: FontWeight.w700,
        color: color ?? AppColors.brandInk,
      );
}

enum PosBadgeTone { brand, success, warning, danger, neutral }

class PosBadge extends StatelessWidget {
  const PosBadge({
    super.key,
    required this.label,
    this.tone = PosBadgeTone.brand,
    this.compact = false,
  });

  final String label;
  final PosBadgeTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      PosBadgeTone.brand => (AppColors.brand100, AppColors.brandInk),
      PosBadgeTone.success => (AppColors.successBg, AppColors.success),
      PosBadgeTone.warning => (AppColors.warningBg, AppColors.warning),
      PosBadgeTone.danger => (AppColors.dangerBg, AppColors.danger),
      PosBadgeTone.neutral => (AppColors.fieldFill, AppColors.textSecondary),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: fg.withValues(alpha: 0.16)),
      ),
      child: Text(
        tr(label),
        style: AppTypography.plex(
          fontSize: compact ? 9.5 : 10.5,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
