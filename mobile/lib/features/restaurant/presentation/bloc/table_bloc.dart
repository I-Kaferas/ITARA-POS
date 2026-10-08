import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'table_event.dart';
part 'table_state.dart';

class TableBloc extends Bloc<TableEvent, TableState> {
  TableBloc() : super(const TableState()) {
    on<TableStarted>(_onStarted);
    on<TableRefreshed>(_onRefreshed);
  }

  Future<void> _onStarted(
    TableStarted event,
    Emitter<TableState> emit,
  ) async {
    emit(state.copyWith(status: TableStatus.loading, clearError: true));
    emit(state.copyWith(status: TableStatus.ready));
  }

  Future<void> _onRefreshed(
    TableRefreshed event,
    Emitter<TableState> emit,
  ) async {
    add(const TableStarted());
  }
}
