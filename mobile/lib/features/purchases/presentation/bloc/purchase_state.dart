part of 'purchase_bloc.dart';

enum PurchaseStatus { initial, loading, ready, failure }

final class PurchaseState extends Equatable {
  const PurchaseState({
    this.status = PurchaseStatus.initial,
    this.errorMessage,
  });

  final PurchaseStatus status;
  final String? errorMessage;

  bool get isLoading => status == PurchaseStatus.loading;

  PurchaseState copyWith({
    PurchaseStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PurchaseState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
