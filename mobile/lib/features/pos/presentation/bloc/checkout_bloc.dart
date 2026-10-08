import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'checkout_event.dart';
part 'checkout_state.dart';

class CheckoutBloc extends Bloc<CheckoutEvent, CheckoutState> {
  CheckoutBloc() : super(const CheckoutState()) {
    on<CheckoutStarted>(_onStarted);
    on<CheckoutRefreshed>(_onRefreshed);
  }

  Future<void> _onStarted(
    CheckoutStarted event,
    Emitter<CheckoutState> emit,
  ) async {
    emit(state.copyWith(status: CheckoutStatus.loading, clearError: true));
    emit(state.copyWith(status: CheckoutStatus.ready));
  }

  Future<void> _onRefreshed(
    CheckoutRefreshed event,
    Emitter<CheckoutState> emit,
  ) async {
    add(const CheckoutStarted());
  }
}
