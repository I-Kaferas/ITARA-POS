import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

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
  static const double deskBreakpoint = 900;
  static const double wideBreakpoint = 900;
  static const double tabletBreakpoint = 720;
  static const double phoneBreakpoint = 600;

  static const double categoryWidth = 208;
  static const double cartWidth = 340;

  static Color get deskCanvas => AppColors.canvas;
  static Color get productsCanvas => AppColors.surfaceVariant;
  static Color get cartCanvas => AppColors.surface;

  static bool isDesk(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= deskBreakpoint;

  static bool isWide(BuildContext context) => isDesk(context);

  static bool isDesktop(BuildContext context) => isDesk(context);

  static bool isPhone(BuildContext context) =>
      MediaQuery.sizeOf(context).width < phoneBreakpoint;

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
        label,
        style: AppTypography.plex(
          fontSize: compact ? 9.5 : 10.5,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
