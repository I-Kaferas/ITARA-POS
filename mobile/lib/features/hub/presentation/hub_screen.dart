import 'dart:async';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/terminal_config.dart';
import '../../../core/config/terminal_config_repository.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../sync/local_master_discovery.dart';
import '../../../sync/local_master_server.dart';
import '../../../sync/pairing_service.dart';
import '../../devices/presentation/bloc/device_bloc.dart';
import '../../devices/presentation/bloc/master_discovery_bloc.dart';
import '../../devices/presentation/bloc/master_pairing_bloc.dart';
import '../../devices/presentation/widgets/devices_registry_panel.dart';
import '../../devices/presentation/widgets/discovered_masters_panel.dart';
import '../../devices/presentation/widgets/master_pairing_dialog.dart';
import '../../pos/presentation/widgets/pos_ui.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

const _masterColor = Color(0xFF6D3FE6);
const _terminalColor = Color(0xFF0EA5E9);
const _infoColor = Color(0xFF3B82F6);

/// Device management: Master dashboard, or role selection for other roles.
class HubScreen extends StatefulWidget {
  const HubScreen({super.key});

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  final _repo = TerminalConfigRepository.instance;
  bool _changingRole = false;
  bool _startingMaster = false;

  PosRole get _role => _repo.config.posRole;

  @override
  void initState() {
    super.initState();
    _repo.addListener(_onConfigChanged);
    if (_role == PosRole.slave) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _searchMasters());
    }
  }

  @override
  void dispose() {
    _repo.removeListener(_onConfigChanged);
    super.dispose();
  }

  void _onConfigChanged() {
    if (mounted) setState(() {});
  }

  void _searchMasters() {
    if (!mounted) return;
    context.read<MasterDiscoveryBloc>().add(const MasterDiscoverySearchRequested());
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr(message)), duration: const Duration(seconds: 2)),
    );
  }

  void _back() {
    if (_changingRole && _role == PosRole.master) {
      setState(() => _changingRole = false);
      return;
    }
    context.go(AppRoutes.cashierSettings);
  }

  Future<void> _startAsMaster() async {
    setState(() => _startingMaster = true);
    try {
      await _repo.save(_repo.config.copyWith(posRole: PosRole.master));
      await LocalMasterServer.instance.startIfMaster();
      await LocalMasterDiscovery.instance.start();
      if (!mounted) return;
      setState(() => _changingRole = false);
      final server = LocalMasterServer.instance;
      if (!server.listening) {
        _toast(server.lastError ?? 'Unable to start the Master server.');
      }
    } finally {
      if (mounted) setState(() => _startingMaster = false);
    }
  }

  Future<void> _becomeTerminal() async {
    if (_role != PosRole.slave && !await _confirmLeaveMaster('POS Terminal')) return;
    await _switchRole(PosRole.slave);
    _searchMasters();
  }

  Future<void> _becomeStandalone() async {
    if (_role == PosRole.standalone) return;
    if (!await _confirmLeaveMaster('standalone')) return;
    await _switchRole(PosRole.standalone);
  }

  Future<bool> _confirmLeaveMaster(String target) async {
    if (_role != PosRole.master) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trf('Switch to {0}?', [target])),
        content: Text(
          tr('The Master server will stop. Connected terminals lose their link until they join another Master.'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Switch'))),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _switchRole(PosRole role) async {
    if (_role != role) {
      await _repo.save(_repo.config.copyWith(posRole: role));
    }
    await LocalMasterServer.instance.startIfMaster();
    if (mounted) setState(() => _changingRole = false);
  }

  @override
  Widget build(BuildContext context) {
    final showMaster = _role == PosRole.master && !_changingRole;
    return ColoredBox(
      color: AppColors.canvas,
      child: showMaster
          ? _MasterHubView(
              onBack: _back,
              onChangeRole: () => setState(() => _changingRole = true),
              onToast: _toast,
            )
          : _RoleSelectView(
              role: _role,
              masterHost: _repo.config.masterHost.trim(),
              startingMaster: _startingMaster,
              onBack: _back,
              onStartMaster: _startAsMaster,
              onFindMaster: _role == PosRole.slave ? _searchMasters : _becomeTerminal,
              onStandalone: _becomeStandalone,
              onSearchMasters: _searchMasters,
            ),
    );
  }
}

class _MasterHubView extends StatelessWidget {
  const _MasterHubView({
    required this.onBack,
    required this.onChangeRole,
    required this.onToast,
  });

  final VoidCallback onBack;
  final VoidCallback onChangeRole;
  final ValueChanged<String> onToast;

  String _address(LocalMasterServer server) {
    final ip = server.lanAddress;
    return ip == null ? '—' : '$ip:${LocalMasterServer.port}';
  }

  Future<void> _showPairing(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const _PairingDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = PosUi.pagePadding(context);
    return ListenableBuilder(
      listenable: LocalMasterServer.instance,
      builder: (context, _) {
        final server = LocalMasterServer.instance;
        final running = server.listening;
        return BlocConsumer<DeviceBloc, DeviceState>(
          listenWhen: (previous, current) =>
              current.message != null && current.message != previous.message,
          listener: (context, state) {
            final message = state.message;
            if (message != null && message.isNotEmpty) onToast(message);
          },
          builder: (context, deviceState) {
            final devices = deviceState.devices;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HubHeader(
                  icon: Icons.dns_rounded,
                  title: tr('Master Hub'),
                  onBack: onBack,
                  trailing: _HeaderButton(
                    icon: Icons.swap_horiz_rounded,
                    label: tr('Change role'),
                    onTap: onChangeRole,
                  ),
                  chips: [
                    _StatusChip(
                      icon: running ? Icons.check_circle : Icons.cancel,
                      label: running ? 'Server running' : 'Server stopped',
                      color: running ? AppColors.success : AppColors.danger,
                    ),
                    _StatusChip(
                      icon: Icons.wifi,
                      label: server.lanAddress ?? 'No network',
                      color: _infoColor,
                    ),
                    _StatusChip(
                      icon: Icons.devices_outlined,
                      label: '${devices.length} ${devices.length == 1 ? 'device' : 'devices'}',
                      color: _infoColor,
                    ),
                  ],
                  action: _HeaderButton(
                    icon: Icons.settings,
                    label: tr('Configure'),
                    onTap: () => context.go(AppRoutes.masterConfiguration),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(pad.left, 24, pad.right, 24),
                    children: [
                      _ServerCard(
                        running: running,
                        address: _address(server),
                        error: server.lastError,
                        onCopy: () async {
                          await Clipboard.setData(ClipboardData(text: _address(server)));
                          onToast('Address copied');
                        },
                        onToggle: () => running
                            ? server.stop()
                            : server.startIfMaster(),
                      ),
                      BlocBuilder<MasterPairingBloc, MasterPairingState>(
                        builder: (context, pairing) {
                          final count = pairing.pendingRequests.length;
                          if (count == 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: _PendingBanner(
                              count: count,
                              onReview: () => _showPairing(context),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 26),
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _infoColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Icon(Icons.devices_outlined, size: 16, color: _infoColor),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              trf('Registered devices ({0})', [devices.length]),
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: tr('Pairing code'),
                            onPressed: () => _showPairing(context),
                            icon: Icon(Icons.qr_code_2, color: AppColors.textSecondary),
                          ),
                          IconButton(
                            tooltip: tr('Refresh'),
                            onPressed: () => context.read<DeviceBloc>().add(const DeviceRefreshed()),
                            icon: Icon(Icons.refresh, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (devices.isEmpty)
                        const _EmptyDevices()
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              for (final device in devices) DeviceRegistryRow(device: device),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _RoleSelectView extends StatelessWidget {
  const _RoleSelectView({
    required this.role,
    required this.masterHost,
    required this.startingMaster,
    required this.onBack,
    required this.onStartMaster,
    required this.onFindMaster,
    required this.onStandalone,
    required this.onSearchMasters,
  });

  final PosRole role;
  final String masterHost;
  final bool startingMaster;
  final VoidCallback onBack;
  final VoidCallback onStartMaster;
  final VoidCallback onFindMaster;
  final VoidCallback onStandalone;
  final VoidCallback onSearchMasters;

  @override
  Widget build(BuildContext context) {
    final pad = PosUi.pagePadding(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HubHeader(icon: Icons.hub_outlined, title: tr('Hub'), onBack: onBack),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(pad.left, 28, pad.right, 28),
            children: [
              Text(
                tr('Select device role'),
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tr('Choose how this device will operate in the POS network'),
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSans(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 720;
                  final master = _DeviceRoleCard(
                    icon: Icons.dns_rounded,
                    color: _masterColor,
                    title: tr('Master'),
                    description:
                        tr('Central server — manages all POS terminals, syncs data, and controls the network.'),
                    features: const [
                      'HTTP + WebSocket server',
                      'Manage connected devices',
                      'Source of truth for data',
                      'Broadcast real-time updates',
                    ],
                    actionIcon: Icons.rocket_launch_rounded,
                    actionLabel: tr('Start as Master'),
                    selected: role == PosRole.master,
                    busy: startingMaster,
                    fill: wide,
                    onAction: onStartMaster,
                  );
                  final terminal = _DeviceRoleCard(
                    icon: Icons.point_of_sale_rounded,
                    color: _terminalColor,
                    title: tr('POS Terminal'),
                    description:
                        tr('Client terminal — connects to the master for order entry, payment, and real-time sync.'),
                    features: const [
                      'Auto-discover master on LAN',
                      'Sync orders in real-time',
                      'Offline queue when disconnected',
                      'Lightweight and fast',
                    ],
                    actionIcon: Icons.search_rounded,
                    actionLabel: role == PosRole.slave ? 'Search again' : 'Find Master',
                    selected: role == PosRole.slave,
                    fill: wide,
                    onAction: onFindMaster,
                  );
                  if (!wide) {
                    return Column(
                      children: [master, const SizedBox(height: 14), terminal],
                    );
                  }
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: master),
                        const SizedBox(width: 16),
                        Expanded(child: terminal),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: onStandalone,
                  style: TextButton.styleFrom(
                    foregroundColor:
                        role == PosRole.standalone ? AppColors.brandInk : AppColors.textMuted,
                  ),
                  icon: Icon(
                    role == PosRole.standalone ? Icons.check_circle : PosRole.standalone.icon,
                    size: 16,
                  ),
                  label: Text(
                    tr('Use this device on its own (standalone)'),
                    style: GoogleFonts.ibmPlexSans(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (role == PosRole.slave) ...[
                const SizedBox(height: 16),
                _AvailableMasters(masterHost: masterHost, onRefresh: onSearchMasters),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AvailableMasters extends StatelessWidget {
  const _AvailableMasters({required this.masterHost, required this.onRefresh});

  final String masterHost;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tr('Masters on the local network'),
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (masterHost.isNotEmpty)
                _StatusChip(
                  icon: Icons.link,
                  label: trf('Linked to {0}', [masterHost]),
                  color: AppColors.success,
                ),
            ],
          ),
          const SizedBox(height: 12),
          BlocBuilder<MasterDiscoveryBloc, MasterDiscoveryState>(
            builder: (context, state) => DiscoveredMastersPanel(
              masters: state.masters,
              searching: state.searching,
              statusMessage: state.statusMessage,
              onRefresh: onRefresh,
              onConnect: (master) => pairWithDiscoveredMaster(context, master),
            ),
          ),
        ],
      ),
    );
  }
}

class _HubHeader extends StatelessWidget {
  const _HubHeader({
    required this.icon,
    required this.title,
    required this.onBack,
    this.trailing,
    this.chips = const [],
    this.action,
  });

  final IconData icon;
  final String title;
  final VoidCallback onBack;
  final Widget? trailing;
  final List<Widget> chips;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final pad = PosUi.pagePadding(context);
    return Container(
      padding: EdgeInsets.fromLTRB(pad.left, 18, pad.right, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppColors.surface,
            Color.lerp(AppColors.surface, _masterColor, 0.16)!,
          ],
        ),
        border: Border(bottom: BorderSide(color: AppColors.border)),
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
                    width: 36,
                    height: 36,
                    child: Icon(Icons.arrow_back, size: 20, color: AppColors.textPrimary),
                  ),
                ),
              ),
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(icon, size: 24, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(title),
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      tr('Device management'),
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (chips.isNotEmpty || action != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Wrap(spacing: 8, runSpacing: 8, children: chips)),
                if (action != null) ...[const SizedBox(width: 12), action!],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: AppColors.textPrimary),
              const SizedBox(width: 6),
              Text(
                tr(label),
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label, required this.color});

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
            style: GoogleFonts.ibmPlexSans(
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

class _ServerCard extends StatelessWidget {
  const _ServerCard({
    required this.running,
    required this.address,
    required this.error,
    required this.onCopy,
    required this.onToggle,
  });

  final bool running;
  final String address;
  final String? error;
  final VoidCallback onCopy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final color = running ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(running ? 'Server running' : 'Server stopped'),
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tr(running ? address : (error ?? 'Terminals cannot connect until the server is started.')),
                  style: GoogleFonts.ibmPlexMono(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (running)
            IconButton(
              tooltip: tr('Copy address'),
              onPressed: onCopy,
              icon: Icon(Icons.copy_rounded, size: 18, color: AppColors.textSecondary),
            ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onToggle,
            style: FilledButton.styleFrom(
              backgroundColor: running ? AppColors.danger : AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: Icon(running ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 18),
            label: Text(
              tr(running ? 'Stop' : 'Start'),
              style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.count, required this.onReview});

  final int count;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_outlined, size: 18, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tr(count == 1
                  ? '1 terminal is waiting for approval'
                  : '$count terminals are waiting for approval'),
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          TextButton(onPressed: onReview, child: Text(tr('Review'))),
        ],
      ),
    );
  }
}

class _PairingDialog extends StatefulWidget {
  const _PairingDialog();

  @override
  State<_PairingDialog> createState() => _PairingDialogState();
}

class _PairingDialogState extends State<_PairingDialog> {
  final _pairing = PairingService.instance;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    if (!_pairing.hasActiveCode && LocalMasterServer.instance.listening) {
      _pairing.refreshCode();
    }
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!_pairing.hasActiveCode && LocalMasterServer.instance.listening) {
        _pairing.refreshCode();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String _remaining() {
    final expires = _pairing.expiresAt;
    if (expires == null) return '—';
    final left = expires.difference(DateTime.now());
    if (left.isNegative) return '0:00';
    final seconds = (left.inSeconds % 60).toString().padLeft(2, '0');
    return '${left.inMinutes}:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: ListenableBuilder(
          listenable: Listenable.merge([_pairing, LocalMasterServer.instance]),
          builder: (context, _) {
            final payload = _pairing.masterQrPayload;
            final running = LocalMasterServer.instance.listening;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr('Pair a POS terminal'),
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ],
                  ),
                  Text(
                    tr('Scan this QR code from the POS terminal, or enter the 6-digit code.'),
                    style: GoogleFonts.ibmPlexSans(fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 18),
                  if (payload == null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        tr(running
                            ? 'No local network address found. Connect this device to Wi-Fi or a LAN cable to show the QR code.'
                            : 'Start the server to generate a pairing QR code.'),
                        style: GoogleFonts.ibmPlexSans(fontSize: 13, color: AppColors.textPrimary),
                      ),
                    )
                  else ...[
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppColors.elevationMd,
                        ),
                        child: BarcodeWidget(
                          barcode: Barcode.qrCode(),
                          data: payload.encode(),
                          width: 220,
                          height: 220,
                          drawText: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${payload.code.substring(0, 3)} ${payload.code.substring(3)}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 6,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${payload.name} · ${payload.hostEndpoint}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.timer_outlined, size: 15, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          trf('Expires in {0}', [_remaining()]),
                          style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.textMuted),
                        ),
                        const SizedBox(width: 10),
                        TextButton.icon(
                          onPressed: _pairing.refreshCode,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: Text(tr('New code')),
                        ),
                      ],
                    ),
                  ],
                  BlocBuilder<MasterPairingBloc, MasterPairingState>(
                    builder: (context, state) {
                      if (state.pendingRequests.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 16),
                          Text(
                            tr('Waiting for approval'),
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (final request in state.pendingRequests)
                            _PendingRequestTile(request: request),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PendingRequestTile extends StatelessWidget {
  const _PendingRequestTile({required this.request});

  final PairingRequest request;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (request.os.isNotEmpty) request.os,
      if (request.ip.isNotEmpty) request.ip,
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(request.wantsToConnectLabel),
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (details.isNotEmpty)
                  Text(
                    tr(details),
                    style: GoogleFonts.ibmPlexMono(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => context
                .read<MasterPairingBloc>()
                .add(MasterPairingRejectRequested(request.id)),
            child: Text(tr('Reject')),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => context
                .read<MasterPairingBloc>()
                .add(MasterPairingAcceptRequested(request.id)),
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            child: Text(tr('Accept')),
          ),
        ],
      ),
    );
  }
}

class _EmptyDevices extends StatelessWidget {
  const _EmptyDevices();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 44),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.devices_other_outlined, size: 44, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            tr('No registered devices'),
            style: GoogleFonts.ibmPlexSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr('Slave POS terminals will appear here once they connect'),
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _DeviceRoleCard extends StatelessWidget {
  const _DeviceRoleCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.features,
    required this.actionIcon,
    required this.actionLabel,
    required this.selected,
    required this.onAction,
    this.busy = false,
    this.fill = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final List<String> features;
  final IconData actionIcon;
  final String actionLabel;
  final bool selected;
  final VoidCallback onAction;
  final bool busy;

  /// Pushes the action button to the bottom; requires a bounded height.
  final bool fill;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.07) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? color : AppColors.border,
          width: selected ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, Color.lerp(color, Colors.black, 0.18)!],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 14),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const Spacer(),
              if (selected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tr('Current'),
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            tr(title),
            style: GoogleFonts.ibmPlexSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr(description),
            style: GoogleFonts.ibmPlexSans(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          for (final feature in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.check, size: 12, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tr(feature),
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 12.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (fill) const Spacer() else const SizedBox(height: 8),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: FilledButton.icon(
              onPressed: busy ? null : onAction,
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                disabledBackgroundColor: color.withValues(alpha: 0.6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(actionIcon, size: 16),
              label: Text(
                tr(actionLabel),
                style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
