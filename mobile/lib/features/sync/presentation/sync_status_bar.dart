import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/network/network_bloc.dart';
import '../../../core/network/operating_mode.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../sync/sync_engine.dart';
import '../../../sync/sync_models.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

class _SyncMark extends StatefulWidget {
  const _SyncMark({required this.color, required this.busy});

  final Color color;
  final bool busy;

  @override
  State<_SyncMark> createState() => _SyncMarkState();
}

class _SyncMarkState extends State<_SyncMark> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _follow();
  }

  @override
  void didUpdateWidget(covariant _SyncMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    _follow();
  }

  void _follow() {
    final spin = widget.busy && !AppMotion.reduceMotion(context);
    if (spin) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );
    if (!widget.busy) return dot;
    return RotationTransition(
      turns: _controller,
      child: Icon(Icons.sync_rounded, size: 14, color: widget.color),
    );
  }
}

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
                      _SyncMark(color: color, busy: busy),
                      const SizedBox(width: 6),
                      Text(
                        tr(busy
                            ? 'Sync · Mode ${mode.code}'
                            : waiting == 0
                                ? 'Mode ${mode.code} · ${mode.shortLabel}'
                                : 'Mode ${mode.code} · $waiting en attente'),
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

