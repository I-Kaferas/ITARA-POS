part of 'printer_configuration_bloc.dart';

sealed class PrinterConfigurationEvent extends Equatable {
  const PrinterConfigurationEvent();

  @override
  List<Object?> get props => const [];
}

final class PrinterConfigurationStarted extends PrinterConfigurationEvent {
  const PrinterConfigurationStarted();
}

final class PrinterConfigurationRefreshed extends PrinterConfigurationEvent {
  const PrinterConfigurationRefreshed();
}
