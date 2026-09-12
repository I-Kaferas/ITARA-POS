import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/terminal_config_repository.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../sync/sync_engine.dart';
import '../../../sync/sync_models.dart';
import '../../pos/presentation/widgets/pos_ui.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.onNavigate,
    this.onBarcodeTap,
    this.onConfigurationTap,
  });

  final ValueChanged<int> onNavigate;
  final VoidCallback? onBarcodeTap;
  final VoidCallback? onConfigurationTap;

  @override
  Widget build(BuildContext context) {
    final config = TerminalConfigRepository.instance.config;
    final cashier = config.cashierName.trim().isEmpty ? 'Caissier' : config.cashierName.trim();
    final terminal = config.deviceName.trim().isEmpty ? 'Terminal POS' : config.deviceName.trim();
    final wide = PosUi.isWide(context) || MediaQuery.sizeOf(context).width >= PosUi.tabletBreakpoint;

    return ListenableBuilder(
      listenable: SyncEngine.instance,
      builder: (context, _) {
        final sync = SyncEngine.instance.snapshot;
        return ColoredBox(
          color: AppColors.canvas,
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: PosUi.contentMaxWidth(context)),
                child: ListView(
                  padding: PosUi.pagePadding(context),
                  children: [
                    _Welcome(
                      greeting: _greeting(),
                      cashier: cashier,
                      terminal: terminal,
                      role: config.posRole.label,
                      sync: sync,
                    ),
                    const SizedBox(height: 18),
                    _OpenRegister(wide: wide, onTap: () => onNavigate(1)),
                    const SizedBox(height: 22),
                    Text('ACCÈS RAPIDE', style: PosUi.sectionLabel()),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= PosUi.phoneBreakpoint ? 3 : 2;
                        return GridView.count(
                          crossAxisCount: columns,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: wide ? 2.2 : 1.4,
                          children: [
                            _Shortcut(
                              icon: Icons.receipt_long_outlined,
                              title: 'Commandes',
                              subtitle: 'Ventes & attente',
                              onTap: () => onNavigate(2),
                            ),
                            _Shortcut(
                              icon: Icons.schedule_outlined,
                              title: 'Shifts',
                              subtitle: 'Ouvrir ou fermer',
                              onTap: () => onNavigate(3),
                            ),
                            _Shortcut(
                              icon: Icons.sync,
                              title: 'Synchroniser',
                              subtitle: sync.pending == 0 ? 'À jour' : '${sync.pending} en attente',
                              onTap: () => context.go(AppRoutes.sync),
                              accent: sync.pending > 0 || sync.failed > 0,
                            ),
                            _Shortcut(
                              icon: Icons.qr_code_scanner,
                              title: 'Codes-barres',
                              subtitle: 'Scanner et imprimer',
                              onTap: onBarcodeTap ?? () => context.go(AppRoutes.barcode),
                            ),
                            _Shortcut(
                              icon: Icons.point_of_sale_outlined,
                              title: 'Caisse',
                              subtitle: 'Vente rapide',
                              onTap: () => onNavigate(1),
                            ),
                            _Shortcut(
                              icon: Icons.settings_outlined,
                              title: 'Réglages',
                              subtitle: 'Terminal et connexion',
                              onTap: onConfigurationTap ?? () => onNavigate(4),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'POS · v${AppConfig.appVersion}',
                      style: PosUi.caption(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bonjour';
    if (hour < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({
    required this.greeting,
    required this.cashier,
    required this.terminal,
    required this.role,
    required this.sync,
  });

  final String greeting;
  final String cashier;
  final String terminal;
  final String role;
  final SyncSnapshot sync;

  @override
  Widget build(BuildContext context) {
    final online = sync.connectivity == ConnectivityState.online ||
        sync.connectivity == ConnectivityState.localAvailable ||
        sync.connectivity == ConnectivityState.cloudAvailable;
    final status = switch (sync.connectivity) {
      ConnectivityState.syncing => 'Synchronisation…',
      ConnectivityState.offline => 'Hors ligne',
      ConnectivityState.syncError => 'Erreur de synchro',
      ConnectivityState.localAvailable => 'Réseau local',
      _ => online ? 'En ligne' : 'Hors ligne',
    };
    final statusColor = sync.connectivity == ConnectivityState.syncError
        ? AppColors.danger
        : online
            ? AppColors.success
            : AppColors.warning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(greeting.toUpperCase(), style: PosUi.sectionLabel()),
        const SizedBox(height: 6),
        Text(
          cashier,
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            height: 1.15,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Pill(icon: Icons.storefront_outlined, label: terminal),
            _Pill(icon: Icons.hub_outlined, label: role),
            _Pill(
              icon: online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
              label: status,
              color: statusColor,
            ),
          ],
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? AppColors.brandInk),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _OpenRegister extends StatelessWidget {
  const _OpenRegister({required this.wide, required this.onTap});

  final bool wide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brand900,
      borderRadius: BorderRadius.circular(PosUi.radiusXl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PosUi.radiusXl),
        child: Padding(
          padding: EdgeInsets.all(wide ? 22 : 16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(PosUi.radiusMd),
                ),
                child: const Icon(Icons.point_of_sale, color: AppColors.accent, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ouvrir la caisse',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Encaisser rapidement, client et paiement.',
                      style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.72), fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(PosUi.radiusMd),
                ),
                child: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF1A222A)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(PosUi.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PosUi.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosUi.radiusLg),
            border: Border.all(
              color: accent ? AppColors.accent.withValues(alpha: 0.45) : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent ? AppColors.accentSoft : AppColors.brand50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: accent ? AppColors.accent : AppColors.brandInk),
              ),
              const Spacer(),
              Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PosUi.caption(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
