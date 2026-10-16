import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/terminal_config.dart';
import '../../../core/config/terminal_config_repository.dart';
import '../../../data/local/local_database.dart';
import '../domain/print_group.dart';
import '../domain/printer.dart';
import '../domain/printer_connection_type.dart';
import 'printer_connection.dart';

/// Registry CRUD for configured printers (mobile.md §37).
class PrinterManager extends ChangeNotifier {
  PrinterManager({
    PrinterConnection? connection,
    Future<Database> Function()? database,
  })  : _connection = connection ?? const PrinterConnection(),
        _database = database ?? (() => LocalDatabase.instance.database);

  final PrinterConnection _connection;
  final Future<Database> Function() _database;

  static final PrinterManager instance = PrinterManager();

  Future<List<Printer>> list({PrintGroup? group, bool enabledOnly = false}) async {
    final db = await _database();
    final rows = await db.query('lan_printers', orderBy: 'priority ASC, name ASC');
    if (rows.isEmpty) {
      return _seedDefaultIfEmpty();
    }
    var printers = rows.map(Printer.fromRow).toList();
    if (group != null) {
      printers = printers.where((p) => p.group == group).toList();
    }
    if (enabledOnly) {
      printers = printers.where((p) => p.enabled).toList();
    }
    return printers;
  }

  Future<Printer?> findById(String id) async {
    if (id.isEmpty) return null;
    final db = await _database();
    final rows = await db.query('lan_printers', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Printer.fromRow(rows.first);
  }

  Future<List<Printer>> forGroup(PrintGroup group, {bool readyOnly = true}) async {
    final all = await list(group: group, enabledOnly: true);
    final sorted = [...all]..sort((a, b) => a.priority.compareTo(b.priority));
    if (!readyOnly) return sorted;
    return sorted.where((p) => p.isReady).toList();
  }

  Future<Printer> upsert(Printer printer) async {
    // Configuration may be incomplete while the user is editing; strict
    // validation runs at probe / print time via [PrinterConnection].
    final db = await _database();
    final saved = printer.copyWith(
      id: printer.id.isEmpty ? const Uuid().v4() : printer.id,
      updatedAt: DateTime.now(),
    );
    await db.insert(
      'lan_printers',
      saved.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyListeners();
    return saved;
  }

  Future<void> delete(String id) async {
    final db = await _database();
    await db.delete('lan_printers', where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }

  Future<Printer> setOnline(String id, {required bool online, String error = ''}) async {
    final existing = await findById(id);
    if (existing == null) {
      throw StateError('Imprimante introuvable: $id');
    }
    final saved = existing.copyWith(
      online: online,
      lastError: error,
      updatedAt: DateTime.now(),
    );
    final db = await _database();
    await db.update(
      'lan_printers',
      {
        'online': online ? 1 : 0,
        'last_error': error,
        'updated_at': saved.updatedAt!.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    notifyListeners();
    return saved;
  }

  Future<PrinterConnectionResult> probe(String id) async {
    final printer = await findById(id);
    if (printer == null) {
      return PrinterConnectionResult.failure('Imprimante introuvable');
    }
    final result = await _connection.probe(printer);
    await setOnline(id, online: result.ok, error: result.ok ? '' : result.message);
    return result;
  }

  Future<Map<String, PrinterConnectionResult>> probeAll() async {
    final printers = await list(enabledOnly: true);
    final results = <String, PrinterConnectionResult>{};
    for (final printer in printers) {
      results[printer.id] = await probe(printer.id);
    }
    return results;
  }

  Future<List<Printer>> _seedDefaultIfEmpty() async {
    final config = TerminalConfigRepository.instance.config;
    if (!config.printerEnabled &&
        config.printerHost.isEmpty &&
        config.printerName.isEmpty) {
      return const [];
    }
    final printer = _defaultFromConfig(config);
    await upsert(printer);
    return [printer];
  }

  /// Keeps the `default-cashier` printer aligned with the settings screen.
  Future<Printer> syncDefaultFromConfig() async {
    final config = TerminalConfigRepository.instance.config;
    final existing = await findById(_defaultId);
    final printer = _defaultFromConfig(config).copyWith(
      group: existing?.group,
      priority: existing?.priority,
    );
    return upsert(printer);
  }

  static const defaultPrinterId = 'default-cashier';
  static const _defaultId = defaultPrinterId;

  Printer _defaultFromConfig(TerminalConfig config) {
    final connection = switch (config.printerMode) {
      'lan' => PrinterConnectionType.fromString(config.printerConnection),
      'bluetooth' => PrinterConnectionType.bluetooth,
      _ => PrinterConnectionType.system,
    };
    final bluetooth = connection == PrinterConnectionType.bluetooth;
    final network = connection.isNetwork;
    final label = bluetooth ? config.printerBluetoothName : config.printerName;
    return Printer(
      id: _defaultId,
      name: label.isEmpty ? 'Caisse' : label,
      group: PrintGroup.cashier,
      host: network ? config.printerHost : '',
      port: config.printerPort,
      model: config.printerModel,
      connection: connection,
      format: config.printerFormat,
      paperWidthMm: config.printerPaperWidthMm,
      systemName: connection == PrinterConnectionType.system ? config.printerName : '',
      bluetoothAddress: bluetooth ? config.bluetoothPrinterAddress : '',
      enabled: config.printerEnabled,
      priority: 1,
    );
  }
}
