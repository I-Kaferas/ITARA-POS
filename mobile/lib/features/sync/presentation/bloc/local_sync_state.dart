part of 'local_sync_bloc.dart';

enum LocalSyncStatus { initial, loading, ready, failure }

final class LocalSyncState extends Equatable {
  const LocalSyncState({
    this.status = LocalSyncStatus.initial,
    this.errorMessage,
  });

  final LocalSyncStatus status;
  final String? errorMessage;

  bool get isLoading => status == LocalSyncStatus.loading;

  LocalSyncState copyWith({
    LocalSyncStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LocalSyncState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
