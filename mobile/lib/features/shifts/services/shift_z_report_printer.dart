import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/config/app_config.dart';
import '../../../core/utils/money_formatter.dart';
import '../domain/shift_models.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

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

  Future<void> printSessionReport(SessionPerformance report) async {
    final currency = report.currency;
    final doc = pw.Document();
    final end = report.closedAt ?? DateTime.now();
    final printedAt = DateTime.now();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(48, 36, 48, 36),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              report.companyName,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text(
              tr('RAPPORT DE PERFORMANCE DE SESSION'),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Center(child: pw.Text('${tr('Utilisateur')} : ${report.userName}', style: const pw.TextStyle(fontSize: 11))),
          pw.Center(child: pw.Text('${tr('Session')} : ${report.sessionCode}', style: const pw.TextStyle(fontSize: 11))),
          pw.SizedBox(height: 8),
          pw.Center(child: pw.Text(tr('Période'), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
          pw.Center(child: pw.Text('${tr('Du')} ${_fmt(report.openedAt)}', style: const pw.TextStyle(fontSize: 11))),
          pw.Center(child: pw.Text('${tr('Au')} ${_fmt(end)}', style: const pw.TextStyle(fontSize: 11))),
          pw.Center(child: pw.Text('${tr('Durée')} : ${_duration(report.openedAt, end)}', style: const pw.TextStyle(fontSize: 11))),
          pw.SizedBox(height: 8),
          _section(tr('Synthèse générale')),
          _stat(tr('Magasins'), '${report.stores}'),
          _stat(tr('Total commandes'), '${report.orders}'),
          _stat(tr('Chiffre d\'affaires brut'), _sessionMoney(report.gross, currency), emphasize: true),
          _stat(tr('Factures payées'), '${report.paidInvoices}'),
          _stat(tr('Montant encaissé'), _sessionMoney(report.collected, currency), emphasize: true),
          _stat(tr('Factures à crédit'), '${report.creditInvoices}'),
          _stat(tr('Crédit en attente'), _sessionMoney(report.outstanding, currency)),
          for (final department in report.departments) ...[
            pw.SizedBox(height: 8),
            _section(department.name.toUpperCase()),
            _stat(tr('Commandes'), '${department.orders}'),
            _stat(tr('Chiffre d\'affaires brut'), _sessionMoney(department.gross, currency)),
            _stat(tr('Factures payées'), '${department.paidInvoices}'),
            _stat(tr('Revenu net'), _sessionMoney(department.net, currency)),
            _stat(tr('Factures à crédit'), '${department.creditInvoices}'),
            _stat(tr('Montant dû'), _sessionMoney(department.amountDue, currency)),
          ],
          pw.SizedBox(height: 8),
          _section(tr('Synthèse des paiements')),
          if (report.payments.isEmpty)
            _stat(tr('Aucun paiement'), _sessionMoney(0, currency))
          else
            ...report.payments.map((line) => _stat(tr(line.label), _sessionMoney(line.amount, currency))),
          _stat(tr('TOTAL ENCAISSÉ'), _sessionMoney(report.collected, currency), emphasize: true),
          _stat(tr('TOTAL CRÉDIT'), _sessionMoney(report.outstanding, currency), emphasize: true),
          pw.SizedBox(height: 8),
          _section(tr('Indicateurs de performance')),
          _stat(tr('Panier moyen'), _sessionMoney(_average(report.gross, report.orders), currency)),
          _stat(tr('Facture payée moyenne'), _sessionMoney(_average(report.collected, report.paidInvoices), currency)),
          _stat(tr('Taux de paiement'), _rate(report.collected, report.gross)),
          _stat(tr('Taux de crédit'), _rate(report.outstanding, report.gross)),
          pw.SizedBox(height: 8),
          _section(tr('TOP 5 PRODUITS VENDUS')),
          if (report.topProducts.isEmpty)
            _stat(tr('Aucun article'), '0')
          else
            ...report.topProducts.map((product) => _stat(product.name, '${product.quantity}')),
          pw.SizedBox(height: 8),
          _section(tr('Informations de contrôle')),
          pw.Center(child: pw.Text('${tr('Session ouverte')} : ${_fmt(report.openedAt)}', style: const pw.TextStyle(fontSize: 11))),
          pw.Center(child: pw.Text('${tr('Session fermée')} : ${_fmt(report.closedAt)}', style: const pw.TextStyle(fontSize: 11))),
          pw.Center(child: pw.Text('${tr('Imprimé le')} : ${_fmt(printedAt)}', style: const pw.TextStyle(fontSize: 11))),
          pw.Center(child: pw.Text('${tr('Imprimé par')} : ${report.userName}', style: const pw.TextStyle(fontSize: 11))),
          pw.SizedBox(height: 22),
          pw.Center(
            child: pw.Text(
              trf('Rapport généré automatiquement par {0} ERP', [report.companyName]),
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ),
          pw.Center(
            child: pw.Text(
              tr('Les montants reflètent les opérations validées durant la période.'),
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ),
          pw.Center(
            child: pw.Text(report.website, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: 'session-${report.sessionCode}',
    );
  }

  pw.Widget _section(String title) {
    return pw.Column(
      children: [
        pw.Container(height: 0.6, color: PdfColors.grey600),
        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(height: 6),
      ],
    );
  }

  pw.Widget _stat(String label, String value, {bool emphasize = false}) {
    final style = pw.TextStyle(fontSize: 11, fontWeight: emphasize ? pw.FontWeight.bold : pw.FontWeight.normal);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Text(label, style: style)),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  String _sessionMoney(int minor, String currency) {
    final rounded = (minor / 100).round();
    final text = NumberFormat('#,##0', 'fr').format(rounded);
    return '$text $currency';
  }

  int _average(int total, int count) {
    if (count <= 0) return 0;
    return (total / count).round();
  }

  String _rate(int part, int whole) {
    if (whole <= 0) return '0.00 %';
    return '${(part / whole * 100).toStringAsFixed(2)} %';
  }

  String _duration(DateTime start, DateTime end) {
    final mins = end.difference(start).inMinutes.clamp(0, 99999);
    if (mins < 60) return '${mins}min';
    final hours = mins ~/ 60;
    final rest = mins % 60;
    return rest == 0 ? '${hours}h' : '${hours}h ${rest}min';
  }
}
