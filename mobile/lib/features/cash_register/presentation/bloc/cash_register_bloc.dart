import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/cash_register_api_service.dart';
import '../../domain/cash_register_models.dart';

part 'cash_register_event.dart';
part 'cash_register_state.dart';

class CashRegisterBloc extends Bloc<CashRegisterEvent, CashRegisterState> {
  CashRegisterBloc({CashRegisterApiService? api})
      : _api = api ?? CashRegisterApiService(),
        super(const CashRegisterState()) {
    on<CashRegisterStarted>(_onStarted);
    on<CashRegisterRefreshed>(_onRefreshed);
    on<CashRegisterSelected>(_onSelected);
    on<CashRegisterOpened>(_onOpened);
    on<CashRegisterClosed>(_onClosed);
    on<CashRegisterCashIn>(_onCashIn);
    on<CashRegisterCashOut>(_onCashOut);
    on<CashRegisterAdjusted>(_onAdjusted);
    on<CashRegisterCounted>(_onCounted);
    on<CashRegisterReconcileRequested>(_onReconcile);
  }

  final CashRegisterApiService _api;

  Future<void> _onStarted(
    CashRegisterStarted event,
    Emitter<CashRegisterState> emit,
  ) async {
    emit(state.copyWith(status: CashRegisterStatus.loading, clearError: true));
    try {
      final registers = await _api.fetchRegisters();
      final selected = registers.cast<CashRegister?>().firstWhere(
            (r) => r?.id == state.selectedRegisterId,
            orElse: () => registers.isNotEmpty ? registers.first : null,
          );
      emit(state.copyWith(
        status: CashRegisterStatus.ready,
        registers: registers,
        selectedRegisterId: selected?.id,
      ));
      if (selected != null && selected.hasOpenSession) {
        add(CashRegisterReconcileRequested(selected.id));
      }
    } catch (e) {
      emit(state.copyWith(
        status: CashRegisterStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onRefreshed(
    CashRegisterRefreshed event,
    Emitter<CashRegisterState> emit,
  ) async {
    add(const CashRegisterStarted());
  }

  Future<void> _onSelected(
    CashRegisterSelected event,
    Emitter<CashRegisterState> emit,
  ) async {
    emit(state.copyWith(selectedRegisterId: event.registerId, clearError: true));
    add(CashRegisterReconcileRequested(event.registerId));
  }

  Future<void> _onOpened(
    CashRegisterOpened event,
    Emitter<CashRegisterState> emit,
  ) async {
    emit(state.copyWith(busy: true, clearError: true));
    try {
      final payload = await _api.openRegister(
        registerId: event.registerId,
        openingBalance: event.openingBalance,
        notes: event.notes,
      );
      emit(state.copyWith(
        busy: false,
        summary: payload.summary,
        reconciliation: payload.reconciliation,
        message: 'Caisse ouverte',
      ));
      add(const CashRegisterRefreshed());
    } catch (e) {
      emit(state.copyWith(busy: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onClosed(
    CashRegisterClosed event,
    Emitter<CashRegisterState> emit,
  ) async {
    emit(state.copyWith(busy: true, clearError: true));
    try {
      final payload = await _api.closeRegister(
        registerId: event.registerId,
        actualCash: event.actualCash,
        notes: event.notes,
        varianceReason: event.varianceReason,
      );
      emit(state.copyWith(
        busy: false,
        summary: payload.summary,
        reconciliation: payload.reconciliation,
        message: 'Caisse fermée',
      ));
      add(const CashRegisterRefreshed());
    } catch (e) {
      emit(state.copyWith(busy: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onCashIn(
    CashRegisterCashIn event,
    Emitter<CashRegisterState> emit,
  ) async {
    await _move(emit, event.registerId, () => _api.cashIn(
          registerId: event.registerId,
          amount: event.amount,
          description: event.description,
        ), 'Entrée enregistrée');
  }

  Future<void> _onCashOut(
    CashRegisterCashOut event,
    Emitter<CashRegisterState> emit,
  ) async {
    await _move(emit, event.registerId, () => _api.cashOut(
          registerId: event.registerId,
          amount: event.amount,
          description: event.description,
        ), 'Sortie enregistrée');
  }

  Future<void> _onAdjusted(
    CashRegisterAdjusted event,
    Emitter<CashRegisterState> emit,
  ) async {
    await _move(emit, event.registerId, () => _api.cashAdjustment(
          registerId: event.registerId,
          amount: event.amount,
          direction: event.direction,
          description: event.description,
        ), 'Ajustement enregistré');
  }

  Future<void> _onCounted(
    CashRegisterCounted event,
    Emitter<CashRegisterState> emit,
  ) async {
    emit(state.copyWith(busy: true, clearError: true));
    try {
      final payload = await _api.cashCount(
        registerId: event.registerId,
        actualCash: event.actualCash,
        notes: event.notes,
      );
      emit(state.copyWith(
        busy: false,
        summary: payload.summary,
        reconciliation: payload.reconciliation,
        message: 'Comptage enregistré',
      ));
      add(const CashRegisterRefreshed());
    } catch (e) {
      emit(state.copyWith(busy: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onReconcile(
    CashRegisterReconcileRequested event,
    Emitter<CashRegisterState> emit,
  ) async {
    try {
      final payload = await _api.reconciliation(event.registerId);
      emit(state.copyWith(
        summary: payload.summary,
        reconciliation: payload.reconciliation,
      ));
    } catch (_) {
      // Register may be closed — ignore.
    }
  }

  Future<void> _move(
    Emitter<CashRegisterState> emit,
    String registerId,
    Future<RegisterSummary> Function() action,
    String successMessage,
  ) async {
    emit(state.copyWith(busy: true, clearError: true));
    try {
      final summary = await action();
      emit(state.copyWith(
        busy: false,
        summary: summary,
        reconciliation: Reconciliation(
          expectedCash: summary.expectedCash,
          actualCash: summary.actualCash,
          difference: summary.difference,
          countedAt: summary.countedAt,
        ),
        message: successMessage,
      ));
      add(const CashRegisterRefreshed());
    } catch (e) {
      emit(state.copyWith(busy: false, errorMessage: e.toString()));
    }
  }
}
