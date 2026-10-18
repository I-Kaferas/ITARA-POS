import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/terminal_config_repository.dart';
import '../../../core/i18n/app_locale.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../sync/cloud/cloud_sync_engine.dart';
import '../../../sync/cloud/cloud_sync_entity.dart';
import '../../../sync/cloud/cloud_sync_report.dart';
import '../../../sync/device_registry.dart';
import '../../../sync/local_master_discovery.dart';
import '../../../sync/local_master_server.dart';
import '../../../sync/local_realtime.dart';
import '../../../sync/offline_store.dart';
import '../../devices/presentation/bloc/device_bloc.dart';
import '../../devices/presentation/widgets/devices_registry_panel.dart';
import '../../devices/presentation/widgets/pairing_approval_panel.dart';
import '../../settings/data/device_api_service.dart';
import '../domain/company_link.dart';
import '../../pos/presentation/widgets/pos_ui.dart';
import '../data/master_overview_repository.dart';
import 'package:pos_mobile/core/i18n/tr.dart';
import 'package:pos_mobile/core/theme/app_typography.dart';

const _accent = AppColors.brand600;
const _info = AppColors.info;
const _amber = AppColors.accent;

typedef _ModuleSpec = ({String label, IconData icon, Color color});

_ModuleSpec _spec(CloudSyncModule module) => switch (module) {
      CloudSyncModule.company => (label: tr('Company'), icon: Icons.apartment_rounded, color: AppColors.brand600),
      CloudSyncModule.usersRoles => (label: tr('Users & Roles'), icon: Icons.groups_rounded, color: _info),
      CloudSyncModule.categories => (label: tr('Categories'), icon: Icons.category_rounded, color: _amber),
      CloudSyncModule.products => (label: tr('Products'), icon: Icons.inventory_2_rounded, color: AppColors.brand500),
      CloudSyncModule.stock => (label: tr('Stock'), icon: Icons.warehouse_rounded, color: AppColors.warning),
      CloudSyncModule.customers => (label: tr('Customers'), icon: Icons.person_rounded, color: _info),
      CloudSyncModule.paymentMethods => (label: tr('Payment Methods'), icon: Icons.credit_card_rounded, color: _amber),
      CloudSyncModule.shifts => (label: tr('Shifts'), icon: Icons.schedule_rounded, color: AppColors.success),
      CloudSyncModule.sales => (label: tr('Sales & Orders'), icon: Icons.receipt_long_rounded, color: AppColors.brand700),
    };

String _ago(DateTime at) {
  final diff = DateTime.now().difference(at);
  if (diff.inSeconds < 45) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

String _uptime(Duration value) {
  final h = value.inHours;
  final m = value.inMinutes % 60;
  final s = value.inSeconds % 60;
  if (h > 0) return '${h}h ${m}m ${s}s';
  if (m > 0) return '${m}m ${s}s';
  return '${s}s';
}

/// Master dashboard: server, terminals, company link and cloud sync.
class MasterConfigurationScreen extends StatefulWidget {
  const MasterConfigurationScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<MasterConfigurationScreen> createState() => _MasterConfigurationScreenState();
}

class _MasterConfigurationScreenState extends State<MasterConfigurationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 4,
    vsync: this,
    initialIndex: widget.initialTab.clamp(0, 3),
  );
  final _repository = MasterOverviewRepository();
  MasterOverview _overview = const MasterOverview();
  CloudSyncModule? _syncingModule;
  final Map<CloudSyncModule, CloudSyncReport> _moduleResults = {};
  bool _syncingAll = false;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _load();
    _refresh = Timer.periodic(const Duration(seconds: 20), (_) => _load());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final next = await _repository.load();
    if (mounted) setState(() => _overview = next);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr(message)), duration: const Duration(seconds: 2)),
    );
  }

  bool get _busy => _syncingAll || _syncingModule != null || CloudSyncEngine.instance.isRunning;

  Future<void> _syncModule(CloudSyncModule module) async {
    if (_busy) return;
    final label = _spec(module).label;
    setState(() {
      _syncingModule = module;
      _moduleResults.remove(module);
    });
    final report = await _runModule(module);
    if (!mounted) return;
    setState(() => _syncingModule = null);
    _toast(report.ok ? '$label synced' : report.message);
  }

  Future<CloudSyncReport> _runModule(CloudSyncModule module) async {
    final label = _spec(module).label;
    final report = await CloudSyncEngine.instance.syncModule(module);
    await OfflineStore.instance.log(
      report.ok ? 'info' : 'error',
      report.ok
          ? (module.uploads ? '$label sent to the cloud' : '$label downloaded from the cloud')
          : '$label: ${report.message}',
    );
    if (mounted) setState(() => _moduleResults[module] = report);
    await _load();
    return report;
  }

  Future<void> _syncAll() async {
    if (_busy) return;
    setState(() {
      _syncingAll = true;
      _moduleResults.clear();
    });
    var failed = 0;
    String? stopReason;
    for (final module in CloudSyncModule.values) {
      if (!mounted) return;
      setState(() => _syncingModule = module);
      final report = await _runModule(module);
      if (!report.ok) failed++;
      if (!report.cloudReachable) {
        stopReason = report.message;
        break;
      }
    }
    await CloudSyncEngine.instance.heartbeat();
    if (!mounted) return;
    setState(() {
      _syncingModule = null;
      _syncingAll = false;
    });
    _toast(stopReason ??
        (failed == 0
            ? 'Cloud sync completed'
            : '$failed module${failed == 1 ? '' : 's'} failed'));
  }

  Future<void> _toggleServer() async {
    final server = LocalMasterServer.instance;
    if (server.listening) {
      await server.stop();
    } else {
      await server.startIfMaster();
      await LocalMasterDiscovery.instance.start();
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DeviceBloc, DeviceState>(
      listenWhen: (previous, current) =>
          current.message != null && current.message != previous.message,
      listener: (context, state) {
        final message = state.message;
        if (message != null && message.isNotEmpty) _toast(message);
      },
      child: ColoredBox(
        color: AppColors.canvas,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(onBack: () => context.go(AppRoutes.hub)),
            _Tabs(controller: _tabs),
            Expanded(
              child: ListenableBuilder(
                listenable: CloudSyncEngine.instance,
                builder: (context, _) => TabBarView(
                  controller: _tabs,
                  children: [
                    _OverviewTab(
                      overview: _overview,
                      syncingModule: _syncingModule,
                      moduleResults: _moduleResults,
                      syncingAll: _syncingAll,
                      busy: _busy,
                      onRefresh: _load,
                      onToggleServer: _toggleServer,
                      onSyncModule: _syncModule,
                      onSyncAll: _syncAll,
                    ),
                    _DevicesTab(onRefresh: _load),
                    const _CompanyTab(),
                    _SyncTab(
                      overview: _overview,
                      syncingAll: _syncingAll,
                      busy: _busy,
                      onRefresh: _load,
                      onSyncAll: _syncAll,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final pad = PosUi.pagePadding(context);
    return Container(
      padding: EdgeInsets.fromLTRB(pad.left, 18, pad.right, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppColors.surface,
            Color.lerp(AppColors.surface, _accent, 0.16)!,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Material(
                color: AppColors.surfaceVariant,
                shape: CircleBorder(side: BorderSide(color: AppColors.border)),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onBack,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(Icons.arrow_back, size: 20, color: AppColors.textPrimary),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('Master Configuration'),
                      style: AppTypography.text(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      tr('Server settings & company connection'),
                      style: AppTypography.text(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ListenableBuilder(
            listenable: Listenable.merge([LocalMasterServer.instance, LocalRealtimeHub.instance]),
            builder: (context, _) {
              final server = LocalMasterServer.instance;
              final running = server.listening;
              final address = server.lanAddress;
              final connected = LocalRealtimeHub.instance.clientCount;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Chip(
                    icon: running ? Icons.check_circle : Icons.cancel,
                    label: running ? 'Server running' : 'Server stopped',
                    color: running ? AppColors.success : AppColors.danger,
                  ),
                  _Chip(
                    icon: Icons.wifi,
                    label: address == null ? 'No network' : '$address:${LocalMasterServer.port}',
                    color: _info,
                  ),
                  _Chip(
                    icon: Icons.devices_outlined,
                    label: trf('{0} connected', [connected]),
                    color: _info,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            tr(label),
            style: AppTypography.text(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final pad = PosUi.pagePadding(context);
    Widget tab(IconData icon, String label) => Tab(
          height: 46,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17),
              const SizedBox(width: 7),
              Text(tr(label)),
            ],
          ),
        );
    return Container(
      padding: EdgeInsets.symmetric(horizontal: pad.left - 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: _accent,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: _accent,
        indicatorWeight: 2.5,
        dividerColor: Colors.transparent,
        labelStyle: AppTypography.text(fontSize: 13.5, fontWeight: FontWeight.w700),
        unselectedLabelStyle: AppTypography.text(fontSize: 13.5, fontWeight: FontWeight.w600),
        tabs: [
          tab(Icons.dashboard_rounded, 'Overview'),
          tab(Icons.devices_rounded, 'Devices'),
          tab(Icons.apartment_rounded, 'Company'),
          tab(Icons.sync_rounded, 'Sync'),
        ],
      ),
    );
  }
}

class _TabList extends StatelessWidget {
  const _TabList({required this.children, this.onRefresh});

  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final pad = PosUi.pagePadding(context);
    final list = ListView(
      padding: EdgeInsets.fromLTRB(pad.left, 20, pad.right, 28),
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          children[i],
        ],
      ],
    );
    final refresh = onRefresh;
    if (refresh == null) return list;
    return RefreshIndicator(onRefresh: refresh, color: _accent, child: list);
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.icon,
    required this.color,
    required this.title,
    required this.child,
    this.subtitle,
    this.subtitleColor,
    this.action,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Color? subtitleColor;
  final Widget? action;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final heading = Row(
      children: [
        _IconTile(icon: icon, color: color, size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(title),
                style: AppTypography.text(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle != null)
                Text(
                  tr(subtitle!),
                  style: AppTypography.text(
                    fontSize: 12,
                    color: subtitleColor ?? AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = action != null && constraints.maxWidth < 440;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (action == null)
                heading
              else if (stacked) ...[
                heading,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: action),
              ] else
                Row(
                  children: [
                    Expanded(child: heading),
                    const SizedBox(width: 10),
                    action!,
                  ],
                ),
              const SizedBox(height: 16),
              child,
            ],
          );
        },
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.color, this.size = 38});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.27),
      ),
      child: Icon(icon, size: size * 0.48, color: color),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color = _accent,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: color.withValues(alpha: 0.55),
        disabledForegroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: busy
          ? const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Icon(icon, size: 17),
      label: Text(tr(label), style: AppTypography.text(fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }
}

// ── Overview ────────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.overview,
    required this.syncingModule,
    required this.moduleResults,
    required this.syncingAll,
    required this.busy,
    required this.onRefresh,
    required this.onToggleServer,
    required this.onSyncModule,
    required this.onSyncAll,
  });

  final MasterOverview overview;
  final CloudSyncModule? syncingModule;
  final Map<CloudSyncModule, CloudSyncReport> moduleResults;
  final bool syncingAll;
  final bool busy;
  final Future<void> Function() onRefresh;
  final VoidCallback onToggleServer;
  final ValueChanged<CloudSyncModule> onSyncModule;
  final VoidCallback onSyncAll;

  @override
  Widget build(BuildContext context) {
    return _TabList(
      onRefresh: onRefresh,
      children: [
        _StatsGrid(overview: overview),
        _HealthPanel(databaseOk: overview.databaseOk, onToggle: onToggleServer),
        _ManualSyncPanel(
          overview: overview,
          syncingModule: syncingModule,
          moduleResults: moduleResults,
          syncingAll: syncingAll,
          busy: busy,
          onSyncModule: onSyncModule,
          onSyncAll: onSyncAll,
        ),
        _ActivityPanel(items: overview.activity),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.overview});

  final MasterOverview overview;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocalMasterServer.instance,
      builder: (context, _) {
        final running = LocalMasterServer.instance.listening;
        final cards = [
          _StatCard(
            icon: Icons.inventory_2_rounded,
            color: AppColors.brand500,
            badge: 'active',
            value: Text('${overview.records(CloudSyncModule.products)}'),
            label: tr('Total products'),
          ),
          _StatCard(
            icon: Icons.receipt_long_rounded,
            color: AppColors.success,
            badge: 'today',
            value: Text('${overview.ordersToday}'),
            label: tr('Orders today'),
          ),
          _StatCard(
            icon: Icons.cloud_done_rounded,
            color: _info,
            badge: 'local DB',
            value: Text('${overview.syncedRecords}'),
            label: tr('Synced records'),
          ),
          _StatCard(
            icon: Icons.timer_rounded,
            color: _amber,
            badge: running ? 'running' : 'stopped',
            badgeColor: running ? AppColors.success : AppColors.danger,
            value: const _UptimeText(),
            label: tr('Server uptime'),
          ),
        ];
        return LayoutBuilder(
          builder: (context, constraints) {
            const gap = 12.0;
            final columns = constraints.maxWidth >= 860 ? 4 : 2;
            final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [for (final card in cards) SizedBox(width: width, child: card)],
            );
          },
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.badge,
    required this.value,
    required this.label,
    this.badgeColor,
  });

  final IconData icon;
  final Color color;
  final String badge;
  final Color? badgeColor;
  final Widget value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tone = badgeColor ?? AppColors.success;
    return Container(
      height: 138,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconTile(icon: icon, color: color),
              const Spacer(),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.trending_up_rounded, size: 12, color: tone),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          tr(badge),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.text(fontSize: 10.5, fontWeight: FontWeight.w700, color: tone),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          DefaultTextStyle(
            style: AppTypography.text(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            child: value,
          ),
          const SizedBox(height: 2),
          Text(
            tr(label),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.text(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _UptimeText extends StatefulWidget {
  const _UptimeText();

  @override
  State<_UptimeText> createState() => _UptimeTextState();
}

class _UptimeTextState extends State<_UptimeText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final started = LocalMasterServer.instance.startedAt;
    return Text(tr(started == null ? '—' : _uptime(DateTime.now().difference(started))));
  }
}

class _HealthPanel extends StatelessWidget {
  const _HealthPanel({required this.databaseOk, required this.onToggle});

  final bool databaseOk;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        LocalMasterServer.instance,
        LocalRealtimeHub.instance,
        LocalMasterDiscovery.instance,
      ]),
      builder: (context, _) {
        final server = LocalMasterServer.instance;
        final checks = [
          ('HTTP', server.listening),
          ('WebSocket', LocalRealtimeHub.instance.isRunning),
          ('Database', databaseOk),
          ('Discovery', LocalMasterDiscovery.instance.isRunning),
        ];
        final down = checks.where((check) => !check.$2).length;
        return _Panel(
          icon: Icons.shield_rounded,
          color: AppColors.success,
          title: tr('Server Health'),
          subtitle: down == 0
              ? 'All systems operational'
              : (server.lastError ?? '$down service${down == 1 ? '' : 's'} need attention'),
          subtitleColor: down == 0 ? AppColors.success : AppColors.danger,
          action: _ActionButton(
            icon: server.listening ? Icons.stop_rounded : Icons.play_arrow_rounded,
            label: server.listening ? 'Stop' : 'Start',
            color: server.listening ? AppColors.danger : AppColors.success,
            onPressed: onToggle,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const gap = 10.0;
              final columns = constraints.maxWidth >= 560 ? 4 : 2;
              final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final check in checks)
                    SizedBox(width: width, child: _HealthTile(label: check.$1, ok: check.$2)),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _HealthTile extends StatelessWidget {
  const _HealthTile({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr(label),
            style: AppTypography.text(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualSyncPanel extends StatelessWidget {
  const _ManualSyncPanel({
    required this.overview,
    required this.syncingModule,
    required this.moduleResults,
    required this.syncingAll,
    required this.busy,
    required this.onSyncModule,
    required this.onSyncAll,
  });

  final MasterOverview overview;
  final CloudSyncModule? syncingModule;
  final Map<CloudSyncModule, CloudSyncReport> moduleResults;
  final bool syncingAll;
  final bool busy;
  final ValueChanged<CloudSyncModule> onSyncModule;
  final VoidCallback onSyncAll;

  @override
  Widget build(BuildContext context) {
    final modules = CloudSyncModule.values;
    final current = syncingModule;
    final String subtitle;
    if (syncingAll && current != null) {
      subtitle = 'Syncing ${_spec(current).label} (${modules.indexOf(current) + 1}/${modules.length})…';
    } else if (moduleResults.isNotEmpty) {
      final failed = moduleResults.values.where((report) => !report.ok).length;
      subtitle = failed == 0
          ? '${moduleResults.length}/${modules.length} modules synced'
          : '$failed module${failed == 1 ? '' : 's'} failed • tap to retry';
    } else {
      subtitle = 'Sync each module with the cloud on its own';
    }
    return _Panel(
      icon: Icons.sync_rounded,
      color: _accent,
      title: tr('Manual Sync'),
      subtitle: subtitle,
      action: _ActionButton(
        icon: Icons.cloud_sync_rounded,
        label: tr('Sync All'),
        busy: syncingAll,
        onPressed: busy ? null : onSyncAll,
      ),
      child: Column(
        children: [
          for (final module in modules) ...[
            _ModuleRow(
              module: module,
              records: overview.records(module),
              syncing: current == module,
              queued: syncingAll && current != module && !moduleResults.containsKey(module),
              result: moduleResults[module],
              enabled: !busy,
              onSync: () => onSyncModule(module),
            ),
            if (module != modules.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ModuleRow extends StatelessWidget {
  const _ModuleRow({
    required this.module,
    required this.records,
    required this.syncing,
    required this.enabled,
    required this.onSync,
    this.queued = false,
    this.result,
  });

  final CloudSyncModule module;
  final int records;
  final bool syncing;
  final bool queued;
  final CloudSyncReport? result;
  final bool enabled;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final spec = _spec(module);
    final done = !syncing && result?.ok == true;
    final failed = !syncing && result != null && !result!.ok;
    final (String? status, Color statusColor) = syncing
        ? ('Syncing…', spec.color)
        : failed
            ? ('Failed', AppColors.danger)
            : done
                ? ('Synced', AppColors.success)
                : queued
                    ? ('Waiting', AppColors.textMuted)
                    : (null, AppColors.textMuted);
    final borderColor = syncing
        ? spec.color.withValues(alpha: 0.6)
        : failed
            ? AppColors.danger.withValues(alpha: 0.45)
            : done
                ? AppColors.success.withValues(alpha: 0.4)
                : AppColors.border;
    final buttonColor = failed ? AppColors.danger : (done ? AppColors.success : spec.color);
    final IconData buttonIcon = failed
        ? Icons.refresh_rounded
        : done
            ? Icons.check_rounded
            : (module.uploads ? Icons.cloud_upload_rounded : Icons.cloud_download_rounded);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: syncing ? Color.lerp(AppColors.canvas, spec.color, 0.06) : AppColors.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: syncing ? 1.5 : 1),
      ),
      child: Row(
        children: [
          _IconTile(icon: spec.icon, color: spec.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(spec.label),
                  style: AppTypography.text(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        trf('{0} record{1}', [records, records == 1 ? '' : 's']),
                        style: AppTypography.text(fontSize: 10.5, color: AppColors.textSecondary),
                      ),
                    ),
                    if (status != null)
                      Text(
                        tr(status),
                        style: AppTypography.text(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                  ],
                ),
                if (failed && result!.message.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    tr(result!.message),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.text(fontSize: 11, color: AppColors.danger),
                  ),
                ],
              ],
            ),
          ),
          Tooltip(
            message: failed
                ? 'Retry'
                : (module.uploads ? 'Send to cloud' : 'Download from cloud'),
            child: Material(
              color: buttonColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                onTap: enabled ? onSync : null,
                borderRadius: BorderRadius.circular(9),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: syncing
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: spec.color),
                          )
                        : Icon(
                            buttonIcon,
                            size: 18,
                            color: enabled || done || failed
                                ? buttonColor
                                : buttonColor.withValues(alpha: 0.4),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityPanel extends StatefulWidget {
  const _ActivityPanel({required this.items, this.title = 'Recent Activity', this.preview = 5});

  final List<MasterActivity> items;
  final String title;
  final int preview;

  @override
  State<_ActivityPanel> createState() => _ActivityPanelState();
}

class _ActivityPanelState extends State<_ActivityPanel> {
  bool _all = false;

  Color _color(MasterActivityKind kind) => switch (kind) {
        MasterActivityKind.device || MasterActivityKind.server => AppColors.success,
        MasterActivityKind.sale => _info,
        MasterActivityKind.cloud => _accent,
        MasterActivityKind.warning => _amber,
        MasterActivityKind.error => AppColors.danger,
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocalMasterServer.instance,
      builder: (context, _) {
        final server = LocalMasterServer.instance;
        final started = server.startedAt;
        final items = [
          ...widget.items,
          if (started != null)
            MasterActivity(
              kind: MasterActivityKind.server,
              title: tr('Server started'),
              detail: '${server.lanAddress ?? 'localhost'}:${LocalMasterServer.port}',
              at: started,
            ),
        ]..sort((a, b) => b.at.compareTo(a.at));
        final visible = _all ? items : items.take(widget.preview).toList();
        return _Panel(
          icon: Icons.timeline_rounded,
          color: _accent,
          title: widget.title,
          action: items.length > widget.preview
              ? TextButton(
                  onPressed: () => setState(() => _all = !_all),
                  style: TextButton.styleFrom(foregroundColor: _accent),
                  child: Text(tr(_all ? 'Show less' : 'View all')),
                )
              : null,
          child: visible.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    tr('No activity yet. Terminals, sales and sync runs will appear here.'),
                    style: AppTypography.text(fontSize: 12.5, color: AppColors.textMuted),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < visible.length; i++)
                      _ActivityRow(
                        item: visible[i],
                        color: _color(visible[i].kind),
                        last: i == visible.length - 1,
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item, required this.color, required this.last});

  final MasterActivity item;
  final Color color;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 16,
            child: Column(
              children: [
                const SizedBox(height: 4),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                if (!last)
                  Expanded(
                    child: Container(width: 2, color: AppColors.border),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(item.title),
                    style: AppTypography.text(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (item.detail.isNotEmpty)
                    Text(
                      tr(item.detail),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.text(fontSize: 12, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            tr(_ago(item.at)),
            style: AppTypography.text(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── Devices ─────────────────────────────────────────────────────────────────

class _DevicesTab extends StatelessWidget {
  const _DevicesTab({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DeviceBloc, DeviceState>(
      builder: (context, state) {
        final devices = state.devices;
        final online = devices.where((device) => device.status == LanDeviceStatus.online).length;
        return _TabList(
          onRefresh: () async {
            context.read<DeviceBloc>().add(const DeviceRefreshed());
            await onRefresh();
          },
          children: [
            _Panel(
              icon: Icons.qr_code_2_rounded,
              color: _accent,
              title: tr('Pair a terminal'),
              subtitle: tr('Share the code with a POS terminal and approve its request'),
              child: PairingApprovalPanel(),
            ),
            _Panel(
              icon: Icons.devices_rounded,
              color: _info,
              title: trf('Registered devices ({0})', [devices.length]),
              subtitle: trf('{0} online', [online]),
              action: IconButton(
                tooltip: tr('Refresh'),
                onPressed: () => context.read<DeviceBloc>().add(const DeviceRefreshed()),
                icon: Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
              ),
              child: devices.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Column(
                        children: [
                          Icon(Icons.devices_other_outlined, size: 40, color: AppColors.textMuted),
                          const SizedBox(height: 10),
                          Text(
                            tr('POS terminals appear here once they pair with this Master'),
                            textAlign: TextAlign.center,
                            style: AppTypography.text(fontSize: 12.5, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [for (final device in devices) DeviceRegistryRow(device: device)],
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ── Company ─────────────────────────────────────────────────────────────────

class _CompanyTab extends StatefulWidget {
  const _CompanyTab();

  @override
  State<_CompanyTab> createState() => _CompanyTabState();
}

class _CompanyTabState extends State<_CompanyTab> {
  static const _violet = AppColors.brand600;

  final _joinCtrl = TextEditingController();
  final _apiCtrl = TextEditingController();
  final _apiFocus = FocusNode();
  bool _validating = false;
  bool _savingUrl = false;
  String? _message;
  bool _messageOk = false;

  @override
  void initState() {
    super.initState();
    final config = TerminalConfigRepository.instance.config;
    _joinCtrl.text = CompanyLink.formatJoinKey(config.deviceSyncToken);
    _apiCtrl.text = config.apiBaseUrl;
  }

  @override
  void dispose() {
    _joinCtrl.dispose();
    _apiCtrl.dispose();
    _apiFocus.dispose();
    super.dispose();
  }

  String _value(String raw) => raw.trim().isEmpty ? '—' : raw.trim();

  void _onJoinChanged(String value) {
    final formatted = CompanyLink.formatJoinKey(value);
    if (formatted == value) {
      setState(() {});
      return;
    }
    _joinCtrl.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    setState(() {});
  }

  Future<void> _copyJoinKey() async {
    final key = _joinCtrl.text.trim();
    if (key.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: key));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('Join key copied')), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _saveUrl() async {
    final url = _apiCtrl.text.trim();
    if (url.isEmpty || _savingUrl) return;
    setState(() => _savingUrl = true);
    try {
      final repo = TerminalConfigRepository.instance;
      await repo.save(repo.config.copyWith(apiBaseUrl: url));
      if (!mounted) return;
      setState(() {
        _message = 'API address saved';
        _messageOk = true;
        _savingUrl = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = humanizeApiCode(error.toString().replaceFirst('Exception: ', ''));
        _messageOk = false;
        _savingUrl = false;
      });
    }
  }

  Future<void> _validate() async {
    final key = CompanyLink.formatJoinKey(_joinCtrl.text);
    if (!CompanyLink.isComplete(key)) {
      setState(() {
        _message = 'Enter the join key first';
        _messageOk = false;
      });
      return;
    }
    final url = _apiCtrl.text.trim();
    if (url.isEmpty) {
      setState(() {
        _message = 'Enter the API address first';
        _messageOk = false;
      });
      return;
    }
    final repo = TerminalConfigRepository.instance;
    if (repo.config.authToken.trim().isEmpty) {
      setState(() {
        _message = 'Sign in before validating the join key';
        _messageOk = false;
      });
      return;
    }

    setState(() {
      _validating = true;
      _message = null;
    });
    try {
      if (url != repo.config.apiBaseUrl.trim()) {
        await repo.save(repo.config.copyWith(apiBaseUrl: url));
      }
      final data = await DeviceApiService().pairWithJoinKey(key);
      final next = CompanyLink.applyPair(
        current: TerminalConfigRepository.instance.config,
        joinKey: key,
        data: data,
      );
      await TerminalConfigRepository.instance.save(next);
      if (!mounted) return;
      setState(() {
        _joinCtrl.text = next.deviceSyncToken;
        _message = 'Join key accepted';
        _messageOk = true;
        _validating = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = humanizeApiCode(error.toString().replaceFirst('Exception: ', ''));
        _messageOk = false;
        _validating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TerminalConfigRepository.instance,
      builder: (context, _) {
        final config = TerminalConfigRepository.instance.config;
        final connected = config.deviceSyncToken.trim().isNotEmpty;
        final company = config.brandName.trim();
        return _TabList(
          children: [
            _ConnectionBanner(connected: connected, company: company),
            LayoutBuilder(
              builder: (context, constraints) {
                final join = _joinCard();
                final api = _apiCard(config.apiBaseUrl);
                if (constraints.maxWidth < 860) {
                  return Column(
                    children: [
                      join,
                      const SizedBox(height: 16),
                      api,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: join),
                    const SizedBox(width: 16),
                    Expanded(child: api),
                  ],
                );
              },
            ),
            _Panel(
              icon: Icons.apartment_rounded,
              color: _violet,
              title: company.isEmpty ? 'Company identity' : company,
              subtitle: connected ? 'Filled from the join key' : 'Waiting for a join key',
              child: _Facts(
                facts: [
                  ('Tenant', _value(config.tenantSlug)),
                  ('Tenant ID', _value(config.tenantId)),
                  ('Store ID', _value(config.storeId)),
                  ('Currency', _value(config.currencyCode)),
                  ('Language', _value(config.locale)),
                  ('Time zone', _value(config.timezone)),
                  ('Business profile', _value(config.companyProfile)),
                  ('Master device', _value(config.deviceName)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _joinCard() {
    final ready = CompanyLink.isComplete(_joinCtrl.text);
    return _Panel(
      icon: Icons.key_rounded,
      color: _violet,
      title: 'Device Join Key',
      subtitle: 'Enter the key generated from your web dashboard (Devices module)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _joinCtrl,
            onChanged: _onJoinChanged,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            style: AppTypography.text(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: AppColors.textPrimary,
            ),
            decoration: _inputDecoration(
              hint: 'ITN-XXXX-XXXX-XXXX',
              icon: Icons.key_rounded,
              suffix: IconButton(
                tooltip: tr('Copy'),
                onPressed: _copyJoinKey,
                icon: Icon(Icons.copy_rounded, size: 18, color: AppColors.textSecondary),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _validating || !ready ? null : _validate,
            style: FilledButton.styleFrom(
              backgroundColor: _violet,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _violet.withValues(alpha: 0.45),
              disabledForegroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: _validating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.key_rounded, size: 18),
            label: Text(
              tr('Validate Join Key'),
              style: AppTypography.text(fontSize: 14.5, fontWeight: FontWeight.w700),
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 10),
            Text(
              tr(_message!),
              style: AppTypography.text(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _messageOk ? AppColors.success : AppColors.danger,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 15, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('You can find the join key in your SaaS dashboard under Devices → Generate Key'),
                  style: AppTypography.text(fontSize: 12, color: AppColors.textMuted, height: 1.35),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _apiCard(String savedUrl) {
    final dirty = _apiCtrl.text.trim() != savedUrl.trim();
    return _Panel(
      icon: Icons.settings_rounded,
      color: _violet,
      title: 'API Configuration',
      subtitle: 'Cloud API server address',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('API Base URL'),
            style: AppTypography.text(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _apiCtrl,
            focusNode: _apiFocus,
            onChanged: (_) => setState(() {}),
            keyboardType: TextInputType.url,
            autocorrect: false,
            style: AppTypography.text(fontSize: 13.5, color: AppColors.textPrimary),
            decoration: _inputDecoration(hint: 'https://api.example.com', icon: Icons.link_rounded),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _savingUrl || _apiCtrl.text.trim().isEmpty ? null : _saveUrl,
            style: OutlinedButton.styleFrom(
              foregroundColor: dirty ? _violet : AppColors.textSecondary,
              disabledForegroundColor: AppColors.textMuted,
              minimumSize: const Size.fromHeight(46),
              side: BorderSide(color: dirty ? _violet.withValues(alpha: 0.7) : AppColors.borderStrong),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: _savingUrl
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textSecondary),
                  )
                : Icon(Icons.lock_outline_rounded, size: 16, color: dirty ? _violet : AppColors.textMuted),
            label: Text(
              tr('Save URL'),
              style: AppTypography.text(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.text(
        fontSize: 13.5,
        letterSpacing: 0.6,
        color: AppColors.textMuted,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(icon, size: 18, color: AppColors.textMuted),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.canvas,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _violet, width: 1.4),
      ),
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.connected, required this.company});

  final bool connected;
  final String company;

  @override
  Widget build(BuildContext context) {
    final color = connected ? AppColors.success : _amber;
    final title = connected ? 'Connected' : 'Not Connected';
    final subtitle = connected
        ? (company.isEmpty ? 'This device is linked to the company' : company)
        : 'Enter your join key to connect this device';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Row(
        children: [
          _IconTile(
            icon: connected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            color: color,
            size: 44,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(title),
                  style: AppTypography.text(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tr(subtitle),
                  style: AppTypography.text(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Facts extends StatelessWidget {
  const _Facts({required this.facts});

  final List<(String, String)> facts;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final columns = constraints.maxWidth >= 620 ? 2 : 1;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final fact in facts)
              Container(
                width: width,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Text(
                      tr(fact.$1),
                      style: AppTypography.text(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onLongPress: fact.$2 == '—'
                            ? null
                            : () => Clipboard.setData(ClipboardData(text: fact.$2)),
                        child: Text(
                          tr(fact.$2),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.text(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Sync ────────────────────────────────────────────────────────────────────

class _SyncTab extends StatelessWidget {
  const _SyncTab({
    required this.overview,
    required this.syncingAll,
    required this.busy,
    required this.onRefresh,
    required this.onSyncAll,
  });

  final MasterOverview overview;
  final bool syncingAll;
  final bool busy;
  final Future<void> Function() onRefresh;
  final VoidCallback onSyncAll;

  @override
  Widget build(BuildContext context) {
    final cloud = CloudSyncEngine.instance;
    final queue = [
      ('Pending', overview.outbox['pending'] ?? 0, _amber, Icons.hourglass_top_rounded),
      ('Failed', overview.outbox['failed'] ?? 0, AppColors.danger, Icons.error_outline_rounded),
      ('Synced', overview.outbox['synced'] ?? 0, AppColors.success, Icons.cloud_done_rounded),
      ('Conflicts', overview.outbox['conflicts'] ?? 0, _accent, Icons.call_split_rounded),
    ];
    final last = cloud.lastSyncAt;
    return _TabList(
      onRefresh: onRefresh,
      children: [
        _Panel(
          icon: Icons.cloud_sync_rounded,
          color: _accent,
          title: tr('Cloud sync'),
          subtitle: last == null
              ? 'No sync run since the app started'
              : 'Last run ${_ago(last)} • ${cloud.lastReport.message}',
          subtitleColor: cloud.lastError == null ? null : AppColors.danger,
          action: _ActionButton(
            icon: Icons.sync_rounded,
            label: tr('Sync now'),
            busy: syncingAll,
            onPressed: busy ? null : onSyncAll,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const gap = 10.0;
              final columns = constraints.maxWidth >= 560 ? 4 : 2;
              final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final item in queue)
                    Container(
                      width: width,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: item.$3.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: item.$3.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Icon(item.$4, size: 18, color: item.$3),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item.$2}',
                                  style: AppTypography.text(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  tr(item.$1),
                                  style: AppTypography.text(fontSize: 11.5, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        _ActivityPanel(items: overview.activity, title: tr('Sync journal'), preview: 12),
      ],
    );
  }
}
