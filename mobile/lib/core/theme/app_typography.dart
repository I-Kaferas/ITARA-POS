import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

export 'app_radius.dart';
export 'app_spacing.dart';

/// Official type scale. Prefer named [AppTypography] styles over raw sizes.
///
/// | Role              | Size | Weight |
/// |-------------------|------|--------|
/// | Page title        | 26   | 600    |
/// | Section title     | 18   | 600    |
/// | Subtitle          | 15   | 500    |
/// | Body              | 14   | 400    |
/// | Form / table      | 13   | 400    |
/// | Button            | 14   | 500    |
/// | Label             | 12   | 500    |
/// | KPI               | 28   | 600    |
/// | Amount            | 15   | 500    |
abstract final class AppTextSize {
  /// Labels, badges, navigation captions (12–13).
  static const double label = 12;

  /// Table cells and form fields (13–14).
  static const double form = 13;

  /// Standard body and button size.
  static const double body = 14;

  /// Subtitles and secondary copy (15–16).
  static const double subtitle = 15;

  /// Monetary amounts and figures (14–16).
  static const double amount = 15;

  /// Section and card titles (18–20).
  static const double section = 18;

  /// Page titles (24–28).
  static const double page = 26;

  /// Primary KPIs and hero figures (28–32).
  static const double kpi = 28;

  // Aliases kept for existing call sites.
  static const double xs = label;
  static const double sm = label;
  static const double md = form;
  static const double base = body;
  static const double lg = subtitle;
  static const double xl = section;
  static const double xxl = page;
  static const double display = kpi;
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
    double fontSize = AppTextSize.body,
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
    double fontSize = AppTextSize.amount,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
    double? height,
  }) =>
      GoogleFonts.ibmPlexMono(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );

  /// Primary KPI / hero figure — 28 px · 600.
  static TextStyle kpi({Color? color}) => plex(
        fontSize: AppTextSize.kpi,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: color ?? AppColors.textPrimary,
      );

  /// Alias of [kpi] for legacy call sites.
  static TextStyle display({Color? color}) => kpi(color: color);

  /// Page title — 26 px · 600.
  static TextStyle pageTitle({Color? color}) => plex(
        fontSize: AppTextSize.page,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: color ?? AppColors.textPrimary,
      );

  /// Dialog / card title — 18 px · 600 (same band as section).
  static TextStyle title({Color? color}) => sectionTitle(color: color);

  /// Section title — 18 px · 600.
  static TextStyle sectionTitle({Color? color}) => plex(
        fontSize: AppTextSize.section,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: color ?? AppColors.textPrimary,
      );

  /// Subtitle — 15 px · 500.
  static TextStyle subtitle({Color? color}) => plex(
        fontSize: AppTextSize.subtitle,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.textSecondary,
      );

  /// Standard text — 14 px · 400.
  static TextStyle body({Color? color, FontWeight weight = FontWeight.w400}) => plex(
        fontSize: AppTextSize.body,
        fontWeight: weight,
        color: color ?? AppColors.textPrimary,
      );

  /// Tables and forms — 13 px · 400.
  static TextStyle form({Color? color, FontWeight weight = FontWeight.w400}) => plex(
        fontSize: AppTextSize.form,
        fontWeight: weight,
        color: color ?? AppColors.textPrimary,
      );

  /// Compact secondary text — 12 px · 500 (label band).
  static TextStyle caption({Color? color}) => plex(
        fontSize: AppTextSize.label,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.textMuted,
      );

  /// Field and chip labels — 12 px · 500.
  static TextStyle label({Color? color}) => plex(
        fontSize: AppTextSize.label,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: color ?? AppColors.textSecondary,
      );

  /// Table column headers / overlines — 12 px · 500.
  static TextStyle overline({Color? color}) => plex(
        fontSize: AppTextSize.label,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
        color: color ?? AppColors.textMuted,
      );

  /// Buttons — 14 px · 500.
  static TextStyle button({Color? color}) => plex(
        fontSize: AppTextSize.body,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.textPrimary,
      );

  /// Amounts and figures — 15 px · 500 (IBM Plex Mono).
  static TextStyle money({
    double size = AppTextSize.amount,
    FontWeight weight = FontWeight.w500,
    Color? color,
  }) =>
      mono(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.brandInk,
      );
}
