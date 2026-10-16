import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/terminal_config_repository.dart';
import '../../settings/domain/cashier_preferences.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/data/pin_auth_service.dart';
import '../../auth/presentation/logout_profile_dialog.dart';
import '../../pos/presentation/widgets/pos_ui.dart';
import '../../sync/presentation/sync_status_bar.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

/// Hub « Menu » smartphone §18 — réglages et modules secondaires.
class PosMenuScreen extends StatelessWidget {
  const PosMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CashierPreferences.instance,
      builder: (context, _) {
        final config = TerminalConfigRepository.instance.config;
        final items = <_MenuEntry>[
          _MenuEntry(
            icon: Icons.dashboard_outlined,
            label: tr('Accueil'),
            subtitle: tr('Vue d’ensemble'),
            route: AppRoutes.dashboard,
          ),
          _MenuEntry(
            icon: Icons.undo_outlined,
            label: tr('Retours'),
            subtitle: tr('Remboursements'),
            route: AppRoutes.returns,
          ),
          if (!CashierPreferences.instance.standardPos)
            _MenuEntry(
              icon: Icons.soup_kitchen_outlined,
              label: tr('Cuisine'),
              subtitle: tr('Kitchen Display'),
              route: AppRoutes.kitchen,
            ),
          _MenuEntry(
            icon: Icons.point_of_sale_outlined,
            label: tr('Caisse'),
            subtitle: tr('Open / Close / Cash In-Out'),
            route: AppRoutes.cashRegister,
          ),
          _MenuEntry(
            icon: Icons.schedule_outlined,
            label: tr('Shifts'),
            subtitle: tr('Caissier & clôture'),
            route: AppRoutes.shifts,
          ),
          _MenuEntry(
            icon: Icons.qr_code_scanner_outlined,
            label: tr('Codes-barres'),
            subtitle: tr('Scanner / imprimer'),
            route: AppRoutes.barcode,
          ),
          _MenuEntry(
            icon: Icons.sync_outlined,
            label: tr('Synchronisation'),
            subtitle: tr('File offline'),
            route: AppRoutes.sync,
          ),
          if (config.isAdmin)
            _MenuEntry(
              icon: Icons.tune_outlined,
              label: tr('Réglages'),
              subtitle: tr('Apparence, caisse, imprimantes'),
              route: AppRoutes.cashierSettings,
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
                            tr(config.deviceName.isEmpty
                                ? 'ITARA POS'
                                : config.deviceName),
                            style: GoogleFonts.ibmPlexSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tr([
                              if (config.cashierName.isNotEmpty)
                                config.cashierName,
                              config.posRole.label,
                            ].join(' · ')),
                            style: PosUi.caption(
                              color: AppColors.textSecondary,
                            ),
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
                            Icon(item.icon, color: AppColors.brandInk),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr(item.label),
                                    style: GoogleFonts.ibmPlexSans(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    tr(item.subtitle),
                                    style: PosUi.caption(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: AppColors.textMuted,
                            ),
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
                  final ok = await showLogoutProfileDialog(context);
                  if (ok) await PinAuthService.signOut();
                },
                icon: const Icon(Icons.logout),
                label: Text(tr('Se déconnecter')),
              ),
            ],
          ),
        );
      },
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
