import 'package:flutter/foundation.dart';

import '../features/printers/printers.dart';

export '../features/printers/domain/print_job.dart';
export '../features/printers/domain/print_job_status.dart';
export '../features/printers/domain/printer.dart';

/// Backward-compatible alias for [Printer] (Master API / older call sites).
typedef MasterPrinter = Printer;

/// Thin adapter over [PrinterService] — keeps Master server / sync imports stable.
class PrintSpooler extends ChangeNotifier {
  PrintSpooler._();

  static final PrintSpooler instance = PrintSpooler._();

  final PrinterService _service = PrinterService.instance;

  void startWorker() {
    _service.startWorker();
    _service.addListener(notifyListeners);
  }

  void stopWorker() {
    _service.removeListener(notifyListeners);
    _service.stopWorker();
  }

  Future<List<MasterPrinter>> listPrinters() => _service.listPrinters();

  Future<MasterPrinter> upsertPrinter(MasterPrinter printer) =>
      _service.upsertPrinter(printer);

  Future<void> deletePrinter(String id) => _service.deletePrinter(id);

  Future<PrintJob> enqueue({
    required String group,
    required String documentType,
    required Map<String, dynamic> payload,
    String? printerId,
    String categoryId = '',
    String productId = '',
  }) {
    return _service.enqueue(
      group: group,
      documentType: documentType,
      payload: payload,
      printerId: printerId,
      categoryId: categoryId,
      productId: productId,
    );
  }

  Future<List<PrintJob>> listJobs({int limit = 50}) =>
      _service.listJobs(limit: limit);

  Future<void> processQueue() => _service.processQueue();

  Future<List<Map<String, dynamic>>> discoverNetworkPrinters({
    Duration timeout = const Duration(milliseconds: 350),
  }) {
    return _service.discoverNetworkPrinters(timeout: timeout);
  }
}
