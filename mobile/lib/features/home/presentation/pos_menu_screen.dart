import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/terminal_config_repository.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/data/pin_auth_service.dart';
import '../../pos/presentation/widgets/pos_ui.dart';
import '../../sync/presentation/sync_status_bar.dart';

/// Hub « Menu » smartphone §18 — réglages et modules secondaires.
class PosMenuScreen extends StatelessWidget {
  const PosMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final config = TerminalConfigRepository.instance.config;
    final items = <_MenuEntry>[
      _MenuEntry(
        icon: Icons.dashboard_outlined,
        label: 'Accueil',
        subtitle: 'Vue d’ensemble',
        route: AppRoutes.dashboard,
      ),
      _MenuEntry(
        icon: Icons.undo_outlined,
        label: 'Retours',
        subtitle: 'Remboursements',
        route: AppRoutes.returns,
      ),
      _MenuEntry(
        icon: Icons.soup_kitchen_outlined,
        label: 'Cuisine',
        subtitle: 'Kitchen Display',
        route: AppRoutes.kitchen,
      ),
      _MenuEntry(
        icon: Icons.point_of_sale_outlined,
        label: 'Caisse',
        subtitle: 'Open / Close / Cash In-Out',
        route: AppRoutes.cashRegister,
      ),
      _MenuEntry(
        icon: Icons.schedule_outlined,
        label: 'Shifts',
        subtitle: 'Caissier & clôture',
        route: AppRoutes.shifts,
      ),
      _MenuEntry(
        icon: Icons.qr_code_scanner_outlined,
        label: 'Codes-barres',
        subtitle: 'Scanner / imprimer',
        route: AppRoutes.barcode,
      ),
      _MenuEntry(
        icon: Icons.sync_outlined,
        label: 'Synchronisation',
        subtitle: 'File offline',
        route: AppRoutes.sync,
      ),
      _MenuEntry(
        icon: Icons.settings_outlined,
        label: 'Réglages',
        subtitle: 'Terminal & Master',
        route: AppRoutes.configuration,
      ),
    ];

    return ColoredBox(
      color: AppColors.canvas,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.deviceName.isEmpty ? 'ITARA POS' : config.deviceName,
                        style: GoogleFonts.ibmPlexSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (config.cashierName.isNotEmpty) config.cashierName,
                          config.posRole.label,
                        ].join(' · '),
                        style: PosUi.caption(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SyncStatusBar(),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.go(item.route),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Icon(item.icon, color: AppColors.brand700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.label,
                                style: GoogleFonts.ibmPlexSans(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                item.subtitle,
                                style: PosUi.caption(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Se déconnecter ?'),
                  content: const Text(
                    'Le caissier sera déconnecté. Le terminal reste configuré.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Annuler'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Déconnexion'),
                    ),
                  ],
                ),
              );
              if (ok == true) await PinAuthService.signOut();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }
}

class _MenuEntry {
  const _MenuEntry({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final String route;
}
