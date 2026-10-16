import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/features/receipt/domain/receipt_models.dart';
import 'package:pos_mobile/features/receipt/services/a4_invoice_builder.dart';
import 'package:pos_mobile/features/receipt/services/thermal_receipt_builder.dart';
import 'package:pos_mobile/features/settings/domain/cashier_preferences.dart';

ReceiptPrintPayload _payload(String type, String format) => ReceiptPrintPayload.fromJson({
      'document_type': type,
      'format': format,
      'company': {
        'name': 'Boutique Exemple',
        'legal_name': 'Boutique Exemple SARL',
        'tax_id': '4000000000',
        'address': {'avenue': 'Avenue de la Démo', 'city': 'Bujumbura'},
      },
      'branch': {'name': 'Centre-ville'},
      'document_number': type == 'invoice' ? 'FAC-0001' : 'REC-0001',
      'sale_reference': 'VNT-0001',
      'date': '2026-10-15T09:30:00Z',
      'cashier': {'name': 'Caissier Démo'},
      'customer': {'name': 'Client Démo', 'phone': '+257 00 00 00 00'},
      'items': [
        {'name': 'Riz 5 kg', 'quantity': 2, 'unit_price': 1500000, 'line_total': 3000000},
        {'name': 'Huile de cuisine 1 L avec un nom très long', 'quantity': 1, 'unit_price': 650000, 'line_discount': 50000, 'line_total': 600000},
      ],
      'subtotal': 3650000,
      'discount_total': 50000,
      'total': 3600000,
      'currency': 'BIF',
      'payments': [
        {'method': 'cash', 'method_label': 'Espèces', 'amount': type == 'invoice' ? 2000000 : 4000000},
      ],
      'amount_paid': type == 'invoice' ? 2000000 : 4000000,
      'change': type == 'invoice' ? 0 : 400000,
      'footer': 'Les marchandises vendues ne sont ni reprises ni échangées.',
    });

void main() {
  tearDown(() => CashierPreferences.instance.printTextLevel = 1);

  for (final type in ['receipt', 'invoice']) {
    for (final format in ['thermal_58', 'thermal_80', 'a4']) {
      test('$type $format produit un PDF', () async {
        final payload = _payload(type, format);
        final bytes = payload.format.isThermal
            ? await ThermalReceiptBuilder().build(payload)
            : await A4InvoiceBuilder().build(payload);

        expect(String.fromCharCodes(bytes.take(4)), '%PDF');
        final out = Platform.environment['RECEIPT_SAMPLES_DIR'];
        if (out != null) {
          await File('$out/${type}_$format.pdf').create(recursive: true).then((f) => f.writeAsBytes(bytes));
        }
      });
    }
  }

  test('le niveau XXL produit un ticket plus grand que Défaut', () async {
    final payload = _payload('receipt', 'thermal_80');
    CashierPreferences.instance.printTextLevel = 1;
    final small = await ThermalReceiptBuilder().build(payload);
    CashierPreferences.instance.printTextLevel = 5;
    final large = await ThermalReceiptBuilder().build(payload);
    expect(large.length, greaterThan(small.length));
  });
}
