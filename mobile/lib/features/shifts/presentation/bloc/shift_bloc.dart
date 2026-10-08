import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'shift_event.dart';
part 'shift_state.dart';

class ShiftBloc extends Bloc<ShiftEvent, ShiftState> {
  ShiftBloc() : super(const ShiftState()) {
    on<ShiftStarted>(_onStarted);
    on<ShiftRefreshed>(_onRefreshed);
  }

  Future<void> _onStarted(
    ShiftStarted event,
    Emitter<ShiftState> emit,
  ) async {
    emit(state.copyWith(status: ShiftStatus.loading, clearError: true));
    emit(state.copyWith(status: ShiftStatus.ready));
  }

  Future<void> _onRefreshed(
    ShiftRefreshed event,
    Emitter<ShiftState> emit,
  ) async {
    add(const ShiftStarted());
  }
}
