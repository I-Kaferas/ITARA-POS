import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import 'onboarding_frame.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  String _withReplay(BuildContext context, String path) {
    final replay =
        GoRouterState.of(context).uri.queryParameters['replay'] == '1';
    return replay ? '$path?replay=1' : path;
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingFrame(
      footer: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 520;
          final discover = OnboardingButton(
            label: tr('Découvrir le logiciel'),
            onPressed: () =>
                context.go(_withReplay(context, AppRoutes.onboarding)),
          );
          final start = OnboardingButton(
            label: tr('Commencer'),
            primary: true,
            onPressed: () =>
                context.go(_withReplay(context, AppRoutes.onboardingFinish)),
          );
          if (stacked) {
            return Column(
              children: [
                SizedBox(width: double.infinity, child: start),
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: discover),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: discover),
              const SizedBox(width: 12),
              Expanded(child: start),
            ],
          );
        },
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 820;
          final copy = _WelcomeCopy();
          final preview = const _PosTerminalPreview();
          if (!wide) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    copy,
                    const SizedBox(height: 28),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: preview,
                    ),
                  ],
                ),
              ),
            );
          }
          return Row(
            children: [
              Expanded(flex: 5, child: copy),
              const SizedBox(width: 36),
              Expanded(flex: 6, child: preview),
            ],
          );
        },
      ),
    );
  }
}

class _WelcomeCopy extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const OnboardingMark(),
        const SizedBox(height: 28),
        Text(
          tr('Gérez. Vendez. Développez.'),
          style: GoogleFonts.ibmPlexSans(
            fontSize: 42,
            height: 1.08,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.0,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            tr('Le point de vente, le stock, le restaurant et l’hôtel dans une même caisse, en ligne ou hors ligne.'),
            style: GoogleFonts.ibmPlexSans(
              fontSize: 16,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _TrustChip(icon: Icons.wifi_off_rounded, label: tr('Hors ligne')),
            _TrustChip(icon: Icons.sync_rounded, label: tr('Synchro')),
            _TrustChip(icon: Icons.print_outlined, label: tr('Reçus')),
            _TrustChip(
              icon: Icons.table_restaurant_outlined,
              label: tr('Tables'),
            ),
          ],
        ),
      ],
    );
  }
}

class _TrustChip extends StatelessWidget {
  const _TrustChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.brand600),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PosTerminalPreview extends StatelessWidget {
  const _PosTerminalPreview();

  @override
  Widget build(BuildContext context) {
    return OnboardingPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.brand600,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Text(
                  tr('Caisse · Bureau 1'),
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tr('En ligne'),
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        Expanded(
                          child: GridView.count(
                            crossAxisCount: 2,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            physics: const NeverScrollableScrollPhysics(),
                            children: const [
                              _SkuTile(name: 'Café', price: '8 000'),
                              _SkuTile(name: 'Jus', price: '3 500'),
                              _SkuTile(name: 'Pain', price: '1 200'),
                              _SkuTile(name: 'Thé', price: '2 500'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              tr('Panier'),
                              style: GoogleFonts.ibmPlexSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const _CartLine(label: 'Café × 2', value: '16 000'),
                            const _CartLine(label: 'Jus × 1', value: '3 500'),
                            const Spacer(),
                            Divider(color: AppColors.border, height: 20),
                            Row(
                              children: [
                                Text(
                                  tr('Total'),
                                  style: GoogleFonts.ibmPlexSans(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '19 500',
                                  style: GoogleFonts.ibmPlexSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.brandInk,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.brand700,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                tr('Encaisser'),
                                style: GoogleFonts.ibmPlexSans(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkuTile extends StatelessWidget {
  const _SkuTile({required this.name, required this.price});

  final String name;
  final String price;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.brand600.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 15,
                color: AppColors.brand600,
              ),
            ),
            const Spacer(),
            Text(
              tr(name),
              style: GoogleFonts.ibmPlexSans(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              price,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartLine extends StatelessWidget {
  const _CartLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tr(label),
              style: GoogleFonts.ibmPlexSans(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
