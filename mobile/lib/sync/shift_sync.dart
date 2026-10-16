import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/terminal_config_repository.dart';
import '../data/local/document_dao.dart';
import '../data/local/local_database.dart';
import 'offline_store.dart';
import 'sync_models.dart';
import 'sync_numbers.dart';

/// Sends shifts opened / closed on this till to `/sync/push` so the web sees them.
class ShiftSync {
  ShiftSync._();

  static final ShiftSync instance = ShiftSync._();

  /// [post] sends one `/sync/push` body with the caller's auth headers.
  ///
  /// A close waits until every sale of that shift is synced, otherwise the
  /// server would compute the expected cash without them.
  Future<int> push(Future<http.Response> Function(String body) post) async {
    final rows = await DataModelDaos.shifts.list(orderBy: 'opened_at ASC');
    if (rows.isEmpty) return 0;

    final db = await LocalDatabase.instance.database;
    final registers = {
      for (final row in await DataModelDaos.cashRegisters.list()) row['id']?.toString() ?? '': row,
    };
    final config = TerminalConfigRepository.instance.config;
    final deviceId = config.deviceId.isNotEmpty ? config.deviceId : config.deviceIdentifier;

    final operations = <Map<String, dynamic>>[];
    final byOperation = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final opened = (row['shift_server_id']?.toString() ?? '').isNotEmpty;
      final closed = row['status']?.toString().toLowerCase() == 'closed';
      final closeSynced = row['shift_close_synced'] == true;
      if (opened && (!closed || closeSynced)) continue;

      final sales = await db.query(
        'sales',
        columns: ['server_id', 'sync_status'],
        where: 'cash_session_id = ?',
        whereArgs: [id],
      );

      if (!opened) {
        final register = registers[row['cash_register_id']?.toString() ?? ''];
        final operationId = 'shift-open-$id';
        operations.add({
          'id': operationId,
          'entity_type': 'cashier_shift',
          'entity_id': id,
          'operation': 'open',
          'payload': {
            'cash_register_id': row['cash_register_id'],
            if (register?['store_id'] != null) 'store_id': register!['store_id'],
            if (register?['code'] != null) 'register_code': register!['code'],
            if ((row['user_id']?.toString() ?? '').isNotEmpty) 'user_id': row['user_id'],
            'opening_balance': syncAsInt(row['opening_balance']),
            'opening_notes': row['opening_notes'] ?? '',
            'opened_at': _utc(row['opened_at']),
            if (deviceId.isNotEmpty) 'device_id': deviceId,
            'sale_ids': [
              for (final sale in sales)
                if ((sale['server_id']?.toString() ?? '').isNotEmpty) sale['server_id'].toString(),
            ],
          },
        });
        byOperation[operationId] = row;
      }

      final unsent = sales.any((sale) => sale['sync_status']?.toString() != SyncQueueStatus.synced.name);
      if (closed && !closeSynced && !unsent) {
        final operationId = 'shift-close-$id';
        operations.add({
          'id': operationId,
          'entity_type': 'cashier_shift',
          'entity_id': id,
          'operation': 'close',
          'payload': {
            'actual_cash': syncAsInt(row['actual_cash']),
            'closing_notes': row['closing_notes'] ?? '',
            'closed_at': _utc(row['closed_at']),
          },
        });
        byOperation[operationId] = row;
      }
    }
    if (operations.isEmpty) return 0;

    var synced = 0;
    for (var start = 0; start < operations.length; start += 50) {
      final batch = operations.sublist(start, (start + 50).clamp(0, operations.length));
      final response = await post(jsonEncode({'operations': batch}));
      if (response.statusCode != 200) {
        await OfflineStore.instance.log('error', 'Shifts non envoyés (HTTP ${response.statusCode})');
        return synced;
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>? ?? body;
      for (final result in data['results'] as List<dynamic>? ?? const []) {
        if (result is! Map) continue;
        final operationId = result['id']?.toString() ?? '';
        final row = byOperation[operationId];
        if (row == null) continue;
        if (result['status']?.toString() != 'synced') {
          await OfflineStore.instance.log(
            'error',
            'Shift ${row['id']} : ${result['error'] ?? 'refusé par le serveur'}',
          );
          continue;
        }
        await _mark(row, {
          'shift_server_id': result['server_id']?.toString() ?? row['shift_server_id'],
          if (operationId.startsWith('shift-close-')) 'shift_close_synced': true,
        });
        row['shift_server_id'] = result['server_id']?.toString() ?? row['shift_server_id'];
        synced++;
      }
    }
    return synced;
  }

  Future<void> _mark(Map<String, dynamic> row, Map<String, Object?> extras) async {
    final current = await DataModelDaos.shifts.find(row['id'].toString()) ?? row;
    final document = {...current, ...extras}..remove('json');
    await DataModelDaos.shifts.upsert(document, columns: {
      'cash_register_id': current['cash_register_id'],
      'cash_session_id': current['cash_session_id'] ?? current['id'],
      'user_id': current['user_id'],
      'status': current['status']?.toString() ?? 'open',
      'opened_at': current['opened_at']?.toString() ?? DateTime.now().toIso8601String(),
      'closed_at': current['closed_at'],
    });
  }

  String? _utc(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed?.toUtc().toIso8601String();
  }
}
