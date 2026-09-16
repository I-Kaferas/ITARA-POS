import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum StatusBadgeVariant { success, warning, danger, neutral, info }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.variant,
  });

  final String label;
  final StatusBadgeVariant variant;

  static StatusBadgeVariant forSessionStatus(String status) {
    return switch (status) {
      'open' => StatusBadgeVariant.success,
      'closed' => StatusBadgeVariant.neutral,
      'cancelled' => StatusBadgeVariant.danger,
      _ => StatusBadgeVariant.warning,
    };
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (variant) {
      StatusBadgeVariant.success => (AppColors.successBg, AppColors.success),
      StatusBadgeVariant.warning => (AppColors.warningBg, AppColors.warning),
      StatusBadgeVariant.danger => (AppColors.dangerBg, AppColors.danger),
      StatusBadgeVariant.info => (AppColors.infoBg, AppColors.info),
      StatusBadgeVariant.neutral => (AppColors.fieldFill, AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: fg.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.plex(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
