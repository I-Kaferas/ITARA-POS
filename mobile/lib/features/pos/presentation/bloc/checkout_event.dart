part of 'checkout_bloc.dart';

sealed class CheckoutEvent extends Equatable {
  const CheckoutEvent();

  @override
  List<Object?> get props => const [];
}

final class CheckoutStarted extends CheckoutEvent {
  const CheckoutStarted();
}

final class CheckoutRefreshed extends CheckoutEvent {
  const CheckoutRefreshed();
}
