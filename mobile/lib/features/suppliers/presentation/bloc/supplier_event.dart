part of 'supplier_bloc.dart';

sealed class SupplierEvent extends Equatable {
  const SupplierEvent();

  @override
  List<Object?> get props => const [];
}

final class SupplierStarted extends SupplierEvent {
  const SupplierStarted();
}

final class SupplierRefreshed extends SupplierEvent {
  const SupplierRefreshed();
}
