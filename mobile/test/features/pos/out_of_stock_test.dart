import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/features/pos/domain/pos_models.dart';
import 'package:pos_mobile/features/pos/services/pos_cart_engine.dart';

PosProduct _product(String id, {int? onHand, String? type, bool? requiresStock}) {
  return PosProduct(
    storeProductId: id,
    productId: id,
    sku: id,
    name: id,
    price: 1000,
    quantityOnHand: onHand,
    productType: type,
    requiresStock: requiresStock,
  );
}

void main() {
  test('stock at 0 or below is ended and cannot be added', () {
    final cart = PosCartEngine();

    final empty = _product('empty', onHand: 0);
    final negative = _product('negative', onHand: -2);
    expect(empty.isOutOfStock, isTrue);
    expect(empty.canAdd(), isFalse);
    expect(negative.isOutOfStock, isTrue);
    expect(cart.addProduct(empty), isFalse);
    expect(cart.addProduct(negative), isFalse);
    expect(cart.lines, isEmpty);
  });

  test('a service with no stock can still be sold', () {
    final cart = PosCartEngine();
    final service = _product('service', onHand: 0, type: 'service');
    expect(service.isOutOfStock, isFalse);
    expect(cart.addProduct(service), isTrue);
    expect(cart.lines, hasLength(1));
  });

  test('increment stops when the on-hand quantity is reached', () {
    final cart = PosCartEngine();
    final product = _product('soda', onHand: 1);
    expect(cart.addProduct(product), isTrue);
    expect(cart.incrementQuantity(cart.lines.single.lineId), isFalse);
    expect(cart.lines.single.quantity, 1);
  });
}
