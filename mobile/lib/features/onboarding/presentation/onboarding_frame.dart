import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';

class OnboardingFrame extends StatelessWidget {
  const OnboardingFrame({super.key, required this.child, this.footer});

  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final reduce = AppMotion.reduceMotion(context);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.canvas,
              Color.alphaBlend(
                AppColors.accent.withValues(alpha: 0.08),
                AppColors.canvas,
              ),
              AppColors.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 1080 : 640),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: wide ? 36 : 20,
                      vertical: wide ? 28 : 16,
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: reduce ? child : AppFadeIn(child: child),
                        ),
                        if (footer != null) ...[
                          const SizedBox(height: 16),
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
      ),
    );
  }
}

class OnboardingMark extends StatelessWidget {
  const OnboardingMark({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 44.0 : 64.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.brand600,
            borderRadius: BorderRadius.circular(compact ? 14 : 18),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            Icons.point_of_sale_rounded,
            color: Colors.white,
            size: compact ? 22 : 32,
          ),
        ),
        SizedBox(width: compact ? 10 : 14),
        Text(
          AppConstants.appName,
          style: GoogleFonts.ibmPlexSans(
            fontSize: compact ? 18 : 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: AppColors.textPrimary,
          ),
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
    final style = GoogleFonts.ibmPlexSans(
      fontWeight: FontWeight.w700,
      fontSize: 15,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    if (primary) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand700,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: shape,
          textStyle: style,
        ),
        child: Text(label),
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        backgroundColor: AppColors.surface.withValues(alpha: 0.72),
        side: BorderSide(color: AppColors.borderStrong),
        minimumSize: const Size.fromHeight(48),
        shape: shape,
        textStyle: style,
      ),
      child: Text(label),
    );
  }
}
