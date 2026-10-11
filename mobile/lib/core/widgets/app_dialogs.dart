import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_typography.dart';
import 'app_buttons.dart';

Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  Color? backgroundColor,
  ShapeBorder? shape,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
      backgroundColor: backgroundColor ?? AppColors.surface,
      barrierColor: const Color(0x7514202B),
    shape: shape,
    sheetAnimationStyle: AnimationStyle(
      duration: AppMotion.resolve(context, AppMotion.modal),
      reverseDuration: AppMotion.resolve(context, AppMotion.content),
    ),
    builder: builder,
  );
}

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
      barrierColor: const Color(0x7514202B),
      transitionDuration: AppMotion.reduceMotion(context) ? Duration.zero : AppMotion.modal,
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
        if (AppMotion.reduceMotion(context)) return child;
        final curved = CurvedAnimation(parent: animation, curve: AppMotion.standard);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(curved),
            child: ScaleTransition(
              scale: Tween(begin: 0.98, end: 1.0).animate(curved),
              child: child,
            ),
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
      barrierColor: const Color(0x7514202B),
      sheetAnimationStyle: AnimationStyle(
        duration: AppMotion.resolve(context, AppMotion.modal),
        reverseDuration: AppMotion.resolve(context, AppMotion.content),
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
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
    final hasActions = actions != null && actions!.isNotEmpty;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Color(0x1414202B), blurRadius: 32, offset: Offset(0, 12)),
          ],
        ),
        child: Material(
          color: AppColors.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.infoBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.layers_outlined, color: AppColors.info, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: AppTypography.plex(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Icons.close, color: AppColors.textMuted, size: 20),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.border),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.62),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (message != null)
                        Text(message!, style: AppTypography.body(color: AppColors.textSecondary)),
                      if (content != null) ...[
                        if (message != null) const SizedBox(height: AppSpacing.md),
                        content!,
                      ],
                    ],
                  ),
                ),
              ),
              if (hasActions)
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                  decoration: BoxDecoration(
                    color: AppColors.canvas,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: actions!,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
