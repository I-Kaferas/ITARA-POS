part of 'expense_bloc.dart';

enum ExpenseStatus { initial, loading, ready, failure }

final class ExpenseState extends Equatable {
  const ExpenseState({
    this.status = ExpenseStatus.initial,
    this.errorMessage,
  });

  final ExpenseStatus status;
  final String? errorMessage;

  bool get isLoading => status == ExpenseStatus.loading;

  ExpenseState copyWith({
    ExpenseStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ExpenseState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
