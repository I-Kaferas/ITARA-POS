import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../pos/domain/pos_models.dart';
import '../../printers/domain/print_group.dart';
import '../../printers/services/printer_router.dart';
import '../../printers/services/printer_service.dart';

/// Builds kitchen / bar tickets and routes them per §40.
class KitchenTicketService {
  KitchenTicketService({
    PrinterRouter? router,
    PrinterService? printerService,
  })  : _router = router ?? PrinterRouter.instance,
        _printerService = printerService ?? PrinterService.instance;

  final PrinterRouter _router;
  final PrinterService _printerService;

  /// Splits sale lines by Category/Product routes then prints each station.
  ///
  /// Example: Drink → Bar Printer, Pizza → Kitchen Printer.
  Future<Map<PrintGroup, int>> printHeldSale(PosHeldSale sale) async {
    if (sale.lines.isEmpty) return const {};

    final buckets = await _router.partitionByRoute<PosCartLine>(
      lines: sale.lines,
      documentType: 'kitchen',
      fallbackGroup: PrintGroup.kitchen,
      refOf: (line) => PrintRouteLineRef(
        productId: line.product.productId,
        categoryId: line.product.categoryId ?? '',
        productKey: line.product.sku,
        categoryKey: _categorySlug(line.product.categoryName ?? line.product.categoryId),
      ),
    );

    final printed = <PrintGroup, int>{};
    for (final entry in buckets.entries) {
      final group = entry.key;
      final lines = entry.value;
      if (lines.isEmpty) continue;

      final documentType = switch (group) {
        PrintGroup.bar => 'bar',
        PrintGroup.dessert => 'dessert',
        PrintGroup.cashier => 'receipt',
        _ => 'kitchen',
      };

      final bytes = await _buildTicketPdf(
        sale: sale,
        lines: lines,
        group: group,
      );

      // Queue for failover / Master spooler (§41 / §42).
      await _printerService.enqueue(
        group: group.name,
        documentType: documentType,
        categoryId: lines.first.product.categoryId ?? '',
        productId: lines.length == 1 ? lines.first.product.productId : '',
        payload: {
          'pdf_base64': base64Encode(bytes),
          'document_type': documentType,
          'sale_id': sale.id,
          'label': sale.label,
          'station': group.name,
          'lines': lines
              .map((l) => {
                    'name': l.displayName,
                    'qty': l.quantity,
                    'product_id': l.product.productId,
                    'category_id': l.product.categoryId,
                  })
              .toList(),
        },
      );

      // Immediate local dialog when no station printer is configured yet.
      final decision = await _router.resolveContext(
        documentType: documentType,
        categoryId: lines.first.product.categoryId ?? '',
        productId: lines.length == 1 ? lines.first.product.productId : '',
        categoryKey: _categorySlug(lines.first.product.categoryName ?? lines.first.product.categoryId),
        fallbackGroup: group,
      );
      if (decision.primary == null) {
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name: 'bon-${group.name}-${sale.id}',
        );
      }

      printed[group] = lines.length;
    }
    return printed;
  }

  String _categorySlug(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    if (value.isEmpty) return '';
    // Normalize "Boissons" / "Drinks" style labels to seed keys.
    if (value.contains('drink') || value.contains('boisson')) return 'drink';
    if (value.contains('pizza')) return 'pizza';
    if (value.contains('food') || value.contains('plat') || value.contains('cuisine')) {
      return 'food';
    }
    return value.replaceAll(RegExp(r'\s+'), '-');
  }

  Future<List<int>> _buildTicketPdf({
    required PosHeldSale sale,
    required List<PosCartLine> lines,
    required PrintGroup group,
  }) async {
    final doc = pw.Document();
    final date = DateFormat('dd/MM/yyyy HH:mm').format(sale.heldAt);
    final title = switch (group) {
      PrintGroup.bar => 'BON DE BAR',
      PrintGroup.dessert => 'BON DESSERT',
      PrintGroup.warehouse => 'BON ENTREPÔT',
      PrintGroup.reception => 'BON RÉCEPTION',
      PrintGroup.cashier => 'TICKET CAISSE',
      PrintGroup.kitchen => 'BON DE CUISINE',
    };

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          80 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 4 * PdfPageFormat.mm,
        ),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              title,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(sale.label, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10)),
            pw.Text(date, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9)),
            pw.Text(
              'Station: ${group.label}',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 9),
            ),
            if (sale.customer != null) ...[
              pw.SizedBox(height: 4),
              pw.Text('Client: ${sale.customer!.name}', style: const pw.TextStyle(fontSize: 9)),
            ],
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 0.6),
            ...lines.map(
              (line) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: 28,
                      child: pw.Text(
                        '${line.quantity}x',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(line.displayName, style: const pw.TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ),
            if (sale.note != null && sale.note!.trim().isNotEmpty) ...[
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.6),
              pw.Text('Note', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.Text(sale.note!, style: const pw.TextStyle(fontSize: 10)),
            ],
            pw.SizedBox(height: 8),
            pw.Text(
              'Non payé — à préparer',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }
}
