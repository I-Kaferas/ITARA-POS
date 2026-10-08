part of 'customer_bloc.dart';

enum CustomerStatus { initial, loading, ready, failure }

final class CustomerState extends Equatable {
  const CustomerState({
    this.status = CustomerStatus.initial,
    this.errorMessage,
  });

  final CustomerStatus status;
  final String? errorMessage;

  bool get isLoading => status == CustomerStatus.loading;

  CustomerState copyWith({
    CustomerStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CustomerState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
