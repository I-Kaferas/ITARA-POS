part of 'expense_bloc.dart';

sealed class ExpenseEvent extends Equatable {
  const ExpenseEvent();

  @override
  List<Object?> get props => const [];
}

final class ExpenseStarted extends ExpenseEvent {
  const ExpenseStarted();
}

final class ExpenseRefreshed extends ExpenseEvent {
  const ExpenseRefreshed();
}
