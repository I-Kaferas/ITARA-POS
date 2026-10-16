import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/features/printers/services/escpos_raster.dart';

RasterPage _page(int width, int height, bool Function(int x, int y) ink) {
  final rgba = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      final value = ink(x, y) ? 0 : 255;
      rgba[i] = value;
      rgba[i + 1] = value;
      rgba[i + 2] = value;
      rgba[i + 3] = 255;
    }
  }
  return (rgba: rgba, width: width, height: height);
}

List<int> _tail(Uint8List bytes, int count) =>
    bytes.sublist(bytes.length - count);

void main() {
  test('dot width follows the paper', () {
    expect(EscPosRaster.dotsFor(58), 384);
    expect(EscPosRaster.dotsFor(80), 576);
  });

  test('scales the page to the head width and trims blank paper', () {
    // 768 px wide → 384 dots (half scale); ink in the top-left 160×20 px.
    final page = _page(768, 100, (x, y) => x < 160 && y < 20);
    final bytes = EscPosRaster.encode([page], dots: 384);

    expect(bytes.sublist(0, 2), [0x1B, 0x40]);
    expect(bytes.sublist(2, 10), [0x1D, 0x76, 0x30, 0x00, 48, 0, 10, 0]);
    final firstRow = bytes.sublist(10, 10 + 48);
    expect(firstRow.sublist(0, 10), everyElement(0xFF));
    expect(firstRow.sublist(10), everyElement(0x00));
    expect(bytes.length, 10 + 48 * 10 + 3 + 4);
    expect(_tail(bytes, 7), [0x1B, 0x64, 0x04, 0x1D, 0x56, 0x42, 0x00]);
  });

  test('blank page only feeds and cuts', () {
    final bytes = EscPosRaster.encode([_page(384, 50, (_, _) => false)], dots: 384);
    expect(bytes, [0x1B, 0x40, 0x1B, 0x64, 0x04, 0x1D, 0x56, 0x42, 0x00]);
  });

  test('tall images are split into bands', () {
    final bytes = EscPosRaster.encode(
      [_page(576, 300, (_, _) => true)],
      dots: 576,
      cut: false,
      openDrawer: true,
    );
    const rowBytes = 72;
    var offset = 2;
    final bands = <int>[];
    while (offset + 8 <= bytes.length && bytes[offset] == 0x1D && bytes[offset + 1] == 0x76) {
      final rows = bytes[offset + 6] | (bytes[offset + 7] << 8);
      expect(bytes[offset + 4], rowBytes);
      bands.add(rows);
      offset += 8 + rows * rowBytes;
    }
    expect(bands, [128, 128, 44]);
    expect(_tail(bytes, 8), [0x1B, 0x64, 0x04, 0x1B, 0x70, 0x00, 0x19, 0xFA]);
  });
}
