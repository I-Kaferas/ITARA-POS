part of 'table_bloc.dart';

enum TableStatus { initial, loading, ready, failure }

final class TableState extends Equatable {
  const TableState({
    this.status = TableStatus.initial,
    this.errorMessage,
  });

  final TableStatus status;
  final String? errorMessage;

  bool get isLoading => status == TableStatus.loading;

  TableState copyWith({
    TableStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TableState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
