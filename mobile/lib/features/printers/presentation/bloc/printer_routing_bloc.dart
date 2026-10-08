import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/print_group.dart';
import '../../domain/print_route.dart';
import '../../domain/printer.dart';
import '../../services/printer_manager.dart';
import '../../services/printer_router.dart';

part 'printer_routing_event.dart';
part 'printer_routing_state.dart';

class PrinterRoutingBloc extends Bloc<PrinterRoutingEvent, PrinterRoutingState> {
  PrinterRoutingBloc({
    PrinterRouter? router,
    PrinterManager? manager,
  })  : _router = router ?? PrinterRouter.instance,
        _manager = manager ?? PrinterManager.instance,
        super(const PrinterRoutingState()) {
    on<PrinterRoutingStarted>(_onStarted);
    on<PrinterRoutingRefreshed>(_onRefreshed);
    on<PrinterRoutingUpserted>(_onUpserted);
    on<PrinterRoutingDeleted>(_onDeleted);
    on<PrinterRoutingSeedRequested>(_onSeed);
  }

  final PrinterRouter _router;
  final PrinterManager _manager;

  Future<void> _onStarted(
    PrinterRoutingStarted event,
    Emitter<PrinterRoutingState> emit,
  ) async {
    emit(state.copyWith(status: PrinterRoutingStatus.loading, clearError: true));
    try {
      await _router.seedDefaultRoutes();
      final routes = await _router.listRoutes();
      final printers = await _manager.list();
      emit(state.copyWith(
        status: PrinterRoutingStatus.ready,
        routes: routes,
        printers: printers,
      ));
    } catch (error) {
      emit(state.copyWith(
        status: PrinterRoutingStatus.failure,
        errorMessage: error.toString(),
      ));
    }
  }

  Future<void> _onRefreshed(
    PrinterRoutingRefreshed event,
    Emitter<PrinterRoutingState> emit,
  ) async {
    add(const PrinterRoutingStarted());
  }

  Future<void> _onUpserted(
    PrinterRoutingUpserted event,
    Emitter<PrinterRoutingState> emit,
  ) async {
    try {
      await _router.upsertRoute(event.route);
      final routes = await _router.listRoutes();
      emit(state.copyWith(
        status: PrinterRoutingStatus.ready,
        routes: routes,
        clearError: true,
      ));
    } catch (error) {
      emit(state.copyWith(
        status: PrinterRoutingStatus.failure,
        errorMessage: error.toString(),
      ));
    }
  }

  Future<void> _onDeleted(
    PrinterRoutingDeleted event,
    Emitter<PrinterRoutingState> emit,
  ) async {
    try {
      await _router.deleteRoute(event.id);
      final routes = await _router.listRoutes();
      emit(state.copyWith(status: PrinterRoutingStatus.ready, routes: routes));
    } catch (error) {
      emit(state.copyWith(
        status: PrinterRoutingStatus.failure,
        errorMessage: error.toString(),
      ));
    }
  }

  Future<void> _onSeed(
    PrinterRoutingSeedRequested event,
    Emitter<PrinterRoutingState> emit,
  ) async {
    try {
      await _router.seedDefaultRoutes(force: event.force);
      final routes = await _router.listRoutes();
      emit(state.copyWith(status: PrinterRoutingStatus.ready, routes: routes));
    } catch (error) {
      emit(state.copyWith(
        status: PrinterRoutingStatus.failure,
        errorMessage: error.toString(),
      ));
    }
  }
}
