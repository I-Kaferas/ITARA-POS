import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'purchase_event.dart';
part 'purchase_state.dart';

class PurchaseBloc extends Bloc<PurchaseEvent, PurchaseState> {
  PurchaseBloc() : super(const PurchaseState()) {
    on<PurchaseStarted>(_onStarted);
    on<PurchaseRefreshed>(_onRefreshed);
  }

  Future<void> _onStarted(
    PurchaseStarted event,
    Emitter<PurchaseState> emit,
  ) async {
    emit(state.copyWith(status: PurchaseStatus.loading, clearError: true));
    emit(state.copyWith(status: PurchaseStatus.ready));
  }

  Future<void> _onRefreshed(
    PurchaseRefreshed event,
    Emitter<PurchaseState> emit,
  ) async {
    add(const PurchaseStarted());
  }
}
