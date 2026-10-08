part of 'restaurant_bloc.dart';

sealed class RestaurantEvent extends Equatable {
  const RestaurantEvent();

  @override
  List<Object?> get props => const [];
}

final class RestaurantStarted extends RestaurantEvent {
  const RestaurantStarted();
}

final class RestaurantRefreshed extends RestaurantEvent {
  const RestaurantRefreshed();
}
