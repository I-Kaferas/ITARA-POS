import 'package:flutter/material.dart';

import '../errors/app_error.dart';
import '../errors/error_resolver.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_buttons.dart';
import 'app_skeleton.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({
    super.key,
    this.message = 'Chargement…',
    this.skeleton = false,
  });

  final String message;
  final bool skeleton;

  @override
  Widget build(BuildContext context) {
    if (skeleton) {
      return const AppSkeletonPage();
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.brand500,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(message, style: AppTypography.subtitle()),
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.title = 'Une erreur est survenue',
    this.onRetry,
    this.retryLabel = 'Réessayer',
  });

  /// Builds from a typed [AppError] (title + reassuring detail).
  factory ErrorView.fromAppError(
    AppError error, {
    Key? key,
    VoidCallback? onRetry,
    String retryLabel = 'Réessayer',
  }) {
    return ErrorView(
      key: key,
      title: error.title,
      message: error.detail?.trim().isNotEmpty == true
          ? error.detail!
          : error.title,
      onRetry: onRetry,
      retryLabel: retryLabel,
    );
  }

  /// Resolves any thrown value into a user-safe ErrorView.
  factory ErrorView.fromError(
    Object? error, {
    Key? key,
    VoidCallback? onRetry,
    String retryLabel = 'Réessayer',
  }) {
    return ErrorView.fromAppError(
      resolveAppError(error),
      key: key,
      onRetry: onRetry,
      retryLabel: retryLabel,
    );
  }

  final String message;
  final String title;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return AppFadeIn(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.dangerBg,
                    borderRadius: AppRadius.borderXl,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.danger,
                    size: 32,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTypography.sectionTitle(),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppTypography.body(color: AppColors.textSecondary),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  AppButton.primary(
                    label: retryLabel,
                    icon: Icons.refresh_rounded,
                    onPressed: onRetry,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline error banner for forms / panels.
class AppErrorBanner extends StatelessWidget {
  const AppErrorBanner({
    super.key,
    required this.message,
    this.onDismiss,
  });

  factory AppErrorBanner.fromAppError(
    AppError error, {
    Key? key,
    VoidCallback? onDismiss,
  }) {
    return AppErrorBanner(
      key: key,
      message: error.userMessage,
      onDismiss: onDismiss,
    );
  }

  final String message;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.body(color: AppColors.danger, weight: FontWeight.w500),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              icon: Icon(Icons.close, size: 16, color: AppColors.danger),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
