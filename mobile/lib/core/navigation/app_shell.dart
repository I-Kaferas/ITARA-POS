import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../i18n/app_locale.dart';
import '../config/terminal_config.dart';
import '../config/terminal_config_repository.dart';
import '../config/terminal_stores.dart';
import '../layout/android_form_factor.dart';
import '../network/network_bloc.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/theme_controller.dart';
import '../widgets/app_buttons.dart';
import '../../features/auth/data/pin_auth_service.dart';
import '../../features/auth/presentation/logout_profile_dialog.dart';
import '../../features/pos/presentation/widgets/pos_ui.dart';
import '../../features/settings/domain/cashier_preferences.dart';
import '../widgets/app_calculator.dart';
import '../../features/sync/presentation/sync_status_bar.dart';
import '../../sync/local_master_server.dart';
import '../../sync/sync_engine.dart';
import '../../sync/sync_models.dart';
import 'app_routes.dart';
import 'config_top_bar.dart';
import 'store_switcher_dialog.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

void _onOverflowSelected(BuildContext context, String value) {
  switch (value) {
    case 'barcode':
      context.go(AppRoutes.barcode);
    case 'sync':
      _syncStock(context);
    case 'menu':
      context.go(AppRoutes.menu);
    case 'settings':
      context.go(AppRoutes.cashierSettings);
    case 'store':
      openStoreSwitcher(context);
    case 'logout':
      _confirmLogout(context);
  }
}

List<PopupMenuEntry<String>> _overflowItems() {
  final admin = TerminalConfigRepository.instance.config.isAdmin;
  return [
    if (admin) PopupMenuItem(value: 'settings', child: Text(tr('Réglages'))),
    PopupMenuItem(value: 'store', child: Text(tr('Changer de magasin'))),
    PopupMenuItem(value: 'menu', child: Text(tr('Plus'))),
    PopupMenuItem(value: 'barcode', child: Text(tr('Codes-barres'))),
    PopupMenuItem(value: 'sync', child: Text(tr('Synchroniser le stock'))),
    PopupMenuDivider(),
    PopupMenuItem(value: 'logout', child: Text(tr('Se déconnecter'))),
  ];
}

Future<void> _syncStock(BuildContext context) async {
  await SyncEngine.instance.refreshCounts();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierColor: AppColors.brand900.withValues(alpha: 0.55),
    builder: (context) => const _SyncStockDialog(),
  );
}

Future<void> _confirmLogout(BuildContext context) async {
  final confirmed = await showLogoutProfileDialog(context);
  if (confirmed) {
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
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 400, maxHeight: size.height * 0.86),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.borderXl,
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.elevationMd,
          ),
          child: ClipRRect(
            borderRadius: AppRadius.borderXl,
            child: ListenableBuilder(
              listenable: SyncEngine.instance,
              builder: (context, _) {
                final live = SyncEngine.instance.snapshot;
                final waiting = live.pending + live.failed;
                final last = live.lastSyncAt == null
                    ? 'Jamais'
                    : DateFormat('dd/MM · HH:mm').format(live.lastSyncAt!);
                final online = live.connectivity == ConnectivityState.online ||
                    live.connectivity == ConnectivityState.cloudAvailable ||
                    live.connectivity == ConnectivityState.localAvailable;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 18),
                      color: AppColors.brand600,
                      child: Column(
                        children: [
                          Container(
                            width: 92,
                            height: 92,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accent,
                            ),
                            child: const Icon(Icons.sync_rounded, size: 40, color: AppColors.brand900),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            AppCopy.get('syncTitle'),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.ibmPlexSans(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: online ? AppColors.success : AppColors.warning,
                              borderRadius: AppRadius.borderPill,
                            ),
                            child: Text(
                              tr(live.label),
                              style: GoogleFonts.ibmPlexSans(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.fieldFill,
                                borderRadius: AppRadius.borderLg,
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                children: [
                                  _SyncInfoRow(icon: Icons.cloud_queue, label: tr('Connexion'), value: live.label),
                                  const SizedBox(height: 10),
                                  _SyncInfoRow(icon: Icons.hourglass_bottom, label: tr('En attente'), value: '$waiting'),
                                  const SizedBox(height: 10),
                                  _SyncInfoRow(icon: Icons.schedule, label: tr('Dernière'), value: last),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (_running)
                              _busy()
                            else if (_report != null)
                              _resultCard(_report!)
                            else
                              _actions(waiting),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _actions(int waiting) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: AppButton.secondary(
            label: waiting == 0 ? AppCopy.get('syncSend') : '${AppCopy.get('syncSend')} ($waiting)',
            icon: Icons.upload_outlined,
            expanded: true,
            onPressed: () => _run('send'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: AppButton.primary(
            label: AppCopy.get('syncDownload'),
            icon: Icons.download_outlined,
            expanded: true,
            onPressed: () => _run('download'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: AppButton.secondary(
            label: AppCopy.get('cancel'),
            expanded: true,
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ],
    );
  }

  Widget _busy() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.brandInk),
          ),
          const SizedBox(height: 12),
          Text(
            AppCopy.get('syncBusy'),
            style: GoogleFonts.ibmPlexSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
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
            borderRadius: AppRadius.borderLg,
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(report.ok ? Icons.check_circle : Icons.error_outline, color: color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr(report.message.isNotEmpty ? report.message : (report.ok ? AppCopy.get('syncDone') : AppCopy.get('syncFailed'))),
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
                        Icon(Icons.check_circle, size: 16, color: AppColors.success),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(tr(line.label), style: GoogleFonts.ibmPlexSans(fontSize: 14, color: AppColors.textPrimary)),
                        ),
                        Text(
                          '${line.count}',
                          style: GoogleFonts.ibmPlexSans(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: AppButton.secondary(
                label: tr('Autre action'),
                expanded: true,
                onPressed: () => setState(() => _report = null),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton.primary(
                label: tr('Fermer'),
                expanded: true,
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SyncInfoRow extends StatelessWidget {
  const _SyncInfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr(label), style: GoogleFonts.ibmPlexSans(fontSize: 11, color: AppColors.textMuted)),
              Text(
                tr(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        TerminalConfigRepository.instance,
        CashierPreferences.instance,
      ]),
      builder: (context, _) => _scaffold(context),
    );
  }

  /// Menus de navigation, filtrés par « Visibilité du menu » (Réglages).
  static final _phoneTabs = [
    _NavItem(
      route: AppRoutes.dashboard,
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard,
      label: tr('Overview'),
      hint: tr('Today at a glance'),
      branchIndex: 0,
      menuKey: 'overview',
    ),
    _NavItem(
      route: AppRoutes.pos,
      icon: Icons.point_of_sale_outlined,
      selectedIcon: Icons.point_of_sale,
      label: tr('Point of Sale'),
      hint: tr('Register'),
      branchIndex: 1,
      menuKey: 'pos',
    ),
    _NavItem(
      route: AppRoutes.orders,
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      label: tr('Orders'),
      hint: tr('Sales and orders'),
      branchIndex: 2,
      menuKey: 'orders',
    ),
    _NavItem(
      route: AppRoutes.kitchen,
      icon: Icons.soup_kitchen_outlined,
      selectedIcon: Icons.soup_kitchen,
      label: tr('Kitchen'),
      hint: tr('Kitchen display'),
      menuKey: 'kitchen',
    ),
    _NavItem(
      route: AppRoutes.reservations,
      icon: Icons.table_restaurant_outlined,
      selectedIcon: Icons.table_restaurant,
      label: tr('Tables'),
      hint: tr('Salle et réservations'),
      menuKey: 'tables',
    ),
    _NavItem(
      route: AppRoutes.shifts,
      icon: Icons.schedule_outlined,
      selectedIcon: Icons.schedule,
      label: tr('Shifts'),
      hint: tr('Open and close'),
      branchIndex: 3,
      menuKey: 'shifts',
    ),
  ];

  static List<_NavItem> _visibleTabs() {
    final prefs = CashierPreferences.instance;
    final tabs = _phoneTabs.where((t) => prefs.menuVisible(t.menuKey!)).toList();
    if (tabs.length >= CashierPreferences.minVisibleMenus) return tabs;
    return _phoneTabs
        .where((t) => tabs.contains(t) || t.menuKey == 'overview' || t.menuKey == 'pos')
        .toList();
  }

  static bool _tabMatches(_NavItem item, String location) {
    switch (item.route) {
      case AppRoutes.dashboard:
        return location == AppRoutes.dashboard ||
            (location.startsWith('${AppRoutes.dashboard}/') && !location.startsWith(AppRoutes.kitchen));
      case AppRoutes.shifts:
        return location == AppRoutes.shifts || location.startsWith('${AppRoutes.shifts}/');
      default:
        return location.startsWith(item.route);
    }
  }

  static final _barcodeItem = _NavItem(
    route: AppRoutes.barcode,
    icon: Icons.qr_code_scanner_outlined,
    selectedIcon: Icons.qr_code_scanner,
    label: tr('Codes-barres'),
    hint: tr('Scanner, générer et imprimer'),
    branchIndex: 0,
  );

  static final _syncItem = _NavItem(
    route: AppRoutes.sync,
    icon: Icons.sync_outlined,
    selectedIcon: Icons.sync,
    label: tr('Synchronisation'),
    hint: tr('File d’attente et envois'),
    branchIndex: 0,
  );

  static final _settingsItem = _NavItem(
    route: AppRoutes.configuration,
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    label: tr('Configuration'),
    hint: tr('Terminal et connexion'),
    branchIndex: 0,
  );

  static final _prefsItem = _NavItem(
    route: AppRoutes.cashierSettings,
    icon: Icons.tune_outlined,
    selectedIcon: Icons.tune,
    label: tr('Réglages'),
    hint: tr('Mode configuration'),
    branchIndex: 0,
  );

  static final _returnsItem = _NavItem(
    route: AppRoutes.returns,
    icon: Icons.undo_outlined,
    selectedIcon: Icons.undo,
    label: tr('Retours'),
    hint: tr('Retours et remboursements'),
    branchIndex: 0,
  );

  static final _tablesItem = _NavItem(
    route: AppRoutes.reservations,
    icon: Icons.table_restaurant_outlined,
    selectedIcon: Icons.table_restaurant,
    label: tr('Tables'),
    hint: tr('Salle et réservations'),
  );

  static final _stockItem = _NavItem(
    route: AppRoutes.stock,
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2,
    label: tr('Stock'),
    hint: tr('Stock local'),
  );

  static final _menuItem = _NavItem(
    route: AppRoutes.menu,
    icon: Icons.menu,
    selectedIcon: Icons.menu_open,
    label: tr('Plus'),
    hint: tr('Autres modules'),
  );

  _NavItem _currentPage(String location) {
    if (location == AppRoutes.barcode) return _barcodeItem;
    if (location == AppRoutes.sync) return _syncItem;
    if (location == AppRoutes.cashierSettings ||
        location == AppRoutes.hub ||
        location == AppRoutes.masterConfiguration) {
      return _prefsItem;
    }
    if (location == AppRoutes.configuration) return _settingsItem;
    if (location == AppRoutes.returns) return _returnsItem;
    if (location.startsWith(AppRoutes.reservations)) return _tablesItem;
    if (location.startsWith(AppRoutes.stock)) return _stockItem;
    if (location == AppRoutes.menu) return _menuItem;
    if (location == AppRoutes.cashRegister) {
      return _NavItem(
        route: AppRoutes.cashRegister,
        icon: Icons.point_of_sale_outlined,
        selectedIcon: Icons.point_of_sale,
        label: tr('Caisse'),
        hint: tr('Open, close, cash in and out'),
      );
    }
    for (final item in _phoneTabs) {
      if (_tabMatches(item, location)) return item;
    }
    return _phoneTabs[0];
  }

  Widget _scaffold(BuildContext context) {
    final form = AndroidLayout.of(context);
    final config = TerminalConfigRepository.instance.config;
    final location = GoRouterState.of(context).uri.path;
    final page = _currentPage(location);
    final tabs = _visibleTabs();
    final phoneTab = tabs.indexWhere((t) => _tabMatches(t, location));
    final configuring = AppRoutes.isConfiguration(location);
    void exitConfiguration() => context.go(AppRoutes.pos);

    if (form.isDesk) {
      return Scaffold(
        body: Row(
          children: [
            if (!configuring)
              _Sidebar(
                activeRoute: location,
                config: config,
                tabs: tabs,
                onTab: (item) => context.go(item.route),
              ),
            Expanded(
              child: Column(
                children: [
                  if (configuring)
                    ConfigTopBar(
                      onHome: exitConfiguration,
                      onFeatures: () => context.go(
                        TerminalConfigRepository.instance.isConfigured
                            ? AppRoutes.menu
                            : '${AppRoutes.configuration}?section=0',
                      ),
                      onLogout: () => _confirmLogout(context),
                    )
                  else
                    _TopBar(
                      title: page.label,
                      subtitle: page.hint,
                      config: config,
                    ),
                  Expanded(
                    child: KeyedSubtree(
                      key: ValueKey(config.storeId),
                      child: navigationShell,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: configuring
            ? IconButton(
                tooltip: tr('Retour à la caisse'),
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: exitConfiguration,
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(page.label),
              style: GoogleFonts.ibmPlexSans(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const _StoreSwitcher(style: _StoreSwitcherStyle.subtitle),
          ],
        ),
        actions: [
          const SyncStatusBar(),
          const SizedBox(width: 4),
          const ThemeModeButton(),
          const CalculatorButton(),
          PopupMenuButton<String>(
            tooltip: tr('Plus'),
            onSelected: (value) => _onOverflowSelected(context, value),
            itemBuilder: (context) => _overflowItems(),
          ),
        ],
      ),
      body: KeyedSubtree(
        key: ValueKey(config.storeId),
        child: navigationShell,
      ),
      bottomNavigationBar: configuring
          ? null
          : NavigationBarTheme(
        data: NavigationBarThemeData(
          indicatorColor: AppColors.cashierBlue,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(color: selected ? Colors.white : AppColors.textSecondary);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return GoogleFonts.ibmPlexSans(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.brandInk : AppColors.textSecondary,
            );
          }),
        ),
        child: NavigationBar(
        animationDuration: AppMotion.resolve(context, AppMotion.micro),
        height: AndroidLayout.preferLite(context) ? 64 : 70,
        backgroundColor: AppColors.surface,
        selectedIndex: phoneTab < 0 ? 0 : phoneTab,
        onDestinationSelected: (i) => context.go(tabs[i].route),
        destinations: tabs
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
              ),
            )
            .toList(),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.activeRoute,
    required this.config,
    required this.tabs,
    required this.onTab,
  });

  final String activeRoute;
  final TerminalConfig config;
  final List<_NavItem> tabs;
  final ValueChanged<_NavItem> onTab;

  @override
  Widget build(BuildContext context) {
    final brand = config.deviceName.trim().isEmpty ? 'ITARA' : config.deviceName.trim();
    return Container(
      width: PosUi.isDesktop(context) ? 248 : 220,
      decoration: const BoxDecoration(
        color: AppColors.sidebar,
        border: Border(right: BorderSide(color: AppColors.sidebarBorder)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.storefront_rounded, color: AppColors.brand900, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(brand),
                        style: GoogleFonts.ibmPlexSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        tr('Point of Sale'),
                        style: GoogleFonts.ibmPlexSans(
                          color: AppColors.sidebarText,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: tr('Réglages'),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_horiz, color: AppColors.sidebarText, size: 20),
                  onSelected: (value) => _onOverflowSelected(context, value),
                  itemBuilder: (context) => _overflowItems(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: const _StoreSwitcher(style: _StoreSwitcherStyle.sidebar),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: ListenableBuilder(
              listenable: LocalMasterServer.instance,
              builder: (context, _) {
                return BlocBuilder<NetworkBloc, NetworkState>(
                  builder: (context, net) {
                    final server = LocalMasterServer.instance.listening || net.masterReachable;
                    final online = net.internetReachable;
                    return Column(
                      children: [
                        _ConnectionPill(
                          icon: Icons.dns_outlined,
                          label: server ? 'Server running' : 'Server offline',
                          on: server,
                        ),
                        const SizedBox(height: 6),
                        _ConnectionPill(
                          icon: Icons.language,
                          label: online ? 'Internet connected' : 'Offline',
                          on: online,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              children: [
                for (final item in tabs)
                  _SidebarItem(
                    item: item,
                    selected: AppShell._tabMatches(item, activeRoute),
                    onTap: () => onTab(item),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: ListenableBuilder(
              listenable: SyncEngine.instance,
              builder: (context, _) {
                final syncing = SyncEngine.instance.connectivity == ConnectivityState.syncing;
                return SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: syncing ? null : () => _syncStock(context),
                    style: ButtonStyle(
                      foregroundColor: const WidgetStatePropertyAll(AppColors.sidebarText),
                      iconColor: const WidgetStatePropertyAll(AppColors.sidebarText),
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed)
                            ? AppColors.sidebarHover
                            : AppColors.sidebarPanel,
                      ),
                      overlayColor: WidgetStatePropertyAll(AppColors.sidebarText.withValues(alpha: 0.08)),
                      side: const WidgetStatePropertyAll(BorderSide(color: AppColors.sidebarBorder)),
                      textStyle: WidgetStatePropertyAll(
                        GoogleFonts.ibmPlexSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.sidebarText),
                      ),
                      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                    ),
                    icon: syncing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sidebarText),
                          )
                        : const Icon(Icons.sync, size: 16, color: AppColors.sidebarText),
                    label: Text(
                      tr(syncing ? 'Synchronisation…' : 'Synchroniser'),
                      style: GoogleFonts.ibmPlexSans(color: AppColors.sidebarText, fontWeight: FontWeight.w600),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: _SidebarItem(
              item: _NavItem(
                route: 'logout',
                icon: Icons.logout_rounded,
                selectedIcon: Icons.logout_rounded,
                label: tr('Logout'),
                hint: '',
              ),
              selected: false,
              onTap: () => _confirmLogout(context),
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.sidebarActive,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.accent,
                  child: Text(
                    tr((config.cashierName.trim().isEmpty ? 'C' : config.cashierName.trim()[0]).toUpperCase()),
                    style: GoogleFonts.ibmPlexSans(color: AppColors.brand900, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(config.cashierName.isNotEmpty ? config.cashierName : 'Caissier'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.ibmPlexSans(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        tr(config.posRole.label),
                        style: GoogleFonts.ibmPlexSans(fontSize: 11, color: AppColors.sidebarText),
                      ),
                    ],
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

enum _StoreSwitcherStyle { chip, sidebar, subtitle }

class _StoreSwitcher extends StatefulWidget {
  const _StoreSwitcher({required this.style});

  final _StoreSwitcherStyle style;

  @override
  State<_StoreSwitcher> createState() => _StoreSwitcherState();
}

class _StoreSwitcherState extends State<_StoreSwitcher> {
  List<TerminalStoreOption> _stores = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final config = TerminalConfigRepository.instance.config;
    if (config.authToken.isEmpty) return;
    try {
      final stores = await loadTerminalStores();
      if (!mounted) return;
      setState(() => _stores = stores);
    } catch (_) {}
  }

  String _label() {
    final config = TerminalConfigRepository.instance.config;
    for (final store in _stores) {
      if (store.id == config.storeId) return store.name;
    }
    if (config.deviceName.trim().isNotEmpty) return config.deviceName.trim();
    if (config.brandName.trim().isNotEmpty) return config.brandName.trim();
    return 'Magasin';
  }

  Future<void> _open() async {
    if (_stores.isEmpty) await _load();
    if (!mounted) return;
    await openStoreSwitcher(context, stores: _stores);
  }

  @override
  Widget build(BuildContext context) {
    final label = _label();
    final several = _stores.length > 1;

    if (widget.style == _StoreSwitcherStyle.subtitle) {
      return GestureDetector(
        onTap: _open,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                several ? trf('{0} · {1} magasins', [label, _stores.length]) : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.swap_horiz_rounded, size: 14, color: AppColors.textSecondary),
          ],
        ),
      );
    }

    if (widget.style == _StoreSwitcherStyle.sidebar) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _open,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.sidebarActive,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.sidebarBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.storefront_outlined, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr(label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.ibmPlexSans(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Tooltip(
                  message: tr('Changer de magasin'),
                  child: const Icon(Icons.swap_horiz_rounded, size: 17, color: AppColors.sidebarText),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _ContextChip(
      icon: Icons.storefront_outlined,
      label: label,
      trailing: Icons.swap_horiz_rounded,
      tooltip: tr('Changer de magasin'),
      onTap: _open,
    );
  }
}

class _ConnectionPill extends StatelessWidget {
  const _ConnectionPill({required this.icon, required this.label, required this.on});

  final IconData icon;
  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final color = on ? AppColors.success : AppColors.textMuted;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: on ? const Color(0x1A059669) : AppColors.sidebarActive,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: on ? 0.45 : 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tr(label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.ibmPlexSans(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
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
            tr(role.label),
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppColors.sidebarActive : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: AppColors.sidebarHover,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  color: selected ? AppColors.accent : AppColors.sidebarText,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr(item.label),
                    style: GoogleFonts.ibmPlexSans(
                      color: selected ? Colors.white : AppColors.sidebarText,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
                  tr(title),
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  tr(subtitle),
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
                    const _StoreSwitcher(style: _StoreSwitcherStyle.chip),
                    const SizedBox(width: 8),
                    _ContextChip(
                      icon: Icons.person_outline,
                      label: cashier,
                    ),
                    const SizedBox(width: 8),
                    _ContextChip(
                      icon: Icons.schedule_outlined,
                      label: tr('Shifts'),
                      tone: AppColors.brandInk,
                      onTap: () => context.go(AppRoutes.shifts),
                    ),
                    const SizedBox(width: 8),
                    _RoleChip(role: config.posRole),
                    const SizedBox(width: 8),
                    const ThemeModeButton(),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const CalculatorButton(),
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
    this.trailing,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final Color? tone;
  final VoidCallback? onTap;
  final IconData? trailing;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final color = tone ?? AppColors.brandInk;
    final child = Container(
      constraints: BoxConstraints(maxWidth: trailing == null ? 160 : 200),
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
              tr(label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            Icon(trailing, size: 15, color: color),
          ],
        ],
      ),
    );

    if (onTap == null) return child;
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: child,
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class _NavItem {
  const _NavItem({
    required this.route,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.hint,
    this.branchIndex = 0,
    this.menuKey,
  });

  final String route;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String hint;
  final int branchIndex;

  /// Key in [CashierPreferences.menuKeys] for menus the user can hide.
  final String? menuKey;
}
