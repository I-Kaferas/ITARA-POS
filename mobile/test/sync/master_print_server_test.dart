import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/features/receipt/services/receipt_print_service.dart';
import 'package:pos_mobile/sync/master_print_server.dart';

void main() {
  group('MasterPrintServer §43', () {
    test('singleton is stable', () {
      expect(identical(MasterPrintServer.instance, MasterPrintServer.instance), isTrue);
    });
  });

  group('ReceiptPrintMode', () {
    test('exposes masterQueue for centralized printing', () {
      expect(ReceiptPrintMode.values, contains(ReceiptPrintMode.masterQueue));
    });
  });
}
