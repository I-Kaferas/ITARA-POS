part of 'stock_count_bloc.dart';

enum StockCountStatus { initial, loading, ready, failure }

final class StockCountState extends Equatable {
  const StockCountState({
    this.status = StockCountStatus.initial,
    this.errorMessage,
  });

  final StockCountStatus status;
  final String? errorMessage;

  bool get isLoading => status == StockCountStatus.loading;

  StockCountState copyWith({
    StockCountStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return StockCountState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
