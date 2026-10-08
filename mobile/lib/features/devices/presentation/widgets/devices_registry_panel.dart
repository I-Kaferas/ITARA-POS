import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../sync/device_registry.dart';
import '../bloc/device_bloc.dart';

/// Master device list + §45 management actions (View / Rename / Disable / …).
class DevicesRegistryPanel extends StatelessWidget {
  const DevicesRegistryPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DeviceBloc, DeviceState>(
      listenWhen: (previous, current) =>
          current.message != null && current.message != previous.message,
      listener: (context, state) {
        final message = state.message;
        if (message == null || message.isEmpty) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
        );
      },
      builder: (context, deviceState) {
        final devices = deviceState.devices;
        if (devices.isEmpty) {
          return Text(
            'Aucun appareil appairé. Affichez le code ci-dessus sur les esclaves.',
            style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w600),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Devices (${devices.length})',
              style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...devices.map((d) => _DeviceRow(device: d)),
          ],
        );
      },
    );
  }
}

enum _DeviceAction {
  view,
  rename,
  disable,
  enable,
  remove,
  sync,
  reconnect,
  sendConfiguration,
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.device});

  final LanDevice device;

  Color get _statusColor => switch (device.status) {
        LanDeviceStatus.online => const Color(0xFF16A34A),
        LanDeviceStatus.idle || LanDeviceStatus.syncing => const Color(0xFFCA8A04),
        LanDeviceStatus.error || LanDeviceStatus.blocked => AppColors.danger,
        LanDeviceStatus.pending => const Color(0xFF2563EB),
        LanDeviceStatus.offline => AppColors.textMuted,
      };

  String get _osLabel {
    final raw = device.os.trim();
    if (raw.isEmpty) return '—';
    final lower = raw.toLowerCase();
    if (lower.contains('android')) return 'Android';
    if (lower.contains('windows') || lower == 'windows') return 'Windows';
    if (lower.contains('ios')) return 'iOS';
    if (lower.contains('macos') || lower.contains('mac')) return 'macOS';
    if (lower.contains('linux')) return 'Linux';
    if (raw.length == 1) return raw.toUpperCase();
    return raw[0].toUpperCase() + raw.substring(1);
  }

  String get _statusLabel => switch (device.status) {
        LanDeviceStatus.online => 'En ligne',
        LanDeviceStatus.idle => 'Inactif',
        LanDeviceStatus.syncing => 'Sync…',
        LanDeviceStatus.offline => 'Hors ligne',
        LanDeviceStatus.error => 'Erreur',
        LanDeviceStatus.blocked => 'Désactivé',
        LanDeviceStatus.pending => 'En attente',
      };

  Future<void> _onAction(BuildContext context, _DeviceAction action) async {
    final bloc = context.read<DeviceBloc>();
    switch (action) {
      case _DeviceAction.view:
        await _showDetails(context);
      case _DeviceAction.rename:
        final name = await _promptRename(context);
        if (name == null || name.isEmpty) return;
        bloc.add(DeviceRenameRequested(deviceId: device.id, name: name));
      case _DeviceAction.disable:
        final ok = await _confirm(
          context,
          title: 'Désactiver ${device.name} ?',
          body: 'L’appareil restera enregistré mais ne pourra plus synchroniser.',
        );
        if (ok) bloc.add(DeviceDisableRequested(device.id));
      case _DeviceAction.enable:
        bloc.add(DeviceEnableRequested(device.id));
      case _DeviceAction.remove:
        final ok = await _confirm(
          context,
          title: 'Retirer ${device.name} ?',
          body: 'L’appareil sera supprimé du registre Master.',
          destructive: true,
        );
        if (ok) bloc.add(DeviceRemoveRequested(device.id));
      case _DeviceAction.sync:
        bloc.add(DeviceSyncRequested(device.id));
      case _DeviceAction.reconnect:
        bloc.add(DeviceReconnectRequested(device.id));
      case _DeviceAction.sendConfiguration:
        bloc.add(DeviceSendConfigurationRequested(device.id));
    }
  }

  Future<void> _showDetails(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(device.name.isEmpty ? device.id : device.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detail('ID', device.id),
            _detail('Type', device.deviceType),
            _detail('OS', _osLabel),
            _detail('IP', device.ip.isEmpty ? '—' : device.ip),
            _detail('Rôle', device.role),
            _detail('Utilisateur', device.userName.isEmpty ? '—' : device.userName),
            _detail('Version', device.version.isEmpty ? '—' : device.version),
            _detail('Statut', _statusLabel),
            _detail('Dernière activité', _formatWhen(device.lastSeen)),
            _detail('Appairé', device.pairedAt == null ? '—' : _formatWhen(device.pairedAt!)),
            _detail('Approuvé', device.approved ? 'Oui' : 'Non'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _promptRename(BuildContext context) async {
    final controller = TextEditingController(text: device.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renommer'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nom de l’appareil',
            hintText: 'POS-01',
          ),
          onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: destructive
                ? TextButton.styleFrom(foregroundColor: AppColors.danger)
                : null,
            child: Text(destructive ? 'Retirer' : 'Confirmer'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  String _formatWhen(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (device.userName.isNotEmpty) device.userName,
      if (device.role.isNotEmpty) device.role,
      if (device.version.isNotEmpty) 'v${device.version}',
      if (device.ip.isNotEmpty) device.ip,
    ].join(' · ');
    final disabled = device.status == LanDeviceStatus.blocked || !device.approved;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _onAction(context, _DeviceAction.view),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(Icons.circle, size: 10, color: _statusColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              device.name.isEmpty ? device.id : device.name,
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 72,
                            child: Text(
                              _osLabel,
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Icon(Icons.circle, size: 10, color: _statusColor),
                        ],
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<_DeviceAction>(
                  tooltip: 'Actions',
                  onSelected: (action) => _onAction(context, action),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: _DeviceAction.view,
                      child: Text('View'),
                    ),
                    const PopupMenuItem(
                      value: _DeviceAction.rename,
                      child: Text('Rename'),
                    ),
                    if (disabled)
                      const PopupMenuItem(
                        value: _DeviceAction.enable,
                        child: Text('Enable'),
                      )
                    else
                      const PopupMenuItem(
                        value: _DeviceAction.disable,
                        child: Text('Disable'),
                      ),
                    const PopupMenuItem(
                      value: _DeviceAction.remove,
                      child: Text('Remove'),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: _DeviceAction.sync,
                      child: Text('Sync'),
                    ),
                    const PopupMenuItem(
                      value: _DeviceAction.reconnect,
                      child: Text('Reconnect'),
                    ),
                    const PopupMenuItem(
                      value: _DeviceAction.sendConfiguration,
                      child: Text('Send Configuration'),
                    ),
                  ],
                  icon: const Icon(Icons.more_vert, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
