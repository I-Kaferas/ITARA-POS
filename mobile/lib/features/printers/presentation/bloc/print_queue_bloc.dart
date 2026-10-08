import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../sync/print_spooler.dart';
import '../../domain/print_job.dart';

part 'print_queue_event.dart';
part 'print_queue_state.dart';

/// Observes the Master print spooler queue (§42 / §43).
class PrintQueueBloc extends Bloc<PrintQueueEvent, PrintQueueState> {
  PrintQueueBloc({PrintSpooler? spooler})
      : _spooler = spooler ?? PrintSpooler.instance,
        super(const PrintQueueState()) {
    on<PrintQueueStarted>(_onStarted);
    on<PrintQueueRefreshed>(_onRefreshed);
    on<PrintQueueProcessRequested>(_onProcess);
    _spooler.addListener(_onSpoolerChanged);
  }

  final PrintSpooler _spooler;

  void _onSpoolerChanged() => add(const PrintQueueRefreshed());

  Future<void> _onStarted(
    PrintQueueStarted event,
    Emitter<PrintQueueState> emit,
  ) async {
    await _refresh(emit);
  }

  Future<void> _onRefreshed(
    PrintQueueRefreshed event,
    Emitter<PrintQueueState> emit,
  ) async {
    await _refresh(emit);
  }

  Future<void> _onProcess(
    PrintQueueProcessRequested event,
    Emitter<PrintQueueState> emit,
  ) async {
    await _spooler.processQueue();
    await _refresh(emit);
  }

  Future<void> _refresh(Emitter<PrintQueueState> emit) async {
    emit(state.copyWith(status: PrintQueueStatus.loading, clearError: true));
    try {
      final jobs = await _spooler.listJobs();
      emit(state.copyWith(status: PrintQueueStatus.ready, jobs: jobs));
    } catch (error) {
      emit(state.copyWith(
        status: PrintQueueStatus.failure,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  @override
  Future<void> close() {
    _spooler.removeListener(_onSpoolerChanged);
    return super.close();
  }
}
