import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/terminal_config_repository.dart';
import '../data/local/document_dao.dart';
import '../data/local/local_database.dart';
import 'offline_store.dart';
import 'sync_models.dart';
import 'sync_numbers.dart';

/// Sends shifts opened / closed on this till to `/sync/push` then `/sync/ack`.
/// Local shift flags are updated only after ACK (same guarantee as sales).
class ShiftSync {
  ShiftSync._();

  static final ShiftSync instance = ShiftSync._();

  /// [postPush] → `/sync/push`, [postAck] → `/sync/ack` (same auth headers).
  ///
  /// A close waits until every sale of that shift is synced, otherwise the
  /// server would compute the expected cash without them.
  Future<int> push({
    required Future<http.Response> Function(String body) postPush,
    required Future<http.Response> Function(String body) postAck,
  }) async {
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
        final storeId = (row['store_id']?.toString() ?? '').trim().isNotEmpty
            ? row['store_id'].toString()
            : register?['store_id'];
        final operationId = 'shift-open-$id';
        operations.add({
          'id': operationId,
          'entity_type': 'cashier_shift',
          'entity_id': id,
          'operation': 'open',
          'payload': {
            'idempotency_key': id,
            'cash_register_id': row['cash_register_id'],
            if (storeId != null) 'store_id': storeId,
            if (register?['code'] != null) 'register_code': register!['code'],
            if ((row['user_id']?.toString() ?? '').isNotEmpty) 'user_id': row['user_id'],
            'opening_balance': syncAsInt(row['opening_balance']),
            'opening_notes': row['opening_notes'] ?? '',
            'opened_at': _utc(row['opened_at']),
            if (deviceId.isNotEmpty) 'device_id': deviceId,
            'pos_id': deviceId,
            'sale_ids': [
              for (final sale in sales)
                if ((sale['server_id']?.toString() ?? '').isNotEmpty) sale['server_id'].toString(),
            ],
          },
        });
        byOperation[operationId] = row;
      }

      // Close only after every sale of this session is on the server.
      final unsent = sales.any((sale) {
        final status = sale['sync_status']?.toString() ?? '';
        return status != SyncQueueStatus.synced.name;
      });
      if (closed && !closeSynced && unsent) {
        await OfflineStore.instance.log(
          'warn',
          'Shift $id : clôture non envoyée — ${sales.where((s) => s['sync_status']?.toString() != SyncQueueStatus.synced.name).length} vente(s) encore en attente de sync',
        );
      }
      if (closed && !closeSynced && !unsent) {
        final operationId = 'shift-close-$id';
        operations.add({
          'id': operationId,
          'entity_type': 'cashier_shift',
          'entity_id': id,
          'operation': 'close',
          'payload': {
            'idempotency_key': 'close-$id',
            'actual_cash': syncAsInt(row['actual_cash']),
            'closing_notes': row['closing_notes'] ?? '',
            'closed_at': _utc(row['closed_at']),
            if (deviceId.isNotEmpty) 'device_id': deviceId,
            'pos_id': deviceId,
          },
        });
        byOperation[operationId] = row;
      }
    }
    if (operations.isEmpty) return 0;

    var synced = 0;
    for (var start = 0; start < operations.length; start += 50) {
      final batch = operations.sublist(start, (start + 50).clamp(0, operations.length));
      final response = await postPush(jsonEncode({'operations': batch}));
      if (response.statusCode != 200) {
        await OfflineStore.instance.log('error', 'Shifts non envoyés (HTTP ${response.statusCode})');
        return synced;
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>? ?? body;
      final readyForAck = <Map<String, dynamic>>[];
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
        readyForAck.add({
          'id': operationId,
          'entity_type': 'cashier_shift',
          'entity_id': row['id']?.toString() ?? '',
          'server_id': result['server_id']?.toString(),
          '_is_close': operationId.startsWith('shift-close-'),
          '_server_id': result['server_id']?.toString() ?? row['shift_server_id'],
          '_row': row,
        });
      }

      if (readyForAck.isEmpty) continue;

      final ackBody = {
        'operations': [
          for (final item in readyForAck)
            {
              'id': item['id'],
              'entity_type': 'cashier_shift',
              'entity_id': item['entity_id'],
              if ((item['server_id']?.toString() ?? '').isNotEmpty) 'server_id': item['server_id'],
            },
        ],
      };
      Set<String> acknowledgedIds = {};
      try {
        final ackResponse = await postAck(jsonEncode(ackBody));
        if (ackResponse.statusCode == 200) {
          final ackJson = jsonDecode(ackResponse.body) as Map<String, dynamic>;
          final ackData = ackJson['data'] as Map<String, dynamic>? ?? ackJson;
          final ids = ackData['acknowledged_ids'] as List<dynamic>? ?? const [];
          acknowledgedIds = ids.map((id) => id.toString()).where((id) => id.isNotEmpty).toSet();
        } else {
          await OfflineStore.instance.log(
            'error',
            'Shifts ACK manquant (HTTP ${ackResponse.statusCode}) — marquage local reporté',
          );
        }
      } catch (error) {
        await OfflineStore.instance.log(
          'error',
          'Shifts ACK échoué — données conservées : $error',
        );
      }

      for (final item in readyForAck) {
        final operationId = item['id']?.toString() ?? '';
        if (!acknowledgedIds.contains(operationId)) {
          await OfflineStore.instance.log(
            'warn',
            'Shift ${item['entity_id']} : push OK mais ACK absent — nouvel envoi au prochain cycle',
          );
          continue;
        }
        final row = item['_row'] as Map<String, dynamic>;
        await _mark(row, {
          'shift_server_id': item['_server_id'],
          if (item['_is_close'] == true) 'shift_close_synced': true,
        });
        row['shift_server_id'] = item['_server_id'];
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
