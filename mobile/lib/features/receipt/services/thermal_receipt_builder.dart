import 'dart:typed_data';

import 'package:barcode_widget/barcode_widget.dart' as bw;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/money_formatter.dart';
import '../domain/receipt_models.dart';

class ThermalReceiptBuilder {
  Future<Uint8List> build(ReceiptPrintPayload payload) async {
    final doc = pw.Document();
    final widthMm = payload.format.paperWidthMm;
    final pageFormat = PdfPageFormat(
      widthMm * PdfPageFormat.mm,
      double.infinity,
      marginAll: 3 * PdfPageFormat.mm,
    );

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (context) => _buildContent(payload, widthMm),
      ),
    );

    return doc.save();
  }

  pw.Widget _buildContent(ReceiptPrintPayload payload, double widthMm) {
    final fontSize = widthMm <= 58 ? 8.0 : 9.0;
    final titleSize = widthMm <= 58 ? 10.0 : 12.0;
    final money = (int amount) =>
        MoneyFormatter.format(amount, currencyCode: payload.currency);
    final date = _formatDate(payload.date);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (payload.company.name != null)
          pw.Text(
            payload.company.name!,
            style: pw.TextStyle(fontSize: titleSize, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
        if (payload.company.legalName != null && payload.company.legalName != payload.company.name)
          pw.Text(payload.company.legalName!, style: pw.TextStyle(fontSize: fontSize)),
        if (payload.company.taxId != null)
          pw.Text('NIF: ${payload.company.taxId}', style: pw.TextStyle(fontSize: fontSize - 1)),
        if (payload.branch.name != null)
          pw.Text(payload.branch.name!, style: pw.TextStyle(fontSize: fontSize)),
        pw.SizedBox(height: 6),
        pw.Divider(thickness: 0.5),
        pw.SizedBox(height: 4),
        _row('N°', payload.documentNumber, fontSize),
        _row('Vente', payload.saleReference, fontSize),
        _row('Date', date, fontSize),
        if (payload.cashier?.name != null)
          _row('Caissier', payload.cashier!.name!, fontSize),
        if (payload.customer?.name != null)
          _row('Client', payload.customer!.name!, fontSize),
        pw.SizedBox(height: 4),
        pw.Divider(thickness: 0.5),
        pw.SizedBox(height: 4),
        ...payload.items.map((item) => _itemBlock(item, money, fontSize)),
        pw.SizedBox(height: 4),
        pw.Divider(thickness: 0.5),
        _totalRow('Sous-total', money(payload.subtotal), fontSize),
        if (payload.discountTotal > 0)
          _totalRow('Remise', '- ${money(payload.discountTotal)}', fontSize),
        if (payload.taxTotal > 0) _totalRow('Taxes', money(payload.taxTotal), fontSize),
        if (payload.feesTotal > 0) _totalRow('Frais', money(payload.feesTotal), fontSize),
        pw.SizedBox(height: 2),
        _totalRow('TOTAL', money(payload.total), fontSize, bold: true),
        pw.SizedBox(height: 4),
        pw.Divider(thickness: 0.5),
        ...payload.payments.map(
          (p) => _row(p.methodLabel, money(p.amount), fontSize),
        ),
        if (payload.change > 0) _row('Monnaie', money(payload.change), fontSize),
        pw.SizedBox(height: 8),
        pw.BarcodeWidget(
          barcode: bw.Barcode.qrCode(),
          data: payload.saleReference,
          width: widthMm <= 58 ? 60 : 80,
          height: widthMm <= 58 ? 60 : 80,
        ),
        if (payload.footer != null) ...[
          pw.SizedBox(height: 6),
          pw.Text(
            payload.footer!,
            style: pw.TextStyle(fontSize: fontSize - 1),
            textAlign: pw.TextAlign.center,
          ),
        ],
        pw.SizedBox(height: 4),
        pw.Text(
          'Merci de votre visite',
          style: pw.TextStyle(fontSize: fontSize - 1),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  pw.Widget _itemBlock(
    ReceiptLineItem item,
    String Function(int) money,
    double fontSize,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            item.name,
            style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold),
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '${item.quantity} x ${money(item.unitPrice)}',
                style: pw.TextStyle(fontSize: fontSize - 1),
              ),
              pw.Text(money(item.lineTotal), style: pw.TextStyle(fontSize: fontSize)),
            ],
          ),
          if (item.lineDiscount > 0)
            pw.Text(
              'Remise: -${money(item.lineDiscount)}',
              style: pw.TextStyle(fontSize: fontSize - 1),
            ),
        ],
      ),
    );
  }

  pw.Widget _row(String label, String value, double fontSize) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('$label:', style: pw.TextStyle(fontSize: fontSize)),
          pw.Flexible(child: pw.Text(value, style: pw.TextStyle(fontSize: fontSize))),
        ],
      ),
    );
  }

  pw.Widget _totalRow(String label, String value, double fontSize, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }
}
