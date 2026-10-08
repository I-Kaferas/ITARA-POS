import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'payment_event.dart';
part 'payment_state.dart';

class PaymentBloc extends Bloc<PaymentEvent, PaymentState> {
  PaymentBloc() : super(const PaymentState()) {
    on<PaymentStarted>(_onStarted);
    on<PaymentRefreshed>(_onRefreshed);
  }

  Future<void> _onStarted(
    PaymentStarted event,
    Emitter<PaymentState> emit,
  ) async {
    emit(state.copyWith(status: PaymentStatus.loading, clearError: true));
    emit(state.copyWith(status: PaymentStatus.ready));
  }

  Future<void> _onRefreshed(
    PaymentRefreshed event,
    Emitter<PaymentState> emit,
  ) async {
    add(const PaymentStarted());
  }
}
