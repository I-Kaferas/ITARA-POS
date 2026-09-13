import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

enum StatusBadgeVariant { success, warning, danger, neutral }

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
    final color = switch (variant) {
      StatusBadgeVariant.success => AppColors.success,
      StatusBadgeVariant.warning => AppColors.warning,
      StatusBadgeVariant.danger => AppColors.danger,
      StatusBadgeVariant.neutral => AppColors.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
