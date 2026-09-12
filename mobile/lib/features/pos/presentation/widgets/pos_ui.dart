import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

/// Spacing / radius tokens for the POS caisse surface (aligned with web PosView).
abstract final class PosUi {
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 20;

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 14;
  static const double radiusXl = 16;

  static const double touchMin = 40;
  static const double ctaHeight = 52;

  /// Desk 3-pane layout (aligned with app shell wide ≥900).
  static const double deskBreakpoint = 900;
  static const double wideBreakpoint = 900;
  static const double tabletBreakpoint = 720;
  static const double phoneBreakpoint = 600;

  /// Web `.pos-categories` ≈ 13.5rem
  static const double categoryWidth = 216;

  /// Web `.pos-cart` ≈ 22rem
  static const double cartWidth = 352;

  /// Web `.pos-root` background
  static const Color deskCanvas = Color(0xFFEEF2F6);

  /// Web `.pos-products` background
  static const Color productsCanvas = Color(0xFFF4F7FA);

  /// Web cart panel background
  static const Color cartCanvas = Color(0xFFFBFCFF);

  static bool isDesk(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= deskBreakpoint;

  static bool isWide(BuildContext context) => isDesk(context);

  static bool isPhone(BuildContext context) =>
      MediaQuery.sizeOf(context).width < phoneBreakpoint;

  static EdgeInsets pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= deskBreakpoint) {
      return const EdgeInsets.fromLTRB(28, 20, 28, 28);
    }
    if (width >= tabletBreakpoint) {
      return const EdgeInsets.fromLTRB(20, 16, 20, 24);
    }
    return const EdgeInsets.fromLTRB(16, 14, 16, 20);
  }

  static double contentMaxWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= deskBreakpoint ? 980 : width;
  }

  static TextStyle sectionLabel({Color? color}) => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.9,
        color: color ?? AppColors.textMuted,
      );

  static TextStyle cardTitle({Color? color}) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle body({Color? color, FontWeight weight = FontWeight.w500}) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: weight,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle caption({Color? color}) => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.textMuted,
      );

  static TextStyle money({
    double size = 14,
    FontWeight weight = FontWeight.w700,
    Color? color,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.brandInk,
      );

  static TextStyle totalCaption() => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: AppColors.textSecondary,
      );

  static TextStyle totalAmount({double size = 30, Color? color}) => GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.1,
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
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: fg.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
