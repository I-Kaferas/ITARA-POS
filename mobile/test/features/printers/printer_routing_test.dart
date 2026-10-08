import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/features/printers/domain/print_group.dart';
import 'package:pos_mobile/features/printers/domain/print_route.dart';
import 'package:pos_mobile/features/printers/services/printer_router.dart';

void main() {
  group('PrinterRouter §40', () {
    final routes = <PrintRoute>[
      const PrintRoute(
        id: 'doc-receipt',
        kind: PrintRouteKind.document,
        matchKey: 'receipt',
        group: PrintGroup.cashier,
        priority: 100,
        label: 'Receipt → Cashier Printer',
      ),
      const PrintRoute(
        id: 'cat-drink',
        kind: PrintRouteKind.category,
        matchKey: 'drink',
        group: PrintGroup.bar,
        priority: 10,
        label: 'Drink → Bar Printer',
      ),
      const PrintRoute(
        id: 'cat-pizza',
        kind: PrintRouteKind.category,
        matchKey: 'pizza',
        group: PrintGroup.kitchen,
        priority: 10,
        label: 'Pizza → Kitchen Printer',
      ),
      const PrintRoute(
        id: 'prod-special',
        kind: PrintRouteKind.product,
        matchKey: 'sku-special-wine',
        group: PrintGroup.bar,
        priority: 1,
        label: 'Special wine → Bar',
      ),
      const PrintRoute(
        id: 'prod-override-pizza',
        kind: PrintRouteKind.product,
        matchKey: 'pizza-cold',
        group: PrintGroup.cashier,
        priority: 1,
        label: 'Cold pizza → Cashier (override)',
      ),
    ];

    test('Drink category → Bar Printer', () {
      final matched = PrinterRouter.pickBestRoute(
        routes: routes,
        documentType: 'kitchen',
        categoryKey: 'drink',
      );
      expect(matched?.group, PrintGroup.bar);
      expect(matched?.id, 'cat-drink');
    });

    test('Pizza category → Kitchen Printer', () {
      final matched = PrinterRouter.pickBestRoute(
        routes: routes,
        documentType: 'kitchen',
        categoryKey: 'pizza',
      );
      expect(matched?.group, PrintGroup.kitchen);
      expect(matched?.label, contains('Kitchen'));
    });

    test('Receipt document → Cashier Printer', () {
      final matched = PrinterRouter.pickBestRoute(
        routes: routes,
        documentType: 'receipt',
      );
      expect(matched?.group, PrintGroup.cashier);
      expect(matched?.kind, PrintRouteKind.document);
    });

    test('Product route beats category route', () {
      final matched = PrinterRouter.pickBestRoute(
        routes: routes,
        documentType: 'kitchen',
        categoryKey: 'pizza',
        productKey: 'pizza-cold',
      );
      expect(matched?.group, PrintGroup.cashier);
      expect(matched?.id, 'prod-override-pizza');
    });

    test('Category beats document when both could apply', () {
      // Document kitchen defaults would be kitchen; drink category wins as bar.
      final matched = PrinterRouter.pickBestRoute(
        routes: routes,
        documentType: 'kitchen',
        categoryId: 'drink',
        categoryKey: 'drink',
      );
      expect(matched?.kind, PrintRouteKind.category);
      expect(matched?.group, PrintGroup.bar);
    });

    test('kindRank prefers product over category over document', () {
      expect(PrinterRouter.kindRank(PrintRouteKind.product), lessThan(PrinterRouter.kindRank(PrintRouteKind.category)));
      expect(PrinterRouter.kindRank(PrintRouteKind.category), lessThan(PrinterRouter.kindRank(PrintRouteKind.document)));
    });

    test('disabled routes are ignored', () {
      final withDisabled = [
        ...routes,
        const PrintRoute(
          id: 'cat-drink-off',
          kind: PrintRouteKind.category,
          matchKey: 'soda',
          group: PrintGroup.bar,
          enabled: false,
          priority: 1,
        ),
      ];
      final matched = PrinterRouter.pickBestRoute(
        routes: withDisabled,
        documentType: 'kitchen',
        categoryKey: 'soda',
      );
      expect(matched, isNull);
    });
  });
}
