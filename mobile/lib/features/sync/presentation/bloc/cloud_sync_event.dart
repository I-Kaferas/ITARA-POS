part of 'cloud_sync_bloc.dart';

sealed class CloudSyncEvent extends Equatable {
  const CloudSyncEvent();

  @override
  List<Object?> get props => const [];
}

final class CloudSyncStarted extends CloudSyncEvent {
  const CloudSyncStarted();
}

final class CloudSyncRefreshed extends CloudSyncEvent {
  const CloudSyncRefreshed();
}

/// Triggers a full Master → Cloud cycle.
final class CloudSyncRequested extends CloudSyncEvent {
  const CloudSyncRequested();
}
