part of 'stock_count_bloc.dart';

sealed class StockCountEvent extends Equatable {
  const StockCountEvent();

  @override
  List<Object?> get props => const [];
}

final class StockCountStarted extends StockCountEvent {
  const StockCountStarted();
}

final class StockCountRefreshed extends StockCountEvent {
  const StockCountRefreshed();
}

final class StockCountCreated extends StockCountEvent {
  const StockCountCreated(this.kind, {this.cycleSize = 20});

  final StockCountKind kind;
  final int cycleSize;

  @override
  List<Object?> get props => [kind, cycleSize];
}

final class StockCountOpened extends StockCountEvent {
  const StockCountOpened(this.countId);

  final String countId;

  @override
  List<Object?> get props => [countId];
}

final class StockCountLineCounted extends StockCountEvent {
  const StockCountLineCounted(this.productId, this.countedQty);

  final String productId;
  final int? countedQty;

  @override
  List<Object?> get props => [productId, countedQty];
}

/// Verification runs first with [applyAdjustments] false, then may be applied.
final class StockCountPosted extends StockCountEvent {
  const StockCountPosted({this.applyAdjustments = true});

  final bool applyAdjustments;

  @override
  List<Object?> get props => [applyAdjustments];
}

final class StockCountClosed extends StockCountEvent {
  const StockCountClosed();
}
