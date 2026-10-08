part of 'local_sync_bloc.dart';

sealed class LocalSyncEvent extends Equatable {
  const LocalSyncEvent();

  @override
  List<Object?> get props => const [];
}

final class LocalSyncStarted extends LocalSyncEvent {
  const LocalSyncStarted();
}

final class LocalSyncRefreshed extends LocalSyncEvent {
  const LocalSyncRefreshed();
}
