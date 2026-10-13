import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import 'onboarding_frame.dart';

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
            label: 'Découvrir le logiciel',
            onPressed: () =>
                context.go(_withReplay(context, AppRoutes.onboarding)),
          );
          final start = OnboardingButton(
            label: 'Commencer',
            primary: true,
            onPressed: () =>
                context.go(_withReplay(context, AppRoutes.onboardingFinish)),
          );
          if (stacked) {
            return Column(
              children: [
                SizedBox(width: double.infinity, child: discover),
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: start),
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
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const OnboardingMark(),
                  const SizedBox(height: 28),
                  Text(
                    'Gérez. Vendez. Développez.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 40,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Text(
                      'Le point de vente, le stock, le restaurant et l’hôtel dans une même caisse, en ligne ou hors ligne.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 16,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _CommerceArt(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CommerceArt extends StatelessWidget {
  const _CommerceArt();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460, maxHeight: 180),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: const Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(
                child: _ArtStat(
                  icon: Icons.inventory_2_outlined,
                  label: 'Stocks',
                  value: 'Catalogue',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _ArtStat(
                  icon: Icons.point_of_sale_outlined,
                  label: 'Caisse',
                  value: 'Vente',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _ArtStat(
                  icon: Icons.insights_outlined,
                  label: 'Pilotage',
                  value: 'Rapports',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtStat extends StatelessWidget {
  const _ArtStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: AppColors.brand600, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.ibmPlexSans(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 12,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
