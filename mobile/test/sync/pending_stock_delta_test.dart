import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/sync/offline_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Mirrors [OfflineStore.pendingStockDeltas] SQL: stock_local = stock_cloud + pending.
void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE sales (
              id TEXT PRIMARY KEY,
              sync_status TEXT NOT NULL
            )
          ''');
          await database.execute('''
            CREATE TABLE stock_movements (
              id TEXT PRIMARY KEY,
              sale_id TEXT NOT NULL,
              product_id TEXT NOT NULL,
              quantity INTEGER NOT NULL,
              type TEXT NOT NULL,
              created_at TEXT NOT NULL,
              warehouse_id TEXT,
              variant_id TEXT,
              sync_status TEXT NOT NULL DEFAULT 'pending'
            )
          ''');
          await database.execute('''
            CREATE TABLE sync_outbox (
              id TEXT PRIMARY KEY,
              entity TEXT NOT NULL,
              entity_id TEXT NOT NULL,
              operation TEXT NOT NULL,
              payload TEXT NOT NULL,
              created_at TEXT NOT NULL,
              status TEXT NOT NULL,
              retry_count INTEGER NOT NULL DEFAULT 0,
              last_error TEXT
            )
          ''');
        },
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<Map<String, int>> pendingDeltas() async {
    final result = <String, int>{};
    final saleRows = await db.rawQuery('''
      SELECT m.product_id AS product_id, SUM(m.quantity) AS delta
      FROM stock_movements m
      INNER JOIN sales s ON s.id = m.sale_id
      WHERE UPPER(m.type) = 'SALE'
        AND s.sync_status NOT IN ('synced', 'discarded')
        AND UPPER(IFNULL(m.sync_status, 'pending')) != 'VOIDED'
      GROUP BY m.product_id
    ''');
    for (final row in saleRows) {
      final id = row['product_id']?.toString() ?? '';
      if (id.isEmpty) continue;
      result[id] = (result[id] ?? 0) + (row['delta'] as int? ?? 0);
    }
    final adjRows = await db.rawQuery('''
      SELECT m.product_id AS product_id, SUM(m.quantity) AS delta
      FROM stock_movements m
      WHERE UPPER(m.type) != 'SALE'
        AND (
          NOT EXISTS (
            SELECT 1 FROM sync_outbox o
            WHERE o.entity = 'stock' AND o.entity_id = m.id
          )
          OR EXISTS (
            SELECT 1 FROM sync_outbox o
            WHERE o.entity = 'stock' AND o.entity_id = m.id
              AND o.status IN ('PENDING', 'SYNCING', 'FAILED', 'CONFLICT')
          )
        )
      GROUP BY m.product_id
    ''');
    for (final row in adjRows) {
      final id = row['product_id']?.toString() ?? '';
      if (id.isEmpty) continue;
      result[id] = (result[id] ?? 0) + (row['delta'] as int? ?? 0);
    }
    return result;
  }

  test('sale during sync stays in pending delta until ACK', () async {
    await db.insert('sales', {'id': 'sale-1', 'sync_status': 'pending'});
    await db.insert('stock_movements', {
      'id': 'm1',
      'sale_id': 'sale-1',
      'product_id': 'p1',
      'quantity': -2,
      'type': 'SALE',
      'created_at': '2026-10-22T12:00:00.000',
    });

    // Cloud says 10; local pending -2 → display 8.
    final pending = await pendingDeltas();
    expect(pending['p1'], -2);
    expect(10 + (pending['p1'] ?? 0), 8);

    await db.update('sales', {'sync_status': 'synced'}, where: 'id = ?', whereArgs: ['sale-1']);
    expect(await pendingDeltas(), isEmpty);
  });

  test('discarded or voided sale is excluded from pending', () async {
    await db.insert('sales', {'id': 'sale-2', 'sync_status': 'discarded'});
    await db.insert('stock_movements', {
      'id': 'm2',
      'sale_id': 'sale-2',
      'product_id': 'p1',
      'quantity': -4,
      'type': 'SALE',
      'created_at': '2026-10-22T12:00:00.000',
      'sync_status': 'voided',
    });
    expect(await pendingDeltas(), isEmpty);
  });

  test('duplicate outbox SYNCED adjustment is excluded from pending', () async {
    await db.insert('stock_movements', {
      'id': 'adj-1',
      'sale_id': 'prod-1',
      'product_id': 'p1',
      'quantity': -3,
      'type': 'ADJUSTMENT_OUT',
      'created_at': '2026-10-22T12:00:00.000',
    });
    await db.insert('sync_outbox', {
      'id': 'o1',
      'entity': 'stock',
      'entity_id': 'adj-1',
      'operation': 'create',
      'payload': '{}',
      'created_at': '2026-10-22T12:00:00.000',
      'status': 'SYNCED',
      'retry_count': 0,
    });
    expect(await pendingDeltas(), isEmpty);
  });

  test('failed stock push remains pending for retry after disconnect', () async {
    await db.insert('stock_movements', {
      'id': 'adj-2',
      'sale_id': 'prod-2',
      'product_id': 'p2',
      'quantity': 5,
      'type': 'PRODUCTION_IN',
      'created_at': '2026-10-22T12:00:00.000',
    });
    await db.insert('sync_outbox', {
      'id': 'o2',
      'entity': 'stock',
      'entity_id': 'adj-2',
      'operation': 'create',
      'payload': '{}',
      'created_at': '2026-10-22T12:00:00.000',
      'status': 'FAILED',
      'retry_count': 1,
      'last_error': 'timeout',
    });
    final pending = await pendingDeltas();
    expect(pending['p2'], 5);
  });

  test('catalog snapshot does not restore the pre-sale quantity', () {
    expect(
      OfflineStore.mergeOnHand(incoming: 61, pending: 0, local: 58, lastCloud: 61),
      58,
    );
    expect(
      OfflineStore.mergeOnHand(incoming: 61, pending: -3, local: 61, lastCloud: 61),
      58,
    );
    expect(
      OfflineStore.mergeOnHand(incoming: 56, pending: 0, local: 58, lastCloud: 61),
      56,
    );
    expect(
      OfflineStore.mergeOnHand(incoming: 71, pending: 0, local: 58, lastCloud: 61),
      68,
    );
    expect(
      OfflineStore.mergeOnHand(incoming: 68, pending: 0, local: 58, lastCloud: 58),
      68,
    );
  });
}
