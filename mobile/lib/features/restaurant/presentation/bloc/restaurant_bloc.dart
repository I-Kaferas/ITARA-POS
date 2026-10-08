import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'restaurant_event.dart';
part 'restaurant_state.dart';

class RestaurantBloc extends Bloc<RestaurantEvent, RestaurantState> {
  RestaurantBloc() : super(const RestaurantState()) {
    on<RestaurantStarted>(_onStarted);
    on<RestaurantRefreshed>(_onRefreshed);
  }

  Future<void> _onStarted(
    RestaurantStarted event,
    Emitter<RestaurantState> emit,
  ) async {
    emit(state.copyWith(status: RestaurantStatus.loading, clearError: true));
    emit(state.copyWith(status: RestaurantStatus.ready));
  }

  Future<void> _onRefreshed(
    RestaurantRefreshed event,
    Emitter<RestaurantState> emit,
  ) async {
    add(const RestaurantStarted());
  }
}
