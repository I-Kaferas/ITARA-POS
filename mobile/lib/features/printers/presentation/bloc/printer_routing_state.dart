part of 'printer_routing_bloc.dart';

enum PrinterRoutingStatus { initial, loading, ready, failure }

final class PrinterRoutingState extends Equatable {
  const PrinterRoutingState({
    this.status = PrinterRoutingStatus.initial,
    this.routes = const [],
    this.printers = const [],
    this.errorMessage,
  });

  final PrinterRoutingStatus status;
  final List<PrintRoute> routes;
  final List<Printer> printers;
  final String? errorMessage;

  bool get isLoading => status == PrinterRoutingStatus.loading;

  List<PrintRoute> routesOf(PrintRouteKind kind) =>
      routes.where((r) => r.kind == kind).toList();

  List<PrintRoute> get categoryRoutes => routesOf(PrintRouteKind.category);
  List<PrintRoute> get productRoutes => routesOf(PrintRouteKind.product);
  List<PrintRoute> get documentRoutes => routesOf(PrintRouteKind.document);

  Printer? printerById(String id) {
    if (id.isEmpty) return null;
    for (final printer in printers) {
      if (printer.id == id) return printer;
    }
    return null;
  }

  String describeDestination(PrintRoute route) {
    final pinned = printerById(route.printerId);
    if (pinned != null) return pinned.name;
    return 'Groupe « ${route.group.label} »';
  }

  /// Example legend from mobile.md §40.
  static const examples = <(String, PrintGroup)>[
    ('Drink', PrintGroup.bar),
    ('Pizza', PrintGroup.kitchen),
    ('Receipt', PrintGroup.cashier),
  ];

  PrinterRoutingState copyWith({
    PrinterRoutingStatus? status,
    List<PrintRoute>? routes,
    List<Printer>? printers,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PrinterRoutingState(
      status: status ?? this.status,
      routes: routes ?? this.routes,
      printers: printers ?? this.printers,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, routes, printers, errorMessage];
}
