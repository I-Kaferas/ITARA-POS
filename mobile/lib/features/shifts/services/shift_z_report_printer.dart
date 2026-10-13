import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/config/app_config.dart';
import '../../../core/utils/money_formatter.dart';
import '../domain/shift_models.dart';

class ShiftZReportPrinter {
  ShiftZReportPrinter();

  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  Future<void> printReport({
    required String registerName,
    required SessionSummary report,
  }) async {
    final doc = pw.Document();
    final currency = AppConfig.currencyCode;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text('Rapport de shift', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(registerName, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
          pw.SizedBox(height: 12),
          pw.Text('Ouverture: ${_fmt(report.openedAt)}'),
          pw.Text('Clôture: ${_fmt(report.closedAt)}'),
          pw.SizedBox(height: 16),
          pw.Text('Résumé caisse', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _row('Fonds d\'ouverture', MoneyFormatter.format(report.openingBalance, currencyCode: currency)),
          _row('Total ventes', MoneyFormatter.format(report.salesTotal, currencyCode: currency)),
          _row('Entrées de caisse', MoneyFormatter.format(report.cashInTotal, currencyCode: currency)),
          _row('Sorties de caisse', MoneyFormatter.format(report.cashOutTotal, currencyCode: currency)),
          _row('Dépenses', MoneyFormatter.format(report.expensesTotal, currencyCode: currency)),
          _row('Espèces attendues', MoneyFormatter.format(report.expectedCash, currencyCode: currency)),
          _row('Espèces comptées', MoneyFormatter.format(report.actualCash ?? 0, currencyCode: currency)),
          _row('Écart', MoneyFormatter.format(report.variance ?? 0, currencyCode: currency)),
          pw.SizedBox(height: 18),
          pw.Text('Par moyen de paiement', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          if (report.paymentMethods.isEmpty)
            pw.Text('Aucun paiement')
          else
            ...report.paymentMethods.map(
              (p) => _row(
                '${p.label} (${p.count})',
                MoneyFormatter.format(p.amount, currencyCode: currency),
              ),
            ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Factures (${report.invoicesCount}) — Total ${MoneyFormatter.format(report.invoicesTotal, currencyCode: currency)}',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          if (report.invoices.isEmpty)
            pw.Text('Aucune facture')
          else
            ...report.invoices.map(
              (inv) => _row(
                '${inv.reference} · ${_fmt(inv.completedAt)}',
                MoneyFormatter.format(inv.total, currencyCode: inv.currency ?? currency),
              ),
            ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: 'rapport-shift-$registerName',
    );
  }

  pw.Widget _row(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          ),
          pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> printHandover({
    required String sessionCode,
    required String cashier,
    required String duration,
    required SessionSummary report,
  }) async {
    final handover = report.handover;
    final currency = handover.currency;
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text('Situation & Remise de Caisse', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Session $sessionCode · Caissier : $cashier · $duration', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.SizedBox(height: 16),
          pw.Text('Synthèse des ventes & articles', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _row('Articles vendus', '${handover.articlesSold}'),
          _row('À crédit (articles)', '${handover.articlesOnCredit}'),
          _row('Chiffre d\'affaires', _handoverMoney(handover.soldTotal > 0 ? handover.soldTotal : report.salesTotal, currency)),
          _row('Commandes traitées', '${handover.ordersCount}'),
          _row('Magasins concernés', '${handover.storesCount}'),
          _row('Ventes à crédit', _handoverMoney(handover.creditSalesTotal, currency)),
          _row('Commandes à crédit', '${handover.creditOrdersCount}'),
          pw.SizedBox(height: 18),
          pw.Text('Articles vendus & stocks par magasin', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (handover.stores.isEmpty)
            pw.Text('Aucun article vendu durant cette session.')
          else
            ...handover.stores.expand((store) => [
                  pw.SizedBox(height: 8),
                  pw.Text('${store.name} · ${store.articlesCount} article(s)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  ...store.lines.map(
                    (line) => _row(
                      '${line.name}${line.code.isEmpty ? '' : ' · ${line.code}'} · vendu ${line.sold} · reste ${line.remaining ?? '—'}${line.creditQty > 0 ? ' · ${line.creditQty} à crédit' : ''}',
                      _handoverMoney(line.total, currency, withCode: false),
                    ),
                  ),
                ]),
          pw.SizedBox(height: 10),
          _row('Total articles vendus', _handoverMoney(handover.soldTotal > 0 ? handover.soldTotal : report.salesTotal, currency)),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: 'remise-$sessionCode',
    );
  }

  String _handoverMoney(int minor, String currency, {bool withCode = true}) {
    final major = minor / 100;
    final whole = (major - major.round()).abs() < 0.001;
    final text = NumberFormat(whole ? '#,##0' : '#,##0.00', 'fr').format(whole ? major.round() : major);
    return withCode ? '$text $currency' : text;
  }

  String _fmt(DateTime? value) {
    if (value == null) return '—';
    return _dateFormat.format(value.toLocal());
  }
}
