import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/pos_health_probe.dart';
import '../domain/pos_health.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

class PosHealthCard extends StatefulWidget {
  const PosHealthCard({super.key});

  @override
  State<PosHealthCard> createState() => _PosHealthCardState();
}

class _PosHealthCardState extends State<PosHealthCard> {
  PosHealth? _health;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final health = await PosHealthProbe.read();
      if (!mounted) return;
      setState(() => _health = health);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _health = PosHealth.resolve(
          databaseOpen: false,
          isMaster: false,
          masterReachable: false,
          internetReachable: false,
          cloudReachable: false,
          printersKnown: 0,
          printersOnline: 0,
          syncFailed: 0,
          syncPending: 0,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final health = _health;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('État du terminal'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (health == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(),
              )
            else
              for (final row in health.rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(_icon(row.level), size: 16, color: _color(row.level)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(tr(row.label))),
                      Text(tr(_caption(row.level)), style: TextStyle(color: _color(row.level))),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  IconData _icon(HealthLevel level) => switch (level) {
        HealthLevel.ok => Icons.check_circle,
        HealthLevel.warn => Icons.error_outline,
        HealthLevel.down => Icons.cancel,
      };

  Color _color(HealthLevel level) => switch (level) {
        HealthLevel.ok => AppColors.success,
        HealthLevel.warn => AppColors.accent,
        HealthLevel.down => AppColors.danger,
      };

  String _caption(HealthLevel level) => switch (level) {
        HealthLevel.ok => 'En ligne',
        HealthLevel.warn => 'À vérifier',
        HealthLevel.down => 'Indisponible',
      };
}
