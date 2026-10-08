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
