part of 'conflict_resolution_bloc.dart';

enum ConflictResolutionStatus { initial, loading, ready, failure }

final class ConflictResolutionState extends Equatable {
  const ConflictResolutionState({
    this.status = ConflictResolutionStatus.initial,
    this.errorMessage,
  });

  final ConflictResolutionStatus status;
  final String? errorMessage;

  bool get isLoading => status == ConflictResolutionStatus.loading;

  ConflictResolutionState copyWith({
    ConflictResolutionStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ConflictResolutionState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
