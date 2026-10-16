import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

export 'app_radius.dart';
export 'app_spacing.dart';

/// The only font sizes the UI should use. Pick the closest step instead of a
/// half-point value.
abstract final class AppTextSize {
  /// Badges, overlines, navigation labels.
  static const double xs = 11;

  /// Captions, field labels, table cells.
  static const double sm = 12;

  /// Secondary text, chips, tabs.
  static const double md = 13;

  /// Body text and buttons.
  static const double base = 14;

  /// Section and card titles.
  static const double lg = 16;

  /// Dialog titles, prominent card figures.
  static const double xl = 18;

  /// Page titles.
  static const double xxl = 22;

  /// Hero headings and large totals.
  static const double display = 28;
}

/// Shared typography — IBM Plex Sans (+ IBM Plex Mono for amounts).
abstract final class AppTypography {
  /// IBM Plex ships in `assets/google_fonts/`: a terminal must render the same
  /// text whether or not it has ever been online.
  static void useBundledFonts() {
    GoogleFonts.config.allowRuntimeFetching = false;
    LicenseRegistry.addLicense(() async* {
      final license = await rootBundle.loadString('assets/google_fonts/OFL.txt');
      yield LicenseEntryWithLineBreaks(const ['IBM Plex'], license);
    });
  }

  static TextStyle plex({
    double fontSize = AppTextSize.base,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.ibmPlexSans(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle mono({
    double fontSize = AppTextSize.base,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double? height,
  }) =>
      GoogleFonts.ibmPlexMono(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );

  static TextStyle display({Color? color}) => plex(
        fontSize: AppTextSize.display,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle pageTitle({Color? color}) => plex(
        fontSize: AppTextSize.xxl,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle title({Color? color}) => plex(
        fontSize: AppTextSize.xl,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle sectionTitle({Color? color}) => plex(
        fontSize: AppTextSize.lg,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle subtitle({Color? color}) => plex(
        fontSize: AppTextSize.md,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.textSecondary,
      );

  static TextStyle body({Color? color, FontWeight weight = FontWeight.w400}) => plex(
        fontSize: AppTextSize.base,
        fontWeight: weight,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle caption({Color? color}) => plex(
        fontSize: AppTextSize.sm,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.textMuted,
      );

  static TextStyle label({Color? color}) => plex(
        fontSize: AppTextSize.sm,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: color ?? AppColors.textSecondary,
      );

  static TextStyle overline({Color? color}) => plex(
        fontSize: AppTextSize.xs,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: color ?? AppColors.textMuted,
      );

  static TextStyle button({Color? color}) => plex(
        fontSize: AppTextSize.base,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle money({
    double size = AppTextSize.base,
    FontWeight weight = FontWeight.w600,
    Color? color,
  }) =>
      mono(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.brandInk,
      );
}
