part of 'printer_discovery_bloc.dart';

sealed class PrinterDiscoveryEvent extends Equatable {
  const PrinterDiscoveryEvent();

  @override
  List<Object?> get props => const [];
}

final class PrinterDiscoveryStarted extends PrinterDiscoveryEvent {
  const PrinterDiscoveryStarted();
}

final class PrinterDiscoveryRefreshed extends PrinterDiscoveryEvent {
  const PrinterDiscoveryRefreshed();
}
