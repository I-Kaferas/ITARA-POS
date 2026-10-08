import '../core/config/terminal_config_repository.dart';
import '../features/printers/domain/print_job.dart';
import '../features/printers/domain/printer.dart';
import '../features/receipt/domain/receipt_models.dart';
import 'local_master_server.dart';
import 'master_print_client.dart';
import 'print_spooler.dart';

/// Centralized Master print hub — mobile.md §43.
///
/// ```text
/// POS 01 ─┐
/// POS 02 ─┼──→ MASTER ──→ PRINTER
/// POS 03 ─┘
/// ```
///
/// - On the **Master** terminal: jobs enter the local [PrintSpooler].
/// - On a **Slave**: jobs are POSTed to the Master's `/print/jobs` API.
class MasterPrintServer {
  MasterPrintServer({
    PrintSpooler? spooler,
    MasterPrintClient? client,
  })  : _spoolerOverride = spooler,
        _clientOverride = client;

  static final MasterPrintServer instance = MasterPrintServer();

  final PrintSpooler? _spoolerOverride;
  final MasterPrintClient? _clientOverride;

  PrintSpooler get _spooler => _spoolerOverride ?? PrintSpooler.instance;
  MasterPrintClient get _client => _clientOverride ?? MasterPrintClient();

  /// Whether this terminal can use the Master print path right now.
  bool get isAvailable {
    final config = TerminalConfigRepository.instance.config;
    // Master always has the local spooler; Slaves need a Master host.
    if (config.isMaster) return true;
    return LocalMasterServer.clientBaseUrl() != null;
  }

  Future<Map<String, dynamic>> enqueueReceipt(
    ReceiptPrintPayload payload, {
    String group = 'cashier',
    String? printerId,
    String? sourceDeviceId,
  }) {
    return enqueue(
      group: group,
      documentType: payload.documentType,
      payload: payload.toJson(),
      printerId: printerId,
      sourceDeviceId: sourceDeviceId,
    );
  }

  Future<Map<String, dynamic>> enqueue({
    required String group,
    required String documentType,
    required Map<String, dynamic> payload,
    String? printerId,
    String? sourceDeviceId,
    String categoryId = '',
    String productId = '',
  }) async {
    final config = TerminalConfigRepository.instance.config;
    final stamped = Map<String, dynamic>.from(payload);
    final deviceId = (sourceDeviceId ?? '').trim().isNotEmpty
        ? sourceDeviceId!.trim()
        : (config.deviceId.isNotEmpty ? config.deviceId : config.deviceIdentifier);
    if (deviceId.isNotEmpty) {
      stamped['_source_device_id'] = deviceId;
    }

    if (config.isMaster) {
      final job = await _spooler.enqueue(
        group: group,
        documentType: documentType,
        payload: stamped,
        printerId: printerId,
        categoryId: categoryId,
        productId: productId,
      );
      return job.toJson();
    }

    return _client.enqueue(
      group: group,
      documentType: documentType,
      payload: stamped,
      printerId: printerId,
    );
  }

  Future<List<Printer>> listPrinters() => _spooler.listPrinters();

  Future<List<PrintJob>> listJobs({int limit = 50}) =>
      _spooler.listJobs(limit: limit);
}
