import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'printer_connection_event.dart';
part 'printer_connection_state.dart';

class PrinterConnectionBloc extends Bloc<PrinterConnectionEvent, PrinterConnectionState> {
  PrinterConnectionBloc() : super(const PrinterConnectionState()) {
    on<PrinterConnectionStarted>(_onStarted);
    on<PrinterConnectionRefreshed>(_onRefreshed);
  }

  Future<void> _onStarted(
    PrinterConnectionStarted event,
    Emitter<PrinterConnectionState> emit,
  ) async {
    emit(state.copyWith(status: PrinterConnectionStatus.loading, clearError: true));
    emit(state.copyWith(status: PrinterConnectionStatus.ready));
  }

  Future<void> _onRefreshed(
    PrinterConnectionRefreshed event,
    Emitter<PrinterConnectionState> emit,
  ) async {
    add(const PrinterConnectionStarted());
  }
}
