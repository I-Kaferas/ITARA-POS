import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../sync/local_master_discovery.dart';

part 'master_discovery_event.dart';
part 'master_discovery_state.dart';

class MasterDiscoveryBloc extends Bloc<MasterDiscoveryEvent, MasterDiscoveryState> {
  MasterDiscoveryBloc(this._discovery)
      : super(MasterDiscoveryState(
          masters: _discovery.visible,
          searching: _discovery.searching,
          statusMessage: _discovery.statusMessage,
        )) {
    _discovery.addListener(_onDiscoveryChanged);
    on<MasterDiscoveryStarted>(_onStarted);
    on<MasterDiscoverySearchRequested>(_onSearch);
    on<MasterDiscoveryStopped>(_onStopped);
    on<MasterDiscoverySynced>(_onSynced);
  }

  final LocalMasterDiscovery _discovery;

  void _onDiscoveryChanged() => add(const MasterDiscoverySynced());

  Future<void> _onStarted(
    MasterDiscoveryStarted event,
    Emitter<MasterDiscoveryState> emit,
  ) async {
    await _discovery.start();
  }

  Future<void> _onSearch(
    MasterDiscoverySearchRequested event,
    Emitter<MasterDiscoveryState> emit,
  ) async {
    await _discovery.searchNow();
  }

  void _onStopped(
    MasterDiscoveryStopped event,
    Emitter<MasterDiscoveryState> emit,
  ) {
    _discovery.stop();
  }

  void _onSynced(
    MasterDiscoverySynced event,
    Emitter<MasterDiscoveryState> emit,
  ) {
    emit(MasterDiscoveryState(
      masters: _discovery.visible,
      searching: _discovery.searching,
      statusMessage: _discovery.statusMessage,
    ));
  }

  @override
  Future<void> close() {
    _discovery.removeListener(_onDiscoveryChanged);
    return super.close();
  }
}
