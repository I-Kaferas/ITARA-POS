import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../config/terminal_config.dart';
import '../config/terminal_config_repository.dart';
import '../theme/app_colors.dart';
import '../theme/theme_controller.dart';
import '../../features/auth/data/pin_auth_service.dart';
import '../../features/pos/presentation/widgets/pos_ui.dart';
import '../widgets/app_calculator.dart';
import '../../features/sync/presentation/sync_status_bar.dart';
import '../../sync/sync_engine.dart';
import '../../sync/sync_models.dart';
import 'app_routes.dart';

Future<void> _syncStock(BuildContext context) async {
  await SyncEngine.instance.refreshCounts();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => const _SyncStockDialog(),
  );
}

Future<void> _confirmLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Se déconnecter ?'),
      content: const Text('Le caissier sera déconnecté. Le terminal reste configuré.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Déconnexion')),
      ],
    ),
  );
  if (confirmed == true) {
    await PinAuthService.signOut();
  }
}

class _SyncStockDialog extends StatefulWidget {
  const _SyncStockDialog();

  @override
  State<_SyncStockDialog> createState() => _SyncStockDialogState();
}

class _SyncStockDialogState extends State<_SyncStockDialog> {
  bool _running = false;
  SyncReport? _report;

  Future<void> _run(String action) async {
    if (_running) return;
    setState(() {
      _running = true;
      _report = null;
    });
    final report = action == 'send'
        ? await SyncEngine.instance.sendStock()
        : await SyncEngine.instance.downloadStock();
    if (!mounted) return;
    setState(() {
      _running = false;
      _report = report;
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = SyncEngine.instance.snapshot;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: ListenableBuilder(
          listenable: SyncEngine.instance,
          builder: (context, _) {
            final live = SyncEngine.instance.snapshot;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 8, 14),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.brand600, width: 3)),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.brand50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.sync, color: AppColors.brand700, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Synchroniser le stock', style: GoogleFonts.ibmPlexSans(fontSize: 16, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(
                              'Ventes, catalogue, clients et paiements',
                              style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _running ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Column(
                    children: [
                      _statusRow(live),
                      const SizedBox(height: 14),
                      if (_running) _busy() else if (_report != null) _resultCard(_report!) else _actions(snapshot),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statusRow(SyncSnapshot snapshot) {
    final waiting = snapshot.pending + snapshot.failed;
    final last = snapshot.lastSyncAt == null ? 'Jamais' : DateFormat('dd/MM · HH:mm').format(snapshot.lastSyncAt!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(PosUi.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _stat('Connexion', snapshot.label),
          _stat('En attente', '$waiting'),
          _stat('Dernière', last),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: GoogleFonts.ibmPlexSans(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, textAlign: TextAlign.center, style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _actions(SyncSnapshot snapshot) {
    return Column(
      children: [
        _ActionTile(
          icon: Icons.upload_outlined,
          title: 'Envoyer le stock',
          caption: snapshot.pending + snapshot.failed == 0
              ? 'Aucune vente en attente sur ce terminal.'
              : '${snapshot.pending + snapshot.failed} vente(s) à envoyer vers le serveur.',
          onTap: () => _run('send'),
        ),
        const SizedBox(height: 8),
        _ActionTile(
          icon: Icons.download_outlined,
          title: 'Télécharger le stock',
          caption: 'Catalogue, clients, paiements, unités, utilisateurs, rôles et permissions.',
          onTap: () => _run('download'),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ),
      ],
    );
  }

  Widget _busy() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
          const SizedBox(height: 10),
          Text('Synchronisation en cours…', style: GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _resultCard(SyncReport report) {
    final color = report.ok ? AppColors.success : AppColors.danger;
    final bg = report.ok ? AppColors.successBg : AppColors.dangerBg;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(report.ok ? Icons.check_circle_outline : Icons.error_outline, color: color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      report.message.isNotEmpty ? report.message : (report.ok ? 'Synchronisation terminée' : 'Échec'),
                      style: GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w700, color: color),
                    ),
                  ),
                ],
              ),
              if (report.ok) ...[
                const SizedBox(height: 12),
                ...report.lines.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(line.label, style: GoogleFonts.ibmPlexSans(fontSize: 13, color: AppColors.textPrimary)),
                        ),
                        Text(
                          '${line.count}',
                          style: GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            TextButton(onPressed: () => setState(() => _report = null), child: const Text('Autre action')),
            const Spacer(),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
          ],
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.caption,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: AppColors.brand50, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: AppColors.brand700),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(caption, style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _navItems = [
    _NavItem(
      route: AppRoutes.dashboard,
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Accueil',
      hint: 'Vue d’ensemble POS',
    ),
    _NavItem(
      route: AppRoutes.pos,
      icon: Icons.point_of_sale_outlined,
      selectedIcon: Icons.point_of_sale,
      label: 'Caisse',
      hint: 'Terminal de vente',
    ),
    _NavItem(
      route: AppRoutes.orders,
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      label: 'Commandes',
      hint: 'Ventes et attente',
    ),
    _NavItem(
      route: AppRoutes.returns,
      icon: Icons.undo_outlined,
      selectedIcon: Icons.undo,
      label: 'Retours',
      hint: 'Retours et remboursements',
    ),
    _NavItem(
      route: AppRoutes.shifts,
      icon: Icons.schedule_outlined,
      selectedIcon: Icons.schedule,
      label: 'Shift',
      hint: 'Ouverture et clôture',
    ),
    _NavItem(
      route: AppRoutes.reservations,
      icon: Icons.event_seat_outlined,
      selectedIcon: Icons.event_seat,
      label: 'Réservations',
      hint: 'Réservations salle',
    ),
    _NavItem(
      route: AppRoutes.configuration,
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: 'Réglages',
      hint: 'Terminal et connexion',
    ),
  ];

  static const _barcodeItem = _NavItem(
    route: AppRoutes.barcode,
    icon: Icons.qr_code_scanner_outlined,
    selectedIcon: Icons.qr_code_scanner,
    label: 'Codes-barres',
    hint: 'Scanner, générer et imprimer',
  );

  static const _syncItem = _NavItem(
    route: AppRoutes.sync,
    icon: Icons.sync_outlined,
    selectedIcon: Icons.sync,
    label: 'Synchronisation',
    hint: 'File d’attente et envois',
  );

  void _onTap(int index) {
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  _NavItem _currentPage(String location) {
    if (location == AppRoutes.barcode) return _barcodeItem;
    if (location == AppRoutes.sync) return _syncItem;
    return _navItems[navigationShell.currentIndex];
  }

  @override
  Widget build(BuildContext context) {
    final isWide = PosUi.isWide(context);
    final config = TerminalConfigRepository.instance.config;
    final location = GoRouterState.of(context).uri.path;
    final page = _currentPage(location);
    final onToolPage = location == AppRoutes.barcode || location == AppRoutes.sync;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(
              selectedIndex: onToolPage ? -1 : navigationShell.currentIndex,
              activeRoute: location,
              config: config,
              onSelected: _onTap,
              onBarcodeTap: () => context.go(AppRoutes.barcode),
              onSyncTap: () => context.go(AppRoutes.sync),
            ),
            Expanded(
              child: Column(
                children: [
                  _TopBar(
                    title: page.label,
                    subtitle: page.hint,
                    config: config,
                  ),
                  Expanded(child: navigationShell),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final storeLabel = config.deviceName.trim().isEmpty ? 'Magasin' : config.deviceName.trim();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(page.label, style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700, fontSize: 16)),
            Text(
              storeLabel,
              style: GoogleFonts.ibmPlexSans(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          const SyncStatusBar(),
          const SizedBox(width: 4),
          const ThemeModeButton(),
          const CalculatorButton(),
          PopupMenuButton<String>(
            tooltip: 'Plus',
            onSelected: (value) {
              switch (value) {
                case 'barcode':
                  context.go(AppRoutes.barcode);
                case 'sync':
                  _syncStock(context);
                case 'shifts':
                  context.go(AppRoutes.shifts);
                case 'logout':
                  _confirmLogout(context);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'shifts', child: Text('Shifts · ${config.posRole.label}')),
              const PopupMenuItem(value: 'barcode', child: Text('Codes-barres')),
              const PopupMenuItem(value: 'sync', child: Text('Synchroniser le stock')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: Text('Se déconnecter')),
            ],
          ),
        ],
      ),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        destinations: _navItems
            .map((item) => NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: item.label,
                ))
            .toList(),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selectedIndex,
    required this.activeRoute,
    required this.config,
    required this.onSelected,
    required this.onBarcodeTap,
    required this.onSyncTap,
  });

  final int selectedIndex;
  final String activeRoute;
  final TerminalConfig config;
  final ValueChanged<int> onSelected;
  final VoidCallback onBarcodeTap;
  final VoidCallback onSyncTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: PosUi.isDesktop(context) ? 248 : 220,
      decoration: const BoxDecoration(
        color: AppColors.sidebar,
        border: Border(right: BorderSide(color: AppColors.sidebarBorder)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(12, 14, 12, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.sidebarPanel,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A222A),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.55)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'POS',
                    style: GoogleFonts.ibmPlexSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.deviceName.isNotEmpty ? config.deviceName : 'POS Mobile',
                        style: GoogleFonts.ibmPlexSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        config.cashierName.isNotEmpty
                            ? config.cashierName
                            : 'v${AppConfig.appVersion}',
                        style: GoogleFonts.ibmPlexSans(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              children: [
                const _SectionLabel('Vente'),
                _SidebarItem(
                  item: AppShell._navItems[1],
                  selected: selectedIndex == 1,
                  onTap: () => onSelected(1),
                ),
                _SidebarItem(
                  item: AppShell._navItems[5],
                  selected: selectedIndex == 5,
                  onTap: () => onSelected(5),
                ),
                const _SectionLabel('Suivi'),
                _SidebarItem(
                  item: AppShell._navItems[0],
                  selected: selectedIndex == 0,
                  onTap: () => onSelected(0),
                ),
                _SidebarItem(
                  item: AppShell._navItems[2],
                  selected: selectedIndex == 2,
                  onTap: () => onSelected(2),
                ),
                _SidebarItem(
                  item: AppShell._navItems[3],
                  selected: selectedIndex == 3,
                  onTap: () => onSelected(3),
                ),
                _SidebarItem(
                  item: AppShell._navItems[4],
                  selected: selectedIndex == 4,
                  onTap: () => onSelected(4),
                ),
                const _SectionLabel('Système'),
                _SidebarItem(
                  item: AppShell._navItems[6],
                  selected: selectedIndex == 6,
                  onTap: () => onSelected(6),
                ),
                _SidebarItem(
                  item: AppShell._barcodeItem,
                  selected: activeRoute == AppRoutes.barcode,
                  onTap: onBarcodeTap,
                ),
                _SidebarItem(
                  item: AppShell._syncItem,
                  selected: activeRoute == AppRoutes.sync,
                  onTap: onSyncTap,
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.sidebarPanel,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 16, color: Colors.white70),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        config.cashierName.isNotEmpty ? config.cashierName : 'Caissier',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.ibmPlexSans(
                          color: Colors.white.withValues(alpha: 0.86),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ListenableBuilder(
                    listenable: SyncEngine.instance,
                    builder: (context, _) {
                      final syncing = SyncEngine.instance.connectivity == ConnectivityState.syncing;
                      return FilledButton.icon(
                        onPressed: syncing ? null : () => _syncStock(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: const Color(0xFF1A222A),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        icon: syncing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync, size: 16),
                        label: const Text('Synchroniser le stock'),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _confirmLogout(context),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFFCA5A5),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Se déconnecter'),
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

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final PosRole role;

  @override
  Widget build(BuildContext context) {
    final bg = switch (role) {
      PosRole.master => AppColors.brand600,
      PosRole.slave => AppColors.accent,
      PosRole.standalone => AppColors.success,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(role.icon, size: 14, color: bg),
          const SizedBox(width: 4),
          Text(
            role.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: bg,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? AppColors.sidebarActive.withValues(alpha: 0.92) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: AppColors.sidebarHover,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  color: selected ? Colors.white : AppColors.sidebarText,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    style: GoogleFonts.ibmPlexSans(
                      color: selected ? Colors.white : AppColors.sidebarText,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.subtitle, required this.config});

  final String title;
  final String subtitle;
  final TerminalConfig config;

  @override
  Widget build(BuildContext context) {
    final storeLabel = config.deviceName.trim().isEmpty ? 'Magasin' : config.deviceName.trim();
    final cashier = config.cashierName.trim().isEmpty ? 'Caissier' : config.cashierName.trim();

    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Flexible(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: PosUi.caption(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SyncStatusBar(),
                    const SizedBox(width: 8),
                    _ContextChip(
                      icon: Icons.storefront_outlined,
                      label: storeLabel,
                      onTap: () => context.go(AppRoutes.configuration),
                    ),
                    const SizedBox(width: 8),
                    _ContextChip(
                      icon: Icons.person_outline,
                      label: cashier,
                    ),
                    const SizedBox(width: 8),
                    _ContextChip(
                      icon: Icons.schedule_outlined,
                      label: 'Shifts',
                      tone: AppColors.brandInk,
                      onTap: () => context.go(AppRoutes.shifts),
                    ),
                    const SizedBox(width: 8),
                    _RoleChip(role: config.posRole),
                    const SizedBox(width: 8),
                    const ThemeModeButton(),
                    const CalculatorButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextChip extends StatelessWidget {
  const _ContextChip({
    required this.icon,
    required this.label,
    this.tone,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color? tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = tone ?? AppColors.brandInk;
    final child = Container(
      constraints: const BoxConstraints(maxWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: child,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
      child: Row(
      children: [
        Container(
          width: 7,
          height: 2,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.ibmPlexSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: AppColors.accent.withValues(alpha: 0.78),
          ),
        ),
      ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.route,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.hint,
  });

  final String route;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String hint;
}
