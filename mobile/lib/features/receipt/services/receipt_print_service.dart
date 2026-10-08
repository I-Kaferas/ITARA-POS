import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../core/config/terminal_config_repository.dart';
import '../../../sync/master_print_server.dart';
import '../../../sync/sync_engine.dart';
import '../../printers/domain/print_group.dart';
import '../../printers/services/printer_router.dart';
import '../domain/receipt_models.dart';
import 'a4_invoice_builder.dart';
import 'thermal_receipt_builder.dart';

enum ReceiptPrintMode {
  dialog,
  network,
  pdf,
  /// Central Master print server (§43) — local spooler on Master, HTTP on Slave.
  masterQueue,
}

class ReceiptPrintService {
  ReceiptPrintService({
    ThermalReceiptBuilder? thermalBuilder,
    A4InvoiceBuilder? a4Builder,
    MasterPrintServer? masterPrintServer,
  })  : _thermalBuilder = thermalBuilder ?? ThermalReceiptBuilder(),
        _a4Builder = a4Builder ?? A4InvoiceBuilder(),
        _masterPrintServerOverride = masterPrintServer;

  final ThermalReceiptBuilder _thermalBuilder;
  final A4InvoiceBuilder _a4Builder;
  final MasterPrintServer? _masterPrintServerOverride;

  MasterPrintServer get _masterPrintServer =>
      _masterPrintServerOverride ?? MasterPrintServer.instance;

  Future<void> print(
    ReceiptPrintPayload payload, {
    ReceiptPrintMode mode = ReceiptPrintMode.dialog,
    NetworkPrinterConfig? networkPrinter,
    String printGroup = 'cashier',
    bool resolvePreferred = true,
  }) async {
    // §40 Document → Printer (receipt / invoice → cashier by default).
    var group = printGroup;
    if (resolvePreferred) {
      try {
        final decision = await PrinterRouter.instance.resolveContext(
          documentType: payload.documentType.isEmpty ? 'receipt' : payload.documentType,
          fallbackGroup: PrintGroup.fromString(printGroup),
        );
        group = decision.group.name;
        if (networkPrinter == null && decision.primary != null) {
          final printer = decision.primary!;
          if (printer.host.isNotEmpty) {
            networkPrinter = NetworkPrinterConfig(
              host: printer.host,
              port: printer.port,
              enabled: printer.enabled,
            );
          }
        }
      } catch (_) {}
    }

    final effectiveMode =
        mode == ReceiptPrintMode.dialog && resolvePreferred
            ? _preferredMode(networkPrinter)
            : mode;

    if (effectiveMode == ReceiptPrintMode.masterQueue) {
      await _masterPrintServer.enqueueReceipt(payload, group: group);
      return;
    }

    final bytes = await buildPdf(payload);
    final name = '${payload.documentType}-${payload.documentNumber}';

    switch (effectiveMode) {
      case ReceiptPrintMode.dialog:
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name: name,
          format: _pageFormat(payload),
        );
      case ReceiptPrintMode.network:
        final config = TerminalConfigRepository.instance.config;
        await _printToNetwork(
          bytes,
          payload,
          networkPrinter ??
              NetworkPrinterConfig(
                host: config.printerHost,
                port: config.printerPort,
                enabled: config.printerEnabled || config.printerHost.isNotEmpty,
              ),
        );
      case ReceiptPrintMode.pdf:
        await Printing.sharePdf(bytes: bytes, filename: '$name.pdf');
      case ReceiptPrintMode.masterQueue:
        break;
    }
  }

  /// §41 / §74 — never throws. Sale / checkout must not fail because of printing.
  ///
  /// Tries the preferred path, then falls back to local network / dialog.
  Future<bool> tryPrint(
    ReceiptPrintPayload payload, {
    ReceiptPrintMode mode = ReceiptPrintMode.dialog,
    NetworkPrinterConfig? networkPrinter,
    String printGroup = 'cashier',
  }) async {
    try {
      await print(
        payload,
        mode: mode,
        networkPrinter: networkPrinter,
        printGroup: printGroup,
      );
      return true;
    } catch (_) {
      // Failover: master queue → direct network → system dialog (never abort sale).
      try {
        final config = TerminalConfigRepository.instance.config;
        if (config.printerEnabled && config.printerHost.isNotEmpty) {
          await print(
            payload,
            mode: ReceiptPrintMode.network,
            resolvePreferred: false,
          );
          return true;
        }
        await print(
          payload,
          mode: ReceiptPrintMode.dialog,
          resolvePreferred: false,
        );
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  /// §43 — Master always centralizes; Slave uses Master when reachable.
  ReceiptPrintMode _preferredMode(NetworkPrinterConfig? networkPrinter) {
    final config = TerminalConfigRepository.instance.config;
    if (config.isMaster && _masterPrintServer.isAvailable) {
      return ReceiptPrintMode.masterQueue;
    }
    if (config.isSlave &&
        config.masterHost.isNotEmpty &&
        SyncEngine.instance.masterReachable) {
      return ReceiptPrintMode.masterQueue;
    }
    if (networkPrinter?.isConfigured == true ||
        (config.printerEnabled && config.printerHost.isNotEmpty)) {
      return ReceiptPrintMode.network;
    }
    return ReceiptPrintMode.dialog;
  }

  Future<Uint8List> buildPdf(ReceiptPrintPayload payload) async {
    if (payload.format.isThermal) {
      return _thermalBuilder.build(payload);
    }
    return _a4Builder.build(payload);
  }

  Future<List<Printer>> listPrinters() => Printing.listPrinters();

  Future<void> _printToNetwork(
    Uint8List bytes,
    ReceiptPrintPayload payload,
    NetworkPrinterConfig? config,
  ) async {
    if (config == null || !config.isConfigured) {
      throw StateError('Imprimante réseau non configurée');
    }

    final printer = Printer(
      url: 'socket://${config.host}:${config.port}',
      name: 'POS-${config.host}',
      isAvailable: true,
    );

    await Printing.directPrintPdf(
      printer: printer,
      onLayout: (_) async => bytes,
      format: _pageFormat(payload),
    );
  }

  PdfPageFormat _pageFormat(ReceiptPrintPayload payload) {
    if (payload.format == ReceiptDocumentFormat.thermal58) {
      return PdfPageFormat(
        58 * PdfPageFormat.mm,
        double.infinity,
        marginAll: 3 * PdfPageFormat.mm,
      );
    }
    if (payload.format == ReceiptDocumentFormat.thermal80) {
      return PdfPageFormat(
        80 * PdfPageFormat.mm,
        double.infinity,
        marginAll: 3 * PdfPageFormat.mm,
      );
    }
    return PdfPageFormat.a4;
  }
}
