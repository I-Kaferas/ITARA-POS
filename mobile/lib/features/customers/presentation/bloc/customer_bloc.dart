import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'customer_event.dart';
part 'customer_state.dart';

class CustomerBloc extends Bloc<CustomerEvent, CustomerState> {
  CustomerBloc() : super(const CustomerState()) {
    on<CustomerStarted>(_onStarted);
    on<CustomerRefreshed>(_onRefreshed);
  }

  Future<void> _onStarted(
    CustomerStarted event,
    Emitter<CustomerState> emit,
  ) async {
    emit(state.copyWith(status: CustomerStatus.loading, clearError: true));
    emit(state.copyWith(status: CustomerStatus.ready));
  }

  Future<void> _onRefreshed(
    CustomerRefreshed event,
    Emitter<CustomerState> emit,
  ) async {
    add(const CustomerStarted());
  }
}
