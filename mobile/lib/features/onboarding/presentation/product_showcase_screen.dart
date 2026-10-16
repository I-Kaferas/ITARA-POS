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
    return OnboardingFrame(
      footer: Row(
        children: [
          TextButton(
            onPressed: () => context.go(finish),
            child: Text(
              tr('Ignorer'),
              style: GoogleFonts.ibmPlexSans(
                fontWeight: FontWeight.w700,
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
          const OnboardingMark(compact: true),
          const SizedBox(height: 16),
          Text(
            tr('Aperçu du logiciel'),
            style: GoogleFonts.ibmPlexSans(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr('Démonstration. Ces chiffres sont fictifs et ne sont pas enregistrés dans les ventes.'),
            style: GoogleFonts.ibmPlexSans(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: MediaQuery.sizeOf(context).width >= 800 ? 3 : 1,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.7,
              children: [
                _DemoCard(
                  title: tr('Tableau de bord'),
                  lines: [
                    'Ventes du jour · 128 000',
                    'Tickets · 24',
                    'Panier moyen · 5 300',
                  ],
                ),
                _DemoCard(
                  title: tr('Caisse'),
                  lines: [
                    'Table 4 · 2 couverts',
                    'Espèces · 18 500',
                    'Reçu prêt',
                  ],
                ),
                _DemoCard(
                  title: tr('Produits'),
                  lines: ['Farine · 4 200', 'Café · 8 000', 'Jus · 3 500'],
                ),
                _DemoCard(
                  title: tr('Stocks'),
                  lines: ['Farine · 20', 'Café · 14', 'Seuil bas · 2'],
                ),
                _DemoCard(
                  title: tr('Rapport'),
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
  const _DemoCard({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(title),
              style: GoogleFonts.ibmPlexSans(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr('Illustration'),
              style: GoogleFonts.ibmPlexSans(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
            const Spacer(),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  tr(line),
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
