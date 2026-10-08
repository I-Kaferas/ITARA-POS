import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/features/printers/domain/print_group.dart';
import 'package:pos_mobile/features/printers/domain/printer.dart';
import 'package:pos_mobile/features/printers/services/printer_failover.dart';

Printer _p({
  required String id,
  int priority = 100,
  bool online = true,
  bool enabled = true,
}) {
  return Printer(
    id: id,
    name: id,
    group: PrintGroup.cashier,
    priority: priority,
    online: online,
    enabled: enabled,
  );
}

void main() {
  group('PrinterFailover.chain §41', () {
    test('preferred first, then ready by priority, then offline', () {
      final chain = PrinterFailover.chain(
        preferred: _p(id: 'p2', priority: 20, online: false),
        groupPrinters: [
          _p(id: 'p1', priority: 10),
          _p(id: 'p2', priority: 20, online: false),
          _p(id: 'p3', priority: 30),
          _p(id: 'p4', priority: 5, enabled: false),
        ],
      );
      expect(chain.map((p) => p.id).toList(), ['p2', 'p1', 'p3']);
    });

    test('skips disabled printers', () {
      final chain = PrinterFailover.chain(
        groupPrinters: [
          _p(id: 'off', enabled: false),
          _p(id: 'on'),
        ],
      );
      expect(chain.map((p) => p.id), ['on']);
    });
  });

  group('PrinterFailover.run §41', () {
    test('Printer 1 OFFLINE → Printer 2 PRINT', () async {
      final failover = const PrinterFailover();
      final tried = <String>[];
      final result = await failover.run(
        candidates: [
          _p(id: 'printer-1', priority: 1),
          _p(id: 'printer-2', priority: 2),
        ],
        printFn: (printer) async {
          tried.add(printer.id);
          if (printer.id == 'printer-1') {
            throw StateError('OFFLINE');
          }
        },
      );

      expect(tried, ['printer-1', 'printer-2']);
      expect(result.success, isTrue);
      expect(result.printer?.id, 'printer-2');
      expect(result.usedFailover, isTrue);
      expect(result.failedPrinterIds, ['printer-1']);
    });

    test('all offline → failure kept for retry, no throw from policy', () async {
      final failover = const PrinterFailover();
      final result = await failover.run(
        candidates: [_p(id: 'a'), _p(id: 'b')],
        printFn: (_) async => throw StateError('down'),
      );
      expect(result.success, isFalse);
      expect(result.attempts, hasLength(2));
      expect(result.failedPrinterIds, ['a', 'b']);
    });
  });
}
