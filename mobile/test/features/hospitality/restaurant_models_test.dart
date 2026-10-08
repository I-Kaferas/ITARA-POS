import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/features/hospitality/domain/restaurant_models.dart';

void main() {
  group('RestaurantStatus §23', () {
    test('wire names match mobile.md', () {
      expect(RestaurantStatus.free.wire, 'FREE');
      expect(RestaurantStatus.occupied.wire, 'OCCUPIED');
      expect(RestaurantStatus.ordering.wire, 'ORDERING');
      expect(RestaurantStatus.preparing.wire, 'PREPARING');
      expect(RestaurantStatus.ready.wire, 'READY');
      expect(RestaurantStatus.served.wire, 'SERVED');
      expect(RestaurantStatus.paying.wire, 'PAYING');
      expect(RestaurantStatus.closed.wire, 'CLOSED');
    });

    test('legacy statuses map to §23', () {
      expect(RestaurantStatus.fromWire('free'), RestaurantStatus.free);
      expect(RestaurantStatus.fromWire('occupied'), RestaurantStatus.occupied);
      expect(RestaurantStatus.fromWire('open'), RestaurantStatus.occupied);
      expect(RestaurantStatus.fromWire('kitchen'), RestaurantStatus.preparing);
      expect(RestaurantStatus.fromWire('paid'), RestaurantStatus.closed);
      expect(RestaurantStatus.fromWire('ORDERING'), RestaurantStatus.ordering);
    });

    test('activity flags', () {
      expect(RestaurantStatus.free.isActive, isFalse);
      expect(RestaurantStatus.closed.isActive, isFalse);
      expect(RestaurantStatus.ordering.isActive, isTrue);
      expect(RestaurantStatus.preparing.canSendKitchen, isFalse);
      expect(RestaurantStatus.ordering.canSendKitchen, isTrue);
    });
  });

  group('OrderLineDraft', () {
    test('includes modifiers extras sides in payload', () {
      const draft = OrderLineDraft(
        name: 'Pizza',
        unitPrice: 1000,
        quantity: 2,
        modifiers: ['bien cuite'],
        sides: ['frites'],
        extras: [
          {'name': 'fromage', 'unit_price': 200},
        ],
      );
      expect(draft.lineTotal, 2400);
      final json = draft.toJson(id: 'l1', checkId: 'c1');
      expect(json['modifiers'], ['bien cuite']);
      expect(json['sides'], ['frites']);
      expect(json['accompagnements'], ['frites']);
      expect(json['extras'], isNotEmpty);
    });
  });
}
