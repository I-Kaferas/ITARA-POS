part of 'kitchen_bloc.dart';

sealed class KitchenEvent extends Equatable {
  const KitchenEvent();

  @override
  List<Object?> get props => const [];
}

final class KitchenStarted extends KitchenEvent {
  const KitchenStarted();
}

final class KitchenRefreshed extends KitchenEvent {
  const KitchenRefreshed();
}

final class KitchenAdvanceRequested extends KitchenEvent {
  const KitchenAdvanceRequested(this.ticketId);

  final String ticketId;

  @override
  List<Object?> get props => [ticketId];
}

final class KitchenCancelRequested extends KitchenEvent {
  const KitchenCancelRequested(this.ticketId);

  final String ticketId;

  @override
  List<Object?> get props => [ticketId];
}
