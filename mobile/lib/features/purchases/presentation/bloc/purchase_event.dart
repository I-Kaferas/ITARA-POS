part of 'purchase_bloc.dart';

sealed class PurchaseEvent extends Equatable {
  const PurchaseEvent();

  @override
  List<Object?> get props => const [];
}

final class PurchaseStarted extends PurchaseEvent {
  const PurchaseStarted();
}

final class PurchaseRefreshed extends PurchaseEvent {
  const PurchaseRefreshed();
}
