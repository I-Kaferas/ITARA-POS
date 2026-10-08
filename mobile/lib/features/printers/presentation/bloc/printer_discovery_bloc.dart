import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'printer_discovery_event.dart';
part 'printer_discovery_state.dart';

class PrinterDiscoveryBloc extends Bloc<PrinterDiscoveryEvent, PrinterDiscoveryState> {
  PrinterDiscoveryBloc() : super(const PrinterDiscoveryState()) {
    on<PrinterDiscoveryStarted>(_onStarted);
    on<PrinterDiscoveryRefreshed>(_onRefreshed);
  }

  Future<void> _onStarted(
    PrinterDiscoveryStarted event,
    Emitter<PrinterDiscoveryState> emit,
  ) async {
    emit(state.copyWith(status: PrinterDiscoveryStatus.loading, clearError: true));
    emit(state.copyWith(status: PrinterDiscoveryStatus.ready));
  }

  Future<void> _onRefreshed(
    PrinterDiscoveryRefreshed event,
    Emitter<PrinterDiscoveryState> emit,
  ) async {
    add(const PrinterDiscoveryStarted());
  }
}
