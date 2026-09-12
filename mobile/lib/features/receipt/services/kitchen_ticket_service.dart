import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../pos/domain/pos_models.dart';

class KitchenTicketService {
  Future<void> printHeldSale(PosHeldSale sale) async {
    final doc = pw.Document();
    final date = DateFormat('dd/MM/yyyy HH:mm').format(sale.heldAt);

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
              'BON DE CUISINE',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(sale.label, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10)),
            pw.Text(date, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9)),
            if (sale.customer != null) ...[
              pw.SizedBox(height: 4),
              pw.Text('Client: ${sale.customer!.name}', style: const pw.TextStyle(fontSize: 9)),
            ],
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 0.6),
            ...sale.lines.map(
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

    final bytes = await doc.save();
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'bon-cuisine-${sale.id}',
    );
  }
}
