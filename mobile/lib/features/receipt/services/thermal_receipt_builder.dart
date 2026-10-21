import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

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
    final thermal = payload.format.isThermal;
    final layout = _RollLayout.of(thermal ? payload.format : ReceiptDocumentFormat.thermal80);
    final pageFormat = thermal
        ? PdfPageFormat(
            payload.format.paperWidthMm * PdfPageFormat.mm,
            double.infinity,
            marginAll: layout.marginMm * PdfPageFormat.mm,
          )
        : PdfPageFormat.a4;

    final logo = await _logoBytes(payload.company.logoUrl);
    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: thermal ? null : const pw.EdgeInsets.fromLTRB(36, 28, 36, 28),
        build: (context) => payload.isInvoice ? _invoice(payload, layout, logo) : _souche(payload, layout, logo),
      ),
    );

    return doc.save();
  }

  Future<Uint8List?> _logoBytes(String? url) async {
    final raw = (url ?? '').trim();
    if (raw.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(raw)).timeout(const Duration(seconds: 2));
      if (response.statusCode != 200 || response.bodyBytes.length < 8) return null;
      final bytes = response.bodyBytes;
      final png = bytes[0] == 0x89 && bytes[1] == 0x50;
      final jpeg = bytes[0] == 0xFF && bytes[1] == 0xD8;
      if (!png && !jpeg) return null;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// Customer stub. Layout follows the souche: logo, fiscal identity, lines, totals.
  pw.Widget _souche(ReceiptPrintPayload payload, _RollLayout layout, Uint8List? logo) {
    final body = CashierPreferences.text(layout.body);
    final small = CashierPreferences.text(layout.small);
    final title = CashierPreferences.text(layout.title);
    final company = payload.company;
    final currency = payload.currency.trim().isEmpty ? 'BIF' : payload.currency.trim().toUpperCase();
    final figures = NumberFormat('#,##0', 'en');
    String plain(int minor) => figures.format((minor / 100).round());
    String money(int minor) => '${plain(minor)} $currency';
    final due = (payload.total - payload.amountPaid).clamp(0, payload.total).toInt();
    final htva = payload.taxTotal <= 0
        ? payload.subtotal
        : (payload.subtotal - payload.taxTotal).clamp(0, payload.subtotal).toInt();
    final address = _soucheAddress(company.address);
    final brand = (company.tradeName ?? '').trim().isNotEmpty
        ? company.tradeName!.trim()
        : (company.name ?? '').trim();
    final legal = (company.legalName ?? '').trim();
    final customer = (payload.customer?.name ?? '').trim();
    final customerNif = (payload.customer?.taxId ?? '').trim();
    final cashier = (payload.cashier?.name ?? '').trim();
    final now = DateTime.now();
    final yesNo = (bool value) => value ? 'Oui' : 'Non';

    pw.Widget center(String text, double size, {bool bold = false}) => pw.Text(
          text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
        );
    pw.Widget detail(String text) => pw.Text(text, style: pw.TextStyle(fontSize: small));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        center('SOUCHE', small, bold: true),
        pw.SizedBox(height: 6),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null)
              pw.Container(
                width: 46,
                height: 46,
                margin: const pw.EdgeInsets.only(right: 6),
                child: pw.Image(pw.MemoryImage(logo), fit: pw.BoxFit.contain),
              ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (brand.isNotEmpty)
                    pw.Text(
                      brand.toUpperCase(),
                      style: pw.TextStyle(fontSize: title, fontWeight: pw.FontWeight.bold),
                    ),
                  if (legal.isNotEmpty && legal.toLowerCase() != brand.toLowerCase())
                    pw.Text(
                      legal.toUpperCase(),
                      style: pw.TextStyle(fontSize: small, fontWeight: pw.FontWeight.bold),
                    ),
                  if ((company.fiscalCenter ?? '').trim().isNotEmpty)
                    detail('C. Fiscal: ${company.fiscalCenter!.trim()}'),
                  if ((company.activitySector ?? '').trim().isNotEmpty)
                    detail('Secteur: ${company.activitySector!.trim()}'),
                  if (address.line1.isNotEmpty) detail('Adresse: ${address.line1}'),
                  if (address.line2.isNotEmpty) detail(address.line2),
                  if (address.commune.isNotEmpty) detail('Commune: ${address.commune}'),
                  if ((company.email ?? '').trim().isNotEmpty) detail('Email: ${company.email!.trim()}'),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        detail('NIF: ${(company.taxId ?? '').trim().isEmpty ? '-' : company.taxId!.trim()}'),
        detail('RC: ${(company.registrationNumber ?? '').trim().isEmpty ? '-' : company.registrationNumber!.trim()}'),
        pw.SizedBox(height: 4),
        center(
          'Exo.TVA: ${yesNo(company.vatExempt)} | TVA: ${yesNo(company.vatRegistered)} | TC: ${yesNo(company.subjectToTc)} | PF: ${yesNo(company.subjectToPf)}',
          small,
        ),
        _dashes(1),
        _row('N°', payload.documentNumber, body),
        _row('Invoice Date', _soucheDate(payload.date), body),
        if (payload.saleReference.isNotEmpty) _row('Order Number', payload.saleReference, body),
        _row('Type', _serviceLabel(payload.serviceMode), body),
        if (cashier.isNotEmpty) _row('Served by', cashier, body),
        _dashes(1),
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                customer.isEmpty ? 'Walk-in Customer' : customer,
                style: pw.TextStyle(fontSize: body, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Text('NIF: ${customerNif.isEmpty ? '-' : customerNif}', style: pw.TextStyle(fontSize: body)),
          ],
        ),
        _dashes(1),
        pw.Row(
          children: [
            pw.SizedBox(width: 36, child: pw.Text('QTY', style: pw.TextStyle(fontSize: small, fontWeight: pw.FontWeight.bold))),
            pw.Expanded(child: pw.Text('DESCRIPTION', style: pw.TextStyle(fontSize: small, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(width: 52, child: pw.Text('P.U.', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: small, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(width: 58, child: pw.Text('AMOUNT', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: small, fontWeight: pw.FontWeight.bold))),
          ],
        ),
        pw.Container(height: 1, color: PdfColors.black),
        for (final item in payload.items)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(width: 36, child: pw.Text('${item.quantity} pcs', style: pw.TextStyle(fontSize: small))),
                pw.Expanded(child: pw.Text(item.name, style: pw.TextStyle(fontSize: body, fontWeight: pw.FontWeight.bold))),
                pw.SizedBox(width: 52, child: pw.Text(plain(item.unitPrice), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: small))),
                pw.SizedBox(width: 58, child: pw.Text(plain(item.lineTotal), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: small, fontWeight: pw.FontWeight.bold))),
              ],
            ),
          ),
        _dashes(1),
        _row('Sous-total', money(payload.subtotal), body),
        _row('HTVA', money(htva), body),
        _row('TVA', money(payload.taxTotal), body),
        pw.SizedBox(height: 3),
        pw.Container(height: 1.6, color: PdfColors.black),
        pw.SizedBox(height: 3),
        _row('TOTAL', money(payload.total), title, bold: true),
        pw.Padding(
          padding: pw.EdgeInsets.symmetric(vertical: CashierPreferences.space(1)),
          child: pw.Row(
            children: [
              pw.Text('Amount Due', style: pw.TextStyle(fontSize: body, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: pw.Text(
                  money(due),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(fontSize: body, fontWeight: pw.FontWeight.bold, color: PdfColors.red),
                ),
              ),
            ],
          ),
        ),
        _dashes(1),
        center('Thank You!', body, bold: true),
        center('Thanks for stopping by. See you soon!', small),
        pw.SizedBox(height: 2),
        center('Printed at ${DateFormat('HH:mm:ss').format(now)} on ${DateFormat('dd-MM-yyyy').format(now)}', small),
      ],
    );
  }

  /// Customer invoice. Same identity block as the souche, plus the payment box.
  pw.Widget _invoice(ReceiptPrintPayload payload, _RollLayout layout, Uint8List? logo) {
    final body = CashierPreferences.text(layout.body);
    final small = CashierPreferences.text(layout.small);
    final title = CashierPreferences.text(layout.title);
    final company = payload.company;
    final currency = payload.currency.trim().isEmpty ? 'BIF' : payload.currency.trim().toUpperCase();
    final figures = NumberFormat('#,##0', 'en');
    String plain(int minor) => figures.format((minor / 100).round());
    String money(int minor) => '${plain(minor)} $currency';
    final htva = payload.taxTotal <= 0
        ? payload.subtotal
        : (payload.subtotal - payload.taxTotal).clamp(0, payload.subtotal).toInt();
    final address = _soucheAddress(company.address);
    final brand = (company.tradeName ?? '').trim().isNotEmpty
        ? company.tradeName!.trim()
        : (company.name ?? '').trim();
    final legal = (company.legalName ?? '').trim();
    final customer = (payload.customer?.name ?? '').trim();
    final customerNif = (payload.customer?.taxId ?? '').trim();
    final cashier = (payload.cashier?.name ?? '').trim();
    final now = DateTime.now();
    final yesNo = (bool value) => value ? 'Oui' : 'Non';

    pw.Widget center(String text, double size, {bool bold = false}) => pw.Text(
          text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
        );
    pw.Widget detail(String text) => pw.Text(text, style: pw.TextStyle(fontSize: small));

    String paymentName(ReceiptPaymentLine payment) {
      final label = payment.methodLabel.trim();
      final code = payment.method.trim().toLowerCase();
      if (label.isNotEmpty && label.toLowerCase() != code) return label;
      return switch (code) {
        'cash' => 'Cash',
        'card' => 'Card',
        'mobile_money' => 'Mobile Money',
        'bank_transfer' => 'Bank',
        'credit' => 'Credit',
        'wallet' => 'Wallet',
        'room' => 'Séjour',
        _ => label.isEmpty ? '-' : label,
      };
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        center('INVOICE', title, bold: true),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null)
              pw.Container(
                width: 52,
                height: 52,
                margin: const pw.EdgeInsets.only(right: 8),
                child: pw.Image(pw.MemoryImage(logo), fit: pw.BoxFit.contain),
              ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (brand.isNotEmpty)
                    pw.Text(
                      brand.toUpperCase(),
                      style: pw.TextStyle(fontSize: title, fontWeight: pw.FontWeight.bold),
                    ),
                  if (legal.isNotEmpty && legal.toLowerCase() != brand.toLowerCase())
                    pw.Text(
                      legal.toUpperCase(),
                      style: pw.TextStyle(fontSize: small, fontWeight: pw.FontWeight.bold),
                    ),
                  if ((company.fiscalCenter ?? '').trim().isNotEmpty)
                    detail('C. Fiscal: ${company.fiscalCenter!.trim()}'),
                  if ((company.activitySector ?? '').trim().isNotEmpty)
                    detail('Secteur: ${company.activitySector!.trim()}'),
                  if (address.line1.isNotEmpty) detail('Adresse: ${address.line1}'),
                  if (address.line2.isNotEmpty) detail(address.line2),
                  if (address.commune.isNotEmpty) detail('Commune: ${address.commune}'),
                  if ((company.email ?? '').trim().isNotEmpty) detail('Email: ${company.email!.trim()}'),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        detail('NIF: ${(company.taxId ?? '').trim().isEmpty ? '-' : company.taxId!.trim()}'),
        detail('RC: ${(company.registrationNumber ?? '').trim().isEmpty ? '-' : company.registrationNumber!.trim()}'),
        pw.SizedBox(height: 4),
        center(
          'Exo.TVA: ${yesNo(company.vatExempt)} | TVA: ${yesNo(company.vatRegistered)} | TC: ${yesNo(company.subjectToTc)} | PF: ${yesNo(company.subjectToPf)}',
          small,
        ),
        _dashes(1),
        _row('N°', payload.documentNumber, body),
        _row('Invoice Date', _soucheDate(payload.date), body),
        _row('Type', _serviceLabel(payload.serviceMode), body),
        _row('Served by', cashier.isEmpty ? '-' : cashier, body),
        _row('Cashier', cashier.isEmpty ? '-' : cashier, body),
        _dashes(1),
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                customer.isEmpty ? 'Walk-in Customer' : customer,
                style: pw.TextStyle(fontSize: body, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Text('NIF: ${customerNif.isEmpty ? '-' : customerNif}', style: pw.TextStyle(fontSize: body)),
          ],
        ),
        _dashes(1),
        pw.Row(
          children: [
            pw.SizedBox(width: 36, child: pw.Text('QTY', style: pw.TextStyle(fontSize: small, fontWeight: pw.FontWeight.bold))),
            pw.Expanded(child: pw.Text('DESCRIPTION', style: pw.TextStyle(fontSize: small, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(width: 52, child: pw.Text('P.U.', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: small, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(width: 58, child: pw.Text('AMOUNT', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: small, fontWeight: pw.FontWeight.bold))),
          ],
        ),
        pw.Container(height: 1, color: PdfColors.black),
        for (final item in payload.items)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(width: 36, child: pw.Text('${item.quantity} pcs', style: pw.TextStyle(fontSize: small))),
                pw.Expanded(child: pw.Text(item.name, style: pw.TextStyle(fontSize: body, fontWeight: pw.FontWeight.bold))),
                pw.SizedBox(width: 52, child: pw.Text(plain(item.unitPrice), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: small))),
                pw.SizedBox(width: 58, child: pw.Text(plain(item.lineTotal), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: small, fontWeight: pw.FontWeight.bold))),
              ],
            ),
          ),
        _dashes(1),
        _row('Sous-total', money(payload.subtotal), body),
        _row('HTVA', money(htva), body),
        _row('TVA', money(payload.taxTotal), body),
        pw.SizedBox(height: 3),
        pw.Container(height: 1.6, color: PdfColors.black),
        pw.SizedBox(height: 3),
        _row('TOTAL', money(payload.total), title, bold: true),
        pw.SizedBox(height: 6),
        pw.Container(
          padding: const pw.EdgeInsets.fromLTRB(8, 6, 8, 6),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text('PAYMENT SUMMARY', style: pw.TextStyle(fontSize: body, fontWeight: pw.FontWeight.bold)),
              if (payload.payments.isEmpty) _row('-', money(0), body),
              for (final payment in payload.payments) _row(paymentName(payment), money(payment.amount), body),
            ],
          ),
        ),
        _dashes(1),
        center('Thank You!', body, bold: true),
        center('Thanks for stopping by. See you soon!', small),
        pw.SizedBox(height: 2),
        center('Printed at ${DateFormat('HH:mm:ss').format(now)} on ${DateFormat('dd-MM-yyyy').format(now)}', small),
      ],
    );
  }

  ({String line1, String line2, String commune}) _soucheAddress(dynamic address) {
    if (address is Map) {
      String field(String key) => address[key]?.toString().trim() ?? '';
      final quarter = field('quarter');
      final avenue = field('avenue');
      final number = field('number');
      final street = field('street');
      final line1 = [
        if (quarter.isNotEmpty) 'Q. $quarter',
        if (avenue.isNotEmpty) 'Av. $avenue',
      ].join(',');
      final line2 = [number, street].where((part) => part.isNotEmpty).join(' ');
      final commune = field('commune');
      if (line1.isNotEmpty || line2.isNotEmpty || commune.isNotEmpty) {
        return (line1: line1, line2: line2, commune: commune);
      }
    }
    final text = _address(address);
    return (line1: text, line2: '', commune: '');
  }

  String _soucheDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('dd/MM/yyyy HH:mm').format(parsed.toLocal());
  }

  String _serviceLabel(String mode) {
    switch (mode.trim().toLowerCase()) {
      case 'takeaway':
      case 'take_away':
      case 'emporter':
        return 'Takeaway';
      case 'delivery':
      case 'livraison':
        return 'Delivery';
      case 'dine_in':
      case 'dine-in':
      case 'dine in':
      case '':
        return 'Dine In';
      default:
        return mode;
    }
  }


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

}
