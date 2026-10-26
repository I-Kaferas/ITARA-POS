import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/features/pos/domain/pos_models.dart';
import 'package:pos_mobile/features/pos/services/pos_cart_engine.dart';

PosProduct _product(String id) => PosProduct(
      storeProductId: id,
      productId: id,
      sku: id,
      name: id,
      price: 1000,
    );

void main() {
  test('holding the open ticket again replaces it instead of stacking a copy', () {
    final cart = PosCartEngine();
    cart.addProduct(_product('soda'));
    cart.holdSale();

    final first = cart.heldSales.single;
    cart.retrieveSale(first.id);
    cart.addProduct(_product('water'));
    final label = cart.holdSale();

    expect(cart.isEmpty, isTrue);
    expect(cart.heldSales, hasLength(1));
    expect(cart.heldSales.single.id, first.id);
    expect(cart.heldSales.single.serverId, isNull);
    expect(cart.heldSales.single.lines, hasLength(2));
    expect(label, first.label);
    expect(cart.isEditingHold, isFalse);
  });

  test('two different orders stay as two holds', () {
    final cart = PosCartEngine();
    cart.addProduct(_product('soda'));
    cart.holdSale();
    cart.addProduct(_product('water'));
    cart.holdSale();

    expect(cart.heldSales, hasLength(2));
    expect(cart.heldSales.map((sale) => sale.id).toSet(), hasLength(2));
  });

  test('reloading holds does not put the open ticket back into the list', () {
    final cart = PosCartEngine();
    cart.addProduct(_product('soda'));
    cart.holdSale();
    final held = cart.heldSales.single;
    cart.retrieveSale(held.id);

    cart.restoreHeldSales([held, held]);

    expect(cart.heldSales, isEmpty);
    expect(cart.lines, isNotEmpty);
    expect(cart.isEditingHold, isTrue);
  });

  test('reloading holds drops a duplicate of the same server ticket', () {
    final cart = PosCartEngine();
    final older = PosHeldSale(
      id: 'local-1',
      serverId: 'server-9',
      label: 'Vente #1',
      lines: [
        PosCartLine(
          lineId: 'a',
          product: _product('soda'),
          unitPrice: 1000,
          quantity: 1,
        ),
      ],
      heldAt: DateTime.utc(2026, 10, 26),
    );
    final copy = PosHeldSale(
      id: 'local-2',
      serverId: 'server-9',
      label: 'Vente #1',
      lines: older.lines,
      heldAt: older.heldAt,
    );

    cart.restoreHeldSales([older, copy]);

    expect(cart.heldSales, hasLength(1));
    expect(cart.heldSales.single.id, 'local-1');
  });
}
