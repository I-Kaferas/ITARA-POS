part of 'printer_routing_bloc.dart';

sealed class PrinterRoutingEvent extends Equatable {
  const PrinterRoutingEvent();

  @override
  List<Object?> get props => const [];
}

final class PrinterRoutingStarted extends PrinterRoutingEvent {
  const PrinterRoutingStarted();
}

final class PrinterRoutingRefreshed extends PrinterRoutingEvent {
  const PrinterRoutingRefreshed();
}

final class PrinterRoutingUpserted extends PrinterRoutingEvent {
  const PrinterRoutingUpserted(this.route);

  final PrintRoute route;

  @override
  List<Object?> get props => [route];
}

final class PrinterRoutingDeleted extends PrinterRoutingEvent {
  const PrinterRoutingDeleted(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

final class PrinterRoutingSeedRequested extends PrinterRoutingEvent {
  const PrinterRoutingSeedRequested({this.force = false});

  final bool force;

  @override
  List<Object?> get props => [force];
}
