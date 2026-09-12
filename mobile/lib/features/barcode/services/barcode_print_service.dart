import 'dart:typed_data';

import 'package:barcode_widget/barcode_widget.dart' as bw;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../domain/barcode_models.dart';

class BarcodePrintService {
  Future<void> printLabel(BarcodePrintPayload payload) async {
    await Printing.layoutPdf(
      onLayout: (_) async => _buildDocument(payload),
      name: 'barcode-${payload.barcode}',
    );
  }

  Future<Uint8List> _buildDocument(BarcodePrintPayload payload) async {
    final doc = pw.Document();
    final symbology = _symbology(payload.type);

    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, 50 * PdfPageFormat.mm),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                payload.label,
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 8),
              pw.BarcodeWidget(
                barcode: symbology,
                data: payload.barcode,
                width: 200,
                height: 60,
                drawText: true,
              ),
              pw.SizedBox(height: 4),
              pw.Text(payload.typeLabel, style: const pw.TextStyle(fontSize: 8)),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  bw.Barcode _symbology(PosBarcodeType type) {
    return switch (type) {
      PosBarcodeType.ean13 => bw.Barcode.ean13(),
      PosBarcodeType.ean8 => bw.Barcode.ean8(),
      PosBarcodeType.upc => bw.Barcode.upcA(),
      PosBarcodeType.qr => bw.Barcode.qrCode(),
      PosBarcodeType.code128 => bw.Barcode.code128(),
      PosBarcodeType.internal => bw.Barcode.code128(),
    };
  }
}
