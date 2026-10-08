import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'printer_configuration_event.dart';
part 'printer_configuration_state.dart';

class PrinterConfigurationBloc extends Bloc<PrinterConfigurationEvent, PrinterConfigurationState> {
  PrinterConfigurationBloc() : super(const PrinterConfigurationState()) {
    on<PrinterConfigurationStarted>(_onStarted);
    on<PrinterConfigurationRefreshed>(_onRefreshed);
  }

  Future<void> _onStarted(
    PrinterConfigurationStarted event,
    Emitter<PrinterConfigurationState> emit,
  ) async {
    emit(state.copyWith(status: PrinterConfigurationStatus.loading, clearError: true));
    emit(state.copyWith(status: PrinterConfigurationStatus.ready));
  }

  Future<void> _onRefreshed(
    PrinterConfigurationRefreshed event,
    Emitter<PrinterConfigurationState> emit,
  ) async {
    add(const PrinterConfigurationStarted());
  }
}
