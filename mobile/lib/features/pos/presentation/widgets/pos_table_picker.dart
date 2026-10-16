import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../hospitality/data/hospitality_api.dart';
import '../../../hospitality/domain/restaurant_models.dart';

class PosTableChoice {
  const PosTableChoice(this.id, this.label);

  /// Returned when the cashier removes the table from the order.
  static const none = PosTableChoice('', '');

  final String id;
  final String label;

  bool get isNone => id.isEmpty;
}

/// Lets the cashier attach a restaurant table to the current order.
/// Returns null when dismissed, [PosTableChoice.none] to clear the table.
/// [busyIds] are tables already taken by held sales on this terminal.
Future<PosTableChoice?> showPosTablePicker(
  BuildContext context, {
  String? selectedId,
  Set<String> busyIds = const {},
}) {
  return showDialog<PosTableChoice>(
    context: context,
    builder: (_) => _TablePickerDialog(selectedId: selectedId, busyIds: busyIds),
  );
}

class _TablePickerDialog extends StatefulWidget {
  const _TablePickerDialog({this.selectedId, this.busyIds = const {}});

  final String? selectedId;
  final Set<String> busyIds;

  @override
  State<_TablePickerDialog> createState() => _TablePickerDialogState();
}

class _TablePickerDialogState extends State<_TablePickerDialog> {
  late Future<List<_Zone>> _zones = _load();

  Future<List<_Zone>> _load() async {
    final snapshot = await HospitalityApi().snapshot();
    final docs = (snapshot['docs'] as List? ?? const [])
        .whereType<Map>()
        .map((doc) => Map<String, dynamic>.from(doc))
        .toList();
    final zoneNames = {
      for (final doc in docs.where((d) => d['kind'] == 'zone'))
        doc['id'].toString(): doc['name']?.toString() ?? doc['label']?.toString() ?? 'Zone',
    };
    final byZone = <String, List<_Table>>{};
    for (final doc in docs.where((d) => d['kind'] == 'table')) {
      final zoneId = doc['zone_id']?.toString() ?? '';
      byZone.putIfAbsent(zoneId, () => []).add(
            _Table(
              id: doc['id'].toString(),
              label: doc['label']?.toString() ?? doc['name']?.toString() ?? doc['id'].toString(),
              seats: int.tryParse(doc['seats']?.toString() ?? ''),
              status: RestaurantStatus.fromWire(doc['status']?.toString()),
            ),
          );
    }
    return [
      for (final entry in byZone.entries)
        _Zone(zoneNames[entry.key] ?? 'Autres tables', entry.value),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = widget.selectedId != null && widget.selectedId!.isNotEmpty;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      title: Row(
        children: [
          const Icon(Icons.table_restaurant_outlined, color: AppColors.cashierBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Choisir une table',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () => setState(() => _zones = _load()),
            icon: Icon(Icons.refresh, color: AppColors.textSecondary),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: FutureBuilder<List<_Zone>>(
          future: _zones,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return _Message(
                icon: Icons.cloud_off_outlined,
                text: snapshot.error.toString().replaceFirst('Exception: ', ''),
              );
            }
            final zones = snapshot.data ?? const [];
            if (zones.isEmpty) {
              return const _Message(
                icon: Icons.table_restaurant_outlined,
                text: 'Aucune table configurée.',
              );
            }
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final zone in zones) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: Text(
                        zone.name.toUpperCase(),
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 11.5,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final table in zone.tables)
                          _TableTile(
                            table: table,
                            selected: table.id == widget.selectedId,
                            busy: table.status.isActive || widget.busyIds.contains(table.id),
                            onTap: () => Navigator.of(context).pop(PosTableChoice(table.id, table.label)),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        if (hasSelection)
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(PosTableChoice.none),
            icon: const Icon(Icons.close, size: 16, color: AppColors.danger),
            label: const Text('Retirer la table', style: TextStyle(color: AppColors.danger)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
      ],
    );
  }
}

class _Zone {
  const _Zone(this.name, this.tables);

  final String name;
  final List<_Table> tables;
}

class _Table {
  const _Table({required this.id, required this.label, required this.seats, required this.status});

  final String id;
  final String label;
  final int? seats;
  final RestaurantStatus status;
}

class _TableTile extends StatelessWidget {
  const _TableTile({
    required this.table,
    required this.selected,
    required this.busy,
    required this.onTap,
  });

  final _Table table;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locked = busy && !selected;
    final tone = selected
        ? AppColors.cashierBlue
        : busy
            ? AppColors.danger
            : AppColors.success;
    final status = table.status.isActive
        ? table.status.label
        : busy
            ? RestaurantStatus.occupied.label
            : table.status.label;
    final tile = Material(
      color: tone.withValues(alpha: selected ? 0.16 : 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: locked ? null : onTap,
        mouseCursor: locked ? SystemMouseCursors.forbidden : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 96,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tone.withValues(alpha: selected ? 0.9 : 0.35), width: selected ? 2 : 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (locked) ...[
                    Icon(Icons.lock_outline_rounded, size: 14, color: tone),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      table.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: locked ? AppColors.textSecondary : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                [
                  tr(status),
                  if (table.seats != null) '${table.seats} pl.',
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.ibmPlexSans(fontSize: 11, color: tone, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
    return locked ? Tooltip(message: tr('Table occupée'), child: tile) : tile;
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: AppColors.textMuted),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSans(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
