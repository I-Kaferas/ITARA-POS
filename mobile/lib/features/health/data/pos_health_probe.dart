import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../core/config/terminal_config_repository.dart';
import '../../../data/local/local_database.dart';
import '../../../sync/sync_engine.dart';
import '../domain/pos_health.dart';

class PosHealthProbe {
  static Future<PosHealth> read({Database? database}) async {
    var databaseOpen = false;
    var printersKnown = 0;
    var printersOnline = 0;
    var syncFailed = 0;
    var syncPending = 0;
    try {
      final db = database ?? await LocalDatabase.instance.database;
      await db.rawQuery('SELECT 1');
      databaseOpen = true;
      try {
        final printers = await db.query('lan_printers');
        printersKnown = printers.where((row) => row['enabled'] == 1).length;
        printersOnline = printers
            .where((row) => row['enabled'] == 1 && row['online'] == 1)
            .length;
      } catch (_) {}
      try {
        syncFailed = _count(await db.rawQuery(
          "SELECT COUNT(*) AS c FROM sync_outbox WHERE status IN ('FAILED', 'CONFLICT')",
        ));
        syncPending = _count(await db.rawQuery(
          "SELECT COUNT(*) AS c FROM sync_outbox WHERE status IN ('PENDING', 'SYNCING')",
        ));
      } catch (_) {}
    } catch (_) {
      databaseOpen = false;
    }
    final config = TerminalConfigRepository.instance.config;
    final engine = SyncEngine.instance;
    return PosHealth.resolve(
      databaseOpen: databaseOpen,
      isMaster: config.isMaster,
      masterReachable: engine.masterReachable || config.isMaster,
      internetReachable: engine.cloudReachable,
      cloudReachable: engine.cloudReachable && engine.lastSyncAt != null,
      printersKnown: printersKnown,
      printersOnline: printersOnline,
      syncFailed: syncFailed,
      syncPending: syncPending,
    );
  }

  static int _count(List<Map<String, Object?>> rows) {
    final value = rows.isEmpty ? 0 : rows.first['c'];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
