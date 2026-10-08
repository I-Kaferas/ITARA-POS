part of 'printer_connection_bloc.dart';

sealed class PrinterConnectionEvent extends Equatable {
  const PrinterConnectionEvent();

  @override
  List<Object?> get props => const [];
}

final class PrinterConnectionStarted extends PrinterConnectionEvent {
  const PrinterConnectionStarted();
}

final class PrinterConnectionRefreshed extends PrinterConnectionEvent {
  const PrinterConnectionRefreshed();
}
