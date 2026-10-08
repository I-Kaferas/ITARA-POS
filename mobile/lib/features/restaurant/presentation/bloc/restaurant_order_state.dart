part of 'restaurant_order_bloc.dart';

enum RestaurantOrderStatus { initial, loading, ready, failure }

final class RestaurantOrderState extends Equatable {
  const RestaurantOrderState({
    this.status = RestaurantOrderStatus.initial,
    this.errorMessage,
  });

  final RestaurantOrderStatus status;
  final String? errorMessage;

  bool get isLoading => status == RestaurantOrderStatus.loading;

  RestaurantOrderState copyWith({
    RestaurantOrderStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RestaurantOrderState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
