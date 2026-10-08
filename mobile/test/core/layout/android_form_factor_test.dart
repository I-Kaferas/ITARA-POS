import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/core/layout/android_form_factor.dart';

void main() {
  group('AndroidLayout form factors (§18)', () {
    test('phone < 600', () {
      expect(AndroidLayout.fromWidth(390), AndroidFormFactor.phone);
      expect(AndroidLayout.fromWidth(599), AndroidFormFactor.phone);
    });

    test('tablet 600–899', () {
      expect(AndroidLayout.fromWidth(600), AndroidFormFactor.tablet);
      expect(AndroidLayout.fromWidth(768), AndroidFormFactor.tablet);
      expect(AndroidLayout.fromWidth(899), AndroidFormFactor.tablet);
    });

    test('desk ≥ 900', () {
      expect(AndroidLayout.fromWidth(900), AndroidFormFactor.desk);
      expect(AndroidLayout.fromWidth(1280), AndroidFormFactor.desk);
    });

    test('tablet/desk use three-pane POS', () {
      expect(AndroidFormFactor.phone.usePosThreePane, isFalse);
      expect(AndroidFormFactor.tablet.usePosThreePane, isTrue);
      expect(AndroidFormFactor.desk.usePosThreePane, isTrue);
    });

    test('product columns scale with width', () {
      expect(AndroidLayout.productColumns(360), 2);
      expect(AndroidLayout.productColumns(500), 2);
      expect(AndroidLayout.productColumns(720), 3);
      expect(AndroidLayout.productColumns(960), 4);
    });
  });
}
