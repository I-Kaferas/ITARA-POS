import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum AppCardElevation { flat, raised, float }

/// Design-system surface card — coherent borders, optional press feedback.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.elevation = AppCardElevation.flat,
    this.color,
    this.borderColor,
    this.width,
    this.height,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final AppCardElevation elevation;
  final Color? color;
  final Color? borderColor;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final shadows = switch (elevation) {
      AppCardElevation.flat => AppShadows.none,
      AppCardElevation.raised => AppShadows.sm,
      AppCardElevation.float => AppShadows.float,
    };

    final content = AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      width: width,
      height: height,
      margin: margin,
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: borderColor ?? AppColors.border),
        boxShadow: shadows,
      ),
      child: child,
    );

    if (onTap == null) return content;

    return AppTapScale(
      onTap: onTap,
      child: content,
    );
  }
}

/// Section header inside cards / pages.
class AppCardHeader extends StatelessWidget {
  const AppCardHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.sectionTitle()),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(subtitle!, style: AppTypography.subtitle()),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}
