part of 'refund_bloc.dart';

enum RefundStatus { initial, loading, ready, failure }

final class RefundState extends Equatable {
  const RefundState({
    this.status = RefundStatus.initial,
    this.errorMessage,
  });

  final RefundStatus status;
  final String? errorMessage;

  bool get isLoading => status == RefundStatus.loading;

  RefundState copyWith({
    RefundStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RefundState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
