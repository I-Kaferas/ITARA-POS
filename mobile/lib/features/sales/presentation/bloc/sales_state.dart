part of 'sales_bloc.dart';

enum SalesStatus { initial, loading, ready, failure }

final class SalesState extends Equatable {
  const SalesState({
    this.status = SalesStatus.initial,
    this.errorMessage,
  });

  final SalesStatus status;
  final String? errorMessage;

  bool get isLoading => status == SalesStatus.loading;

  SalesState copyWith({
    SalesStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SalesState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
