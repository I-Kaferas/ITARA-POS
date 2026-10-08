import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'stock_count_event.dart';
part 'stock_count_state.dart';

class StockCountBloc extends Bloc<StockCountEvent, StockCountState> {
  StockCountBloc() : super(const StockCountState()) {
    on<StockCountStarted>(_onStarted);
    on<StockCountRefreshed>(_onRefreshed);
  }

  Future<void> _onStarted(
    StockCountStarted event,
    Emitter<StockCountState> emit,
  ) async {
    emit(state.copyWith(status: StockCountStatus.loading, clearError: true));
    emit(state.copyWith(status: StockCountStatus.ready));
  }

  Future<void> _onRefreshed(
    StockCountRefreshed event,
    Emitter<StockCountState> emit,
  ) async {
    add(const StockCountStarted());
  }
}
