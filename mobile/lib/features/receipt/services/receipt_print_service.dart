import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../domain/receipt_models.dart';
import 'a4_invoice_builder.dart';
import 'thermal_receipt_builder.dart';

enum ReceiptPrintMode {
  dialog,
  network,
  pdf,
}

class ReceiptPrintService {
  ReceiptPrintService({
    ThermalReceiptBuilder? thermalBuilder,
    A4InvoiceBuilder? a4Builder,
  })  : _thermalBuilder = thermalBuilder ?? ThermalReceiptBuilder(),
        _a4Builder = a4Builder ?? A4InvoiceBuilder();

  final ThermalReceiptBuilder _thermalBuilder;
  final A4InvoiceBuilder _a4Builder;

  Future<void> print(
    ReceiptPrintPayload payload, {
    ReceiptPrintMode mode = ReceiptPrintMode.dialog,
    NetworkPrinterConfig? networkPrinter,
  }) async {
    final bytes = await buildPdf(payload);
    final name = '${payload.documentType}-${payload.documentNumber}';

    switch (mode) {
      case ReceiptPrintMode.dialog:
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name: name,
          format: _pageFormat(payload),
        );
      case ReceiptPrintMode.network:
        await _printToNetwork(bytes, payload, networkPrinter);
      case ReceiptPrintMode.pdf:
        await Printing.sharePdf(bytes: bytes, filename: '$name.pdf');
    }
  }

  Future<Uint8List> buildPdf(ReceiptPrintPayload payload) async {
    if (payload.format.isThermal) {
      return _thermalBuilder.build(payload);
    }
    return _a4Builder.build(payload);
  }

  Future<List<Printer>> listPrinters() => Printing.listPrinters();

  Future<void> _printToNetwork(
    Uint8List bytes,
    ReceiptPrintPayload payload,
    NetworkPrinterConfig? config,
  ) async {
    if (config == null || !config.isConfigured) {
      throw StateError('Imprimante réseau non configurée');
    }

    final printer = Printer(
      url: 'socket://${config.host}:${config.port}',
      name: 'POS-${config.host}',
      isAvailable: true,
    );

    await Printing.directPrintPdf(
      printer: printer,
      onLayout: (_) async => bytes,
      format: _pageFormat(payload),
    );
  }

  PdfPageFormat _pageFormat(ReceiptPrintPayload payload) {
    if (payload.format == ReceiptDocumentFormat.thermal58) {
      return PdfPageFormat(
        58 * PdfPageFormat.mm,
        double.infinity,
        marginAll: 3 * PdfPageFormat.mm,
      );
    }
    if (payload.format == ReceiptDocumentFormat.thermal80) {
      return PdfPageFormat(
        80 * PdfPageFormat.mm,
        double.infinity,
        marginAll: 3 * PdfPageFormat.mm,
      );
    }
    return PdfPageFormat.a4;
  }
}
