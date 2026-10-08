import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_buttons.dart';

/// Design-system dialogs — consistent chrome for confirms, alerts, sheets.
abstract final class AppDialogs {
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? message,
    Widget? content,
    List<Widget>? Function(BuildContext dialogContext)? actionsBuilder,
    bool barrierDismissible = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: AppMotion.normal,
      pageBuilder: (dialogContext, animation, secondary) {
        return SafeArea(
          child: Center(
            child: AppDialogFrame(
              title: title,
              message: message,
              content: content,
              actions: actionsBuilder?.call(dialogContext),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondary, child) {
        final curved = CurvedAnimation(parent: animation, curve: AppMotion.standard);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  static Future<bool> confirm({
    required BuildContext context,
    required String title,
    String? message,
    String confirmLabel = 'Confirmer',
    String cancelLabel = 'Annuler',
    bool destructive = false,
  }) async {
    final result = await show<bool>(
      context: context,
      title: title,
      message: message,
      actionsBuilder: (dialogContext) => [
        AppButton.secondary(
          label: cancelLabel,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        if (destructive)
          AppButton.danger(
            label: confirmLabel,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          )
        else
          AppButton.primary(
            label: confirmLabel,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
      ],
    );
    return result ?? false;
  }

  static Future<void> alert({
    required BuildContext context,
    required String title,
    String? message,
    String okLabel = 'OK',
  }) {
    return show<void>(
      context: context,
      title: title,
      message: message,
      actionsBuilder: (dialogContext) => [
        AppButton.primary(
          label: okLabel,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
      ],
    );
  }

  static Future<T?> sheet<T>({
    required BuildContext context,
    required Widget child,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: child,
      ),
    );
  }
}

class AppDialogFrame extends StatelessWidget {
  const AppDialogFrame({
    super.key,
    required this.title,
    this.message,
    this.content,
    this.actions,
  });

  final String title;
  final String? message;
  final Widget? content;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          margin: const EdgeInsets.all(AppSpacing.xl),
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.borderXl,
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.elevationMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppTypography.sectionTitle()),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(message!, style: AppTypography.body(color: AppColors.textSecondary)),
              ],
              if (content != null) ...[
                const SizedBox(height: AppSpacing.lg),
                content!,
              ],
              if (actions != null && actions!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: actions!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
