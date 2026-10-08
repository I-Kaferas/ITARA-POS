part of 'inventory_bloc.dart';

enum InventoryStatus { initial, loading, ready, failure }

final class InventoryState extends Equatable {
  const InventoryState({
    this.status = InventoryStatus.initial,
    this.errorMessage,
  });

  final InventoryStatus status;
  final String? errorMessage;

  bool get isLoading => status == InventoryStatus.loading;

  InventoryState copyWith({
    InventoryStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return InventoryState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
