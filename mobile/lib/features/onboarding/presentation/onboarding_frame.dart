import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import 'package:pos_mobile/core/i18n/tr.dart';
import 'package:pos_mobile/core/theme/app_typography.dart';

class OnboardingFrame extends StatelessWidget {
  const OnboardingFrame({super.key, required this.child, this.footer});

  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final reduce = AppMotion.reduceMotion(context);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _OnboardingBackdrop(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 1120 : 680),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: wide ? 40 : 20,
                        vertical: wide ? 28 : 16,
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: reduce ? child : AppFadeIn(child: child),
                          ),
                          if (footer != null) ...[
                            const SizedBox(height: 18),
                            footer!,
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingBackdrop extends StatelessWidget {
  const _OnboardingBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.canvas,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(
              AppColors.brand600.withValues(alpha: 0.04),
              AppColors.canvas,
            ),
            AppColors.canvas,
            Color.alphaBlend(
              AppColors.accent.withValues(alpha: 0.05),
              AppColors.canvas,
            ),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _GridPainter(
          color: AppColors.brand600.withValues(alpha: 0.035),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const step = 48.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.color != color;
}

class OnboardingMark extends StatelessWidget {
  const OnboardingMark({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 40.0 : 56.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.brand600,
            borderRadius: BorderRadius.circular(compact ? 12 : 16),
            boxShadow: [
              BoxShadow(
                color: AppColors.brand600.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            Icons.point_of_sale_rounded,
            color: Colors.white,
            size: compact ? 20 : 28,
          ),
        ),
        SizedBox(width: compact ? 10 : 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr(AppConstants.appName),
              style: AppTypography.text(
                fontSize: compact ? 17 : 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                height: 1.05,
                color: AppColors.textPrimary,
              ),
            ),
            if (!compact)
              Text(
                tr('Point de vente professionnel'),
                style: AppTypography.text(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class OnboardingButton extends StatelessWidget {
  const OnboardingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.text(
      fontWeight: FontWeight.w600,
      fontSize: 15,
      letterSpacing: -0.1,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    if (primary) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand700,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.brand200,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          shape: shape,
          textStyle: style,
        ),
        child: Text(tr(label)),
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        backgroundColor: AppColors.surface.withValues(alpha: 0.85),
        disabledForegroundColor: AppColors.textMuted,
        side: BorderSide(color: AppColors.borderStrong),
        minimumSize: const Size.fromHeight(52),
        elevation: 0,
        shape: shape,
        textStyle: style,
      ),
      child: Text(tr(label)),
    );
  }
}

class OnboardingPanel extends StatelessWidget {
  const OnboardingPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.tint,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            if (tint != null)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 4, color: tint),
              ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}
