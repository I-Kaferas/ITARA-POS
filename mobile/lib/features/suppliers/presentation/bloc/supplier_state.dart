part of 'supplier_bloc.dart';

enum SupplierStatus { initial, loading, ready, failure }

final class SupplierState extends Equatable {
  const SupplierState({
    this.status = SupplierStatus.initial,
    this.errorMessage,
  });

  final SupplierStatus status;
  final String? errorMessage;

  bool get isLoading => status == SupplierStatus.loading;

  SupplierState copyWith({
    SupplierStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SupplierState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
