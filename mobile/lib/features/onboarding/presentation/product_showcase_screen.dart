import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import 'onboarding_frame.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

/// Visual tour only. Figures are invented and are never written to sales.
class ProductShowcaseScreen extends StatelessWidget {
  const ProductShowcaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final replay =
        GoRouterState.of(context).uri.queryParameters['replay'] == '1';
    final finish = replay
        ? '${AppRoutes.onboardingFinish}?replay=1'
        : AppRoutes.onboardingFinish;
    final wide = MediaQuery.sizeOf(context).width >= 800;
    return OnboardingFrame(
      footer: Row(
        children: [
          TextButton(
            onPressed: () => context.go(finish),
            child: Text(
              tr('Ignorer'),
              style: GoogleFonts.ibmPlexSans(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 180,
            child: OnboardingButton(
              label: tr('Continuer'),
              primary: true,
              onPressed: () => context.go(finish),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const OnboardingMark(compact: true),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  tr('Démo'),
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.violet600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            tr('Aperçu du logiciel'),
            style: GoogleFonts.ibmPlexSans(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr('Démonstration. Ces chiffres sont fictifs et ne sont pas enregistrés dans les ventes.'),
            style: GoogleFonts.ibmPlexSans(
              fontSize: 14,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: GridView.count(
              crossAxisCount: wide ? 3 : 1,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: wide ? 1.55 : 2.1,
              children: [
                _DemoCard(
                  title: tr('Tableau de bord'),
                  icon: Icons.dashboard_outlined,
                  tint: AppColors.info,
                  lines: [
                    'Ventes du jour · 128 000',
                    'Tickets · 24',
                    'Panier moyen · 5 300',
                  ],
                ),
                _DemoCard(
                  title: tr('Caisse'),
                  icon: Icons.point_of_sale_outlined,
                  tint: AppColors.success,
                  lines: [
                    'Table 4 · 2 couverts',
                    'Espèces · 18 500',
                    'Reçu prêt',
                  ],
                ),
                _DemoCard(
                  title: tr('Produits'),
                  icon: Icons.inventory_2_outlined,
                  tint: AppColors.brand600,
                  lines: ['Farine · 4 200', 'Café · 8 000', 'Jus · 3 500'],
                ),
                _DemoCard(
                  title: tr('Stocks'),
                  icon: Icons.warehouse_outlined,
                  tint: AppColors.warning,
                  lines: ['Farine · 20', 'Café · 14', 'Seuil bas · 2'],
                ),
                _DemoCard(
                  title: tr('Rapport'),
                  icon: Icons.insights_outlined,
                  tint: AppColors.violet600,
                  lines: [
                    'Encaissé · 96 000',
                    'Crédit · 32 000',
                    'Dépenses · 12 000',
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoCard extends StatelessWidget {
  const _DemoCard({
    required this.title,
    required this.lines,
    required this.icon,
    required this.tint,
  });

  final String title;
  final List<String> lines;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return OnboardingPanel(
      tint: tint,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: tint),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr(title),
                  style: GoogleFonts.ibmPlexSans(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr(line),
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 13,
                        height: 1.3,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
