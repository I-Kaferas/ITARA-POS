import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/features/barcode/services/hid_scanner_controller.dart';
import 'package:pos_mobile/features/pos/presentation/widgets/pos_desktop_shortcuts.dart';
import 'package:pos_mobile/features/receipt/services/cash_drawer_service.dart';

void main() {
  group('PosDesktopShortcutKeys', () {
    test('maps F1–F6 and Escape', () {
      expect(PosDesktopShortcutKeys.search.trigger, LogicalKeyboardKey.f1);
      expect(PosDesktopShortcutKeys.newSale.trigger, LogicalKeyboardKey.f2);
      expect(PosDesktopShortcutKeys.customer.trigger, LogicalKeyboardKey.f3);
      expect(PosDesktopShortcutKeys.payment.trigger, LogicalKeyboardKey.f4);
      expect(PosDesktopShortcutKeys.hold.trigger, LogicalKeyboardKey.f5);
      expect(PosDesktopShortcutKeys.retrieve.trigger, LogicalKeyboardKey.f6);
      expect(PosDesktopShortcutKeys.cancel.trigger, LogicalKeyboardKey.escape);
      expect(PosDesktopShortcutKeys.hints.length, 7);
    });
  });

  group('CashDrawerService', () {
    test('ESC/POS kick bytes are valid', () {
      expect(CashDrawerService.escPosKickPin2, [0x1B, 0x70, 0x00, 0x19, 0xFA]);
      expect(CashDrawerService.escPosKickPin5.first, 0x1B);
    });

    test('opens drawer for cash-like payments', () {
      expect(CashDrawerService.shouldOpenForPayment(method: 'cash'), isTrue);
      expect(CashDrawerService.shouldOpenForPayment(method: 'Espèces'), isTrue);
      expect(CashDrawerService.shouldOpenForPayment(method: 'card', change: 500), isTrue);
      expect(CashDrawerService.shouldOpenForPayment(method: 'card'), isFalse);
    });
  });

  group('HidScannerController passthrough', () {
    test('ignores function keys so POS shortcuts work', () {
      final controller = HidScannerController();
      final focus = FocusNode();
      addTearDown(() {
        controller.dispose();
        focus.dispose();
      });

      final event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.f1,
        logicalKey: LogicalKeyboardKey.f1,
        timeStamp: Duration.zero,
      );
      expect(controller.handleKeyEvent(focus, event), KeyEventResult.ignored);

      final esc = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.escape,
        logicalKey: LogicalKeyboardKey.escape,
        timeStamp: Duration.zero,
      );
      expect(controller.handleKeyEvent(focus, esc), KeyEventResult.ignored);
    });
  });
}
