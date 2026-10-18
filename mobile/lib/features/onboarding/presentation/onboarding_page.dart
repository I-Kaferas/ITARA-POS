import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'onboarding_frame.dart';
import 'package:pos_mobile/core/i18n/tr.dart';
import 'package:pos_mobile/core/theme/app_typography.dart';

enum OnboardingVisual { commerce, pos, hospitality, control }

class OnboardingPageData {
  const OnboardingPageData({
    required this.title,
    required this.body,
    required this.points,
    required this.icon,
    required this.tint,
    required this.visual,
    required this.eyebrow,
  });

  final String title;
  final String body;
  final List<String> points;
  final IconData icon;
  final Color tint;
  final OnboardingVisual visual;
  final String eyebrow;
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
              Expanded(flex: 5, child: illustration),
              const SizedBox(height: 18),
              Expanded(flex: 6, child: copy),
            ],
          );
        }
        return Row(
          children: [
            Expanded(flex: 11, child: illustration),
            const SizedBox(width: 32),
            Expanded(flex: 10, child: copy),
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
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: data.tint.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            tr(data.eyebrow),
            style: AppTypography.text(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: data.tint,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          tr(data.title),
          style: AppTypography.text(
            fontSize: 34,
            height: 1.12,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.7,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          tr(data.body),
          style: AppTypography.text(
            fontSize: 16,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 22),
        for (var i = 0; i < data.points.length; i++) ...[
          _PointRow(index: i + 1, text: data.points[i], tint: data.tint),
          if (i < data.points.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _PointRow extends StatelessWidget {
  const _PointRow({
    required this.index,
    required this.text,
    required this.tint,
  });

  final int index;
  final String text;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$index',
            style: AppTypography.text(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: tint,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              tr(text),
              style: AppTypography.text(
                fontSize: 14,
                height: 1.4,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({required this.data});

  final OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return OnboardingPanel(
      tint: data.tint,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: data.tint.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(data.icon, color: data.tint, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr(data.title),
                  style: AppTypography.text(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(child: _VisualBody(visual: data.visual, tint: data.tint)),
        ],
      ),
    );
  }
}

class _VisualBody extends StatelessWidget {
  const _VisualBody({required this.visual, required this.tint});

  final OnboardingVisual visual;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    switch (visual) {
      case OnboardingVisual.commerce:
        return _CommerceVisual(tint: tint);
      case OnboardingVisual.pos:
        return _PosVisual(tint: tint);
      case OnboardingVisual.hospitality:
        return _HospitalityVisual(tint: tint);
      case OnboardingVisual.control:
        return _ControlVisual(tint: tint);
    }
  }
}

class _CommerceVisual extends StatelessWidget {
  const _CommerceVisual({required this.tint});
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MiniBar(label: tr('Catalogue'), value: '248', tint: tint),
        const SizedBox(height: 8),
        _MiniBar(label: tr('En stock'), value: '1 842', tint: tint),
        const SizedBox(height: 8),
        _MiniBar(label: tr('À commander'), value: '12', tint: AppColors.warning),
        const Spacer(),
        Row(
          children: [
            Expanded(child: _MetricChip(label: tr('Achats'), value: 'OK')),
            const SizedBox(width: 8),
            Expanded(child: _MetricChip(label: tr('Prix'), value: 'Sync')),
          ],
        ),
      ],
    );
  }
}

class _PosVisual extends StatelessWidget {
  const _PosVisual({required this.tint});
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TicketLine(left: 'Espresso × 2', right: '16 000'),
        _TicketLine(left: 'Croissant × 1', right: '2 500'),
        _TicketLine(left: 'Jus orange × 1', right: '3 500'),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Text(
                tr('À encaisser'),
                style: AppTypography.text(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '22 000',
                style: AppTypography.text(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: tint,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _PayPill(label: tr('Espèces'), active: true, tint: tint),
            ),
            const SizedBox(width: 8),
            Expanded(child: _PayPill(label: tr('Carte'), tint: tint)),
            const SizedBox(width: 8),
            Expanded(child: _PayPill(label: tr('Mobile'), tint: tint)),
          ],
        ),
      ],
    );
  }
}

class _HospitalityVisual extends StatelessWidget {
  const _HospitalityVisual({required this.tint});
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _TableTile(label: 'T1', status: tr('Libre'), free: true),
        _TableTile(label: 'T2', status: tr('Occupée'), free: false, tint: tint),
        _TableTile(label: 'T3', status: tr('Libre'), free: true),
        _TableTile(label: 'T4', status: tr('Cuisine'), free: false, tint: AppColors.warning),
        _TableTile(label: 'T5', status: tr('Libre'), free: true),
        _TableTile(label: 'T6', status: tr('Occupée'), free: false, tint: tint),
      ],
    );
  }
}

class _ControlVisual extends StatelessWidget {
  const _ControlVisual({required this.tint});
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final h in [0.45, 0.7, 0.55, 0.9, 0.62, 0.78, 0.5]) ...[
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: h,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: tint.withValues(alpha: 0.55 + h * 0.35),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ),
                if (h != 0.5) const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _MetricChip(label: tr('Ventes'), value: '128k'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricChip(label: tr('Tickets'), value: '24'),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({
    required this.label,
    required this.value,
    required this.tint,
  });

  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: AppTypography.text(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: AppTypography.text(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.text(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
          Text(
            value,
            style: AppTypography.text(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketLine extends StatelessWidget {
  const _TicketLine({required this.left, required this.right});

  final String left;
  final String right;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tr(left),
              style: AppTypography.text(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            right,
            style: AppTypography.text(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PayPill extends StatelessWidget {
  const _PayPill({
    required this.label,
    required this.tint,
    this.active = false,
  });

  final String label;
  final Color tint;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? tint : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: active ? tint : AppColors.border),
      ),
      child: Text(
        label,
        style: AppTypography.text(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: active ? Colors.white : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _TableTile extends StatelessWidget {
  const _TableTile({
    required this.label,
    required this.status,
    required this.free,
    this.tint,
  });

  final String label;
  final String status;
  final bool free;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final color = free ? AppColors.success : (tint ?? AppColors.brand600);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: AppTypography.text(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: color,
            ),
          ),
          Text(
            status,
            style: AppTypography.text(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
