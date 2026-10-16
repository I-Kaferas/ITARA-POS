import 'dart:typed_data';

import 'package:barcode_widget/barcode_widget.dart' as bw;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/money_formatter.dart';
import '../../settings/domain/cashier_preferences.dart';
import '../domain/receipt_models.dart';

class A4InvoiceBuilder {
  static const _ink = PdfColor.fromInt(0xFF12243C);
  static const _muted = PdfColor.fromInt(0xFF5B6B7F);
  static const _line = PdfColor.fromInt(0xFFD9E0E8);
  static const _zebra = PdfColor.fromInt(0xFFF4F6F9);

  Future<Uint8List> build(ReceiptPrintPayload payload) async {
    final doc = pw.Document();
    String money(int amount) => MoneyFormatter.format(amount, currencyCode: payload.currency);
    double size(double value) => CashierPreferences.text(value);
    double gap(double value) => CashierPreferences.space(value);
    final qr = size(72).clamp(64.0, 110.0);

    final invoice = payload.isInvoice;
    final due = payload.total - payload.amountPaid;
    final showDiscount = payload.items.any((item) => item.lineDiscount > 0);
    final showTax = payload.items.any((item) => item.lineTax > 0);
    final address = _address(payload.company.address);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.fromLTRB(36, 36, 36, gap(30)),
        theme: pw.ThemeData.base().copyWith(
          defaultTextStyle: pw.TextStyle(fontSize: size(10), color: _ink),
        ),
        footer: (context) => pw.Container(
          padding: pw.EdgeInsets.only(top: gap(6)),
          decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _line, width: 0.6))),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                [payload.company.name, payload.company.taxId == null ? null : 'NIF ${payload.company.taxId}']
                    .whereType<String>()
                    .where((part) => part.isNotEmpty)
                    .join('  ·  '),
                style: pw.TextStyle(fontSize: size(8), color: _muted),
              ),
              pw.Text(
                'Page ${context.pageNumber} / ${context.pagesCount}',
                style: pw.TextStyle(fontSize: size(8), color: _muted),
              ),
            ],
          ),
        ),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      payload.company.name ?? '',
                      style: pw.TextStyle(fontSize: size(20), fontWeight: pw.FontWeight.bold),
                    ),
                    if ((payload.company.legalName ?? '').isNotEmpty &&
                        payload.company.legalName != payload.company.name)
                      _muted10(payload.company.legalName!, size),
                    if (address.isNotEmpty) _muted10(address, size),
                    if ((payload.company.taxId ?? '').isNotEmpty) _muted10('NIF : ${payload.company.taxId}', size),
                    if ((payload.branch.name ?? '').isNotEmpty) _muted10('Succursale : ${payload.branch.name}', size),
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Container(
                width: 210 + (CashierPreferences.instance.printTextScale - 1) * 40,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _ink, width: 1),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Container(
                      padding: pw.EdgeInsets.symmetric(vertical: gap(8)),
                      decoration: const pw.BoxDecoration(
                        color: _ink,
                        borderRadius: pw.BorderRadius.only(
                          topLeft: pw.Radius.circular(5),
                          topRight: pw.Radius.circular(5),
                        ),
                      ),
                      child: pw.Text(
                        invoice ? 'FACTURE' : 'REÇU DE VENTE',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(color: PdfColors.white, fontSize: size(16), fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(gap(10)),
                      child: pw.Column(
                        children: [
                          _infoRow('N°', payload.documentNumber, size),
                          if (payload.saleReference.isNotEmpty && payload.saleReference != payload.documentNumber)
                            _infoRow('Réf. vente', payload.saleReference, size),
                          _infoRow('Date', _formatDate(payload.date), size),
                          _infoRow('Devise', payload.currency, size),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: gap(22)),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _panel(
                  invoice ? 'Facturé à' : 'Client',
                  [
                    payload.customer?.name ?? 'Client comptant',
                    if ((payload.customer?.phone ?? '').isNotEmpty) payload.customer!.phone!,
                    if ((payload.customer?.email ?? '').isNotEmpty) payload.customer!.email!,
                  ],
                  size,
                  gap,
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _panel('Servi par', [payload.cashier?.name ?? '-'], size, gap),
              ),
            ],
          ),
          pw.SizedBox(height: gap(18)),
          _itemsTable(payload.items, money, size, gap, showDiscount: showDiscount, showTax: showTax),
          pw.SizedBox(height: gap(14)),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Paiement', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: size(11))),
                    pw.SizedBox(height: gap(4)),
                    if (payload.payments.isEmpty) _muted10(invoice ? 'À régler' : '-', size),
                    ...payload.payments.map(
                      (p) => pw.Text('${p.methodLabel.isEmpty ? p.method : p.methodLabel} : ${money(p.amount)}'),
                    ),
                    if (payload.change > 0) pw.Text('Monnaie rendue : ${money(payload.change)}'),
                    if ((payload.notes ?? '').trim().isNotEmpty) ...[
                      pw.SizedBox(height: gap(10)),
                      pw.Text('Notes', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: size(11))),
                      pw.SizedBox(height: gap(2)),
                      pw.Text(payload.notes!.trim()),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Container(
                width: 230 + (CashierPreferences.instance.printTextScale - 1) * 30,
                padding: pw.EdgeInsets.all(gap(10)),
                decoration: pw.BoxDecoration(
                  color: _zebra,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  children: [
                    _summaryRow('Sous-total', money(payload.subtotal), size),
                    if (payload.discountTotal > 0) _summaryRow('Remise', '- ${money(payload.discountTotal)}', size),
                    if (payload.taxTotal > 0) _summaryRow('Taxes', money(payload.taxTotal), size),
                    if (payload.feesTotal > 0) _summaryRow('Frais', money(payload.feesTotal), size),
                    pw.Divider(color: _line),
                    _summaryRow('TOTAL', money(payload.total), size, bold: true, large: true),
                    if (invoice) ...[
                      _summaryRow('Montant payé', money(payload.amountPaid), size),
                      if (due > 0) _summaryRow('Reste à payer', money(due), size, bold: true),
                    ],
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: gap(22)),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if ((payload.footer ?? '').trim().isNotEmpty) pw.Text(payload.footer!.trim()),
                    pw.SizedBox(height: gap(4)),
                    _muted10('Merci de votre confiance.', size),
                  ],
                ),
              ),
              pw.BarcodeWidget(
                barcode: bw.Barcode.qrCode(),
                data: payload.saleReference.isEmpty ? payload.documentNumber : payload.saleReference,
                width: qr,
                height: qr,
              ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _itemsTable(
    List<ReceiptLineItem> items,
    String Function(int) money,
    double Function(double) size,
    double Function(double) gap, {
    required bool showDiscount,
    required bool showTax,
  }) {
    final headers = <(String, double, pw.TextAlign)>[
      ('Article', 4.2, pw.TextAlign.left),
      ('Qté', 0.9, pw.TextAlign.center),
      ('Prix unitaire', 1.7, pw.TextAlign.right),
      if (showDiscount) ('Remise', 1.4, pw.TextAlign.right),
      if (showTax) ('Taxe', 1.4, pw.TextAlign.right),
      ('Total', 1.8, pw.TextAlign.right),
    ];

    pw.Widget cell(String text, pw.TextAlign align, {bool header = false}) => pw.Padding(
          padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: gap(5)),
          child: pw.Text(
            text,
            textAlign: align,
            style: pw.TextStyle(
              fontSize: size(header ? 9 : 9.5),
              color: header ? PdfColors.white : _ink,
              fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        );

    return pw.Table(
      border: const pw.TableBorder(bottom: pw.BorderSide(color: _line, width: 0.6)),
      columnWidths: {
        for (var i = 0; i < headers.length; i++) i: pw.FlexColumnWidth(headers[i].$2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _ink),
          children: [for (final header in headers) cell(header.$1, header.$3, header: true)],
        ),
        for (var index = 0; index < items.length; index++)
          pw.TableRow(
            decoration: pw.BoxDecoration(color: index.isOdd ? _zebra : PdfColors.white),
            children: [
              cell(
                (items[index].sku ?? '').isEmpty ? items[index].name : '${items[index].name}\n${items[index].sku}',
                pw.TextAlign.left,
              ),
              cell('${items[index].quantity}', pw.TextAlign.center),
              cell(money(items[index].unitPrice), pw.TextAlign.right),
              if (showDiscount)
                cell(items[index].lineDiscount > 0 ? money(items[index].lineDiscount) : '-', pw.TextAlign.right),
              if (showTax) cell(items[index].lineTax > 0 ? money(items[index].lineTax) : '-', pw.TextAlign.right),
              cell(money(items[index].lineTotal), pw.TextAlign.right),
            ],
          ),
      ],
    );
  }

  pw.Widget _panel(
    String title,
    List<String> lines,
    double Function(double) size,
    double Function(double) gap,
  ) {
    return pw.Container(
      padding: pw.EdgeInsets.all(gap(10)),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _line, width: 0.8),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title.toUpperCase(), style: pw.TextStyle(fontSize: size(8), color: _muted, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: gap(4)),
          for (var i = 0; i < lines.length; i++)
            pw.Text(
              lines[i],
              style: pw.TextStyle(fontSize: size(i == 0 ? 11 : 9.5), fontWeight: i == 0 ? pw.FontWeight.bold : pw.FontWeight.normal),
            ),
        ],
      ),
    );
  }

  pw.Widget _muted10(String text, double Function(double) size) =>
      pw.Text(text, style: pw.TextStyle(fontSize: size(9.5), color: _muted));

  pw.Widget _infoRow(String label, String value, double Function(double) size) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: size(9), color: _muted)),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(fontSize: size(9.5), fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _summaryRow(
    String label,
    String value,
    double Function(double) size, {
    bool bold = false,
    bool large = false,
  }) {
    final style = pw.TextStyle(
      fontSize: size(large ? 13 : 10),
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [pw.Text(label, style: style), pw.Text(value, style: style)],
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
      address['province'],
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
