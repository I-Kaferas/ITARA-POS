part of 'customer_bloc.dart';

sealed class CustomerEvent extends Equatable {
  const CustomerEvent();

  @override
  List<Object?> get props => const [];
}

final class CustomerStarted extends CustomerEvent {
  const CustomerStarted();
}

final class CustomerRefreshed extends CustomerEvent {
  const CustomerRefreshed();
}
