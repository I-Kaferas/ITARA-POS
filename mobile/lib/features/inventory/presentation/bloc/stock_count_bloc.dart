import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/inventory_repository.dart';
import '../../domain/inventory_exception.dart';
import '../../domain/stock_count.dart';

part 'stock_count_event.dart';
part 'stock_count_state.dart';

class StockCountBloc extends Bloc<StockCountEvent, StockCountState> {
  StockCountBloc({InventoryRepository? repository})
      : _repository = repository ?? InventoryRepository.instance,
        super(const StockCountState()) {
    on<StockCountStarted>(_onStarted);
    on<StockCountRefreshed>(_onRefreshed);
    on<StockCountCreated>(_onCreated);
    on<StockCountOpened>(_onOpened);
    on<StockCountLineCounted>(_onCounted);
    on<StockCountPosted>(_onPosted);
    on<StockCountClosed>((event, emit) => emit(state.copyWith(clearActive: true, clearMessage: true)));
  }

  final InventoryRepository _repository;

  Future<void> _onStarted(
    StockCountStarted event,
    Emitter<StockCountState> emit,
  ) async {
    emit(state.copyWith(status: StockCountStatus.loading, clearError: true));
    await _reload(emit);
  }

  Future<void> _onRefreshed(
    StockCountRefreshed event,
    Emitter<StockCountState> emit,
  ) =>
      _reload(emit);

  Future<void> _reload(Emitter<StockCountState> emit) async {
    try {
      emit(state.copyWith(status: StockCountStatus.ready, counts: await _repository.counts()));
    } catch (error) {
      emit(state.copyWith(status: StockCountStatus.failure, errorMessage: error.toString()));
    }
  }

  Future<void> _onCreated(
    StockCountCreated event,
    Emitter<StockCountState> emit,
  ) async {
    emit(state.copyWith(submitting: true, clearError: true, clearMessage: true));
    try {
      final products = event.kind == StockCountKind.cycle
          ? await _repository.cycleCandidates(size: event.cycleSize)
          : await _repository.products();
      if (products.isEmpty) throw const InventoryException('Aucun article suivi en stock');
      final sheet = await _repository.startCount(kind: event.kind, products: products);
      emit(state.copyWith(submitting: false, active: sheet));
      await _reload(emit);
    } catch (error) {
      emit(state.copyWith(submitting: false, errorMessage: error.toString()));
    }
  }

  Future<void> _onOpened(
    StockCountOpened event,
    Emitter<StockCountState> emit,
  ) async {
    final sheet = await _repository.loadCount(event.countId);
    if (sheet != null) emit(state.copyWith(active: sheet, clearError: true, clearMessage: true));
  }

  Future<void> _onCounted(
    StockCountLineCounted event,
    Emitter<StockCountState> emit,
  ) async {
    final sheet = state.active;
    if (sheet == null) return;
    try {
      await _repository.setCounted(sheet.id, event.productId, event.countedQty);
      emit(state.copyWith(
        active: StockCountSheet(
          id: sheet.id,
          kind: sheet.kind,
          status: sheet.status,
          warehouseId: sheet.warehouseId,
          createdAt: sheet.createdAt,
          lines: [
            for (final line in sheet.lines)
              line.productId == event.productId ? line.withCounted(event.countedQty) : line,
          ],
        ),
        clearError: true,
      ));
    } catch (error) {
      emit(state.copyWith(errorMessage: error.toString()));
    }
  }

  Future<void> _onPosted(
    StockCountPosted event,
    Emitter<StockCountState> emit,
  ) async {
    final sheet = state.active;
    if (sheet == null) return;
    if (sheet.countedLines == 0) {
      emit(state.copyWith(errorMessage: 'Saisissez au moins une quantité comptée'));
      return;
    }
    emit(state.copyWith(submitting: true, clearError: true, clearMessage: true));
    try {
      final postings = await _repository.postCount(sheet.id, applyAdjustments: event.applyAdjustments);
      final refreshed = await _repository.loadCount(sheet.id);
      emit(state.copyWith(
        submitting: false,
        active: refreshed,
        message: event.applyAdjustments
            ? (postings.isEmpty ? 'Inventaire validé · aucun écart' : 'Inventaire validé · ${postings.length} ajustement(s)')
            : (sheet.varianceLines == 0 ? 'Vérification · aucun écart' : 'Vérification · ${sheet.varianceLines} écart(s)'),
      ));
      await _reload(emit);
    } catch (error) {
      emit(state.copyWith(submitting: false, errorMessage: error.toString()));
    }
  }
}
