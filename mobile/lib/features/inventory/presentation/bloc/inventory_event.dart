part of 'inventory_bloc.dart';

sealed class InventoryEvent extends Equatable {
  const InventoryEvent();

  @override
  List<Object?> get props => const [];
}

final class InventoryStarted extends InventoryEvent {
  const InventoryStarted();
}

final class InventoryRefreshed extends InventoryEvent {
  const InventoryRefreshed();
}

final class InventoryQueryChanged extends InventoryEvent {
  const InventoryQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

final class InventoryMovementSubmitted extends InventoryEvent {
  const InventoryMovementSubmitted({
    required this.product,
    required this.type,
    required this.quantity,
    this.unit,
    this.warehouseId,
    this.reason,
  });

  final PosProduct product;
  final InventoryMovementType type;
  final num quantity;
  final InventoryUnit? unit;
  final String? warehouseId;
  final String? reason;

  @override
  List<Object?> get props => [product.productId, type, quantity, unit?.id, warehouseId, reason];
}

final class InventoryTransferSubmitted extends InventoryEvent {
  const InventoryTransferSubmitted({
    required this.product,
    required this.quantity,
    required this.sourceWarehouseId,
    required this.destinationWarehouseId,
    this.unit,
    this.reason,
  });

  final PosProduct product;
  final num quantity;
  final String sourceWarehouseId;
  final String destinationWarehouseId;
  final InventoryUnit? unit;
  final String? reason;

  @override
  List<Object?> get props => [product.productId, quantity, sourceWarehouseId, destinationWarehouseId, unit?.id];
}

final class InventoryFeedbackCleared extends InventoryEvent {
  const InventoryFeedbackCleared();
}
