import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart' as printing;

import '../../../sync/local_realtime.dart';
import '../../receipt/domain/receipt_models.dart';
import '../../receipt/services/receipt_print_service.dart';
import '../domain/print_group.dart';
import '../domain/print_job.dart';
import '../domain/printer.dart';
import '../domain/printer_connection_type.dart';
import 'print_queue.dart';
import 'printer_connection.dart';
import 'printer_failover.dart';
import 'printer_manager.dart';
import 'printer_router.dart';

/// Facade for printer management + queued printing (mobile.md §37 / §41 / §74).
///
/// A print failure never throws out of [enqueue] — jobs stay in the queue.
/// §74 : une panne d’imprimante ne doit jamais annuler une vente.
class PrinterService extends ChangeNotifier {
  PrinterService({
    PrinterManager? manager,
    PrintQueue? queue,
    PrinterRouter? router,
    PrinterConnection? connection,
    ReceiptPrintService? receiptPrinter,
    PrinterFailover? failover,
  })  : _manager = manager ?? PrinterManager.instance,
        _queue = queue ?? PrintQueue.instance,
        _router = router ?? PrinterRouter.instance,
        _connection = connection ?? const PrinterConnection(),
        _receiptPrinter = receiptPrinter ?? ReceiptPrintService(),
        _failover = failover ?? const PrinterFailover();

  final PrinterManager _manager;
  final PrintQueue _queue;
  final PrinterRouter _router;
  final PrinterConnection _connection;
  final ReceiptPrintService _receiptPrinter;
  final PrinterFailover _failover;

  static final PrinterService instance = PrinterService();

  Timer? _worker;
  bool _processing = false;

  PrinterManager get manager => _manager;
  PrintQueue get queue => _queue;
  PrinterRouter get router => _router;
  PrinterConnection get connection => _connection;

  void startWorker() {
    _worker?.cancel();
    _worker = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(processQueue());
    });
    unawaited(processQueue());
    unawaited(_router.seedDefaultRoutes());
  }

  void stopWorker() {
    _worker?.cancel();
    _worker = null;
  }

  Future<List<Printer>> listPrinters({PrintGroup? group}) =>
      _manager.list(group: group);

  Future<Printer> upsertPrinter(Printer printer) async {
    final saved = await _manager.upsert(printer);
    notifyListeners();
    return saved;
  }

  Future<void> deletePrinter(String id) async {
    await _manager.delete(id);
    notifyListeners();
  }

  Future<PrinterConnectionResult> probePrinter(String id) => _manager.probe(id);

  Future<PrintJob> enqueue({
    required String group,
    required String documentType,
    required Map<String, dynamic> payload,
    String? printerId,
    String categoryId = '',
    String productId = '',
  }) async {
    final job = await _queue.enqueue(
      group: PrintGroup.fromString(group),
      documentType: documentType,
      payload: payload,
      printerId: printerId,
      categoryId: categoryId,
      productId: productId,
    );
    LocalRealtimeHub.instance.publish(RealtimeEvent(
      type: RealtimeEventType.printJobQueued,
      payload: job.toJson(),
    ));
    notifyListeners();
    unawaited(processQueue());
    return job;
  }

  Future<List<PrintJob>> listJobs({int limit = 50}) => _queue.list(limit: limit);

  Future<void> processQueue() async {
    if (_processing) return;
    _processing = true;
    try {
      final jobs = await _queue.claimNext(limit: 5);
      for (final job in jobs) {
        await _printOne(job);
      }
    } finally {
      _processing = false;
      notifyListeners();
    }
  }

  Future<void> _printOne(PrintJob job) async {
    final decision = await _router.resolve(job);
    final candidates = decision.printers;
    if (candidates.isEmpty) {
      await _queue.markFailedOrRetry(
        job,
        StateError('Aucune imprimante pour ${decision.group.name}'),
      );
      return;
    }

    final result = await _failover.run(
      candidates: candidates,
      printFn: (printer) async {
        await _queue.markPrinting(job, printerId: printer.id);
        await _sendToPrinter(job, printer);
      },
    );

    for (final attempt in result.attempts) {
      if (attempt.success) {
        await _manager.setOnline(attempt.printer.id, online: true);
      } else {
        await _manager.setOnline(
          attempt.printer.id,
          online: false,
          error: attempt.error?.toString() ?? 'OFFLINE',
        );
      }
    }

    if (result.success && result.printer != null) {
      final printed = await _queue.markPrinted(job, printerId: result.printer!.id);
      LocalRealtimeHub.instance.publish(RealtimeEvent(
        type: RealtimeEventType.printJobDone,
        payload: {
          ...printed.toJson(),
          'failover': result.usedFailover,
          'failed_printer_ids': result.failedPrinterIds,
          'attempts': result.attempts.length,
        },
      ));
      return;
    }

    // Queue keeps the job for retry — never affects the sale (§41).
    await _queue.markFailedOrRetry(
      job,
      result.error ?? StateError('Échec impression ${job.id}'),
    );
  }

  Future<void> _sendToPrinter(PrintJob job, Printer printer) async {
    final validation = _connection.validate(printer);
    if (!validation.ok) {
      throw StateError(validation.message);
    }

    // Kitchen / bar tickets enqueue raw PDF (§40 routing).
    final rawB64 = job.payload['pdf_base64']?.toString();
    if (rawB64 != null && rawB64.isNotEmpty) {
      final bytes = base64Decode(rawB64);
      await _printRawPdf(bytes, printer, name: '${job.documentType}-${job.id}');
      return;
    }

    final payload = ReceiptPrintPayload.fromJson(job.payload);

    switch (printer.connection) {
      case PrinterConnectionType.lan:
      case PrinterConnectionType.ethernet:
      case PrinterConnectionType.wifi:
        await _receiptPrinter.print(
          payload,
          mode: ReceiptPrintMode.network,
          networkPrinter: NetworkPrinterConfig(
            host: printer.host,
            port: printer.port,
            enabled: true,
          ),
        );
      case PrinterConnectionType.system:
      case PrinterConnectionType.usb:
        await _printViaSystem(payload, printer);
      case PrinterConnectionType.bluetooth:
        await _printViaBluetooth(payload, printer);
    }
  }

  Future<void> _printRawPdf(
    List<int> bytes,
    Printer printer, {
    required String name,
  }) async {
    final data = Uint8List.fromList(bytes);
    switch (printer.connection) {
      case PrinterConnectionType.lan:
      case PrinterConnectionType.ethernet:
      case PrinterConnectionType.wifi:
        final target = printing.Printer(
          url: 'socket://${printer.host}:${printer.port}',
          name: printer.name,
          isAvailable: true,
        );
        await printing.Printing.directPrintPdf(
          printer: target,
          onLayout: (_) async => data,
          name: name,
        );
      case PrinterConnectionType.system:
      case PrinterConnectionType.usb:
      case PrinterConnectionType.bluetooth:
        final systemName =
            printer.systemName.isNotEmpty ? printer.systemName : printer.name;
        final printers = await printing.Printing.listPrinters();
        final match = printers.where(
          (item) =>
              item.name == systemName ||
              item.name == printer.name ||
              item.url.contains(printer.host),
        );
        if (match.isEmpty) {
          await printing.Printing.layoutPdf(onLayout: (_) async => data, name: name);
          return;
        }
        await printing.Printing.directPrintPdf(
          printer: match.first,
          onLayout: (_) async => data,
          name: name,
        );
    }
  }

  Future<void> _printViaSystem(ReceiptPrintPayload payload, Printer printer) async {
    final bytes = await _receiptPrinter.buildPdf(payload);
    final name = printer.systemName.isNotEmpty ? printer.systemName : printer.name;
    if (name.isEmpty) {
      await _receiptPrinter.print(payload, mode: ReceiptPrintMode.dialog);
      return;
    }
    final printers = await printing.Printing.listPrinters();
    final match = printers.where((item) => item.name == name).toList();
    if (match.isEmpty) {
      throw StateError('Imprimante système introuvable: $name');
    }
    await printing.Printing.directPrintPdf(
      printer: match.first,
      onLayout: (_) async => bytes,
    );
  }

  Future<void> _printViaBluetooth(
    ReceiptPrintPayload payload,
    Printer printer,
  ) async {
    final bytes = await _receiptPrinter.buildPdf(payload);
    final printers = await printing.Printing.listPrinters();
    final byName = printers.where(
      (item) =>
          item.name == printer.name ||
          item.name == printer.systemName ||
          item.url.contains(printer.bluetoothAddress),
    );
    if (byName.isNotEmpty) {
      await printing.Printing.directPrintPdf(
        printer: byName.first,
        onLayout: (_) async => bytes,
      );
      return;
    }

    final address = printer.bluetoothAddress.trim();
    if (address.isEmpty) {
      throw StateError('Adresse Bluetooth manquante');
    }
    final url = address.startsWith('btspp://') ? address : 'btspp://$address';
    await printing.Printing.directPrintPdf(
      printer: printing.Printer(url: url, name: printer.name, isAvailable: true),
      onLayout: (_) async => bytes,
    );
  }

  /// Network discovery helper used by Master (port 9100 sweep).
  Future<List<Map<String, dynamic>>> discoverNetworkPrinters({
    Duration timeout = const Duration(milliseconds: 350),
    String? baseHost,
  }) {
    return _discoverLan(timeout: timeout, baseHost: baseHost);
  }

  Future<List<Map<String, dynamic>>> _discoverLan({
    required Duration timeout,
    String? baseHost,
  }) async {
    final baseIp = baseHost?.split(':').first ?? await _guessLanIp();
    if (baseIp == null || baseIp.isEmpty) return const [];

    final parts = baseIp.split('.');
    if (parts.length != 4) return const [];
    final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
    final found = <Map<String, dynamic>>[];
    final selfOctet = int.tryParse(parts[3]) ?? 1;

    final candidates = <int>{
      for (var i = 1; i <= 254; i += 1)
        if ((i - selfOctet).abs() <= 20 || i % 10 == 0) i,
    };

    await Future.wait(candidates.map((octet) async {
      final host = '$prefix.$octet';
      if (host == baseIp) return;
      try {
        final socket = await Socket.connect(host, 9100, timeout: timeout);
        await socket.close();
        found.add({
          'host': host,
          'port': 9100,
          'name': 'Printer $host',
          'connection': PrinterConnectionType.lan.name,
        });
      } catch (_) {}
    }));

    found.sort((a, b) => (a['host'] as String).compareTo(b['host'] as String));
    return found;
  }

  Future<String?> _guessLanIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (_) {}
    return null;
  }
}
