part of 'cart_bloc.dart';

final class CartState extends Equatable {
  const CartState({
    this.lines = const [],
    this.heldSales = const [],
    this.customer,
    this.note,
    this.discountAmount = 0,
    this.discountPercent = 0,
    this.subtotal = 0,
    this.taxTotal = 0,
    this.discountTotal = 0,
    this.feesTotal = 0,
    this.total = 0,
    this.itemCount = 0,
  });

  factory CartState.fromEngine(PosCartEngine engine) {
    return CartState(
      lines: engine.lines,
      heldSales: engine.heldSales,
      customer: engine.customer,
      note: engine.note,
      discountAmount: engine.discountAmount,
      discountPercent: engine.discountPercent,
      subtotal: engine.subtotal,
      taxTotal: engine.taxTotal,
      discountTotal: engine.discountTotal,
      feesTotal: engine.feesTotal,
      total: engine.total,
      itemCount: engine.itemCount,
    );
  }

  final List<PosCartLine> lines;
  final List<PosHeldSale> heldSales;
  final PosCustomer? customer;
  final String? note;
  final int discountAmount;
  final double discountPercent;
  final int subtotal;
  final int taxTotal;
  final int discountTotal;
  final int feesTotal;
  final int total;
  final int itemCount;

  bool get isEmpty => lines.isEmpty;

  @override
  List<Object?> get props => [
        lines,
        heldSales,
        customer,
        note,
        discountAmount,
        discountPercent,
        subtotal,
        taxTotal,
        discountTotal,
        feesTotal,
        total,
        itemCount,
      ];
}
