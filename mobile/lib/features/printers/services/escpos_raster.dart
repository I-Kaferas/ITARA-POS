import 'dart:typed_data';

import 'package:printing/printing.dart';

typedef RasterPage = ({Uint8List rgba, int width, int height});

/// Turns a receipt PDF into ESC/POS raster bytes (`GS v 0`).
///
/// Raster images print the same on every ESC/POS thermal printer (Epson,
/// Xprinter, Rongta, Bixolon, Sunmi, Star in ESC/POS mode…) whatever the
/// code page, so accents, logos and QR codes come out exactly as previewed.
class EscPosRaster {
  const EscPosRaster._();

  /// Printable dots per line: 384 on 58 mm heads, 576 on 80 mm heads.
  static int dotsFor(int paperWidthMm) => paperWidthMm <= 58 ? 384 : 576;

  static Future<Uint8List> fromPdf(
    Uint8List pdf, {
    required int paperWidthMm,
    bool cut = true,
    bool openDrawer = false,
  }) async {
    final dots = dotsFor(paperWidthMm);
    final dpi = dots * 25.4 / paperWidthMm;
    final pages = <RasterPage>[
      await for (final page in Printing.raster(pdf, dpi: dpi))
        (rgba: page.pixels, width: page.width, height: page.height),
    ];
    return encode(pages, dots: dots, cut: cut, openDrawer: openDrawer);
  }

  /// Encodes RGBA pages, scaled to [dots] wide, as one ESC/POS job.
  static Uint8List encode(
    List<RasterPage> pages, {
    required int dots,
    bool cut = true,
    bool openDrawer = false,
  }) {
    final out = BytesBuilder(copy: false)..add(const [0x1B, 0x40]);
    for (final page in pages) {
      final bitmap = _monochrome(page.rgba, page.width, page.height, dots);
      if (bitmap == null) continue;
      _writeRaster(out, bitmap.bits, dots ~/ 8, bitmap.rows);
    }
    out.add(const [0x1B, 0x64, 0x04]);
    if (cut) out.add(const [0x1D, 0x56, 0x42, 0x00]);
    if (openDrawer) out.add(const [0x1B, 0x70, 0x00, 0x19, 0xFA]);
    return out.toBytes();
  }

  static ({Uint8List bits, int rows})? _monochrome(
    Uint8List rgba,
    int width,
    int height,
    int dots,
  ) {
    if (width <= 0 || height <= 0) return null;
    final bytesPerRow = dots ~/ 8;
    final scale = width / dots;
    final rows = (height / scale).floor();
    final bits = Uint8List(bytesPerRow * rows);
    var lastInk = -1;
    for (var y = 0; y < rows; y++) {
      final sy = (y * scale).floor().clamp(0, height - 1);
      for (var x = 0; x < dots; x++) {
        final sx = (x * scale).floor().clamp(0, width - 1);
        final i = (sy * width + sx) * 4;
        final alpha = rgba[i + 3];
        final luma = (rgba[i] * 299 + rgba[i + 1] * 587 + rgba[i + 2] * 114) ~/ 1000;
        final shade = 255 - ((255 - luma) * alpha ~/ 255);
        if (shade < 150) {
          bits[y * bytesPerRow + (x >> 3)] |= 0x80 >> (x & 7);
          lastInk = y;
        }
      }
    }
    if (lastInk < 0) return null;
    final kept = lastInk + 1;
    return (bits: Uint8List.sublistView(bits, 0, kept * bytesPerRow), rows: kept);
  }

  /// Sends the image in bands: small printer buffers overflow on one huge block.
  static void _writeRaster(BytesBuilder out, Uint8List bits, int bytesPerRow, int rows) {
    const band = 128;
    for (var start = 0; start < rows; start += band) {
      final count = (rows - start) < band ? rows - start : band;
      out.add([
        0x1D, 0x76, 0x30, 0x00,
        bytesPerRow & 0xFF, (bytesPerRow >> 8) & 0xFF,
        count & 0xFF, (count >> 8) & 0xFF,
      ]);
      out.add(Uint8List.sublistView(
        bits,
        start * bytesPerRow,
        (start + count) * bytesPerRow,
      ));
    }
  }
}
