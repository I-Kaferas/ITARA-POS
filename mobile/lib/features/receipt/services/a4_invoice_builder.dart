import 'dart:typed_data';

import 'package:barcode_widget/barcode_widget.dart' as bw;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/money_formatter.dart';
import '../domain/receipt_models.dart';

class A4InvoiceBuilder {
  Future<Uint8List> build(ReceiptPrintPayload payload) async {
    final doc = pw.Document();
    final money = (int amount) =>
        MoneyFormatter.format(amount, currencyCode: payload.currency);
    final date = _formatDate(payload.date);
    final title = payload.isInvoice ? 'FACTURE' : 'REÇU DE VENTE';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    payload.company.name ?? '',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  if (payload.company.legalName != null)
                    pw.Text(payload.company.legalName!),
                  if (payload.company.taxId != null)
                    pw.Text('NIF: ${payload.company.taxId}'),
                  if (payload.branch.name != null)
                    pw.Text('Succursale: ${payload.branch.name}'),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    title,
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text('N° ${payload.documentNumber}'),
                  pw.Text('Réf. vente: ${payload.saleReference}'),
                  pw.Text('Date: $date'),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Caissier', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(payload.cashier?.name ?? '—'),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Client', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(payload.customer?.name ?? 'Client comptant'),
                    if (payload.customer?.email != null) pw.Text(payload.customer!.email!),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.5),
              5: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _headerCell('Article'),
                  _headerCell('Qté'),
                  _headerCell('Prix'),
                  _headerCell('Remise'),
                  _headerCell('Taxe'),
                  _headerCell('Total'),
                ],
              ),
              ...payload.items.map(
                (item) => pw.TableRow(
                  children: [
                    _cell(item.name),
                    _cell('${item.quantity}'),
                    _cell(money(item.unitPrice)),
                    _cell(item.lineDiscount > 0 ? money(item.lineDiscount) : '—'),
                    _cell(item.lineTax > 0 ? money(item.lineTax) : '—'),
                    _cell(money(item.lineTotal)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.SizedBox(
                width: 220,
                child: pw.Column(
                  children: [
                    _summaryRow('Sous-total', money(payload.subtotal)),
                    if (payload.discountTotal > 0)
                      _summaryRow('Remise', '- ${money(payload.discountTotal)}'),
                    if (payload.taxTotal > 0) _summaryRow('Taxes', money(payload.taxTotal)),
                    if (payload.feesTotal > 0) _summaryRow('Frais', money(payload.feesTotal)),
                    pw.Divider(),
                    _summaryRow('TOTAL', money(payload.total), bold: true),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text('Paiement', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ...payload.payments.map(
            (p) => pw.Text('${p.methodLabel}: ${money(p.amount)}'),
          ),
          if (payload.change > 0)
            pw.Text('Monnaie rendue: ${money(payload.change)}'),
          pw.SizedBox(height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.BarcodeWidget(
                barcode: bw.Barcode.qrCode(),
                data: payload.saleReference,
                width: 80,
                height: 80,
              ),
            ],
          ),
          if (payload.footer != null) ...[
            pw.SizedBox(height: 16),
            pw.Text(payload.footer!, textAlign: pw.TextAlign.center),
          ],
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _headerCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
    );
  }

  pw.Widget _cell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
    );
  }

  pw.Widget _summaryRow(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
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
