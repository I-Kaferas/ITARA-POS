import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'sales_event.dart';
part 'sales_state.dart';

class SalesBloc extends Bloc<SalesEvent, SalesState> {
  SalesBloc() : super(const SalesState()) {
    on<SalesStarted>(_onStarted);
    on<SalesRefreshed>(_onRefreshed);
  }

  Future<void> _onStarted(
    SalesStarted event,
    Emitter<SalesState> emit,
  ) async {
    emit(state.copyWith(status: SalesStatus.loading, clearError: true));
    emit(state.copyWith(status: SalesStatus.ready));
  }

  Future<void> _onRefreshed(
    SalesRefreshed event,
    Emitter<SalesState> emit,
  ) async {
    add(const SalesStarted());
  }
}
