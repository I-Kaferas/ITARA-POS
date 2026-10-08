part of 'payment_bloc.dart';

sealed class PaymentEvent extends Equatable {
  const PaymentEvent();

  @override
  List<Object?> get props => const [];
}

final class PaymentStarted extends PaymentEvent {
  const PaymentStarted();
}

final class PaymentRefreshed extends PaymentEvent {
  const PaymentRefreshed();
}
