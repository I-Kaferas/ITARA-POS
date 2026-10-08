import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../data/local/local_database.dart';
import 'log_entry.dart';
import 'log_type.dart';

/// Persistent ring buffer for diagnostic logs (§57).
class LogStore {
  LogStore({LocalDatabase? database, int maxEntries = 5000})
      : _database = database ?? LocalDatabase.instance,
        _maxEntries = maxEntries;

  final LocalDatabase _database;
  final int _maxEntries;
  static const _uuid = Uuid();

  Future<LogEntry> append({
    required LogType type,
    required String severity,
    required String message,
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) async {
    final entry = LogEntry(
      id: _uuid.v4(),
      type: type,
      severity: severity,
      message: message,
      tag: tag,
      error: error?.toString(),
      stackTrace: stackTrace?.toString(),
      context: context,
      createdAt: DateTime.now().toUtc(),
    );

    final db = await _database.database;
    await db.insert(
      'app_logs',
      {
        'id': entry.id,
        'type': entry.type.name,
        'severity': entry.severity,
        'message': entry.message,
        'tag': entry.tag,
        'error': entry.error,
        'stack_trace': entry.stackTrace,
        'context': context == null ? null : jsonEncode(context),
        'created_at': entry.createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _prune(db);
    return entry;
  }

  Future<List<LogEntry>> recent({
    int limit = 200,
    LogType? type,
    String? severity,
    DateTime? since,
  }) async {
    final db = await _database.database;
    final where = <String>[];
    final args = <Object?>[];

    if (type != null) {
      where.add('type = ?');
      args.add(type.name);
    }
    if (severity != null) {
      where.add('severity = ?');
      args.add(severity);
    }
    if (since != null) {
      where.add('created_at >= ?');
      args.add(since.toUtc().toIso8601String());
    }

    final rows = await db.query(
      'app_logs',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return rows.map(_fromRow).toList();
  }

  Future<Map<String, int>> countsByType() async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      'SELECT type, COUNT(*) AS c FROM app_logs GROUP BY type',
    );
    final result = <String, int>{
      for (final type in LogType.values) type.name: 0,
    };
    for (final row in rows) {
      final type = row['type'] as String? ?? 'info';
      result[type] = (row['c'] as int?) ?? 0;
    }
    return result;
  }

  Future<int> count() async {
    final db = await _database.database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM app_logs');
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<void> clear() async {
    final db = await _database.database;
    await db.delete('app_logs');
  }

  Future<void> _prune(Database db) async {
    final total = (await db.rawQuery('SELECT COUNT(*) AS c FROM app_logs'))
        .first['c'] as int? ?? 0;
    if (total <= _maxEntries) return;

    final overflow = total - _maxEntries;
    await db.rawDelete(
      '''
      DELETE FROM app_logs WHERE id IN (
        SELECT id FROM app_logs ORDER BY created_at ASC LIMIT ?
      )
      ''',
      [overflow],
    );
  }

  LogEntry _fromRow(Map<String, dynamic> row) {
    Map<String, dynamic>? context;
    final raw = row['context'];
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) context = Map<String, dynamic>.from(decoded);
      } catch (_) {
        context = {'raw': raw};
      }
    }
    return LogEntry(
      id: row['id'] as String,
      type: LogType.tryParse(row['type'] as String?) ?? LogType.info,
      severity: (row['severity'] as String?) ?? 'info',
      message: row['message'] as String? ?? '',
      tag: row['tag'] as String?,
      error: row['error'] as String?,
      stackTrace: row['stack_trace'] as String?,
      context: context,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
