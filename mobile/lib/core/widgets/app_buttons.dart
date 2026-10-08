import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum AppButtonVariant { primary, secondary, ghost, danger, accent }

enum AppButtonSize { sm, md, lg }

/// Design-system button — tactile, 44px+ targets, consistent across POS.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.icon,
    this.expanded = false,
    this.loading = false,
  });

  const AppButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.md,
    this.icon,
    this.expanded = false,
    this.loading = false,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.md,
    this.icon,
    this.expanded = false,
    this.loading = false,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.md,
    this.icon,
    this.expanded = false,
    this.loading = false,
  }) : variant = AppButtonVariant.ghost;

  const AppButton.danger({
    super.key,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.md,
    this.icon,
    this.expanded = false,
    this.loading = false,
  }) : variant = AppButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool expanded;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final height = switch (size) {
      AppButtonSize.sm => 40.0,
      AppButtonSize.md => AppSpacing.ctaHeight,
      AppButtonSize.lg => 56.0,
    };
    final padH = switch (size) {
      AppButtonSize.sm => AppSpacing.md,
      AppButtonSize.md => AppSpacing.lg,
      AppButtonSize.lg => AppSpacing.xl,
    };
    final (bg, fg, border) = _colors(enabled);

    final child = AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      height: height,
      padding: EdgeInsets.symmetric(horizontal: padH),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.borderMd,
        border: border != null ? Border.all(color: border) : null,
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: fg,
              ),
            )
          else ...[
            if (icon != null) ...[
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: AppSpacing.sm),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.button(color: fg),
              ),
            ),
          ],
        ],
      ),
    );

    return AppTapScale(
      enabled: enabled,
      onTap: enabled ? onPressed : null,
      child: expanded ? SizedBox(width: double.infinity, child: child) : child,
    );
  }

  (Color, Color, Color?) _colors(bool enabled) {
    if (!enabled) {
      return (
        AppColors.brand50,
        AppColors.textMuted,
        AppColors.border,
      );
    }
    return switch (variant) {
      AppButtonVariant.primary => (AppColors.brand600, Colors.white, null),
      AppButtonVariant.accent => (AppColors.accent, AppColors.brand900, null),
      AppButtonVariant.secondary => (
          AppColors.surface,
          AppColors.brand700,
          AppColors.borderStrong,
        ),
      AppButtonVariant.ghost => (Colors.transparent, AppColors.brand700, null),
      AppButtonVariant.danger => (AppColors.danger, Colors.white, null),
    };
  }
}

/// Compact icon-only control for toolbars.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.tone,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final color = tone ?? AppColors.brandInk;
    final button = AppTapScale(
      onTap: onPressed,
      child: Container(
        width: AppSpacing.touchMin,
        height: AppSpacing.touchMin,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: AppRadius.borderMd,
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
