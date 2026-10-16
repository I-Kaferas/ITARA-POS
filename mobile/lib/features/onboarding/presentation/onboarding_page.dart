import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

class OnboardingPageData {
  const OnboardingPageData({
    required this.title,
    required this.body,
    required this.points,
    required this.icon,
    required this.tint,
  });

  final String title;
  final String body;
  final List<String> points;
  final IconData icon;
  final Color tint;
}

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key, required this.data});

  final OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 760;
        final illustration = _Illustration(data: data);
        final copy = _Copy(data: data);
        if (stacked) {
          return Column(
            children: [
              Expanded(flex: 4, child: illustration),
              const SizedBox(height: 16),
              Expanded(flex: 5, child: copy),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: illustration),
            const SizedBox(width: 28),
            Expanded(child: copy),
          ],
        );
      },
    );
  }
}

class _Copy extends StatelessWidget {
  const _Copy({required this.data});

  final OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(data.title),
          style: GoogleFonts.ibmPlexSans(
            fontSize: 32,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          tr(data.body),
          style: GoogleFonts.ibmPlexSans(
            fontSize: 16,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 18),
        for (final point in data.points) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_rounded, size: 18, color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr(point),
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    height: 1.35,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({required this.data});

  final OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: data.tint.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(data.icon, size: 42, color: data.tint),
            ),
            const SizedBox(height: 16),
            Text(
              tr('Illustration'),
              style: GoogleFonts.ibmPlexSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
