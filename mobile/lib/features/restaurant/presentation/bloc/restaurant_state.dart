part of 'restaurant_bloc.dart';

enum RestaurantStatus { initial, loading, ready, failure }

final class RestaurantState extends Equatable {
  const RestaurantState({
    this.status = RestaurantStatus.initial,
    this.errorMessage,
  });

  final RestaurantStatus status;
  final String? errorMessage;

  bool get isLoading => status == RestaurantStatus.loading;

  RestaurantState copyWith({
    RestaurantStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RestaurantState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
