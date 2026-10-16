import 'dart:typed_data';

import 'package:barcode_widget/barcode_widget.dart' as bw;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/money_formatter.dart';
import '../../settings/domain/cashier_preferences.dart';
import '../domain/receipt_models.dart';

/// Sizes for one roll width: 58 mm stays compact, 80 mm gets an item table.
/// Fonts and gaps then grow with [CashierPreferences.printTextLevel].
class _RollLayout {
  const _RollLayout({
    required this.marginMm,
    required this.body,
    required this.small,
    required this.title,
    required this.total,
    required this.qr,
    required this.table,
  });

  factory _RollLayout.of(ReceiptDocumentFormat format) => format == ReceiptDocumentFormat.thermal58
      ? const _RollLayout(marginMm: 2, body: 7.5, small: 6.5, title: 10.5, total: 10, qr: 56, table: false)
      : const _RollLayout(marginMm: 3, body: 8.5, small: 7.5, title: 13, total: 12, qr: 76, table: true);

  final double marginMm;
  final double body;
  final double small;
  final double title;
  final double total;
  final double qr;
  final bool table;
}

class ThermalReceiptBuilder {
  Future<Uint8List> build(ReceiptPrintPayload payload) async {
    final doc = pw.Document();
    final layout = _RollLayout.of(payload.format);
    final pageFormat = PdfPageFormat(
      payload.format.paperWidthMm * PdfPageFormat.mm,
      double.infinity,
      marginAll: layout.marginMm * PdfPageFormat.mm,
    );

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (context) => _content(payload, layout),
      ),
    );

    return doc.save();
  }

  pw.Widget _content(ReceiptPrintPayload payload, _RollLayout layout) {
    final body = CashierPreferences.text(layout.body);
    final small = CashierPreferences.text(layout.small);
    final title = CashierPreferences.text(layout.title);
    final total = CashierPreferences.text(layout.total);
    final gap = CashierPreferences.space(1);
    final qr = CashierPreferences.text(layout.qr).clamp(40.0, layout.qr * 1.35);
    String money(int amount) => MoneyFormatter.format(amount, currencyCode: payload.currency);
    final due = payload.total - payload.amountPaid;
    final address = _address(payload.company.address);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if ((payload.company.name ?? '').isNotEmpty)
          pw.Text(
            payload.company.name!.toUpperCase(),
            style: pw.TextStyle(fontSize: title, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
        if ((payload.company.legalName ?? '').isNotEmpty && payload.company.legalName != payload.company.name)
          _centered(payload.company.legalName!, small),
        if (address.isNotEmpty) _centered(address, small),
        if ((payload.company.taxId ?? '').isNotEmpty) _centered('NIF : ${payload.company.taxId}', small),
        if ((payload.branch.name ?? '').isNotEmpty) _centered(payload.branch.name!, small),
        pw.SizedBox(height: 5 * gap),
        pw.Container(
          padding: pw.EdgeInsets.symmetric(vertical: 3 * gap),
          decoration: const pw.BoxDecoration(color: PdfColors.black),
          child: pw.Text(
            payload.isInvoice ? 'FACTURE' : 'REÇU DE VENTE',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(color: PdfColors.white, fontSize: total, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 5 * gap),
        _row('N°', payload.documentNumber, body),
        if (payload.saleReference.isNotEmpty && payload.saleReference != payload.documentNumber)
          _row('Vente', payload.saleReference, body),
        _row('Date', _formatDate(payload.date), body),
        if ((payload.cashier?.name ?? '').isNotEmpty) _row('Caissier', payload.cashier!.name!, body),
        if ((payload.customer?.name ?? '').isNotEmpty) _row('Client', payload.customer!.name!, body),
        if (payload.isInvoice && (payload.customer?.phone ?? '').isNotEmpty)
          _row('Tél.', payload.customer!.phone!, body),
        _dashes(gap),
        if (layout.table)
          _itemTable(payload.items, money, body, small, gap)
        else
          ...payload.items.map((item) => _itemBlock(item, money, body, small, gap)),
        _dashes(gap),
        _row('Sous-total', money(payload.subtotal), body),
        if (payload.discountTotal > 0) _row('Remise', '- ${money(payload.discountTotal)}', body),
        if (payload.taxTotal > 0) _row('Taxes', money(payload.taxTotal), body),
        if (payload.feesTotal > 0) _row('Frais', money(payload.feesTotal), body),
        pw.SizedBox(height: 3 * gap),
        pw.Container(
          padding: pw.EdgeInsets.symmetric(vertical: 3 * gap),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(width: 1),
              bottom: pw.BorderSide(width: 1),
            ),
          ),
          child: _row('TOTAL', money(payload.total), total, bold: true),
        ),
        pw.SizedBox(height: 3 * gap),
        ...payload.payments.map((p) => _row(p.methodLabel.isEmpty ? p.method : p.methodLabel, money(p.amount), body)),
        if (payload.change > 0) _row('Monnaie rendue', money(payload.change), body, bold: true),
        if (due > 0) _row('Reste à payer', money(due), body, bold: true),
        if ((payload.notes ?? '').trim().isNotEmpty) ...[
          pw.SizedBox(height: 4 * gap),
          pw.Text(payload.notes!.trim(), style: pw.TextStyle(fontSize: small)),
        ],
        pw.SizedBox(height: 8 * gap),
        pw.Center(
          child: pw.BarcodeWidget(
            barcode: bw.Barcode.qrCode(),
            data: payload.saleReference.isEmpty ? payload.documentNumber : payload.saleReference,
            width: qr,
            height: qr,
          ),
        ),
        if ((payload.footer ?? '').trim().isNotEmpty) ...[
          pw.SizedBox(height: 6 * gap),
          _centered(payload.footer!.trim(), small),
        ],
        pw.SizedBox(height: 4 * gap),
        _centered('Merci de votre visite', small),
      ],
    );
  }

  /// 58 mm: name on its own line, quantity × price and total underneath.
  pw.Widget _itemBlock(
    ReceiptLineItem item,
    String Function(int) money,
    double body,
    double small,
    double gap,
  ) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: 3 * gap),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(item.name, style: pw.TextStyle(fontSize: body, fontWeight: pw.FontWeight.bold)),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('${item.quantity} x ${money(item.unitPrice)}', style: pw.TextStyle(fontSize: small)),
              pw.Text(money(item.lineTotal), style: pw.TextStyle(fontSize: body)),
            ],
          ),
          if (item.lineDiscount > 0)
            pw.Text('Remise : -${money(item.lineDiscount)}', style: pw.TextStyle(fontSize: small)),
        ],
      ),
    );
  }

  /// 80 mm: Article | Qté | P.U. | Total.
  pw.Widget _itemTable(
    List<ReceiptLineItem> items,
    String Function(int) money,
    double body,
    double small,
    double gap,
  ) {
    pw.Widget cell(String text, {bool bold = false, pw.TextAlign align = pw.TextAlign.left, double? size}) =>
        pw.Padding(
          padding: pw.EdgeInsets.fromLTRB(1, 1.5 * gap, 1, 1.5 * gap),
          child: pw.Text(
            text,
            textAlign: align,
            style: pw.TextStyle(fontSize: size ?? body, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
          ),
        );

    return pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(3.2),
        1: pw.FlexColumnWidth(0.8),
        2: pw.FlexColumnWidth(2.8),
        3: pw.FlexColumnWidth(3.1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.6))),
          children: [
            cell('Article', bold: true, size: small),
            cell('Qté', bold: true, size: small, align: pw.TextAlign.center),
            cell('P.U.', bold: true, size: small, align: pw.TextAlign.right),
            cell('Total', bold: true, size: small, align: pw.TextAlign.right),
          ],
        ),
        for (final item in items)
          pw.TableRow(
            verticalAlignment: pw.TableCellVerticalAlignment.top,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  cell(item.name),
                  if (item.lineDiscount > 0) cell('Remise -${money(item.lineDiscount)}', size: small),
                ],
              ),
              cell('${item.quantity}', align: pw.TextAlign.center),
              cell(money(item.unitPrice), align: pw.TextAlign.right, size: small),
              cell(money(item.lineTotal), align: pw.TextAlign.right),
            ],
          ),
      ],
    );
  }

  pw.Widget _centered(String text, double size) =>
      pw.Text(text, style: pw.TextStyle(fontSize: size), textAlign: pw.TextAlign.center);

  pw.Widget _dashes(double gap) => pw.Padding(
        padding: pw.EdgeInsets.symmetric(vertical: 4 * gap),
        child: pw.Divider(height: 1, thickness: 0.6, borderStyle: pw.BorderStyle.dashed),
      );

  pw.Widget _row(String label, String value, double size, {bool bold = false}) {
    final style = pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: CashierPreferences.space(1)),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: style),
          pw.SizedBox(width: 6),
          pw.Expanded(child: pw.Text(value, style: style, textAlign: pw.TextAlign.right)),
        ],
      ),
    );
  }

  String _address(dynamic address) {
    if (address is String) return address.trim();
    if (address is! Map) return '';
    return [
      address['street'],
      address['avenue'],
      address['quarter'],
      address['commune'],
      address['city'],
    ].map((part) => part?.toString().trim() ?? '').where((part) => part.isNotEmpty).join(', ');
  }

  String _formatDate(String iso) {
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }
}
