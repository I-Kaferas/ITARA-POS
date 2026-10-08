import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'restaurant_order_event.dart';
part 'restaurant_order_state.dart';

class RestaurantOrderBloc extends Bloc<RestaurantOrderEvent, RestaurantOrderState> {
  RestaurantOrderBloc() : super(const RestaurantOrderState()) {
    on<RestaurantOrderStarted>(_onStarted);
    on<RestaurantOrderRefreshed>(_onRefreshed);
  }

  Future<void> _onStarted(
    RestaurantOrderStarted event,
    Emitter<RestaurantOrderState> emit,
  ) async {
    emit(state.copyWith(status: RestaurantOrderStatus.loading, clearError: true));
    emit(state.copyWith(status: RestaurantOrderStatus.ready));
  }

  Future<void> _onRefreshed(
    RestaurantOrderRefreshed event,
    Emitter<RestaurantOrderState> emit,
  ) async {
    add(const RestaurantOrderStarted());
  }
}
