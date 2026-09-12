import 'package:flutter/material.dart';

import '../../../core/config/terminal_config_repository.dart';
import '../domain/printer_models.dart';
import '../domain/receipt_models.dart';
import '../services/receipt_print_service.dart';

class ReceiptPreviewSheet extends StatelessWidget {
  const ReceiptPreviewSheet({
    super.key,
    required this.payload,
    required this.printService,
    this.networkPrinter,
    required this.onPrinted,
  });

  final ReceiptPrintPayload payload;
  final ReceiptPrintService printService;
  final NetworkPrinterConfig? networkPrinter;
  final VoidCallback onPrinted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            payload.isInvoice ? 'Facture' : 'Reçu',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text('N° ${payload.documentNumber}'),
          Text('Total: ${payload.total / 100} ${payload.currency}'),
          const SizedBox(height: 16),
          Text('Format', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _FormatChip(
                label: '58mm',
                format: ReceiptDocumentFormat.thermal58,
                selected: payload.format == ReceiptDocumentFormat.thermal58,
                onSelected: () => _print(context, ReceiptDocumentFormat.thermal58),
              ),
              _FormatChip(
                label: '80mm',
                format: ReceiptDocumentFormat.thermal80,
                selected: payload.format == ReceiptDocumentFormat.thermal80,
                onSelected: () => _print(context, ReceiptDocumentFormat.thermal80),
              ),
              _FormatChip(
                label: 'A4',
                format: ReceiptDocumentFormat.a4,
                selected: payload.format == ReceiptDocumentFormat.a4,
                onSelected: () => _print(context, ReceiptDocumentFormat.a4),
              ),
              _FormatChip(
                label: 'PDF',
                format: ReceiptDocumentFormat.pdf,
                selected: payload.format == ReceiptDocumentFormat.pdf,
                onSelected: () => _exportPdf(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _print(context, payload.format),
            icon: const Icon(Icons.print),
            label: const Text('Imprimer'),
          ),
          if (networkPrinter?.isConfigured == true) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _printNetwork(context),
              icon: const Icon(Icons.print_outlined),
              label: Text('Impression réseau (${networkPrinter!.host})'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _print(BuildContext context, ReceiptDocumentFormat format) async {
    final updated = _copyWithFormat(payload, format);
    final config = TerminalConfigRepository.instance.config;
    final useNetwork = config.printerEnabled && config.printerConnection == PrinterConnection.network.name;
    try {
      await printService.print(
        updated,
        mode: useNetwork ? ReceiptPrintMode.network : ReceiptPrintMode.dialog,
        networkPrinter: networkPrinter,
      );
      onPrinted();
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur impression: $e')),
        );
      }
    }
  }

  Future<void> _printNetwork(BuildContext context) async {
    try {
      await printService.print(
        payload,
        mode: ReceiptPrintMode.network,
        networkPrinter: networkPrinter,
      );
      onPrinted();
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur impression réseau: $e')),
        );
      }
    }
  }

  Future<void> _exportPdf(BuildContext context) async {
    final updated = _copyWithFormat(payload, ReceiptDocumentFormat.pdf);
    try {
      await printService.print(updated, mode: ReceiptPrintMode.pdf);
      onPrinted();
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur export PDF: $e')),
        );
      }
    }
  }

  ReceiptPrintPayload _copyWithFormat(
    ReceiptPrintPayload source,
    ReceiptDocumentFormat format,
  ) {
    return ReceiptPrintPayload(
      documentType: source.documentType,
      format: format,
      company: source.company,
      branch: source.branch,
      receiptNumber: source.receiptNumber,
      invoiceNumber: source.invoiceNumber,
      documentNumber: source.documentNumber,
      saleReference: source.saleReference,
      saleId: source.saleId,
      date: source.date,
      cashier: source.cashier,
      customer: source.customer,
      items: source.items,
      subtotal: source.subtotal,
      discountTotal: source.discountTotal,
      taxTotal: source.taxTotal,
      feesTotal: source.feesTotal,
      total: source.total,
      currency: source.currency,
      payments: source.payments,
      amountPaid: source.amountPaid,
      change: source.change,
      footer: source.footer,
      notes: source.notes,
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({
    required this.label,
    required this.format,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final ReceiptDocumentFormat format;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

Future<void> showReceiptPreviewSheet({
  required BuildContext context,
  required ReceiptPrintPayload payload,
  ReceiptPrintService? printService,
  NetworkPrinterConfig? networkPrinter,
  VoidCallback? onPrinted,
}) {
  final config = TerminalConfigRepository.instance.config;
  final format = config.printerEnabled ? ReceiptDocumentFormat.fromString(config.printerFormat) : payload.format;
  final resolvedPrinter = networkPrinter ??
      NetworkPrinterConfig(
        host: config.printerHost,
        port: config.printerPort,
        enabled: config.printerEnabled && config.printerConnection == PrinterConnection.network.name,
      );

  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ReceiptPreviewSheet(
          payload: payload.format == format ? payload : payload.copyWith(format: format),
          printService: printService ?? ReceiptPrintService(),
          networkPrinter: resolvedPrinter,
          onPrinted: onPrinted ?? () {},
        ),
      ),
    ),
  );
}
