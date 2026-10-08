import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Shared typography — IBM Plex Sans (+ IBM Plex Mono for amounts).
abstract final class AppTypography {
  static TextStyle plex({
    double fontSize = 14,
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
    double fontSize = 14,
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
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle pageTitle({Color? color}) => plex(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle sectionTitle({Color? color}) => plex(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle subtitle({Color? color}) => plex(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.textSecondary,
      );

  static TextStyle body({Color? color, FontWeight weight = FontWeight.w400}) => plex(
        fontSize: 13.5,
        fontWeight: weight,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle caption({Color? color}) => plex(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.textMuted,
      );

  static TextStyle label({Color? color}) => plex(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: color ?? AppColors.textSecondary,
      );

  static TextStyle button({Color? color}) => plex(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle money({
    double size = 14,
    FontWeight weight = FontWeight.w600,
    Color? color,
  }) =>
      mono(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.brandInk,
      );
}
