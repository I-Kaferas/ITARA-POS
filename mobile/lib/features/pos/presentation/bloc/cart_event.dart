part of 'cart_bloc.dart';

sealed class CartEvent extends Equatable {
  const CartEvent();

  @override
  List<Object?> get props => const [];
}

final class CartSynced extends CartEvent {
  const CartSynced();
}

final class CartProductAdded extends CartEvent {
  const CartProductAdded({
    required this.product,
    this.quantity = 1,
    this.variant,
    this.saleUnitId,
  });

  final PosProduct product;
  final int quantity;
  final PosVariant? variant;
  final String? saleUnitId;

  @override
  List<Object?> get props => [product, quantity, variant, saleUnitId];
}

final class CartLineRemoved extends CartEvent {
  const CartLineRemoved(this.lineId);

  final String lineId;

  @override
  List<Object?> get props => [lineId];
}

final class CartQuantityUpdated extends CartEvent {
  const CartQuantityUpdated({required this.lineId, required this.quantity});

  final String lineId;
  final int quantity;

  @override
  List<Object?> get props => [lineId, quantity];
}

final class CartCleared extends CartEvent {
  const CartCleared();
}

final class CartCustomerSet extends CartEvent {
  const CartCustomerSet(this.customer);

  final PosCustomer? customer;

  @override
  List<Object?> get props => [customer];
}

final class CartDiscountSet extends CartEvent {
  const CartDiscountSet({this.amount = 0, this.percent = 0});

  final int amount;
  final double percent;

  @override
  List<Object?> get props => [amount, percent];
}

final class CartNoteSet extends CartEvent {
  const CartNoteSet(this.note);

  final String? note;

  @override
  List<Object?> get props => [note];
}
