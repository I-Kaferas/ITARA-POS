import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/terminal_config_repository.dart';
import '../../../../sync/local_master_server.dart';
import '../../../../sync/sync_engine.dart';
import '../../../../sync/sync_models.dart';

part 'master_connection_event.dart';
part 'master_connection_state.dart';

class MasterConnectionBloc
    extends Bloc<MasterConnectionEvent, MasterConnectionState> {
  MasterConnectionBloc({
    required SyncEngine syncEngine,
    required LocalMasterServer masterServer,
    required TerminalConfigRepository configRepository,
  })  : _sync = syncEngine,
        _master = masterServer,
        _config = configRepository,
        super(const MasterConnectionState()) {
    _sync.addListener(_onChanged);
    _master.addListener(_onChanged);
    _config.addListener(_onChanged);
    on<MasterConnectionSynced>(_onSynced);
    add(const MasterConnectionSynced());
  }

  final SyncEngine _sync;
  final LocalMasterServer _master;
  final TerminalConfigRepository _config;

  void _onChanged() => add(const MasterConnectionSynced());

  void _onSynced(
    MasterConnectionSynced event,
    Emitter<MasterConnectionState> emit,
  ) {
    final config = _config.config;
    if (config.isMaster) {
      emit(MasterConnectionState(
        status: _master.listening
            ? MasterConnectionStatus.connectedLocal
            : MasterConnectionStatus.disconnected,
        activeTarget: _master.advertiseUrl,
        errorMessage: _master.lastError,
      ));
      return;
    }

    final target = _sync.activeTarget;
    final connectivity = _sync.connectivity;
    if (target == null) {
      emit(MasterConnectionState(
        status: connectivity == ConnectivityState.offline
            ? MasterConnectionStatus.disconnected
            : MasterConnectionStatus.searching,
        errorMessage: _sync.lastError,
      ));
      return;
    }

    final local = LocalMasterServer.clientBaseUrl();
    final isLocal = local != null && target == local;
    emit(MasterConnectionState(
      status: isLocal
          ? MasterConnectionStatus.connectedLocal
          : MasterConnectionStatus.connectedCloud,
      activeTarget: target,
      errorMessage: _sync.lastError,
    ));
  }

  @override
  Future<void> close() {
    _sync.removeListener(_onChanged);
    _master.removeListener(_onChanged);
    _config.removeListener(_onChanged);
    return super.close();
  }
}
