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
