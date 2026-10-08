import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'local_sync_event.dart';
part 'local_sync_state.dart';

class LocalSyncBloc extends Bloc<LocalSyncEvent, LocalSyncState> {
  LocalSyncBloc() : super(const LocalSyncState()) {
    on<LocalSyncStarted>(_onStarted);
    on<LocalSyncRefreshed>(_onRefreshed);
  }

  Future<void> _onStarted(
    LocalSyncStarted event,
    Emitter<LocalSyncState> emit,
  ) async {
    emit(state.copyWith(status: LocalSyncStatus.loading, clearError: true));
    emit(state.copyWith(status: LocalSyncStatus.ready));
  }

  Future<void> _onRefreshed(
    LocalSyncRefreshed event,
    Emitter<LocalSyncState> emit,
  ) async {
    add(const LocalSyncStarted());
  }
}
