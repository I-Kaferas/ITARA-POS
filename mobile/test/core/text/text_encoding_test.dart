import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/core/text/text_encoding.dart';

void main() {
  test('keeps UTF-8 accents', () {
    final bytes = utf8.encode('Café — Hôtel');
    expect(decodeText(bytes), 'Café — Hôtel');
  });

  test('reads Windows-1252 accents and em dash', () {
    expect(decodeText([0x43, 0x61, 0x66, 0xE9]), 'Café');
    expect(decodeText([0x97]), '—');
    expect(decodeText([0x48, 0xF4, 0x74, 0x65, 0x6C]), 'Hôtel');
  });

  test('does not break mixed UTF-8 when a legacy byte follows', () {
    final utf8Cafe = utf8.encode('Café');
    expect(decodeText([...utf8Cafe, 0x20, 0x97]), 'Café —');
  });
}
