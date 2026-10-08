import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/terminal_config_repository.dart';
import '../../../../sync/local_realtime.dart';
import '../../data/kitchen_repository.dart';
import '../../domain/kitchen_ticket.dart';
import '../../domain/kitchen_ticket_status.dart';

part 'kitchen_event.dart';
part 'kitchen_state.dart';

class KitchenBloc extends Bloc<KitchenEvent, KitchenState> {
  KitchenBloc({KitchenRepository? repository})
      : _repository = repository ?? KitchenRepository(),
        super(const KitchenState()) {
    on<KitchenStarted>(_onStarted);
    on<KitchenRefreshed>(_onRefreshed);
    on<KitchenAdvanceRequested>(_onAdvance);
    on<KitchenCancelRequested>(_onCancel);
  }

  final KitchenRepository _repository;
  StreamSubscription<RealtimeEvent>? _realtimeSub;
  Timer? _debounce;

  Future<void> _onStarted(
    KitchenStarted event,
    Emitter<KitchenState> emit,
  ) async {
    emit(state.copyWith(status: KitchenLoadStatus.loading, clearError: true));
    await _bindRealtime();
    await _load(emit);
  }

  Future<void> _onRefreshed(
    KitchenRefreshed event,
    Emitter<KitchenState> emit,
  ) async {
    await _load(emit, silent: state.tickets.isNotEmpty);
  }

  Future<void> _onAdvance(
    KitchenAdvanceRequested event,
    Emitter<KitchenState> emit,
  ) async {
    final ticket = state.tickets.where((item) => item.id == event.ticketId).firstOrNull;
    final next = ticket?.status.next;
    if (ticket == null || next == null) return;
    try {
      final tickets = await _repository.setStatus(ticketId: ticket.id, status: next);
      emit(state.copyWith(status: KitchenLoadStatus.ready, tickets: tickets, clearError: true));
    } catch (error) {
      emit(state.copyWith(
        status: KitchenLoadStatus.failure,
        error: error.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> _onCancel(
    KitchenCancelRequested event,
    Emitter<KitchenState> emit,
  ) async {
    try {
      final tickets = await _repository.setStatus(
        ticketId: event.ticketId,
        status: KitchenTicketStatus.cancelled,
      );
      emit(state.copyWith(status: KitchenLoadStatus.ready, tickets: tickets, clearError: true));
    } catch (error) {
      emit(state.copyWith(
        status: KitchenLoadStatus.failure,
        error: error.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> _load(Emitter<KitchenState> emit, {bool silent = false}) async {
    if (!silent) {
      emit(state.copyWith(status: KitchenLoadStatus.loading, clearError: true));
    }
    try {
      final tickets = await _repository.fetchTickets();
      emit(state.copyWith(status: KitchenLoadStatus.ready, tickets: tickets, clearError: true));
    } catch (error) {
      emit(state.copyWith(
        status: KitchenLoadStatus.failure,
        error: error.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> _bindRealtime() async {
    await _realtimeSub?.cancel();
    final config = TerminalConfigRepository.instance.config;
    final stream = config.isMaster
        ? LocalRealtimeHub.instance.events
        : LocalRealtimeClient.instance.events;
    _realtimeSub = stream.listen(_onRealtime);
  }

  void _onRealtime(RealtimeEvent event) {
    final relevant = switch (event.type) {
      RealtimeEventType.kitchenOrderCreated ||
      RealtimeEventType.kitchenOrderReady ||
      RealtimeEventType.orderCreated ||
      RealtimeEventType.orderUpdated =>
        true,
      _ => false,
    };
    if (!relevant) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!isClosed) add(const KitchenRefreshed());
    });
  }

  @override
  Future<void> close() async {
    _debounce?.cancel();
    await _realtimeSub?.cancel();
    return super.close();
  }
}
