import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../pos/domain/pos_models.dart';
import '../../data/inventory_repository.dart';
import '../../domain/inventory_movement_type.dart';
import '../../domain/inventory_posting.dart';
import '../../domain/unit_converter.dart';

part 'inventory_event.dart';
part 'inventory_state.dart';

class InventoryBloc extends Bloc<InventoryEvent, InventoryState> {
  InventoryBloc({InventoryRepository? repository})
      : _repository = repository ?? InventoryRepository.instance,
        super(const InventoryState()) {
    on<InventoryStarted>(_onStarted);
    on<InventoryRefreshed>(_onRefreshed);
    on<InventoryQueryChanged>((event, emit) => emit(state.copyWith(query: event.query)));
    on<InventoryMovementSubmitted>(_onMovement);
    on<InventoryTransferSubmitted>(_onTransfer);
    on<InventoryFeedbackCleared>(
      (event, emit) => emit(state.copyWith(clearMessage: true, clearError: true)),
    );
  }

  final InventoryRepository _repository;

  Future<void> _onStarted(
    InventoryStarted event,
    Emitter<InventoryState> emit,
  ) async {
    emit(state.copyWith(status: InventoryStatus.loading, clearError: true));
    await _reload(emit);
  }

  Future<void> _onRefreshed(
    InventoryRefreshed event,
    Emitter<InventoryState> emit,
  ) =>
      _reload(emit);

  Future<void> _reload(Emitter<InventoryState> emit) async {
    try {
      final products = await _repository.products();
      final warehouses = await _repository.warehouses();
      final history = await _repository.history(limit: 60);
      emit(state.copyWith(
        status: InventoryStatus.ready,
        products: products,
        warehouses: warehouses,
        history: history,
      ));
    } catch (error) {
      emit(state.copyWith(status: InventoryStatus.failure, errorMessage: error.toString()));
    }
  }

  Future<void> _onMovement(
    InventoryMovementSubmitted event,
    Emitter<InventoryState> emit,
  ) async {
    emit(state.copyWith(submitting: true, clearError: true, clearMessage: true));
    try {
      final posting = await _repository.record(
        product: event.product,
        type: event.type,
        quantity: event.quantity,
        unit: event.unit,
        warehouseId: event.warehouseId,
        reason: event.reason,
      );
      await _reload(emit);
      emit(state.copyWith(
        submitting: false,
        message: '${event.type.label} · ${event.product.name} '
            '${posting.signedQuantity > 0 ? '+' : ''}${posting.signedQuantity}',
      ));
    } catch (error) {
      emit(state.copyWith(submitting: false, errorMessage: error.toString()));
    }
  }

  Future<void> _onTransfer(
    InventoryTransferSubmitted event,
    Emitter<InventoryState> emit,
  ) async {
    emit(state.copyWith(submitting: true, clearError: true, clearMessage: true));
    try {
      final legs = await _repository.transfer(
        product: event.product,
        quantity: event.quantity,
        unit: event.unit,
        sourceWarehouseId: event.sourceWarehouseId,
        destinationWarehouseId: event.destinationWarehouseId,
        reason: event.reason,
      );
      await _reload(emit);
      emit(state.copyWith(
        submitting: false,
        message: 'Transfert · ${event.product.name} ${legs.first.signedQuantity.abs()}',
      ));
    } catch (error) {
      emit(state.copyWith(submitting: false, errorMessage: error.toString()));
    }
  }
}
