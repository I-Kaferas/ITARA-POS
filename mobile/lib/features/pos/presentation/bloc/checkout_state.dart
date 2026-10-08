part of 'checkout_bloc.dart';

enum CheckoutStatus { initial, loading, ready, failure }

final class CheckoutState extends Equatable {
  const CheckoutState({
    this.status = CheckoutStatus.initial,
    this.errorMessage,
  });

  final CheckoutStatus status;
  final String? errorMessage;

  bool get isLoading => status == CheckoutStatus.loading;

  CheckoutState copyWith({
    CheckoutStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CheckoutState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
