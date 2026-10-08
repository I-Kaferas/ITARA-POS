part of 'restaurant_order_bloc.dart';

sealed class RestaurantOrderEvent extends Equatable {
  const RestaurantOrderEvent();

  @override
  List<Object?> get props => const [];
}

final class RestaurantOrderStarted extends RestaurantOrderEvent {
  const RestaurantOrderStarted();
}

final class RestaurantOrderRefreshed extends RestaurantOrderEvent {
  const RestaurantOrderRefreshed();
}
