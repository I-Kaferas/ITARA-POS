part of 'payment_bloc.dart';

enum PaymentStatus { initial, loading, ready, failure }

final class PaymentState extends Equatable {
  const PaymentState({
    this.status = PaymentStatus.initial,
    this.errorMessage,
  });

  final PaymentStatus status;
  final String? errorMessage;

  bool get isLoading => status == PaymentStatus.loading;

  PaymentState copyWith({
    PaymentStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PaymentState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
