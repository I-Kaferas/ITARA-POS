import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'expense_event.dart';
part 'expense_state.dart';

class ExpenseBloc extends Bloc<ExpenseEvent, ExpenseState> {
  ExpenseBloc() : super(const ExpenseState()) {
    on<ExpenseStarted>(_onStarted);
    on<ExpenseRefreshed>(_onRefreshed);
  }

  Future<void> _onStarted(
    ExpenseStarted event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(state.copyWith(status: ExpenseStatus.loading, clearError: true));
    emit(state.copyWith(status: ExpenseStatus.ready));
  }

  Future<void> _onRefreshed(
    ExpenseRefreshed event,
    Emitter<ExpenseState> emit,
  ) async {
    add(const ExpenseStarted());
  }
}
