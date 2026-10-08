import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../data/local/local_database.dart';
import 'outbox_models.dart';

export 'outbox_models.dart';

/// Repository Outbox locale `sync_outbox` (mobile.md §30).
class SyncOutbox {
  SyncOutbox._();

  static final SyncOutbox instance = SyncOutbox._();

  static const table = 'sync_outbox';

  Future<Database> get _db => LocalDatabase.instance.database;

  /// Insert dans une transaction existante ou via la DB.
  Future<OutboxEntry> enqueue({
    required String entity,
    required String entityId,
    required String operation,
    required Object payload,
    String? id,
    DatabaseExecutor? executor,
  }) async {
    final entry = OutboxEntry(
      id: id ?? const Uuid().v4(),
      entity: entity,
      entityId: entityId,
      operation: operation,
      payload: payload is String ? payload : jsonEncode(payload),
      createdAt: DateTime.now(),
      status: OutboxStatus.pending,
    );
    final db = executor ?? await _db;
    await db.insert(
      table,
      entry.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return entry;
  }

  Future<List<OutboxEntry>> pending({int limit = 50}) async {
    final db = await _db;
    final rows = await db.query(
      table,
      where: "status IN (?, ?)",
      whereArgs: [OutboxStatus.pending.wire, OutboxStatus.failed.wire],
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(OutboxEntry.fromRow).toList();
  }

  Future<List<Map<String, dynamic>>> pendingCompat({int limit = 50}) async {
    final items = await pending(limit: limit);
    return items.map((e) => e.toCompatMap()).toList();
  }

  Future<void> markSyncing(String id, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _db;
    await db.update(
      table,
      {'status': OutboxStatus.syncing.wire},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markSynced(String id, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _db;
    await db.update(
      table,
      {
        'status': OutboxStatus.synced.wire,
        'last_error': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markFailed(
    String id,
    String error, {
    required int retryCount,
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _db;
    await db.update(
      table,
      {
        'status': OutboxStatus.failed.wire,
        'retry_count': retryCount,
        'last_error': error,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markConflict(
    String id,
    String error, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _db;
    await db.update(
      table,
      {
        'status': OutboxStatus.conflict.wire,
        'last_error': error,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> releaseStuck({DatabaseExecutor? executor}) async {
    final db = executor ?? await _db;
    await db.update(
      table,
      {'status': OutboxStatus.pending.wire},
      where: 'status = ?',
      whereArgs: [OutboxStatus.syncing.wire],
    );
  }

  Future<void> retryNow(String id) async {
    final db = await _db;
    await db.update(
      table,
      {
        'status': OutboxStatus.pending.wire,
        'last_error': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> retryAllFailed() async {
    final db = await _db;
    await db.update(
      table,
      {
        'status': OutboxStatus.pending.wire,
        'last_error': null,
      },
      where: 'status IN (?, ?)',
      whereArgs: [OutboxStatus.failed.wire, OutboxStatus.conflict.wire],
    );
  }

  Future<OutboxEntry?> find(String id) async {
    final db = await _db;
    final rows = await db.query(table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return OutboxEntry.fromRow(rows.first);
  }

  Future<String?> latestError() async {
    final db = await _db;
    final rows = await db.query(
      table,
      columns: ['last_error'],
      where: 'status IN (?, ?) AND last_error IS NOT NULL',
      whereArgs: [OutboxStatus.failed.wire, OutboxStatus.conflict.wire],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['last_error'] as String?;
  }

  Future<Map<String, int>> counts() async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT status, COUNT(*) AS c FROM $table GROUP BY status',
    );
    final byStatus = <String, int>{
      for (final row in rows)
        OutboxStatus.parse(row['status']?.toString()).wire:
            int.tryParse(row['c']?.toString() ?? '0') ?? 0,
    };
    return {
      'pending': (byStatus[OutboxStatus.pending.wire] ?? 0) +
          (byStatus[OutboxStatus.syncing.wire] ?? 0),
      'failed': byStatus[OutboxStatus.failed.wire] ?? 0,
      'synced': byStatus[OutboxStatus.synced.wire] ?? 0,
      'conflicts': byStatus[OutboxStatus.conflict.wire] ?? 0,
    };
  }

  Future<List<Map<String, dynamic>>> details({int limit = 50}) async {
    final db = await _db;
    final rows = await db.query(table, orderBy: 'created_at DESC', limit: limit);
    return rows.map((r) => OutboxEntry.fromRow(r).toCompatMap()).toList();
  }
}
