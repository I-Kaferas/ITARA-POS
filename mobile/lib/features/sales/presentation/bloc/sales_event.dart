part of 'sales_bloc.dart';

sealed class SalesEvent extends Equatable {
  const SalesEvent();

  @override
  List<Object?> get props => const [];
}

final class SalesStarted extends SalesEvent {
  const SalesStarted();
}

final class SalesRefreshed extends SalesEvent {
  const SalesRefreshed();
}
