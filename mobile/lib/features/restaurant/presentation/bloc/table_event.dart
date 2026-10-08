part of 'table_bloc.dart';

sealed class TableEvent extends Equatable {
  const TableEvent();

  @override
  List<Object?> get props => const [];
}

final class TableStarted extends TableEvent {
  const TableStarted();
}

final class TableRefreshed extends TableEvent {
  const TableRefreshed();
}
