import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../sync/cloud/cloud_sync_engine.dart';
import '../../../../sync/cloud/cloud_sync_entity.dart';
import '../../../../sync/cloud/cloud_sync_report.dart';

part 'cloud_sync_event.dart';
part 'cloud_sync_state.dart';

class CloudSyncBloc extends Bloc<CloudSyncEvent, CloudSyncState> {
  CloudSyncBloc({CloudSyncEngine? engine})
      : _engine = engine ?? CloudSyncEngine.instance,
        super(const CloudSyncState()) {
    on<CloudSyncStarted>(_onStarted);
    on<CloudSyncRefreshed>(_onRefreshed);
    on<CloudSyncRequested>(_onRequested);
  }

  final CloudSyncEngine _engine;

  Future<void> _onStarted(
    CloudSyncStarted event,
    Emitter<CloudSyncState> emit,
  ) async {
    emit(state.copyWith(status: CloudSyncStatus.loading, clearError: true));
    final reachable = await _engine.probe();
    emit(state.copyWith(
      status: CloudSyncStatus.ready,
      cloudReachable: reachable,
      allowed: _engine.isAllowed,
      lastReport: _engine.lastReport,
      entities: CloudSyncEntity.values,
    ));
  }

  Future<void> _onRefreshed(
    CloudSyncRefreshed event,
    Emitter<CloudSyncState> emit,
  ) async {
    add(const CloudSyncStarted());
  }

  Future<void> _onRequested(
    CloudSyncRequested event,
    Emitter<CloudSyncState> emit,
  ) async {
    emit(state.copyWith(status: CloudSyncStatus.syncing, clearError: true));
    final report = await _engine.syncNow();
    emit(state.copyWith(
      status: report.ok ? CloudSyncStatus.ready : CloudSyncStatus.failure,
      cloudReachable: report.cloudReachable,
      allowed: _engine.isAllowed,
      lastReport: report,
      errorMessage: report.ok ? null : report.message,
      clearError: report.ok,
      entities: CloudSyncEntity.values,
    ));
  }
}
