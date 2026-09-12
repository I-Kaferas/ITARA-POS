import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../sync/sync_engine.dart';
import '../../../sync/sync_models.dart';

class SyncStatusBar extends StatelessWidget {
  const SyncStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SyncEngine.instance,
      builder: (context, _) {
        final snapshot = SyncEngine.instance.snapshot;
        final waiting = snapshot.pending + snapshot.failed;
        final color = switch (snapshot.connectivity) {
          ConnectivityState.online ||
          ConnectivityState.cloudAvailable ||
          ConnectivityState.localAvailable =>
            AppColors.success,
          ConnectivityState.syncing => AppColors.accent,
          ConnectivityState.syncError => AppColors.danger,
          _ => AppColors.textMuted,
        };

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.go(AppRoutes.sync),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: color.withValues(alpha: 0.28)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    waiting == 0 ? snapshot.label : '${snapshot.label} · $waiting en attente',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
