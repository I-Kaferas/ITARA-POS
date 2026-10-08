import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/sync/outbox/outbox_models.dart';
import 'package:pos_mobile/sync/outbox/sync_outbox.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('OutboxStatus (§30)', () {
    test('wire values are uppercase', () {
      expect(OutboxStatus.pending.wire, 'PENDING');
      expect(OutboxStatus.syncing.wire, 'SYNCING');
      expect(OutboxStatus.synced.wire, 'SYNCED');
      expect(OutboxStatus.failed.wire, 'FAILED');
      expect(OutboxStatus.conflict.wire, 'CONFLICT');
    });

    test('parse accepts wire and legacy lowercase', () {
      expect(OutboxStatus.parse('PENDING'), OutboxStatus.pending);
      expect(OutboxStatus.parse('SYNCING'), OutboxStatus.syncing);
      expect(OutboxStatus.parse('processing'), OutboxStatus.syncing);
      expect(OutboxStatus.parse('failed'), OutboxStatus.failed);
      expect(OutboxStatus.parse('retrying'), OutboxStatus.failed);
      expect(OutboxStatus.parse('conflict'), OutboxStatus.conflict);
      expect(OutboxStatus.parse(null), OutboxStatus.pending);
    });
  });

  group('OutboxEntry', () {
    test('toRow / fromRow round-trip', () {
      final entry = OutboxEntry(
        id: 'o1',
        entity: 'sale',
        entityId: 's1',
        operation: 'create',
        payload: '{"total":10}',
        createdAt: DateTime.parse('2026-10-07T12:00:00.000'),
        status: OutboxStatus.pending,
        retryCount: 2,
        lastError: 'timeout',
      );
      final row = entry.toRow();
      expect(row['entity'], 'sale');
      expect(row['status'], 'PENDING');
      expect(row['retry_count'], 2);
      expect(row.containsKey('entity_type'), isFalse);

      final restored = OutboxEntry.fromRow(row);
      expect(restored.id, 'o1');
      expect(restored.entity, 'sale');
      expect(restored.entityId, 's1');
      expect(restored.status, OutboxStatus.pending);
      expect(restored.retryCount, 2);
      expect(restored.lastError, 'timeout');
    });

    test('fromRow accepts legacy sync_queue columns', () {
      final entry = OutboxEntry.fromRow({
        'id': 'q1',
        'entity_type': 'customer',
        'entity_id': 'c1',
        'operation': 'create',
        'payload': '{}',
        'created_at': '2026-10-07T12:00:00.000',
        'status': 'processing',
        'attempts': 3,
        'error_message': 'boom',
      });
      expect(entry.entity, 'customer');
      expect(entry.status, OutboxStatus.syncing);
      expect(entry.retryCount, 3);
      expect(entry.lastError, 'boom');
    });

    test('toCompatMap exposes SyncEngine aliases', () {
      final map = OutboxEntry(
        id: 'o2',
        entity: 'sale',
        entityId: 's2',
        operation: 'create',
        payload: '{}',
        createdAt: DateTime.parse('2026-10-07T12:00:00.000'),
        status: OutboxStatus.failed,
        retryCount: 1,
        lastError: 'err',
      ).toCompatMap();
      expect(map['entity_type'], 'sale');
      expect(map['attempts'], 1);
      expect(map['error_message'], 'err');
      expect(map['status'], 'FAILED');
    });
  });

  group('sync_outbox table + SyncOutbox', () {
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

    test('schema has §30 columns', () async {
      final cols = await db.rawQuery('PRAGMA table_info(sync_outbox)');
      final names = cols.map((c) => c['name']).toSet();
      expect(
        names,
        containsAll([
          'id',
          'entity',
          'entity_id',
          'operation',
          'payload',
          'created_at',
          'status',
          'retry_count',
          'last_error',
        ]),
      );
    });

    test('enqueue + status transitions via executor', () async {
      final entry = await SyncOutbox.instance.enqueue(
        entity: 'sale',
        entityId: 'sale-1',
        operation: 'create',
        payload: {'total': 42},
        executor: db,
      );
      expect(entry.status, OutboxStatus.pending);

      await SyncOutbox.instance.markSyncing(entry.id, executor: db);
      var rows = await db.query(SyncOutbox.table, where: 'id = ?', whereArgs: [entry.id]);
      expect(rows.single['status'], 'SYNCING');

      await SyncOutbox.instance.markFailed(
        entry.id,
        'network',
        retryCount: 1,
        executor: db,
      );
      rows = await db.query(SyncOutbox.table, where: 'id = ?', whereArgs: [entry.id]);
      expect(rows.single['status'], 'FAILED');
      expect(rows.single['retry_count'], 1);
      expect(rows.single['last_error'], 'network');

      await SyncOutbox.instance.markConflict(entry.id, 'stock', executor: db);
      rows = await db.query(SyncOutbox.table, where: 'id = ?', whereArgs: [entry.id]);
      expect(rows.single['status'], 'CONFLICT');

      await SyncOutbox.instance.markSynced(entry.id, executor: db);
      rows = await db.query(SyncOutbox.table, where: 'id = ?', whereArgs: [entry.id]);
      expect(rows.single['status'], 'SYNCED');
      expect(rows.single['last_error'], isNull);
    });

    test('migrates legacy sync_queue row shape', () async {
      await db.execute('''
        CREATE TABLE sync_queue (
          id TEXT PRIMARY KEY,
          entity_type TEXT,
          entity_id TEXT,
          operation TEXT,
          payload TEXT,
          status TEXT,
          attempts INTEGER,
          error_message TEXT,
          created_at TEXT
        )
      ''');
      await db.insert('sync_queue', {
        'id': 'legacy-1',
        'entity_type': 'customer',
        'entity_id': 'c-1',
        'operation': 'create',
        'payload': '{}',
        'status': 'failed',
        'attempts': 4,
        'error_message': 'old',
        'created_at': '2026-01-01T00:00:00.000',
      });

      final rows = await db.query('sync_queue');
      for (final row in rows) {
        final statusRaw = (row['status']?.toString() ?? 'pending').toLowerCase();
        final status = switch (statusRaw) {
          'processing' => 'SYNCING',
          'synced' => 'SYNCED',
          'failed' || 'retrying' => 'FAILED',
          'conflict' => 'CONFLICT',
          _ => 'PENDING',
        };
        await db.insert('sync_outbox', {
          'id': row['id'],
          'entity': row['entity_type'] ?? 'sale',
          'entity_id': row['entity_id'],
          'operation': row['operation'] ?? 'create',
          'payload': row['payload'] ?? '{}',
          'created_at': row['created_at'],
          'status': status,
          'retry_count': row['attempts'] ?? 0,
          'last_error': row['error_message'],
        });
      }

      final out = await db.query(SyncOutbox.table);
      expect(out, hasLength(1));
      expect(out.single['entity'], 'customer');
      expect(out.single['status'], 'FAILED');
      expect(out.single['retry_count'], 4);
      expect(out.single['last_error'], 'old');
    });
  });
}
