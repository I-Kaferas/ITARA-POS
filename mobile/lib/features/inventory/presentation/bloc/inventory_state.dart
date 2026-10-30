part of 'inventory_bloc.dart';

enum InventoryStatus { initial, loading, ready, failure }

final class InventoryState extends Equatable {
  const InventoryState({
    this.status = InventoryStatus.initial,
    this.products = const [],
    this.warehouses = const [],
    this.history = const [],
    this.query = '',
    this.submitting = false,
    this.message,
    this.errorMessage,
  });

  final InventoryStatus status;
  final List<PosProduct> products;
  final List<InventoryWarehouse> warehouses;
  final List<InventoryMovementRecord> history;
  final String query;
  final bool submitting;

  /// One-shot confirmation shown after a movement.
  final String? message;
  final String? errorMessage;

  bool get isLoading => status == InventoryStatus.loading;

  bool get canTransfer => warehouses.length > 1;

  List<PosProduct> get filtered {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return products;
    return products
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.sku.toLowerCase().contains(q) ||
            p.matchesBarcode(query.trim()))
        .toList();
  }

  int get lowStockCount => products.where((p) {
        final threshold = p.lowStockThreshold ?? 0;
        return threshold > 0 && (p.quantityOnHand ?? 0) <= threshold;
      }).length;

  InventoryState copyWith({
    InventoryStatus? status,
    List<PosProduct>? products,
    List<InventoryWarehouse>? warehouses,
    List<InventoryMovementRecord>? history,
    String? query,
    bool? submitting,
    String? message,
    String? errorMessage,
    bool clearError = false,
    bool clearMessage = false,
  }) {
    return InventoryState(
      status: status ?? this.status,
      products: products ?? this.products,
      warehouses: warehouses ?? this.warehouses,
      history: history ?? this.history,
      query: query ?? this.query,
      submitting: submitting ?? this.submitting,
      message: clearMessage ? null : (message ?? this.message),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, products, warehouses, history, query, submitting, message, errorMessage];
}
