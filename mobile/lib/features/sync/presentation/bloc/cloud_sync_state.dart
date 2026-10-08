part of 'cloud_sync_bloc.dart';

enum CloudSyncStatus { initial, loading, syncing, ready, failure }

final class CloudSyncState extends Equatable {
  const CloudSyncState({
    this.status = CloudSyncStatus.initial,
    this.errorMessage,
    this.cloudReachable = false,
    this.allowed = false,
    this.lastReport,
    this.entities = const [],
  });

  final CloudSyncStatus status;
  final String? errorMessage;
  final bool cloudReachable;
  final bool allowed;
  final CloudSyncReport? lastReport;
  final List<CloudSyncEntity> entities;

  bool get isLoading =>
      status == CloudSyncStatus.loading || status == CloudSyncStatus.syncing;

  CloudSyncState copyWith({
    CloudSyncStatus? status,
    String? errorMessage,
    bool clearError = false,
    bool? cloudReachable,
    bool? allowed,
    CloudSyncReport? lastReport,
    List<CloudSyncEntity>? entities,
  }) {
    return CloudSyncState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      cloudReachable: cloudReachable ?? this.cloudReachable,
      allowed: allowed ?? this.allowed,
      lastReport: lastReport ?? this.lastReport,
      entities: entities ?? this.entities,
    );
  }

  @override
  List<Object?> get props => [
        status,
        errorMessage,
        cloudReachable,
        allowed,
        lastReport,
        entities,
      ];
}
