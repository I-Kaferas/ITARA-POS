import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Elevation tokens — soft shadows for a premium, calm surface hierarchy.
abstract final class AppShadows {
  static List<BoxShadow> get none => const [];

  static List<BoxShadow> get sm => [
        BoxShadow(
          color: AppColors.shadow,
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get md => [
        BoxShadow(
          color: AppColors.shadow,
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get lg => [
        BoxShadow(
          color: AppColors.shadow,
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ];

  static List<BoxShadow> get float => [
        BoxShadow(
          color: AppColors.shadow,
          blurRadius: 20,
          spreadRadius: -2,
          offset: const Offset(0, 8),
        ),
      ];
}
