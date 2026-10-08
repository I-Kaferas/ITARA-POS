import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'supplier_event.dart';
part 'supplier_state.dart';

class SupplierBloc extends Bloc<SupplierEvent, SupplierState> {
  SupplierBloc() : super(const SupplierState()) {
    on<SupplierStarted>(_onStarted);
    on<SupplierRefreshed>(_onRefreshed);
  }

  Future<void> _onStarted(
    SupplierStarted event,
    Emitter<SupplierState> emit,
  ) async {
    emit(state.copyWith(status: SupplierStatus.loading, clearError: true));
    emit(state.copyWith(status: SupplierStatus.ready));
  }

  Future<void> _onRefreshed(
    SupplierRefreshed event,
    Emitter<SupplierState> emit,
  ) async {
    add(const SupplierStarted());
  }
}
