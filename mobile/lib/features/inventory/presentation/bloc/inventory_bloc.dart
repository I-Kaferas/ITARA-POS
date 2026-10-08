import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'inventory_event.dart';
part 'inventory_state.dart';

class InventoryBloc extends Bloc<InventoryEvent, InventoryState> {
  InventoryBloc() : super(const InventoryState()) {
    on<InventoryStarted>(_onStarted);
    on<InventoryRefreshed>(_onRefreshed);
  }

  Future<void> _onStarted(
    InventoryStarted event,
    Emitter<InventoryState> emit,
  ) async {
    emit(state.copyWith(status: InventoryStatus.loading, clearError: true));
    emit(state.copyWith(status: InventoryStatus.ready));
  }

  Future<void> _onRefreshed(
    InventoryRefreshed event,
    Emitter<InventoryState> emit,
  ) async {
    add(const InventoryStarted());
  }
}
