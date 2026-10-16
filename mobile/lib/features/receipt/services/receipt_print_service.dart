import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../core/config/terminal_config_repository.dart';
import '../../../sync/master_print_server.dart';
import '../../../sync/sync_engine.dart';
import '../../printers/domain/print_group.dart';
import '../../printers/domain/printer.dart' as pos;
import '../../printers/services/printer_manager.dart';
import '../../printers/services/printer_router.dart';
import '../../printers/services/raw_printer_output.dart';
import '../domain/receipt_models.dart';
import 'a4_invoice_builder.dart';
import 'thermal_receipt_builder.dart';

enum ReceiptPrintMode {
  /// Printer chosen under « Cet appareil », or the OS print dialog.
  dialog,
  network,
  bluetooth,
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

  /// Paper of a dedicated printer, otherwise the paper chosen in settings.
  static ReceiptDocumentFormat formatFor(pos.Printer? printer) {
    final dedicated = printer != null &&
        printer.id != PrinterManager.defaultPrinterId &&
        printer.format.trim().isNotEmpty;
    return ReceiptDocumentFormat.fromString(
      dedicated ? printer.format : TerminalConfigRepository.instance.config.printerFormat,
    );
  }

  /// [keepFormat] keeps the format chosen by hand (preview sheet, PDF export).
  Future<void> print(
    ReceiptPrintPayload document, {
    ReceiptPrintMode mode = ReceiptPrintMode.dialog,
    NetworkPrinterConfig? networkPrinter,
    String printGroup = 'cashier',
    bool resolvePreferred = true,
    bool keepFormat = false,
  }) async {
    // §40 Document → Printer (receipt / invoice → cashier by default).
    var group = printGroup;
    pos.Printer? routed;
    if (resolvePreferred) {
      try {
        final decision = await PrinterRouter.instance.resolveContext(
          documentType: document.documentType.isEmpty ? 'receipt' : document.documentType,
          fallbackGroup: PrintGroup.fromString(printGroup),
        );
        group = decision.group.name;
        routed = decision.primary;
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

    final payload = keepFormat ? document : document.copyWith(format: formatFor(routed));

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
        await _printToSystem(bytes, payload, name);
      case ReceiptPrintMode.bluetooth:
        final address = TerminalConfigRepository.instance.config.bluetoothPrinterAddress;
        if (address.isEmpty) {
          throw StateError('Imprimante Bluetooth non configurée');
        }
        await RawPrinterOutput.instance.printPdf(
          bytes,
          RawPrinterTarget.bluetooth(address),
          paperWidthMm: payload.format.paperWidthMm.round(),
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
        if (config.printsOverNetwork || config.printsOverBluetooth) {
          await print(
            payload,
            mode: config.printsOverBluetooth
                ? ReceiptPrintMode.bluetooth
                : ReceiptPrintMode.network,
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
    if (config.printsOverBluetooth) return ReceiptPrintMode.bluetooth;
    if (networkPrinter?.isConfigured == true || config.printsOverNetwork) {
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
    await RawPrinterOutput.instance.printPdf(
      bytes,
      RawPrinterTarget.network(config.host, port: config.port),
      paperWidthMm: payload.format.paperWidthMm.round(),
    );
  }

  /// Uses the printer picked in settings; the OS dialog when none is picked
  /// or when the platform cannot address printers by name (Android, iOS).
  Future<void> _printToSystem(
    Uint8List bytes,
    ReceiptPrintPayload payload,
    String name,
  ) async {
    final config = TerminalConfigRepository.instance.config;
    final wanted = config.printerEnabled && config.printerMode == 'system'
        ? config.printerName.trim()
        : '';
    if (wanted.isNotEmpty) {
      final info = await Printing.info();
      if (info.canListPrinters && info.directPrint) {
        final printers = await Printing.listPrinters();
        final match = printers.where((item) => item.name == wanted).firstOrNull;
        if (match != null) {
          final done = await Printing.directPrintPdf(
            printer: match,
            onLayout: (_) async => bytes,
            name: name,
            format: _pageFormat(payload),
          );
          if (done) return;
        }
      }
    }
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: name,
      format: _pageFormat(payload),
    );
  }

  PdfPageFormat _pageFormat(ReceiptPrintPayload payload) {
    if (payload.format == ReceiptDocumentFormat.thermal58) {
      return PdfPageFormat(
        58 * PdfPageFormat.mm,
        double.infinity,
        marginAll: 2 * PdfPageFormat.mm,
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
