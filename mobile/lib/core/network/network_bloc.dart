import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../sync/local_master_discovery.dart';
import '../../sync/local_master_server.dart';
import '../../sync/sync_engine.dart';
import '../config/terminal_config.dart';
import '../config/terminal_config_repository.dart';
import '../logging/app_logger.dart';
import 'network_status.dart';
import 'operating_mode.dart';
import 'operation_router.dart';

part 'network_event.dart';
part 'network_state.dart';

/// Dérive [NetworkStatus] §17 + [OperatingMode] A/B/C depuis SyncEngine / Master.
class NetworkBloc extends Bloc<NetworkEvent, NetworkState> {
  NetworkBloc({
    required SyncEngine syncEngine,
    required LocalMasterDiscovery discovery,
    required LocalMasterServer masterServer,
    required TerminalConfigRepository configRepository,
    required AppLogger logger,
  })  : _syncEngine = syncEngine,
        _discovery = discovery,
        _masterServer = masterServer,
        _configRepository = configRepository,
        _log = logger.tagged('network'),
        super(const NetworkState()) {
    _syncEngine.addListener(_onChanged);
    _discovery.addListener(_onChanged);
    _masterServer.addListener(_onChanged);
    _configRepository.addListener(_onChanged);
    on<NetworkSynced>(_onSynced);
    on<NetworkRefreshRequested>(_onRefresh);
    add(const NetworkSynced());
  }

  final SyncEngine _syncEngine;
  final LocalMasterDiscovery _discovery;
  final LocalMasterServer _masterServer;
  final TerminalConfigRepository _configRepository;
  final AppLogger _log;

  void _onChanged() => add(const NetworkSynced());

  void _onRefresh(
    NetworkRefreshRequested event,
    Emitter<NetworkState> emit,
  ) {
    add(const NetworkSynced());
  }

  void _onSynced(
    NetworkSynced event,
    Emitter<NetworkState> emit,
  ) {
    final config = _configRepository.config;
    final role = config.posRole;

    final masterReachable = switch (role) {
      PosRole.master => _masterServer.listening,
      PosRole.slave => _syncEngine.masterReachable,
      PosRole.standalone => false,
    };
    final internet = _syncEngine.cloudReachable;
    final lanPeers = _discovery.visible.isNotEmpty;
    final lanVisible = !masterReachable &&
        (lanPeers || (role == PosRole.master && _masterServer.listening));

    final status = NetworkStatus.resolve(
      masterReachable: masterReachable,
      internetReachable: internet,
      lanVisible: lanVisible,
    );

    final mode = OperatingModeResolver.resolve(
      role: role,
      masterReachable: masterReachable,
      cloudReachable: internet,
    );

    final next = NetworkState(
      status: status,
      mode: mode,
      masterReachable: masterReachable,
      internetReachable: internet,
      lanVisible: lanVisible,
      role: role,
    );
    if (next != state) {
      _log.debug(
        '${status.wire} mode=${mode.code} master=$masterReachable '
        'cloud=$internet lan=$lanVisible',
      );
      emit(next);
    }
  }

  @override
  Future<void> close() {
    _syncEngine.removeListener(_onChanged);
    _discovery.removeListener(_onChanged);
    _masterServer.removeListener(_onChanged);
    _configRepository.removeListener(_onChanged);
    return super.close();
  }
}
