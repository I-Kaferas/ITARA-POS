import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/network/network_bloc.dart';
import '../../../core/network/operating_mode.dart';
import '../../../core/theme/app_colors.dart';
import '../../../sync/sync_engine.dart';
import '../../../sync/sync_models.dart';

class SyncStatusBar extends StatelessWidget {
  const SyncStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NetworkBloc, NetworkState>(
      builder: (context, network) {
        return ListenableBuilder(
          listenable: SyncEngine.instance,
          builder: (context, _) {
            final snapshot = SyncEngine.instance.snapshot;
            final mode = network.mode;
            final waiting = snapshot.pending + snapshot.failed;
            final color = switch (mode) {
              OperatingMode.fullOnline => AppColors.success,
              OperatingMode.localOffline => AppColors.accent,
              OperatingMode.isolatedOffline =>
                snapshot.connectivity == ConnectivityState.syncError
                    ? AppColors.danger
                    : AppColors.warning,
            };
            final busy = snapshot.connectivity == ConnectivityState.syncing;

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
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        busy
                            ? 'Sync · Mode ${mode.code}'
                            : waiting == 0
                                ? 'Mode ${mode.code} · ${mode.shortLabel}'
                                : 'Mode ${mode.code} · $waiting en attente',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

