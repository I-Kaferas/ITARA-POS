part of 'cash_register_bloc.dart';

sealed class CashRegisterEvent extends Equatable {
  const CashRegisterEvent();

  @override
  List<Object?> get props => const [];
}

final class CashRegisterStarted extends CashRegisterEvent {
  const CashRegisterStarted();
}

final class CashRegisterRefreshed extends CashRegisterEvent {
  const CashRegisterRefreshed();
}

final class CashRegisterSelected extends CashRegisterEvent {
  const CashRegisterSelected(this.registerId);

  final String registerId;

  @override
  List<Object?> get props => [registerId];
}

final class CashRegisterOpened extends CashRegisterEvent {
  const CashRegisterOpened({
    required this.registerId,
    required this.openingBalance,
    this.notes,
  });

  final String registerId;
  final int openingBalance;
  final String? notes;

  @override
  List<Object?> get props => [registerId, openingBalance, notes];
}

final class CashRegisterClosed extends CashRegisterEvent {
  const CashRegisterClosed({
    required this.registerId,
    required this.actualCash,
    this.notes,
    this.varianceReason,
  });

  final String registerId;
  final int actualCash;
  final String? notes;
  final String? varianceReason;

  @override
  List<Object?> get props => [registerId, actualCash, notes, varianceReason];
}

final class CashRegisterCashIn extends CashRegisterEvent {
  const CashRegisterCashIn({
    required this.registerId,
    required this.amount,
    this.description,
  });

  final String registerId;
  final int amount;
  final String? description;

  @override
  List<Object?> get props => [registerId, amount, description];
}

final class CashRegisterCashOut extends CashRegisterEvent {
  const CashRegisterCashOut({
    required this.registerId,
    required this.amount,
    this.description,
  });

  final String registerId;
  final int amount;
  final String? description;

  @override
  List<Object?> get props => [registerId, amount, description];
}

final class CashRegisterAdjusted extends CashRegisterEvent {
  const CashRegisterAdjusted({
    required this.registerId,
    required this.amount,
    required this.direction,
    this.description,
  });

  final String registerId;
  final int amount;
  final String direction;
  final String? description;

  @override
  List<Object?> get props => [registerId, amount, direction, description];
}

final class CashRegisterCounted extends CashRegisterEvent {
  const CashRegisterCounted({
    required this.registerId,
    required this.actualCash,
    this.notes,
  });

  final String registerId;
  final int actualCash;
  final String? notes;

  @override
  List<Object?> get props => [registerId, actualCash, notes];
}

final class CashRegisterReconcileRequested extends CashRegisterEvent {
  const CashRegisterReconcileRequested(this.registerId);

  final String registerId;

  @override
  List<Object?> get props => [registerId];
}
