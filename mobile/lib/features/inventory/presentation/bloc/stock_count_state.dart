part of 'stock_count_bloc.dart';

enum StockCountStatus { initial, loading, ready, failure }

final class StockCountState extends Equatable {
  const StockCountState({
    this.status = StockCountStatus.initial,
    this.counts = const [],
    this.active,
    this.submitting = false,
    this.message,
    this.errorMessage,
  });

  final StockCountStatus status;
  final List<StockCountSheet> counts;

  /// Sheet being counted; null shows the list of counts.
  final StockCountSheet? active;
  final bool submitting;
  final String? message;
  final String? errorMessage;

  bool get isLoading => status == StockCountStatus.loading;

  StockCountState copyWith({
    StockCountStatus? status,
    List<StockCountSheet>? counts,
    StockCountSheet? active,
    bool clearActive = false,
    bool? submitting,
    String? message,
    bool clearMessage = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return StockCountState(
      status: status ?? this.status,
      counts: counts ?? this.counts,
      active: clearActive ? null : (active ?? this.active),
      submitting: submitting ?? this.submitting,
      message: clearMessage ? null : (message ?? this.message),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        counts,
        active?.id,
        active?.status,
        active?.lines.map((line) => line.countedQty).toList(),
        submitting,
        message,
        errorMessage,
      ];
}
