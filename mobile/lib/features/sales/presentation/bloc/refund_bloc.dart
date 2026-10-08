import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'refund_event.dart';
part 'refund_state.dart';

class RefundBloc extends Bloc<RefundEvent, RefundState> {
  RefundBloc() : super(const RefundState()) {
    on<RefundStarted>(_onStarted);
    on<RefundRefreshed>(_onRefreshed);
  }

  Future<void> _onStarted(
    RefundStarted event,
    Emitter<RefundState> emit,
  ) async {
    emit(state.copyWith(status: RefundStatus.loading, clearError: true));
    emit(state.copyWith(status: RefundStatus.ready));
  }

  Future<void> _onRefreshed(
    RefundRefreshed event,
    Emitter<RefundState> emit,
  ) async {
    add(const RefundStarted());
  }
}
