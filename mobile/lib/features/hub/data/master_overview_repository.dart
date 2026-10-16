import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../core/config/terminal_config_repository.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../data/local/local_database.dart';
import '../../../sync/cloud/cloud_sync_entity.dart';
import '../../../sync/master_config_store.dart';
import '../../../sync/outbox/sync_outbox.dart';

enum MasterActivityKind { device, sale, cloud, warning, error, server }

class MasterActivity {
  const MasterActivity({
    required this.kind,
    required this.title,
    required this.detail,
    required this.at,
  });

  final MasterActivityKind kind;
  final String title;
  final String detail;
  final DateTime at;
}

class MasterOverview {
  const MasterOverview({
    this.moduleCounts = const {},
    this.ordersToday = 0,
    this.outbox = const {},
    this.databaseOk = false,
    this.activity = const [],
    this.sharedConfig = const {},
  });

  final Map<CloudSyncModule, int> moduleCounts;
  final int ordersToday;
  final Map<String, int> outbox;
  final bool databaseOk;
  final List<MasterActivity> activity;
  final Map<String, dynamic> sharedConfig;

  int records(CloudSyncModule module) => moduleCounts[module] ?? 0;
  int get syncedRecords => outbox['synced'] ?? 0;
}

/// Local figures behind the Master configuration dashboard.
class MasterOverviewRepository {
  Future<MasterOverview> load() async {
    final Database db;
    try {
      db = await LocalDatabase.instance.database;
      await db.rawQuery('SELECT 1');
    } catch (_) {
      return const MasterOverview();
    }

    final storeId = TerminalConfigRepository.instance.config.storeId.trim();
    Future<int> count(String table, {String? where, List<Object?>? args}) async {
      try {
        final rows = await db.rawQuery(
          'SELECT COUNT(*) AS c FROM $table${where == null ? '' : ' WHERE $where'}',
          args,
        );
        return rows.isEmpty ? 0 : int.tryParse(rows.first['c']?.toString() ?? '') ?? 0;
      } catch (_) {
        return 0;
      }
    }

    Future<int> scoped(String table) => storeId.isEmpty
        ? count(table)
        : count(table, where: 'store_id = ?', args: [storeId]);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day).toIso8601String();

    final moduleCounts = <CloudSyncModule, int>{
      CloudSyncModule.company:
          await count('organizations') + await count('branches') + await count('tenants'),
      CloudSyncModule.usersRoles: await count('users') + await count('roles'),
      CloudSyncModule.categories: await scoped('categories'),
      CloudSyncModule.products: await scoped('products'),
      CloudSyncModule.stock: await count('stocks'),
      CloudSyncModule.customers: await count('customers'),
      CloudSyncModule.paymentMethods: await count('payment_methods'),
      CloudSyncModule.shifts: await count('shifts'),
      CloudSyncModule.sales: await scoped('sales'),
    };

    final ordersToday = storeId.isEmpty
        ? await count('sales', where: 'created_at >= ?', args: [today])
        : await count('sales', where: 'created_at >= ? AND store_id = ?', args: [today, storeId]);

    Map<String, int> outbox;
    try {
      outbox = await SyncOutbox.instance.counts();
    } catch (_) {
      outbox = const {};
    }

    Map<String, dynamic> sharedConfig;
    try {
      sharedConfig = await MasterConfigStore.instance.document();
    } catch (_) {
      sharedConfig = const {};
    }

    return MasterOverview(
      moduleCounts: moduleCounts,
      ordersToday: ordersToday,
      outbox: outbox,
      databaseOk: true,
      activity: await _activity(db),
      sharedConfig: sharedConfig,
    );
  }

  Future<List<MasterActivity>> _activity(Database db) async {
    final items = <MasterActivity>[];
    final currency = TerminalConfigRepository.instance.config.currencyCode;

    Future<List<Map<String, Object?>>> rows(String sql) async {
      try {
        return await db.rawQuery(sql);
      } catch (_) {
        return const [];
      }
    }

    for (final row in await rows(
      'SELECT name, ip, status, last_seen FROM lan_devices ORDER BY last_seen DESC LIMIT 6',
    )) {
      final at = DateTime.tryParse(row['last_seen']?.toString() ?? '');
      if (at == null) continue;
      final status = row['status']?.toString() ?? '';
      final name = row['name']?.toString().trim() ?? '';
      final ip = row['ip']?.toString().trim() ?? '';
      items.add(MasterActivity(
        kind: status == 'offline' || status == 'blocked'
            ? MasterActivityKind.warning
            : MasterActivityKind.device,
        title: switch (status) {
          'pending' => 'Pairing requested',
          'offline' => 'Terminal disconnected',
          'blocked' => 'Terminal blocked',
          _ => 'Terminal connected',
        },
        detail: [if (name.isNotEmpty) name, if (ip.isNotEmpty) ip].join(' • '),
        at: at,
      ));
    }

    for (final row in await rows(
      'SELECT reference, total, sync_status, created_at FROM sales ORDER BY created_at DESC LIMIT 8',
    )) {
      final at = DateTime.tryParse(row['created_at']?.toString() ?? '');
      if (at == null) continue;
      final synced = (row['sync_status']?.toString() ?? '').toLowerCase() == 'synced';
      final total = int.tryParse(row['total']?.toString() ?? '') ?? 0;
      items.add(MasterActivity(
        kind: MasterActivityKind.sale,
        title: synced ? 'Sale synced' : 'Sale recorded',
        detail: '${row['reference'] ?? ''} • ${MoneyFormatter.format(total, currencyCode: currency)}',
        at: at,
      ));
    }

    for (final row in await rows(
      'SELECT level, message, created_at FROM sync_logs ORDER BY id DESC LIMIT 10',
    )) {
      final at = DateTime.tryParse(row['created_at']?.toString() ?? '');
      if (at == null) continue;
      final error = (row['level']?.toString() ?? '') == 'error';
      items.add(MasterActivity(
        kind: error ? MasterActivityKind.error : MasterActivityKind.cloud,
        title: error ? 'Sync issue' : 'Cloud sync',
        detail: row['message']?.toString() ?? '',
        at: at,
      ));
    }

    items.sort((a, b) => b.at.compareTo(a.at));
    return items;
  }
}
