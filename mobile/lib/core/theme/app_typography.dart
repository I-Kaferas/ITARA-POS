import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

export 'app_radius.dart';
export 'app_spacing.dart';

/// Professional scale on a 16 px base: display → xs.
///
/// | Step    | px | Role                          |
/// |---------|----|-------------------------------|
/// | display | 36 | Hero                          |
/// | 3xl     | 28 | Page title, KPI               |
/// | 2xl     | 24 | Large title                   |
/// | xl      | 20 | Section title                 |
/// | lg      | 18 | Small title                   |
/// | md      | 17 | Subtitle                      |
/// | base    | 16 | Body, buttons                 |
/// | sm      | 14 | Forms, secondary              |
/// | xs      | 12 | Labels, captions              |
///
/// Titles use Plus Jakarta Sans. Text uses IBM Plex Sans.
abstract final class AppTextSize {
  static const double xs = 12;
  static const double sm = 14;
  static const double base = 16;
  static const double md = 17;
  static const double lg = 18;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 28;
  static const double display = 36;

  static const double label = xs;
  static const double form = sm;
  static const double body = base;
  static const double subtitle = md;
  static const double amount = base;
  static const double section = xl;
  static const double page = xxxl;
  static const double kpi = xxxl;
}

/// Shared typography — Plus Jakarta Sans for titles, IBM Plex Sans for text,
/// IBM Plex Mono for amounts.
abstract final class AppTypography {
  /// Fonts ship in `assets/google_fonts/`: a terminal must render the same
  /// text whether or not it has ever been online.
  static void useBundledFonts() {
    GoogleFonts.config.allowRuntimeFetching = false;
    LicenseRegistry.addLicense(() async* {
      final license = await rootBundle.loadString('assets/google_fonts/OFL.txt');
      yield LicenseEntryWithLineBreaks(const ['IBM Plex'], license);
      final jakarta = await rootBundle.loadString('assets/google_fonts/PlusJakartaSans-OFL.txt');
      yield LicenseEntryWithLineBreaks(const ['Plus Jakarta Sans'], jakarta);
    });
  }

  static const _bodySteps = <double>[12, 14, 16, 17];
  static const _titleSteps = <double>[16, 18, 20, 24, 28, 36];

  static double _nearest(double size, List<double> steps) {
    var best = steps.first;
    var bestDistance = (size - best).abs();
    for (final step in steps) {
      final distance = (size - step).abs();
      if (distance < bestDistance || (distance == bestDistance && step > best)) {
        best = step;
        bestDistance = distance;
      }
    }
    return best;
  }

  /// Snaps a raw size onto the scale and uses Plus Jakarta Sans for titles.
  static TextStyle text({
    TextStyle? textStyle,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    final size = fontSize ?? textStyle?.fontSize ?? AppTextSize.base;
    final weight = fontWeight ?? textStyle?.fontWeight ?? FontWeight.w400;
    final style = fontStyle ?? textStyle?.fontStyle;
    final title = style != FontStyle.italic && weight.value >= FontWeight.w600.value && size >= 15;
    final snapped = title ? _nearest(size, _titleSteps) : _nearest(size, _bodySteps);
    final resolved = title
        ? GoogleFonts.plusJakartaSans(
            fontSize: snapped,
            fontWeight: weight,
            fontStyle: style,
            color: color ?? textStyle?.color,
            height: height ?? textStyle?.height,
            letterSpacing: letterSpacing ?? textStyle?.letterSpacing,
          )
        : GoogleFonts.ibmPlexSans(
            fontSize: snapped,
            fontWeight: weight,
            fontStyle: style,
            color: color ?? textStyle?.color,
            height: height ?? textStyle?.height,
            letterSpacing: letterSpacing ?? textStyle?.letterSpacing,
          );
    return resolved;
  }

  static TextStyle plex({
    double fontSize = AppTextSize.body,
    FontWeight fontWeight = FontWeight.w400,
    FontStyle? fontStyle,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      text(
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle jakarta({
    double fontSize = AppTextSize.section,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      text(
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

  /// Display — 36 px · Plus Jakarta Sans 700.
  static TextStyle display({Color? color}) => jakarta(
        fontSize: AppTextSize.display,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -0.8,
        color: color ?? AppColors.textPrimary,
      );

  /// KPI figure — 28 px · Plus Jakarta Sans 600.
  static TextStyle kpi({Color? color}) => jakarta(
        fontSize: AppTextSize.kpi,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: -0.5,
        color: color ?? AppColors.textPrimary,
      );

  /// Page title — 28 px · Plus Jakarta Sans 700.
  static TextStyle pageTitle({Color? color}) => jakarta(
        fontSize: AppTextSize.page,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.4,
        color: color ?? AppColors.textPrimary,
      );

  /// Large title — 24 px · Plus Jakarta Sans 700.
  static TextStyle titleLarge({Color? color}) => jakarta(
        fontSize: AppTextSize.xxl,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: -0.3,
        color: color ?? AppColors.textPrimary,
      );

  /// Dialog / card title — 20 px · Plus Jakarta Sans 600.
  static TextStyle title({Color? color}) => sectionTitle(color: color);

  /// Section title — 20 px · Plus Jakarta Sans 600.
  static TextStyle sectionTitle({Color? color}) => jakarta(
        fontSize: AppTextSize.section,
        fontWeight: FontWeight.w600,
        height: 1.25,
        letterSpacing: -0.2,
        color: color ?? AppColors.textPrimary,
      );

  /// Small title — 18 px · Plus Jakarta Sans 600.
  static TextStyle titleSmall({Color? color}) => jakarta(
        fontSize: AppTextSize.lg,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: color ?? AppColors.textPrimary,
      );

  /// Subtitle — 17 px · IBM Plex Sans 500.
  static TextStyle subtitle({Color? color}) => plex(
        fontSize: AppTextSize.subtitle,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: color ?? AppColors.textSecondary,
      );

  /// Standard text — 16 px · IBM Plex Sans 400.
  static TextStyle body({Color? color, FontWeight weight = FontWeight.w400}) => plex(
        fontSize: AppTextSize.body,
        fontWeight: weight,
        height: 1.5,
        color: color ?? AppColors.textPrimary,
      );

  /// Tables and forms — 14 px · IBM Plex Sans 400.
  static TextStyle form({Color? color, FontWeight weight = FontWeight.w400}) => plex(
        fontSize: AppTextSize.form,
        fontWeight: weight,
        height: 1.45,
        color: color ?? AppColors.textPrimary,
      );

  /// Compact secondary text — 12 px · IBM Plex Sans 500.
  static TextStyle caption({Color? color}) => plex(
        fontSize: AppTextSize.xs,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.textMuted,
      );

  /// Field and chip labels — 12 px · IBM Plex Sans 500.
  static TextStyle label({Color? color}) => plex(
        fontSize: AppTextSize.xs,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: color ?? AppColors.textSecondary,
      );

  /// Table column headers / overlines — 12 px · IBM Plex Sans 500.
  static TextStyle overline({Color? color}) => plex(
        fontSize: AppTextSize.xs,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
        color: color ?? AppColors.textMuted,
      );

  /// Buttons — 16 px · IBM Plex Sans 500.
  static TextStyle button({Color? color}) => plex(
        fontSize: AppTextSize.base,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.textPrimary,
      );

  /// Amounts and figures — 16 px · IBM Plex Mono 500.
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
